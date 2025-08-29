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

# Comprobar si la replicacion esta activa
REPLICATION=$(vault read sys/replication/dr/status --format=json)
echo $REPLICATION
REPLICATION_STATUS=$(echo "$REPLICATION" | jq -r '.data.mode')
echo $REPLICATION_STATUS
echo $DR_ROL

if [ ["$REPLICATION_STATUS" != "disabled"] && [ -v $DR_ROL ] ]; then
    echo "Comprobando rol"
    if [ "$DR_ROL" == "PRIMARY" ]; then
      echo "Habilitando rol PRIMARY"
      vault write -f sys/replication/dr/primary/enable
      TOKEN_DATA=$(vault write sys/replication/dr/primary/secondary-token id="dr-secondary")
      WRAPPING_TOKEN=$(echo "$TOKEN_DATA" | jq -r '.data.wrapping_token')
      echo "$WRAPPING_TOKEN" >> /vault/data/wrapping_token
    elif [ "$DR_ROL" == "SECONDARY" ]; then
      echo "Habilitando rol SECONDARY"
      TOKEN_FILE="/vault/token/wrapping_token-vault-1"
      until [ -f "$TOKEN_FILE" ]; do
        echo "Waiting for wrapping token from nodo primario"
        sleep 15
      done
      vault write sys/replication/dr/secondary/enable token="$(cat $TOKEN_FILE)"
    fi
  
  vault read sys/replication/dr/status
fi

wait $VAULT_PID