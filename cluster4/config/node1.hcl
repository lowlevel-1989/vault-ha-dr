storage "raft" {
  path    = "/vault/data"
  node_id = "c4-node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr     = "http://vault4-1:8200"
cluster_addr = "http://vault4-1:8201"
ui = true

# no es seguro para prod
disable_mlock = true
