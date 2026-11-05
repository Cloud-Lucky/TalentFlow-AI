import json
import os
import uuid

import boto3
from flask import current_app


def aws_client(service):
    return boto3.client(
        service,
        region_name=current_app.config["AWS_REGION"]
    )



def create_resume_upload(name, content_type):
    bucket = current_app.config["S3_BUCKET"]

    if not bucket:
        raise RuntimeError("S3_BUCKET is not configured")

    if content_type != "application/pdf":
        raise ValueError("Only PDF files are accepted")

    safe_name = os.path.basename(name).replace(" ", "_")[:120]
    key = f"resumes/{uuid.uuid4().hex}/{safe_name}"

    max_size = 10 * 1024 * 1024

    presigned = aws_client("s3").generate_presigned_post(
        Bucket=bucket,
        Key=key,
        Fields={
            "Content-Type": "application/pdf"
        },
        Conditions=[
            {"Content-Type": "application/pdf"},
            ["content-length-range", 1, max_size]
        ],
        ExpiresIn=300
    )

    return {
        "upload_url": presigned["url"],
        "fields": presigned["fields"],
        "object_key": key,
        "expires_in": 300,
        "max_size": max_size
    }




def verify_resume_upload(object_key):
    bucket = current_app.config["S3_BUCKET"]

    if not bucket:
        raise RuntimeError("S3_BUCKET is not configured")

    response = aws_client("s3").head_object(
        Bucket=bucket,
        Key=object_key
    )

    file_size = response.get("ContentLength", 0)
    content_type = response.get("ContentType", "")

    max_size = 10 * 1024 * 1024

    if file_size <= 0:
        raise ValueError("Uploaded PDF is empty")

    if file_size > max_size:
        raise ValueError("Resume exceeds the 10 MB size limit")

    if content_type != "application/pdf":
        raise ValueError("Uploaded file must have PDF content type")

    # Verify the actual PDF file signature
    pdf_header = aws_client("s3").get_object(
        Bucket=bucket,
        Key=object_key,
        Range="bytes=0-4"
    )

    signature = pdf_header["Body"].read(5)

    if signature != b"%PDF-":
        raise ValueError("Invalid PDF file signature")

    return True



def publish_resume_job(candidate_id, object_key):
    queue_url = current_app.config["SQS_RESUME_QUEUE_URL"]

    if not queue_url:
        return {
            "queued": False,
            "message": "SQS_RESUME_QUEUE_URL is not configured"
        }

    aws_client("sqs").send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({
            "candidate_id": candidate_id,
            "object_key": object_key
        })
    )

    return {"queued": True}


def publish_event(event_type, detail):
    bus = current_app.config["EVENT_BUS_NAME"]

    response = aws_client("events").put_events(
        Entries=[{
            "Source": "talentflow.application",
            "DetailType": event_type,
            "Detail": json.dumps(detail),
            "EventBusName": bus
        }]
    )

    failed_count = response.get("FailedEntryCount", 0)

    if failed_count > 0:
        current_app.logger.error(
            "EventBridge failed to publish %s: %s",
            event_type,
            response.get("Entries")
        )
        raise RuntimeError(
            f"EventBridge failed to publish {event_type}"
        )

    event_id = response["Entries"][0].get("EventId")

    current_app.logger.info(
        "EventBridge event published successfully: type=%s event_id=%s",
        event_type,
        event_id
    )

    return event_id
