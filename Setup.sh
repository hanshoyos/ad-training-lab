#!/bin/bash

# Step 1: Navigate to the ad-training-lab directory
echo "Step 1: Navigating to the ad-training-lab directory..."
cd ~/ad-training-lab || { echo "Directory ad-training-lab not found"; exit 1; }

# Step 2: Copy env.example to .env and open nano to edit it
echo "Step 2: Copying env.example to .env and opening nano to edit it..."
cp env.example .env
echo "Please edit the .env file to include the API token and Proxmox IP address."
nano .env

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
