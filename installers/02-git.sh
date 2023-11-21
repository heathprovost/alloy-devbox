#!/bin/bash

# install os package
sudo apt-get -y install git

# configure git globals to standards
git config --global push.default simple
git config --global core.autocrlf false
git config --global core.eol lf

# set user.name and user.email if available in environment
if [ -n "${GIT_USER_NAME}" ] && [ -n "${GIT_USER_EMAIL}" ]; then
  git config --global user.name "${GIT_USER_NAME}"
  git config --global user.email "${GIT_USER_EMAIL}"
else
  echo "GIT_USER_NAME and GIT_USER_EMAIL not set, skipping"
fi  

