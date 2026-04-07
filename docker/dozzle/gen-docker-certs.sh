#!/bin/bash
# gen-docker-certs.sh
# Usage: ./gen-docker-certs.sh <server-ip-or-hostname> [<server-ip-or-hostname> ...]
# Example: ./gen-docker-certs.sh 192.168.1.10 192.168.1.11 192.168.1.12

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <server-ip-or-hostname> [<server-ip-or-hostname> ...]"
  exit 1
fi

CERT_DIR="$HOME/.docker/certs"
CA_KEY="$CERT_DIR/ca-key.pem"
CA_CERT="$CERT_DIR/ca.pem"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# --- Generate CA (only if it doesn't exist) ---
if [ ! -f "$CA_KEY" ]; then
  echo "==> Generating CA..."
  openssl genrsa -out ca-key.pem 4096
  openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 \
    -subj "/CN=docker-ca" -out ca.pem
  chmod 0400 ca-key.pem
  chmod 0444 ca.pem
else
  echo "==> CA already exists, reusing it."
fi

# --- Generate client cert (only once, for the monitoring machine) ---
if [ ! -f "$CERT_DIR/client/cert.pem" ]; then
  echo "==> Generating client cert..."
  mkdir -p "$CERT_DIR/client"
  openssl genrsa -out client/key.pem 4096
  openssl req -subj '/CN=client' -new -key client/key.pem -out client/client.csr
  echo extendedKeyUsage = clientAuth > client/extfile-client.cnf
  openssl x509 -req -days 3650 -sha256 -in client/client.csr \
    -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
    -out client/cert.pem -extfile client/extfile-client.cnf
  chmod 0400 client/key.pem
  chmod 0444 client/cert.pem
  cp ca.pem client/ca.pem
  rm client/client.csr client/extfile-client.cnf
else
  echo "==> Client cert already exists, skipping."
fi

# --- Generate a server cert per host ---
for HOST in "$@"; do
  echo "==> Generating server cert for: $HOST"
  mkdir -p "servers/$HOST"

  openssl genrsa -out "servers/$HOST/server-key.pem" 4096
  openssl req -subj "/CN=$HOST" -sha256 -new \
    -key "servers/$HOST/server-key.pem" \
    -out "servers/$HOST/server.csr"

  # Support both IP and DNS SANs
  if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:$HOST,IP:127.0.0.1"
  else
    SAN="DNS:$HOST,IP:127.0.0.1"
  fi

  echo "subjectAltName = $SAN" > "servers/$HOST/extfile.cnf"
  echo "extendedKeyUsage = serverAuth" >> "servers/$HOST/extfile.cnf"

  openssl x509 -req -days 3650 -sha256 \
    -in "servers/$HOST/server.csr" \
    -CA ca.pem -CAkey ca-key.pem -CAcreateserial \
    -out "servers/$HOST/server-cert.pem" \
    -extfile "servers/$HOST/extfile.cnf"

  chmod 0400 "servers/$HOST/server-key.pem"
  chmod 0444 "servers/$HOST/server-cert.pem"
  rm "servers/$HOST/server.csr" "servers/$HOST/extfile.cnf"
  echo "    Done: $CERT_DIR/servers/$HOST/"
done

echo ""
echo "==> All done."
echo "    CA cert:     $CA_CERT"
echo "    Client cert: $CERT_DIR/client/"
echo "    Server cert: $CERT_DIR/servers/<host>/"
echo ""
echo "    IMPORTANT: Never distribute $CA_KEY outside this machine."
