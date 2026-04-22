# featured/kathara QEMU image

Ubuntu 24.04 VM with Kathara network-emulation framework and Docker v28 pre-installed.

## Why Docker is installed but not started during provisioning

`install.yml` installs `docker-ce` v28 from the official apt repo but leaves the daemon **stopped, disabled, and masked**. Images are not pre-pulled during `make build_qemu_root`. This is deliberate.

### What happens if Docker starts during provisioning

The VM is provisioned over an SSH session forwarded by QEMU's user-mode network backend (slirp). `scripts/shell/build_qemu_root.sh` runs `ansible-playbook -c ssh` against `idekube@localhost:10022`, which slirp maps to the guest's `eth0` at `10.0.2.15:22`.

When `dockerd` starts it does all of the following in quick succession:

1. Creates the `docker0` bridge and flips `net.ipv4.ip_forward=1` + `bridge-nf-call-iptables=1`.
2. Loads `br_netfilter`, `overlay`, `nf_nat`, `xt_conntrack`, … modules.
3. Inserts `DOCKER`, `DOCKER-USER`, `DOCKER-ISOLATION-STAGE-1/2` chains in `filter` and `nat`.
4. On Ubuntu 24.04 the iptables CLI talks to the nftables backend; the rule-load is an atomic ruleset swap that briefly drops packets.
5. Flushes conntrack entries that no longer match the new ruleset.

Step 5 kills the provisioning SSH connection. Slirp-forwarded TCP cannot recover because the conntrack entry is gone and slirp itself has no retransmit affinity. Symptoms observed:

- Established SSH session freezes mid-task.
- New `ssh -p 10022` connections time out during banner exchange.
- `curl`/`apt` inside the guest hangs.
- QEMU host process is healthy (ppoll, ~10% CPU); the *guest network stack* is wedged.

### What the playbook does instead

| Step | Mitigation |
|---|---|
| Before `apt install docker-ce` | `update-alternatives --set iptables iptables-legacy` (and ip6tables). Avoids the Ubuntu 24.04 nft-backend rule swap. |
| Before `apt install docker-ce` | Drop `/usr/sbin/policy-rc.d` returning 101. dpkg postinst respects this and skips `invoke-rc.d docker start`. |
| After `apt install docker-ce` | Remove `policy-rc.d` so subsequent package installs behave normally. |
| After `apt install docker-ce` | `systemctl stop/disable/mask docker.service docker.socket containerd.service`. |
| Later in playbook | Clone `Kathara-Labs` repo only. **No** `docker pull`, **no** daemon start. |

## Bringing Docker up at runtime

Once the VM is booted for actual use (not provisioning), unmask and start Docker manually:

```bash
sudo systemctl unmask docker.service docker.socket containerd.service
sudo systemctl enable --now docker.service
```

Optionally wire this into `/etc/idekube/startup.bash/20-docker.sh` or a systemd unit that runs only when the VM is running under the container entrypoint, not during Ansible provisioning.

## Pre-pulling Kathara images

Done after the daemon is up:

```bash
for img in kathara/base kathara/frr kathara/quagga; do
  docker pull docker.io/$img
done
```

If you want these baked into the disk image, add a new branch (e.g. `featured/kathara-prepulled`) that starts from `featured/kathara` via the `IDEKUBE_FROM` mechanism in `images.json` — boot that VM, unmask+start Docker, pull, shut down cleanly. Don't do it in `install.yml` or you'll reintroduce the hang.

## If it still hangs

1. **Confirm Docker is really masked.** SSH into the VM, run `systemctl is-enabled docker docker.socket containerd` — all three must report `masked`.
2. **Check iptables backend.** `sudo iptables --version` should say `(legacy)` not `(nf_tables)`.
3. **Next suspect: `wireshark-common` postinst.** It calls `dpkg-reconfigure` which prompts for "non-superusers should capture packets" — if stdin is not a tty, it may block. `DEBIAN_FRONTEND=noninteractive` on the apt task is required (already set).
4. **Next suspect: `unattended-upgrades`.** Can hold `/var/lib/dpkg/lock-frontend` for minutes in parallel with the playbook's apt tasks. Add `apt: lock_timeout=300` or disable the service before provisioning.

## Reference: playbook task order

```
Update apt cache
Install required system packages (ca-certificates, curl, gnupg, …)
Setup Docker:
  Switch iptables → legacy
  Ensure /etc/apt/keyrings exists
  Add Docker GPG key (with retry)
  Detect dpkg architecture
  Add Docker apt repo
  Resolve latest 5:28.x version via apt-cache madison
  Install policy-rc.d guard
  apt install docker-ce{,-cli}=<pinned>, containerd.io, buildx, compose
  Remove policy-rc.d
  systemctl stop + disable + mask docker.service / docker.socket / containerd.service
  Add idekube to docker group
Setup Kathara (amd64): add PPA, apt install kathara
Install network tools (wireshark, tcpdump, …)
Setup netcap (amd64): download + extract + install
Setup Kathara Labs: clone repo only (no docker pull, no daemon start)
Cleanup
```
