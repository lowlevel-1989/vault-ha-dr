FROM alpine:3.20

ARG VAULT_ENTERPRISE=false
ARG VAULT_VERSION=1.19.0

RUN apk add --no-cache wget curl jq unzip ca-certificates

COPY install-vault.sh /tmp/install-vault.sh
RUN chmod +x /tmp/install-vault.sh \
    && VAULT_ENTERPRISE=${VAULT_ENTERPRISE} VAULT_VERSION=${VAULT_VERSION} /tmp/install-vault.sh \
    && rm /tmp/install-vault.sh

CMD ["vault", "--version"]
