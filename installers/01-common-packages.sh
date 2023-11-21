#!/bin/bash

# runs apt-get update if needed
apt_get_update_if_needed()
{
  if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
    echo "Running apt-get update..."
    apt-get update
  else
    echo "Skipping apt-get update."
  fi
}

# update if needed and install common packages
apt_get_update_if_needed
sudo apt-get -y install curl wget nano zip unzip