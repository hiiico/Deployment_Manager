#!/bin/bash
# Individual App Management

COMMAND=$1
APP_NAME=$2

case $COMMAND in
    start)
        echo "🚀 Starting $APP_NAME..."
        ;;
    stop)
        echo "🛑 Stopping $APP_NAME..."
        ;;
    status)
        echo "📊 Status of $APP_NAME..."
        ;;
    logs)
        echo "📋 Logs for $APP_NAME..."
        ;;
    list)
        echo "📝 All Applications:"
        echo "  - node-app (Kubernetes)"
        echo "  - app-1 (Docker Compose)"
        echo "  - app-2 (Kubernetes)"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|list} [app-name]"
        ;;
esac
