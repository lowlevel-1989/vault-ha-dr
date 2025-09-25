#!/bin/sh
set -e

vault server -config=/vault/config/vault.hcl &
VAULT_PID=$!

echo "vault server started"

wait_for_vault() {
  until curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null; do
    echo "Waiting for local Vault API..."
    sleep 2
  done
}

wait_for_vault_leader() {
  until [ -f "/vault/shared/cluster_a_init_ready" ]; do
    echo "Waiting for autounseal token from node 1..."
    sleep 15
  done
}

vault_unseal() {
  vault operator unseal "$(cat /vault/shared/cluster_a_unseal_key)"
}

wait_for_vault
wait_for_vault_leader
vault_unseal

touch /vault/shared/cluster_a_node_2_init_ready
wait $VAULT_PID
