#!/bin/sh

set -e

VAULT_ENTERPRISE=${VAULT_ENTERPRISE}
VAULT_VERSION=${VAULT_VERSION}

if [ -z "$VAULT_ENTERPRISE" ]; then
    echo "VAULT_ENTERPRISE is not set"
    exit 1
fi

if [ -z "$VAULT_VERSION" ]; then
    echo "VAULT_VERSION is not set"
    exit 1
fi

if $VAULT_ENTERPRISE; then
    VAULT_SUFFIX="+ent"
    VAULT_VERSION_MSG="Enterprise"
else
    VAULT_SUFFIX=""
    VAULT_VERSION_MSG="Community"
fi

echo "Vault ${VAULT_VERSION_MSG} version ${VAULT_VERSION} is being installed..."

VAULT_FULL_VERSION="${VAULT_VERSION}${VAULT_SUFFIX}"

echo "Downloading Vault ${VAULT_FULL_VERSION}..."

wget "https://releases.hashicorp.com/vault/${VAULT_FULL_VERSION}/vault_${VAULT_FULL_VERSION}_linux_amd64.zip"
unzip "vault_${VAULT_FULL_VERSION}_linux_amd64.zip"
mv vault /usr/local/bin/
rm "vault_${VAULT_FULL_VERSION}_linux_amd64.zip"

echo "Vault ${VAULT_FULL_VERSION} installed successfully!"