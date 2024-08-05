#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

USER="jupyteruser"
IP=0.0.0.0
PORT=8888

if [ ! -f "/etc/lsb-release" ] || [ -z "$(grep '22.04' /etc/lsb-release)" ]; then
    echo "ERROR: jdgregson-jupyter-host only supports Ubuntu Server 22.04"
    exit 1
fi

if [ ! -f "/root/secrets" ]; then
    echo "ERROR: /root/secrets not found"
    exit 1
fi

source /root/secrets
cd ~

echo "Installing updates and dependencies..."
apt-get update
NEEDRESTART_MODE=a apt-get upgrade --yes
NEEDRESTART_MODE=a apt-get install --yes \
    python3-pip \
    unattended-upgrades

echo "Creating and configuring user..."
if [ ! -d "/home/$USER" ]; then
    echo "Creating user $USER..."
    useradd -m "$USER"
    if [ -n "$HF_TOKEN" ]; then
        echo "export HF_TOKEN=$HF_TOKEN" >> "/home/$USER/.profile"
    fi
fi
if [ ! -d "/home/$USER/notebooks" ]; then
    mkdir "/home/$USER/notebooks"
    chown $USER:$USER "/home/$USER/notebooks"
fi

echo "Deploying cloudflared..."
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
cloudflared service install $CLOUDFLARED_TOKEN
rm cloudflared.deb

echo "Deploying jdgregson-jupyter-host..."
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/jdgregson-jupyter-host.git "$DEPLOY_DIR/"
"$DEPLOY_DIR/opt/jdgregson/jdgregson-jupyter-host/restore-permissions.sh" "$DEPLOY_DIR"
cp -fr "$DEPLOY_DIR"/* /
rm -fr "$DEPLOY_DIR"

echo "Installing Jupyter and plugins..."
sudo pip3 install jupyterlab jupyter-resource-usage jupyterlab_theme_solarized_dark

echo "Creating Jupyter service..."
cat >/etc/systemd/system/jupyter.service <<EOF
[Unit]
Description=Jupyter

[Service]
Type=simple
ExecStart=/usr/bin/env jupyter lab --ip=$IP --port=$PORT --LabApp.token='$JUPYTER_ACCESS_TOKEN'
Environment="HF_TOKEN=$HF_TOKEN"

WorkingDirectory=/home/$USER/notebooks
User=$USER
Group=$USER

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "Starting Jupyter on $IP:$PORT..."
systemctl enable --now jupyter

