#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

if [ ! -f "/etc/lsb-release" ] || [ -z "grep '22.04' /etc/lsb-release" ]; then
    echo "ERROR: jdgregson-jupyter-host only supports Ubuntu Server 22.04."
    exit 1
fi

echo "Installing updates and dependencies..."
apt-get update
NEEDRESTART_MODE=a apt-get upgrade --yes
NEEDRESTART_MODE=a apt-get install --yes \
    podman \
    unattended-upgrades

USER="jupyteruser"
if [ ! -d "/home/$USER" ]; then
    echo "Creating user $USER..."
    useradd -m "$USER"
fi

echo "Deploying jdgregson-jupyter-host..."
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/jdgregson-jupyter-host.git "$DEPLOY_DIR/"
cd "$DEPLOY_DIR"
"$DEPLOY_DIR/opt/jdgregson/jdgregson-jupyter-host/restore-permissions.sh" "$DEPLOY_DIR"
rsync --perms --verbose --recursive --exclude=.git "$DEPLOY_DIR/" /
rm -fr "$DEPLOY_DIR"

echo "Deploying jdgregson-jupyter..."
git clone https://github.com/jdgregson/jdgregson-jupyter.git /opt/jdgregson/jdgregson-jupyter
chmod +x /opt/jdgregson/jdgregson-jupyter/*.sh

