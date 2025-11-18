#!/bin/bash
set -e

echo "🏗️  Setting Up Multi-App Infrastructure"
echo "======================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

setup_directories() {
    print_status "Creating directory structure..."
    
    mkdir -p apps
    mkdir -p kubernetes/templates
    mkdir -p ngrok-tunnel-manager
    
    print_success "Directories created"
}

setup_templates() {
    print_status "Setting up Kubernetes templates..."
    
    # Check if source files exist before copying
    if [ ! -f "kubernetes/deployment.yml" ]; then
        print_error "Source file not found: kubernetes/deployment.yml"
        return 1
    fi
    
    # Create templates from your existing files
    cp kubernetes/deployment.yml kubernetes/templates/deployment-template.yml
    cp kubernetes/service.yml kubernetes/templates/service-template.yml
    cp kubernetes/ingress.yml kubernetes/templates/ingress-template.yml
    
    print_success "Kubernetes templates created"
}

setup_configs() {
    print_status "Creating configuration files..."
    
    # Port configuration
    cat > app-ports.conf << 'EOF'
# App Port Configuration
# Format: APP_NAME|INTERNAL_PORT|EXTERNAL_PORT|PROTOCOL
node-app|8080|30001|http
EOF

    # Apps registry
    cat > apps-registry.conf << 'EOF'
# Apps Registry
# Format: APP_NAME|STATUS|VERSION|HEALTH_CHECK_PATH
node-app|stopped|1.0|/
EOF

    print_success "Configuration files created"
}

make_scripts_executable() {
    print_status "Making scripts executable..."
    
    # Your existing scripts
    chmod +x start-all.sh stop-all.sh status-all.sh update-app.sh
    
    # New scripts
    chmod +x manage-app.sh migrate-existing.sh ports-config.sh
    chmod +x kubernetes/manage-app.sh kubernetes/setup-cluster.sh
    chmod +x ngrok-tunnel-manager/ngrok-manager.sh ngrok-tunnel-manager/setup-ngrok.sh
    
    print_success "Scripts made executable"
}

verify_setup() {
    print_status "Verifying setup..."
    
    local errors=0
    
    # Check directories
    for dir in "apps" "kubernetes/templates" "ngrok-tunnel-manager"; do
        if [ -d "$dir" ]; then
            print_success "Directory: $dir"
        else
            print_error "Missing: $dir"
            ((errors++))
        fi
    done
    
    # Check template files
    for file in "kubernetes/templates/deployment-template.yml" "kubernetes/templates/service-template.yml" "kubernetes/templates/ingress-template.yml"; do
        if [ -f "$file" ]; then
            print_success "Template: $file"
        else
            print_error "Missing: $file"
            ((errors++))
        fi
    done
    
    # Check config files
    for file in "app-ports.conf" "apps-registry.conf"; do
        if [ -f "$file" ]; then
            print_success "Config: $file"
        else
            print_error "Missing: $file"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        print_success "Infrastructure setup completed!"
        echo
        echo "📋 Next steps:"
        echo "  1. Run './migrate-existing.sh' to migrate your node-app"
        echo "  2. Run './manage-app.sh start node-app' to test"
        echo "  3. Run './ports-config.sh list' to verify ports"
    else
        print_error "Setup completed with $errors errors"
    fi
    
    return $errors
}

main() {
    echo
    setup_directories
    echo
    setup_templates
    echo
    setup_configs
    echo
    make_scripts_executable
    echo
    verify_setup
}

main "$@"