#!/bin/bash

#
# ensures that script itself is *not* run using the sudo command but that there *is* a sudo session that can be used when needed
#
function resolve_sudo() {
  if [ -n "$SUDO_USER" ]; then
    # user is sudo'd
    print_as "error" "This script must be run without using sudo."
    exit 1
  else
    # validate sudo session (prompting for password if necessary)
    (sudo -n true 2> /dev/null)
    local sudo_session_ok=$?
    if [ "$sudo_session_ok" != "0" ]; then
      sudo -v 
      if [ $? != 0 ] ; then 
        exit 1
      fi
    fi
  fi
}

#
# prints a message to the console. Each type is display using a custom glyph and/or color
# single quoted substrings are highlighted in blue when detected
#
# @param string $1 - the message type, one of "success", "skipped", "failed", "error", "info", "prompt", "magic"
# @param string $2 - the message to print
#
function print_as() {
  local red='\033[0;31m'
  local green='\033[0;32m'
  local yellow='\033[0;33m'
  local blue='\033[0;34m'
  local purple='\033[0;35m'
  local cyan='\033[0;36m'
  local default='\033[0;39m'
  local reset='\033[0m'
  local success_glyph="${green}✓${reset} "
  local success_color="$default"
  local skipped_glyph="${blue}✗${reset} "
  local skipped_color="$default"
  local failed_glyph="${red}✗${reset} "
  local failed_color="$default"
  local error_glyph="💥 "
  local error_color="$red"
  local info_glyph="💡 "
  local info_color="$yellow"
  local prompt_glyph=""
  local prompt_color="$blue"
  local magic_glyph="🧙 "
  local magic_color="$cyan"
  local nl="\n"

  # store $1 as the msgtype
  local msgtype=$1

  declare -n glyph="${msgtype}_glyph"
  declare -n color="${msgtype}_color"

  # use sed to highlight single quoted substrings in $2 and store as msg
  local msg=$(echo -n -e "$(echo -e -n "$2" | sed -e "s/'\([^']*\)'/\\${blue}\1\\${reset}\\${color}/g")")

  if [ "$msgtype" = "prompt" ]; then
    nl=''
  fi

  printf "${glyph}${color}${msg}${reset}${nl}"
}

#
# log to log file
#
function log() {
  printf "$@" &>> "/var/log/devbox.log"
}

#
# installs common-packages
#
function install_common_packages() {
  # runs apt-get update, upgrade, and autoremove
  sudo apt-get -y update
  sudo apt-get -y upgrade
  sudo apt-get -y autoremove

  # install commonly used packaged
  sudo apt-get -y install curl wget nano zip unzip
}

#
# installs git
#
function install_git() {
  # install os package
  sudo apt-get -y install git

  # configure git globals to standards
  git config --global push.default simple
  git config --global core.autocrlf false
  git config --global core.eol lf

  # use tests to determine the environment we are in and setup GCM accordingly
  if [ -d "/opt/orbstack-guest" ]; then
    # we are in an orbstack vm on macos so link to its GCM binary and configure for it
    mac link git-credential-manager
    git config --global credential.helper "/opt/orbstack-guest/data/bin/cmdlinks/git-credential-manager"
  elif [ -d "/run/WSL" ]; then
    # we are in a wsl2 vm on windows so configure to call the windows GCM binary
    git config --global credential.helper "/mnt/c/Program\ Files/git/mingw64/bin/git-credential-manager-core.exe"
  fi

  # set user.name and user.email if available in environment
  if [ -n "${GIT_USER_NAME}" ] && [ -n "${GIT_USER_EMAIL}" ]; then
    git config --global user.name "${GIT_USER_NAME}"
    git config --global user.email "${GIT_USER_EMAIL}"
  else
    log "GIT_USER_NAME and GIT_USER_EMAIL not set, skipping"
  fi
}

#
# installs node using nvm and sets up required global packages
#
function install_node () {
  local env_updated
  # install packages needed by node gyp to do builds
  sudo apt-get -y install make gcc g++ python3-minimal

  # set node version
  NODE_VERSION='18'
  NVM_VERSION='v0.39.5'

  # if nvm is not already installed install it
  if [ ! -d "${HOME}/.nvm/.git" ]; then
    # download and run install script directly from nvm github repo
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
    env_updated=true
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
  if [ -n "${GIT_HUB_PKG_TOKEN}" ]; then
    printf "//npm.pkg.github.com/:_authToken=${GIT_HUB_PKG_TOKEN}\n@stullerinc:registry=https://npm.pkg.github.com" > "$HOME/.npmrc"
  else
    log "GIT_HUB_PKG_TOKEN not set, skipping .npmrc generation"
  fi
  if [ "$env_updated" = true ]; then
    exit 90
  fi  
}

#
# installs java jdk 11 for solr and keycloak
#
function install_java_jdk () {
  # install java
  sudo apt-get -y install openjdk-11-jdk-headless
}

#
# installs dotnet sdk using microsoft package feed
#
function install_dotnet_sdk() {
  local env_updated

  # remove the existing .NET packages from your distribution just in case to avoid conflicts
  sudo apt-get -y remove 'dotnet*' 'aspnet*' 'netstandard*'

  # set node version
  local dotnet_version='6.0.410'

  # run the dotnet-install script
  curl -fsSL  https://dot.net/v1/dotnet-install.sh | bash -s -- --version $dotnet_version

  # append exports to .bashrc if needed
  if ! grep -qc '$HOME/.dotnet' "$HOME/.bashrc"; then
    printf '\n# dotnet exports\nexport DOTNET_ROOT="$HOME/.dotnet"\nexport DOTNET_CLI_TELEMETRY_OPTOUT=1\nexport PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools\n' >> "$HOME/.bashrc"
    env_updated=true
  fi

  # update current shell with exports needed to run dotnet commands
  export DOTNET_ROOT="$HOME/.dotnet"
  export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools

  if [ "$env_updated" = true ]; then
    exit 90
  fi
}

#
# installs AWS CLI v2
#
function install_aws_cli() {
  # get the architecture id for the machine this script is running on
  arch=$(uname -m)

  # download and install aws-cli v2 for current arch (aarch64 or x86_64 are supported by AWS)
  curl "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip
  rm -rf aws/
}

#
# installs os package dependencies needed to run cypress
#
function install_cypress_deps() {
  # install packages required for cypress
  sudo apt-get -y install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libnss3 libxss1 libasound2 libxtst6 xauth xvfb
}

#
# installs os package dependencies needed to run meteor builds
#
function install_meteor_deps() {
  # install packages required for meteor builds
  sudo apt-get -y install build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev
}

#
# Run the command passed as 1st argument and shows the spinner until this is done
#
# @param string $1 - the command to run
# @param string $2 - the title to show next the spinner
#
function execute_and_wait() {
  set +m
  eval install_$1 &>> "/var/log/devbox.log" 2>&1 &
  pid=$!
  delay=0.05

  frames=('\u280B' '\u2819' '\u2839' '\u2838' '\u283C' '\u2834' '\u2826' '\u2827' '\u2807' '\u280F')

  # Hide the cursor, it looks ugly :D
  tput civis
  index=0
  framesCount=${#frames[@]}

  log "===================================\n$1\n===================================\n"
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    printf "\033[0;34m${frames[$index]}\033[0m Installing $1"

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

  set -m

  if [ "$exitCode" -eq 0 ] || [ "$exitCode" -eq "90" ]; then
    print_as "success" "Installing $1"
    if [ "$exitCode" -eq 90 ]; then
      # 90 means environment will need to be reloaded, so this still successful frun
      ENV_UPDATED=true
    fi
  elif [ "$exitCode" -eq 65 ]; then
    print_as "skipped" "Installing $1 ... skipped (existing installation detected and upgrade not supported)"
  else
    print_as "failed" "Installing $1"
  fi
  
  # Restore the cursor
  tput cnorm
}

#
# return its argument with leading and trailing space trimmed
#
function trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

#
# Collects configuration options, either by prompting user or reading them from .devboxrc file
#
function configure() {
  local name
  local email
  local token

  local logfile="/var/log/devbox.log"

  # import from .devboxrc if it exists otherwise prompt for input of options
  if [ -f "$HOME/.devboxrc" ]; then
    print_as "magic" "Using existing '~/.devboxrc' file for configuration."
    printf "\n"
    set -o allexport
    source <(cat "$HOME/.devboxrc" | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" -e "s/\s*=\s*/=/g")
    set +o allexport
  else
    print_as "magic" "Prompting for required configuration. Responses will be saved in '~/.devboxrc' for future use."
    printf "\n"
    print_as "prompt" "Enter your full name for git configuration: "
    read name
    print_as "prompt" "Enter your email for git configuration: "
    read email
    print_as "prompt" "Enter your github package token for npm configuration: "
    read token
    printf "\n"
  fi

  # copy options into globals, trimming whitespace if any
  GIT_USER_NAME=$(trim $name)
  GIT_USER_EMAIL=$(trim $email)
  GIT_HUB_PKG_TOKEN=$(trim $token)

  # save to .devboxrc for future use
  printf "name = $GIT_USER_NAME\nemail = $GIT_USER_EMAIL\ntoken = $GIT_HUB_PKG_TOKEN\n" > "$HOME/.devboxrc"

  # delete setup.log if it exists
  if [ -f "$logfile" ]; then
    sudo rm -f "$logfile"
  fi

  # create log file and make current user owner
  sudo touch "$logfile"
  sudo chown "$USER:" "$logfile"
}

#
# Print messages upon completion
#
function completion_report() {
  print_as "success" "Done!"
  printf "\n"
  if [ "$ENV_UPDATED" = true ]; then
    print_as "info" "Environment was updated. Run 'source ~/.bashrc' to reload in your current shell."
  fi
}

#
# Execute a series of installers sequentially and report results
#
function setup() {
  # configure options
  configure

  # run installers
  execute_and_wait 'common_packages'
  execute_and_wait 'git'
  execute_and_wait 'node'
  execute_and_wait 'dotnet_sdk'
  execute_and_wait 'java_jdk'
  execute_and_wait 'aws_cli'
  execute_and_wait 'cypress_deps'
  execute_and_wait 'meteor_deps'

  # show completion report
  completion_report
}

resolve_sudo
setup
