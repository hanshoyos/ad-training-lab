#!/bin/bash

LOGFILE=setup.log

log() {
  echo "$1" | tee -a $LOGFILE
}

os_package_updates_and_installs_menu() {
  echo "OS Package Updates and Installs Menu:"
  echo "1) Update and upgrade system"
  echo "2) Install curl"
  echo "3) Install git"
  echo "4) Install nano"
  echo "5) Install all (curl, git, nano)"
  echo "6) Back to main menu"
  read -p "Enter choice [1-6]: " os_choice
  case $os_choice in
    1) sudo apt update && sudo apt upgrade -y ;;
    2) sudo apt install -y curl ;;
    3) sudo apt install -y git ;;
    4) sudo apt install -y nano ;;
    5) sudo apt update && sudo apt upgrade -y && sudo apt install -y curl git nano ;;
    6) show_menu ;;
    *) echo "Invalid choice!"; os_package_updates_and_installs_menu ;;
  esac
}

source_env() {
  if [ -f .env ]; then
    log "Sourcing .env file..."
    export $(grep -v '^#' .env | xargs)
  else
    log "Error: .env file not found! Exiting..."
    exit 1
  fi
}

configure_proxmox_users() {
  log "Configuring Proxmox users and roles..."
  read -p "Enter Proxmox User IP: " PROXMOX_USER_IP
  read -p "Enter Proxmox User Username: " PROXMOX_USER
  echo "Enter Proxmox User Password:"
  
  ssh $PROXMOX_USER@$PROXMOX_USER_IP << EOF > /tmp/proxmox_output.log 2>&1
pveum role add provisioner -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Pool.Audit SDN.Use Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Console VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
pveum user add userprovisioner@pve
pveum aclmod / -user userprovisioner@pve -role provisioner
pveum user token add userprovisioner@pve provisioner-token --privsep=0
pveum aclmod /storage/local --user userprovisioner@pve --role PVEDatastoreAdmin --token userprovisioner@pve!provisioner-token
pveum user token list userprovisioner@pve provisioner-token --output-format=json
hostname
EOF

  log "SSH command output:"
  cat /tmp/proxmox_output.log | tee -a $LOGFILE
  
  echo "Please copy the API token from the output above."
  read -p "Have you copied the API token? Type 'yes' to continue: " confirmation
  if [ "$confirmation" == "yes" ]; then
    echo "Creating .env file..."
    echo "PROXMOX_API_ID=userprovisioner@pve!provisioner-token" > .env
    echo "PROXMOX_API_TOKEN=" >> .env
    echo "PROXMOX_NODE_IP=$PROXMOX_USER_IP" >> .env
    echo "PROXMOX_NODE_NAME=pve" >> .env
    log ".env file created successfully. Please paste the copied API token in the PROXMOX_API_TOKEN field."
    nano .env
  else
    log "API token not copied. Exiting..."
    exit 1
  fi
}

download_iso() {
  local url=$1
  local filename=$2
  ssh $PROXMOX_USER@$PROXMOX_NODE_IP "cd /var/lib/vz/template/iso/ && nohup wget -O $filename $url &"
  if [ $? -eq 0 ]; then
    log "$filename download initiated."
  else
    log "Error: Failed to initiate $filename download."
    exit 1
  fi
}

download_all_iso_files_proxmox() {
  log "Downloading all ISO files on Proxmox server. This may take a while..."
  source_env
  read -p "Enter Proxmox User Username: " PROXMOX_USER
  echo "Enter Proxmox User Password:"

  ssh $PROXMOX_USER@$PROXMOX_NODE_IP << EOF
cd /var/lib/vz/template/iso/ || exit 1
nohup wget -O virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso &
nohup wget -O windows10.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso &
nohup wget -O windows_server_2019.iso https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso &
nohup wget -O ubuntu-22.iso https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso &
EOF
  if [ $? -eq 0 ]; then
    log "ISO files download initiated."
  else
    log "Error: Failed to initiate ISO files download."
    exit 1
  fi
}

download_iso_files_proxmox_menu() {
  echo "ISO Download Menu:"
  echo "1) Download all ISO files"
  echo "2) Download Virtio ISO"
  echo "3) Download Windows 10 ISO"
  echo "4) Download Windows Server 2019 ISO"
  echo "5) Download Ubuntu 22.04 ISO"
  echo "6) Back to main menu"
  read -p "Enter choice [1-6]: " iso_choice
  case $iso_choice in
    1) download_all_iso_files_proxmox ;;
    2) download_iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" "virtio-win.iso" ;;
    3) download_iso "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso" "windows10.iso" ;;
    4) download_iso "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" "windows_server_2019.iso" ;;
    5) download_iso "https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso" "ubuntu-22.iso" ;;
    6) show_menu ;;
    *) echo "Invalid choice!"; download_iso_files_proxmox_menu ;;
  esac
}

replace_placeholders() {
  source .env

  log "Replacing placeholders in configuration files..."
  find . -type f ! -name "requirements.sh" -exec sed -i \
    -e "s/<proxmox_api_id>/$PROXMOX_API_ID/g" \
    -e "s/<proxmox_api_token>/$PROXMOX_API_TOKEN/g" \
    -e "s/<proxmox_node_ip>/$PROXMOX_NODE_IP/g" \
    -e "s/<proxmox_node_name>/$PROXMOX_NODE_NAME/g" {} +

  find ./packer -type f -name "example.auto.pkrvars.hcl.txt" -exec bash -c \
    'mv "$0" "${0/example.auto.pkrvars.hcl.txt/value.auto.pkrvars.hcl}"' {} \;

  find ./terraform -type f -name "example-terraform.tfvars.txt" -exec bash -c \
    'mv "$0" "${0/example-terraform.tfvars.txt/terraform.tfvars}"' {} \;
}

install_requirements() {
  log "Installing required packages. This may take a while..."
  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt update -qq
  sudo apt install -qq -y python3 python3-pip unzip mkisofs terraform packer mono-complete

  pip3 install ansible pywinrm jmespath
  ansible-galaxy collection install community.windows microsoft.ad
  if [ $? -eq 0 ]; then
    log "Required packages installed successfully."
  else
    log "Error: Failed to install required packages."
    exit 1
  fi
}

create_templates() {
  log "Running task_templating.sh script in packer/..."
  cd ~/ad-training-lab/packer || { echo "Directory packer not found"; exit 1; }
  ./task_templating.sh | tee -a $LOGFILE
  if [ $? -eq 0 ]; then
    log "task_templating.sh script ran successfully."
  else
    log "Error: Failed to run task_templating.sh script."
    exit 1
  fi
}

run_terraform() {
  log "Running task_terraforming.sh script in terraform/..."
  cd ~/ad-training-lab/terraform || { echo "Directory terraform not found"; exit 1; }
  ./task_terraforming.sh | tee -a $LOGFILE
  if [ $? -eq 0 ]; then
    log "task_terraforming.sh script ran successfully."
  else
    log "Error: Failed to run task_terraforming.sh script."
    exit 1
  fi
}

run_ansible() {
  log "Running the Ansible playbook inside ansible/..."
  cd ~/ad-training-lab/ansible || { echo "Directory ansible not found"; exit 1; }
  ansible-playbook main.yml -vvv | tee -a $LOGFILE
  if [ $? -eq 0 ]; then
    log "Ansible playbook ran successfully."
  else
    log "Error: Failed to run Ansible playbook."
    exit 1
  fi
}

show_menu() {
  echo "Main Menu:"
  echo "1) Configure Proxmox users and roles"
  echo "2) Download ISO files on Proxmox server"
  echo "3) Replace placeholders in configuration files"
  echo "4) OS package updates and installs"
  echo "5) Make scripts executable"
  echo "6) Run requirements.sh script"
  echo "7) Create templates using Packer"
  echo "8) Run Terraform scripts"
  echo "9) Clone Snare-Products repository"
  echo "10) Run Ansible playbook"
  echo "11) View log file"
  echo "12) Exit"
  read -p "Enter choice [1-12]: " choice
  case $choice in
    1) configure_proxmox_users ;;
    2) download_iso_files_proxmox_menu ;;
    3) source_env && replace_placeholders ;;
    4) os_package_updates_and_installs_menu ;;
    5) chmod +x requirements.sh packer/task_templating.sh terraform/task_terraforming.sh ;;
    6) sudo ./requirements.sh | tee -a $LOGFILE ;;
    7) create_templates ;;
    8) run_terraform ;;
    9) cd ~/ad-training-lab/ansible && git clone https://github.com/hanshoyos/Snare-Products.git ;;
    10) run_ansible ;;
    11) tail -f $LOGFILE ;;
    12) exit 0 ;;
    *) echo "Invalid choice!"; show_menu ;;
  esac
}

show_menu
