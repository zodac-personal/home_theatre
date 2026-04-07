#!/bin/bash
# deploy-docker-certs.sh
# Usage: ./deploy-docker-certs.sh <user> <server-ip> [keyfile] [<user> <server-ip> [keyfile] ...]
# Example: ./deploy-docker-certs.sh ubuntu 192.168.1.10 ubuntu 192.168.1.11 ~/.ssh/my.key

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <user> <server-ip> [keyfile] [<user> <server-ip> [keyfile] ...]"
  exit 1
fi

CERT_DIR="$HOME/.docker/certs"
REMOTE_CERT_DIR="/etc/docker/certs"

while [ "$#" -ge 2 ]; do
  REMOTE_USER=$1
  HOST=$2
  shift 2

  # Optional third argument: path to SSH identity file
  SSH_OPTS="-o StrictHostKeyChecking=accept-new"
  if [ "$#" -gt 0 ] && [ -f "$1" ]; then
    SSH_OPTS="$SSH_OPTS -i $1"
    shift
  fi

  echo "==> Deploying certs to $REMOTE_USER@$HOST..."

  if [ ! -f "$CERT_DIR/servers/$HOST/server-cert.pem" ]; then
    echo "    ERROR: No server cert found for $HOST. Run gen-docker-certs.sh $HOST first."
    exit 1
  fi

  ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo mkdir -p $REMOTE_CERT_DIR"

  for FILE in \
    "$CERT_DIR/ca.pem" \
    "$CERT_DIR/servers/$HOST/server-cert.pem" \
    "$CERT_DIR/servers/$HOST/server-key.pem"; do
    BASENAME=$(basename "$FILE")
    scp $SSH_OPTS "$FILE" "$REMOTE_USER@$HOST:/tmp/$BASENAME"
    ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo mv /tmp/$BASENAME $REMOTE_CERT_DIR/$BASENAME && sudo chmod 0444 $REMOTE_CERT_DIR/$BASENAME"
  done
  ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo chmod 0400 $REMOTE_CERT_DIR/server-key.pem"

  echo "    Certs deployed. Configuring Docker service..."
  ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo mkdir -p /etc/systemd/system/docker.service.d"
  ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo tee /etc/systemd/system/docker.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// \\\\
  -H tcp://0.0.0.0:2376 \\\\
  --tlsverify \\\\
  --tlscacert=$REMOTE_CERT_DIR/ca.pem \\\\
  --tlscert=$REMOTE_CERT_DIR/server-cert.pem \\\\
  --tlskey=$REMOTE_CERT_DIR/server-key.pem \\\\
  --containerd=/run/containerd/containerd.sock
EOF"

  ssh $SSH_OPTS "$REMOTE_USER@$HOST" "sudo systemctl daemon-reload && sudo systemctl restart docker"
  echo "    Docker restarted on $HOST."
  echo ""
done

echo "==> All hosts configured."
echo ""
echo "    To connect from this machine, set:"
echo "      export DOCKER_TLS_VERIFY=1"
echo "      export DOCKER_CERT_PATH=$CERT_DIR/client"
echo "      export DOCKER_HOST=tcp://<host>:2376"
