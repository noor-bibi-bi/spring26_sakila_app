# Use lightweight base image
FROM python:3.9-slim

# Metadata labels
LABEL maintainer="Noor Bibi"
LABEL version="1.0.0"
LABEL description="Optimized Flask Sakila App Container"

# Set working directory
WORKDIR /app

# Copy only requirements first (for caching)
COPY requirements.txt .

RUN apt-get update && apt-get install -y curl \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get clean

# Install dependencies (single layer, no cache)
RUN pip install --no-cache-dir -r requirements.txt

# Copy rest of application
COPY . .

# Create non-root user
RUN useradd -m appuser
USER appuser

# Environment variables (no secrets hardcoded)
ENV MYSQL_HOST=sakila-db-server \
    MYSQL_USER=root \
    MYSQL_DB=sakila

# Expose only required port
EXPOSE 5000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
CMD curl --fail http://localhost:5000 || exit 1

# Run application
CMD ["python", "app.py"]