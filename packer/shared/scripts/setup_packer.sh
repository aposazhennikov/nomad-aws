#!/usr/bin/env bash
set -e

logger() {
	DT=$(date '+%Y/%m/%d %H:%M:%S')
	echo "################################################################################"
	echo "			Date: ${DT} 		Script: $(basename $0):"
	echo "$1"
	echo "################################################################################"
}

CNI_VERSION="v1.3.0"
CFSSL_VERSION="1.6.5"
export DEBIAN_FRONTEND="noninteractive"

logger "Ugrade the box"
sleep 10
# check apt is not locked
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
	echo "Waiting while apt is locked..."
	sleep 5
done


# Update packages
apt-get -y update
# Sometimes gce assets don't work, added "&& true" so we don't fail on upgrades
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --fix-missing upgrade && true

logger "Install dependencies"
# Install dependencies
apt-get -y install software-properties-common dnsutils ca-certificates curl jq gpg net-tools expect

# Add HashiCorp GPG key
logger "Adding HashiCorp repository"
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Add Docker Repository
logger "Install Docker repository"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo \
	"deb [arch="$(dpkg --print-architecture)" signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "${VERSION_CODENAME}")" stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
# Add Graphana Agent Repository

logger "Install Graphana Agent repository"
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Update packages
logger "Updating packages"
apt-get -y update

# Install Hashicorp stack
logger "Install Hashicorp stack"
apt-get install -y nomad consul consul-template docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin grafana-agent-flow

# Install autocomplete
logger "Install autocomplete and disable service"
for service in nomad consul grafana-agent-flow; do
	if [[ $service != "grafana-agent-flow" ]]; then
		${service} -autocomplete-install
	fi
	systemctl disable "${service}"
done

logger "Install CNI plugins"

# Download and install CNI plugins
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}".tgz
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins.tgz
rm -f cni-plugins.tgz

logger "Download and install CFSSL"


curl -s -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64" -o /usr/local/bin/cfssl
curl -s -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64" -o /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson

logger "Install Gitlab Runner"

curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
chmod +x /usr/local/bin/gitlab-runner
useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
gitlab-runner start &

logger "Complete installation of Gitlab Runner"


logger "Create new ansible user"

useradd -m -s /bin/bash -G sudo ansible
mkdir -p /home/ansible/.ssh
echo "ssh-ed25519 123 ansible" | tee -a /home/ansible/.ssh/authorized_keys
chown ansible:ansible /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
echo "ansible ALL=(ALL) NOPASSWD:ALL" |  tee /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible
echo "Ansible user has been created and configured with sudo privileges and SSH key."
logger "Ansible user has been created and configured with sudo privileges and SSH key."

logger "Changing security setting of the Kernel"
cp /opt/shared/configs/sysctl.d/99-perf.conf /etc/sysctl.d/99-perf.conf

logger "Copying configs"

cp -r /opt/shared/configs/consul/* /etc/consul.d/
cp -r /opt/shared/configs/nomad/* /etc/nomad.d/

usermod -aG docker ansible
usermod -aG docker admin
usermod -aG nomad ansible
usermod -aG nomad admin


logger "Cleanup"
apt-get -y autoremove
apt-get -y clean
rm -rf /tmp/* /var/lib/apt/lists/*
# Remove unnecessary packages
apt remove -y exim*


logger "Completed installing!"

