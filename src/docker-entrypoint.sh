#!/bin/sh

# should test for docker.sock
# and get GID from there

usermod -a -G $DOCKERGID nginx
UPSTREAM=$(sed 's/[\/\.]/\\&/g' <<<"$UPSTREAM")
echo "UPSTREAM(sed-friendly)=$UPSTREAM"

# calls "parent" entrypoint
exec /entrypoint.sh
