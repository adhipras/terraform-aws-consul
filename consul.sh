#!/bin/bash

# Arguments
AWS_ACCESS_KEY=$1
AWS_SECRET_KEY=$2
AWS_REGION=$3
CONSUL_SERVER_NODES=$4
CONSUL_SERVER_ADDRESS=$5
CONSUL_SERVER_NAME=$6
CONSUL_TAG_KEY=$7
CONSUL_TAG_VALUE=$8

set -e

echo "Installing dependencies..."
sudo apt install -y unzip
sudo apt update
sudo apt install -y jq

echo "Checking the latest Consul version..."
CONSUL_CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
CONSUL_VERSION=$(curl -s "${CONSUL_CHECKPOINT_URL}"/consul | jq .current_version | tr -d '"')

echo "Downloading Consul ${CONSUL_VERSION}..."
cd /tmp/
curl https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o consul.zip

echo "Installing Consul ${CONSUL_VERSION}..."
cd /tmp/
unzip consul.zip >/dev/null
chmod +x consul
sudo chown root:root consul
sudo mv consul /usr/local/bin/consul

# Enable autocompletion
echo "Enable Consul command autocompletion..."
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

# Create Consul user
echo "Create Consul user..."
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul/data
sudo chown --recursive consul:consul /opt/consul

# Configure Consul agent
echo "Configure Consul agent..."
sudo mkdir --parents /etc/consul.d
sudo tee /etc/consul.d/server.json > /dev/null << EOF
{
  "addresses": {
    "http": "0.0.0.0"
  },
  "advertise_addr": "${CONSUL_SERVER_ADDRESS}",
  "bind_addr": "${CONSUL_SERVER_ADDRESS}",
  "bootstrap_expect": ${CONSUL_SERVER_NODES},
  "client_addr": "0.0.0.0",
  "data_dir": "/opt/consul/data",
  "datacenter": "consul-${AWS_REGION}",
  "disable_remote_exec": true,
  "disable_update_check": true,
  "leave_on_terminate" : true,
  "log_level": "warn",
  "node_name": "${CONSUL_SERVER_NAME}",
  "retry_join": ["provider=aws tag_key=${CONSUL_TAG_KEY} tag_value=${CONSUL_TAG_VALUE} access_key_id=${AWS_ACCESS_KEY} secret_access_key=${AWS_SECRET_KEY}"],
  "server": true,
  "ui": true
}
EOF
sudo chmod 0644 /etc/consul.d/server.json
sudo chown --recursive consul:consul /etc/consul.d

# Configure the Consul service
echo "Configure Consul service..."
sudo tee /usr/lib/systemd/system/consul.service > /dev/null << EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul