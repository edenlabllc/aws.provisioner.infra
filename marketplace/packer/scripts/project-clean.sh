#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

# Clean project and stop cluster
rmk release destroy -l scope=kodjin
sleep 30
rmk release destroy -l scope=deps
rmk cluster k3d stop
