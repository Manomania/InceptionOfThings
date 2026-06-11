#!/bin/bash

echo "[LOG] Update package and install 'curl'"
apt-get update -y && apt-get install curl -y

if ! command -v k3s &> /dev/null; then
	echo "[LOG] Installing k3s"
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110" sh -
fi

echo "[LOG] Deploying application one"
kubectl apply -f /vagrant/confs/app1/

echo "[LOG] Deploying application two"
kubectl apply -f /vagrant/confs/app2/

echo "[LOG] Deploying application three"
kubectl apply -f /vagrant/confs/app3/

echo "[LOG] Applying ingress"
kubectl apply -f /vagrant/confs
