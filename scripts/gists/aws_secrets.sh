#!/usr/bin/env bash
#
# Pulls JumpServer secrets from AWS Secrets Manager and writes them into
# ${CONFIG_FILE} (config.txt), so they never have to be committed or typed by hand.
#
# The secret must be a JSON object. Only the keys listed in AWS_SECRET_KEYS are
# copied; empty or missing keys keep whatever config.txt already has.
#
# Settings (environment variable wins over config.txt):
#   AWS_SECRETS_ENABLED  true/false (default: true)
#   AWS_SECRET_NAME      secret id/ARN (default: prod/pam-server)
#   AWS_SECRET_REGION    region of the secret (default: us-east-1)
#
# Credentials come from the default AWS CLI chain (EC2 instance role, env vars,
# ~/.aws). Required IAM permission: secretsmanager:GetSecretValue on the secret
# (plus kms:Decrypt when the secret uses a customer managed KMS key).

AWS_SECRET_KEYS="BOOTSTRAP_TOKEN SECRET_KEY DB_HOST DB_USER DB_PASSWORD DB_NAME"

function is_aws_secrets_enabled() {
  local enabled
  enabled=$(get_config_or_env AWS_SECRETS_ENABLED "true")
  case "${enabled}" in
  1 | true | True | TRUE | yes | y) return 0 ;;
  *) return 1 ;;
  esac
}

# Writes KEY=VALUE into config.txt without passing the value through sed, so
# characters like "," "&" "/" or "|" can't break the substitution.
function set_config_literal() {
  local key=$1
  local value=$2
  local tmp_file="${CONFIG_FILE}.aws.$$"

  KEY="${key}" VALUE="${value}" awk '
    BEGIN { key = ENVIRON["KEY"]; value = ENVIRON["VALUE"]; done = 0 }
    $0 ~ "^[ \t]*" key "=" {
      if (!done) { print key "=" value; done = 1 }
      next
    }
    { print }
    END { if (!done) print key "=" value }
  ' "${CONFIG_FILE}" >"${tmp_file}" || {
    rm -f "${tmp_file}"
    return 1
  }

  chmod 600 "${tmp_file}" 2>/dev/null || true
  mv -f "${tmp_file}" "${CONFIG_FILE}"
}

# config.txt is read both by docker compose (.env, unquoted, with $VAR
# interpolation and " #" comments) and by get_config (splits on spaces and "=").
# Values with these characters would be silently altered, so refuse them.
function is_safe_config_value() {
  local value=$1
  case "${value}" in
  *[[:space:]]* | *\'* | *\"* | *\$* | *\`* | *\\* | *\#* | *=*) return 1 ;;
  esac
  return 0
}

function load_aws_secrets() {
  local secret_name region secret_json key value updated

  if ! is_aws_secrets_enabled; then
    return 0
  fi

  secret_name=$(get_config_or_env AWS_SECRET_NAME "prod/pam-server")
  region=$(get_config_or_env AWS_SECRET_REGION "us-east-1")

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_error "AWS Secrets Manager: config file not found: ${CONFIG_FILE}"
    return 1
  fi
  if ! command -v aws &>/dev/null; then
    log_error "AWS Secrets Manager: aws CLI not found. Install it or set AWS_SECRETS_ENABLED=false"
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    log_error "AWS Secrets Manager: jq not found. Install it or set AWS_SECRETS_ENABLED=false"
    return 1
  fi

  echo "AWS Secrets Manager: loading ${secret_name} (${region})"
  if ! secret_json=$(aws secretsmanager get-secret-value \
    --secret-id "${secret_name}" \
    --region "${region}" \
    --query SecretString \
    --output text); then
    log_error "AWS Secrets Manager: failed to read secret ${secret_name}"
    return 1
  fi

  if ! printf '%s' "${secret_json}" | jq -e 'type == "object"' &>/dev/null; then
    log_error "AWS Secrets Manager: secret ${secret_name} is not a JSON object"
    return 1
  fi

  updated=""
  for key in ${AWS_SECRET_KEYS}; do
    value=$(printf '%s' "${secret_json}" | jq -r --arg k "${key}" '.[$k] // empty | tostring')
    if [[ -z "${value}" ]]; then
      log_warn "AWS Secrets Manager: ${key} is empty or missing, keeping current config value"
      continue
    fi
    if ! is_safe_config_value "${value}"; then
      log_error "AWS Secrets Manager: ${key} contains a forbidden character (space, quote, \$, \`, \\, # or =)"
      return 1
    fi
    set_config_literal "${key}" "${value}" || {
      log_error "AWS Secrets Manager: failed to write ${key} to ${CONFIG_FILE}"
      return 1
    }
    updated="${updated} ${key}"
  done

  unset secret_json value
  chmod 600 "${CONFIG_FILE}" 2>/dev/null || true
  echo "AWS Secrets Manager: updated${updated:- nothing}"
}
