#!/bin/bash

# This script will help you manually set up the Lightsail instance
# since we're having issues with SSH access

# 1. Go to the AWS Lightsail console: https://lightsail.aws.amazon.com/
# 2. Select the q-server instance
# 3. Click on the "Connect" tab
# 4. Use the browser-based SSH client to connect to the instance
# 5. Run the following commands:

# Create app directory
mkdir -p ~/app

# Install Docker and Nginx if not already installed
sudo yum update -y
sudo yum install -y docker nginx
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable nginx
sudo systemctl start nginx

# Configure Nginx as reverse proxy
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << 'EOT'
server {
    listen 80;
    server_name q.condu.it;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOT

# Restart Nginx to apply changes
sudo systemctl restart nginx

# Create a simple test server
mkdir -p ~/app/server
cat > ~/app/server/server.js << 'EOT'
const http = require('http');
const port = 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', message: 'Amazon Q Command Center API is running' }));
  } else if (req.url === '/api/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      name: 'Amazon Q Command Center',
      version: '1.0.0',
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOT

# Run the server using Docker
cd ~/app
cat > Dockerfile << 'EOT'
FROM node:18-alpine
WORKDIR /app
COPY server/ .
EXPOSE 3000
CMD ["node", "server.js"]
EOT

# Build and run the Docker container
sudo docker build -t q-command-center:latest .
sudo docker run -d --name q-command-center -p 3000:3000 q-command-center:latest

echo "Setup complete! The API should now be accessible at http://q.condu.it/health"
