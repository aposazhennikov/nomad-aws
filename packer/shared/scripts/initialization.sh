#!/bin/bash
logger() {
	DT=$(date '+%Y/%m/%d %H:%M:%S')
	echo "${DT} initialization.sh: $1"
}

REGION="$1"
export REGION="$REGION"
echo "export REGION=$REGION" >> ~/.bashrc


logger "Add important env to .bashrc"

# Consul first
echo "export CONSUL_HTTP_SSL=true" >> ~/.bashrc
echo "export CONSUL_CLIENT_CERT=/etc/consul.d/certs/server.pem" >> ~/.bashrc
echo "export CONSUL_CLIENT_KEY=/etc/consul.d/certs/server_key.pem" >> ~/.bashrc
echo "export CONSUL_CACERT=/etc/consul.d/certs/ca.pem" >> ~/.bashrc
echo "export CONSUL_HTTP_ADDR=https://127.0.0.1:8501" >> ~/.bashrc
# Nomad second
echo "export NOMAD_ADDR=https://127.0.0.1:4646" >> ~/.bashrc
echo "export NOMAD_CACERT=/opt/certs/ca.pem" >> ~/.bashrc
echo "export NOMAD_CLIENT_CERT=/opt/certs/server.pem" >> ~/.bashrc
echo "export NOMAD_CLIENT_KEY=/opt/certs/server_key.pem" >> ~/.bashrc
echo "export NOMAD_TLS_SERVER_NAME=server.global.nomad" >> ~/.bashrc

logger "Copying important files"


cp -r /opt/certs/ /etc/consul.d/
logger "Change .hcl config files, sed variable REGION"

sed -i -e "s|\$REGION|${REGION}|g" /etc/consul.d/consul.hcl
sed -i -e "s|\$REGION|${REGION}|g" /etc/nomad.d/nomad.hcl


logger "Change owner and mod on important file"
chown -R consul:consul /etc/consul.d/ && \
chown -R consul:consul /opt/consul/

chmod -R 755 /etc/consul.d/ && chmod -R 755 /opt/certs/ && chmod -R 755 /opt/consul/ 

chown -R nomad:nomad /opt/certs/ && chown -R nomad:nomad /opt/nomad/ && \
chown -R nomad:nomad /etc/nomad.d/
chmod -R 755 /etc/nomad.d/ && chmod -R 755 /opt/nomad/ 


logger "Starting consul server"
source /root/.bashrc
cat /etc/consul.d/consul.hcl
logger ""
logger ""
logger ""

systemctl start consul
journalctl -xeu consul.service

logger ""
logger ""
logger ""

systemctl status consul.service
sleep 5
logger ""
logger ""
logger ""

# Bootstraping Consul server and transfer MGMT TOKEN to bashrc and to the VLT
logger "Bootstraping consul server"
consul acl bootstrap >/etc/consul.d/bootstrap
cat /etc/consul.d/bootstrap


export CONSUL_MGMT_TOKEN=$(cat /etc/consul.d/bootstrap | grep "SecretID:" | awk '{print $2}')


logger "Completed"


logger "Adding token to bashrc file"

echo "export CONSUL_HTTP_TOKEN=${CONSUL_MGMT_TOKEN}" >>~/.bashrc

sed -i "s/\$token/$CONSUL_MGMT_TOKEN/g" /etc/nomad.d/jobs/fabio.hcl

# Setting agent-token to turn off warning notificaton from Consul, you should do it on every server!
consul acl set-agent-token -token="$CONSUL_MGMT_TOKEN" agent "$CONSUL_MGMT_TOKEN"

# Adding it Tokens to the .hcl configuration files
logger "Adding tokens to Consul & Nomad configuration files"
sed -i "s|\$token|\"${CONSUL_MGMT_TOKEN}\"|g" /etc/nomad.d/nomad.hcl

# Starting and bootstraping Nomad server
logger "Starting and bootstraping Nomad server"
cat /etc/nomad.d/nomad.hcl


systemctl start nomad
systemctl enable consul
systemctl enable nomad

loger "Watch Nomad status"

systemctl status nomad
journalctl -xeu nomad.service

nomad acl bootstrap > /etc/nomad.d/bootstrap

export NOMAD_TOKEN=$(grep "Secret ID" /etc/nomad.d/bootstrap | awk -F'= ' '{print $2}')
echo "export NOMAD_TOKEN=$NOMAD_TOKEN" >> ~/.bashrc

cp /root/.bashrc /home/admin
logger "Completed initialization"

