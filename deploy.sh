#!/bin/bash
# Deploy EncChat server to remote host
# Usage: ./deploy.sh

set -e

SERVER_IP="162.211.181.145"
SERVER_USER="root"
REMOTE_DIR="/opt/enc-chat"

echo "=== EncChat Server Deploy Script ==="
echo "Target: ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}"

# Create server directory
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${REMOTE_DIR}"

# Copy server files
echo "Uploading server files..."
scp -r server/src ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/
scp server/package.json server/tsconfig.json server/.env.example ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/
scp server/Dockerfile server/docker-compose.yml server/docker/Caddyfile ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/

# Create uploads directory
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${REMOTE_DIR}/uploads"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "To finish setup on the server:"
echo "  ssh ${SERVER_USER}@${SERVER_IP}"
echo "  cd ${REMOTE_DIR}"
echo "  cp .env.example .env"
echo "  # Edit .env with your settings"
echo "  docker-compose up -d"
echo ""
echo "Verify:"
echo "  curl http://${SERVER_IP}:3000/health"
