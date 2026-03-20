FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    sed \
    bash \
    && rm -rf /var/lib/apt/lists/*

RUN pip install pytest pyyaml

COPY . /app/

RUN chmod +x /app/scripts/*.sh 2>/dev/null || true

CMD ["sleep", "infinity"]
