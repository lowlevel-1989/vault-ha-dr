storage "raft" {
  path    = "/vault/data"
  node_id = "c4-node2"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8204"
  tls_disable = 1
}

api_addr     = "http://vault4-2:8200"
cluster_addr = "http://vault4-2:8204"
ui = true

# no es seguro para prod
disable_mlock = true
