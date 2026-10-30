import os

class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "local-dev-only-change-me")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", SECRET_KEY)
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///talentflow.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    MAX_CONTENT_LENGTH = int(os.environ.get("MAX_CONTENT_LENGTH", 10 * 1024 * 1024))
    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080").split(",")
    S3_BUCKET = os.environ.get("S3_BUCKET", "")
    AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")
    SQS_RESUME_QUEUE_URL = os.environ.get("SQS_RESUME_QUEUE_URL", "")
    EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "default")
