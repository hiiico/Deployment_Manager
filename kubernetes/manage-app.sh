#!/bin/bash
set -e

echo "☸️  Kubernetes App Manager"
echo "========================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_DIR="$SCRIPT_DIR"
TEMPLATES_DIR="$KUBE_DIR/templates"
# Go up one level from kubernetes/ to root, then to apps/
APPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/apps"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

generate_manifests() {
    local app_name=$1
    local internal_port=$2
    local external_port=$3
    
    print_status "Generating manifests: $app_name"
    
    local app_dir="$APPS_DIR/$app_name"
    local kube_dir="$app_dir/kubernetes"
    
    # Check if app directory exists
    if [ ! -d "$app_dir" ]; then
        print_error "App directory not found: $app_dir"
        return 1
    fi
    
    mkdir -p "$kube_dir"
    
    # Read app config
    if [ -f "$app_dir/app.conf" ]; then
        source "$app_dir/app.conf"
    else
        print_error "app.conf not found in $app_dir"
        return 1
    fi
    
    # Check if templates exist
    if [ ! -f "$TEMPLATES_DIR/deployment-template.yml" ]; then
        print_error "Template not found: $TEMPLATES_DIR/deployment-template.yml"
        return 1
    fi
    
    # Generate deployment from template
    sed \
        -e "s/name: node-app/name: $app_name/g" \
        -e "s/app: node-app/app: $app_name/g" \
        -e "s|image: hiiico/node-app:latest|image: $DOCKER_IMAGE|g" \
        -e "s/containerPort: 8080/containerPort: $internal_port/g" \
        -e "s/port: 8080/port: $internal_port/g" \
        "$TEMPLATES_DIR/deployment-template.yml" > "$kube_dir/deployment.yml"
    
    # Generate service
    sed \
        -e "s/name: node-app-service/name: $app_name-service/g" \
        -e "s/app: node-app/app: $app_name/g" \
        -e "s/port: 80/port: $external_port/g" \
        -e "s/targetPort: 8080/targetPort: $internal_port/g" \
        "$TEMPLATES_DIR/service-template.yml" > "$kube_dir/service.yml"
    
    # Generate ingress
    sed \
        -e "s/name: main-ingress/name: $app_name-ingress/g" \
        -e "s/name: node-app-service/name: $app_name-service/g" \
        -e "s/number: 80/number: $external_port/g" \
        "$TEMPLATES_DIR/ingress-template.yml" > "$kube_dir/ingress.yml"
    
    print_success "Manifests generated: $kube_dir/"
}

deploy_app() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    local kube_dir="$app_dir/kubernetes"
    
    print_status "Deploying: $app_name"
    
    if [ ! -f "$kube_dir/deployment.yml" ]; then
        print_error "Deployment not found: $kube_dir/deployment.yml"
        print_error "Run 'generate' first or check app directory"
        return 1
    fi
    
    # Apply manifests
    kubectl apply -f "$kube_dir/deployment.yml"
    kubectl apply -f "$kube_dir/service.yml"
    
    # Handle ingress with retry
    if kubectl apply -f "$kube_dir/ingress.yml" 2>/dev/null; then
        print_success "Ingress created"
    else
        print_warning "Ingress retry..."
        kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
        sleep 2
        kubectl apply -f "$kube_dir/ingress.yml"
    fi
    
    # Wait for deployment
    print_status "Waiting for pods..."
    if kubectl wait --for=condition=ready pod -l app="$app_name" --timeout=180s 2>/dev/null; then
        print_success "Deployment ready"
    else
        print_error "Deployment timeout"
        return 1
    fi
}

stop_app() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    local kube_dir="$app_dir/kubernetes"
    
    print_status "Stopping: $app_name"
    
    kubectl delete -f "$kube_dir/ingress.yml" --ignore-not-found=true
    kubectl delete -f "$kube_dir/service.yml" --ignore-not-found=true
    kubectl delete -f "$kube_dir/deployment.yml" --ignore-not-found=true
    kubectl delete pods -l app="$app_name" --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
    
    print_success "Stopped: $app_name"
}

main() {
    case "${1:-help}" in
        generate)
            [ -z "$2" ] && { echo "Usage: $0 generate APP INTERNAL_PORT EXTERNAL_PORT"; exit 1; }
            generate_manifests "$2" "$3" "$4"
            ;;
        deploy)
            [ -z "$2" ] && { echo "Usage: $0 deploy APP"; exit 1; }
            deploy_app "$2"
            ;;
        stop)
            [ -z "$2" ] && { echo "Usage: $0 stop APP"; exit 1; }
            stop_app "$2"
            ;;
        help|--help|-h)
            echo "Usage: $0 {generate|deploy|stop}"
            echo "  generate - Generate K8s manifests"
            echo "  deploy   - Deploy app to K8s"
            echo "  stop     - Stop app in K8s"
            ;;
        *)
            print_error "Unknown: $1"
            echo "Usage: $0 {generate|deploy|stop|help}"
            exit 1
            ;;
    esac
}

main "$@"