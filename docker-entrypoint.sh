#!/usr/bin/env bash
# Windows bind mounts don't preserve unix perms and are mounted read-only,
# so ssh/ansible reject the key as "too open". Copy the keys into a normal
# (writable) directory inside the container and fix the perms there instead.
set -e

if [ -d "$HOME/.ssh-host" ]; then
  mkdir -p "$HOME/.ssh"
  cp -f "$HOME"/.ssh-host/* "$HOME/.ssh/" 2>/dev/null || true
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f ! -name '*.pub' -exec chmod 600 {} \;
  find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} \;
fi

exec "$@"
