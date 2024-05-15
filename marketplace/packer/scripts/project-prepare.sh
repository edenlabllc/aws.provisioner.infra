#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

# Install dependencies tools
curl -sL "https://edenlabllc-rmk-tools-infra.s3.eu-north-1.amazonaws.com/rmk/s3-installer" | bash -s -- "${RMK_VERSION}"

curl -sfL https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz > /tmp/k9s_Linux_amd64.tar.gz && \
  mkdir -p /tmp/k9s_Linux_amd64 && \
  tar -zxf /tmp/k9s_Linux_amd64.tar.gz -C /tmp/k9s_Linux_amd64 && \
  mv /tmp/k9s_Linux_amd64/k9s "${HOME}/.local/bin/k9s"

# Git init repository for project
git config --global "user.name" "github-actions"
git config --global "user.email" "github-actions@github.com"
git config --global init.defaultBranch "${PROJECT_ENVIRONMENT}"
git init
git remote add origin "git@github.com:edenlabllc/${PROJECT_NAME}.bootstrap.infra.git"
git add .
git commit -m "init commit"

# Init RMK config for project
rmk config init --progress-bar=false --cluster-provider=k3d --artifact-mode=online
rmk cluster k3d create
rmk cluster k3d delete
