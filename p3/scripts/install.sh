#!/bin/bash

green='\e[1;32m'
orange='\e[0;33m'
blue='\e[1;34m'
red='\e[0;31m'
reset='\e[0;m\033[K'


log_file="/tmp/install_p3_log$(date | awk '{printf "_%s_%s_%s", $2, $3, $4}' | tr -s ':' '_')"

if [ ! "$EUID" -eq 0 ]; then
	echo -e "${red}[LOG] Please run: sudo ./install.sh${reset}"
	exit 1
fi

if ! command -v docker >> "$log_file"; then
	echo -ne "${orange}[LOG] Uninstalling old versions of docker...${reset}"
	apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1) >> "$log_file"
	echo -ne "${orange}[LOG] Installing dependencies...${reset}"
	apt update -y >> "$log_file"
	apt install -y ca-certificates curl >> "$log_file"
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc >> "$log_file"
	chmod a+r /etc/apt/keyrings/docker.asc
	tee /etc/apt/sources.list.d/docker.sources >> "$log_file" <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
	apt update -y >> "$log_file"
	echo -ne "\r${orange}[LOG] Installing Docker...${reset}"
	if ! apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$log_file"; then
		echo -ne "\r${red}[LOG] Failed to install Docker${reset}\n"
		exit 1
	fi
	if ! systemctl is-active docker >> "$log_file"; then
		systemctl start docker
		if ! systemctl is-active docker >> "$log_file"; then
			echo -ne "\r${red}[LOG] A problem occurred during Docker installation${reset}\n"
			exit 1
		fi
	fi
	echo -ne "\r${green}[LOG] Docker has been installed successfully${reset}\n"
else
	if ! systemctl is-active docker >> "$log_file"; then
		echo -ne "${orange}[LOG] Docker is installed but inactive. Starting docker...${reset}"
		systemctl start docker
		echo -ne "\r${green}[LOG] Docker has been activated${reset}\n"
	else
		echo -ne "${green}[LOG] Docker is already installed${reset}\n"
	fi
fi

if ! command -v kubectl >> "$log_file"; then
	echo -ne "${orange}[LOG] Downloading kubectl...${reset}"
	if ! curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> "$log_file"; then
		echo -ne "\r${red}[LOG] Failed to download kubectl${reset}\n"
		exit 1
	fi
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" >> "$log_file"
	if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check >> "$log_file"; then
		echo -ne "\r${red}[LOG] Kubectl checksum FAILED${reset}\n"
		rm -f kubectl kubectl.sha256
		exit 1
	fi
	echo -ne "\r${orange}[LOG] Installing kubectl...${reset}"
	if ! install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; then
		echo -ne "\r${red}[LOG] Failed to install kubectl${reset}\n"
		rm -f kubectl kubectl.sha256
		exit 1
	fi
	rm -f kubectl kubectl.sha256
	echo -ne "\r${green}[LOG] Kubectl has been installed${reset}\n"
else
	echo -ne "${green}[LOG] Kubectl is already installed${reset}\n"
fi

if [ "$(echo $SHELL)" == "/usr/bin/zsh" ]; then
	if ! cat ~/.zshrc | grep 'autoload -Uz compinit' >> "$log_file"; then
		echo -ne "${orange}[LOG] Adding autocompletion for kubectl in zsh...${reset}"
		content=$(cat ~/.zshrc)
		cat << EOF > ~/.zshrc
autoload -Uz compinit
compinit
source <(kubectl completion zsh)
$content
EOF
		echo -ne "\r${green}[LOG] Autocompletion added for kubectl${reset}\n"
		echo -e "${blue}[LOG] Please run: source ~/.zshrc to apply autocompletion${reset}"
	else
		echo -ne "${green}[LOG] Autocompletion already added for kubectl${reset}\n"
	fi
elif [ "$(echo "$SHELL")" == "/usr/bin/bash" ]; then
	source /usr/share/bash-completion/bash_completion
	if ! cat ~/.bashrc | grep 'source <(kubectl completion bash)' >> "$log_file"; then
		echo -ne "${orange}[LOG] Adding autocompletion for kubectl in bash...${reset}"
		echo "source <(kubectl completion bash)" >> ~/.bashrc
		echo "alias k=kubectl" >> ~/.bashrc
		echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
		echo -ne "\r${green}[LOG] Autocompletion added for kubectl${reset}\n"
		echo -e "${blue}[LOG] Please run: source ~/.bashrc to apply autocompletion${reset}"
	else
		echo -ne "${green}[LOG] Autocompletion already added for kubectl${reset}\n"
	fi
fi

if ! command -v k3d >> "$log_file"; then
	echo -ne "${orange}[LOG] Installing k3d...${reset}"
	if ! curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash >> "$log_file"; then
		echo -ne "\r${red}[LOG] Failed to install k3d${reset}\n"
		exit 1
	fi
	echo -ne "\r${green}[LOG] K3d has been installed${reset}\n"
else
	echo -ne "${green}[LOG] K3d is already installed${reset}\n"
fi
