# 🪄 Alloy DevBox
Automated script magic for configuring machines, vms, or containers
for [alloy](https://github.com/StullerInc/alloy) development.

![DevBox Demo](../assets/devbox-demo.gif?raw=true)

## Installation

There is no install and there are no dependencies other than your target environment must be running **Ubuntu 22.04 LTS**
or higher. Setup is performed by simply running one of the following cURL or Wget commands on the target machine, VM, or container.

```shell
source <(curl -so- https://raw.githubusercontent.com/heathprovost/alloy-devbox/main/devbox.sh)
```

```shell
source <(wget -qO- https://raw.githubusercontent.com/heathprovost/alloy-devbox/main/devbox.sh)
```

Running either of the above commands downloads the script and runs it. By default you will be promted to provide a few options, but you 
can create a file called `~/.devboxrc` to provide default responses for unattended installs if you prefer. This file will be created upon
first use to avoid prompting in the future. For example:

```env
name = Jay Doe
email = jay_doe@domain.com
token = ghp_YourGithubTokenForNpmPackageInstalls
```

### Windows using [wsl2](https://learn.microsoft.com/en-us/windows/wsl/install)

If you do not yet have a WSL setup and configured you can run the following to perform a 1st time install of the current Ubuntu LTS distro:

```shell
C:\Users\foo> wsl --install
C:\Users\foo> wsl --set-default-version 2
C:\Users\foo> wsl --set-default-version 2
```

### MacOS using [orbstack](https://orbstack.dev)

This will create a machine called "alloy" and setup devbox in it all from a single command.

```console
foo@bar:~$ orb create ubuntu alloy && orb -m alloy ./devbox.sh
```
