set -x
GITHUB_PUSH_SECRET=$1
GITHUB_USER=$2
DOCKER_IMAGE_NAME=$3
if [ -n "$4" ]; then
    DOCKER_IMAGE_TAG="$4"
else
    exit 1
fi
GITHUB_REPOSITORY="nikinov/wazuh"
GITHUB_OWNER="nikinov"
IMAGE_ID=ghcr.io/${GITHUB_OWNER}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
IMAGE_ID=$(echo ${IMAGE_ID} | tr '[A-Z]' '[a-z]')

# Login to GHCR
echo ${GITHUB_PUSH_SECRET} | docker login https://ghcr.io -u $GITHUB_USER --password-stdin

# Try to pull image
if docker pull ${IMAGE_ID}; then
    echo "Successfully pulled ${IMAGE_ID}"
    docker image tag ${IMAGE_ID} ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
else
    echo "Image ${IMAGE_ID} not found. Continuing without error."
    # Exit with success code to prevent workflow failure
    exit 0
fi
