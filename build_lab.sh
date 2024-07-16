#!/bin/bash

# Define paths
PACKER_DIR=~/ad-training-lab/packer
TERRAFORM_DIR=~/ad-training-lab/terraform
ANSIBLE_DIR=~/ad-training-lab/ansible
MARKER_FILE=$TERRAFORM_DIR/.terraform_ran

# Function to check the exit status of the previous command
check_status() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed."
    exit 1
  fi
}

# Function to show options and get user input
show_menu() {
  echo "Select an option:"
  echo "  1) Verify templates and run task_templating.sh if needed"
  echo "  2) Verify VMs and run task_terraforming.sh if needed"
  echo "  3) Run ad_setup.yml playbook"
  echo "  4) Run snare_env_setup.yml playbook"
  echo "  5) Exit"
  echo "  6) Run all steps sequentially"
  read -p "Enter the number: " choice
}

# Function to handle the first option
verify_templates() {
  echo "Running verify_templates.yml playbook..."
  cd $ANSIBLE_DIR
  ansible-playbook playbooks/verify_templates.yml > verify_templates_output.txt
  check_status "verify_templates.yml playbook"

  # Parse the output to check if all templates exist
  if grep -q "exists: False" verify_templates_output.txt; then
    echo "One or more templates do not exist. Running task_templating.sh..."
    cd $PACKER_DIR
    ./task_templating.sh
    check_status "task_templating.sh"
  else
    echo "All templates exist. Skipping task_templating.sh..."
  fi
}

# Function to handle the second option
verify_vms() {
  echo "Running verify_vms.yml playbook..."
  cd $ANSIBLE_DIR
  ansible-playbook playbooks/verify_vms.yml > verify_vms_output.txt
  check_status "verify_vms.yml playbook"

  # Check if VMs exist and if task_terraforming.sh has run before
  if grep -q "exists: False" verify_vms_output.txt || [ ! -f $MARKER_FILE ]; then
    echo "One or more VMs do not exist or task_terraforming.sh has not been run before. Running task_terraforming.sh..."
    cd $TERRAFORM_DIR
    ./task_terraforming.sh
    check_status "task_terraforming.sh"
    # Create a marker file to indicate that the Terraform step has run
    touch $MARKER_FILE
  else
    echo "All VMs exist and task_terraforming.sh has run before. Skipping task_terraforming.sh..."
  fi
}

# Function to handle the third option
run_ad_setup() {
  echo "Running ad_setup.yml playbook..."
  cd $ANSIBLE_DIR
  ansible-playbook ad_setup.yml
  check_status "ad_setup.yml playbook"
}

# Function to handle the fourth option
run_snare_env_setup() {
  echo "Running snare_env_setup.yml playbook..."
  cd $ANSIBLE_DIR
  ansible-playbook snare_env_setup.yml
  check_status "snare_env_setup.yml playbook"
}

# Function to run all steps sequentially
run_all_steps() {
  verify_templates
  verify_vms
  run_ad_setup
  run_snare_env_setup
}

# Show the menu and get the user's choice
show_menu

# Loop to handle the user's choice
while true; do
  case $choice in
    1)
      verify_templates
      ;;
    2)
      verify_vms
      ;;
    3)
      run_ad_setup
      ;;
    4)
      run_snare_env_setup
      ;;
    5)
      echo "Exiting."
      exit 0
      ;;
    6)
      run_all_steps
      ;;
    *)
      echo "Invalid option. Please try again."
      ;;
  esac

  # Show the menu again after executing a task
  show_menu
done

echo "Task completed successfully."
