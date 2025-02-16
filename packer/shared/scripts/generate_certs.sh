#!/bin/bash
set -e

logger() {
	DT=$(date '+%Y/%m/%d %H:%M:%S')
	echo "${DT} generate_certs.sh: $1"
}

# Default variables
CERT_DIR="/opt/certs/"
DATACENTER=${1:-'ap-south-1'}
DOMAINS=("global.nomad" "$DATACENTER.consul")

logger "Creating folder for certs. Flag -p for creating parents if it's necessary."

mkdir -p $CERT_DIR
cd $CERT_DIR

logger "Creating CA."
cfssl print-defaults csr | cfssl gencert -cn="Trident" -initca - | cfssljson -bare ca

# Default configuration for certs.
cat <<EOF >cfssl.json
{
  "signing": {
    "default": {
      "expiry": "87600h",
      "usages": ["signing", "key encipherment", "server auth", "client auth"]
    }
  }
}
EOF

logger "Creating certs for server & client"
for role in server client; do

	# CN_LIST need for CN it might looks like 'Subject: CN = "server.global.nomad,server.dc1.consul"'.
	CN_LIST=""
	for domain in "global.nomad" "$DATACENTER.consul"; do
		# If CN_LIST is not empty add ',' at the end of the row.
		if [ ! -z "$CN_LIST" ]; then
			CN_LIST="$CN_LIST,"
		fi
		CN_LIST="${CN_LIST}${role}.${domain}"
	done

	# HOSTNAME_STR need for 'X509v3 Subject Alternative Name' field, it might looks like
	# 'DNS:server.global.nomad, DNS:server.dc1.consul, DNS:localhost, IP Address:127.0.0.1, IP Address:10.114.0.3'.
	HOSTNAME_STR="${CN_LIST},localhost,127.0.0.1"

	logger "Starting generate certs"
	echo '{}' | cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=cfssl.json \
		-cn="$CN_LIST" \
		-hostname="$HOSTNAME_STR" \
		- | cfssljson -bare $role

	logger "A certificate has been generated for $role with CN $CN and SAN $HOSTNAME_STR"
done

echo "Certificate generation completed."

logger "Renaming certs, changing "-" to "_" in certificate names"
for file in *-*; do mv "$file" "${file//-/_}"; done