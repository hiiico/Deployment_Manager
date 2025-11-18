#!/bin/bash
set -e

echo "🔄 Migrating Existing node-app to New Structure"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

migrate_node_app() {
    local app_name="node-app"
    local app_dir="$APPS_DIR/$app_name"
    
    print_status "Migrating $app_name..."
    
    # Create app directory
    mkdir -p "$app_dir"
    mkdir -p "$app_dir/kubernetes"
    
    # Move existing files if they exist in root
    if [ -f "server.js" ]; then
        mv server.js "$app_dir/" 2>/dev/null || true
    fi
    if [ -f "package.json" ]; then
        mv package.json "$app_dir/" 2>/dev/null || true
    fi
    if [ -f "Dockerfile" ]; then
        mv Dockerfile "$app_dir/" 2>/dev/null || true
    fi
    
    # Create app configuration
    cat > "$app_dir/app.conf" << EOF
APP_NAME="node-app"
INTERNAL_PORT="8080"
DOCKER_IMAGE="hiiico/node-app:latest"
HEALTH_CHECK="/"
VERSION="1.0"
EOF
    print_success "Created app.conf"
    
    # Ensure Dockerfile exists
    if [ ! -f "$app_dir/Dockerfile" ]; then
        cat > "$app_dir/Dockerfile" << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
EOF
        print_success "Created Dockerfile"
    fi
    
    # Generate Kubernetes manifests
    print_status "Generating Kubernetes manifests..."
    ./kubernetes/manage-app.sh generate "$app_name" 8080 30001
    
    print_success "Node-app migration completed"
}

update_existing_scripts() {
    print_status "Updating existing scripts for multi-app support..."
    
    # Rename update-app.sh to update-all.sh for consistency
    if [ -f "update-app.sh" ] && [ ! -f "update-all.sh" ]; then
        mv update-app.sh update-all.sh
        print_success "Renamed update-app.sh to update-all.sh"
    fi
    
    print_success "Scripts updated"
}

main() {
    echo
    migrate_node_app
    echo
    update_existing_scripts
    echo
    
    print_success "🎉 Migration completed!"
    echo
    echo "📋 Your node-app is now in the multi-app structure:"
    echo "   Location: apps/node-app/"
    echo "   Image: hiiico/node-app:latest"
    echo "   Port: 30001"
    echo
    echo "🚀 Test with: ./manage-app.sh start node-app"
}

main "$@"