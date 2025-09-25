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

wait_for_vault_restart() {
  until [ -f /vault/shared/cluster_a_init_ready ] && \
        [ -f /vault/shared/cluster_b_init_ready ] && \
        [ -f /vault/shared/cluster_c_init_ready ] && \
        [ -f /vault/shared/cluster_d_init_ready ]; do
    echo "Waiting for initialization files to exist..."
    sleep 2
  done

  echo "All required files exist. Exiting."
  exit 0
}

vault_dr_enable_with_cluster_c() {
  export VAULT_TOKEN=$1

  echo --- DR[1] Enable DR replication on the secondary cluster.

  until [ -f "/vault/shared/cluster_c_wrapping_token_ready" ]; do
    echo "Waiting for cluster_c_wrapping_token_ready"
    sleep 15
  done

  WRAPPING_TOKEN=$(cat /vault/shared/cluster_c_wrapping_token)

  vault write sys/replication/dr/secondary/enable token="$WRAPPING_TOKEN"

  unset VAULT_TOKEN
}

vault_init() {
  echo "Initializing cluster with Transit seal..."
  vault operator init -format json > /vault/data/init.json

  # limpiamos el token para el unseal
  unset VAULT_TOKEN
}

# Solo inicializar si no lo está
# Este paso solo se ejecuta la primera vez que se levanta el cluster
if [ ! -f "/vault/shared/cluster_d_init_ready" ]; then
  vault_init

  # utilizarlo para login temporal
  INIT_TOKEN="$(jq -r '.root_token' /vault/data/init.json)"

  echo "--- ROOT TOKEN: $INIT_TOKEN"

  # vault_dr_enable_with_cluster_c $INIT_TOKEN
  touch /vault/shared/cluster_d_init_ready
  unset VAULT_TOKEN

  wait_for_vault_restart
fi

wait $VAULT_PID

