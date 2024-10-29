#!/bin/bash

# Load configuration file
CONFIG_FILE=".deployment/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file ($CONFIG_FILE) not found."
  exit 1
fi

# Read values from config file
source "$CONFIG_FILE"

# Check if DOCKERFILE is set; if not, default to 'Dockerfile'
DOCKERFILE=${DOCKERFILE:-Dockerfile}
# Check if the specified Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile '$DOCKERFILE' not found."
  exit 1
fi

# Check if ~/.docker/config.json exists locally
if [ ! -f "$HOME/.docker/config.json" ]; then
  # Prompt for Docker Hub password if config.json does not exist locally
  echo "Local Docker config not found. Please log in to Docker Hub."
  read -sp "Docker Hub password: " DOCKER_PASSWORD
  echo

  # Login to Docker Hub locally
  echo "$DOCKER_PASSWORD" | docker login -u "$REGUSER" --password-stdin
  if [ $? -ne 0 ]; then
    echo "Docker login failed."
    exit 1
  fi
fi

# Build the Docker image
echo "docker build -t $NAME ."
docker build -f "$DOCKERFILE" -t "$NAME" .

# Tag the Docker image
echo "docker tag $NAME $REGUSER/$NAME:$VERSION"
docker tag "$NAME" "$REGUSER/$NAME:$VERSION"

# Optional: push the Docker image
echo "docker push $REGUSER/$NAME:$VERSION"
docker push "$REGUSER/$NAME:$VERSION"

echo "Docker image $REGUSER/$NAME:$VERSION built and tagged successfully."

# SSH to the server to ensure Docker and OpenSSL are installed and Docker is logged in
echo "Checking Docker, OpenSSL, and Docker Hub login on $SERVER..."
ssh "$USER@$SERVER" << EOF
  # Check for Docker and OpenSSL installation
  if ! command -v docker &> /dev/null; then
    echo "Docker is not installed on $SERVER. Please install Docker and try again."
    exit 1
  fi
  if ! command -v openssl &> /dev/null; then
    echo "OpenSSL is not installed on $SERVER. Please install OpenSSL and try again."
    exit 1
  fi

  # Check for Docker Hub login
  if [ ! -f "\$HOME/.docker/config.json" ]; then
    echo "Docker config not found on $SERVER. Logging into Docker Hub."
    read -sp "Docker Hub password: " DOCKER_PASSWORD
    echo
    echo "\$DOCKER_PASSWORD" | docker login -u "$REGUSER" --password-stdin
    if [ \$? -ne 0 ]; then
      echo "Docker login on $SERVER failed."
      exit 1
    fi
  fi
EOF

# Ensure the destination directory exists on the remote server
ssh "$USER@$SERVER" "mkdir -p ~/$NAME"

sed -e "s/{{NAME}}/$NAME/g" \
    -e "s/{{VERSION}}/$VERSION/g" \
    -e "s/{{REGUSER}}/$REGUSER/g" \
    -e "s/{{POSTGRES_USER}}/$POSTGRES_USER/g" \
    -e "s/{{POSTGRES_PASS}}/$POSTGRES_PASS/g" \
    -e "s/{{RAILS_MASTER_KEY}}/$RAILS_MASTER_KEY/g" \
    -e "s/{{HOST}}/$HOST/g" \
    -e "s/{{PORT}}/$PORT/g" \
    .deployment/docker-compose.yml > .deployment/docker-compose.temp.yml

# Use rsync to copy docker-compose.yml to the remote server
echo "Syncing docker-compose.yml to $USER@$SERVER:~/$NAME/"
rsync -avz .deployment/docker-compose.temp.yml "$USER@$SERVER:~/$NAME/"
rm .deployment/docker-compose.temp.yml

# Copy traefik_dynamic.yml if $SELFSIGNED is true
if [ "$SELFSIGNED" = true ]; then
  echo "SELFSIGNED is true, copying traefik_dynamic.yml to $USER@$SERVER:~/$NAME/"
  rsync -avz .deployment/traefik_dynamic.yml "$USER@$SERVER:~/$NAME/"
fi

# SSH to the server to check service status, manage certificates, and run Docker Compose commands
ssh "$USER@$SERVER" << EOF
  cd ~/$NAME

  # Check if the service is already running and stop it if it is
  if docker compose ls | grep -q "$NAME"; then
    echo "$NAME is currently running. Stopping service..."
    docker compose down
  fi

  # Create traefik_certs directory if SELFSIGNED is true
  if [ "$SELFSIGNED" = true ]; then
    mkdir -p traefik_certs

    # Check for self-signed certificates and generate if missing
    if [ ! -f traefik_certs/selfsigned.key ] || [ ! -f traefik_certs/selfsigned.crt ]; then
      echo "Generating self-signed certificate..."
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout traefik_certs/selfsigned.key \
        -out traefik_certs/selfsigned.crt \
        -subj "/CN=localhost"
    else
      echo "Self-signed certificates already exist."
    fi
  fi

  # Run Docker Compose commands
  echo "Pulling latest images with docker compose pull..."
  docker compose pull

  echo "Starting services with docker compose up -d..."
  docker compose up -d
EOF

echo "Script completed successfully."
