storage "raft" {
  path    = "/vault/data"
  node_id = "D-node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8204"
  tls_disable = 1
}

# Desactivado por problemas de automatización a la hora de realizar dr.
# no se desellan los nodos 2, 3 automaticamente al iniciar el dr.
# seal "transit" {
#  address            = "http://vaultD-transit:8100"
#  # token is read from VAULT_TOKEN env
#  # token              = ""
#  disable_renewal    = "false"
#
#  // Key configuration
#  key_name           = "unseal_key"
#  mount_path         = "transit/"
# }

api_addr     = "http://vaultD-1:8200"
cluster_addr = "http://vaultD-1:8204"
ui = true

# no es seguro para prod
disable_mlock = true
