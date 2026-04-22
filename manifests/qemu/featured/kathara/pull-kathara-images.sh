#!/bin/bash
images=(
    docker.io/kathara/base
    docker.io/kathara/frr
    docker.io/kathara/quagga
    docker.io/kathara/pox
    docker.io/kathara/sdn
    docker.io/kathara/bind
    docker.io/kathara/bird
    docker.io/kathara/openbgpd
    docker.io/kathara/p4
    docker.io/kathara/rkill
    docker.io/kathara/scion
    docker.io/kathara/rift-python
    docker.io/kathara/katharanp
    docker.io/kathara/katharanp_vde
    docker.io/kathara/core
    docker.io/kathara/apache
    lscr.io/linuxserver/wireshark
)

for image in "${images[@]}"; do
    docker pull "$image"
done
