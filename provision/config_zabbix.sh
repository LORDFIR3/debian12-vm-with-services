#!/bin/bash
set -e -x

apt update
apt install -y curl jq
#HOSTNAME="debian12-vm"
#IP_ADDR="127.0.0.1"
#ZABBIX_USERNAME="Admin"
#ZABBIX_PASSWD="zabbix"

#TEMPLATE="$1"
#ZABBIX_URL="http://zabbix.local/api_jsonrpc.php"
#DB_USER="zabbix"
#USER_PASSWD="zabbixpass"
#DB_NAME="zabbix"

#TEMPLATE_NAME="Linux_server_and_services"
#HOST_NAME="debian-vm"
source /tmp/zabbix.env

AUTH_TOKEN=$(curl -X POST -H "Content-Type: application/json" -d "{
  \"jsonrpc\": \"2.0\",
  \"method\": \"user.login\",
  \"params\": {
    \"username\": \"$ZABBIX_USERNAME\",
    \"password\": \"$ZABBIX_PASSWD\"
  },
  \"id\": 1
}" http://zabbix.local/api_jsonrpc.php | jq -r '.result')


import_template() {
    local escaped_yaml=$(jq -Rs . < "$TEMPLATE")
    local json_payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "configuration.import",
  "params": {
    "format": "yaml",
    "rules": {
      "templates": {
        "createMissing": true, "updateExisting": true},
      "items": {
        "createMissing": true, "updateExisting": true},
      "triggers": {
        "createMissing": true, "updateExisting": true},
      "graphs": {
        "createMissing": true, "updateExisting": true},
      "discoveryRules": {
        "createMissing": true, "updateExisting": true}
    },
    "source": $escaped_yaml
  },
  "id": 2
}
EOF
)

    echo "Sending request..."
    curl --request POST \
      --url "$ZABBIX_URL" \
      --header "Content-Type: application/json" \
      --header "Authorization: Bearer $AUTH_TOKEN" \
      --data "$json_payload"

    echo "Imported $TEMPLATE"
}

get_next_host_id() {
    local next_host_id
    next_host_id=$(mysql -u"$DB_USER" -p"$USER_PASSWD" -D"$DB_NAME" --skip-column-names \
    --execute="SELECT COALESCE(MAX(hostid), 0) + 1 FROM hosts;" | sed 's/^ *//;s/ *$//')
    echo "$next_host_id"
}

get_next_interface_id() {
    local next_int_id

    next_int_id=$(mysql -u"$DB_USER" -p"$USER_PASSWD" -D "$DB_NAME" --skip-column-names \
    --execute="SELECT COALESCE(MAX(interfaceid), 0) + 1 FROM interface;" | sed 's/^ *//;s/ *$//')

    if [ -z "$next_int_id" ]; then
        echo "Failed to retrieve the next interface ID."
        exit 1
    fi

    echo "$next_int_id"
}

add_host() {
    local hostname="$1"
    local ip_address="$2"
    local host_id
    local interface_id

    echo "Adding host $hostname with IP $ip_address..."

    # Get the next host ID
    host_id=$(get_next_host_id)
    if [ -z "$host_id" ]; then
        echo "Failed to get the next host ID."
        return 1
    fi  

    echo "Host ID: $host_id"

    local sql_host="INSERT INTO hosts (hostid, host, name, status, description) VALUES ('$host_id', '$hostname', '$hostname', 0, 'local vm') RETURNING hostid;"
    local result
    result=$(mysql -u"$DB_USER" -p"$USER_PASSWD" -D"$DB_NAME" --execute="$sql_host" 2>&1 | sed 's/^ *//;s/ *$//')

    if [[ "$result" == *"ERROR"* || -z "$result" ]]; then
        echo "Failed to add host $hostname. SQL Result: $result"
        return 1
    fi  

    # Get the next interface ID
    interface_id=$(get_next_interface_id)
    if [ -z "$interface_id" ]; then
        echo "Failed to get the next interface ID."
        return 1
    fi  

    echo "Next interface ID: $interface_id"

    # Insert the IP address into the interface table
    local sql_interface="INSERT INTO interface (interfaceid, hostid, main, ip, dns, port) VALUES ('$interface_id', '$host_id','1', '$ip_address', '$hostname', 10050);"
    result=$(mysql -u"$DB_USER" -p"$USER_PASSWD" -D"$DB_NAME" --execute="$sql_interface" 2>&1)

    if [[ "$result" == *"ERROR"* ]]; then
        echo "Failed to add IP address $ip_address for host ID $host_id. SQL Result: $result"
        return 1
    fi

    echo "Successfully added IP address $ip_address for host $hostname (host ID: $host_id, interface ID: $interface_id)."
    return 0
}

link_template_to_host() {
    local host_id=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"host.get\",
        \"params\": {
            \"filter\": { \"host\": [\"$HOSTNAME\"] }
        },
        \"id\": 1
        }" "$ZABBIX_URL" | jq -r '.result[0].hostid')

    local template_id=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"template.get\",
        \"params\": {
                \"filter\": { \"host\": [\"$TEMPLATE_NAME\"] }
        },
        \"id\": 1
        }" "$ZABBIX_URL" | jq -r '.result[0].templateid')

    curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"host.update\",
        \"params\": {
            \"hostid\": \"$host_id\",
            \"templates\": [{\"templateid\": \"$template_id\"}]
        },
        \"id\": 1
    }" "$ZABBIX_URL"
}

main() {
    import_template
    add_host "$HOSTNAME" "$IP_ADDR"
        if [ $? -eq 0 ]; then
            echo -e "Successfully processed host \033[1;32m$hostname\033[0m with IP \033[1;32m$ip_address\033[0m."; sleep 0.5
            echo -e "";
        fi
    link_template_to_host
}

main

