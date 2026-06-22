#!/bin/bash

if ! command -v docker &> /dev/null; then
	echo "[LOG] Uninstall old version of docker"
	sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
	sudo apt update -y
	sudo apt install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

	sudo apt update -y
	echo "[LOG] Installing Docker..."
	sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	if ! systemctl is-active docker &> /dev/null; then
		sudo systemctl start docker
		if ! systemctl is-active docker &> dev/null; then
			echo "[LOG] A problem occurred during installation"
		else
			echo "[LOG] Docker has been installed successfully"
		fi
		
	else
		echo "[LOG] Docker has been installed succesfully"
	fi
else
	if ! systemctl is-active docker &> /dev/null; then
		echo "[LOG] Docker is intalled but inactive. Starting docker..."
		sudo systemctl start docker
		echo "[LOG] Docker has been activated"
	else	
		echo "[LOG] Docker is already installed"
	fi
fi

if ! command -v kubectl &> /dev/null; then
	echo "[LOG] Install kubectl binary with curl..."
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
	echo "[LOG] Validate the kubectl binary..." 
	if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check &> /dev/null; then
		echo "[LOG] Kubectl: FAILED"
	fi
	echo "[LOG] Kubectl: OK"
	echo "[LOG] Installing kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	echo "[LOG] Kubectl has been installed"
	rm -f kubectl
	rm -f kubectl.sha256
else
	echo "[LOG] Kubectl is already installed"
fi

if [ "$(echo $SHELL)" == "/usr/bin/zsh" ]; then
	if ! cat ~/.zshrc | grep 'autoload -Uz compinit' &> /dev/null; then
		echo "[LOG] Add autocompletion for kubectl"
		content=$(cat ~/.zshrc)
		cat << EOF > ~/.zshrc
autoload -Uz compinit
compinit
source <(kubectl completion zsh)
$content
EOF
		echo "[LOG] Please run: source ~/.zshrc to apply autocompletion for kubectl"
	else
		echo "[LOG] Autocompletion already added for kubectl"
	fi
elif [ "$(echo "$SHELL")" == "/usr/bin/bash" ]; then
	source /usr/share/bash-completion/bash_completion
	if ! cat ~/.bashrc | grep 'source <(kubectl completion bash)' &> /dev/null; then
		echo "[LOG] Add autocompletion for kubectl"
		echo "source <(kubectl completion bash)" >> ~/.bashrc
		echo "alias k=kubectl" >> ~/.bashrc
		echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
		echo "[LOG] Please run: source ~/.bashrc to apply autocompletion"
	else
		echo "[LOG] Autocompletion already added for kubectl"
	fi	
fi

if ! command -v k3d &> /dev/null ; then
	echo "[LOG] Installing k3d"
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash &> /dev/null
	echo "[LOG] K3d has been installed"
else
	echo "[LOG] K3d is already installed"
fi
