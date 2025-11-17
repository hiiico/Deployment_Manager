# FROM node:latest
# WORKDIR /app
# COPY . .
# RUN npm install
# ENTRYPOINT ["npm", "run", "dev"]

FROM node:16-alpine

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies (including dev dependencies for build)
RUN npm install

# Copy source code
COPY . .

# Create dist directory and build the Vue.js app
RUN mkdir -p dist && npm run build

# Verify build output
RUN ls -la dist/

# Expose port (http-server runs on 8080 by default)
EXPOSE 8080

# Health check - wait for build to complete
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start the development server (serves from dist/)
ENTRYPOINT ["npm", "run", "dev"]