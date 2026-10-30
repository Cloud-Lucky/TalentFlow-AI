"""Minimal SQS-triggered worker. Extend with PDF text extraction and human-reviewed AI screening."""
import json, logging, os
import boto3
logger = logging.getLogger(); logger.setLevel(logging.INFO)
REGION = os.environ.get("AWS_REGION", "ap-south-1")
BUCKET = os.environ["S3_BUCKET"]

def handler(event, context):
    s3 = boto3.client("s3", region_name=REGION)
    processed = 0
    failures = []
    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])
            key = body["object_key"]
            if not key.startswith("resumes/") or ".." in key:
                raise ValueError("Invalid resume object key")
            # Validate object exists. Add a controlled PDF extraction / screening step here.
            s3.head_object(Bucket=BUCKET, Key=key)
            logger.info("Resume object verified candidate_id=%s key=%s", body.get("candidate_id"), key)
            processed += 1
        except Exception:
            logger.exception("Resume processing failed")
            failures.append({"itemIdentifier": record.get("messageId", "")})
    return {"batchItemFailures": failures, "processed": processed}
