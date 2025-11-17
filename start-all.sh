#!/bin/bash
set -e

echo "🚀 Smart Full Stack Deployment"
echo "=============================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBERNETES_DIR="$SCRIPT_DIR/kubernetes"
NGROK_DIR="$SCRIPT_DIR/ngrok-tunnel-manager"
APPS_DIR="$SCRIPT_DIR/apps"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

# Health checks
is_kubernetes_healthy() {
    kubectl cluster-info >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1
}

is_app_healthy() {
    kubectl get pods -l app=node-app 2>/dev/null | grep -q "Running"
}

is_ngrok_healthy() {
    curl -sf --max-time 2 http://localhost:4040/api/tunnels >/dev/null 2>&1
}

get_ngrok_url() {
    curl -sf http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^"]*\.ngrok[^"]*' | head -1
}

# Dependency check
check_dependencies() {
    print_status "Checking dependencies"
    local deps=("kind" "kubectl" "ngrok" "docker")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            print_success "$dep"
        else
            print_error "$dep"
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# Start Kubernetes cluster
start_kubernetes() {
    print_status "Setting up Kubernetes cluster"
    cd "$KUBERNETES_DIR"
    
    if kind get clusters | grep -q "my-apps-cluster"; then
        print_success "Cluster already exists"
        return 0
    fi
    
    if ./setup-cluster.sh; then
        print_success "Cluster created successfully"
        return 0
    else
        print_error "Failed to create cluster"
        return 1
    fi
}

# Deploy application
deploy_application() {
    print_status "Deploying Vue.js application"
    cd "$KUBERNETES_DIR"
    
    # Check if manifest files exist
    if [ ! -f "deployment.yml" ] || [ ! -f "service.yml" ] || [ ! -f "ingress.yml" ]; then
        print_error "Missing Kubernetes manifest files"
        return 1
    fi
    
    kubectl apply -f deployment.yml
    kubectl apply -f service.yml
    
    # Handle ingress webhook issue
    print_status "Creating ingress"
    if kubectl apply -f ingress.yml 2>/dev/null; then
        print_success "Ingress created successfully"
    else
        print_warning "Ingress creation failed - fixing webhook..."
        kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
        sleep 2
        if kubectl apply -f ingress.yml; then
            print_success "Ingress created after webhook fix"
        else
            print_error "Failed to create ingress even after webhook fix"
            return 1
        fi
    fi
    
    # Wait for app
    print_status "Waiting for application to start"
    if kubectl wait --for=condition=ready pod -l app=node-app --timeout=120s 2>/dev/null; then
        print_success "Application is running"
        return 0
    else
        print_error "Application failed to start within timeout"
        return 1
    fi
}

# Start ngrok tunnel
start_ngrok() {
    print_status "Starting ngrok tunnel"
    cd "$NGROK_DIR"
    
    # Stop existing ngrok
    pkill -f ngrok 2>/dev/null || true
    sleep 2
    
    # Start ngrok
    print_status "Starting ngrok on port 8080"
    ngrok http 8080 > /tmp/ngrok.log 2>&1 &
    local ngrok_pid=$!
    echo $ngrok_pid > /tmp/ngrok.pid
    print_success "Ngrok started with PID: $ngrok_pid"
    
    # Wait for tunnel
    print_status "Waiting for tunnel to establish..."
    local max_attempts=15
    local attempt=1
    local public_url=""
    
    while [ $attempt -le $max_attempts ]; do
        if is_ngrok_healthy; then
            public_url=$(get_ngrok_url)
            if [ -n "$public_url" ]; then
                print_success "Ngrok tunnel ready"
                echo "🌐 Public URL: $public_url"
                return 0
            fi
        fi
        print_warning "Waiting for ngrok... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    print_error "Ngrok failed to start within timeout"
    return 1
}

# Smart deployment
deploy_full_stack() {
    print_status "Starting smart deployment"
    
    if ! check_dependencies; then
        exit 1
    fi
    
    # Kubernetes
    if is_kubernetes_healthy; then
        print_success "Kubernetes is already running"
    else
        if ! start_kubernetes; then
            exit 1
        fi
    fi
    
    # Application
    if is_app_healthy; then
        print_success "Vue.js app is already running"
    else
        if ! deploy_application; then
            exit 1
        fi
    fi
    
    # Ngrok
    if is_ngrok_healthy; then
        print_success "Ngrok is already running"
        local url=$(get_ngrok_url)
        if [ -n "$url" ]; then
            echo "🌐 Public URL: $url"
        fi
    else
        if ! start_ngrok; then
            print_warning "Ngrok failed to start, but deployment completed"
        fi
    fi
    
    print_success "Full stack deployment completed!"
}

# Show status
show_status() {
    print_status "System Status"
    echo "==================="
    echo "Kubernetes Cluster: $(is_kubernetes_healthy && echo '✅ Running' || echo '❌ Stopped')"
    echo "Vue.js App: $(is_app_healthy && echo '✅ Running' || echo '❌ Stopped')"
    echo "Ngrok Tunnel: $(is_ngrok_healthy && echo '✅ Running' || echo '❌ Stopped')"
    
    if is_ngrok_healthy; then
        local url=$(get_ngrok_url)
        if [ -n "$url" ]; then
            echo "Public URL: $url"
        fi
    fi
    echo "==================="
}

# Main execution
main() {
    case "${1:-deploy}" in
        deploy|start)
            deploy_full_stack
            ;;
        status)
            show_status
            ;;
        stop)
            echo "🛑 Use ./stop-all.sh to stop everything"
            ;;
        update)
            echo "🔄 Use ./update-app.sh to update application"
            ;;
        ngrok-only)
            start_ngrok
            ;;
        help|--help|-h)
            echo "Usage: $0 {deploy|status|stop|update|ngrok-only}"
            echo "  deploy     - Deploy full stack (default)"
            echo "  status     - Show current status"
            echo "  stop       - Stop everything (use stop-all.sh)"
            echo "  update     - Update application (use update-app.sh)"
            echo "  ngrok-only - Start only ngrok tunnel"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Usage: $0 {deploy|status|stop|update|ngrok-only|help}"
            exit 1
            ;;
    esac
}

main "$@"