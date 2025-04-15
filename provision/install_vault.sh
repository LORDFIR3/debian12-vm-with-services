#!/bin/bash
set -e

# Install Vault
echo "Installing Vault"
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
echo "Done !"

# Create directory for server data
echo "Creating directory"
mkdir /tmp/vault-data

# Create self-signed certificate
echo "Creating cerificates"
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 \
    -nodes -keyout /tmp/vault-key.pem -out /tmp/vault-cert.pem \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# Create server configuration file
echo "Creating vault-server.hcl"
cat > /tmp/vault-server.hcl << EOF
api_addr                = "https://127.0.0.1:8200"
cluster_addr            = "https://127.0.0.1:8201"
cluster_name            = "vault-cluster"
disable_mlock           = true
ui                      = true

listener "tcp" {
address       = "127.0.0.1:8200"
tls_cert_file = "/tmp/vault-cert.pem"
tls_key_file  = "/tmp/vault-key.pem"
}

backend "raft" {
path    = "/tmp/vault-data"
node_id = "vault-server"
}
EOF
echo "Done !"

# Vault initalization
echo "Initializing Vault"

systemctl start vault.service
systemctl enable vault.service
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
vault operator init >> keys

# Vault unsealing
unseal_vault() {
	for ((n=1; n<4; n++));
	 do
		KEY=$(awk -F': ' -v num=$n '$0 ~ "Unseal Key " num ":"  {print $2}' keys)
		vault operator unseal $KEY
	 done
}
echo "Starting unseal"
unseal_vault
echo "Finished unseal"

# rm -f keys - йой най буде, і так потім логінитись в рут для того щоб юзера зробити
echo "Vault installed"


