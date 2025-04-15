#!/bin/bash
set -e
set -x

# Install Zabbix and configure it

# Install dependencies
apt update
apt install -y wget gnupg2 lsb-release apache2 php php-mysql mariadb-server mariadb-client libapache2-mod-php php-bcmath php-mbstring php-xml php-gd php-ldap php-json php-mysql unzip

# Add Zabbix package
wget https://repo.zabbix.com/zabbix/7.2/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.2+debian12_all.deb
dpkg -i zabbix-release_latest_7.2+debian12_all.deb
apt update

# Install Zabbix server, agent, frontend
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Create database
mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -e "create user zabbix@localhost identified by 'zabbixpass';"
mysql -e "grant all privileges on zabbix.* to zabbix@localhost;"
mysql -e "flush privileges;"

# Import init schema
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix

# Configure Zabbix server
sed -i 's/# DBPassword=/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf

# Config file to skip web setup
mv /tmp/zabbix.conf.php /etc/zabbix/web/

# Configure Zabbix agent
sudo cat > /etc/zabbix/zabbix_agentd.d/service-monitoring.conf << EOF
UserParameter=zabbix-server.status, systemctl is-active zabbix-server
UserParameter=jenkins.status, systemctl is-active jenkins
UserParameter=vault.status, systemctl is-active vault
EOF

# Enable and start services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

