#!/bin/sh
set -e

TOKEN_FILE="/vault/token/root_token-vault_1"
until [ -f "$TOKEN_FILE" ]; do
  echo "Waiting for autounseal token from transit..."
  sleep 15
done

VAULT_TOKEN=$(cat "$TOKEN_FILE")
export VAULT_TOKEN

vault server -config=/vault/config/vault.hcl &
VAULT_PID=$!

echo "vault server started"

# Esperar a que responda
until curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null; do
  echo "Waiting for local Vault API..."
  sleep 2
done

# Solo inicializar si no lo está
if ! vault status >/dev/null 2>&1; then
  echo "Initializing cluster with Transit seal..."
  vault operator init -format json > /vault/data/init.json

  echo "--- ROOT TOKEN: $(jq -r '.root_token' /vault/data/init.json)"
fi

wait $VAULT_PID

