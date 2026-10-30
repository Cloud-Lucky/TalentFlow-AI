# TalentFlow AI — AWS implementation starter

This package extends the public TalentFlow-AI frontend repository with a beginner-friendly backend API, local Docker development environment, and Terraform scaffolding for AWS. It is an implementation starter, not a claim that AWS resources have already been deployed or that all business features are production-ready.

## What is included

- `backend/`: Flask REST API, JWT authentication, SQLAlchemy models for users/jobs/candidates/applications, S3 presigned PDF uploads, SQS job publishing, EventBridge events, health endpoints.
- `docker-compose.yml`: local PostgreSQL, API, and Nginx frontend.
- `terraform/`: VPC with public/app/database subnets, ALB, ECS Fargate service with autoscaling, private PostgreSQL RDS, private S3 buckets for resumes and frontend, CloudFront, ECR, SQS + DLQ, SNS, EventBridge, Lambda resume worker, CloudWatch logs and IAM roles.
- `lambda/resume_worker/`: SQS-triggered worker validates the S3 object exists. PDF extraction and AI screening are intentionally not faked; implement and test those steps before enabling them.
- `.github/workflows/ci.yml`: basic Python syntax CI.

## Important: copy the original frontend files

The repository owner’s original frontend source is not duplicated in this starter. Clone your original repository, then copy these files into this package's `frontend/` directory:

- `index.html`
- `style.css`
- `script.js`
- `1.png`

Keep the filenames unchanged. The original front end currently uses browser-side demo behavior; it will not automatically use this new API. The backend endpoints are available under `/api`. Wire the UI's login, job, candidate, application, and resume-upload actions to the API before calling it a fully integrated application. Never ship demo credentials or client-side-only authentication in production.

## Local run (Docker Desktop required)

1. Install Docker Desktop and start it.
2. Copy `.env.example` to `.env`.
3. Replace `SECRET_KEY` and `JWT_SECRET_KEY` with long random values. Do not commit `.env`.
4. Copy the four frontend files listed above into `frontend/`.
5. Run:

```bash
docker compose up --build
```

6. Open `http://localhost:8080` for the frontend and `http://localhost:5000/health` for API health.
7. API readiness check: `http://localhost:5000/api/health/ready`.

The local API defaults to SQLite if run outside Compose, but Compose uses PostgreSQL. AWS integrations require valid AWS credentials and the configured bucket, queue and event bus. Local use does not require AWS credentials if those integrations are not called.

## API quick start

Register a development recruiter (use a strong password):

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"recruiter@example.com","password":"ChangeThisToALongUniquePassword"}'
```

Log in:

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"recruiter@example.com","password":"ChangeThisToALongUniquePassword"}'
```

Create a job with the returned access token:

```bash
curl -X POST http://localhost:5000/api/jobs \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"title":"Cloud Engineer","department":"Engineering","description":"AWS and automation experience"}'
```

Public API endpoints currently include `GET /api/jobs`, `POST /api/candidates`, `POST /api/applications`, `POST /api/resumes/presign`, and `POST /api/candidates/<id>/resume-complete`. Protected endpoints include `POST /api/jobs`, `GET /api/applications`, and `GET /api/me`.

## AWS deployment order

### A. Build and push the API image to ECR

Create the ECR repository using the AWS Console or a first Terraform apply after adapting `container_image` to a temporary valid image URI. The cleaner beginner approach is to create the ECR repository first in the console, push the image, then configure Terraform with the immutable tag.

```bash
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
docker build -t talentflow-api ./backend
docker tag talentflow-api:latest ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/talentflow-api:v1
docker push ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/talentflow-api:v1
```

Replace `ACCOUNT_ID`, region, repository and tag with your actual values.

### B. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Set `container_image` to the pushed image URI. Supply secrets through environment variables rather than committing them:

```bash
export TF_VAR_db_password='UseAUniqueStrongPasswordHere'
export TF_VAR_app_secret_key='UseAnotherLongRandomSecretHere'
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Review the plan and estimate charges before `terraform apply`. This starter creates chargeable resources, including NAT Gateway, ALB, RDS, Fargate tasks, CloudFront, and logs. You are responsible for reviewing the plan and deleting resources when finished.

**First-deployment caveat:** ECS cannot start until the image exists in ECR, and the Terraform configuration references the image. Create ECR first using the console or split ECR into an initial bootstrap configuration, push the image, and then apply the main stack. Do not use `latest` in a production pipeline; use immutable version tags.

### C. Publish the static frontend

After Terraform creates the frontend bucket and CloudFront distribution, copy the four original website files to the bucket:

```bash
aws s3 sync ../frontend s3://YOUR_FRONTEND_BUCKET/ --delete
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths '/*'
```

Use the actual output values. The CloudFront default domain uses the default CloudFront certificate. For a custom domain, configure Route 53 and an ACM certificate in `us-east-1`, then update the distribution configuration.

### D. Configure the frontend to call the API

The current Terraform exposes the API on the ALB HTTP listener for lab setup and creates the frontend CloudFront distribution separately. Before real use, configure HTTPS and route `/api/*` to the ALB using CloudFront behaviors or a custom domain/reverse proxy, then update `CORS_ORIGINS` to the exact frontend origin. The sample `CORS_ORIGINS="*"` in Terraform is intentionally marked for replacement; wildcard CORS is not recommended for a real application.

## AWS services mapped to the internship report

| Report component | Starter implementation |
|---|---|
| VPC, public/private subnets, routing | Terraform VPC resources |
| Application compute and scaling | ECS Fargate service + target tracking; an alternative to EC2 Auto Scaling |
| ALB | Terraform Application Load Balancer |
| RDS | Private PostgreSQL RDS |
| S3 | Private resume bucket and private frontend bucket |
| SQS + DLQ | Resume processing queue and dead-letter queue |
| Lambda | SQS-triggered resume worker (object validation only) |
| SNS | Notification topic; add a confirmed email subscription manually |
| EventBridge | Application event bus/rule; API publishes events |
| CloudWatch | ECS logs and Lambda logs |
| Route 53 | Not created automatically; requires a domain/hosted zone you control |
| CloudTrail / AWS Config | Account-level governance; enable separately after reviewing cost/retention |
| Terraform | Main infrastructure stack |
| ECR | API image repository |

## Known gaps before production

- The existing frontend has not been modified to call the new API; this requires UI integration and browser testing.
- The backend schema uses `db.create_all()` for a starter. Add Alembic/Flask-Migrate migrations before production.
- The initial auth API is a minimal example. Add email verification, password reset, rate limiting, recruiter/admin provisioning, RBAC enforcement, CSRF considerations where cookies are used, and audit logging.
- The API currently exposes candidate creation and application submission without candidate authentication. Add authorization and anti-abuse controls before using real candidate data.
- The SQS Lambda worker currently validates object existence only. It does not parse PDFs, invoke an AI model, write evaluation results to RDS, or make hiring decisions.
- Resume upload completion must be bound to an authenticated candidate and verified against the actual S3 object metadata. Add file-size limits, malware scanning, retention/deletion controls, and private presigned GET URLs.
- The API publishes EventBridge events best-effort; production should use a transactional outbox/retry strategy so database commits and event delivery remain consistent.
- Terraform embeds a DB connection string and application secret in ECS task-definition environment values. For production, move these to Secrets Manager and reference them as ECS secrets.
- RDS deletion protection is disabled and final snapshots are skipped in this learning stack. Change both before production.
- TLS listener, custom domain, Route 53 records, CloudTrail organization trail, AWS Config rules, budget alerts, and detailed CloudWatch alarms need final configuration.
- This stack uses ECS Fargate, which is a deliberate deployment simplification. If your mentor explicitly requires EC2 and EC2 Auto Scaling, replace the ECS compute layer with an EC2 launch template/Auto Scaling Group behind the same ALB.

## Teardown

When you are done with the lab, run `terraform destroy` only after reviewing the plan. Empty S3 buckets first if they contain objects; `force_destroy` is disabled to prevent accidental deletion. Preserve any data you need. Deleting infrastructure does not necessarily delete every separately configured resource, such as a manually created hosted zone or account-level CloudTrail trail.
