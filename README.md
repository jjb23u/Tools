# Tools

Portable, declarative setup for a personal offensive-security / CTF workstation,
for **authorized testing and TryHackMe-style labs only**. Two playbooks:

- `provision.yaml` (laptop / KVM host) spins up an isolated Fedora 43 VM named
  `tools` on its own firewalled network.
- `site.yaml` (inside the VM) installs the toolkit: fish, CLI tools, Python tools
  isolated with pipx, a training-sized wordlist set, and the COSMIC desktop.

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
resolves `tools` by name via libvirt's NSS module (enabled with authselect's `with-libvirt` feature),
so no IP is hardcoded.

Needs an SSH key at `~/.ssh/id_ed25519.pub` (`ssh-keygen -t ed25519`).

## Configure the VM (guest side)

    ansible-playbook site.yaml

No `-K` needed (passwordless sudo). The first run waits for cloud-init to finish.
Or on the VM itself:

    curl -fsSLO https://raw.githubusercontent.com/jjb23u/Tools/main/bootstrap.sh
    bash bootstrap.sh

## Login password

The VM user is created without a password: SSH is key-only and sudo is
passwordless. The desktop login and serial console need one, so if the user has
no usable password, `site.yaml` prompts for it (twice, hidden, 8+ characters)
and sets it on the VM. Later runs skip the prompt. Nothing is stored in the repo.

To change it later: `ssh tools passwd`.

## Accessing and managing the VM

    ssh tools                                     # terminal
    virt-viewer --connect qemu:///system tools    # desktop (dnf install virt-viewer)
    sudo virsh list --all                         # state
    sudo virsh start|shutdown|reboot tools
    sudo virsh console tools                      # serial console; Ctrl+] to exit

virt-manager (`dnf install virt-manager`, QEMU/KVM system connection) covers the
same ground in a GUI, including snapshots.

To rebuild from scratch (the old disk must go, or provisioning reuses it):

    sudo virsh destroy tools
    sudo virsh undefine tools --remove-all-storage --nvram
    ansible-playbook provision.yaml -K && ansible-playbook site.yaml

## SSH host keys

The VM's host key is trusted on first connection (`StrictHostKeyChecking=accept-new`)
and checked on every connection after that. Provisioning a new VM removes the old
`tools` entry from `~/.ssh/known_hosts` so the new key can be accepted.

## COSMIC desktop vs headless

The default build has the COSMIC desktop and Wireshark. `with_desktop: true` in
`group_vars/all.yaml` gives the VM a SPICE display at provision time and installs
the desktop at configure time. Reboot the VM after the first `site.yaml` run and
view it with `virt-viewer --connect qemu:///system tools`.

The VM gets 16 GB of RAM (`vm_memory` in `roles/vm/defaults/main.yaml`) and a
virtio GPU with 3D acceleration (virgl) rendered on the host's GPU. That's what
makes a Wayland desktop like COSMIC usable; without it the guest falls back to
software rendering. It needs a local viewer (virt-viewer or virt-manager) and a
host GPU with a render node (Intel and AMD work out of the box). If the VM fails
to start with an EGL/GL error, set `vm_desktop_gl: false` and rebuild.

`spice-vdagent` is installed for display resizing and clipboard sharing.
Clipboard sharing is limited on Wayland guests; copying over SSH is reliable.

For a headless build, set `with_desktop: false` (or pass `-e with_desktop=false`
to both playbooks). Pass it to `bootstrap.sh` too when bootstrapping a machine
that shouldn't get a desktop.

Decide before the first provision: changing the display on an existing VM means
reprovisioning (or `virsh edit tools`).

## VPN

`wireguard-tools` is installed. Bring a tunnel up from a config file with
`sudo wg-quick up ./lab.conf` (and `down` to stop), or import it into
NetworkManager with `nmcli connection import type wireguard file lab.conf`.

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

## Wordlists

SecLists is cloned to `~/toolkit/wordlists/seclists` as a shallow, sparse clone:
git only downloads the lists that are checked out. By default that is the
training set in `roles/wordlists/defaults/main.yaml` — the web-content, DNS,
password, username and fuzzing lists TryHackMe-style rooms use, plus `rockyou.txt`
extracted to `~/toolkit/wordlists/rockyou.txt`. About 290 MB on disk, versus
roughly 2.6 GB for a full clone.

Kali/AttackBox paths work, so commands from room write-ups run as written:

    /usr/share/wordlists/rockyou.txt
    /usr/share/wordlists/dirb/common.txt
    /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
    /usr/share/wordlists/SecLists/...
    /usr/share/seclists/...

To add specific larger lists, list their SecLists paths in `wordlists_extra_paths`
in `group_vars/all.yaml` and re-run `--tags wordlists`:

    wordlists_extra_paths:
      - /Usernames/xato-net-10-million-usernames.txt
      - /Discovery/DNS/dns-Jhaddix.txt

To check out everything:

    ansible-playbook site.yaml --tags wordlists -e wordlists_full=true

Running without the flag later shrinks the checkout back to the training set.
Removed lists stay cached in `.git`; delete `~/toolkit/wordlists/seclists` and
re-run to reclaim that space.

## Tags

- `--tags wordlists` — just the wordlists
- `--tags tools` — just the Go and Python tools
- `--tags base` — just shell, directories, packages
- `--tags desktop` — just the COSMIC/GUI layer

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
