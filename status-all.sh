#!/bin/bash

echo "🔍 Full Stack Status"
echo "==================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

# Health checks
check_kubernetes() {
    kubectl cluster-info >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1
}

check_app() {
    kubectl get pods -l app=node-app 2>/dev/null | grep -q "Running"
}

check_ngrok() {
    curl -sf --max-time 2 http://localhost:4040/api/tunnels >/dev/null 2>&1
}

get_ngrok_url() {
    curl -sf http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^"]*\.ngrok[^"]*' | head -1
}

# Status display
echo "1. Kubernetes Cluster:"
if check_kubernetes; then
    echo -e "   ${GREEN}✅ Running${NC}"
    echo "   Pods:"
    kubectl get pods -l app=node-app 2>/dev/null | grep -v NAME || echo "      No pods found"
else
    echo -e "   ${RED}❌ Stopped${NC}"
fi

echo "2. Vue.js App:"
if check_app; then
    echo -e "   ${GREEN}✅ Running${NC}"
else
    echo -e "   ${RED}❌ Stopped${NC}"
fi

echo "3. Ngrok Tunnel:"
if check_ngrok; then
    echo -e "   ${GREEN}✅ Running${NC}"
    local url
    url=$(get_ngrok_url)
    if [ -n "$url" ]; then
        echo "   URL: $url"
    fi
else
    echo -e "   ${RED}❌ Stopped${NC}"
fi

echo "==================="

# Additional debug info if requested
if [ "$1" = "debug" ]; then
    print_status "Debug Information"
    echo "Ngrok Processes: $(pgrep -f ngrok 2>/dev/null || echo 'None')"
    echo "Kubernetes Context: $(kubectl config current-context 2>/dev/null || echo 'None')"
fi