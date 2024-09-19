Vagrant.configure("2") do |config|

  # Define the base box
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20240823.0.1"

  # Master node configuration
  config.vm.define "master" do |master|
    master.vm.hostname = "master"

    # Bridged network for internet access and SSH with static IP
    master.vm.network "public_network", ip: "192.168.0.99", bridge: "Intel(R) Wi-Fi 6 AX201 160MHz"

    master.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end
    master.vm.provision "shell", path: "bootstrap.sh", args: ["master"]
  end

  # Worker node configuration
  (1..3).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.hostname = "worker#{i}"

      # Bridged network for internet access and SSH with static IP
      worker.vm.network "public_network", ip: "192.168.0.#{100 + i}", bridge: "Your_Bridged_Interface_Name"

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = 3072
        vb.cpus = 1
      end
      worker.vm.provision "shell", path: "bootstrap.sh", args: ["worker"]
    end
  end

  # NFS server configuration
  config.vm.define "nfs" do |nfs|
    nfs.vm.hostname = "nfs"

    # Bridged network for internet access and SSH with static IP
    nfs.vm.network "public_network", ip: "192.168.0.105", bridge: "Your_Bridged_Interface_Name"

    nfs.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 1
    end
    nfs.vm.provision "shell", path: "bootstrap.sh", args: ["nfs"]
  end

end
