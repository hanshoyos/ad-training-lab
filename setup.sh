#!/bin/bash

# Function to create the .env file with user input
create_env_file() {
  echo "Creating .env file..."
  read -p "Enter Proxmox API ID (e.g., userprovisioner@pve!provisioner-token): " PROXMOX_API_ID
  read -p "Enter Proxmox API Token: " PROXMOX_API_TOKEN
  read -p "Enter Proxmox Node IP (e.g., 192.168.1.X): " PROXMOX_NODE_IP
  read -p "Enter Proxmox Node Name (e.g., pve): " PROXMOX_NODE_NAME

  cat <<EOF > .env
PROXMOX_API_ID=$PROXMOX_API_ID
PROXMOX_API_TOKEN=$PROXMOX_API_TOKEN
PROXMOX_NODE_IP=$PROXMOX_NODE_IP
PROXMOX_NODE_NAME=$PROXMOX_NODE_NAME
EOF

  echo ".env file created successfully."
}

# Function to source .env file
source_env() {
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
  else
    echo ".env file not found!"
    exit 1
  fi
}

# Function to configure Proxmox users and roles
configure_proxmox_users() {
  echo "Configuring Proxmox users and roles..."
  ssh root@$PROXMOX_NODE_IP << EOF
pveum role add provisioner -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Pool.Audit SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Console VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
pveum user add userprovisioner@pve
pveum aclmod / -user userprovisioner@pve -role provisioner
pveum user token add userprovisioner@pve provisioner-token --privsep=0
pveum aclmod /storage/local --user userprovisioner@pve --role PVEDatastoreAdmin --token $PROXMOX_API_ID
EOF
  if [ $? -eq 0 ]; then
    echo "Proxmox user configuration successful."
  else
    echo "Proxmox user configuration failed." >&2
    exit 1
  fi
}

# Function to download all ISO files on Proxmox server
download_all_iso_files_proxmox() {
  echo "Downloading all ISO files on Proxmox server..."
  ssh root@$PROXMOX_NODE_IP << EOF
cd /var/lib/vz/template/iso/ || exit 1
nohup wget -O virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso &
nohup wget -O windows10.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso &
nohup wget -O windows_server_2019.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso &
nohup wget -O ubuntu-22.iso https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso &
EOF
}

# Function to download a specific ISO file on Proxmox server
download_specific_iso_file_proxmox() {
  local url=$1
  local filename=$2
  echo "Downloading $filename on Proxmox server..."
  ssh root@$PROXMOX_NODE_IP << EOF
cd /var/lib/vz/template/iso/ || exit 1
nohup wget -O $filename $url &
EOF
}

# Submenu for downloading specific ISO files
download_iso_files_proxmox_menu() {
  echo "Choose an ISO to download on Proxmox server:"
  echo "1) Download all ISO files"
  echo "2) Download Virtio ISO"
  echo "3) Download Windows 10 ISO"
  echo "4) Download Windows Server 2019 ISO"
  echo "5) Download Ubuntu 22.04 ISO"
  echo "6) Back to main menu"
  read -p "Enter choice [1-6]: " sub_choice
  case $sub_choice in
    1) download_all_iso_files_proxmox ;;
    2) download_specific_iso_file_proxmox "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" "virtio-win.iso" ;;
    3) download_specific_iso_file_proxmox "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso" "windows10.iso" ;;
    4) download_specific_iso_file_proxmox "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" "windows_server_2019.iso" ;;
    5) download_specific_iso_file_proxmox "https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso" "ubuntu-22.iso" ;;
    6) show_menu ;;
    *) echo "Invalid choice!"; download_iso_files_proxmox_menu ;;
  esac
}

# Main menu
show_menu() {
  echo "Main Menu:"
  echo "1) Create .env file"
  echo "2) Configure Proxmox users and roles"
  echo "3) Download ISO files on Proxmox server"
  echo "4) Proceed with the setup"
  echo "5) Exit"
  read -p "Enter choice [1-5]: " main_choice
  case $main_choice in
    1) create_env_file ;;
    2) source_env && configure_proxmox_users ;;
    3) source_env && download_iso_files_proxmox_menu ;;
    4) proceed_with_setup ;;
    5) exit 0 ;;
    *) echo "Invalid choice!"; show_menu ;;
  esac
}

# Function to proceed with the setup
proceed_with_setup() {
  # Step 1: Navigate to the ad-training-lab directory
  echo "Step 1: Navigating to the ad-training-lab directory..."
  cd ~/ad-training-lab || { echo "Directory ad-training-lab not found"; exit 1; }

  # Step 3: Make the required scripts executable
  echo "Step 3: Making the required scripts executable..."
  chmod +x requirements.sh packer/task_templating.sh terraform/task_terraforming.sh

  # Step 4: Run the requirements.sh script with sudo
  echo "Step 4: Running the requirements.sh script..."
  sudo ./requirements.sh

  # Step 5: Run the task_templating.sh script inside packer/
  echo "Step 5: Running the task_templating.sh script inside packer/..."
  cd ~/ad-training-lab/packer || { echo "Directory packer not found"; exit 1; }
  ./task_templating.sh

  # Step 6: Navigate back to the ad-training-lab directory
  echo "Step 6: Navigating back to the ad-training-lab directory..."
  cd ~/ad-training-lab

  # Step 7: Run the task_terraforming.sh script inside terraform/
  echo "Step 7: Running the task_terraforming.sh script inside terraform/..."
  cd ~/ad-training-lab/terraform || { echo "Directory terraform not found"; exit 1; }
  ./task_terraforming.sh

  # Step 8: Navigate back to the ad-training-lab directory
  echo "Step 8: Navigating back to the ad-training-lab directory..."
  cd ~/ad-training-lab

  # Step 9: Clone the Snare-Products repository
  echo "Step 9: Cloning the Snare-Products repository..."
  cd ~/ad-training-lab/ansible || { echo "Directory ansible not found"; exit 1; }
  git clone https://github.com/hanshoyos/Snare-Products.git

  # Step 10: Run the ansible playbook inside ansible/
  echo "Step 10: Running the ansible playbook inside ansible/..."
  ansible-playbook main.yml

  # Step 11: Completion message
  echo "Step 11: Setup and configuration complete. Enjoy 🤞"
}

# Show the main menu
show_menu
