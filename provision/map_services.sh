#!/bin/bash
set -e

# Global variablles
ZABBIX_DIR="/usr/share/zabbix/"
ZABBIX_CONFIG="/etc/apache2/sites-available/zabbix.local.conf"
JENKINS_CONFIG="/etc/apache2/sites-available/jenkins.local.conf"
VHOSTS_ENTRY=(
	"127.0.0.1	zabbix.local"
	"127.0.0.1	jenkins.local"
	"127.0.0.1	vault.local"
)

# Updating /etc/hosts

for entry in "${VHOSTS_ENTRY[@]}"; do
	if ! grep "$entry" /etc/hosts; then
		echo "Adding $entry to hosts"
		echo "$entry" | tee -a /etc/hosts
	else
		echo "Already here!"
	fi
done

### ZABBIX MAPPING ###

echo "Mapping Zabbix to zabbix.local"
# Create apache virtual host
echo "Creating Apache virtual host for Zabbix at $ZABBIX_CONFIG"
sudo cat >> $ZABBIX_CONFIG << EOF
<VirtualHost *:80>
     ServerName zabbix.local
 
     DocumentRoot $ZABBIX_DIR/ui
 
     <Directory "$ZABBIX_DIR/ui">
         Options FollowSymLinks
         AllowOverride All
         Require all granted
      </Directory>
  
      ErrorLog \${APACHE_LOG_DIR}/zabbix_error.log
      CustomLog \${APACHE_LOG_DIR}/zabbix_access.log combined
</VirtualHost>
EOF

# Update /etc/hosts
echo "$ZABBIX_ENTRY" | sudo tee -a /etc/hosts

### JENKINS MAPPING ###
echo "Creating Apache reverse proxy config for Jenkins at $JENKINS_CONFIG"
sudo cat > $JENKINS_CONFIG <<EOF
<VirtualHost *:80>
    ServerName jenkins.local

    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/

    ErrorLog \${APACHE_LOG_DIR}/jenkins_error.log
    CustomLog \${APACHE_LOG_DIR}/jenkins_access.log combined
</VirtualHost>
EOF

# Enable modules
a2enmod proxy proxy_http >/dev/null

echo "Disabling default Apache site"
a2dissite 000-default.conf >/dev/null 2>&1

# Enable zabbix site
echo "Enabling new sites"
a2ensite zabbix.local.conf
a2ensite jenkins.local.conf

echo "Reload apache2"
systemctl reload apache2

