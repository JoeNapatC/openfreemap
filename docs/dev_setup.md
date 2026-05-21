# dev setup

### Docker (recommended for quick start)

The quickest way to get started is with Docker:

```bash
# Copy the example env file
cp docker/.env.example .env

# Edit .env — set SKIP_PLANET=true and SELF_SIGNED_CERTS=true for dev

# Start just the HTTP host
docker compose up http-host

# Or start the website for development
docker compose up website
```

See [Docker deployment docs](docker_deployment.md) for full details.

### macOS (OrbStack VM)

On macOS, I recommend [OrbStack](https://orbstack.dev/).

I saved this function into my bash_profile. It sets up a clean x64-based Ubuntu 22 VM in a few seconds.

```
orb_reset() {
   orbctl delete -f ubuntu-test
   orbctl create -a amd64 ubuntu:jammy ubuntu-test
}
```

I saved the following in `.ssh/config`:

```
Host orb_my
  Hostname 127.0.0.1
  Port 32222
  IdentityFile ~/.orbstack/ssh/id_ed25519
```

Then I run commands like the following:

```
./init-server.py http-host-static orb_my
./init-server.py debug orb_my
```
