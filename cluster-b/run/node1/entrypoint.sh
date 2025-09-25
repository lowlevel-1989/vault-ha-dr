#!/bin/sh
set -e

vault server -config=/vault/config/vault.hcl &
VAULT_PID=$!

echo "vault server started"

wait_for_vault() {
  until curl -s http://$1:8200/v1/sys/health >/dev/null; do
    echo "Waiting for Vault API [$1]..."
    sleep 2
  done
}

vault_unseal() {
  vault operator unseal "$(cat /vault/shared/cluster_a_unseal_key)"
}

vault_wait_for_leader() {
  while ! vault operator raft list-peers | grep -qi leader; do
    echo "Waiting for a leader to appear in the cluster..."
    sleep 2
  done
  echo "Leader detected!"
}

wait_for_vault_unseal() {
  echo "Waiting for Vault to be unsealed..."
  vault status

  while [ "$(vault status -format=json 2>/dev/null | jq -r '.sealed')" = "true" ]; do
    echo "Vault is still sealed..."
    sleep 2
  done

  vault status
  echo "Vault is unsealed"
}

vault_init() {
  echo "Initializing ..."
  INIT_RESPONSE=$(vault operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY"  > /vault/shared/cluster_b_unseal_key
  echo "$VAULT_TOKEN" > /vault/shared/cluster_b_root_token

  printf "\n%s" \
    "--- UNSEAL KEY: $UNSEAL_KEY" \
    "--- ROOT TOKEN: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "unsealing and logging" \
    ""
  sleep 2 # Added for human readability

  vault operator unseal "$UNSEAL_KEY"

  export VAULT_TOKEN
}

vault_dr_enable_with_cluster_a() {
  echo dr_enable_with_cluster_a
  vault status

  until [ -f "/vault/shared/cluster_a_wrapping_token_ready" ]; do
    echo "Waiting for cluster_a_wrapping_token from cluster A..."
    sleep 2
  done

  echo --- DR[1] Enable DR replication on the secondary cluster.

  WRAPPING_TOKEN=$(cat /vault/shared/cluster_a_wrapping_token)

  vault write sys/replication/dr/secondary/enable token="$WRAPPING_TOKEN"
}

wait_for_vault 127.0.0.1

# Solo inicializar si no lo está
# Este paso solo se ejecuta la primera vez que se levanta el cluster
if [ ! -f "/vault/shared/cluster_b_init_ready" ]; then
  # VAULT_TOKEN asignado en vault_init como login temporal
  vault_init
  vault_wait_for_leader
  vault_dr_enable_with_cluster_a
  wait_for_vault_unseal

  touch /vault/shared/cluster_b_init_ready
else
  vault_unseal
fi

unset VAULT_TOKEN
wait $VAULT_PID
