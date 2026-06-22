#!/bin/bash

k3d cluster create maximart-p3 -p "8888:80@loadbalancer" --agents 1

kubectl create namespace dev
kubectl create namespace argocd

kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait -n argocd --for=condition=Ready pod --all --timeout=120s

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

kubectl port-forward svc/argocd-server -n argocd 8080:443 &> /tmp/argocd-logs &
argocd_server_pid="/tmp/argocd-p3-pid.pid"
echo $! > "$argocd_server_pid"
sleep 3

password=$(argocd admin initial-password -n argocd | head -1)

argocd login localhost:8080 --username admin --password $password --insecure

argocd account update-password --current-password $password

#TODO ADD APPLICATION WIL42 FOR ARGOCD AS IAC
