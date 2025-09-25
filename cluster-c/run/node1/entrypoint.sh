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

wait_for_vault_nodes() {
  until [ "$(vault operator raft list-peers -format=json | jq '.data.config.servers | length')" -ge 3 ]; do
    echo "Less than 3 nodes in the cluster, retrying..."
    sleep 5
  done

  echo "3 nodes are now present in the cluster"
}

vault_wait_for_leader() {
  while ! vault operator raft list-peers | grep -qi leader; do
    echo "Waiting for a leader to appear in the cluster..."
    sleep 2
  done
  echo "Leader detected!"
}

vault_unseal() {
  vault operator unseal "$(cat /vault/shared/cluster_c_unseal_key)"
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

  echo "$UNSEAL_KEY"  > /vault/shared/cluster_c_unseal_key
  echo "$VAULT_TOKEN" > /vault/shared/cluster_c_root_token

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

vault_pr_enable() {
  until [ -f "/vault/shared/cluster_a_performance_token_ready" ]; do
    echo "Waiting for cluster_a_performance_token from cluster A..."
    sleep 4
  done

  echo --- PR[1]. Enabling PR replication on cluster C.

  SECONDARY_PR_TOKEN=$(cat /vault/shared/cluster_a_performance_token)

  vault write sys/replication/performance/secondary/enable token="$SECONDARY_PR_TOKEN"
}

vault_dr_enable() {
  echo dr_enable
  vault status
  # REF: https://developer.hashicorp.com/vault/tutorials/enterprise/disaster-recovery#enable-dr-primary-replicationense
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
}

wait_for_vault 127.0.0.1

# Solo inicializar si no lo está
# Este paso solo se ejecuta la primera vez que se levanta el cluster
if [ ! -f "/vault/shared/cluster_c_init_ready" ]; then
  # VAULT_TOKEN asignado en vault_init como login temporal
  vault_init
  wait_for_vault vaultA-1
  wait_for_vault vaultA-2
  wait_for_vault vaultA-3
  vault_wait_for_leader

  touch /vault/shared/cluster_c_init_ready
  wait_for_vault_nodes

  vault_pr_enable
  wait_for_vault_unseal

else
  vault_unseal
fi

unset VAULT_TOKEN
wait $VAULT_PID
