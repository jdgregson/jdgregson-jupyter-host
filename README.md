# jdgregson-jupyter-host

This repository contains the host configuration for hosts powering jupyter.jdgregson.com.

## Deployment

1. Create secrets file: `vi /root/secrets`:

```
export CLOUDFLARED_TOKEN=...
export HF_TOKEN=...
export JUPYTER_ACCESS_TOKEN=...
```

2. Deploy:

```
curl https://raw.githubusercontent.com/jdgregson/jdgregson-jupyter-host/main/opt/jdgregson/jdgregson-jupyter-host/setup.sh | sudo bash
```

