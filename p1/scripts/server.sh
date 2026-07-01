#!/bin/bash

green='\e[1;32m'
orange='\e[0;33m'
blue='\e[1;34m'
red='\e[0;31m'
reset='\e[0;m\033[K'

log_file="/tmp/k3s_p1_master_log$(date | awk '{printf "_%s_%s_%s", $2, $3, $4}' | tr -s ':' '_')"

echo -ne "${orange}[LOG] Updating packages and installing 'curl'...${reset}"
if ! apt-get update -y >> "$log_file" || ! apt-get install -y curl >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to update packages or install curl${reset}\n"
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Packages updated and curl installed                             ${reset}\n"

if ! command -v k3s >> "$log_file"; then
	echo -ne "${orange}[LOG] Installing k3s...                                                    ${reset}"
	if ! curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110" sh - >> "$log_file"; then
		echo -ne "\r${red}[LOG] Failed to install k3s                                                                 ${reset}\n"
		echo -e "${red}\n[LOG] LOGS: ${reset}"
		cat "$log_file"
		exit 1
	fi
	echo -ne "\r${green}[LOG] K3s has been installed successfully${reset}\n"
else
	echo -ne "${green}[LOG] K3s is already installed${reset}\n"
fi

echo -ne "${orange}[LOG] Waiting for node-token to be generated...${reset}"
TIMEOUT=60
ELAPSED=0
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
	sleep 1
	ELAPSED=$((ELAPSED + 1))
	if [ $ELAPSED -ge $TIMEOUT ]; then
		echo -ne "\r${red}[LOG] Timeout: node-token was not generated${reset}\n"
		exit 1
	fi
done
echo -ne "\r${green}[LOG] Node-token has been generated                                            ${reset}\n"

echo -ne "${orange}[LOG] Copying token to shared folder...${reset}"
if ! cp /var/lib/rancher/k3s/server/node-token /vagrant/token >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to copy token to shared folder${reset}\n"
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Token copied to shared folder successfully                       ${reset}\n"
