#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

# Clean secrets
for FILE in ls etc/*/*/secrets/*.yaml; do
  rm -f "${FILE}"
done
