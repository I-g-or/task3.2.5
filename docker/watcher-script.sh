#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="il-central-1"
AWS_REPO_NAME="study/ghostfolio"
APP_NAME="ghostfolio"
COMPOSE_FILE="docker-compose.yml"

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
echo "ECR_VERSION=$ECR_VERSION" >> /etc/environment
cd /home/ec2-user/task3-2-5/docker

# Get the running image
echo "Checking local version..."
RUNNING_IMAGE=$(docker compose -f "$COMPOSE_FILE" images -q "$APP_NAME" | xargs docker inspect --format '{{.Config.Image}}' 2>/dev/null)
RUNNING_VERSION="${RUNNING_IMAGE##*:}"

echo "ECR image: $ECR_VERSION"
echo "Local runnning image: $RUNNING_VERSION"

# Comparison of versions
LATEST_VERSION=$(printf "$ECR_VERSION\n$RUNNING_VERSION" | sort -V | tail -n 1)

if [ "$LATEST_VERSION" == "$ECR_VERSION" ] && [ "$LATEST_VERSION" != "$RUNNING_VERSION" ]; then
    echo "New version found! Starting the update to $ECR_VERSION..."
    APP_VERSION=$ECR_VERSION
    echo "APP_VERSION=$APP_VERSION" >> /etc/environment

    echo "Download new image..."
    docker compose -f "$COMPOSE_FILE" pull "$APP_NAME"

    echo "Rebooting Docker Compose..."
    docker compose -f "$COMPOSE_FILE" up -d "$APP_NAME"

    echo "Deleting old images..."
    docker image prune -f

    echo "The update was completed successfully!"
    exit 0
else
    echo "The version is current, no update required"
    exit 0
fi
