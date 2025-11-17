#!/bin/bash
# ngrok-manager.sh

CONFIG_FILE="ngrok-config.yml"
NGROK_PORT="8080"

case "$1" in
    start)
        echo "Starting ngrok tunnel..."
        pkill ngrok 2>/dev/null
        ngrok http $NGROK_PORT --log=stdout > ngrok.log 2>&1 &
        echo "Ngrok started on port $NGROK_PORT"
        ;;
    stop)
        echo "Stopping ngrok tunnel..."
        pkill ngrok
        echo "Ngrok stopped"
        ;;
    status)
        if pgrep ngrok > /dev/null; then
            echo "✅ Ngrok is running"
            curl -s http://localhost:4040/api/tunnels | python3 -m json.tool
        else
            echo "❌ Ngrok is stopped"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac