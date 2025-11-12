#!/bin/bash

# Cleanup script for Grafana Docker Desktop setup

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Grafana Docker Desktop Cleanup"
echo "=============================="
echo ""

echo "This will:"
echo "  - Stop and remove Grafana container"
echo "  - Optionally remove persistent data"
echo ""

read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

echo ""
echo "Stopping Grafana..."
cd "$SCRIPT_DIR"
docker-compose down

echo ""
read -p "Remove persistent data (volumes)? (yes/no): " REMOVE_DATA

if [ "$REMOVE_DATA" = "yes" ]; then
    docker-compose down -v
    echo "✓ Data removed"
else
    echo "✓ Data preserved (will be reused on next start)"
fi

echo ""
echo "✓ Grafana cleanup complete"
echo ""
echo "To reinstall: ./setup-grafana-docker.sh"
