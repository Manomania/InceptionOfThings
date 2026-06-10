#!/bin/bash

echo "[LOG] Update packages and installing 'curl'"
apt-get update -y && apt-get install curl -y

TIMEOUT=30
ELAPSED=0
while [ ! -f /vagrant/token ]; do
	sleep 1
	ELAPSED=$((ELAPSED + 1))
	if [ $ELAPSED -ge $TIMEOUT ]; then
		echo "Timeout waiting for token"
		exit 1
	fi
done

echo "[LOG] Token retrieval"
NODE_TOKEN=$(cat /vagrant/token)

echo "[LOG] Token deleted"
rm -rf vagrant/token

echo "[LOG] Installing k3s-agent"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.111" K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="$NODE_TOKEN" sh -
