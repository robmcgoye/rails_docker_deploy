# Deployment Automation Script

This script automates the process of building, tagging, and deploying a Docker image to a remote server. It also sets up any necessary self-signed certificates for Traefik if specified. It allows specifying a custom Dockerfile, and other configuration options. This is meant to be used with rails 7.2 applications for docker file deployments.

## Requirements

### Prerequisites

1. **Local Requirements**:
   - **Docker**: Ensure Docker is installed and running on the local machine.
   - **`rsync`**: Used to copy files efficiently to the remote server.
   - **SSH Access**: Ensure SSH access to the remote server is set up and configured with appropriate permissions.
   - **Docker Hub Account**: A Docker Hub account is required for logging in and pushing/pulling images.

2. **Remote Server Requirements**:
   - **Docker**: The remote server must have Docker installed.
   - **OpenSSL**: Required if you need to generate self-signed certificates on the server.

3. **Configuration File**:
   - The script expects a configuration file named `config.conf` in the .deployment directory. This file should contain necessary environment variables for the deployment.

### Config File (`config.conf`)

Create a `config.conf` file with the following variables:

```bash
# config.conf

# Docker and image information
NAME=my_app          # Name of the Docker image
VERSION=1.0          # Version tag for the Docker image
REGUSER=mydockeruser # Docker Hub username

# Deployment server details
SERVER=myserver.com  # Server address or hostname
USER=myuser          # SSH user for the server

# SSL certificate setup
SELFSIGNED=true      # Set to 'true' to enable self-signed certificate creation

# postgres info
POSTGRES_USER=postgres_user          # postgres user name
POSTGRES_PASSWORD=postgres_password  # postgres password

# rails setup
HOST=hostname_or_ip_of_deployment_app  
PORT=rails_port_set_in_app
RAILS_MASTER_KEY=rails_master_key

# Optional Dockerfile
DOCKERFILE=Dockerfile.dev # Path to the Dockerfile to use (default: Dockerfile)
```
## Usage
**Basic Usage**
>./deploy_app.sh
