#!/bin/bash

# import from devbox.env if it exists otherwise error and exit
if [ -f devbox.env ]; then
  set -o allexport
  source <(cat devbox.env | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g")
  set +o allexport
else
  echo "Please create devbox.env file with your defaults. See README.md"
  exit 1
fi

# constants
CHECK_SYMBOL='\u2713'
X_SYMBOL='\u2A2F'
ANSI_RED='\e[31m'
ANSI_BLUE='\e[34m'
ANSI_GREEN='\e[32m'
ANSI_NC='\e[39m'

# installers

#
# installs common-packages
#
function common_packages() {
  # runs apt-get update if needed
  if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
    echo "Running apt-get update..."
    apt-get update
  else
    echo "Skipping apt-get update."
  fi

  sudo apt-get -y install curl wget nano zip unzip
}

#
# installs git
#
function git() {
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
}

#
# installs node using nvm and sets up required global packages
#
function node () {
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
}

#
# installs dotnet sdk using microsoft package feed
#
function dotnet_sdk() {
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
}

#
# installs AWS CLI v2
#
function aws_cli() {
  # download and install aws-cli v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip
  rm -rf aws/
}

#
# installs os package dependencies needed to run cypress
#
function cypress_deps() {
  # install packages required for cypress
  sudo apt-get -y install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libnss3 libxss1 libasound2 libxtst6 xauth xvfb
}

#
# Run the command passed as 1st argument and shows the spinner until this is done
#
# @param string $1 - the command to run
# @param string $2 - the title to show next the spinner
#
function execute_and_wait() {
  eval $1 &>> devbox.log 2>&1 &
  pid=$!
  delay=0.05

  frames=('\u280B' '\u2819' '\u2839' '\u2838' '\u283C' '\u2834' '\u2826' '\u2827' '\u2807' '\u280F')

  echo "$pid" >"/tmp/.spinner.pid"

  # Hide the cursor, it looks ugly :D
  tput civis
  index=0
  framesCount=${#frames[@]}

  printf "===================================\n$1\n===================================\n" &>> devbox.log
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    printf "${ANSI_BLUE}${frames[$index]}${ANSI_NC} Installing $1"

    let index=index+1
    if [ "$index" -ge "$framesCount" ]; then
      index=0
    fi

    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    sleep $delay
  done


  #
  # Wait the command to be finished, this is needed to capture its exit status
  #
  wait $!
  exitCode=$?

  if [ "$exitCode" -eq "0" ]; then
    printf "${ANSI_GREEN}${CHECK_SYMBOL}${ANSI_NC} Installing $1\n"
  elif [ "$exitCode" -eq "65" ]; then
    printf "${ANSI_BLUE}${X_SYMBOL}${ANSI_NC} Installing $1 ... skipped (existing installation detected and upgrade not supported)\n"
  else
    printf "${ANSI_RED}${X_SYMBOL}${ANSI_NC} Installing $1\n"
  fi
  
  # Restore the cursor
  tput cnorm
}

#
# Execute a series of installer scripts sequentially and report results
#
# @param array $1 - array of installer names
#
function setup() {
  # delete setup.log if it exists
  rm -f devbox.log

  # run installers
  execute_and_wait 'common_packages'
  execute_and_wait 'git'
  execute_and_wait 'node'
  execute_and_wait 'dotnet_sdk'
  execute_and_wait 'awl_cli'
  execute_and_wait 'cypress_deps'

  printf "${ANSI_GREEN}${CHECK_SYMBOL}${ANSI_NC} Done!\n\n"
  printf "Run ${ANSI_BLUE}'git clone https://github.com/StullerInc/alloy.git'${ANSI_NC} to get started\n"
}

setup
