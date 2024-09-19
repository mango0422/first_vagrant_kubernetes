#!/bin/bash

role=$1

# Common tasks for master and worker nodes (skip for nfs)
if [ "$role" != "nfs" ]; then
    sudo swapoff -a
    sudo sed -i '$s/^/#/' /etc/fstab
    sudo apt-get update -y
    sudo apt`-get install -y apt-transport-https ca-certificates curl gpg software-properties-common
    
    # Kubernetes repository and containerd setup
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl containerd
    
    sudo systemctl enable --now kubelet
    sudo apt-mark hold kubelet kubeadm kubectl containerd
    
    # Sysctl settings for Kubernetes
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system
    
    # Containerd setup
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
fi

# Create users and configure SSH settings for each role
if [ "$role" == "master" ]; then
  # Create master user
  sudo useradd -m -s /bin/bash master
  echo 'master:master' | sudo chpasswd
  sudo usermod -aG sudo master
  echo "master ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/master
  
  # Setup Kubernetes master
  sudo kubeadm init --apiserver-advertise-address=192.168.0.99 --pod-network-cidr=10.244.0.0/16 --service-cidr=192.168.1.0/24 --node-name=master
  mkdir -p /home/master/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/master/.kube/config
  sudo chown master:master /home/master/.kube/config

  echo "Master node setup completed"

elif [ "$role" == "worker" ]; then
  # Create worker user
  sudo useradd -m -s /bin/bash worker
  echo 'worker:worker' | sudo chpasswd
  sudo usermod -aG sudo worker
  echo "worker ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/worker

  echo "Run 'kubeadm join' command from the master node to join this worker."

elif [ "$role" == "nfs" ]; then
  # Create nfs user
  sudo useradd -m -s /bin/bash nfs
  echo 'nfs:nfs' | sudo chpasswd
  sudo usermod -aG sudo nfs
  echo "nfs ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/nfs

  # Install and configure NFS server
  sudo apt update
  sudo apt install nfs-kernel-server -y
  sudo mkdir /mnt/nfs_share
  sudo chown nobody:nogroup /mnt/nfs_share
  sudo chmod 777 /mnt/nfs_share
  echo "/mnt/nfs_share 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
  sudo exportfs -rav
  sudo systemctl start nfs-kernel-server
  sudo systemctl enable nfs-kernel-server

  echo "NFS server setup completed"
fi

# Enable password-based SSH login and restart the SSH service
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo systemctl restart ssh
