FROM alpine:3.24

ARG GOOSE_VERSION=v3.28.0
ARG TARGETARCH=x86_64

RUN apk add --no-cache ca-certificates curl \
    && curl -fsSL \
       "https://github.com/pressly/goose/releases/download/${GOOSE_VERSION}/goose_linux_${TARGETARCH}" \
       -o /usr/local/bin/goose \
    && chmod +x /usr/local/bin/goose \
    && goose --version

WORKDIR /migrations
ENTRYPOINT ["goose"]
