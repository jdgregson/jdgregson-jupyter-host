#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

if [ ! -f "/etc/lsb-release" ] || [ -z "grep '22.04' /etc/lsb-release" ]; then
    echo "ERROR: jdgregson-jupyter-host only supports Ubuntu Server 22.04."
    exit 1
fi

# Install dependencies
apt-get update
apt-get install \
    podman \
    unattended-upgrades

# Create user to run the container
USER="jupyteruser"
if [ ! -d "/home/$USER" ]; then
    useradd -m "$USER"
fi

# Pull in jdgregson-jupyter-host
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/jdgregson-jupyter-host.git "$DEPLOY_DIR/"
"$DEPLOY_DIR/opt/jdgregson/jdgregson-jupyter-host/restore-permissions.sh" "$DEPLOY_DIR"
rsync -pvr "$DEPLOY_DIR/" /
rm -fr "$DEPLOY_DIR"

# Pull in jdgregson-jupyter
git clone https://github.com/jdgregson/jdgregson-jupyter.git /opt/jdgregson/jdgregson-jupyter
chmod +x /opt/jdgregson/jdgregson-jupyter/*.sh

