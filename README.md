# idekube container

This is a collection of dev containers for different use cases.

Supported Architecture: `amd64`, `arm64`

## Usage

### novnc

Visit `$IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH/novnc/` in your browser.

### coder

Visit `$IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH/coder/` in your browser.

### jupyter

Visit `$IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH/jupyter/` in your browser.

### SSH

The ssh is proxied through the nginx server via websocat. Use the following command to connect to the container:

```bash
ssh -o ProxyCommand="websocat --binary ws://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/" idekube@idekube
```

Or use this ssh config snippet:

```ssh-config
Host idekube
  User idekube
  ProxyCommand websocat --binary ws://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/
```

## Build the container

First use `make pull_deps` to pull the dependencies.

Set `BRANCH` to the branch you want to build (e.g. coder/base), then use `make build` to build the container.

Use `make publish` to push the container to the registry.

Use `make publish_all` to push all containers to the registry.

For multi-arch publish, first publish each architecture with `make publish`, then use `make manifest` to create the manifest list.

### Build Sysetem

The project use Makefile to build the container. A `scripts/build_image.sh` is used to parse `.dockerargs` file and generate docker build arguments. Image produced are taged as `docker.io/davidliyutong/idekube-container:coder-base-latest-amd64` etc.

## Architecture Explained

There are two flavors: `coder` with novnc support and `jupyter` without novnc support.

The container runs a `supervisord` process that starts services. A nginx server is used to reverse proxy the services.

The `artifacts/startup.sh` script is used to start the container. It configure the container according to environment variables and starts the `supervisord` process.

| Name                      | Description                                                      | Default     |
| ------------------------- | ---------------------------------------------------------------- | ----------- |
| `IDEKUBE_DESKTOP`         | `true` if desktop environment                                    | `false`     |
| `IDEKUBE_INIT_HOME`       | `true` if need to init home with /usr/local/share/home_template/ | `false`     |
| `IDEKUBE_PREFERED_SHELL`  | path to shell                                                    | `/bin/bash` |
| `IDEKUBE_AUTHORIZED_KEYS` | base64 encoded authorized keys                                   | `""`        |
| `IDEKUBE_INGRESS_HOST`    | Ingress host, e.g. idekube.example.com                           | `localhost` |
| `IDEKUBE_INGRESS_PATH`    | Ingress path, e.g. <user_name>/, leave empty for `/`             | `""`        |
| `IDEKUBE_INGRESS_SCHEME`  | Ingress scheme, e.g. http or https                               | `http`      |
