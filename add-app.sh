#!/bin/bash

echo "➕ Adding New Application"
echo "========================"

# Usage: ./add-app.sh <app-name> <docker-image> <port> [type]

APP_NAME=$1
DOCKER_IMAGE=$2
PORT=$3
TYPE=${4:-kubernetes}

echo "App Name: $APP_NAME"
echo "Docker Image: $DOCKER_IMAGE" 
echo "Port: $PORT"
echo "Type: $TYPE"

# Create app directory
mkdir -p "apps/$APP_NAME"
echo "✅ Created app directory"

# Update registry
echo "📝 Updating app registry..."
# [Registry update logic here]

echo "🎉 App '$APP_NAME' added successfully!"
