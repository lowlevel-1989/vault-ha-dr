storage "raft" {
  path    = "/vault/data"
  node_id = "A-node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = 1
}

api_addr     = "http://vaultA-1:8200"
cluster_addr = "http://vaultA-1:8201"
ui = true

# no es seguro para prod
disable_mlock = true
