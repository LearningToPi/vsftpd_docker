#!/bin/bash -v


VERSION=$1
DISTRO='ubuntu'
TAG='latest'

docker pull docker.io/${DISTRO}:${TAG}
RETCODE=$?
if [ "${RETCODE}" -ne 0 ] ; then
    echo "Failed to pull ${DISTRO}:{$TAG}.  Return code ${RECODE}"
    quit $RETCODE
fi

IMAGE_DISTRO=`docker image inspect ${DISTRO}:${TAG} -f '{{index .Config.Labels "org.opencontainers.image.ref.name"}}'`
IMAGE_VERSION=`docker image inspect ${DISTRO}:${TAG} -f '{{index .Config.Labels "org.opencontainers.image.version"}}'`

docker build -f Containerfile . -t learningtopi/vsftpd:${VERSION} -t learningtopi/vsftpd:latest --build-arg VERSION="${IMAGE_DISTRO}-${IMAGE_VERSION}"
