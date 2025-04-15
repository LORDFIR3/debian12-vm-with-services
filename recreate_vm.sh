#!/bin/bash
set -e

DISK_NAME=$1

# Destroy VM
echo "Destroing VM"
vagrant halt
vagrant destroy

# Delete disk
echo "Deleting VM disk"
VBoxManage closemedium disk $DISK_NAME --delete

# Creating  VM
echo "Creating VM"
vagrant up

echo "VM created !"
exit 0

