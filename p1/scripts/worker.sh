#!/bin/bash

green='\e[1;32m'
orange='\e[0;33m'
blue='\e[1;34m'
red='\e[0;31m'
reset='\e[0;m\033[K'

log_file="/tmp/k3s_p1_worker_log$(date | awk '{printf "_%s_%s_%s", $2, $3, $4}' | tr -s ':' '_')"

echo -ne "${orange}[LOG] Updating packages and installing 'curl'...${reset}"
if ! apt-get update -y >> "$log_file" || ! apt-get install -y curl >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to update packages or install curl                ${reset}\n"
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Packages updated and curl installed                             ${reset}\n"

echo -ne "${orange}[LOG] Waiting for token...${reset}"
TIMEOUT=30
ELAPSED=0
while [ ! -f /vagrant/token ]; do
	sleep 1
	ELAPSED=$((ELAPSED + 1))
	if [ $ELAPSED -ge $TIMEOUT ]; then
		echo -ne "\r${red}[LOG] Timeout: token was not found${reset}\n"
		exit 1
	fi
done
echo -ne "\r${green}[LOG] Token found                                  ${reset}\n"

echo -ne "${orange}[LOG] Retrieving token...${reset}"
NODE_TOKEN=$(cat /vagrant/token)
echo -ne "\r${green}[LOG] Token retrieved successfully                       ${reset}\n"

echo -ne "${orange}[LOG] Deleting token...${reset}"
if ! rm -rf /vagrant/token >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to delete token                                 ${reset}\n"
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] Token deleted                                                ${reset}\n"

echo -ne "${orange}[LOG] Installing k3s-agent...${reset}"
if ! curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.111" K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="$NODE_TOKEN" sh - >> "$log_file"; then
	echo -ne "\r${red}[LOG] Failed to install k3s-agent                               ${reset}\n"
	echo -e "${red}\n[LOG] LOGS: ${reset}"
	cat "$log_file"
	exit 1
fi
echo -ne "\r${green}[LOG] K3s-agent has been installed successfully${reset}\n"
