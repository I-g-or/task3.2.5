#!/bin/bash

REPO_NAME="study/task3.2.5"
REGION="il-central-1"
APP_NAME="ghostfolio"
COMPOSE_FILE="docker-compose.yml"


# Get the latest tag from ECR (excluding latest)
echo "Checking ECR image version..."
log "Checking ECR image version..."
ECR_VERSION=$(aws ecr describe-images \
    --repository-name "$REPO_NAME" \
    --region "$REGION" \
    --query 'imageDetails[].imageTags[]' \
    --output text | tr '\t' '\n' | grep -E '^v?[0-9]+\.[0-9]+' | sort -V | tail -n 1)

# Get the running image
echo "Checking local version..."
log "Checking local version..."
RUNNING_IMAGE=$(docker compose -f "$COMPOSE_FILE" images -q "$APP_NAME" | xargs docker inspect --format '{{.Config.Image}}' 2>/dev/null)
RUNNING_VERSION="${RUNNING_IMAGE##*:}"

echo "ECR image: $ECR_VERSION"
echo "Local runnning image: $RUNNING_VERSION"

log "ECR image: $ECR_VERSION"
log "Local runnning image: $RUNNING_VERSION"

# Comparison of versions
LATEST_VERSION=$(printf "$ECR_VERSION\n$RUNNING_VERSION" | sort -V | tail -n 1)

if [ "$LATEST_VERSION" == "$ECR_VERSION" ] && [ "$LATEST_VERSION" != "$RUNNING_VERSION" ]; then
    echo "New version found! Starting the update to $ECR_VERSION..."
    # 1. Меняем тег в docker-compose.yml
    # Ищем строку с образом для конкретного сервиса и меняем всё после двоеточия
    sed -i "/image:.*$REPO_NAME/s/:.*$/:$ECR_VERSION/" "$COMPOSE_FILE"

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

