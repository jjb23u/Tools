# Tools

Portable, declarative setup for a personal offensive-security / CTF workstation,
for **authorized testing and TryHackMe-style labs only**. Two playbooks:

- `provision.yaml` (laptop / KVM host) spins up an isolated Fedora 43 VM named
  `tools` on its own firewalled network.
- `site.yaml` (inside the VM) installs the toolkit: fish, CLI tools, Python tools
  each in their own venv, wordlists, and optionally the COSMIC desktop.

## Pin the base image

Set two values in `roles/vm/defaults/main.yaml`:

- `vm_base_image_url` — on https://fedoraproject.org/cloud/download, under the
  x86_64 section, right-click **Fedora Cloud Base 43 / QEMU / qcow2** and copy the
  link. It includes the exact respin (e.g. `...-43-1.1...`), which pins the version.
- `vm_base_image_checksum` — from the same page's verify/checksum link, as
  `sha256:<hash>`. Optional but recommended; `get_url` verifies the download.

## Spin up the VM (host side)

    ansible-playbook provision.yaml -K

Installs libvirt, creates the isolated `tools-vm-net` network (NAT out, firewalled
off your LAN), downloads and verifies the image, and boots the VM with your SSH key
and passwordless sudo. DHCP assigns the address; the host resolves `tools` by name
via libvirt's NSS module, so no IP is hardcoded.

Needs an SSH key at `~/.ssh/id_ed25519.pub` (`ssh-keygen -t ed25519`).

## Configure the VM (guest side)

    ansible-playbook site.yaml --limit tools

No `-K` needed (passwordless sudo). Or on the VM itself:

    curl -fsSLO https://raw.githubusercontent.com/jjb23u/Tools/main/bootstrap.sh
    bash bootstrap.sh

## Headless vs COSMIC desktop

The default build is headless. For a GUI build (COSMIC + Wireshark), set
`with_desktop: true` in `group_vars/all.yaml`, then run **both** playbooks — the
flag gives the VM a SPICE display at provision time and installs the desktop at
configure time. Reboot the VM afterward and view it with `virt-viewer tools`.

Decide before the first provision: adding graphics to an already-headless VM means
reprovisioning (or `virsh edit tools`).

## Searching traffic from Python

`tshark` and the analysis libraries (pyshark, scapy) are always installed. The
analysis venv is exposed as `apy`, so one-liners just work:

    apy -c 'import pyshark; [print(p.highest_layer) for p in pyshark.FileCapture("cap.pcap", display_filter="http")]'

Live capture needs root (or the `wireshark` group, which the desktop build adds);
reading a pcap does not.

## Tags

- `--skip-tags wordlists` — skip the multi-GB wordlist clones
- `--tags tools` — just the Go and Python tools
- `--tags base` — just shell, directories, packages
- `--tags desktop` — just the COSMIC/GUI layer (with `-e with_desktop=true`)

## Versions

Tool versions live in `group_vars/all.yaml`. Python tools: set `version:` to pin;
unpinned installs once at latest. Go tools: installs skip once the binary exists —
delete it from `~/go/bin` to move versions.

## Workspace

Projects live under `~/workspace`, one directory per repo.

## Secrets

Nothing sensitive is committed. API keys (subfinder, nuclei) go in their own local
config; engagement output stays in `~/toolkit/loot` and `~/toolkit/notes`. The VM
uses passwordless sudo for automation — change it in
`roles/vm/templates/cloud-init-user-data.yaml.j2` if you want a sudo password.
