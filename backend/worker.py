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


def update_candidate(candidate_id, resume_text):
    """Save extracted resume text in PostgreSQL."""

    with engine.begin() as connection:
        result = connection.execute(
            text("""
                UPDATE candidate
                SET resume_text = :resume_text,
                    resume_processed_at = :processed_at
                WHERE id = :candidate_id
            """),
            {
                "resume_text": resume_text,
                "processed_at": datetime.now(timezone.utc),
                "candidate_id": candidate_id
            }
        )

        if result.rowcount != 1:
            raise ValueError(
                f"Candidate {candidate_id} was not found"
            )


def process_message(message):
    """Process one SQS message."""

    body = json.loads(message["Body"])

    candidate_id = int(body["candidate_id"])
    object_key = body["object_key"]

    if not object_key.startswith("resumes/") or ".." in object_key:
        raise ValueError("Invalid S3 object key")

    logger.info(
        "Processing resume for candidate ID %s",
        candidate_id
    )

    resume_text = extract_pdf_text(object_key)

    update_candidate(candidate_id, resume_text)

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

