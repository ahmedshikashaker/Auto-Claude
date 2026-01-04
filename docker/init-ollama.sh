#!/bin/sh
set -e
echo "Waiting for Ollama to be ready..."
# Wait for Ollama to be reachable
until ollama list > /dev/null 2>&1; do
  echo "Ollama not ready yet, retrying in 2s..."
  sleep 2
done

echo "Ollama is ready. Starting model pulls."

echo "Pulling embeddinggemma..."
ollama pull embeddinggemma

echo "Pulling deepseek-r1:7b..."
ollama pull deepseek-r1:7b

echo "All models pulled successfully."
