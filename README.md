# Vault HA (4 clusters with 3 nodes each)

This repository contains a lab environment to deploy **4 independent HashiCorp Vault clusters**, each in **High Availability (HA)** mode with 3 nodes using **Podman Compose** and **Raft** storage.

Each cluster contains three nodes configured with:

* Unique `node_id`
* Individual `api_addr` and `cluster_addr` per node
* `storage "raft"` as HA backend

address listen on start service docker. (8200)
cluster_address listen post unseal.     (820x)

show ports listen in container
```
podman exec -it vaultA-2 sh
netstat -tuln
```

---

## Steps to run the clusters

### 1. Start all clusters (build happens automatically)

Podman Compose will build the image because services use `build: .` in the compose file:

```
podman-compose up -d
```

This will launch 12 containers:

* Cluster A → vaultA-1, vaultA-2, vaultA-3
* Cluster B → vaultB-1, vaultB-2, vaultB-3
* Cluster C → vaultC-1, vaultC-2, vaultC-3
* Cluster D → vaultD-1, vaultD-2, vaultD-3

## Verify cluster state

On any node of a cluster:
```
cat clusterA/data/init.json
podman logs vaultA-1 2>&1 | grep -i "root token"
podman exec -it vaultA-1 vault login
podman exec -it vaultA-1 vault operator raft list-peers
```

You should see all 3 nodes (leader + 2 followers).

---

## Security notes

* The `podman-compose.yml` includes the capability `IPC_LOCK` to allow Vault to use `mlock` and prevent sensitive data from being swapped to disk.

  * Lab: not required.
  * Production: recommended.

* TLS is disabled in this lab setup (`tls_disable = 1`). For real environments, configure TLS certificates.

---

## Cleanup

To stop and clean up the containers:

```
podman-compose down -v
find cluster{A..D}/data/node{1..3} cluster{A..D}/data/transit -mindepth 1 ! -name '.keepgit' -exec rm -rf {} +
```

This will remove the containers and data volumes.


## References

- https://developer.hashicorp.com/vault/tutorials/raft/raft-storage


