# jdgregson-jupyter-host

This repository contains the host configuration of hosts powering jupyter.jdgregson.com.

## Deployment

1. Create host secrets file: `vi /root/host-secrets`:

```
export CLOUDFLARED_TOKEN=...
```

2. Create host secrets file: `vi /root/host-secrets`:

```
export HF_TOKEN=...
```

3. Deploy:

```
curl https://raw.githubusercontent.com/jdgregson/jdgregson-jupyter-host/main/opt/jdgregson/jdgregson-jupyter-host/setup.sh | sudo bash
```

