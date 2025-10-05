FROM ghcr.io/invoke-ai/invokeai:5.9.0rc2-cuda

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/invoke-bootstrap
COPY scripts/entrypoint.sh scripts/download_models.sh ./
RUN chmod +x entrypoint.sh download_models.sh

# Optional, but helpful
EXPOSE 9090
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://127.0.0.1:9090/ || exit 1

ENTRYPOINT ["/opt/invoke-bootstrap/entrypoint.sh"]
