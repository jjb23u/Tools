# Tools

Portable, declarative setup for a personal offensive-security / CTF workstation,
for **authorized testing and TryHackMe-style labs only**. Two playbooks:

- `provision.yaml` (laptop / KVM host) spins up an isolated Fedora 43 VM named
  `tools` on its own firewalled network.
- `site.yaml` (inside the VM) installs the toolkit: fish, CLI tools, Python tools
  isolated with pipx, wordlists, and optionally the COSMIC desktop.

## Inventory

`inventory/hosts.yaml` holds the laptop (`localhost`) and the VM. The VM is in the
`lab` group, and `site.yaml` only targets `lab`, so it can never touch the laptop.
`inventory/local.yaml` puts `localhost` in `lab` for `bootstrap.sh`.

## Pin the base image

Set two values in `roles/vm/defaults/main.yaml`:

- `vm_base_image_url` — on https://fedoraproject.org/cloud/download, under the
  x86_64 section, right-click **Fedora Cloud Base 43 / QEMU / qcow2** and copy the
  link. It includes the exact respin (e.g. `...-43-1.6...`), which pins the version.
- `vm_base_image_checksum` — from the same page's verify/checksum link, as
  `sha256:<hash>`. Optional but recommended; `get_url` verifies the download.

## Spin up the VM (host side)

    ansible-playbook provision.yaml -K

Installs libvirt (modular daemons), creates the isolated `tools-vm-net` network
(NAT out, firewalled off your LAN), downloads and verifies the image, and boots the
VM with your SSH key and passwordless sudo. DHCP assigns the address; the host
resolves `tools` by name via libvirt's NSS module (configured through authselect),
so no IP is hardcoded.

Needs an SSH key at `~/.ssh/id_ed25519.pub` (`ssh-keygen -t ed25519`).

## Configure the VM (guest side)

    ansible-playbook site.yaml

No `-K` needed (passwordless sudo). The first run waits for cloud-init to finish.
Or on the VM itself:

    curl -fsSLO https://raw.githubusercontent.com/jjb23u/Tools/main/bootstrap.sh
    bash bootstrap.sh

## SSH host keys

The VM's host key is trusted on first connection (`StrictHostKeyChecking=accept-new`)
and checked on every connection after that. Provisioning a new VM removes the old
`tools` entry from `~/.ssh/known_hosts` so the new key can be accepted.

## Headless vs COSMIC desktop

The default build is headless. For a GUI build (COSMIC + Wireshark), set
`with_desktop: true` in `group_vars/all.yaml`, then run **both** playbooks — the
flag gives the VM a SPICE display at provision time and installs the desktop at
configure time. Reboot the VM afterward and view it with `virt-viewer tools`.

Decide before the first provision: adding graphics to an already-headless VM means
reprovisioning (or `virsh edit tools`).

## Python tools

Each tool is installed with pipx into its own venv under `~/.local/share/pipx`.
Only each tool's own commands are linked into `~/.local/bin`, so shared
dependencies (impacket, Flask, etc.) never shadow each other. Manage them with
`pipx list`, `pipx upgrade <name>`, and `pipx uninstall <name>`.

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

Tool versions live in `group_vars/all.yaml`.

- Python tools: `name` is the package name (it is also the pipx venv name). Add
  `spec:` to pin or change the source, e.g. `spec: "impacket==0.13.1"` or
  `spec: "git+https://github.com/Pennyw0rth/NetExec@<tag>"`. Installs skip once
  the venv exists — `pipx uninstall <name>` (or `pipx upgrade <name>`) to move versions.
- Go tools: installs skip once the binary exists — delete it from `~/go/bin` to
  move versions.

## Workspace

Projects live under `~/workspace`, one directory per repo. The fish hook activates
the nearest `.venv` in the current directory or any parent.

## Secrets

Nothing sensitive is committed. API keys (subfinder, nuclei) go in their own local
config; engagement output stays in `~/toolkit/loot` and `~/toolkit/notes`. The VM
uses passwordless sudo for automation — change it in
`roles/vm/templates/cloud-init-user-data.yaml.j2` if you want a sudo password.
