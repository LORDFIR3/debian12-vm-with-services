#!/bin/bash
set -e

# Install OpenJDK
apt install -y  openjdk-17-jdk

# Get Jenkins repository
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
apt update 
apt install -y jenkins git curl gnupg2

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

### TOTALLY NOT VERY SECURE BS. ASK IF IT IS NEEDED !!!###
# Print out initial admin password
ADMIN_PASS=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "===================================================================="
echo "Initial Jenkins admin password (use this to unlock Jenkins UI):"
echo "$ADMIN_PASS"
echo "===================================================================="
