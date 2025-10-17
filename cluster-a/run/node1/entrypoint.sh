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

vault_init() {
  echo "Initializing ..."
  INIT_RESPONSE=$(vault operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY"  > /vault/shared/cluster_a_unseal_key
  echo "$VAULT_TOKEN" > /vault/shared/cluster_a_root_token

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
  echo $SECONDARY_TOKEN > /vault/shared/cluster_a_wrapping_token
  touch /vault/shared/cluster_a_wrapping_token_ready

  echo secondary-token: $SECONDARY_TOKEN
}

vault_pr_enable() {
  echo pr_enable
  vault status
  # Habilitar Performance Replication en el primario
  # REF: https://developer.hashicorp.com/vault/tutorials/enterprise/performance-replication
  echo "--- PR[1]. Enable Performance Replication on the primary cluster."
  sleep 2
  echo "--- PR[2]. Initial steps for Performance Replication primary cluster."
  
  vault write -f sys/replication/performance/primary/enable

  echo "--- PR[3]. Generate a Performance secondary token."
  sleep 2
  RESPONSE=$(vault write --format json sys/replication/performance/primary/secondary-token id="pr-secondary")
  SECONDARY_PR_TOKEN=$(echo "$RESPONSE" | jq -r ".wrap_info.token")

  echo "$SECONDARY_PR_TOKEN" > /vault/shared/cluster_a_performance_token
  touch /vault/shared/cluster_a_performance_token_ready

  echo "secondary-performance-token: $SECONDARY_PR_TOKEN"
}

vault_create_period_token() {
  echo create_period_token
  vault status
  # ref: https://developer.hashicorp.com/vault/docs/concepts/tokens#periodic-tokens
  # lo utiliza el agente para authenticar y renovarlo
  # el request de renew lo ejecuta en funcion del 
  # tiempo asignado al period
  RESPONSE=$(vault token create -format json -period=5m -orphan=true)
  PERIOD_TOKEN=$(echo "$RESPONSE" | jq -r ".auth.client_token")

  echo $PERIOD_TOKEN > /vault/shared/cluster_a_period_token_5m
}

vault_create_policy_superuser() {
  echo create_policy_superuser
  vault status
  vault policy write superuser -<<EOF
  path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
EOF
}

vault_create_admin_superuser() {
  echo create_admin_superuser
  vault status
  vault auth enable userpass
  vault write auth/userpass/users/admin password="admin" policies="superuser"
}

wait_for_vault 127.0.0.1

# Solo inicializar si no lo está
# Este paso solo se ejecuta la primera vez que se levanta el cluster
if [ ! -f "/vault/shared/cluster_a_init_ready" ]; then
  # VAULT_TOKEN asignado en vault_init como login temporal
  vault_init
  vault_wait_for_leader

  vault_create_period_token
  vault_create_policy_superuser
  vault_create_admin_superuser

  touch /vault/shared/cluster_a_init_ready
  wait_for_vault_nodes

  vault_dr_enable
fi

vault_unseal
unset VAULT_TOKEN
wait $VAULT_PID
