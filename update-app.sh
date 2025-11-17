#!/bin/bash
set -e

echo "🔄 Updating Vue.js Application"
echo "=============================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/apps/node-app"
KUBERNETES_DIR="$SCRIPT_DIR/kubernetes"

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "Application directory not found: $APP_DIR"
    exit 1
fi

# Build application
print_status "Building application..."
cd "$APP_DIR"

if [ -f "package.json" ]; then
    print_status "Installing dependencies..."
    if npm install; then
        print_success "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
    
    print_status "Building application..."
    if npm run build; then
        print_success "Application built successfully"
    else
        print_error "Build failed"
        exit 1
    fi
else
    print_error "package.json not found in $APP_DIR"
    exit 1
fi

# Update Kubernetes deployment
print_status "Updating Kubernetes deployment..."
cd "$KUBERNETES_DIR"

if kubectl get deployment node-app >/dev/null 2>&1; then
    if kubectl rollout restart deployment/node-app; then
        print_success "Deployment update triggered"
        
        print_status "Waiting for rollout to complete..."
        if kubectl rollout status deployment/node-app --timeout=180s; then
            print_success "Deployment updated successfully!"
            
            # Show updated pods
            echo
            kubectl get pods -l app=node-app
        else
            print_error "Deployment rollout failed"
            exit 1
        fi
    else
        print_error "Failed to restart deployment"
        exit 1
    fi
else
    print_error "Deployment 'node-app' not found in cluster"
    echo "You may need to deploy the application first using: ./start-all.sh"
    exit 1
fi

print_success "🎉 Application update completed!"