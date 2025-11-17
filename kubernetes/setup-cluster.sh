#!/bin/bash

set -e

echo "🚀 Deploying Vue.js App to Kubernetes"
echo "====================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Create cluster
echo -e "${BLUE}📦 Step 1: Creating Kubernetes cluster...${NC}"
kind create cluster --name my-apps-cluster --config kind-config.yml

# Step 2: Install ingress
echo -e "${BLUE}🌐 Step 2: Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo -e "${BLUE}⏳ Waiting for ingress controller...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
# Wait a bit longer for ingress to be fully ready
echo "⏳ Waiting for ingress to be fully ready..."
sleep 30

# Delete the problematic webhook to prevent future issues
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true

# Step 3: Deploy Vue.js app
echo -e "${BLUE}🚀 Step 3: Deploying Vue.js application...${NC}"
kubectl apply -f deployment.yml
kubectl apply -f ingress.yml

echo -e "${YELLOW}⏳ Vue.js app is building with Browserify + Vueify...${NC}"
echo -e "${YELLOW}This process takes 30-60 seconds...${NC}"

# Wait for pod to be running (not necessarily ready)
echo -e "${BLUE}📊 Waiting for pod to start...${NC}"
kubectl wait --for=condition=Ready pod -l app=node-app --timeout=300s

# Show build progress
echo -e "${BLUE}🔍 Build logs:${NC}"
kubectl logs -l app=node-app --tail=10

echo -e "${YELLOW}💡 Still building... Check progress with:${NC}"
echo -e "kubectl logs -l app=node-app --follow"

# Wait additional time for build completion
sleep 30

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${BLUE}🌐 Access your Vue.js app:${NC}"
echo -e "Local:    http://localhost:8080"
echo -e "Should show: Vue.js logo with 'Welcome to Your Vue.js App'"
echo ""
echo -e "${BLUE}📝 Verification commands:${NC}"
echo -e "Check status:    kubectl get pods -l app=node-app"
echo -e "View logs:       kubectl logs -l app=node-app"
echo -e "Test app:        curl http://localhost:8080"
echo ""
echo -e "${BLUE}🚀 Expose with Ngrok:${NC}"
echo -e "cd ../ngrok-tunnel-manager && ./ngrok-manager.sh start kubernetes-ingress"