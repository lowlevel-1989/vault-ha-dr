storage "raft" {
  path    = "/vault/data"
  node_id = "D-node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8204"
  tls_disable = 1
}

api_addr     = "http://vaultD-1:8200"
cluster_addr = "http://vaultD-1:8204"
ui = true

# no es seguro para prod
disable_mlock = true
