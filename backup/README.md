# PostgreSQL backup image

`Dockerfile` uses PostgreSQL 17's `pg_dump` to create a custom-format (`-Fc`) full logical database archive. `run-backup` uploads it to S3 with the ECS task role, then `upload.py` checks the object size using `HeadObject`. A dump, upload, or verification failure exits nonzero so the task failure alarm can fire.

The task supplies `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `BACKUP_BUCKET`, and `AWS_REGION`. `BACKUP_PREFIX` defaults to `database`. PostgreSQL connections require TLS by default (`PGSSLMODE=require`). The role needs `s3:PutObject` and `s3:GetObject` on the backup prefix.
