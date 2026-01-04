#!/bin/bash
# docker/start.sh

# Start FastAPI in background (Disabled: api.main not found)
# cd /app
# uvicorn api.main:app --host 0.0.0.0 --port 8000 &
# Keep container running for now
tail -f /dev/null &

# Start Caddy (foreground)
caddy run --config /etc/caddy/Caddyfile