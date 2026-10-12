#!/usr/bin/env bash
set -e

wget -O /tmp/create-ci.sh \
  https://raw.githubusercontent.com/a-yspv/my-scripts/main/proxmox/create-ci-interactive.sh
chmod +x /tmp/create-ci.sh
/tmp/create-ci.sh
