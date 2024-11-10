#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

USER="jupyteruser"
IP=0.0.0.0
PORT=8888

APP="jdgregson-jupyter-host"
NOTEBOOK_DIR="/home/$USER/notebooks"

if [ ! -f "/etc/lsb-release" ] || [ -z "$(grep '22.04' /etc/lsb-release)" ]; then
    echo "ERROR: $APP only supports Ubuntu Server 22.04"
    exit 1
fi

if [ ! -f "/root/secrets" ]; then
    echo "ERROR: /root/secrets not found"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
source /root/secrets
cd ~

echo "Installing updates and dependencies..."
apt-get update
NEEDRESTART_MODE=i apt-get upgrade --yes
NEEDRESTART_MODE=i apt-get install --yes \
    python3-pip \
    unattended-upgrades \
    awscli \
    inotify-tools \
    vim \
    git \
    ca-certificates \
    curl \
    gnupg \
    gcc \
    g++ \
    make

if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    apt-get update
    NEEDRESTART_MODE=i apt-get install --yes \
        nodejs
fi

echo "\$nrconf{restart} = 'i';" >> /etc/needrestart/needrestart.conf
echo "\$nrconf{kernelhints} = 0;" >> /etc/needrestart/needrestart.conf
echo "\$nrconf{notify} = 'none';" >> /etc/needrestart/needrestart.conf

echo "Creating and configuring user..."
if [ ! -d "/home/$USER" ]; then
    echo "Creating user $USER..."
useradd -m -s /bin/bash "$USER"
fi
if [ -n "$HF_TOKEN" ]; then
    echo "export HF_TOKEN=$HF_TOKEN" >> "/home/$USER/.profile"
fi
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "Configuring AWS credentials..."
    echo "export AWS_REGION=$AWS_REGION" >> "/home/$USER/.profile"
    echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> "/home/$USER/.profile"
    echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> "/home/$USER/.profile"

    mkdir "/home/$USER/.aws"
    echo "[default]" > "/home/$USER/.aws/config"
    echo "region = $AWS_REGION" >> "/home/$USER/.aws/config"
    echo "output = json" >> "/home/$USER/.aws/config"
    echo "[default]" > "/home/$USER/.aws/credentials"
    echo "aws_access_key_id = $AWS_ACCESS_KEY_ID" >> "/home/$USER/.aws/credentials"
    echo "aws_secret_access_key = $AWS_SECRET_ACCESS_KEY" >> "/home/$USER/.aws/credentials"
fi
echo "export PATH=\$PATH:/opt/jdgregson/$APP/scripts" >> "/home/$USER/.profile"

echo "Downloading notebooks from S3..."
if [ ! -d "$NOTEBOOK_DIR" ]; then
    mkdir "$NOTEBOOK_DIR"
fi
mkdir "/home/$USER/.jupyter"
mkdir "/home/$USER/.jupyter/lab"
aws s3 sync "s3://$NOTEBOOK_S3_BUCKET_NAME" "$NOTEBOOK_DIR"
if [ -d "$NOTEBOOK_DIR/.jupyter-sync" ]; then
    ln -s "$NOTEBOOK_DIR/.jupyter-sync/jupyter_lab_config.py" "/home/$USER/.jupyter/jupyter_lab_config.py"
    ln -s "$NOTEBOOK_DIR/.jupyter-sync/jupyter_server_config.py" "/home/$USER/.jupyter/jupyter_server_config.py"
    ln -s "$NOTEBOOK_DIR/.jupyter-sync/custom" "/home/$USER/.jupyter/custom"
    ln -s "$NOTEBOOK_DIR/.jupyter-sync/lab/user-settings" "/home/$USER/.jupyter/lab/user-settings"
fi

echo "Restoring permissions..."
chown $USER:$USER "/home/$USER" -R

echo "Deploying cloudflared..."
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
cloudflared service install $CLOUDFLARED_TOKEN
rm cloudflared.deb

echo "Deploying $APP..."
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/$APP.git "$DEPLOY_DIR/"
"$DEPLOY_DIR/opt/jdgregson/$APP/restore-permissions.sh" "$DEPLOY_DIR"
cp -fr "$DEPLOY_DIR"/* /
rm -fr "$DEPLOY_DIR"

echo "Installing Jupyter and plugins..."
sudo pip3 install \
    jupyterlab \
    jupyter-resource-usage \
    jupyterlab_theme_solarized_dark \
    jupyter_scheduler

echo "Configuring Jupyter..."
mkdir /etc/jupyter
cat >/etc/jupyter/jupyter_server_config.py <<EOF
c.ServerApp.extra_static_paths = ['/opt/jdgregson/$APP/static']
EOF

echo "Installing Jupyter extensions..."
for extension in $(find "/opt/jdgregson/$APP/extensions/" -mindepth 1 -maxdepth 1 -type d); do
    echo "Installing $extension..."
    jupyter labextension install "$extension"
done

echo "Creating Jupyter service..."
cat >/etc/systemd/system/jupyter.service <<EOF
[Unit]
Description=Jupyter

[Service]
Type=simple
ExecStart=/usr/bin/env jupyter lab --ip=$IP --port=$PORT --notebook-dir=$NOTEBOOK_DIR --LabApp.token='$JUPYTER_ACCESS_TOKEN'
Environment="HF_TOKEN=$HF_TOKEN"
Environment="WORKERS_AI_TOKEN=$WORKERS_AI_TOKEN"
WorkingDirectory=$NOTEBOOK_DIR
User=$USER
Group=$USER

Restart=always
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

echo "Starting Jupyter on $IP:$PORT..."
systemctl enable --now jupyter

echo "Creating S3 Sync service..."
cat >/etc/systemd/system/s3sync.service <<EOF
[Unit]
Description=S3 Sync
After=network.target

[Service]
User=$USER
Group=$USER
Environment="AWS_SHARED_CREDENTIALS_FILE=/home/$USER/.aws/credentials"
ExecStart=/opt/jdgregson/$APP/scripts/s3-sync "$NOTEBOOK_DIR" "$NOTEBOOK_S3_BUCKET_NAME"
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=s3sync

[Install]
WantedBy=multi-user.target
EOF

echo "Starting S3 Sync..."
systemctl enable --now s3sync

echo "Installing Microsoft Defender for Endpoint..."
DEPLOY_DIR=$(mktemp -d)
cd "$DEPLOY_DIR"
curl "https://raw.githubusercontent.com/microsoft/mdatp-xplat/refs/heads/master/linux/installation/mde_installer.sh" -o mde_installer.sh
chmod +x mde_installer.sh
./mde_installer.sh --install
rm -fr "$DEPLOY_DIR"

echo "$APP setup complete, REBOOT REQUIRED!"
