#!/usr/bin/env bash

set -e

# Install necessary dependencies
sudo -S yum update
sudo -S yum install -y git python3-pip docker mc
sudo -S service docker start
sudo -S usermod -a -G docker "${USER}"

mkdir -p "${HOME}/${PROJECT_NAME}"
mkdir -p "${HOME}/scripts"

kill -HUP "$PPID"
