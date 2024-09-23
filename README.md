# jdgregson-jupyter-host

This repository contains the host configuration for hosts powering jupyter.jdgregson.com.

jupyter.jdgregson.com is a JupyterLab implementation configured with:
 - PWA support
 - Notebook syncing to S3
 - Cloudflare tunnel support
 - AWS, Hugging Face, etc. creds pre-set

## Deployment

1. Create secrets file: `vi /root/secrets`:

```
export JUPYTER_ACCESS_TOKEN=...
export CLOUDFLARED_TOKEN=...
export HF_TOKEN=...
export NOTEBOOK_S3_BUCKET_NAME=...
export AWS_REGION=us-west-2
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

2. Deploy:

```
curl https://raw.githubusercontent.com/jdgregson/jdgregson-jupyter-host/main/opt/jdgregson/jdgregson-jupyter-host/setup.sh | sudo bash
```
