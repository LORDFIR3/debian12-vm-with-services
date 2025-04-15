Vagrant.configure("2") do |config|
	
	# Create vm
	config.vm.box = "generic/debian12"
	config.vm.provider "virtualbox" do |vb|
		vb.memory = "2048"
		vb.cpus = 2
		vb.customize ["modifyvm", :id, "--name", "test-vm"]
		vb.customize ["createhd", "--filename", "TEST.vdi", "--size", 20480] # Set 20GB disk
	end

	# Port forwarding for Zabbix frontend
	config.vm.network "private_network", ip: "192.168.56.10"
	config.vm.provision "file", source: "./provision/zabbix.conf.php", destination: "/tmp/zabbix.conf.php"	
	config.vm.provision "file", source: "./provision/template.yaml", destination: "/tmp/template.yaml"	
	config.vm.provision "file", source: "./provision/zabbix.env", destination: "/tmp/zabbix.env"	

	# Vm provisioning script
	config.vm.provision "shell", path: "./provision/install_zabbix.sh"
	config.vm.provision "shell", path: "./provision/install_vault.sh"
	config.vm.provision "shell", path: "./provision/install_jenkins.sh"
	config.vm.provision "shell", path: "./provision/map_services.sh"
	config.vm.provision "shell", path: "./provision/config_zabbix.sh"
end
