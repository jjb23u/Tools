# lab-kit

Portable, declarative setup for a personal offensive-security / CTF workstation,
built for **authorized testing and TryHackMe-style labs only**. One Ansible run
turns a fresh Fedora 43 (COSMIC) box into a working toolkit: fish shell, a curated
set of CLI tools, Python tools each in their own venv, and wordlists.

## Quick start

On a fresh machine, download the bootstrap script and run it (installs Ansible,
then pulls and applies). Downloading first — rather than piping curl into bash —
gives the sudo prompt a terminal to read from:

    curl -fsSLO https://raw.githubusercontent.com/jjb23u/CHANGE_ME/main/bootstrap.sh
    bash bootstrap.sh -K

Or, if you already have Ansible:

    ansible-pull -U https://github.com/jjb23u/CHANGE_ME.git -i "localhost," --limit localhost site.yml -K

`-K` prompts for the sudo password (needed for package installs). The explicit
`-i "localhost," --limit localhost` keeps the pull from touching the `labvm`
host defined in the repo inventory.

### Provisioning the isolated VM from another machine

    ansible-playbook site.yml --limit labvm --ask-become-pass

Set the VM's IP in `inventory/hosts.yml` first.

## Tags

- `--skip-tags wordlists` — everything except the multi-GB wordlist clones
- `--tags tools` — just the Go and Python tools
- `--tags base` — just shell, directories, packages

## Versions

All tool versions live in `group_vars/all.yml`. Behavior when you change one:

- **Python tools**: set `version: "x.y.z"` and the next run converges to it.
  Left unpinned, a tool installs once at whatever was latest then and is not
  upgraded on later runs.
- **Go tools**: installs are skipped once the binary exists. To move a version,
  delete the binary from `~/go/bin` and re-run.

For a reproducible public snapshot, pin the Python tools once you've confirmed a
working set.

## Workspace

Projects live under `~/workspace`, one directory per repo. Use the `work`
fish function: `work <git-url>` to clone-and-enter, `work <name>` to jump back.

## Secrets

No credentials are committed. Tool API keys (subfinder, nuclei) belong in their
own local config (e.g. `~/.config/subfinder/provider-config.yaml`), which is not
part of this repo. Engagement output stays in `~/toolkit/loot` and `~/toolkit/notes`,
outside the repo.
