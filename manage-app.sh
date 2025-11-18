#!/bin/bash
set -e

echo "🎯 Application Manager"
echo "====================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
PORTS_FILE="$SCRIPT_DIR/app-ports.conf"
REGISTRY_FILE="$SCRIPT_DIR/apps-registry.conf"
KUBE_SCRIPT="$SCRIPT_DIR/kubernetes/manage-app.sh"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }

get_app_port() {
    local app_name=$1
    if [ -f "$PORTS_FILE" ]; then
        grep "^$app_name|" "$PORTS_FILE" 2>/dev/null | head -1
    fi
}

update_registry() {
    local app_name=$1
    local status=$2
    local version=${3:-1.0}
    
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo "# Apps Registry" > "$REGISTRY_FILE"
        echo "# Format: APP_NAME|STATUS|VERSION|HEALTH_CHECK_PATH" >> "$REGISTRY_FILE"
    fi
    
    if grep -q "^$app_name|" "$REGISTRY_FILE"; then
        grep -v "^$app_name|" "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"
        mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
    fi
    
    echo "$app_name|$status|$version|/" >> "$REGISTRY_FILE"
}

start_app() {
    local app_name=$1
    print_status "Starting: $app_name"
    
    if [ ! -d "$APPS_DIR/$app_name" ]; then
        print_error "App not found: $APPS_DIR/$app_name"
        return 1
    fi
    
    local port_config=$(get_app_port "$app_name")
    if [ -z "$port_config" ]; then
        print_error "No port config for: $app_name"
        return 1
    fi
    
    IFS='|' read -r app internal_port external_port protocol <<< "$port_config"
    
    # Generate manifests first
    print_status "Generating Kubernetes manifests..."
    if ! "$KUBE_SCRIPT" generate "$app_name" "$internal_port" "$external_port"; then
        print_error "Failed to generate manifests"
        return 1
    fi
    
    # Deploy to Kubernetes
    if "$KUBE_SCRIPT" deploy "$app_name"; then
        update_registry "$app_name" "running"
        print_success "Started $app_name"
        echo "🌐 Access: http://localhost:$external_port"
        return 0
    else
        update_registry "$app_name" "error"
        print_error "Failed to start $app_name"
        return 1
    fi
}

stop_app() {
    local app_name=$1
    print_status "Stopping: $app_name"
    
    if "$KUBE_SCRIPT" stop "$app_name"; then
        update_registry "$app_name" "stopped"
        print_success "Stopped $app_name"
    else
        print_error "Failed to stop $app_name"
        return 1
    fi
}

restart_app() {
    local app_name=$1
    print_status "Restarting: $app_name"
    stop_app "$app_name" && start_app "$app_name"
}

status_app() {
    local app_name=$1
    print_status "Status: $app_name"
    
    local registry_entry=$(grep "^$app_name|" "$REGISTRY_FILE" 2>/dev/null || true)
    if [ -n "$registry_entry" ]; then
        IFS='|' read -r app status version health_path <<< "$registry_entry"
        echo "Registry: $status (v$version)"
    else
        echo "Registry: Not registered"
    fi
    
    local port_config=$(get_app_port "$app_name")
    if [ -n "$port_config" ]; then
        IFS='|' read -r app internal external protocol <<< "$port_config"
        echo "Port: $external → $internal"
    fi
    
    echo "Kubernetes:"
    kubectl get pods -l app="$app_name" 2>/dev/null || echo "  No pods found"
}

list_apps() {
    print_status "Applications:"
    echo
    
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo "No apps registered"
        return
    fi
    
    printf "%-20s %-10s %-10s %-15s\n" "APP" "STATUS" "VERSION" "PORT"
    echo "--------------------------------------------------------"
    
    while IFS='|' read -r app status version health_path; do
        [[ "$app" =~ ^#.* ]] && continue
        [[ -z "$app" ]] && continue
        
        local port_config=$(get_app_port "$app")
        local port=""
        if [ -n "$port_config" ]; then
            IFS='|' read -r app_name internal external protocol <<< "$port_config"
            port="$external"
        fi
        
        printf "%-20s %-10s %-10s %-15s\n" "$app" "$status" "$version" "${port:-N/A}"
    done < "$REGISTRY_FILE"
}

main() {
    case "${1:-list}" in
        start)
            [ -z "$2" ] && { echo "Usage: $0 start APP"; exit 1; }
            start_app "$2"
            ;;
        stop)
            [ -z "$2" ] && { echo "Usage: $0 stop APP"; exit 1; }
            stop_app "$2"
            ;;
        restart)
            [ -z "$2" ] && { echo "Usage: $0 restart APP"; exit 1; }
            restart_app "$2"
            ;;
        status)
            if [ -z "$2" ]; then
                list_apps
            else
                status_app "$2"
            fi
            ;;
        list)
            list_apps
            ;;
        help|--help|-h)
            echo "Usage: $0 {start|stop|restart|status|list} [APP]"
            echo "  start APP    - Start application"
            echo "  stop APP     - Stop application"
            echo "  restart APP  - Restart application"
            echo "  status [APP] - Show status (all or specific)"
            echo "  list         - List all applications"
            ;;
        *)
            print_error "Unknown: $1"
            echo "Usage: $0 {start|stop|restart|status|list|help}"
            exit 1
            ;;
    esac
}

main "$@"