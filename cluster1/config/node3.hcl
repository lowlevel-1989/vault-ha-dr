storage "raft" {
  path    = "/vault/data"
  node_id = "c1-node3"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr     = "http://vault1-3:8200"
cluster_addr = "http://vault1-3:8203"
ui = true

# no es seguro para prod
disable_mlock = true
