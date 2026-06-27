#!/bin/bash

green='\e[1;32m'
orange='\e[0;33m'
blue='\e[1;34m'
red='\e[0;31m'
reset='\e[0;m\033[K'

log_file="/tmp/k3d_p3_log$(date | awk '{printf "_%s_%s_%s", $2, $3, $4}' | tr -s ':' '_')"

if [ ! "$EUID" -eq 0 ]; then
	echo -e "${red}[LOG] Please run: sudo ./run.sh${reset}"
	exit 1
fi

if [ ! "$(k3d cluster list | awk '{print $1}' | tail -1)" == "maximart-p3" ]; then
	echo -ne "${orange}[LOG] Creating cluster for p3 part...${reset}"
	if ! k3d cluster create maximart-p3 -p "8888:80@loadbalancer" --agents 1 >> "$log_file"; then
		echo -ne "\r${red}[LOG] Failed to create cluster${reset}\n"
		exit 1
	fi
else
	echo -ne "\r${red}[LOG] Cluster maximart-p3 already exist${reset}\n"
	exit 1
fi
echo -ne "\r${green}[LOG] Cluster created successfully ! ${reset}\n"

echo -ne "${orange}[LOG] Creating namespaces dev & argocd...${reset}"
if ! kubectl create namespace dev >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to create namespace dev${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Namespace dev created successfully ${reset}\n"

if ! kubectl create namespace argocd >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to create namespace argocd${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "${green}[LOG] Namespace argocd created successfully${reset}\n"

echo -ne "${orange}[LOG] Installing Argo CD...${reset}"
if ! kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to install Argo CD${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Argo CD has been installed successfully${reset}\n"

echo -ne "${orange}[LOG] Waiting pods to be ready...${reset}"
if ! kubectl wait -n argocd --for=condition=Ready pod --all --timeout=120s >> "$log_file"; then
	echo -ne "\r${red}[LOG] Timeout ! Pods aren't ready${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1

fi
echo -ne "\r${green}[LOG] Pods are ready${reset}\n"

echo -ne "${orange}[LOG] Installation of Argo CD CLI...${reset}"
if ! curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to download Argo CD CLI${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
if ! { install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && rm argocd-linux-amd64; } >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to install Argo CD CLI${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Argo CD CLI has been installed successfully${reset}\n"

echo -ne "${orange}[LOG] Launch Argo CD server..${reset}"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &> /tmp/argocd-logs &
argocd_server_pid="/tmp/argocd-p3-pid.pid"
echo $! > "$argocd_server_pid"
echo -ne "\r${green}[LOG] Argo CD Server is up${reset}\n"
sleep 3

password=$(argocd admin initial-password -n argocd | head -1)

echo -ne "${orange}[LOG] First connection to Argo CD..${reset}"
if ! argocd login localhost:8080 --username admin --password $password --insecure >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to login to Argo CD${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] First connection has been done${reset}\n"

while true; do
	echo -ne "${orange}[LOG] Enter a new password: ${reset}"
	read -s new_password
	echo -ne "\r${orange}[LOG] Confirm new password: ${reset}"
	read -s confirm_password
	if [ "$new_password" = "$confirm_password" ] && [ ${#new_password} -ge 8 ] && [ ${#new_password} -le 32 ]; then
		break
	fi
	echo -ne "\r${red}[LOG] Passwords don't match or too short or too long, try again${reset}\n"
done

echo -ne "\r${orange}[LOG] Updating password...${reset}"
if ! argocd account update-password --current-password $password --new-password $new_password >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to update password                          ${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] New password has been set${reset}\n"

echo -ne "${orange}[LOG] Deleting argo-cd-initial-admin-secret...${reset}"
if ! kubectl delete secret argocd-initial-admin-secret -n argocd >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to delete initial password${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Initial password has been removed${reset}\n"



echo -ne "${orange}[LOG] Creating project 'development' for Argo CD...${reset}"
if ! argocd proj create development >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to create project 'development' for Argo CD${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Project 'development' has been created for Argo CD${reset}\n"

echo -ne "${orange}[LOG] Adding github source to 'development' project...${reset}"
if ! argocd proj add-source development https://github.com/Manomania/InceptionOfThings >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to adding source to 'development' project${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Github source has been added to 'development' project${reset}\n"

echo -ne "${orange}[LOG] Adding destination to 'development' project...${reset}"
if ! argocd proj add-destination development https://kubernetes.default.svc dev >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to adding destination to 'development' project${reset}\n"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Destination has been added to 'development' project${reset}\n"

echo -ne "${orange}[LOG] Apply wil42 to Argo CD...${reset}"
if ! kubectl apply -f /home/maximart/Inception-of-Things/p3/confs/application.yaml >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to create wil42${reset}"
	echo -e "${red}[LOG] Deleting cluster maximart-p3${reset}"
	k3d cluster delete maximart-p3 &> /dev/null
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Wil42 application has been created successfully${reset}\n"

echo -e "${blue}\n[LOG] You can connect to Argo CD at 'https://localhost:8080/'${reset}"
echo -e "${blue}[LOG] If you need to kill the server, run this command: 'sudo kill $(cat $argocd_server_pid)'${reset}"
