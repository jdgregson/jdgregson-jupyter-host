#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

if [ ! -f "/etc/lsb-release" ] || [ -z "grep '22.04' /etc/lsb-release" ]; then
    echo "ERROR: jdgregson-jupyter-host only supports Ubuntu Server 22.04."
    exit 1
fi

if [ ! -f "/root/secrets" ]; then
    echo "ERROR: /root/secrets not found!"
    exit 1
fi

source /root/secrets
cd ~

echo "Installing updates and dependencies..."
apt-get update
NEEDRESTART_MODE=a apt-get upgrade --yes
NEEDRESTART_MODE=a apt-get install --yes \
    podman \
    unattended-upgrades

echo "Creating and configuring user..."
USER="jupyteruser"
if [ ! -d "/home/$USER" ]; then
    echo "Creating user $USER..."
    useradd -m "$USER"
fi
if [ ! -d "/home/$USER/notebooks" ]; then
    mkdir "/home/$USER/notebooks"
    chown $USER:$USER "/home/$USER/notebooks"
fi

echo "Deploying jdgregson-jupyter-host..."
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/jdgregson-jupyter-host.git "$DEPLOY_DIR/"
"$DEPLOY_DIR/opt/jdgregson/jdgregson-jupyter-host/restore-permissions.sh" "$DEPLOY_DIR"
cp -fr "$DEPLOY_DIR"/* /
rm -fr "$DEPLOY_DIR"

echo "Deploying jdgregson-jupyter..."
git clone https://github.com/jdgregson/jdgregson-jupyter.git /opt/jdgregson/jdgregson-jupyter
chmod +x /opt/jdgregson/jdgregson-jupyter/*.sh

echo "Deploying cloudflared"
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
echo "Cloudflared token: $CLOUDFLARED_TOKEN"
cloudflared service install $CLOUDFLARED_TOKEN
rm cloudflared.deb

echo "Enabing and starting jdgregson-jupyter service..."
systemctl enable jdgregson-jupyter
systemctl start jdgregson-jupyter

