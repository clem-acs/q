#!/bin/bash

# Script to deploy updates to the Q Command Center server
# This would be called by your CI/CD pipeline

# Variables
LIGHTSAIL_INSTANCE="q-server"
REGION="us-west-2"
SERVER_DIR="../server"
REMOTE_USER="ec2-user"
REMOTE_DIR="/home/ec2-user/app"

# Get the instance IP
INSTANCE_IP=$(aws lightsail get-instance --instance-name $LIGHTSAIL_INSTANCE --region $REGION --query 'instance.publicIpAddress' --output text)

echo "Deploying to $LIGHTSAIL_INSTANCE at $INSTANCE_IP..."

# Build the Docker image locally
echo "Building Docker image..."
cd $SERVER_DIR
docker build -t q-command-center:latest .

# Save the Docker image to a tar file
echo "Saving Docker image..."
docker save q-command-center:latest > q-command-center.tar

# Copy the Docker image to the server
echo "Copying Docker image to server..."
scp q-command-center.tar $REMOTE_USER@$INSTANCE_IP:$REMOTE_DIR/

# SSH into the server and update the application
echo "Updating application on server..."
ssh $REMOTE_USER@$INSTANCE_IP << EOF
  cd $REMOTE_DIR
  # Load the Docker image
  docker load < q-command-center.tar
  
  # Stop and remove the old container if it exists
  docker stop q-command-center || true
  docker rm q-command-center || true
  
  # Run the new container
  docker run -d --name q-command-center -p 3000:3000 q-command-center:latest
  
  # Clean up
  rm q-command-center.tar
EOF

echo "Deployment completed successfully!"
