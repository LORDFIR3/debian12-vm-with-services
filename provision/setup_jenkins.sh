#!/bin/bash
set -e -x

# Variables
CASC_JENKINS_CONF="/var/lib/jenkins/jenkins.yaml"
PLUGINS_FILE="/tmp/plugins.txt"
JENKINS_WAR_FILE="/usr/share/java/jenkins.war"
JENKINS_ADMIN_ID="Lordfire"
JENKINS_ADMIN_PASSWD="admin"
JENKINS_PLUGINS_DIR="/var/lib/jenkins/plugins"
# Update and Install dependencies
sudo apt update
sudo apt install -y openjdk-17-jre curl gnupg2

# Add Jenkins repo and key
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Disabling Jenkins setup wizard
echo 'JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Djenkins.CASC_JENKINS_CONFIG=/var/lib/jenkins/jenkins.yaml"' | sudo tee -a /etc/default/jenkins

# Install jenkins-plugin-manager
wget https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar -O /tmp/jenkins-plugin-manager-2.13.2.jar

cat > $PLUGINS_FILE << EOF
ant:latest
antisamy-markup-formatter:latest
authorize-project:latest
build-timeout:latest
cloudbees-folder:latest
configuration-as-code:latest
credentials-binding:latest
email-ext:latest
git:latest
github-branch-source:latest
gradle:latest
ldap:latest
mailer:latest
matrix-auth:latest
pam-auth:latest
pipeline-github-lib:latest
pipeline-stage-view:latest
ssh-slaves:latest
timestamper:latest
workflow-aggregator:latest
ws-cleanup:latest
EOF

# Install configuration-as-code plugin
java -jar /tmp/jenkins-plugin-manager-2.13.2.jar \
    --war $JENKINS_WAR_FILE \
    --plugin-download-directory $JENKINS_PLUGINS_DIR \
    --plugin-file $PLUGINS_FILE \
    --plugins delivery-pipeline-plugin:1.3.2 deployit-plugin

# Install rest of the plugins
java -jar /tmp/jenkins-plugin-manager-2.13.2.jar \
    --war $JENKINS_WAR_FILE \
    --plugin-file $PLUGINS_FILE \
    --plugin-download-directory $JENKINS_PLUGINS_DIR \
    --verbose

sudo chown -R jenkins:jenkins "/var/lib/jenkins/plugins"

# Create Configuration-as-code file
cat > $CASC_JENKINS_CONF << EOF
jenkins:
    securityRealm:
        local:
            allowsSignup: false
            users:
            - id: $JENKINS_ADMIN_ID
              password: $JENKINS_ADMIN_PASSWD
    authorizationStrategy:
        globalMatrix:
            permissions:
                - "USER:Overall/Administer:$JENKINS_ADMIN_ID"
                - "GROUP:Overall/Read:authenticated"
    remotingSecurity:
        enabled: true

unclassified:
    location:
        url: http://localhost:8080/
EOF

# Fix permssions
chown -R jenkins:jenkins "$CASC_JENKINS_CONF"

# IDK why this is works, but it works
java -jar $JENKINS_WAR_FILE --config=$CASC_JENKINS_CONF &
sleep 7s
pkill java

# Skips "Customize Jenkins" screen
echo $(jenkins --version) > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
echo $(jenkins --version) > /var/lib/jenkins/jenkins.install.UpgradeWizard.state 
chown jenkins:jenkins /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins
systemctl restart jenkins
echo "Yipee Jenkins works!"

