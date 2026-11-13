#!/usr/bin/env python3
"""Upload a pg_dump archive with the ECS task role and verify object size."""

import os
import sys

import boto3


def main() -> int:
    path, bucket, key = sys.argv[1:]
    expected_size = os.path.getsize(path)
    if expected_size == 0:
        raise RuntimeError("Backup archive is empty")

    s3 = boto3.client("s3", region_name=os.environ["AWS_REGION"])
    s3.upload_file(path, bucket, key)
    actual_size = s3.head_object(Bucket=bucket, Key=key)["ContentLength"]
    if actual_size != expected_size:
        raise RuntimeError(
            f"S3 object size mismatch: expected {expected_size}, got {actual_size}"
        )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Backup upload or verification failed: {exc}", file=sys.stderr)
        sys.exit(1)
