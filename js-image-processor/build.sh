#!/bin/bash
# This script builds the Lambda package inside a Docker container and saves it to the Desktop.

set -e

IMAGE_NAME="image-opt-builder"
CONTAINER_NAME="image-opt-artifacts"

echo "--> Building the Docker image..."
docker build -t $IMAGE_NAME .

echo "--> Creating a temporary container to copy files from..."
docker create --name $CONTAINER_NAME $IMAGE_NAME

echo "--> Cleaning up old build artifacts..."
rm -rf ./build
mkdir -p ./build

echo "--> Copying correctly built node_modules and JS files from the container..."
# Copy all built artifacts from the container's /app directory
docker cp $CONTAINER_NAME:/app/. ./build/

echo "--> Removing temporary container..."
docker rm $CONTAINER_NAME

echo "--> Creating final deployment package on your Desktop..."
# Go into the build directory and zip its contents directly to the Desktop
cd ./build
zip -r ~/Desktop/deployment-package.zip .
cd ..
rm -rf ./build

echo "✅ Build complete! 'deployment-package.zip' is on your Desktop and ready for deployment."