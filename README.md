# jdgregson-jupyter-host

This repository contains the host configuration of hosts powering jupyter.jdgregson.com.

## Deployment

1. Create `/root/secrets`:

```
export CLOUDFLARED_TOKEN=...
export HF_TOKEN=...
```

2. Deploy:

```
curl https://raw.githubusercontent.com/jdgregson/jdgregson-jupyter-host/main/opt/jdgregson/jdgregson-jupyter-host/setup.sh | sudo bash
```

