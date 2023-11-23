# 🪄 Alloy DevBox
Automated script magic for configuring machines or containers
for [alloy](https://github.com/StullerInc/alloy) development.

## Installation

There is no install and there are no dependencies other than your target environment must be running Ubuntu 22.04 LTS
or higher. Setup is performed by simply downloading [devbox.sh](devbox.sh) and running it on the target machine, VM, or container.

By default you will be promted to provide a few options, but you can create a file called `.devboxrc` to provide default responses for unattended installs if you prefer. For example:

```env
name = Lorem Ipsum
email = lorem_ipsum@domain.com
token = ghp_YourGithubTokenForNpmPackageInstalls
```
Just place this file in the folder where you downloaded the script before running it.

### Windows using [wsl2](https://learn.microsoft.com/en-us/windows/wsl/install)

It is **highly** recommended for quality of life to configure your WSL user account to disable password prompting when running `sudo` commands. You can do this by running the following command:

```shell
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$USER"
```

The following assumes you have not yet installed the WSL2 subsystem and will setup
devbox in the default Ubuntu distribution.

```shell
C:\Users\foo> wsl --install
C:\Users\foo> wsl --set-default-version 2
```

### MacOS using [orbstack](https://orbstack.dev)

This will create a machine called "alloy" and setup devbox in it all from a single command.

```console
foo@bar:~$ orb create ubuntu alloy && orb -m alloy ./devbox.sh
```
