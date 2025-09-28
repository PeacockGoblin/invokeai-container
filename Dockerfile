FROM ghcr.io/invoke-ai/invokeai:5.9.0rc2-cuda

USER root
RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/invoke-bootstrap
COPY scripts/entrypoint.sh scripts/download_models.sh ./
RUN chmod +x entrypoint.sh download_models.sh

ENTRYPOINT ["/opt/invoke-bootstrap/entrypoint.sh"]
