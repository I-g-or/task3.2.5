#!/bin/bash

# Load global environment variables
. /etc/environment

# Required variables
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
AWS_REGION="${AWS_REGION}"
AWS_REPO_NAME="${AWS_REPO_NAME}"
RUNNING_IMAGE="0.0.6"


# AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# AWS_REGION="il-central-1"
# AWS_REPO_NAME="study/ghostfolio"
# APP_NAME="ghostfolio"
# COMPOSE_FILE="docker-compose.yml"

# Amazon ECR login
aws ecr get-login-password --region "$AWS_REGION" \
| docker login \
  --username AWS \
  --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Get the latest tag from ECR (excluding latest)
echo "Checking ECR image version..."
ECR_VERSION=$(aws ecr describe-images \
    --repository-name "$AWS_REPO_NAME" \
    --region "$AWS_REGION" \
    --query 'imageDetails[].imageTags[]' \
    --output text | tr '\t' '\n' | grep -E '^v?[0-9]+\.[0-9]+' | sort -V | tail -n 1)
sudo sed -i "s/^ECR_VERSION=.*/ECR_VERSION=${ECR_VERSION}/" /etc/environment

# Get the running image
cd /home/ec2-user/task3-2-5/docker
echo "Checking local version..."
CONTAINER_ID=$(sudo docker compose -f docker-compose.yml ps -q ghostfolio)
RUNNING_IMAGE=$(sudo docker inspect --format '{{.Config.Image}}' "$CONTAINER_ID")
RUNNING_VERSION="${RUNNING_IMAGE##*:}"

echo "ECR image: $ECR_VERSION"
echo "Local runnning image: $RUNNING_VERSION"

# Compare versions
LATEST_VERSION=$(printf "$ECR_VERSION\n$RUNNING_VERSION" | sort -V | tail -n 1)

if [ "$LATEST_VERSION" == "$ECR_VERSION" ] && [ "$LATEST_VERSION" != "$RUNNING_VERSION" ]; then
    echo "New version found! Starting the update to $ECR_VERSION..."
    APP_VERSION=$ECR_VERSION
    sudo sed -i "s/^APP_VERSION=.*/APP_VERSION=${APP_VERSION}/" /etc/environment
    . /etc/environment

    echo "Download new image..."
    sudo docker compose -f docker-compose.yml pull ghostfolio

    echo "Rebooting Docker Compose..."
    sudo docker compose -f docker-compose.yml up -d ghostfolio

    echo "The update was completed successfully!"
    exit 0
else
    echo "The version is current, no update required"
    exit 0
fi
