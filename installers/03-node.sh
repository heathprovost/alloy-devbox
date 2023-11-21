#!/bin/bash

# install packages needed by node gyp to do builds
sudo apt-get -y install make gcc g++ python3-minimal

# set node version
NODE_VERSION='18'
NVM_VERSION='v0.39.5'

# if nvm is not already installed install it
if [ ! -d "${HOME}/.nvm/.git" ]; then
  # download and run install script directly from nvm github repo
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
fi

# update current shell with exports needed to run nvm commands
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# use nvm to install the specified version of node and make it default
nvm install $NODE_VERSION
nvm use $NODE_VERSION

# install nawsso globally
npm install -g @heathprovost/nawsso

# setup default .npmrc file if it does not exist and GIT_HUB_PKG_TOKEN is set
if [ ! -f "$HOME/.npmrc" ] && [ -n "${GIT_HUB_PKG_TOKEN}" ]; then
  printf "//npm.pkg.github.com/:_authToken=${GIT_HUB_PKG_TOKEN}\n@stullerinc:registry=https://npm.pkg.github.com" > "$HOME/.npmrc"
else
  echo ".npmrc already exists or GIT_HUB_PKG_TOKEN not set, skipping"
fi  