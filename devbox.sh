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
  script_file=$(basename -- "$1")
  script_name="${script_file%.sh}"
  package_name="${script_name#*-}"

  frames=('\u280B' '\u2819' '\u2839' '\u2838' '\u283C' '\u2834' '\u2826' '\u2827' '\u2807' '\u280F')

  echo "$pid" >"/tmp/.spinner.pid"

  # Hide the cursor, it looks ugly :D
  tput civis
  index=0
  framesCount=${#frames[@]}

  printf "===================================\n$package_name\n===================================\n" &>> devbox.log
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    printf "${ANSI_BLUE}${frames[$index]}${ANSI_NC} Installing ${package_name}"

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
    printf "${ANSI_GREEN}${CHECK_SYMBOL}${ANSI_NC} Installing ${package_name}\n"
  elif [ "$exitCode" -eq "65" ]; then
    printf "${ANSI_BLUE}${X_SYMBOL}${ANSI_NC} Installing ${package_name} ... skipped (existing installation detected and upgrade not supported)\n"
  else
    printf "${ANSI_RED}${X_SYMBOL}${ANSI_NC} Installing ${package_name}\n"
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
  local script
  local package_name
  # delete setup.log if it exists
  rm -f devbox.log

  # run all configured installer scripts
  for script in installers/[0-9][0-9]-*.sh
  do
    package_name="${script##*/}"
    execute_and_wait "./$script"
  done
  printf "${ANSI_GREEN}${CHECK_SYMBOL}${ANSI_NC} Done!\n\n"
  printf "Run ${ANSI_BLUE}'git clone https://github.com/StullerInc/alloy.git'${ANSI_NC} to get started\n"
}

setup
