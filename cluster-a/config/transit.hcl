# De momento no esta en uso, lo dejo de referencia
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8100"
  tls_disable = 1
}

ui = true
disable_mlock = true
