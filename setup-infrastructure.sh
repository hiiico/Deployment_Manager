#!/bin/bash

echo "🚀 Setting up Multi-App Infrastructure"
echo "======================================"

# Colors for pretty output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }

# Make all scripts executable
make_executable() {
    for file in *.sh; do
        if [[ -f "$file" ]]; then
            chmod +x "$file"
            print_success "Made executable: $file"
        fi
    done
}

setup_directories() {
    print_status "Creating directory structure"
    mkdir -p apps/ kubernetes/ ngrok-tunnel-manager/ logs/
    print_success "Directories created"
}

main() {
    setup_directories
    make_executable
    print_success "Infrastructure setup complete!"
}

main "$@"
