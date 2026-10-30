# API contract (starter)

Base URL in local Compose: `http://localhost:5000/api`

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/register` | No (development only) | Create a recruiter account; password minimum 12 chars |
| POST | `/auth/login` | No | Return JWT access token |
| GET | `/me` | JWT | Current user |
| GET | `/jobs` | No | List open jobs |
| POST | `/jobs` | JWT | Create a job |
| POST | `/candidates` | No (needs protection for production) | Create candidate record |
| POST | `/applications` | No (needs protection for production) | Submit an application |
| POST | `/resumes/presign` | No (needs candidate auth for production) | Request a short-lived S3 PDF upload URL |
| POST | `/candidates/{id}/resume-complete` | No (needs candidate ownership checks) | Store S3 key and queue processing |
| GET | `/applications` | JWT | List application records |
| GET | `/health/ready` | No | Database readiness check |

This is an API foundation, not a complete authorization model. Do not use with real personal data until the noted ownership, rate-limiting, role and upload validation gaps are closed.
