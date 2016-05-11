#!/bin/sh
docker build \
    --build-arg="BASEREPO=$BASEREPO" \
    --build-arg="EPELREPO=$EPELREPO" \
    -t vertigo/docker-proxy .
