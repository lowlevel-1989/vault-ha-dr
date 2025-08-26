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

```
- Cluster A → vaultA-1, vaultA-2, vaultA-3
- Cluster B → vaultB-1, vaultB-2, vaultB-3
- Cluster C → vaultC-1, vaultC-2, vaultC-3
- Cluster D → vaultD-1, vaultD-2, vaultD-3
```

### 2. Initialize each cluster

In each cluster, only initialize the first node:

```
podman exec -it vaultA-1 vault operator init
podman exec -it vaultB-1 vault operator init
podman exec -it vaultC-1 vault operator init
podman exec -it vaultD-1 vault operator init

podman exec -it vaultA-1 vault operator unseal
podman exec -it vaultB-1 vault operator unseal
podman exec -it vaultC-1 vault operator unseal
podman exec -it vaultD-1 vault operator unseal
```

Save the unseal keys and the root token printed by each `init`, they are unique per cluster.

### 3. Join the other nodes to the cluster

After initializing the first node, join the other two:

Cluster A:

```
podman exec -it vaultA-2 vault operator raft join http://vaultA-1:8200
podman exec -it vaultA-3 vault operator raft join http://vaultA-1:8200

podman exec -it vaultA-2 vault operator unseal
podman exec -it vaultA-3 vault operator unseal
```

Cluster A:

```
podman exec -it vaultB-2 vault operator raft join http://vaultB-1:8200
podman exec -it vaultB-3 vault operator raft join http://vaultB-1:8200

podman exec -it vaultB-2 vault operator unseal
podman exec -it vaultB-3 vault operator unseal
```

Cluster C:

```
podman exec -it vaultC-2 vault operator raft join http://vaultC-1:8200
podman exec -it vaultC-3 vault operator raft join http://vaultC-1:8200

podman exec -it vaultC-2 vault operator unseal
podman exec -it vaultC-3 vault operator unseal
```

Cluster D:

```
podman exec -it vaultD-2 vault operator raft join http://vaultD-1:8200
podman exec -it vaultD-3 vault operator raft join http://vaultD-1:8200

podman exec -it vaultD-2 vault operator unseal
podman exec -it vaultD-3 vault operator unseal
```

### 4. Verify cluster state

On any node of a cluster:

```
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
rm -rf cluster{A..D}/data/node{1..3}
```

This will remove the containers and data volumes.


## References

- https://developer.hashicorp.com/vault/tutorials/raft/raft-storage


