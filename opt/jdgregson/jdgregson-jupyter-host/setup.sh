#!/bin/bash

# Setup script for jdgregson-jupyter-host
# Author: Jonathan Gregson <hello@jdgregson.com>

USER="jupyteruser"
IP=127.0.0.1
PORT=8888
TZ="America/Los_Angeles"
APP="jdgregson-jupyter-host"
NOTEBOOK_DIR="/home/$USER/notebooks"

# Green and red echo
gecho() { echo -e "\033[1;32m$1\033[0m"; }
recho() { echo -e "\033[1;31m$1\033[0m"; }

if [ ! -f "/etc/lsb-release" ] || [ -z "$(grep '24.04' /etc/lsb-release)" ]; then
    echo "ERROR: $APP only supports Ubuntu Server 24.04"
    exit 1
fi

if [ ! -f "/root/secrets" ]; then
    echo "ERROR: /root/secrets not found"
    exit 1
fi

DEPLOY_DIR=$(mktemp -d)
cd "$DEPLOY_DIR"

gecho "Setting time zone to $TZ..."
timedatectl set-timezone "$TZ"

export DEBIAN_FRONTEND=noninteractive
source /root/secrets

# Add Docker's repository
apt-get update
apt-get install --yes ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Add NodeJS repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Install updates and dependencies
gecho "Installing updates and dependencies..."
apt-get remove needrestart --yes
apt-get upgrade --yes
apt-get install --yes \
    python3 \
    python3-pip \
    unzip \
    unattended-upgrades \
    inotify-tools \
    libplist-utils \
    vim \
    git \
    gnupg \
    gpg \
    gcc \
    g++ \
    make \
    nodejs \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    apt-transport-https \
    docker-compose-plugin

# Install CUDA dependencies
gecho "Installing CUDA dependencies..."
apt-get install --yes --no-install-recommends nvidia-driver-535-server
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600

wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb
dpkg -i cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb

cp /var/cuda-repo-ubuntu2404-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
apt-get update
apt-get install --yes cuda-toolkit-12-8

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install --yes nvidia-container-toolkit
systemctl restart docker

# Create jupyter user
gecho "Creating and configuring user..."
if [ ! -d "/home/$USER" ]; then
    echo "Creating user $USER..."
    useradd -m -s /bin/bash "$USER"
fi

usermod -aG docker $USER
echo "$USER ALL=(ALL) NOPASSWD: /sbin/reboot" | tee /etc/sudoers.d/99-$USER-reboot

# Set env vars
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

# Initial S3 sync
gecho "Downloading notebooks from S3..."
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

gecho "Restoring permissions..."
chown $USER:$USER "/home/$USER" -R

# Install Jupyterlab service
gecho "Deploying $APP..."
DEPLOY_DIR=$(mktemp -d)
git clone https://github.com/jdgregson/$APP.git "$DEPLOY_DIR/"
"$DEPLOY_DIR/opt/jdgregson/$APP/restore-permissions.sh" "$DEPLOY_DIR"
cp -fr "$DEPLOY_DIR"/* /
rm -fr "$DEPLOY_DIR"

gecho "Installing Jupyter and plugins..."
pip3 install --break-system-packages \
    jupyterlab \
    jupyter-resource-usage \
    jupyterlab_theme_solarized_dark \
    jupyter_scheduler \
    jupyter-ai[all] \
    amazon-q-developer-jupyterlab-ext

# Configure Jupyterlab service
gecho "Configuring Jupyter..."
mkdir /etc/jupyter
cat >/etc/jupyter/jupyter_server_config.py <<EOF
c.ServerApp.extra_static_paths = ['/opt/jdgregson/$APP/static']
EOF

gecho "Installing Jupyter extensions..."
for extension in $(find "/opt/jdgregson/$APP/extensions/" -mindepth 1 -maxdepth 1 -type d); do
    echo "Installing $extension..."
    jupyter labextension install "$extension"
done

gecho "Creating Jupyter service..."
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

gecho "Starting Jupyter on $IP:$PORT..."
systemctl enable --now jupyter

# Configue S3 sync
gecho "Creating S3 Sync service..."
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

gecho "Starting S3 Sync..."
systemctl enable --now s3sync

# Install MDE
gecho "Installing Microsoft Defender for Endpoint..."
curl -o microsoft.list https://packages.microsoft.com/config/ubuntu/24.04/prod.list
mv ./microsoft.list /etc/apt/sources.list.d/microsoft-prod.list
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /usr/share/keyrings/microsoft-prod.gpg > /dev/null
apt-get update
apt-get install --yes mdatp

# Install Cloudflared
gecho "Installing cloudflared..."
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
apt-get update
apt-get install --yes cloudflared

# Install awscli
gecho "Installing awscli"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

gecho "$APP setup complete, REBOOT REQUIRED!"
