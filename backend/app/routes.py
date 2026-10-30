from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from sqlalchemy.exc import IntegrityError
from .extensions import db
from .models import User, Job, Candidate, Application
from .services import create_resume_upload, publish_resume_job, publish_event

api = Blueprint("api", __name__)

@api.post("/auth/register")
def register():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))
    if not email or "@" not in email or len(password) < 12:
        return jsonify(error="Provide a valid email and password of at least 12 characters."), 400
    if User.query.filter_by(email=email).first(): return jsonify(error="Account already exists."), 409
    user = User(email=email, role="recruiter"); user.set_password(password)
    db.session.add(user); db.session.commit()
    return jsonify(id=user.id, email=user.email, role=user.role), 201

@api.post("/auth/login")
def login():
    data = request.get_json(silent=True) or {}
    user = User.query.filter_by(email=str(data.get("email", "")).strip().lower()).first()
    if not user or not user.check_password(str(data.get("password", ""))):
        return jsonify(error="Invalid email or password."), 401
    return jsonify(access_token=create_access_token(identity=str(user.id)), user={"id": user.id, "email": user.email, "role": user.role})

@api.get("/me")
@jwt_required()
def me():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user: return jsonify(error="User not found"), 404
    return jsonify(id=user.id, email=user.email, role=user.role)

@api.get("/jobs")
def list_jobs():
    jobs = Job.query.filter_by(status="open").order_by(Job.created_at.desc()).all()
    return jsonify([{"id": j.id, "title": j.title, "department": j.department, "description": j.description, "created_at": j.created_at.isoformat()} for j in jobs])

@api.post("/jobs")
@jwt_required()
def create_job():
    data = request.get_json(silent=True) or {}
    title, description = str(data.get("title", "")).strip(), str(data.get("description", "")).strip()
    if not title or not description: return jsonify(error="title and description are required"), 400
    job = Job(title=title, department=str(data.get("department", ""))[:120], description=description, created_by=int(get_jwt_identity()))
    db.session.add(job); db.session.commit()
    try: publish_event("JOB_CREATED", {"job_id": job.id, "title": job.title})
    except Exception: current_app.logger.exception("EventBridge publish failed; job was still created")
    return jsonify(id=job.id, title=job.title, department=job.department, description=job.description, status=job.status), 201


@api.get("/candidates")
@jwt_required()
def list_candidates():
    candidates = Candidate.query.order_by(
        Candidate.created_at.desc()
    ).all()

    return jsonify([
        {
            "id": c.id,
            "name": c.full_name,
            "email": c.email,
            "phone": c.phone,
            "role": c.role,
            "experience": c.experience,
            "score": c.score,
            "stage": c.stage,
            "source": c.source,
            "applied": c.created_at.date().isoformat()
        }
        for c in candidates
    ])


@api.post("/candidates")
@jwt_required()
def create_candidate():
    data = request.get_json(silent=True) or {}

    name = str(data.get("full_name", "")).strip()
    email = str(data.get("email", "")).strip().lower()

    if not name or not email or "@" not in email:
        return jsonify(
            error="full_name and valid email are required"
        ), 400

    try:
        score = int(data.get("score", 0))
    except (TypeError, ValueError):
        return jsonify(error="score must be an integer"), 400

    if not 0 <= score <= 100:
        return jsonify(error="score must be between 0 and 100"), 400

    candidate = Candidate(
        full_name=name,
        email=email,
        phone=str(data.get("phone", ""))[:40],
        role=str(data.get("role", ""))[:160],
        experience=str(data.get("experience", ""))[:80],
        score=score,
        stage="Applied",
        source=str(data.get("source", "Website"))[:80]
    )

    db.session.add(candidate)
    db.session.commit()

    try:
        publish_event("CANDIDATE_CREATED", {
            "candidate_id": candidate.id
        })
    except Exception:
        current_app.logger.exception(
            "EventBridge publish failed; candidate was still created"
        )

    return jsonify(
        id=candidate.id,
        name=candidate.full_name,
        email=candidate.email,
        role=candidate.role,
        experience=candidate.experience,
        score=candidate.score,
        stage=candidate.stage,
        source=candidate.source
    ), 201

@api.put("/candidates/<int:candidate_id>")
@jwt_required()
def update_candidate(candidate_id):
    data = request.get_json(silent=True) or {}

    stage = str(data.get("stage", "")).strip()

    allowed_stages = [
        "Applied",
        "Screening",
        "Shortlisted",
        "Interview",
        "Offer",
        "Hired",
        "Rejected"
    ]

    if stage not in allowed_stages:
        return jsonify(error="Invalid candidate stage"), 400

    candidate = db.session.get(Candidate, candidate_id)

    if not candidate:
        return jsonify(error="Candidate not found"), 404

    candidate.stage = stage
    db.session.commit()

    return jsonify(
        message="Candidate stage updated successfully",
        id=candidate.id,
        stage=candidate.stage
    ), 200

@api.post("/resumes/presign")
def presign_resume():
    data = request.get_json(silent=True) or {}
    name, content_type = str(data.get("filename", "")), str(data.get("content_type", ""))
    if not name.lower().endswith(".pdf") or content_type != "application/pdf":
        return jsonify(error="Only PDF resumes are accepted."), 400
    try: return jsonify(create_resume_upload(name, content_type))
    except RuntimeError as exc: return jsonify(error=str(exc)), 503
    except Exception: current_app.logger.exception("Could not create upload URL"); return jsonify(error="Upload service unavailable"), 503

@api.post("/applications")
def apply_for_job():
    data = request.get_json(silent=True) or {}
    try: job_id, candidate_id = int(data.get("job_id")), int(data.get("candidate_id"))
    except (TypeError, ValueError): return jsonify(error="job_id and candidate_id must be integers"), 400
    job, candidate = db.session.get(Job, job_id), db.session.get(Candidate, candidate_id)
    if not job or job.status != "open": return jsonify(error="Open job not found"), 404
    if not candidate: return jsonify(error="Candidate not found"), 404
    application = Application(job_id=job_id, candidate_id=candidate_id)
    db.session.add(application)
    try: db.session.commit()
    except IntegrityError: db.session.rollback(); return jsonify(error="Candidate already applied for this job"), 409
    try: publish_event("APPLICATION_CREATED", {"application_id": application.id, "job_id": job_id, "candidate_id": candidate_id})
    except Exception: current_app.logger.exception("EventBridge publish failed; application was still created")
    return jsonify(id=application.id, job_id=job_id, candidate_id=candidate_id, status=application.status), 201

@api.post("/candidates/<int:candidate_id>/resume-complete")
def resume_complete(candidate_id):
    data = request.get_json(silent=True) or {}
    key = str(data.get("object_key", ""))
    if not key.startswith("resumes/") or ".." in key: return jsonify(error="Invalid object_key"), 400
    candidate = db.session.get(Candidate, candidate_id)
    if not candidate: return jsonify(error="Candidate not found"), 404
    candidate.resume_key = key; db.session.commit()
    try: queue_status = publish_resume_job(candidate.id, key)
    except Exception: current_app.logger.exception("Queue publish failed"); return jsonify(error="Resume saved but processing could not be queued"), 503
    try: publish_event("RESUME_UPLOADED", {"candidate_id": candidate.id, "object_key": key})
    except Exception: current_app.logger.exception("EventBridge publish failed")
    return jsonify(candidate_id=candidate.id, resume_key=key, processing=queue_status), 202

@api.get("/applications")
@jwt_required()
def list_applications():
    rows = db.session.query(Application, Job, Candidate).join(Job, Application.job_id == Job.id).join(Candidate, Application.candidate_id == Candidate.id).order_by(Application.created_at.desc()).all()
    return jsonify([{"id": a.id, "job": j.title, "candidate": c.full_name, "email": c.email, "status": a.status, "created_at": a.created_at.isoformat()} for a,j,c in rows])

@api.get("/health/ready")
def readiness():
    try: db.session.execute(db.text("SELECT 1")); return jsonify(status="ready", database="ok")
    except Exception: current_app.logger.exception("Readiness check failed"); return jsonify(status="not_ready"), 503
