pid_file = "/tmp/vauld-agent.pid"

vault {
  address = "$VAULT_ADDR"
}

auto_auth {
  method {
    type = "token_file"
    namespace = "$VAULT_NAMESPACE"
    config = {
      token_file_path = "/vault/shared/cluster_a_period_token_5m"
    }
  }
  sink "file" {
    config = {
      path = "/vault/data/vault-token-via-agent"
    }
  }
}
