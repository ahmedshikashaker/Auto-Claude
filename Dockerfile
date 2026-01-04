# Dockerfile
FROM python:3.12-slim AS python-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | sh

# Set up Python environment
WORKDIR /app
COPY auto-claude/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install API dependencies
COPY auto-claude/api/requirements.txt ./api-requirements.txt
RUN pip install --no-cache-dir -r api-requirements.txt

# Copy application code
COPY auto-claude/ ./auto-claude/

# --- Frontend Build Stage ---
FROM node:22-alpine AS frontend-build

WORKDIR /app
COPY auto-claude-ui/package*.json ./
RUN npm ci

COPY auto-claude-ui/ ./
# Modify for web build (remove Electron-specific code)
ENV VITE_API_URL=/api
ENV VITE_WS_URL=/ws
RUN npm run build:web

# --- Production Stage ---
FROM python-base AS production

# Install Caddy for reverse proxy
RUN apt-get update && apt-get install -y caddy && rm -rf /var/lib/apt/lists/*

# Copy frontend build
COPY --from=frontend-build /app/dist/web /var/www/html

# Copy Caddyfile
COPY docker/Caddyfile /etc/caddy/Caddyfile

# Create data directories
RUN mkdir -p /data /projects /home/claude

# Environment
ENV PYTHONPATH=/app/auto-claude
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