# idekube container

The IDEKUBE project was initiated to provide an IDE container, facilitating development work within Kubernetes clusters. This is a continuously updated collection of containers, primarily used in scenarios such as robotics, simulations, machine learning, and education. The project has been utilized in courses at the Shanghai Jiao Tong University Paris Elite Institute of Technology (SPEIT).

The project is divided into two branches: `coder` and `jupyter`, each offering IDE containers based on Coder and Jupyter, respectively. The `coder` branch provides a desktop environment, whereas the `jupyter` branch does not support a desktop environment. Both branches offer SSH support based on Websocat tunnels. All exposed services are reverse-proxied by the built-in Nginx on port 80 of the container, with the following endpoints:

| Endpoint             | Service                  |
|----------------------|--------------------------|
| `/coder/`            | Coder service            |
| `/jupyter/`          | Jupyter service          |
| `/novnc/`            | noVNC service            |
| `/novnc/websockify/` | noVNC websockify service |
| `/ssh`               | Websocat-proxied SSH     |

The desktop environment supports hardware acceleration based on EGL (using VirtualGL), thus eliminating the need for /tmp/.X11-unix mapping. When the container runs on an NVIDIA runtime, it should load NVIDIA's OpenGL libraries and enable hardware acceleration. If the container is not configured with a GPU, it will switch to software rendering mode. The container has been tested in Kubernetes clusters with `nvidia-device-plugin`, WSL, and `nvidia-container-toolkit`, an external display is not required.

The container supports architectures including `amd64` and `arm64`.

> Due to a lack of hardware, GPU hardware acceleration on the `arm64` architecture has not been tested.

## Get Started

This image is designed to be used in a Kubernetes cluster. The following is an example deployment for `k3s` and `nvidia-device-plugin` combo:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-pod
  template:
    metadata:
      labels:
        app: test-pod
    spec:
      runtimeClassName: nvidia
      containers:
        - name: container-0
          image: docker.io/davidliyutong/idekube-container:coder-base-v0.3.1
          env:
            - name: NVIDIA_DRIVER_CAPABILITIES # For Vulkan, OpenGL, NVEncode, etc, avoid manually mapping libs.
              value: all
          ports:
            - containerPort: 80
              name: 80tcp
              protocol: TCP
          resources: # GPU allocation
            limits:
              nvidia.com/gpu: "1"
            requests:
              nvidia.com/gpu: "1"
          securityContext:
            allowPrivilegeEscalation: true
            privileged: false
          volumeMounts:
            - mountPath: /home/idekube
              name: your-volume
            - mountPath: /dev/shm # For deep learning frameworks, e.g. PyTorch
              name: shm-volume
      volumes:
        - name: your-volume # Use a volume claim for persistent storage
          persistentVolumeClaim:
            claimName: your-pvc
        - name: shm-volume
          emptyDir:
            medium: Memory
            sizeLimit: 256Mi
```

However, it can also be used as a standalone container. The following is an example docker-compose file:

```yaml
services:
  idekube_container:
    image: davidliyutong/idekube-container:coder-base-v0.3.1
    ports:
      - "3000:80"
    volumes:
      - idekube_volume:/home/idekube
      - <your_extra_data_path>:/mnt/data
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: ["gpu"]
    ipc: host

volumes:
  idekube_volume:
    driver: local
```

To run OpenGL applications in the container, you need to use `vglrun` from `VirtualGL`. For example

```shell
vglrun glxgears
```

You can monitor the CPU usage of the container with `htop`.

## Architecture Explained

There are two flavors: `coder` with novnc support and `jupyter` without novnc support.

The container runs a `supervisord` process that starts services. A nginx server is used to reverse proxy the services.

The `artifacts/$flavor/startup.sh` script is used to start the container. It configure the container according to environment variables and starts the `supervisord` process.

| Name                      | Description                                                   | Default     |
|---------------------------|---------------------------------------------------------------|-------------|
| `IDEKUBE_INIT_HOME`       | any value if need to init home with /etc/skel/                | empty       |
| `IDEKUBE_INIT_ROOT`       | any value force init root (works only for the init container) | empty       |
| `IDEKUBE_PREFERED_SHELL`  | path to shell                                                 | `/bin/bash` |
| `IDEKUBE_AUTHORIZED_KEYS` | base64 encoded authorized keys                                | `""`        |
| `IDEKUBE_INGRESS_PATH`    | Ingress path, e.g. <uuid>/, leave empty for `/`               | `""`        |
| `I_AM_INIT_CONTAINER`     | any value if the container is an init container               | empty       |

## Usage

| URL/CMD                                                                                               | Service              | Note                      |
|-------------------------------------------------------------------------------------------------------|----------------------|---------------------------|
| `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/coder/`                                                  | Coder service        | tailing slash is required |
| `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/jupyter/`                                                | Jupyter service      | tailing slash is required |
| `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/novnc/`                                                  | noVNC service        | tailing slash is required |
| `ssh -o ProxyCommand="websocat --binary ws://INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/" idekube@idekube` | Websocat-proxied SSH |                           |

### SSH Proxy

You can also use this ssh config snippet:

```ssh-config
Host idekube
  User idekube
  ProxyCommand websocat --binary ws://INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/
```

> If you have SSL enabled, you can use `wss` instead of `ws`.

### Build Sysetem

The project use Makefile to build the container. A script `scripts/build_image.sh` is used to parse `.dockerargs` file and generate docker build arguments. Image produced are taged as `$REGISTRY/$AUTHOR/$NAME:$BRANCH-$ARCH` etc. Mutli-arch build is supported with `docker buildx` via `scripts/buildx_image.sh`.

## Build the container

First use `make pull_deps` to pull the dependencies.

Set `BRANCH` to the branch you want to build (e.g. coder/base), then use`make build` to build native image and `make buildx` to build the container for multi-arch.

> Use `make buildx_all` to build all branches sequentially.

### Build Stage Variables

You can configure environment variables to control the build process. The following variables are available:

| Name             | Description                                          | Default               |
|------------------|------------------------------------------------------|-----------------------|
| `REGISTRY`       | The registry to push the image to.                   | `"docker.io"`         |
| `AUTHOR`         | The username for the registry. Also the project name | `"davidliyutong"`     |
| `NAME`           | The project name                                     | `"idekube-container"` |
| `USE_APT_MIRROR` | Use apt mirror for faster build if set to `true`     | `false`               |
| `APT_MIRROR`     | The apt mirror to use                                | `""`                  |
| `USE_PIP_MIRROR` | Use pypi mirror for faster build if set to `true`    | `false`               |
| `PIP_MIRROR_URL` | The pypi mirror to use                               | `""`                  |
| `GIT_TAG`        | Use pypi mirror for faster build if set to `true`    | `false`               |

### Publishing

For multi-arch publish, you can also first publish each architecture with `make publish`, then use `make manifest` to create the manifest list. You may also use `make publishx` to push the multi-arch container directly to the registry.

> Use `make publishx_all` to push all branches to the registry.

### Testing the Container

Here is a checklist for testing the container:

- [ ] Coder is working
- [ ] VNC is working, with `turbovnc` and `novnc`, autocorrect resolution
- [ ] Jupyter is working
- [ ] SSH is working, with `websocat` proxy
- [ ] `glxgears` is working
- [ ] `chromium` is working, hardware acceleration is enabled
- [ ] `nvidia-smi` is working
- [ ] shell highlight is working
- [ ] `dind` is working
- [ ] Contaienr runs in the `nvidia` runtime class with GPU
- [ ] Container runs without GPU
- [ ] Container runs in the non-root user mode

## Known Issues

- For Kubernetes with Nginx Ingress Controller, `nginx.org/websocket-services: "code-server"` annotation is required for the coder service to work properly, where code-server is the service name. Optional configurations are `nginx.org/proxy-read-timeout: "3600"` and `nginx.org/proxy-send-timeout: "3600"`.

- `FUSE` is not supported in rootless container. Use `privileged: true`  (Kubernetes Deployment) or `--priviledged=true` (Docker) to enable it. However, **this has bugs with `nvidia-device-plugin`**.

## Roadmap

- [ ] Add a new branch `coder/isaac` for NVIDIA Isaac Sim support
- [ ] Add a new branch `coder/ros` for ROS support
- [ ] Add a new branch `jupyter/nlp` for NLP support
- [ ] Test multus CNI for multiple network interfaces
- [ ] Test the initContainer for persistent `/` volume
- [ ] Support for `ubuntu:20.04` and `ubuntu:22.04` base image

## Acknowledgement

Many thanks to the authors of the following projects:

* https://github.com/theasp/docker-novnc
* https://github.com/VirtualGL/virtualgl
* https://github.com/TurboVNC/turbovnc
* https://github.com/coder/coder
