import os
import json
import time
import logging
from datetime import datetime, timezone
from io import BytesIO

import boto3
from pypdf import PdfReader
from sqlalchemy import create_engine, text

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
logger = logging.getLogger(__name__)

# Configuration
AWS_REGION = os.environ["AWS_REGION"]
S3_BUCKET = os.environ["S3_BUCKET"]
QUEUE_URL = os.environ["SQS_RESUME_QUEUE_URL"]
DATABASE_URL = os.environ["DATABASE_URL"]

# AWS clients use the EC2 instance role
s3 = boto3.client("s3", region_name=AWS_REGION)
sqs = boto3.client("sqs", region_name=AWS_REGION)

# Database connection
engine = create_engine(DATABASE_URL, pool_pre_ping=True)


def extract_pdf_text(object_key):
    """Download a PDF from S3 and extract its text."""

    response = s3.get_object(
        Bucket=S3_BUCKET,
        Key=object_key
    )

    pdf_content = response["Body"].read()

    reader = PdfReader(BytesIO(pdf_content))

    if reader.is_encrypted:
        raise ValueError("Encrypted PDFs are not supported")

    pages = []

    for page in reader.pages:
        pages.append(page.extract_text() or "")

    extracted_text = "\n".join(pages).strip()

    if not extracted_text:
        raise ValueError("No extractable text found in PDF")

    return extracted_text


def is_resume_already_processed(candidate_id, object_key):
    """Check whether this exact resume has already been processed."""

    with engine.connect() as connection:
        result = connection.execute(
            text("""
                SELECT resume_processed_at
                FROM candidate
                WHERE id = :candidate_id
                  AND resume_key = :object_key
            """),
            {
                "candidate_id": candidate_id,
                "object_key": object_key
            }
        ).first()

        if result is None:
            return False

        return result[0] is not None


def update_candidate(candidate_id, object_key, resume_text):
    """Save extracted text only if this is still the candidate's current resume."""

    with engine.begin() as connection:
        result = connection.execute(
            text("""
                UPDATE candidate
                SET resume_text = :resume_text,
                    resume_processed_at = :processed_at
                WHERE id = :candidate_id
                  AND resume_key = :object_key
            """),
            {
                "resume_text": resume_text,
                "processed_at": datetime.now(timezone.utc),
                "candidate_id": candidate_id,
                "object_key": object_key
            }
        )

        if result.rowcount == 1:
            return True

        candidate_exists = connection.execute(
            text("""
                SELECT 1 FROM candidate WHERE id = :candidate_id
            """),
            {"candidate_id": candidate_id}
        ).first()

        if not candidate_exists:
            raise ValueError(
                f"Candidate {candidate_id} was not found"
            )

        logger.warning(
            "Skipping outdated resume message for candidate ID %s",
            candidate_id
        )
        return False




def process_message(message):
    """Validate and process one SQS message."""

    try:
        body = json.loads(message["Body"])
    except (KeyError, json.JSONDecodeError) as exc:
        raise ValueError("Message body is not valid JSON") from exc

    if not isinstance(body, dict):
        raise ValueError("Message body must be a JSON object")

    candidate_id = body.get("candidate_id")
    object_key = body.get("object_key")

    # Validate candidate ID
    if (
        isinstance(candidate_id, bool)
        or not isinstance(candidate_id, int)
        or candidate_id <= 0
    ):
        raise ValueError("candidate_id must be a positive integer")

    # Validate S3 object key
    if not isinstance(object_key, str) or not object_key:
        raise ValueError("object_key must be a non-empty string")

    key_parts = object_key.split("/")

    if (
        len(key_parts) < 2
        or key_parts[0] != "resumes"
        or any(part in ("", ".", "..") for part in key_parts)
    ):
        raise ValueError("Invalid S3 resume object key")

    if is_resume_already_processed(candidate_id, object_key):
        logger.info(
            "Resume already processed for candidate ID %s; skipping",
            candidate_id
        )
        return

    logger.info(
        "Processing resume for candidate ID %s",
        candidate_id
    )

    resume_text = extract_pdf_text(object_key)

    updated = update_candidate(
        candidate_id,
        object_key,
        resume_text
    )

    if not updated:
        logger.info(
            "Skipped outdated resume for candidate ID %s",
            candidate_id
        )
        return

    logger.info(
        "Successfully processed candidate ID %s; extracted %s characters",
        candidate_id,
        len(resume_text)
    )



def main():
    logger.info("TalentFlow resume worker started")

    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20,
                VisibilityTimeout=120
            )

            messages = response.get("Messages", [])

            for message in messages:
                try:
                    process_message(message)

                    # Delete only after successful database update
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=message["ReceiptHandle"]
                    )

                    logger.info("SQS message deleted successfully")

                except Exception:
                    logger.exception(
                        "Resume processing failed; SQS will retry"
                    )

        except Exception:
            logger.exception("SQS polling failed")
            time.sleep(5)


if __name__ == "__main__":
    main()

