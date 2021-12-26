#!/bin/bash

BASE_DIR="$(dirname $0)"
REPO_PATH="${BASE_DIR}/.."
ARCH="${1}"
IMAGE="${2}"
VERSION="${3}"

[[ $ARCH ]] || ARCH="x86"

tag_and_push() {
  docker tag "comworkio/${IMAGE}:latest" "comworkio/${IMAGE}:${1}"
  docker push "comworkio/${IMAGE}:${1}"
}

cd "${REPO_PATH}" && git pull origin master || : 

COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose -f docker-compose-build.yml build "${IMAGE}-${ARCH}"

echo "${DOCKER_ACCESS_TOKEN}" | docker login --username "${DOCKER_USERNAME}" --password-stdin

if [[ $ARCH == "x86" ]]; then
  docker-compose -f docker-compose-build.yml push "${IMAGE}-${ARCH}"
  tag_and_push "latest"
  tag_and_push "${VERSION}"
  tag_and_push "${VERSION}-${CI_COMMIT_SHORT_SHA}"
fi

tag_and_push "latest-${ARCH}"
tag_and_push "${VERSION}-${ARCH}"
tag_and_push "${VERSION}-${ARCH}-${CI_COMMIT_SHORT_SHA}"
