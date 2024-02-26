#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

DEPLOYMENT_ID=$(uuidgen)

# Install dependencies
#apt-get update
#apt-get install \
#	podman \
#	unattended-upgrades

# Create user to run the container
USER="jupyteruser"
if [ ! -d "/home/$USER" ]; then
	useradd -m "$USER"
fi

# Pull in jdgregson-jupyter-host
DEPLOY_DIR="/tmp/jdgregson-jupyter-host-$DEPLOYMENT_ID"
mkdir "$DEPLOY_DIR"
git clone https://github.com/jdgregson/jdgregson-jupyter-host.git "$DEPLOY_DIR/"
chmod +x "$DEPLOY_DIR/restore-permissions.sh"
"$DEPLOY_DIR/opt/jdgregson/jdgregson-jupyter-host/restore-permissions.sh" "$DEPLOY_DIR"
#rsync -pvr "$DEPLOY_DIR/" /
#rm -fr "$DEPLOY_DIR"

# Pull in jdgregson-jupyter
#mkdir /opt/jdgregson
#git clone https://github.com/jdgregson/jdgregson-jupyter.git /opt/jdgregson/jdgregson-jupyter
#chmod +x /opt/jdgregson/jdgregson-jupyter/*.sh

