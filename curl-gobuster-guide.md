# curl + gobuster Cheat Sheet

Quick reference for web recon on CTF boxes and authorized engagements.

```bash
t=10.10.10.10
url=http://$t
wl=/usr/share/seclists        # adjust to wherever SecLists is installed
```

> Only test sites you own or have written authorization (with defined scope) to test.

---

# curl

## 1. Inspecting Responses

```bash
curl -i "$url"                  # response headers + body
curl -I "$url"                  # HEAD request: headers only
curl -v "$url"                  # full request/response exchange (TLS, redirects, headers)
curl -s "$url"                  # silent: no progress bar
curl -sL "$url"                 # follow redirects
curl -sk https://$t             # ignore cert errors (labs/self-signed only)
curl -s -o /dev/null -w "%{http_code} %{size_download}\n" "$url"   # status + size only
```

Useful `-w` variables: `%{http_code}`, `%{size_download}`, `%{redirect_url}`, `%{time_total}`, `%{content_type}`.

## 2. First Look at a Site

```bash
curl -s "$url/robots.txt"
curl -s "$url/sitemap.xml"
curl -sI "$url" | grep -iE "server|x-powered-by|set-cookie"   # tech fingerprinting
curl -s "$url" | grep -oiE 'href="[^"]+"|src="[^"]+"' | sort -u # links and scripts
curl -s "$url" | grep -i "<!--"                               # HTML comments
curl -si -X OPTIONS "$url" | grep -i allow                    # allowed methods
```

## 3. Headers, Cookies, User Agent

```bash
curl -H "X-Forwarded-For: 127.0.0.1" "$url"
curl -A "Mozilla/5.0" "$url"                  # custom user agent
curl -e "http://google.com" "$url"            # referer
curl -b "session=abc123" "$url"               # send cookie
curl -c cookies.txt "$url/login"              # save cookies to a jar
curl -b cookies.txt "$url/dashboard"          # reuse the jar
```

## 4. Sending Data

```bash
# URL-encoded form POST
curl -s -X POST -d "username=admin&password=test" "$url/login"
curl -s --data-urlencode "q=a b&c" "$url/search"

# GET with query params built from -d
curl -s -G -d "id=1" -d "sort=asc" "$url/items"

# JSON
curl -s -H "Content-Type: application/json" -d '{"user":"admin"}' "$url/api/login"
curl -s --json '{"user":"admin"}' "$url/api/login"     # curl 7.82+

# Multipart file upload
curl -s -F "file=@test.txt" "$url/upload"

# PUT a file
curl -s -T test.txt "$url/uploads/test.txt"

# Other methods
curl -s -X DELETE "$url/api/items/1"
```

## 5. Auth and Sessions

```bash
curl -u admin:password "$url/admin"                         # basic auth
curl -H "Authorization: Bearer <token>" "$url/api/me"       # bearer token

# Log in, keep session, request an authenticated page
curl -s -c jar.txt -d "user=admin&pass=test" "$url/login" >/dev/null
curl -s -b jar.txt "$url/profile"
```

## 6. Virtual Hosts and Routing

```bash
curl -H "Host: dev.target.thm" "http://$t"                  # test a vhost without /etc/hosts
curl --resolve target.thm:443:$t https://target.thm         # pin a name to an IP (keeps SNI correct)
curl -x http://127.0.0.1:8080 -k "$url"                     # route through Burp/Caido
curl --path-as-is "$url/../../etc/passwd"                   # stop curl from normalizing ../
```

## 7. Downloading

```bash
curl -O "$url/file.zip"           # save with remote name
curl -o out.html "$url"           # save with your own name
curl -C - -O "$url/big.iso"       # resume a download
```

---

# gobuster

Modes: `dir` (paths/files), `dns` (subdomains), `vhost` (virtual hosts), `fuzz` (custom FUZZ keyword).

## Common Wordlists (SecLists)

```text
Discovery/Web-Content/common.txt                          fast first pass
Discovery/Web-Content/raft-medium-directories.txt         solid default
Discovery/Web-Content/directory-list-2.3-medium.txt       big, slow, thorough
Discovery/Web-Content/raft-medium-files.txt               files
Discovery/DNS/subdomains-top1million-5000.txt             subdomains / vhosts
```

## 1. Directory and File Discovery (`dir`)

```bash
# First pass
gobuster dir -u "$url" -w $wl/Discovery/Web-Content/common.txt -o gb-common.txt

# Deeper pass with extensions
gobuster dir -u "$url" -w $wl/Discovery/Web-Content/raft-medium-directories.txt \
  -x php,txt,html,bak,zip -t 50 -o gb-medium.txt

# HTTPS with self-signed cert
gobuster dir -u https://$t -w $wl/Discovery/Web-Content/common.txt -k
```

### Useful `dir` flags

```text
-x php,txt,bak       extensions to append
-t 50                threads (default 10)
-s 200,204,301,302   only show these codes (must pair with -b "")
-b 404,403           hide these codes (default 404)
--exclude-length N   hide responses of size N (soft-404 pages)
-r                   follow redirects
-f                   append / to each request (directory check)
-k                   skip TLS verification
-c "session=abc"     cookies
-H "Header: value"   custom header (repeatable)
-a "Mozilla/5.0"     user agent
-U user -P pass      basic auth
--proxy http://127.0.0.1:8080
--delay 100ms        slow down (use with -t 1 for rate-limited targets)
-q --no-error        clean output
-o file              save results
```

### Handling soft 404s

If every path returns 200 with the same page:

```bash
curl -s -o /dev/null -w "%{size_download}\n" "$url/doesnotexist123"   # get the "not found" size
gobuster dir -u "$url" -w $wl/Discovery/Web-Content/common.txt --exclude-length <size>
```

### Authenticated scanning

```bash
gobuster dir -u "$url" -w $wl/Discovery/Web-Content/common.txt -c "session=abc123"
```

## 2. Subdomain Discovery (`dns`)

Requires the domain to resolve via real DNS (not just `/etc/hosts`).

```bash
gobuster dns --domain example.com -w $wl/Discovery/DNS/subdomains-top1million-5000.txt -t 50
gobuster dns --domain example.com -w <wordlist> -r 1.1.1.1:53      # specific resolver
```

## 3. Virtual Host Discovery (`vhost`)

Best option on CTF boxes, where subdomains exist only on the web server.

```bash
echo "$t target.thm" | sudo tee -a /etc/hosts

gobuster vhost -u http://target.thm -w $wl/Discovery/DNS/subdomains-top1million-5000.txt \
  --append-domain -t 50
```

`--append-domain` turns `dev` into `dev.target.thm` (required in gobuster 3.2+). Filter noise with `--exclude-length`. Add any hits to `/etc/hosts`, then enumerate each one with `dir`.

## 4. Custom Fuzzing (`fuzz`)

`FUZZ` marks the injection point.

```bash
gobuster fuzz -u "$url/index.php?FUZZ=test" -w $wl/Discovery/Web-Content/burp-parameter-names.txt \
  --exclude-length <baseline_size>

gobuster fuzz -u "$url/api/v1/FUZZ" -w $wl/Discovery/Web-Content/api/api-endpoints.txt -b 404
```

---

## Typical Workflow

```bash
# 1. Fingerprint
curl -sI "$url"
curl -s "$url/robots.txt"

# 2. Fast directory pass
gobuster dir -u "$url" -w $wl/Discovery/Web-Content/common.txt -x php,txt -o gb-1.txt

# 3. Vhosts (if the site uses a hostname)
gobuster vhost -u http://target.thm -w $wl/Discovery/DNS/subdomains-top1million-5000.txt --append-domain

# 4. Inspect anything interesting by hand
curl -si "$url/<found_path>"

# 5. Deeper pass on promising directories
gobuster dir -u "$url/<found_dir>" -w $wl/Discovery/Web-Content/raft-medium-files.txt -x php,bak
```
