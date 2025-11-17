#!/bin/bash

set -e

echo "🚀 Setting up Ngrok Tunnel Manager..."

# Make scripts executable
chmod +x ngrok-manager.sh
echo "✅ Made ngrok-manager.sh executable"

# Run the manager to setup token
echo "🔐 Starting token setup..."
./ngrok-manager.sh status

echo ""
echo "🎉 Ngrok setup complete!"
echo ""
echo "📋 Available commands:"
echo "   ./ngrok-manager.sh start node-app    # Start Node.js app tunnel"
echo "   ./ngrok-manager.sh start react-app   # Start React app tunnel" 
echo "   ./ngrok-manager.sh status            # Check active tunnels"
echo "   ./ngrok-manager.sh stop              # Stop all tunnels"
echo "   ./ngrok-manager.sh list              # List all available apps"
echo ""
echo "📁 Manager location: ~/ngrok-tunnel-manager/"
