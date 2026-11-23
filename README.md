# Tools

A portable pentest/CTF toolkit that runs anywhere Docker does. The full
environment — tools plus an XFCE desktop — runs in a container and is reached
through the browser over a VNC session, so you get a familiar GUI on any
machine without installing anything locally.

## Architecture

Two containers, split so the toolkit itself is never directly exposed:

```
browser --HTTPS+auth--> frontend ----VNC over private net----> backend
                        (Caddy + noVNC)   [dmz, internal]      (XFCE + tools)
                        published :8443                         egress -> internet
```

- **frontend** — Caddy terminating TLS and enforcing login, with noVNC +
  websockify behind it. The only container that publishes a port.
- **backend** — Fedora + XFCE + the toolkit. Publishes nothing; reachable only
  from the frontend over the `dmz` network (`internal: true`). Reaches the
  internet via the `egress` network.
- **LAN fence** — `scripts/lan-fence.sh` blocks the backend's egress network
  from your home subnet while leaving internet/target access intact.

## Prerequisites

- Docker (or Podman) with the compose plugin
- On Linux, root for the LAN fence script

## Quick start

```fish
cp secrets.env.example secrets.env
docker compose build
# generate the frontend login hash and paste it into secrets.env:
docker run --rm toolkit-frontend caddy hash-password
docker compose up -d
```

Then open `https://localhost:8443/vnc.html` and log in with `FRONTEND_USER` and
the password you hashed. Accept the self-signed cert (Caddy's local CA).

## LAN fence

```fish
sudo env LAN_SUBNET=192.168.1.0/24 ./scripts/lan-fence.sh
```

Set `LAN_SUBNET` to your actual home subnet. Re-run after a Docker daemon
restart. This is a host firewall rule — the one piece that doesn't travel with
the image. DNS is pointed at 9.9.9.9/1.1.1.1 so the fence doesn't break name
resolution, and VPN'd lab targets (THM/HTB 10.x over the tunnel) are unaffected
since they're not on your LAN subnet.

## Wordlists

Kept out of the image to stay lean. Populate the volume once:

```fish
docker compose exec -u root backend \
  git clone --depth 1 https://github.com/danielmiessler/SecLists /usr/share/seclists
```

## Your work

`/home/toolkit/work` in the backend is a named volume, so loot and notes
survive rebuilds.

## Guides

CLI references in `guides/`: tshark triage, nmap, curl + gobuster, and
exploitation/privesc.

## Tools included

- Recon: nmap, ncat, tcpdump, tshark, subfinder, httpx, naabu, dnsx, katana,
  nuclei, whois, bind-utils
- Exploitation / AD: impacket, netexec, certipy, sqlmap, pwntools, bloodhound
- VPN: wireguard-tools

Your guides also reference gobuster, nikto, hydra, john, and hashcat, which
aren't in this list yet — say the word and I'll add them.
