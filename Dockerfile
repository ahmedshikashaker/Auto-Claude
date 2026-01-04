# Dockerfile
FROM python:3.12-slim AS python-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Set up Python environment
WORKDIR /app
COPY apps/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY apps/backend/ ./apps/backend/

# --- Frontend Build Stage ---
FROM node:22-alpine AS frontend-build

WORKDIR /app
COPY apps/frontend/package*.json ./
COPY apps/frontend/scripts ./scripts
RUN npm install

COPY apps/frontend/ ./
# Modify for web build (remove Electron-specific code)
ENV VITE_API_URL=/api
ENV VITE_WS_URL=/ws
# Using standard build script as build:web does not exist
RUN npm run build

# --- Production Stage ---
FROM python-base AS production

# Install Caddy for reverse proxy
RUN apt-get update && apt-get install -y caddy && rm -rf /var/lib/apt/lists/*

# Copy frontend build (electron-vite outputs to out/renderer)
COPY --from=frontend-build /app/out/renderer /var/www/html

# Copy Caddyfile
COPY docker/Caddyfile /etc/caddy/Caddyfile

# Create data directories
RUN mkdir -p /data /projects /home/claude

# Environment
ENV PYTHONPATH=/app/apps/backend
ENV DATA_DIR=/data
ENV PROJECTS_DIR=/projects
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s \
    CMD curl -f http://localhost:3000/api/health || exit 1

# Start script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]