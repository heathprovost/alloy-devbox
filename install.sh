#!/bin/bash

{ # this ensures the entire script is downloaded #

devbox_has() {
  type "$1" > /dev/null 2>&1
}

devbox_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then
  # shellcheck disable=SC2016
  devbox_echo >&2 'Error: the install instructions explicitly say to pipe the install script to `bash`; please follow them'
  exit 1
fi

devbox_grep() {
  GREP_OPTIONS='' command grep "$@"
}

devbox_default_install_dir() {
  [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.devbox" || printf %s "${XDG_CONFIG_HOME}/devbox"
}

devbox_install_dir() {
  if [ -n "$DEVBOX_DIR" ]; then
    printf %s "${DEVBOX_DIR}"
  else
    devbox_default_install_dir
  fi
}

devbox_latest_version() {
  devbox_echo "main"
}

devbox_profile_is_bash_or_zsh() {
  local TEST_PROFILE
  TEST_PROFILE="${1-}"
  case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc" | *"/.zprofile")
      return
    ;;
    *)
      return 1
    ;;
  esac
}

#
# Outputs the location to DEVBOX depending on:
# * The availability of $DEVBOX_SOURCE
# * The presence of $DEVBOX_INSTALL_GITHUB_REPO
# * The method used ("script" or "git" in the script, defaults to "git")
# DEVBOX_SOURCE always takes precedence unless the method is "script-devbox-exec"
#
devbox_source() {
  local DEVBOX_GITHUB_REPO
  DEVBOX_GITHUB_REPO="${DEVBOX_INSTALL_GITHUB_REPO:-heathprovost/alloy-devbox}"
  if [ "${DEVBOX_GITHUB_REPO}" != 'heathprovost/alloy-devbox' ]; then
    { devbox_echo >&2 "$(cat)" ; } << EOF
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE REPO IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!

The default repository for this install is \`heathprovost/alloy-devbox\`,
but the environment variables \`\$DEVBOX_INSTALL_GITHUB_REPO\` is
currently set to \`${DEVBOX_GITHUB_REPO}\`.

If this is not intentional, interrupt this installation and
verify your environment variables.
EOF
  fi
  local DEVBOX_VERSION
  DEVBOX_VERSION="${DEVBOX_INSTALL_VERSION:-$(devbox_latest_version)}"
  local DEVBOX_METHOD
  DEVBOX_METHOD="$1"
  local DEVBOX_SOURCE_URL
  DEVBOX_SOURCE_URL="$DEVBOX_SOURCE"
  if [ "_$DEVBOX_METHOD" = "_script-devbox-exec" ]; then
    DEVBOX_SOURCE_URL="https://raw.githubusercontent.com/${DEVBOX_GITHUB_REPO}/${DEVBOX_VERSION}/devbox-exec"
  elif [ -z "$DEVBOX_SOURCE_URL" ]; then
    if [ "_$DEVBOX_METHOD" = "_script" ]; then
      DEVBOX_SOURCE_URL="https://raw.githubusercontent.com/${DEVBOX_GITHUB_REPO}/${DEVBOX_VERSION}/devbox.sh"
    elif [ "_$DEVBOX_METHOD" = "_git" ] || [ -z "$DEVBOX_METHOD" ]; then
      DEVBOX_SOURCE_URL="https://github.com/${DEVBOX_GITHUB_REPO}.git"
    else
      devbox_echo >&2 "Unexpected value \"$DEVBOX_METHOD\" for \$DEVBOX_METHOD"
      return 1
    fi
  fi
  devbox_echo "$DEVBOX_SOURCE_URL"
}

devbox_download() {
  if devbox_has "curl"; then
    curl --fail --compressed -q "$@"
  elif devbox_has "wget"; then
    # Emulate curl with wget
    ARGS=$(devbox_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                            -e 's/--compressed //' \
                            -e 's/--fail //' \
                            -e 's/-L //' \
                            -e 's/-I /--server-response /' \
                            -e 's/-s /-q /' \
                            -e 's/-sS /-nv /' \
                            -e 's/-o /-O /' \
                            -e 's/-C - /-c /')
    # shellcheck disable=SC2086
    eval wget $ARGS
  fi
}

install_devbox_from_git() {
  local INSTALL_DIR
  INSTALL_DIR="$(devbox_install_dir)"
  local DEVBOX_VERSION
  DEVBOX_VERSION="${DEVBOX_INSTALL_VERSION:-$(devbox_latest_version)}"
  if [ -n "${DEVBOX_INSTALL_VERSION:-}" ]; then
    # Check if version is an existing ref
    if command git ls-remote "$(devbox_source "git")" "$DEVBOX_VERSION" | devbox_grep -q "$DEVBOX_VERSION" ; then
      :
    # Check if version is an existing changeset
    elif ! devbox_download -o /dev/null "$(devbox_source "script-devbox-exec")"; then
      devbox_echo >&2 "Failed to find '$DEVBOX_VERSION' version."
      exit 1
    fi
  fi

  local fetch_error
  if [ -d "$INSTALL_DIR/.git" ]; then
    # Updating repo
    devbox_echo "=> devbox is already installed in $INSTALL_DIR, trying to update using git"
    command printf '\r=> '
    fetch_error="Failed to update devbox with $DEVBOX_VERSION, run 'git fetch' in $INSTALL_DIR yourself."
  else
    fetch_error="Failed to fetch origin with $DEVBOX_VERSION. Please report this!"
    devbox_echo "=> Downloading devbox from git to '$INSTALL_DIR'"
    command printf '\r=> '
    mkdir -p "${INSTALL_DIR}"
    if [ "$(ls -A "${INSTALL_DIR}")" ]; then
      # Initializing repo
      command git init "${INSTALL_DIR}" || {
        devbox_echo >&2 'Failed to initialize devbox repo. Please report this!'
        exit 2
      }
      command git --git-dir="${INSTALL_DIR}/.git" remote add origin "$(devbox_source)" 2> /dev/null \
        || command git --git-dir="${INSTALL_DIR}/.git" remote set-url origin "$(devbox_source)" || {
        devbox_echo >&2 'Failed to add remote "origin" (or set the URL). Please report this!'
        exit 2
      }
    else
      # Cloning repo
      command git clone "$(devbox_source)" --depth=1 "${INSTALL_DIR}" || {
        devbox_echo >&2 'Failed to clone devbox repo. Please report this!'
        exit 2
      }
    fi
  fi
  # Try to fetch tag
  if command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" fetch origin tag "$DEVBOX_VERSION" --depth=1 2>/dev/null; then
    :
  # Fetch given version
  elif ! command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" fetch origin "$DEVBOX_VERSION" --depth=1; then
    devbox_echo >&2 "$fetch_error"
    exit 1
  fi
  command git -c advice.detachedHead=false --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" checkout -f --quiet FETCH_HEAD || {
    devbox_echo >&2 "Failed to checkout the given version $DEVBOX_VERSION. Please report this!"
    exit 2
  }
  if [ -n "$(command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" show-ref refs/heads/master)" ]; then
    if command git --no-pager --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch --quiet 2>/dev/null; then
      command git --no-pager --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch --quiet -D master >/dev/null 2>&1
    else
      devbox_echo >&2 "Your version of git is out of date. Please update it!"
      command git --no-pager --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch -D master >/dev/null 2>&1
    fi
  fi

  devbox_echo "=> Compressing and cleaning up git repository"
  if ! command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" reflog expire --expire=now --all; then
    devbox_echo >&2 "Your version of git is out of date. Please update it!"
  fi
  if ! command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" gc --auto --aggressive --prune=now ; then
    devbox_echo >&2 "Your version of git is out of date. Please update it!"
  fi
  return
}

install_devbox_as_script() {
  local INSTALL_DIR
  INSTALL_DIR="$(devbox_install_dir)"
  local DEVBOX_SOURCE_LOCAL
  DEVBOX_SOURCE_LOCAL="$(devbox_source script)"
  local DEVBOX_EXEC_SOURCE
  DEVBOX_EXEC_SOURCE="$(devbox_source script-devbox-exec)"

  # Downloading to $INSTALL_DIR
  mkdir -p "$INSTALL_DIR"
  if [ -f "$INSTALL_DIR/devbox.sh" ]; then
    devbox_echo "=> devbox is already installed in $INSTALL_DIR, trying to update the script"
  else
    devbox_echo "=> Downloading devbox as script to '$INSTALL_DIR'"
  fi
  devbox_download -s "$DEVBOX_SOURCE_LOCAL" -o "$INSTALL_DIR/devbox.sh" || {
    devbox_echo >&2 "Failed to download '$DEVBOX_SOURCE_LOCAL'"
    return 1
  } &
  devbox_download -s "$DEVBOX_EXEC_SOURCE" -o "$INSTALL_DIR/devbox-exec" || {
    devbox_echo >&2 "Failed to download '$DEVBOX_EXEC_SOURCE'"
    return 2
  } &
  for job in $(jobs -p | command sort)
  do
    wait "$job" || return $?
  done
  chmod a+x "$INSTALL_DIR/devbox-exec" || {
    devbox_echo >&2 "Failed to mark '$INSTALL_DIR/devbox-exec' as executable"
    return 3
  }
}

devbox_try_profile() {
  if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
    return 1
  fi
  devbox_echo "${1}"
}

#
# Detect profile file if not specified as environment variable
# (eg: PROFILE=~/.myprofile)
# The echo'ed path is guaranteed to be an existing file
# Otherwise, an empty string is returned
#
devbox_detect_profile() {
  if [ "${PROFILE-}" = '/dev/null' ]; then
    # the user has specifically requested NOT to have devbox touch their profile
    return
  fi

  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    devbox_echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''

  if [ "${SHELL#*bash}" != "$SHELL" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
    if [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.zprofile" ]; then
      DETECTED_PROFILE="$HOME/.zprofile"
    fi
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zprofile" ".zshrc"
    do
      if DETECTED_PROFILE="$(devbox_try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    devbox_echo "$DETECTED_PROFILE"
  fi
}

devbox_do_install() {
  if [ -n "${DEVBOX_DIR-}" ] && ! [ -d "${DEVBOX_DIR}" ]; then
    if [ -e "${DEVBOX_DIR}" ]; then
      devbox_echo >&2 "File \"${DEVBOX_DIR}\" has the same name as installation directory."
      exit 1
    fi

    if [ "${DEVBOX_DIR}" = "$(devbox_default_install_dir)" ]; then
      mkdir "${DEVBOX_DIR}"
    else
      devbox_echo >&2 "You have \$DEVBOX_DIR set to \"${DEVBOX_DIR}\", but that directory does not exist. Check your profile files and environment."
      exit 1
    fi
  fi
  if [ -z "${METHOD}" ]; then
    # Autodetect install method
    if devbox_has git; then
      install_devbox_from_git
    elif devbox_has curl || devbox_has wget; then
      install_devbox_as_script
    else
      devbox_echo >&2 'You need git, curl, or wget to install devbox'
      exit 1
    fi
  elif [ "${METHOD}" = 'git' ]; then
    if ! devbox_has git; then
      devbox_echo >&2 "You need git to install devbox"
      exit 1
    fi
    install_devbox_from_git
  elif [ "${METHOD}" = 'script' ]; then
    if ! devbox_has curl && ! devbox_has wget; then
      devbox_echo >&2 "You need curl or wget to install devbox"
      exit 1
    fi
    install_devbox_as_script
  else
    devbox_echo >&2 "The environment variable \$METHOD is set to \"${METHOD}\", which is not recognized as a valid installation method."
    exit 1
  fi

  devbox_echo

  local DEVBOX_PROFILE
  DEVBOX_PROFILE="$(devbox_detect_profile)"
  local PROFILE_INSTALL_DIR
  PROFILE_INSTALL_DIR="$(devbox_install_dir | command sed "s:^$HOME:\$HOME:")"

  SOURCE_STR="\\nexport DEVBOX_DIR=\"${PROFILE_INSTALL_DIR}\"\\n[ -s \"\$DEVBOX_DIR/devbox.sh\" ] && \\. \"\$DEVBOX_DIR/devbox.sh\"  # This loads devbox\\n"

  BASH_OR_ZSH=false

  if [ -z "${DEVBOX_PROFILE-}" ] ; then
    local TRIED_PROFILE
    if [ -n "${PROFILE}" ]; then
      TRIED_PROFILE="${DEVBOX_PROFILE} (as defined in \$PROFILE), "
    fi
    devbox_echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zprofile, ~/.zshrc, and ~/.profile."
    devbox_echo "=> Create one of them and run this script again"
    devbox_echo "   OR"
    devbox_echo "=> Append the following lines to the correct file yourself:"
    command printf "${SOURCE_STR}"
    devbox_echo
  else
    if devbox_profile_is_bash_or_zsh "${DEVBOX_PROFILE-}"; then
      BASH_OR_ZSH=true
    fi
    if ! command grep -qc '/devbox.sh' "$DEVBOX_PROFILE"; then
      devbox_echo "=> Appending devbox source string to $DEVBOX_PROFILE"
      command printf "${SOURCE_STR}" >> "$DEVBOX_PROFILE"
    else
      devbox_echo "=> devbox source string already in ${DEVBOX_PROFILE}"
    fi
  fi

  # Source devbox
  # shellcheck source=/dev/null
  \. "$(devbox_install_dir)/devbox.sh"

  devbox_reset

  devbox_echo "=> Close and reopen your terminal to start using devbox or run the following to use it now:"
  command printf "${SOURCE_STR}"
}

#
# Unsets the various functions defined
# during the execution of the install script
#
devbox_reset() {
  unset -f devbox_has devbox_install_dir devbox_latest_version devbox_profile_is_bash_or_zsh \
    devbox_source devbox_download install_devbox_from_git \
    install_devbox_as_script devbox_try_profile devbox_detect_profile \
    devbox_do_install devbox_reset devbox_default_install_dir devbox_grep
}

[ "_$DEVBOX_ENV" = "_testing" ] || devbox_do_install

} # this ensures the entire script is downloaded #