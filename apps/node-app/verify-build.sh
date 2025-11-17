#!/bin/bash

echo "🔍 Verifying Vue.js Build"
echo "========================"

cd /home/mywebsites/apps/node-app

# Check if all required files exist
echo "📁 Checking project structure..."
[ -f "package.json" ] && echo "✅ package.json" || echo "❌ package.json missing"
[ -f "index.html" ] && echo "✅ index.html" || echo "❌ index.html missing"
[ -f "src/main.js" ] && echo "✅ src/main.js" || echo "❌ src/main.js missing"
[ -f "src/App.vue" ] && echo "✅ src/App.vue" || echo "❌ src/App.vue missing"
[ -f "src/components/Hello.vue" ] && echo "✅ src/components/Hello.vue" || echo "❌ Hello.vue missing"

# Test build process
echo ""
echo "🏗️  Testing build process..."
if docker run --rm -v $(pwd):/app node:16-alpine sh -c "cd /app && npm install && npm run build"; then
    echo "✅ Build successful"
    echo "📁 Build output:"
    ls -la dist/
else
    echo "❌ Build failed"
    exit 1
fi

echo ""
echo "🐳 Testing Docker build..."
docker build -t hiiico/node-app:test-build .

echo ""
echo "🎯 Next: Deploy to Kubernetes"
echo "cd /home/mywebsites/kubernetes && ./setup-cluster.sh"