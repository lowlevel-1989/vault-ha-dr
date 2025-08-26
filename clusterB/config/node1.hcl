storage "raft" {
  path    = "/vault/data"
  node_id = "B-node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8202"
  tls_disable = 1
}

seal "transit" {
  address            = "http://vaultB-transit:8100"
  # token is read from VAULT_TOKEN env
  # token              = ""
  disable_renewal    = "false"

  // Key configuration
  key_name           = "unseal_key"
  mount_path         = "transit/"
}

api_addr     = "http://vaultB-1:8200"
cluster_addr = "http://vaultB-1:8202"
ui = true

# no es seguro para prod
disable_mlock = true
