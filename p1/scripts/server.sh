#!/bin/bash

echo "[LOG] Update package and install 'curl'"
apt-get update -y && apt-get install curl -y

if ! command -v k3s &> /dev/null; then
	echo "[LOG] Installing k3s"
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110" sh -
fi

TIMEOUT=60
ELAPSED=0
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
	sleep 1
	ELAPSED=$(($ELAPSED + 1))
	if [ $ELAPSED -ge $TIMEOUT ]; then
		echo "Timeout token not generated"
		exit 1
	fi
done


echo "[LOG] Copy token on shared folder"
cp /var/lib/rancher/k3s/server/node-token /vagrant/token
