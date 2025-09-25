#!/bin/sh
set -e

vault server -config=/vault/config/vault.hcl &
VAULT_PID=$!

VAULT_ADDR=http://127.0.0.1:8100
export VAULT_ADDR

# Esperar a que esté vivo
until curl -s $VAULT_ADDR/v1/sys/health >/dev/null; do
  echo "Waiting Vault..."
  sleep 2
done

if [ ! -f /vault/data/init_done ]; then
  INIT_RESPONSE=$(vault operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY"  > /vault/data/unseal_key-vault_1
  echo "$VAULT_TOKEN" > /vault/data/root_token-vault_1

  printf "\n%s" \
    "--- UNSEAL KEY: $UNSEAL_KEY" \
    "--- ROOT TOKEN: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "unsealing and logging in" \
    ""
  sleep 2 # Added for human readability

  vault operator unseal "$UNSEAL_KEY"
  vault login "$VAULT_TOKEN"

  printf "\n%s" \
    "enabling the transit secret engine and creating a key to auto-unseal vault cluster" \
    ""
  sleep 5 # Added for human readability

  vault secrets enable transit || true
  vault write -f transit/keys/unseal_key

  touch /vault/data/init_done
else
  echo "Already initialized, reusing stored credentials"

  UNSEAL_KEY=$(cat /vault/data/unseal_key-vault_1)
  VAULT_TOKEN=$(cat /vault/data/root_token-vault_1)

  vault operator unseal "$UNSEAL_KEY"
  vault login "$VAULT_TOKEN"
fi

# Esperar a que responda
until curl -s http://vaultA-1:8200/v1/sys/health >/dev/null; do
  sleep 2
done

# Salimos si el nodo 1 deja de existir
while curl -s http://vaultA-1:8200/v1/sys/health >/dev/null; do
  sleep 2
done

kill $VAULT_PID

