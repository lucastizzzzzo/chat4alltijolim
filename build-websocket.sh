#!/bin/bash
# Build WebSocket Gateway and all services
# Usage: ./build-websocket.sh

set -e

echo "=========================================="
echo "  Building Chat4All with WebSocket"
echo "=========================================="

echo ""
echo "▶ Building all Java services..."
mvn clean package -DskipTests

echo ""
echo "▶ Building Docker images..."
docker-compose build websocket-gateway
docker-compose build router-worker
docker-compose build api-service

echo ""
echo "✓ Build complete!"
echo ""
echo "Next steps:"
echo "  1. Start services: docker-compose up -d"
echo "  2. Check logs: docker-compose logs -f websocket-gateway"
echo "  3. Test CLI: cd cli && python3 chat4all-cli.py"
echo ""
