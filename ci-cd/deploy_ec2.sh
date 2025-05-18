#!/bin/bash

# Script to deploy updates to the Q Command Center server on EC2
# This would be called by your CI/CD pipeline

# Variables
SERVER_DIR="../server"
SSH_KEY="../infrastructure/q_key"

# Get the instance IP from Terraform output
cd ../infrastructure
INSTANCE_IP=$(terraform output -raw instance_ip)
cd ../ci-cd

echo "Deploying to EC2 instance at $INSTANCE_IP..."

# Build the Docker image locally
echo "Building Docker image..."
cd $SERVER_DIR
docker build -t q-command-center:latest .

# Save the Docker image to a tar file
echo "Saving Docker image..."
docker save q-command-center:latest > q-command-center.tar

# Copy the Docker image to the server
echo "Copying Docker image to server..."
scp -i $SSH_KEY q-command-center.tar ec2-user@$INSTANCE_IP:/home/ec2-user/app/

# SSH into the server and update the application
echo "Updating application on server..."
ssh -i $SSH_KEY ec2-user@$INSTANCE_IP << EOF
  cd /home/ec2-user/app
  # Load the Docker image
  sudo docker load < q-command-center.tar
  
  # Stop and remove the old container if it exists
  sudo docker stop q-command-center || true
  sudo docker rm q-command-center || true
  
  # Run the new container
  sudo docker run -d --name q-command-center -p 3000:3000 q-command-center:latest
  
  # Clean up
  rm q-command-center.tar
EOF

echo "Deployment completed successfully!"
