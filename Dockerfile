FROM alpine:3.20

ARG VAULT_VERSION=1.19.0+ent
RUN apk add --no-cache wget curl jq unzip ca-certificates \
    && wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
    && unzip vault_${VAULT_VERSION}_linux_amd64.zip \
    && mv vault /usr/local/bin/ \
    && rm vault_${VAULT_VERSION}_linux_amd64.zip

CMD ["vault", "--version"]
