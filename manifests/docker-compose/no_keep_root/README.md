# Deploying `agent-base-v0.6.2` with Docker Compose

A minimal, no-keep-root deployment of the IDEKube agent image. It exposes
only the openclaw gateway (`/agent`) and the web SSH endpoint (`/ssh`),
reverse-proxied by Nginx on port 80 inside the container.

## Quick start

```bash
cd manifests/docker-compose/no_keep_root
docker compose up -d
```

Then open <http://localhost:3000/agent> for the agent UI, or
<http://localhost:3000/ssh> for the in-browser terminal.

The home directory is persisted to `./data` on the host, which is bind-mounted
to `/home/idekube` inside the container.

## Base compose file

See [docker-compose.yaml](docker-compose.yaml):

```yaml
services:
  idekube_container:
    image: davidliyutong/idekube-container:agent-base-v0.6.2
    ports:
      - "3000:80"
    volumes:
      - ./data:/home/idekube
    environment:
      - IDEKUBE_PREFERED_SHELL=/bin/zsh
    ipc: host
```

## Injecting SSH authorized keys

The container reads `IDEKUBE_AUTHORIZED_KEYS` on startup, base64-decodes it,
and writes the result to `/home/idekube/.ssh/authorized_keys` with mode
`600`. See the handler in
[startup.sh:191-203](../../../artifacts/docker/startup-scripts/startup.sh#L191-L203).

Encode your public key(s) on the host:

```bash
# single key
base64 -w0 ~/.ssh/id_ed25519.pub

# or multiple keys concatenated
cat ~/.ssh/id_ed25519.pub ~/team/*.pub | base64 -w0
```

On macOS use `base64` without `-w0` (it emits a single line by default).

Add the result to the `environment:` block:

```yaml
    environment:
      - IDEKUBE_PREFERED_SHELL=/bin/zsh
      - IDEKUBE_AUTHORIZED_KEYS=c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBS...
```

After `docker compose up -d`, you can SSH either through the web terminal at
`/ssh` or directly over the proxied port once you publish it. To verify the
keys landed correctly:

```bash
docker compose exec idekube_container cat /home/idekube/.ssh/authorized_keys
```

## Matching the host UID

By default the in-container user `idekube` owns `/home/idekube`. When the
home directory is bind-mounted from the host (as it is here), file ownership
on the host side will only match your host user if the container user's UID
equals your host UID — otherwise new files appear as a foreign UID on the
host, and existing host files may be unreadable inside the container.

Set `IDEKUBE_USER_UID` to your host UID. The startup script calls
`usermod -u` and re-chowns the home directory to the new UID. See
[startup.sh:104-120](../../../artifacts/docker/startup-scripts/startup.sh#L104-L120).

```bash
id -u    # e.g. 1000
```

```yaml
    environment:
      - IDEKUBE_PREFERED_SHELL=/bin/zsh
      - IDEKUBE_USER_UID=1000
      - IDEKUBE_AUTHORIZED_KEYS=c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBS...
```

Verify inside the container:

```bash
docker compose exec idekube_container id idekube
# uid=1000(idekube) gid=1000(idekube) groups=1000(idekube)
```

And on the host, files written under `./data` should now be owned by your
user, not by a stray UID.

## Full example

```yaml
services:
  idekube_container:
    image: davidliyutong/idekube-container:agent-base-v0.6.2
    ports:
      - "3000:80"
    volumes:
      - ./data:/home/idekube
    environment:
      - IDEKUBE_PREFERED_SHELL=/bin/zsh
      - IDEKUBE_USER_UID=1000
      - IDEKUBE_AUTHORIZED_KEYS=c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBS...
    ipc: host
```
