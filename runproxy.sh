#!/bin/sh
docker stop docker-proxy
docker rm docker-proxy
docker run --detach \
    --name docker-proxy \
    --env EMAIL=andre@vertigo.com.br \
    --env DOMAIN=vertigo.webhop.me \
    --env UPSTREAM=unix:/var/run/docker.sock \
    --publish 80:80 \
    --publish 443:443 \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume letsencrypt:/etc/letsencrypt \
    --volume letsencrypt-backups:/var/lib/letsencrypt \
    --volume dhparam-cache:/cache \
    vertigo/docker-proxy
