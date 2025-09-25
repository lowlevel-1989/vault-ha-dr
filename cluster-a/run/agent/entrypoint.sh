#!/bin/sh
set -e

vault agent -config=/vault/config/vault.hcl &
VAULT_PID=$!

echo "vault agent started"

# Esperar a que responda
until curl -s http://vaultA-1:8200/v1/sys/health >/dev/null; do
  sleep 2
done

wait $VAULT_PID
