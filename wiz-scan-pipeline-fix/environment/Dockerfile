FROM python:3.12-slim

WORKDIR /app

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    sed \
    && rm -rf /var/lib/apt/lists/*

RUN pip install pytest

# Copy all environment files to /app/
COPY . /app/

# Keep container running for agent interaction
ENTRYPOINT ["tail", "-f", "/dev/null"]
