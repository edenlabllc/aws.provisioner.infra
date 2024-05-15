#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

# Clean project and stop cluster
rmk release destroy --selector scope=kodjin
# Needed for finished previously step
sleep 30
rmk release destroy --selector scope=deps
rmk cluster k3d stop
