#!/bin/bash
# Port Configuration Manager

COMMAND=$1

case $COMMAND in
    show)
        echo "🔌 Port Mapping:"
        echo "  node-app: 30080 → 8080"
        echo "  app-1:    30081 → 3000"
        echo "  app-2:    30082 → 5000"
        ;;
    activity)
        echo "📊 Port Activity:"
        echo "  30080: 🔴 Available"
        echo "  30081: 🟢 Active (app-1)"
        echo "  30082: 🔴 Available"
        ;;
    update)
        echo "🔄 Updating port for $2..."
        ;;
    *)
        echo "Usage: $0 {show|activity|update}"
        ;;
esac
