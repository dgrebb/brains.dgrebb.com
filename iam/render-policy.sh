#!/usr/bin/env bash
# Renders brains-tofu-policy.json.tpl with this account's identifiers.
# Output goes to stdout and is gitignored if redirected into this directory,
# since the rendered policy embeds the account id, zone id, and distribution id.
#
# Ids come from pass via scripts/env.sh. Each falls back to discovery, so this
# still works before those entries exist — though the distribution id fallback
# needs local state, which a fresh clone will not have.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=../scripts/env.sh
source "${ROOT}/scripts/env.sh"

account_id="$(aws sts get-caller-identity --query Account --output text)"

zone_id="${BRAINS_ZONE_ID:-}"
if [[ -z "$zone_id" ]]; then
  zone_id="$(aws route53 list-hosted-zones-by-name --dns-name "${PARENT_ZONE:-dgrebb.com}." \
    --query 'HostedZones[0].Id' --output text | sed 's#/hostedzone/##')"
fi

distribution_id="${BRAINS_DISTRIBUTION_ID:-}"
if [[ -z "$distribution_id" ]]; then
  distribution_id="$(tofu output -raw cloudfront_distribution_id)"
fi

for pair in "account_id:${account_id}" "zone_id:${zone_id}" "distribution_id:${distribution_id}"; do
  if [[ -z "${pair#*:}" || "${pair#*:}" == "None" ]]; then
    echo "error: could not resolve ${pair%%:*}" >&2
    exit 1
  fi
done

sed \
  -e "s/__ACCOUNT_ID__/${account_id}/g" \
  -e "s/__ZONE_ID__/${zone_id}/g" \
  -e "s/__DISTRIBUTION_ID__/${distribution_id}/g" \
  iam/brains-tofu-policy.json.tpl
