FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-boto3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY run-backup /usr/local/bin/run-backup
COPY upload.py /usr/local/bin/upload.py
RUN chmod 0555 /usr/local/bin/run-backup /usr/local/bin/upload.py

USER postgres
ENTRYPOINT ["/usr/local/bin/run-backup"]
