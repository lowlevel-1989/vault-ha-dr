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

vault_init() {
  echo "Initializing cluster with Transit seal..."
  vault operator init -format json > /vault/data/init.json

  # limpiamos el token para el unseal
  unset VAULT_TOKEN
}

vault_pr_enable() {
  SEC_ADDR=http://vaultC-1:8200

  until [ -f "/vault/shared/cluster_a_performance_token_ready" ]; do
    echo "Waiting for cluster_a_performance_token from cluster A..."
    sleep 4
  done

  echo --- PR[1]Enabling PR replication on cluster C.

  export VAULT_TOKEN=$1
  SECONDARY_PR_TOKEN=$(cat /vault/shared/cluster_a_performance_token)

  vault write -address=$SEC_ADDR sys/replication/performance/secondary/enable token="$SECONDARY_PR_TOKEN"

  unset VAULT_TOKEN
  unset SEC_ADDR
}

vault_dr_enable() {
  # VAULT_TOKEN como login temporal
  # REF: https://developer.hashicorp.com/vault/tutorials/enterprise/disaster-recovery#enable-dr-primary-replicationense

  export VAULT_TOKEN=$1
  echo --- DR[1]. Enable DR replication on the primary cluster.
  sleep 2
  vault write -f sys/replication/dr/primary/enable

  echo --- DR[2]. Generate a secondary token.
  sleep 2
  RESPONSE=$(vault write --format json sys/replication/dr/primary/secondary-token id="dr-secondary")
  SECONDARY_TOKEN=$(echo "$RESPONSE" | jq -r ".wrap_info.token")
  echo $SECONDARY_TOKEN > /vault/shared/cluster_c_wrapping_token
  touch /vault/shared/cluster_c_wrapping_token_ready

  echo secondary-token: $SECONDARY_TOKEN

  unset VAULT_TOKEN
}



# Solo inicializar si no lo está
# Este paso solo se ejecuta la primera vez que se levanta el cluster
if ! vault status >/dev/null 2>&1; then
  vault_init

  # utilizarlo para login temporal
  INIT_TOKEN="$(jq -r '.root_token' /vault/data/init.json)"

  echo "--- ROOT TOKEN: $INIT_TOKEN"

  vault_pr_enable $INIT_TOKEN
  vault_dr_enable $INIT_TOKEN
  
  unset INIT_TOKEN

fi

wait $VAULT_PID

