FROM node:20-alpine AS frontend-build

WORKDIR /app/frontend

COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund

COPY frontend/ ./
RUN npm run build

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

COPY --from=frontend-build /app/frontend/dist ./frontend/dist

RUN if [ -f package.json ]; then npm install --no-audit --no-fund --omit=dev; fi

RUN mkdir -p /app/data /app/backend/app/storage/media /app/backend/app/storage/exports

ENV PYTHONUNBUFFERED=1 \
    NODE_ENV=production \
    FRONTEND_SERVE_STATIC=true \
    CONFIG_FILE=/app/config/default.yaml

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

CMD ["python", "main.py", "--host", "0.0.0.0", "--port", "8000"]
