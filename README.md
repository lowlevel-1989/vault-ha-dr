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
podman exec -it vault1-2 sh
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

* Cluster 1 → vault1-1, vault1-2, vault1-3
* Cluster 2 → vault2-1, vault2-2, vault2-3
* Cluster 3 → vault3-1, vault3-2, vault3-3
* Cluster 4 → vault4-1, vault4-2, vault4-3

### 2. Initialize each cluster

In each cluster, only initialize the first node:

```
podman exec -it vault1-1 vault operator init
podman exec -it vault2-1 vault operator init
podman exec -it vault3-1 vault operator init
podman exec -it vault4-1 vault operator init

podman exec -it vault1-1 vault operator unseal
podman exec -it vault2-1 vault operator unseal
podman exec -it vault3-1 vault operator unseal
podman exec -it vault4-1 vault operator unseal
```

Save the unseal keys and the root token printed by each `init`, they are unique per cluster.

### 3. Join the other nodes to the cluster

After initializing the first node, join the other two:

Cluster 1:

```
podman exec -it vault1-2 vault operator raft join http://vault1-1:8200
podman exec -it vault1-3 vault operator raft join http://vault1-1:8200

podman exec -it vault1-2 vault operator unseal
podman exec -it vault1-3 vault operator unseal
```

Cluster 2:

```
podman exec -it vault2-2 vault operator raft join http://vault2-1:8200
podman exec -it vault2-3 vault operator raft join http://vault2-1:8200

podman exec -it vault2-2 vault operator unseal
podman exec -it vault2-3 vault operator unseal
```

Cluster 3:

```
podman exec -it vault3-2 vault operator raft join http://vault3-1:8200
podman exec -it vault3-3 vault operator raft join http://vault3-1:8200

podman exec -it vault3-2 vault operator unseal
podman exec -it vault3-3 vault operator unseal
```

Cluster 4:

```
podman exec -it vault4-2 vault operator raft join http://vault4-1:8200
podman exec -it vault4-3 vault operator raft join http://vault4-1:8200

podman exec -it vault4-2 vault operator unseal
podman exec -it vault4-3 vault operator unseal
```

### 4. Verify cluster state

On any node of a cluster:

```
podman exec -it vault1-1 vault operator raft list-peers
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
```

This will remove the containers and data volumes.


## References



