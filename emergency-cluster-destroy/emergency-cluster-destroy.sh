#!/usr/bin/env bash

set -e

# Required inputs
export AWS_PROFILE="${1}"
export CF_TOKEN="${2}"

export AWS_ACCOUNT_ID=288509344804
export AWS_REGION=eu-north-1

export AWS_CONFIG_FILE="${HOME}/.aws/config_${AWS_PROFILE}"
export AWS_SHARED_CREDENTIALS_FILE="${HOME}/.aws/credentials_${AWS_PROFILE}"
export CLUSTER_NAME="${AWS_PROFILE}"

readonly AWS_NUKE_CONFIG_TMPL=aws-nuke.yaml.tmpl
readonly AWS_NUKE_CONFIG=aws-nuke.yaml

function delete_cf_records() {
  if [[ -z "${CF_TOKEN}" ]]; then
    >2& echo "Error: variable \${CF_TOKEN} set but empty"
    return 1
  fi

  local ZONE_ID="$(curl --silent --location --request GET \
  --url "https://api.cloudflare.com/client/v4/zones" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${CF_TOKEN}" | yq --input-format=json '.result[].id')"

  local DNS_RECORD_IDS=("$(curl --silent --location --url "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${CF_TOKEN}" | yq --input-format=json '.result[] | select(.name == "'"${CLUSTER_NAME}"'.*") | .id ')")

  if [[ -z "${DNS_RECORD_IDS[*]}" ]]; then
    >2& echo "Error: not found DNS records by zone ID: ${ZONE_ID}"
    return 1
  fi

  for ID in ${DNS_RECORD_IDS[*]}; do
    if [[ "${1}" == "--no-dry-run" ]]; then
      curl --silent --location --request DELETE \
       --url "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${ID}" \
       --header "Content-Type: application/json" \
       --header "Authorization: Bearer ${CF_TOKEN}" | yq '.'
    else
      echo "Cloudflare DNS record ID: ${ID} - would remove"
    fi
  done
}

# shellcheck disable=SC2016
YQ_TMPL_QUERY='.accounts.[env(AWS_ACCOUNT_ID)] = .accounts.["${AWS_ACCOUNT_ID}"] | del(.accounts.["${AWS_ACCOUNT_ID}"]) | (.. | select(tag == "!!str")) |= envsubst(ne)'
if (yq "${YQ_TMPL_QUERY}" "${AWS_NUKE_CONFIG_TMPL}" > "${AWS_NUKE_CONFIG}"); then
  delete_cf_records
  aws-nuke --config "${AWS_NUKE_CONFIG}" --profile "${AWS_PROFILE}" --force --force-sleep 3 | grep "would remove"
  read -re -p "Do you agree to the removal of objects found in AWS? [Yes]: " AGREE
  case "${AGREE}" in
  YES|Yes|yes|Y|y)
    delete_cf_records --no-dry-run
    aws-nuke --config "${AWS_NUKE_CONFIG}" --profile "${AWS_PROFILE}" --no-dry-run --force --force-sleep 10
    ;;
  esac
fi
