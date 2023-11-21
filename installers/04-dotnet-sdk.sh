#!/bin/bash

# remove the existing .NET packages from your distribution. You want to start over 
# and ensure that you don't install them from the wrong repository.
sudo apt-get -y remove 'dotnet*' 'aspnet*' 'netstandard*'

# create /etc/apt/preferences.d/ignore-ubuntu-dotnet-packages.pref, if it doesn't already exist.
sudo touch /etc/apt/preferences.d/ignore-ubuntu-dotnet-packages.pref

# add the following to the .pref file, which prevents packages that start with dotnet, 
# aspnetcore, or netstandard from being sourced from the ubuntu repository.
cat > /etc/apt/preferences.d/ignore-ubuntu-dotnet-packages.pref <<EOF
Package: dotnet* aspnet* netstandard*
Pin: origin "archive.ubuntu.com"
Pin-Priority: -10
EOF

# get current ubuntu version
declare repo_version=$(if command -v lsb_release &> /dev/null; then lsb_release -r -s; else grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"'; fi)

# Download Microsoft signing key and repository
wget https://packages.microsoft.com/config/ubuntu/$repo_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

# Install Microsoft signing key and repository
DEBIAN_FRONTEND=noninteractive sudo dpkg -i packages-microsoft-prod.deb

# Clean up
rm -f packages-microsoft-prod.deb

# Install dotnet-sdk-6.0
sudo apt-get -y install dotnet-sdk-6.0