#!/bin/bash

LOGFILE=~/Git_Project/Snare_Lab_POC/setup.log

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}

error_exit() {
  log "ERROR: $1"
  exit 1
}

run_packer_in_parallel() {
  log "Running packer task templating in parallel..."

  local base_dir=~/Git_Project/Snare_Lab_POC/packer
  local directories=("ubuntu-server" "win10" "win2019")
  local pids=()

  for directory in "${directories[@]}"; do
    local dir_path="$base_dir/$directory"
    local log_path="$dir_path/packer_build.log"

    if [ -d "$dir_path" ]; then
      (
        cd $dir_path || error_exit "Failed to enter directory $dir_path."
        log "Initializing Packer in $dir_path..."
        packer init . >> $log_path 2>&1 || error_exit "Packer init failed in $dir_path."
        log "Building template in: $(pwd)"
        packer build . >> $log_path 2>&1 || error_exit "Packer build failed in $dir_path."
      ) &
      pids+=($!)
    else
      log "Directory $dir_path does not exist. Skipping..."
    fi
  done

  # Wait for all parallel processes to complete
  for pid in "${pids[@]}"; do
    wait $pid || error_exit "Packer task templating failed in one of the directories."
  done

  log "Packer task templating completed successfully in all directories."

  echo -e "\033[1;32m
  ##############################################################
  #                                                            #
  #    Templates created successfully in all directories.      #
  #                                                            #
  #    Next step: terraform apply                              #
  #                                                            #
  ##############################################################
  \033[0m"
}

run_next_script() {
  log "AUTOMATICALLY RUNNING THE NEXT SCRIPT task_terraforming.sh"
  cd ~/Git_Project/Snare_Lab_POC/terraform || error_exit "Failed to change directory to ~/Git_Project/Snare_Lab_POC/terraform"
  ./task_terraforming.sh
}


run_packer_in_parallel
run_next_script
