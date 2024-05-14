#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

# Add environment variables for project user
cat .env.sh | sudo -S tee -a /etc/profile

kill -HUP "$PPID"
