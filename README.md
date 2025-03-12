# idekube container

This is a collection of dev containers for different use cases.

Supported Architecture: `amd64`, `arm64`

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


## Architecture Explained

There are two flavors: `coder` with novnc support and `jupyter` without novnc support.

The container runs a `supervisord` process that starts services. A nginx server is used to reverse proxy the services.

The `artifacts/$flavor/startup.sh` script is used to start the container. It configure the container according to environment variables and starts the `supervisord` process.

| Name                      | Description                                                      | Default     |
| ------------------------- | ---------------------------------------------------------------- | ----------- |
| `IDEKUBE_INIT_HOME`       | `true` if need to init home with /etc/skel/                      | `false`     |
| `IDEKUBE_PREFERED_SHELL`  | path to shell                                                    | `/bin/bash` |
| `IDEKUBE_AUTHORIZED_KEYS` | base64 encoded authorized keys                                   | `""`        |
| `IDEKUBE_INGRESS_PATH`    | Ingress path, e.g. <uuid>/, leave empty for `/`                  | `""`        |

## Usage

### novnc

Visit `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/novnc/` in your browser.

### coder

Visit `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/coder/` in your browser.

### jupyter

Visit `$SCHEME://INGRESS_HOST$IDEKUBE_INGRESS_PATH/jupyter/` in your browser.

### SSH

The ssh is proxied through the nginx server via websocat. Use the following command to connect to the container:

```bash
ssh -o ProxyCommand="websocat --binary ws://INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/" idekube@idekube
```

You can also use this ssh config snippet:

```ssh-config
Host idekube
  User idekube
  ProxyCommand websocat --binary ws://INGRESS_HOST$IDEKUBE_INGRESS_PATH/ssh/
```

> If you have SSL enabled, you can use `wss` instead of `ws`.

## Build the container

First use `make pull_deps` to pull the dependencies.

Set `BRANCH` to the branch you want to build (e.g. coder/base), then use `make buildx` to build the container for multi-arch.

Use `make buildx_all` to build all branches

Use `make publishx` to push the container to the registry.

Use `make publishx_all` to push all containers to the registry.

For multi-arch publish, you can also first publish each architecture with `make publish`, then use `make manifest` to create the manifest list.

### Build Sysetem

The project use Makefile to build the container. A `scripts/build_image.sh` is used to parse `.dockerargs` file and generate docker build arguments. Image produced are taged as `docker.io/davidliyutong/idekube-container:coder-base-latest-amd64` etc.

## Known Issues

- For Kubernetes with Nginx Ingress Controller, `nginx.org/websocket-services: "code-server"` annotation is required for the coder service to work properly, where code-server is the service name. Optional configurations are `nginx.org/proxy-read-timeout: "3600"` and `nginx.org/proxy-send-timeout: "3600"`.

- `FUSE` is not supported in this container if using Kubernetes. Use `privileged: true` in the deployment to enable it (this has confilicts with `nvidia-device-plugin`).
