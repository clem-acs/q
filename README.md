# Amazon Q Command Center

A simple command center for Amazon Q with a Lightsail instance running in Oregon, featuring a reverse proxy and a simple API that can be updated via CI/CD.

## Project Structure

```
q/
├── infrastructure/    # Terraform files for AWS infrastructure
├── server/           # Node.js API server code
├── ci-cd/            # CI/CD deployment scripts
└── .github/          # GitHub Actions workflows
```

## Setup Instructions

### 1. Deploy Infrastructure

```bash
cd infrastructure
terraform init
terraform apply
```

This will:
- Create a Lightsail instance in Oregon (us-west-2)
- Set up a static IP
- Configure the DNS record for q.condu.it
- Install and configure Nginx as a reverse proxy

### 2. Deploy the API Server

Initial deployment:

```bash
cd ci-cd
chmod +x deploy.sh
./deploy.sh
```

Subsequent deployments will happen automatically via GitHub Actions when you push to the main branch.

### 3. Access the API

Once deployed, you can access the API at:

- http://q.condu.it/health - Health check endpoint
- http://q.condu.it/api/info - Example API endpoint

## CI/CD Pipeline

The project uses GitHub Actions for CI/CD:

1. When code is pushed to the main branch, the workflow is triggered
2. It builds the Docker image
3. Deploys it to the Lightsail instance
4. Updates the running container

## Customization

- Modify `server/server.js` to add new API endpoints
- Update `infrastructure/main.tf` to change infrastructure settings
- Adjust `ci-cd/deploy.sh` for custom deployment steps
