storage "raft" {
  path    = "/vault/data"
  node_id = "C-node1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8203"
  tls_disable = 1
}

api_addr     = "http://vaultC-1:8200"
cluster_addr = "http://vaultC-1:8203"
ui = true

# no es seguro para prod
disable_mlock = true
