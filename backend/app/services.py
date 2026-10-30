import json, os, uuid
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from flask import current_app


def aws_client(service):
    return boto3.client(service, region_name=current_app.config["AWS_REGION"])


def create_resume_upload(name, content_type):
    bucket = current_app.config["S3_BUCKET"]
    if not bucket:
        raise RuntimeError("S3_BUCKET is not configured")
    safe_name = os.path.basename(name).replace(" ", "_")[:120]
    key = f"resumes/{uuid.uuid4().hex}/{safe_name}"
    url = aws_client("s3").generate_presigned_url(
        "put_object", Params={"Bucket": bucket, "Key": key, "ContentType": content_type}, ExpiresIn=300
    )
    return {"upload_url": url, "object_key": key, "expires_in": 300}


def publish_resume_job(candidate_id, object_key):
    queue_url = current_app.config["SQS_RESUME_QUEUE_URL"]
    if not queue_url:
        return {"queued": False, "message": "SQS_RESUME_QUEUE_URL is not configured"}
    aws_client("sqs").send_message(QueueUrl=queue_url, MessageBody=json.dumps({"candidate_id": candidate_id, "object_key": object_key}))
    return {"queued": True}


def publish_event(event_type, detail):
    bus = current_app.config["EVENT_BUS_NAME"]
    aws_client("events").put_events(Entries=[{
        "Source": "talentflow.application", "DetailType": event_type,
        "Detail": json.dumps(detail), "EventBusName": bus
    }])
