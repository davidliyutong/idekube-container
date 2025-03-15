#!/bin/bash
set -e

# If the user with UID 1000 exists, delete it
if id -u 1000 >/dev/null 2>&1; then
    userdel $(id -un 1000)
fi

# If the group with GID 1000 exists, delete it
if getent group 1000 >/dev/null 2>&1; then
    groupdel $(getent group 1000 | cut -d: -f1)
fi

# Delete the /home/ubuntu directory
rm -rf /home/ubuntu

# Create a new user with UID 1000 and GID 1000
useradd -m -s /bin/bash -u 1000 idekube

# Set the password for the idekube user
echo "idekube:idekube" | chpasswd

# Add the idekube user to the sudo group and allow it to run sudo without a password
echo "idekube ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo