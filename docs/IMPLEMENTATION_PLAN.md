# Implementation plan and verification checklist

## Phase 1 — Local baseline
- [ ] Copy original frontend assets into `frontend/`.
- [ ] Start Compose; verify UI, `/health`, `/api/health/ready`.
- [ ] Register a recruiter, log in, create a job, create a candidate and submit an application.
- [ ] Wire the existing UI to API endpoints and remove client-side demo credentials.

## Phase 2 — AWS foundation
- [ ] Secure root MFA, deployment IAM, budget alerts.
- [ ] Create ECR, build/push a versioned backend image.
- [ ] Review Terraform plan; verify VPC routes, SGs, private RDS and private S3.
- [ ] Deploy ECS/ALB and test health checks.
- [ ] Upload static frontend and test CloudFront.

## Phase 3 — Files and events
- [ ] Configure exact CORS origins and API routing over HTTPS.
- [ ] Test presigned PDF upload with a dummy file.
- [ ] Verify SQS message, Lambda invocation, retries and DLQ.
- [ ] Subscribe a test email to SNS and confirm it.
- [ ] Verify EventBridge event delivery and CloudWatch logs.

## Phase 4 — Security and production readiness
- [ ] Replace ECS plaintext environment secrets with Secrets Manager references.
- [ ] Add database migrations, RBAC, rate limiting, candidate ownership checks and audit logs.
- [ ] Add file content validation, malware scanning and retention/deletion policy.
- [ ] Add TLS, Route 53 custom domain, CloudTrail, Config and CloudWatch alarms.
- [ ] Review cost estimates, backups, restore test, incident response and resource teardown.

## Distinguishing report scope from implementation choices
The internship report specifies the AWS services and target architecture. This package adds implementation choices (Flask REST API, PostgreSQL, ECS Fargate, JWT, presigned uploads, a minimal SQS Lambda worker) to make the project executable as a starter. ECS Fargate is used instead of the report's initial EC2 compute plan; use EC2 Auto Scaling instead if required by the mentor.
