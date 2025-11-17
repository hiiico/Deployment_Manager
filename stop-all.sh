#!/bin/bash
set -e

echo "🛑 Stopping Full Stack Deployment"
echo "================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if ngrok is running
is_ngrok_running() {
    if curl -sf --max-time 2 http://localhost:4040/api/tunnels >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Stop ngrok tunnel
stop_ngrok() {
    print_status "Stopping ngrok tunnel"
    
    # Check current status
    if is_ngrok_running; then
        print_status "Ngrok is running - stopping..."
    else
        print_status "Ngrok is not running"
    fi
    
    # Multiple methods to ensure ngrok stops
    local ngrok_stopped=false
    
    # Method 1: Using PID file
    if [ -f /tmp/ngrok.pid ]; then
        local pid=$(cat /tmp/ngrok.pid)
        if kill -0 "$pid" 2>/dev/null; then
            print_status "Stopping ngrok via PID file (PID: $pid)"
            kill "$pid" 2>/dev/null && ngrok_stopped=true
            print_success "Stopped ngrok via PID file"
        fi
        rm -f /tmp/ngrok.pid
    fi
    
    # Method 2: Kill all ngrok processes directly
    local ngrok_processes
    ngrok_processes=$(pgrep -f "ngrok" 2>/dev/null || true)
    if [ -n "$ngrok_processes" ]; then
        print_status "Stopping ngrok processes: $ngrok_processes"
        pkill -f "ngrok" 2>/dev/null || true
        sleep 2
        # Force kill if still running
        pkill -9 -f "ngrok" 2>/dev/null || true
        ngrok_stopped=true
        print_success "Stopped all ngrok processes"
    fi
    
    if ! $ngrok_stopped; then
        print_success "No ngrok processes were running"
    fi
    
    # Verify ngrok is stopped
    sleep 2
    if is_ngrok_running; then
        print_warning "Ngrok might still be running - checking..."
        sleep 3
        if is_ngrok_running; then
            print_error "Ngrok failed to stop - manual intervention required"
        else
            print_success "Ngrok successfully stopped after verification"
        fi
    else
        print_success "Ngrok verified as stopped"
    fi
}

# Stop Kubernetes application
stop_kubernetes_app() {
    print_status "Stopping Kubernetes application"
    
    cd /home/hiiico/Mywebsites/kubernetes 2>/dev/null || {
        print_warning "Kubernetes directory not found - skipping app cleanup"
        return 0
    }
    
    # Delete resources in correct order
    print_status "Deleting Kubernetes resources..."
    
    # Ingress first
    if kubectl get ingress main-ingress >/dev/null 2>&1; then
        kubectl delete -f ingress.yml --ignore-not-found=true 2>/dev/null
        print_success "Deleted ingress"
    fi
    
    # Service second
    if kubectl get service node-app-service >/dev/null 2>&1; then
        kubectl delete -f service.yml --ignore-not-found=true 2>/dev/null
        print_success "Deleted service"
    fi
    
    # Deployment last
    if kubectl get deployment node-app >/dev/null 2>&1; then
        kubectl delete -f deployment.yml --ignore-not-found=true 2>/dev/null
        print_success "Deleted deployment"
    fi
    
    # Clean up any remaining pods
    local remaining_pods
    remaining_pods=$(kubectl get pods -l app=node-app -o name 2>/dev/null | wc -l)
    if [ "$remaining_pods" -gt 0 ]; then
        print_status "Cleaning up $remaining_pods remaining pods"
        kubectl delete pods -l app=node-app --ignore-not-found=true --force --grace-period=0 2>/dev/null
        sleep 3
        print_success "Remaining pods cleaned up"
    fi
}

# Stop Kubernetes cluster
stop_kubernetes_cluster() {
    print_status "Stopping Kubernetes cluster"
    
    if kind get clusters 2>/dev/null | grep -q "my-apps-cluster"; then
        print_status "Deleting cluster: my-apps-cluster"
        if kind delete cluster --name my-apps-cluster 2>/dev/null; then
            print_success "Kubernetes cluster stopped"
        else
            print_warning "Failed to stop cluster gracefully - forcing deletion"
            kind delete cluster --name my-apps-cluster --force 2>/dev/null
            print_success "Kubernetes cluster force stopped"
        fi
    else
        print_success "No Kubernetes cluster running"
    fi
}

# Cleanup temporary files
cleanup_files() {
    print_status "Cleaning up temporary files"
    
    local files=("/tmp/ngrok.log" "/tmp/ngrok.pid")
    local cleaned=0
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Removed $file"
            ((cleaned++))
        fi
    done
    
    if [ $cleaned -eq 0 ]; then
        print_success "No temporary files to clean"
    fi
}

# Verification function
verify_cleanup() {
    print_status "Verifying cleanup"
    
    local errors=0
    
    # Check ngrok
    if is_ngrok_running; then
        print_warning "Ngrok is still running"
        ((errors++))
    else
        print_success "Ngrok stopped"
    fi
    
    # Check Kubernetes cluster
    if kind get clusters 2>/dev/null | grep -q "my-apps-cluster"; then
        print_warning "Kubernetes cluster still exists"
        ((errors++))
    else
        print_success "Kubernetes cluster stopped"
    fi
    
    # Check Kubernetes resources
    if kubectl get pods -l app=node-app 2>/dev/null | grep -q "node-app"; then
        print_warning "Kubernetes pods still exist"
        ((errors++))
    else
        print_success "Kubernetes resources cleaned"
    fi
    
    return $errors
}

# Quick stop function
quick_stop() {
    print_status "Quick stop mode"
    pkill -f "ngrok" 2>/dev/null || true
    kind delete cluster --name my-apps-cluster 2>/dev/null || true
    print_success "Quick stop completed"
}

# Show current status
show_status() {
    print_status "Current System Status"
    echo "==================="
    
    # Ngrok status
    echo "Ngrok Tunnel:"
    if is_ngrok_running; then
        echo "   ✅ Running"
    else
        echo "   ❌ Stopped"
    fi
    
    # Kubernetes status
    echo "Kubernetes Cluster:"
    if kind get clusters 2>/dev/null | grep -q "my-apps-cluster"; then
        echo "   ✅ Running"
    else
        echo "   ❌ Stopped"
    fi
    
    echo "==================="
}

# Main execution flow
main() {
    local mode=${1:-normal}
    
    case $mode in
        quick)
            quick_stop
            ;;
        debug|status)
            show_status
            ;;
        help|--help|-h)
            echo "Usage: ./stop-all.sh [mode]"
            echo "Modes:"
            echo "  (none)    Normal stop (recommended)"
            echo "  quick     Fast stop (force kill)"
            echo "  debug     Show status without stopping"
            echo "  status    Same as debug"
            echo "  help      Show this help"
            ;;
        *)
            echo
            stop_ngrok
            echo
            stop_kubernetes_app
            echo
            stop_kubernetes_cluster
            echo
            cleanup_files
            echo
            
            if verify_cleanup; then
                echo
                echo -e "${GREEN}🎉 Full stack stopped successfully!${NC}"
            else
                echo
                echo -e "${YELLOW}⚠️  Some components may still be running${NC}"
                echo -e "${YELLOW}    Run './stop-all.sh quick' for force stop${NC}"
            fi
            ;;
    esac
    
    echo
}

main "$@"