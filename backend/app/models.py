from datetime import datetime, timezone
from werkzeug.security import generate_password_hash, check_password_hash
from .extensions import db

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(254), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(24), nullable=False, default="recruiter")
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    def set_password(self, value): self.password_hash = generate_password_hash(value)
    def check_password(self, value): return check_password_hash(self.password_hash, value)

class Job(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(160), nullable=False)
    department = db.Column(db.String(120), default="")
    description = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(24), default="open", nullable=False)
    created_by = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

class Candidate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(160), nullable=False)
    email = db.Column(db.String(254), nullable=False, index=True)
    phone = db.Column(db.String(40), default="")
    resume_key = db.Column(db.String(1024), default="")
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

class Application(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    job_id = db.Column(db.Integer, db.ForeignKey("job.id"), nullable=False, index=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey("candidate.id"), nullable=False, index=True)
    status = db.Column(db.String(32), default="submitted", nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    __table_args__ = (db.UniqueConstraint("job_id", "candidate_id", name="uq_application_job_candidate"),)
