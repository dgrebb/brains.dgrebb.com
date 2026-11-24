#!/usr/bin/env bash
# Renders brains-tofu-policy.json.tpl with this account's identifiers.
# Output goes to stdout and is gitignored if redirected into this directory,
# since the rendered policy embeds the account id, zone id, and distribution id.
set -euo pipefail

cd "$(dirname "$0")"

account_id="$(aws sts get-caller-identity --query Account --output text)"
zone_id="$(aws route53 list-hosted-zones-by-name --dns-name "${PARENT_ZONE:-dgrebb.com}." \
  --query 'HostedZones[0].Id' --output text | sed 's#/hostedzone/##')"
distribution_id="$(cd .. && tofu output -raw cloudfront_distribution_id)"

sed \
  -e "s/__ACCOUNT_ID__/${account_id}/g" \
  -e "s/__ZONE_ID__/${zone_id}/g" \
  -e "s/__DISTRIBUTION_ID__/${distribution_id}/g" \
  brains-tofu-policy.json.tpl
