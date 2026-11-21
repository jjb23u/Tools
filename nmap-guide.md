# nmap Cheat Sheet

Quick reference for recon on CTF boxes and authorized engagements.

```bash
t=10.10.10.10
```

> Only scan targets you own or have written authorization (with defined scope) to test.

`-sS`, `-sU`, `-O`, and most evasion options require `sudo`. Without root, nmap falls back to a full connect scan (`-sT`).

---

## 1. Standard Workflow

```bash
# Stage 1: all TCP ports, fast
sudo nmap -p- --min-rate 5000 -T4 -Pn "$t" -oA scans/full

# Grab open ports as a comma list
ports=$(grep -oP '\d+(?=/open)' scans/full.gnmap | paste -sd,)

# Stage 2: versions + default scripts on open ports only
sudo nmap -sC -sV -p"$ports" -Pn "$t" -oA scans/detail

# Stage 3: top UDP ports (slow; run in background)
sudo nmap -sU --top-ports 100 -Pn "$t" -oA scans/udp
```

`--min-rate 5000` is fine for CTFs. On real networks, drop it and use `-T3` or `-T4` to avoid dropped packets and disruption.

## 2. Host Discovery

```bash
nmap -sn 10.0.0.0/24                 # ping sweep, no port scan
nmap -sn -PR 192.168.1.0/24          # ARP discovery (local subnet)
nmap -sL 10.0.0.0/24                 # list targets only, no packets sent
nmap -Pn "$t"                        # skip discovery; treat host as up (THM/HTB boxes often block ICMP)
nmap -iL targets.txt --exclude 10.0.0.1
```

## 3. Scan Types

```text
-sS   SYN "half-open" scan (default as root)
-sT   TCP connect scan (default without root)
-sU   UDP scan
-sA   ACK scan: maps firewall rules (filtered vs unfiltered)
-sN   NULL scan  \
-sF   FIN scan    > can slip past stateless filters; unreliable on Windows
-sX   Xmas scan  /
-sV   service/version detection (--version-intensity 0-9)
-sC   default NSE scripts (same as --script default)
-O    OS detection
-A    -O -sV -sC --traceroute
```

## 4. Port Selection

```text
-p 22,80,443        specific ports
-p 1-1000           range
-p-                 all 65535
--top-ports 100     most common N
-F                  top 100 (fast)
-p U:53,161,T:22    mixed UDP/TCP (with -sU -sS)
```

## 5. Timing and Performance

```text
-T0 .. -T5          paranoid .. insane (T4 is the usual CTF default)
--min-rate N        at least N packets/sec
--max-retries N     fewer retries = faster, less accurate
--host-timeout 10m  give up on slow hosts
--stats-every 30s   periodic progress (or press space during a scan)
```

## 6. Output

```text
-oN file      normal
-oG file      grepable
-oX file      XML
-oA base      all three (always use this)
--open        show only open ports
-v / -vv      verbose; prints open ports as found
--reason      why a port is in its state
--packet-trace  show every packet sent/received
```

```bash
xsltproc scans/detail.xml -o scans/detail.html   # HTML report
ndiff old.xml new.xml                            # compare two scans
```

## 7. NSE Scripts

```bash
ls /usr/share/nmap/scripts/ | grep smb      # find scripts
nmap --script-help smb-enum-shares          # what a script does
sudo nmap --script-updatedb                 # refresh script index

nmap --script vuln -p"$ports" "$t"          # known-vuln checks (noisy)
nmap --script "smb-* and not brute" -p445 "$t"
nmap --script <name> --script-args key=value "$t"
```

Categories: `default`, `safe`, `discovery`, `version`, `vuln`, `auth`, `brute`, `intrusive`, `exploit`, `dos`.

> `intrusive`, `brute`, `exploit`, and `dos` can lock accounts or crash services. Keep them out of real engagements unless they're in scope.

## 8. Per-Service Enumeration

### FTP (21)
```bash
nmap -p21 --script ftp-anon,ftp-syst "$t"
```

### SSH (22)
```bash
nmap -p22 --script ssh2-enum-algos,ssh-hostkey,ssh-auth-methods "$t"
```

### SMTP (25/465/587)
```bash
nmap -p25 --script smtp-commands,smtp-enum-users,smtp-open-relay "$t"
```

### DNS (53)
```bash
nmap -p53 --script dns-zone-transfer --script-args dns-zone-transfer.domain=example.com "$t"
nmap --script dns-brute --script-args dns-brute.domain=example.com
```

### HTTP/HTTPS (80/443/8080)
```bash
nmap -p80,443,8080 --script http-title,http-headers,http-methods,http-robots.txt,http-enum "$t"
```

### Kerberos (88)
```bash
nmap -p88 --script krb5-enum-users --script-args krb5-enum-users.realm=CORP.LOCAL,userdb=users.txt "$t"
```

### NFS (111/2049)
```bash
nmap -p111,2049 --script nfs-ls,nfs-showmount,nfs-statfs "$t"
```

### SMB (139/445)
```bash
nmap -p445 --script smb-os-discovery,smb-protocols,smb2-security-mode,smb-enum-shares,smb-enum-users "$t"
nmap -p445 --script smb-vuln-ms17-010 "$t"
```

### SNMP (161/udp)
```bash
sudo nmap -sU -p161 --script snmp-info,snmp-sysdescr,snmp-interfaces "$t"
```

### LDAP (389/636)
```bash
nmap -p389 --script ldap-rootdse "$t"
```

### MySQL (3306)
```bash
nmap -p3306 --script mysql-info,mysql-empty-password "$t"
```

### RDP (3389)
```bash
nmap -p3389 --script rdp-enum-encryption,rdp-ntlm-info "$t"
```

### TLS (any TLS port)
```bash
nmap -p443 --script ssl-cert,ssl-enum-ciphers "$t"
```

## 9. Firewall / IDS Evasion

Know these for exams and CTFs. Use only when in scope.

```text
-f / --mtu 16        fragment packets
-D RND:5             decoy source IPs
-S <ip> -e <iface>   spoof source IP (you won't see replies)
-g 53                spoof source port (e.g. DNS)
--data-length 25     append random data
--randomize-hosts    shuffle target order
--spoof-mac 0        random MAC
```

## 10. Port States

```text
open            service accepting connections
closed          reachable, nothing listening
filtered        no response / ICMP unreachable (firewall)
unfiltered      reachable, state unknown (ACK scan)
open|filtered   no response (common for UDP)
```
