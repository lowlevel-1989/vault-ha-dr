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

wait_for_vault_leader() {
  until [ -f "/vault/shared/cluster_b_init_ready" ]; do
    echo "Waiting for autounseal token from node 1..."
    sleep 15
  done
}

vault_unseal() {
  while true; do
    if [ "$(vault status -format=json 2>/dev/null | jq -r '.sealed')" = "false" ]; then
      break
    fi
    if ! vault operator unseal "$(cat /vault/shared/cluster_a_unseal_key)"; then 
      echo "Waiting for a unseal with cluster_a_unseal_key..."
      vault status
    fi
    sleep 2
  done
}

wait_for_vault 127.0.0.1
wait_for_vault_leader
vault_unseal

touch /vault/shared/cluster_b_node_3_init_ready
wait $VAULT_PID
