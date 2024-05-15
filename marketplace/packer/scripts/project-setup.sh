#!/usr/bin/env bash

set -e

PROJECT_HOME_DIR="${HOME}/${PROJECT_NAME}"
cd "${PROJECT_HOME_DIR}"

function add_host_port() {
  if [[ -n "${1}" ]]; then
    PORTS=("${2}")
    COUNT_PORT=0
    for PORT in ${PORTS[*]}; do
      if [[ "${1}" == "${PORT}" ]]; then
        ((++COUNT_PORT))
      fi
    done

    if ((COUNT_PORT == 0)); then
      k3d node edit "${LOAD_BALANCER_NODE_NAME}" --port-add "${1}":"${3}"
    fi
  fi
}

# Run project
rmk config init
(rmk cluster k3d create 2> /dev/null) || echo "INFO: skip K3D cluster creating"

LOAD_BALANCER_NODE_NAME="$(k3d node list --output yaml | yq '.[] | select(.role == "loadbalancer") | .name')"
CURRENT_HOST_PORTS_0="$(k3d node list --output yaml | yq '.[] | select(.role == "loadbalancer") | .portMappings.80/tcp[].HostPort')"
CURRENT_HOST_PORTS_1="$(k3d node list --output yaml | yq '.[] | select(.role == "loadbalancer") | .portMappings.443/tcp[].HostPort')"

add_host_port "${HOST_PORT_0}" "${CURRENT_HOST_PORTS_0}" "80"
add_host_port "${HOST_PORT_1}" "${CURRENT_HOST_PORTS_1}" "443"

(rmk secret keys create 2> /dev/null) || echo "INFO: skip SOPS age keys creating"
rmk secret manager generate
rmk secret manager encrypt
rmk release sync
