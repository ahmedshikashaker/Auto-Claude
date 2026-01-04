#!/bin/bash
# docker/start.sh

# Start FastAPI in background
cd /app/auto-claude
uvicorn api.main:app --host 0.0.0.0 --port 8000 &

# Start Caddy (foreground)
caddy run --config /etc/caddy/Caddyfile