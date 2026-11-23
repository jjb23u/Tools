# tshark Triage Cheat Sheet

Quick reference for the first pass on any new capture.

```bash
f=capture.pcap
```

Always use `-n` so tshark never does reverse DNS lookups against attacker infrastructure.

---

## 1. Overview

```bash
capinfos "$f"                          # duration, packet count, start/end, link type
tshark -n -r "$f" -qz io,phs           # protocol hierarchy
tshark -n -r "$f" -qz expert           # malformed packets, retransmissions, resets
tshark -n -r "$f" -qz io,stat,60       # traffic volume per 60s (bursts / gaps)
```

## 2. Conversations

```bash
tshark -n -r "$f" -qz conv,eth
tshark -n -r "$f" -qz conv,ip
tshark -n -r "$f" -qz conv,tcp
tshark -n -r "$f" -qz conv,udp
```

Look for: long-duration conversations, lopsided byte counts (large outbound = possible exfil), unusual/high ports.

## 3. Endpoints, Protocols, Packet Counts

```bash
tshark -n -r "$f" -qz endpoints,ip
tshark -n -r "$f" -qz endpoints,tcp
tshark -n -r "$f" -qz endpoints,udp

# Packet counts by source IP + protocol
tshark -n -r "$f" -T fields -e ip.src -e _ws.col.Protocol | sort | uniq -c | sort -rn

# Protocol breakdown for one host
tshark -n -r "$f" -qz io,phs,ip.addr==10.0.0.5
```

## 4. Transferred Files

```bash
mkdir -p objects/{http,smb,tftp,imf,ftp}
tshark -n -r "$f" -q --export-objects http,objects/http
tshark -n -r "$f" -q --export-objects smb,objects/smb
tshark -n -r "$f" -q --export-objects tftp,objects/tftp
tshark -n -r "$f" -q --export-objects imf,objects/imf        # email
tshark -n -r "$f" -q --export-objects ftp-data,objects/ftp   # 4.x+

file objects/*/*        # true file type
sha256sum objects/*/*   # hashes for VirusTotal
```

Context for where files came from:

```bash
tshark -n -r "$f" -Y http.request -T fields -e frame.time -e ip.src -e http.host \
  -e http.request.method -e http.request.uri -e http.user_agent

tshark -n -r "$f" -qz http_req,tree

tshark -n -r "$f" -Y ftp.request.command -T fields \
  -e ip.src -e ftp.request.command -e ftp.request.arg
```

> Treat exported objects as live malware. Don't open them on your workstation.

## 5. DNS

```bash
# All queries
tshark -n -r "$f" -Y "dns.flags.response==0" -T fields \
  -e frame.time -e ip.src -e dns.qry.name -e dns.qry.type

# Most-queried names
tshark -n -r "$f" -Y "dns.flags.response==0" -T fields -e dns.qry.name \
  | sort | uniq -c | sort -rn

# Resolutions
tshark -n -r "$f" -Y "dns.flags.response==1" -T fields \
  -e dns.qry.name -e dns.a -e dns.aaaa -e dns.cname -e dns.resp.ttl

tshark -n -r "$f" -qz dns,tree
```

### Suspicious DNS filters

Use with `-Y "<filter>"`:

```text
dns.flags.rcode == 3                       # NXDOMAIN floods -> DGA
len(dns.qry.name) > 50                     # long/encoded subdomains -> tunneling/exfil
dns.qry.type == 16                         # TXT queries -> C2/tunnel channel
dns.resp.ttl < 60                          # very low TTL -> fast-flux
dns && dns.flags.response==0 && !(ip.dst == <resolver>)   # bypassing internal resolver
dns && !(udp.port == 53 || tcp.port == 53)                # DNS on non-standard port
dns.qry.name matches "\\.(xyz|top|tk|zip|ru)$"            # higher-risk TLDs
```

Also check:
- Many unique subdomains under one parent domain (tunneling)
- Hosts connecting directly to IPs with no prior DNS lookup

## 6. Other Checks

### TLS SNI

```bash
tshark -n -r "$f" -Y "tls.handshake.type==1" -T fields \
  -e ip.src -e ip.dst -e tls.handshake.extensions_server_name
```

Newer versions also expose `tls.handshake.ja3` and `tls.handshake.ja4`.

### Credentials

```bash
tshark -n -r "$f" -qz credentials
tshark -n -r "$f" -Y ntlmssp.auth.username -T fields -e ntlmssp.auth.domain -e ntlmssp.auth.username
tshark -n -r "$f" -Y kerberos.CNameString -T fields -e kerberos.CNameString
```

### DHCP hostnames (map IPs to machines)

```bash
tshark -n -r "$f" -Y dhcp.option.hostname -T fields -e ip.src -e eth.src -e dhcp.option.hostname
```

### User agents

`curl`, `python-requests`, PowerShell, or blank/odd strings are red flags.

```bash
tshark -n -r "$f" -Y http.user_agent -T fields -e http.user_agent | sort | uniq -c | sort -rn
```

### Scanning (SYN without ACK by source)

```bash
tshark -n -r "$f" -Y "tcp.flags.syn==1 && tcp.flags.ack==0" -T fields -e ip.src \
  | sort | uniq -c | sort -rn
```

### Protocol on the wrong port

```text
http && !(tcp.port in {80 8080})
tls && !(tcp.port == 443)
```

### Beaconing (look for regular intervals)

```bash
tshark -n -r "$f" -Y "ip.addr==10.0.0.5 && ip.addr==203.0.113.9" -T fields -e frame.time_delta_displayed
```

### Misc filters

```text
icmp && data.len > 64                # ICMP tunneling
arp.duplicate-address-detected       # ARP spoofing
```

### Follow a stream

```bash
tshark -n -r "$f" -qz follow,tcp,ascii,<stream_number>
```
