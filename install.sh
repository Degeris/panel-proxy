#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

APP_NAME='𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Reverse Proxy'
STATE_DIR='/etc/degeris-proxy'
STATE_FILE="$STATE_DIR/config"
BACKUP_DIR="$STATE_DIR/backups"
CERTBOT_INSTALLED_BY_US='0'
ACME_ROOT='/var/www/degeris-acme'
NGINX_SITE='/etc/nginx/sites-available/degeris-proxy.conf'
NGINX_LINK='/etc/nginx/sites-enabled/degeris-proxy.conf'
NGINX_HASH='/etc/nginx/conf.d/degeris-proxy-hash.conf'
DSADMIN_BIN='/usr/local/bin/dsadmin'
DSADMIN_SBIN='/usr/local/sbin/dsadmin'
MANAGER_BIN='/usr/local/sbin/degeris-proxy-manager'
INTERNAL_PORT=6060
HTTP_PORT=80
HTTPS_PORT=443
LOCK_FILE='/run/degeris-proxy.lock'

info(){ printf '[INFO] %s\n' "$*"; }
ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[WARNING] %s\n' "$*" >&2; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

need_root(){ [[ $EUID -eq 0 ]] || die 'Run as root.'; }
cmd(){ command -v "$1" >/dev/null 2>&1; }

valid_domain(){
  local d="$1"
  [[ "$d" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]
}

valid_webpass(){
  # Custom WebPass: 4-64 chars, only A-Z a-z 0-9 - _ (safe inside an Nginx path/regex).
  local LC_ALL=C
  [[ "$1" =~ ^[A-Za-z0-9_-]{4,64}$ ]]
}

normalize_domain(){
  local d="$1"
  d="${d//[$'\r\n\t ']/}"
  d="${d#https://}"
  d="${d#http://}"
  [[ "$d" != */* ]] || return 1
  valid_domain "$d" || return 1
  printf '%s' "${d,,}"
}

parse_backend(){
  python3 - "$1" <<'PY'
import sys, urllib.parse, re
raw=sys.argv[1].strip()
u=urllib.parse.urlsplit(raw)
if u.scheme not in ('http','https') or not u.hostname or u.username or u.password or u.query or u.fragment:
    raise SystemExit(1)
port=u.port or (443 if u.scheme=='https' else 80)
path=u.path.rstrip('/') or '/'
if '//' in path or any(c in path for c in ('\\',';','`','"',"'",'$')):
    raise SystemExit(1)
if not re.fullmatch(r'/[A-Za-z0-9._~!@&()*+,=:%/-]*', path):
    raise SystemExit(1)
print(u.scheme)
print(u.hostname)
print(port)
print(path)
PY
}

load_state(){
  [[ -f "$STATE_FILE" ]] || return 1
  DOMAIN=''; BACKEND_URL=''; WEBPASS_ENABLED='1'; WEBPASS=''; HASH_MANAGED='0'; CERTBOT_INSTALLED_BY_US='0'
  [[ "$(stat -c '%a' "$STATE_FILE" 2>/dev/null || echo 999)" == '600' ]] || return 1
  # Created only by this installer via printf %q.
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  valid_domain "$DOMAIN" || return 1
  parse_backend "$BACKEND_URL" >/dev/null || return 1
  case "$WEBPASS_ENABLED" in
    1) valid_webpass "$WEBPASS" || return 1 ;;
    0) WEBPASS='' ;;
    *) return 1 ;;
  esac
}

save_state(){
  mkdir -p "$STATE_DIR"
  local tmp="$STATE_FILE.tmp.$$"
  {
    printf 'DOMAIN=%q\n' "$DOMAIN"
    printf 'BACKEND_URL=%q\n' "$BACKEND_URL"
    printf 'WEBPASS_ENABLED=%q\n' "$WEBPASS_ENABLED"
    printf 'WEBPASS=%q\n' "$WEBPASS"
    printf 'HASH_MANAGED=%q\n' "${HASH_MANAGED:-0}"
    printf 'CERTBOT_INSTALLED_BY_US=%q\n' "${CERTBOT_INSTALLED_BY_US:-0}"
  } > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

backup_nginx(){
  mkdir -p "$BACKUP_DIR"
  local f="$BACKUP_DIR/nginx-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
  tar -czf "$f" -C / etc/nginx
  printf '%s' "$f"
}

backup_managed(){
  mkdir -p "$BACKUP_DIR"
  if [[ -f "$NGINX_SITE" ]]; then
    cp -a "$NGINX_SITE" "$BACKUP_DIR/site-$(date +%Y%m%d-%H%M%S)-$$.conf"
  fi
  if [[ -f "$STATE_FILE" ]]; then
    cp -a "$STATE_FILE" "$BACKUP_DIR/state-$(date +%Y%m%d-%H%M%S)-$$"
  fi
}

snapshot(){
  SNAP_SITE_EXISTS=0
  SNAP_LINK_EXISTS=0
  SNAP_STATE_EXISTS=0
  SNAP_HASH_EXISTS=0
  SNAP_SITE=''
  SNAP_STATE=''
  SNAP_HASH=''
  if [[ -f "$NGINX_SITE" ]]; then SNAP_SITE_EXISTS=1; SNAP_SITE="$(cat "$NGINX_SITE")"; fi
  if [[ -L "$NGINX_LINK" ]]; then SNAP_LINK_EXISTS=1; fi
  if [[ -f "$STATE_FILE" ]]; then SNAP_STATE_EXISTS=1; SNAP_STATE="$(cat "$STATE_FILE")"; fi
  if [[ -f "$NGINX_HASH" ]]; then SNAP_HASH_EXISTS=1; SNAP_HASH="$(cat "$NGINX_HASH")"; fi
}

restore_snapshot(){
  if [[ "$SNAP_SITE_EXISTS" == 1 ]]; then printf '%s\n' "$SNAP_SITE" > "$NGINX_SITE"; else rm -f "$NGINX_SITE"; fi
  if [[ "$SNAP_LINK_EXISTS" == 1 ]]; then ln -sfn "$NGINX_SITE" "$NGINX_LINK"; else rm -f "$NGINX_LINK"; fi
  if [[ "$SNAP_STATE_EXISTS" == 1 ]]; then printf '%s\n' "$SNAP_STATE" > "$STATE_FILE"; chmod 600 "$STATE_FILE"; else rm -f "$STATE_FILE"; fi
  if [[ "$SNAP_HASH_EXISTS" == 1 ]]; then printf '%s\n' "$SNAP_HASH" > "$NGINX_HASH"; chmod 644 "$NGINX_HASH"; else rm -f "$NGINX_HASH"; fi
}

restore_pair(){
  local old_site="$1" old_state="$2"
  printf '%s\n' "$old_site" > "$NGINX_SITE"
  printf '%s\n' "$old_state" > "$STATE_FILE"
  chmod 600 "$STATE_FILE"
  ln -sfn "$NGINX_SITE" "$NGINX_LINK"
}

remove_own_stale_links(){
  rm -f \
    /etc/nginx/sites-enabled/degeris-proxy-public.conf \
    /etc/nginx/sites-available/degeris-proxy.conf.precert \
    /etc/nginx/sites-enabled/degeris-proxy-acme.conf \
    /etc/nginx/sites-available/degeris-proxy-acme.conf
}

clean_own_dangling_links(){
  local dir='/etc/nginx/sites-enabled'
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' link; do
    local base
    base="${link##*/}"
    # NEVER remove the canonical managed link. Some systems include it
    # explicitly from nginx.conf instead of using sites-enabled/* .
    [[ "$link" == "$NGINX_LINK" ]] && continue
    case "$base" in
      degeris-proxy-public.conf|degeris-proxy-acme.conf|degeris-proxy-*.conf.precert) ;;
      *) continue ;;
    esac
    [[ -e "$link" ]] || rm -f -- "$link"
  done < <(find "$dir" -maxdepth 1 -type l -print0)
}

nginx_explicitly_includes_own_site(){
  grep -RqsF \
    "include ${NGINX_LINK};" \
    /etc/nginx/nginx.conf /etc/nginx/conf.d 2>/dev/null
}

remove_own_explicit_includes(){
  local f
  for f in /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    if grep -qF "include ${NGINX_LINK};" "$f" 2>/dev/null; then
      sed -i "\|^[[:space:]]*include[[:space:]]*${NGINX_LINK};[[:space:]]*$|d" "$f"
    fi
  done
}

ensure_own_link(){
  mkdir -p "$(dirname "$NGINX_SITE")" "$(dirname "$NGINX_LINK")"
  # If nginx.conf explicitly includes the canonical path, that path must
  # exist before any nginx -t/start. An empty managed file is harmless and
  # is replaced by render_site() later in the same install.
  if [[ ! -e "$NGINX_SITE" ]]; then
    printf '%s\n' '# Managed by 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 (temporary pre-install placeholder)' > "$NGINX_SITE"
    chmod 600 "$NGINX_SITE"
  fi
  ln -sfn "$NGINX_SITE" "$NGINX_LINK"
}

ensure_hash_setting(){
  mkdir -p /etc/nginx/conf.d
  if [[ -f "$NGINX_HASH" ]] && grep -qx 'server_names_hash_bucket_size 64;' "$NGINX_HASH"; then
    HASH_MANAGED=1
    return 0
  fi
  if [[ -f "$NGINX_HASH" ]]; then
    rm -f "$NGINX_HASH"
  fi
  HASH_MANAGED=0

  local found='' size=''
  found="$(grep -RhsE '^[[:space:]]*server_names_hash_bucket_size[[:space:]]+[0-9]+;[[:space:]]*$' /etc/nginx/nginx.conf /etc/nginx/conf.d 2>/dev/null | head -1 || true)"
  if [[ -n "$found" ]]; then
    size="$(awk '{print $2}' <<< "$found" | tr -d ';')"
    [[ "$size" =~ ^[0-9]+$ ]] || die 'Existing server_names_hash_bucket_size is malformed.'
    (( size >= 64 )) || die "Existing server_names_hash_bucket_size is $size. Increase it to 64+ before installing."
    return 0
  fi

  grep -Eq '^[[:space:]]*include[[:space:]]+/etc/nginx/conf\.d/\*\.conf;' /etc/nginx/nginx.conf \
    || die 'Nginx does not include /etc/nginx/conf.d/*.conf; refusing to edit nginx.conf automatically.'

  printf '%s\n' '# Managed by 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍' 'server_names_hash_bucket_size 64;' > "$NGINX_HASH"
  chmod 644 "$NGINX_HASH"
  HASH_MANAGED=1
}


check_ports(){
  local line p
  line="$(ss -ltnp 2>/dev/null | grep -E "127\.0\.0\.1:${INTERNAL_PORT}([^0-9]|$)" | head -1 || true)"
  if [[ -n "$line" ]]; then
    if [[ "$line" == *nginx* ]] && grep -RqsE "^[[:space:]]*listen[[:space:]]+127\.0\.0\.1:${INTERNAL_PORT};" /etc/nginx/sites-enabled 2>/dev/null; then
      info "Port ${INTERNAL_PORT} is already used by the existing DegerisVPN proxy; it will be regenerated safely."
    else
      die "Internal port ${INTERNAL_PORT} is already in use. No process will be killed."
    fi
  fi
  for p in "$HTTP_PORT" "$HTTPS_PORT"; do
    line="$(ss -ltnp 2>/dev/null | grep -E "0\.0\.0\.0:${p}([^0-9]|$)|\[::\]:${p}([^0-9]|$)" | head -1 || true)"
    if [[ -n "$line" && "$line" != *nginx* ]]; then
      die "Port ${p} is occupied by a non-Nginx process: $line"
    fi
  done
}

ensure_nginx(){
  cmd nginx || die 'Nginx is required but was not found.'
  cmd systemctl || die 'systemctl is required.'
  systemctl is-active --quiet nginx || systemctl start nginx
}

ensure_certbot(){
  if ! cmd certbot; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y certbot >/dev/null
    CERTBOT_INSTALLED_BY_US='1'
  fi
}

check_dns(){
  local ip local_ips
  ip="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
  local_ips="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | sort -u)"
  printf 'DNS IPv4s:\n%s\n' "${ip:-unknown}"
  printf 'VPS IPv4s:\n%s\n' "${local_ips:-unknown}"
  if [[ -n "$ip" ]] && ! grep -qx "$ip" <<< "$local_ips"; then
    warn 'DNS does not point directly to an IPv4 assigned to this VPS. NAT/proxying may still be valid; Certbot must be able to reach HTTP port 80.'
  else
    ok 'DNS points to an IPv4 assigned to this VPS.'
  fi
}

write_acme_site(){
  # Remove only this project's legacy ACME vhost/link so there is exactly one
  # HTTP vhost for the managed domain during HTTP-01 validation.
  rm -f /etc/nginx/sites-enabled/degeris-proxy-acme.conf /etc/nginx/sites-available/degeris-proxy-acme.conf
  mkdir -p "$ACME_ROOT/.well-known/acme-challenge"
  chown -R www-data:www-data "$ACME_ROOT"
  chmod 755 "$ACME_ROOT" "$ACME_ROOT/.well-known" "$ACME_ROOT/.well-known/acme-challenge"
  cat > "$NGINX_SITE" <<EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name ${DOMAIN};
    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
        default_type text/plain;
        try_files \$uri =404;
    }
    location / { return 404; }
}
EOF
  ln -sfn "$NGINX_SITE" "$NGINX_LINK"
}

acme_local_self_test(){
  local token_file="$1"
  local expected="$2"
  local body_file
  local code
  body_file="$(mktemp /tmp/degeris-acme-body.XXXXXX)"

  # Write and verify the challenge file BEFORE asking Nginx to serve it.
  # This catches a zero-byte/truncated challenge immediately.
  # IMPORTANT: the installer runs with umask 077. A newly-created token
  # would therefore be mode 600/root:root and nginx (www-data) could not
  # read it, producing the exact 404/empty challenge failure seen before.
  # Write it, then explicitly make it readable by nginx.
  printf '%s\n' "$expected" > "$token_file"
  chown www-data:www-data "$token_file"
  chmod 644 "$token_file"
  if [[ ! -s "$token_file" ]] || ! grep -Fxq "$expected" "$token_file"; then
    rm -f "$body_file" "$token_file"
    return 1
  fi

  # Test the same Host header ACME will use, but connect directly to the
  # local Nginx listener. This avoids DNS-hairpin/proxy behavior and also
  # avoids curl --resolve differences on VPS environments.
  code="$(curl -4 -sS --max-time 10 --connect-timeout 5 \
    -H "Host: ${DOMAIN}" \
    -o "$body_file" -w '%{http_code}' \
    "http://127.0.0.1:${HTTP_PORT}/.well-known/acme-challenge/$(basename "$token_file")" || true)"

  if [[ "$code" != '200' ]]; then
    rm -f "$body_file" "$token_file"
    return 1
  fi

  # The ACME challenge body must be byte-for-byte identical to the file.
  if ! [[ -s "$body_file" ]] || ! cmp -s "$token_file" "$body_file"; then
    local expected_bytes actual_bytes
    expected_bytes="$(wc -c < "$token_file" | tr -d ' ')"
    actual_bytes="$(wc -c < "$body_file" | tr -d ' ')"
    warn "ACME self-test body mismatch: HTTP=${code}, expected_bytes=${expected_bytes}, actual_bytes=${actual_bytes}"
    warn "ACME token file: $token_file"
    warn "ACME token perms: $(stat -c '%U:%G %a %s bytes' "$token_file" 2>/dev/null || true)"
    warn "ACME body dump: $(od -An -tx1 -v "$body_file" | tr '\n' ' ')"
    warn "Matching Nginx server_name entries:"
    nginx -T 2>&1 | grep -n -B3 -A10 -F "server_name ${DOMAIN};" >&2 || true
    rm -f "$body_file" "$token_file"
    return 1
  fi

  rm -f "$body_file" "$token_file"
  return 0
}

obtain_certificate(){
  local cert="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  local key="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
  if [[ -s "$cert" && -s "$key" ]]; then
    ok "SSL certificate exists for ${DOMAIN}."
    return 0
  fi
  ensure_certbot
  write_acme_site
  nginx -t
  systemctl reload nginx

  local self_test_file="$ACME_ROOT/.well-known/acme-challenge/degeris-self-test"

  # First try the normal Nginx webroot flow. If Nginx cannot serve the
  # challenge (duplicate server_name, stale vhost, proxy in front, etc.),
  # fall back automatically to Certbot standalone HTTP-01 instead of aborting.
  # Standalone temporarily stops Nginx, binds TCP/80 directly, then the
  # Certbot hooks bring Nginx back. This makes certificate issuance resilient
  # to ACME-vhost selection problems.
  if acme_local_self_test "$self_test_file" 'DEGERIS-ACME-OK'; then
    certbot certonly --webroot -w "$ACME_ROOT" -d "$DOMAIN" \
      --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring
  else
    rm -f "$self_test_file"
    warn 'Nginx webroot ACME self-test failed; falling back to Certbot standalone HTTP-01.'
    if ! certbot certonly --standalone -d "$DOMAIN" \
      --preferred-challenges http-01 \
      --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring \
      --pre-hook 'systemctl stop nginx' \
      --post-hook 'systemctl start nginx'; then
      systemctl start nginx >/dev/null 2>&1 || true
      nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
      die 'Certificate request failed in both Nginx webroot and standalone HTTP-01 modes.'
    fi
  fi

  nginx -t
  systemctl reload nginx
  [[ -s "$cert" && -s "$key" ]] || die 'Certificate files were not created.'
}

generate_webpass(){
  WEBPASS="$(openssl rand -hex 16)"
  WEBPASS_ENABLED='1'
}

remove_certificate(){
  local domain="$1"
  [[ -n "$domain" ]] || return 0
  if cmd certbot; then
    certbot delete --cert-name "$domain" --non-interactive >/dev/null 2>&1 || true
  fi
  rm -rf -- "/etc/letsencrypt/live/$domain" "/etc/letsencrypt/archive/$domain" "/etc/letsencrypt/renewal/$domain.conf"
}


check_domain_conflict(){
  # Domain conflicts are surfaced by nginx -t; this function intentionally
  # does not block installs based on heuristic text matching.
  return 0
}

backend_vars(){
  mapfile -t _B < <(parse_backend "$BACKEND_URL") || die 'Backend URL is invalid.'
  ((${#_B[@]} == 4)) || die 'Backend URL parser returned invalid data.'
  BSCHEME="${_B[0]}"; BHOST="${_B[1]}"; BPORT="${_B[2]}"; BPATH="${_B[3]}"
  if [[ "$BSCHEME" == https && "$BPORT" == 443 ]] || [[ "$BSCHEME" == http && "$BPORT" == 80 ]]; then
    BACKEND_AUTHORITY="$BHOST"
  else
    BACKEND_AUTHORITY="$BHOST:$BPORT"
  fi
}

render_site(){
  local out="$1"
  backend_vars
  local pp='/'
  [[ "$WEBPASS_ENABLED" == '1' ]] && pp="/$WEBPASS"

  {
    printf '# Managed by %s\n' "$APP_NAME"
    printf 'server {\n    listen 127.0.0.1:%s;\n    server_name %s;\n    client_max_body_size 100m;\n    # Never leak the internal port (6060) in nginx-generated redirects.\n    absolute_redirect off;\n    port_in_redirect off;\n' "$INTERNAL_PORT" "$DOMAIN"

    if [[ "$WEBPASS_ENABLED" == '1' ]]; then
      cat <<EOF
    location = ${pp} { return 301 ${pp}/; }
    location ^~ ${pp}/ {
        proxy_http_version 1.1;
        proxy_set_header Host ${BHOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header X-Forwarded-Prefix ${pp};
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_server_name on;
        proxy_ssl_name ${BHOST};
EOF
      if [[ "$BPATH" == '/' ]]; then
        cat <<EOF
        rewrite ^${pp}/?(.*)$ /\$1 break;
        proxy_pass ${BSCHEME}://${BACKEND_AUTHORITY};
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}/ ${pp}/;
        proxy_redirect ~^https?://${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}${pp}\$2;
        proxy_redirect ~^//${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}${pp}\$2;
        proxy_redirect / ${pp}/;
        proxy_cookie_path / ${pp}/;
EOF
      else
        cat <<EOF
        rewrite ^${pp}/?(.*)$ ${BPATH}/\$1 break;
        proxy_pass ${BSCHEME}://${BACKEND_AUTHORITY};
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH}/ ${pp}/;
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH} ${pp}/;
        proxy_redirect ~^https?://${BHOST}(:${BPORT})?${BPATH}(/.*)?$ https://${DOMAIN}${pp}\$2;
        # Fallback for backend redirects that omit the internal BPATH.
        # This strips the backend port even when the application returns
        # https://HOST:PORT/... instead of https://HOST:PORT/BPATH/... .
        proxy_redirect ~^https?://${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}${pp}\$2;
        proxy_redirect ~^//${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}${pp}\$2;
        proxy_redirect ${BPATH}/ ${pp}/;
        proxy_redirect ${BPATH} ${pp}/;
        proxy_cookie_path ${BPATH}/ ${pp}/;
EOF
      fi
      cat <<EOF
        proxy_set_header Accept-Encoding "";
        sub_filter_types text/html text/css application/javascript text/javascript application/json application/xml;
        sub_filter_once off;
EOF
      if [[ "$BPATH" == '/' ]]; then
        printf '        sub_filter "%s://%s/" "https://%s%s/";\n' "$BSCHEME" "$BACKEND_AUTHORITY" "$DOMAIN" "$pp"
        printf '        sub_filter "%s://%s:%s/" "https://%s%s/";\n' "$BSCHEME" "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "%s://%s:%s" "https://%s%s";\n' "$BSCHEME" "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "http://%s:%s" "https://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "ws://%s:%s" "wss://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "wss://%s:%s" "wss://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp" "$BHOST" "$BPORT" "$DOMAIN" "$pp"
      else
        printf '        sub_filter "%s://%s%s/" "https://%s%s/";\n' "$BSCHEME" "$BACKEND_AUTHORITY" "$BPATH" "$DOMAIN" "$pp"
        printf '        sub_filter "%s://%s:%s%s/" "https://%s%s/";\n' "$BSCHEME" "$BHOST" "$BPORT" "$BPATH" "$DOMAIN" "$pp"
        # Catch absolute backend URLs even when the returned URL has no BPATH.
        printf '        sub_filter "%s://%s:%s" "https://%s%s";\n' "$BSCHEME" "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "http://%s:%s" "https://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "ws://%s:%s" "wss://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "wss://%s:%s" "wss://%s%s";\n' "$BHOST" "$BPORT" "$DOMAIN" "$pp" "$BHOST" "$BPORT" "$DOMAIN" "$pp"
        printf '        sub_filter "%s/" "%s/";\n' "$BPATH" "$pp"
        printf '        sub_filter "%s" "%s";\n' "$BPATH" "$pp"
      fi
      cat <<'EOF'
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    location / { return 404; }
}
EOF
    else
      if [[ "$BPATH" == '/' ]]; then
        cat <<EOF
    location / {
        proxy_http_version 1.1;
        proxy_set_header Host ${BHOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_server_name on;
        proxy_ssl_name ${BHOST};
        proxy_pass ${BSCHEME}://${BACKEND_AUTHORITY};
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF
      else
        cat <<EOF
    location = ${BPATH} { return 301 /; }
    location ^~ ${BPATH}/ {
        proxy_http_version 1.1;
        proxy_set_header Host ${BHOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_server_name on;
        proxy_ssl_name ${BHOST};
        proxy_pass ${BSCHEME}://${BACKEND_AUTHORITY};
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH}/ /;
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH} /;
        proxy_redirect ~^https?://${BHOST}(:${BPORT})?${BPATH}(/.*)?$ https://${DOMAIN}\$2;
        # Fallback for backend redirects that omit the internal BPATH.
        proxy_redirect ~^https?://${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}\$2;
        proxy_redirect ~^//${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}\$2;
        proxy_redirect ${BPATH}/ /;
        proxy_redirect ${BPATH} /;
        proxy_cookie_path ${BPATH}/ /;
        proxy_set_header Accept-Encoding "";
        sub_filter_types text/html text/css application/javascript text/javascript application/json application/xml;
        sub_filter_once off;
        sub_filter "${BPATH}/" "/";
        sub_filter "${BPATH}" "/";
        sub_filter "${BSCHEME}://${BACKEND_AUTHORITY}${BPATH}/" "https://${DOMAIN}/";
        sub_filter "${BSCHEME}://${BHOST}:${BPORT}${BPATH}/" "https://${DOMAIN}/";
        # Catch absolute backend URLs even when the returned URL has no BPATH.
        sub_filter "${BSCHEME}://${BHOST}:${BPORT}" "https://${DOMAIN}";
        sub_filter "http://${BHOST}:${BPORT}" "https://${DOMAIN}";
        sub_filter "ws://${BHOST}:${BPORT}" "wss://${DOMAIN}";
        sub_filter "wss://${BHOST}:${BPORT}" "wss://${DOMAIN}";
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    location / {
        proxy_http_version 1.1;
        proxy_set_header Host ${BHOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_ssl_server_name on;
        proxy_ssl_name ${BHOST};
        rewrite ^/(.*)$ ${BPATH}/\$1 break;
        proxy_pass ${BSCHEME}://${BACKEND_AUTHORITY};
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH}/ /;
        proxy_redirect ${BSCHEME}://${BACKEND_AUTHORITY}${BPATH} /;
        proxy_redirect ~^https?://${BHOST}(:${BPORT})?${BPATH}(/.*)?$ https://${DOMAIN}\$2;
        # Fallback for backend redirects that omit the internal BPATH.
        proxy_redirect ~^https?://${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}\$2;
        proxy_redirect ~^//${BHOST}(:[0-9]+)?(.*)$ https://${DOMAIN}\$2;
        proxy_redirect ${BPATH}/ /;
        proxy_redirect ${BPATH} /;
        proxy_cookie_path ${BPATH}/ /;
        proxy_set_header Accept-Encoding "";
        sub_filter_types text/html text/css application/javascript text/javascript application/json application/xml;
        sub_filter_once off;
        sub_filter "${BPATH}/" "/";
        sub_filter "${BPATH}" "/";
        sub_filter "${BSCHEME}://${BACKEND_AUTHORITY}${BPATH}/" "https://${DOMAIN}/";
        sub_filter "${BSCHEME}://${BHOST}:${BPORT}${BPATH}/" "https://${DOMAIN}/";
        # Catch absolute backend URLs even when the returned URL has no BPATH.
        sub_filter "${BSCHEME}://${BHOST}:${BPORT}" "https://${DOMAIN}";
        sub_filter "http://${BHOST}:${BPORT}" "https://${DOMAIN}";
        sub_filter "ws://${BHOST}:${BPORT}" "wss://${DOMAIN}";
        sub_filter "wss://${BHOST}:${BPORT}" "wss://${DOMAIN}";
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF
      fi
    fi

    cat <<EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name ${DOMAIN};
    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
        default_type text/plain;
        try_files \$uri =404;
    }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen ${HTTPS_PORT} ssl;
    listen [::]:${HTTPS_PORT} ssl;
    server_name ${DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    client_max_body_size 100m;
EOF
    if [[ "$WEBPASS_ENABLED" == '1' ]]; then
      cat <<EOF
    location = ${pp} { return 301 ${pp}/; }
    location ^~ ${pp}/ {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
        # Safety net: strip the internal port from any redirect that still contains it.
        proxy_redirect ~^https?://([^/:]+):${INTERNAL_PORT}(/.*)?\$ https://\$1\$2;
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    location / { return 404; }
}
EOF
    else
      cat <<EOF
    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header Forwarded "proto=https;host=\$host;port=443";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:${INTERNAL_PORT};
        # Safety net: strip the internal port from any redirect that still contains it.
        proxy_redirect ~^https?://([^/:]+):${INTERNAL_PORT}(/.*)?\$ https://\$1\$2;
        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF
    fi
  } > "$out"
}

write_final_nginx(){
  local tmp="$NGINX_SITE.tmp.$$"
  render_site "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$NGINX_SITE"
  ln -sfn "$NGINX_SITE" "$NGINX_LINK"
}

install_manager(){
  mkdir -p /usr/local/bin /usr/local/sbin
  cp -f "$0" "$MANAGER_BIN"
  chmod 755 "$MANAGER_BIN"
  cat > "$DSADMIN_BIN" <<EOF
#!/usr/bin/env bash
exec "$MANAGER_BIN" --menu "\$@"
EOF
  chmod 755 "$DSADMIN_BIN"
  cat > "$DSADMIN_SBIN" <<EOF
#!/usr/bin/env bash
exec "$MANAGER_BIN" --menu "\$@"
EOF
  chmod 755 "$DSADMIN_SBIN"
}

install_apply(){
  write_final_nginx
  nginx -t
  systemctl reload nginx
}

public_smoke_test(){
  local public html headers code
  backend_vars
  public="https://${DOMAIN}/"
  [[ "$WEBPASS_ENABLED" == '1' ]] && public="https://${DOMAIN}/${WEBPASS}/"
  html="$(mktemp /tmp/degeris-proxy-html.XXXXXX)"
  headers="$(mktemp /tmp/degeris-proxy-headers.XXXXXX)"
  local curl_err="$(mktemp /tmp/degeris-proxy-curlerr.XXXXXX)"
  code="$(curl -4 -ksSL --max-time 20 -D "$headers" -o "$html" -w '%{http_code}' "$public" 2>"$curl_err" || true)"

  case "$code" in
    2*|3*|401|403) ;;
    *)
      local curl_detail
      curl_detail="$(tr '\n' ' ' < "$curl_err" | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c1-300)"
      rm -f "$html" "$headers" "$curl_err"
      warn "Public proxy smoke test failed: HTTP ${code:-connection-error}."
      [[ -n "$curl_detail" ]] && warn "curl detail: $curl_detail"
      return 1 ;;
  esac

  if grep -Eqi "https?://${BHOST}(:${BPORT})?|wss?://${BHOST}(:${BPORT})?" "$headers" "$html"; then
    rm -f "$html" "$headers" "$curl_err"
    warn "Public proxy smoke test found the backend hostname/port in the response. Backend: ${BHOST}:${BPORT}"
    return 1
  fi

  if [[ "$WEBPASS_ENABLED" == '1' && "$BPATH" != '/' ]]; then
    if grep -qF "$BPATH" "$html"; then
      rm -f "$html" "$headers" "$curl_err"
      warn 'Public proxy smoke test found an unreplaced backend Base Path in HTML.'
      return 1
    fi
    if ! grep -qF "/${WEBPASS}/" "$html"; then
      rm -f "$html" "$headers" "$curl_err"
      warn 'Public proxy smoke test found no WebPass path in returned HTML.'
      return 1
    fi
  fi
  rm -f "$html" "$headers" "$curl_err"
  ok "Public proxy smoke test passed: HTTP $code"
  return 0
}

initial_install(){
  need_root
  for c in nginx curl openssl python3 ss tar flock; do cmd "$c" || die "Required command not found: $c"; done
  # Remove only this project's stale/dangling Nginx links before touching the Nginx service.
  # This is intentionally before ensure_nginx because systemctl start can trigger an Nginx config test.
  remove_own_stale_links
  # Migrate the old private ACME webroot used by earlier versions.
  if [[ -d /etc/degeris-proxy/acme && "/etc/degeris-proxy/acme" != "$ACME_ROOT" ]]; then
    mkdir -p "$ACME_ROOT"
    cp -a /etc/degeris-proxy/acme/. "$ACME_ROOT/" 2>/dev/null || true
  fi
  mkdir -p "$ACME_ROOT/.well-known/acme-challenge"
  chown -R www-data:www-data "$ACME_ROOT"
  chmod 755 "$ACME_ROOT" "$ACME_ROOT/.well-known" "$ACME_ROOT/.well-known/acme-challenge"
  clean_own_dangling_links
  check_ports
  snapshot
  ensure_own_link
  ensure_hash_setting
  ensure_nginx
  nginx -t

  local input backend_input
  read -r -p 'Proxy Domain: ' input
  DOMAIN="$(normalize_domain "$input" 2>/dev/null || true)"
  [[ -n "$DOMAIN" ]] || die 'Invalid Proxy Domain.'

  read -r -p 'Backend Panel URL: ' backend_input
  parse_backend "$backend_input" >/dev/null || die 'Invalid Backend Panel URL.'
  BACKEND_URL="${backend_input%/}"
  check_domain_conflict "$DOMAIN"

  mkdir -p "$STATE_DIR" "$BACKUP_DIR" "$ACME_ROOT/.well-known/acme-challenge"
  chown -R www-data:www-data "$ACME_ROOT"
  chmod 755 "$ACME_ROOT" "$ACME_ROOT/.well-known" "$ACME_ROOT/.well-known/acme-challenge"
  local b
  b="$(backup_nginx)"
  info "Nginx backup: $b"
  backup_managed
  trap 'rc=$?; if [[ $rc -ne 0 ]]; then restore_snapshot >/dev/null 2>&1 || true; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; fi; exit $rc' ERR
  nginx -t
  check_dns

  generate_webpass
  save_state
  obtain_certificate
  install_apply
  install_manager
  if ! public_smoke_test; then
    warn 'Public smoke test failed; restoring the configuration from the pre-install snapshot.'
    restore_snapshot >/dev/null 2>&1 || true
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
    trap - ERR
    die 'Installation was rolled back because the public proxy smoke test failed.'
  fi
  trap - ERR

  printf '\n=========================================\n'
  printf '  𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy Ready\n'
  printf '=========================================\n'
  printf 'Proxy Domain: https://%s/\n' "$DOMAIN"
  printf 'WebPass URL  : https://%s/%s/\n' "$DOMAIN" "$WEBPASS"
  printf 'Backend URL  : %s\n' "$BACKEND_URL"
  printf 'Internal     : 127.0.0.1:%s\n' "$INTERNAL_PORT"
  printf 'SSL          : OK\n'
  printf 'Management   : dsadmin\n'
  printf '=========================================\n'
}

change_backend(){
  load_state || die 'Proxy is not configured.'
  local old_site old_state input
  old_site="$(cat "$NGINX_SITE")"; old_state="$(cat "$STATE_FILE")"
  read -r -p 'New Backend Panel URL: ' input
  parse_backend "$input" >/dev/null || die 'Invalid Backend Panel URL.'
  BACKEND_URL="${input%/}"
  if ! write_final_nginx || ! nginx -t; then
    restore_pair "$old_site" "$old_state"
    die 'New backend rejected; previous configuration restored.'
  fi
  if ! systemctl reload nginx; then restore_pair "$old_site" "$old_state"; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; die 'Nginx reload failed; previous configuration restored.'; fi
  save_state
  ok 'Backend URL changed.'
}

prompt_webpass(){
  # Sets NEW_WEBPASS. Returns 1 if the user cancelled.
  local input
  NEW_WEBPASS=''
  while true; do
    read -r -p 'New WebPass (4-64 chars: A-Z a-z 0-9 - _ | Enter = random | q = cancel): ' input
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    # Accept a pasted URL such as https://domain/mypass/ as well.
    input="${input#https://}"; input="${input#http://}"; input="${input#"${DOMAIN}"}"
    while [[ "$input" == /* ]]; do input="${input#/}"; done
    while [[ "$input" == */ ]]; do input="${input%/}"; done
    case "$input" in
      '') NEW_WEBPASS="$(openssl rand -hex 16)"; return 0 ;;
      q|Q) return 1 ;;
    esac
    if valid_webpass "$input"; then NEW_WEBPASS="$input"; return 0; fi
    warn 'Invalid WebPass. Use 4-64 characters: letters, numbers, - and _ only (no spaces, dots or slashes).'
  done
}

change_webpass(){
  load_state || die 'Proxy is not configured.'
  local old_site old_state
  old_site="$(cat "$NGINX_SITE")"; old_state="$(cat "$STATE_FILE")"
  if [[ "$WEBPASS_ENABLED" == '1' ]]; then echo "Current WebPass: ${WEBPASS}"; else echo 'Current WebPass: disabled'; fi
  prompt_webpass || { echo 'Cancelled.'; return 0; }
  if [[ "$WEBPASS_ENABLED" == '1' && "$NEW_WEBPASS" == "$WEBPASS" ]]; then
    ok 'WebPass is unchanged.'
    return 0
  fi
  WEBPASS="$NEW_WEBPASS"; WEBPASS_ENABLED='1'
  if ! write_final_nginx || ! nginx -t; then
    restore_pair "$old_site" "$old_state"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
    die 'New WebPass rejected; previous configuration restored.'
  fi
  if ! systemctl reload nginx; then restore_pair "$old_site" "$old_state"; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; die 'Nginx reload failed; previous configuration restored.'; fi
  save_state
  ok "New WebPass URL: https://${DOMAIN}/${WEBPASS}/"
}

remove_webpass(){
  load_state || die 'Proxy is not configured.'
  local old_site old_state
  old_site="$(cat "$NGINX_SITE")"; old_state="$(cat "$STATE_FILE")"
  WEBPASS_ENABLED='0'; WEBPASS=''
  if ! write_final_nginx || ! nginx -t; then
    restore_pair "$old_site" "$old_state"
    die 'Remove WebPass failed; previous configuration restored.'
  fi
  if ! systemctl reload nginx; then restore_pair "$old_site" "$old_state"; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; die 'Nginx reload failed; previous configuration restored.'; fi
  save_state
  ok "WebPass removed. Public URL: https://${DOMAIN}/"
}

enable_webpass(){
  load_state || die 'Proxy is not configured.'
  local old_site old_state
  old_site="$(cat "$NGINX_SITE")"; old_state="$(cat "$STATE_FILE")"
  generate_webpass
  if ! write_final_nginx || ! nginx -t; then
    restore_pair "$old_site" "$old_state"
    die 'Enable WebPass failed; previous configuration restored.'
  fi
  if ! systemctl reload nginx; then restore_pair "$old_site" "$old_state"; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; die 'Nginx reload failed; previous configuration restored.'; fi
  save_state
  ok "WebPass enabled: https://${DOMAIN}/${WEBPASS}/"
}

change_domain(){
  load_state || die 'Proxy is not configured.'
  local input newdomain olddomain old_site old_state
  read -r -p 'New Proxy Domain: ' input
  newdomain="$(normalize_domain "$input" 2>/dev/null || true)"
  [[ -n "$newdomain" ]] || die 'Invalid Proxy Domain.'
  [[ "$newdomain" != "$DOMAIN" ]] || { ok 'Domain is unchanged.'; return; }
  check_domain_conflict "$newdomain"
  local dns_prev="$DOMAIN"; DOMAIN="$newdomain"; check_dns || true; DOMAIN="$dns_prev"

  olddomain="$DOMAIN"
  old_site="$(cat "$NGINX_SITE")"; old_state="$(cat "$STATE_FILE")"
  local cert="/etc/letsencrypt/live/${newdomain}/fullchain.pem" key="/etc/letsencrypt/live/${newdomain}/privkey.pem"

  if [[ ! -s "$cert" || ! -s "$key" ]]; then
    ensure_certbot
    local temp_site='/etc/nginx/sites-available/degeris-proxy-acme.conf'
    local temp_link='/etc/nginx/sites-enabled/degeris-proxy-acme.conf'
    mkdir -p "$ACME_ROOT/.well-known/acme-challenge"
    chown -R www-data:www-data "$ACME_ROOT"
    chmod 755 "$ACME_ROOT" "$ACME_ROOT/.well-known" "$ACME_ROOT/.well-known/acme-challenge"
    cat > "$temp_site" <<EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name ${newdomain};
    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
        default_type text/plain;
        try_files \$uri =404;
    }
    location / { return 404; }
}
EOF
    ln -sfn "$temp_site" "$temp_link"
    if ! nginx -t; then
      rm -f "$temp_link" "$temp_site"
      die "Temporary certificate configuration failed; ${olddomain} remains active."
    fi
    systemctl reload nginx
    local old_domain_for_test="$DOMAIN"
    DOMAIN="$newdomain"
    if ! acme_local_self_test "$ACME_ROOT/.well-known/acme-challenge/degeris-self-test" 'DEGERIS-ACME-OK'; then
      warn "Nginx webroot ACME self-test failed for ${newdomain}; standalone HTTP-01 fallback will be attempted."
    fi
    DOMAIN="$old_domain_for_test"
    if ! certbot certonly --webroot -w "$ACME_ROOT" -d "$newdomain" --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring; then
      warn "Webroot certificate request failed for ${newdomain}; retrying with standalone HTTP-01."
      rm -f "$temp_link" "$temp_site" "$ACME_ROOT/.well-known/acme-challenge/degeris-self-test"
      nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
      if ! certbot certonly --standalone -d "$newdomain" \
        --preferred-challenges http-01 \
        --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring \
        --pre-hook 'systemctl stop nginx' \
        --post-hook 'systemctl start nginx'; then
        systemctl start nginx >/dev/null 2>&1 || true
        die "Certificate request failed for ${newdomain} in both webroot and standalone HTTP-01 modes; ${olddomain} remains active."
      fi
    fi
    rm -f "$temp_link" "$temp_site" "$ACME_ROOT/.well-known/acme-challenge/degeris-self-test"
  fi

  DOMAIN="$newdomain"
  if ! write_final_nginx || ! nginx -t; then
    restore_pair "$old_site" "$old_state"
    nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
    die "New domain configuration failed; ${olddomain} restored."
  fi
  if ! systemctl reload nginx; then restore_pair "$old_site" "$old_state"; nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true; die "Nginx reload failed; ${olddomain} restored."; fi
  save_state
  remove_certificate "$olddomain"
  ok "Proxy domain changed to ${DOMAIN}."
  public_smoke_test || warn 'Domain changed, but the public smoke test did not pass. Check DNS, then run Test from the menu.'
}

test_all(){
  load_state || die 'Proxy is not configured.'
  backend_vars
  echo '--- 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy Test ---'
  nginx -t && ok 'Nginx syntax' || warn 'Nginx syntax failed'
  if ss -ltnp 2>/dev/null | grep -Eq "127\.0\.0\.1:${INTERNAL_PORT}([^0-9]|$)"; then ok "Internal proxy listening on 127.0.0.1:${INTERNAL_PORT}"; else warn "Internal proxy is not listening on 127.0.0.1:${INTERNAL_PORT}"; fi
  if [[ -s "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" && -s "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]]; then ok 'SSL certificate files'; else warn 'SSL certificate files missing'; fi
  local bcode pcode public
  bcode="$(curl -kLsS --max-time 20 -o /dev/null -w '%{http_code}' "$BACKEND_URL/" || true)"
  case "$bcode" in 2*|3*|401|403) ok "Backend responded: HTTP $bcode";; *) warn "Backend response: HTTP ${bcode:-failed}";; esac
  if [[ "$WEBPASS_ENABLED" == '1' ]]; then public="https://${DOMAIN}/${WEBPASS}/"; else public="https://${DOMAIN}/"; fi
  pcode="$(curl -kLsS --max-time 20 -o /dev/null -w '%{http_code}' "$public" || true)"
  case "$pcode" in 2*|3*|401|403) ok "Public proxy responded: HTTP $pcode";; *) warn "Public proxy response: HTTP ${pcode:-failed}";; esac
  echo "Public URL : ${public}"
  echo "Backend URL: ${BACKEND_URL}"
}

reload_nginx(){ nginx -t && systemctl reload nginx && ok 'Nginx reloaded.'; }

show_status(){
  load_state || die 'Proxy is not configured.'
  echo '========================================='
  echo '  𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy Status'
  echo '========================================='
  echo "Proxy Domain : https://${DOMAIN}/"
  if [[ "$WEBPASS_ENABLED" == '1' ]]; then echo 'WebPass      : enabled'; echo "Public URL   : https://${DOMAIN}/${WEBPASS}/"; else echo 'WebPass      : disabled'; echo "Public URL   : https://${DOMAIN}/"; fi
  echo "Backend URL  : ${BACKEND_URL}"
  echo "Internal     : 127.0.0.1:${INTERNAL_PORT}"
  echo "Nginx        : $(systemctl is-active nginx 2>/dev/null || true)"
  if [[ -s "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then printf 'SSL Expiry   : '; openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" | sed 's/^notAfter=//'; else echo 'SSL Expiry   : unavailable'; fi
  echo '========================================='
}

remove_all(){
  local confirm olddomain hash_managed
  if load_state; then
    olddomain="$DOMAIN"
  else
    # Allow uninstall even if the state file was damaged/removed.
    olddomain="$(awk '$1=="server_name"{gsub(";","",$2); print $2; exit}' "$NGINX_SITE" 2>/dev/null || true)"
    valid_domain "$olddomain" || olddomain=''
  fi

  read -r -p 'Remove 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 proxy completely? [y/N]: ' confirm
  case "${confirm,,}" in y|yes) ;; *) echo 'Cancelled.'; return 0;; esac

  backup_nginx >/dev/null || true
  hash_managed="${HASH_MANAGED:-0}"

  # Remove any exact nginx include created/used for this project's canonical site,
  # then remove the canonical site itself. This avoids leaving an empty SSL vhost.
  remove_own_explicit_includes
  rm -f "$NGINX_LINK" "$NGINX_SITE"

  # Remove all manager entry points and project-only nginx leftovers.
  rm -f "$DSADMIN_BIN" "$DSADMIN_SBIN" "$MANAGER_BIN"
  [[ "$hash_managed" == 1 ]] && rm -f "$NGINX_HASH"
  rm -f \
    /etc/nginx/sites-enabled/degeris-proxy-public.conf \
    /etc/nginx/sites-available/degeris-proxy.conf.precert \
    /etc/nginx/sites-enabled/degeris-proxy-acme.conf \
    /etc/nginx/sites-available/degeris-proxy-acme.conf

  # Remove ACME challenge files/webroot and temporary files created by this script.
  rm -rf "$ACME_ROOT"
  rm -f /tmp/degeris-acme-test.* /tmp/degeris-acme-change.* /tmp/degeris-proxy-html.*

  # Remove only this domain's Let's Encrypt/Certbot certificate material.
  # Other domains/certificates on the server are left untouched.
  if [[ -n "$olddomain" ]]; then
    remove_certificate "$olddomain"
  fi

  if nginx -t; then
    systemctl reload nginx
    ok 'Nginx configuration cleaned.'
  else
    warn 'Nginx test failed after removing the managed proxy. Nginx was not reloaded.'
  fi

  rm -rf "$STATE_DIR"
  rm -f "$LOCK_FILE"

  ok '𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 proxy removed completely.'
  exit 0
}

menu(){
  need_root
  while true; do
    clear 2>/dev/null || true
    echo '========================================='
    echo '  𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy Manager'
    echo '========================================='
    if load_state; then
      if [[ "$WEBPASS_ENABLED" == '1' ]]; then echo "Public: https://${DOMAIN}/${WEBPASS}/"; else echo "Public: https://${DOMAIN}/"; fi
      echo "Backend: ${BACKEND_URL}"
    else
      echo 'Status: Not configured'
    fi
    echo '-----------------------------------------'
    echo '1) Change Backend Link / URL'
    echo '2) Change WebPass Proxy'
    echo '3) Change Proxy Domain'
    echo '4) Remove WebPass'
    echo '5) Enable WebPass'
    echo '6) Remove 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy'
    echo '7) Test'
    echo '8) Reload'
    echo '9) Status'
    echo '0) Exit'
    echo '========================================='
    read -r -p 'Select: ' choice
    case "$choice" in
      1) change_backend; read -r -p 'Press Enter...' _;;
      2) change_webpass; read -r -p 'Press Enter...' _;;
      3) change_domain; read -r -p 'Press Enter...' _;;
      4) remove_webpass; read -r -p 'Press Enter...' _;;
      5) enable_webpass; read -r -p 'Press Enter...' _;;
      6) remove_all; read -r -p 'Press Enter...' _;;
      7) test_all; read -r -p 'Press Enter...' _;;
      8) reload_nginx; read -r -p 'Press Enter...' _;;
      9) show_status; read -r -p 'Press Enter...' _;;
      0) exit 0;;
      *) echo 'Invalid option.'; sleep 1;;
    esac
  done
}

self_test(){
  local tmp rootcfg certdir site
  tmp="$(mktemp -d /tmp/degeris-proxy-selftest.XXXXXX)"
  trap 'rm -rf "$tmp"' RETURN
  certdir="$tmp/certs"
  mkdir -p "$certdir" "$tmp/acme/.well-known/acme-challenge"
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj '/CN=admins.example.com' -keyout "$certdir/key.pem" -out "$certdir/cert.pem" >/dev/null 2>&1

  normalize_domain 'https://admins.example.com' | grep -qx 'admins.example.com'
  normalize_domain 'bad domain' >/dev/null && return 1 || true
  normalize_domain 'admins.example.com/path' >/dev/null && return 1 || true
  valid_webpass 'my-Pass_123'
  valid_webpass '0123456789abcdef0123456789abcdef'
  valid_webpass 'abc' >/dev/null && return 1 || true
  valid_webpass 'bad/pass' >/dev/null && return 1 || true
  valid_webpass 'bad pass' >/dev/null && return 1 || true
  valid_webpass 'bad.pass' >/dev/null && return 1 || true
  local p
  mapfile -t p < <(parse_backend 'https://127.0.0.1:18000/SECRET/')
  [[ "${p[0]}" == 'https' && "${p[1]}" == '127.0.0.1' && "${p[2]}" == '18000' && "${p[3]}" == '/SECRET' ]]
  parse_backend 'https://127.0.0.1:18000/SECRET?x=1' >/dev/null && return 1 || true
  parse_backend 'javascript:alert(1)' >/dev/null && return 1 || true

  DOMAIN='admins.example.com'; BACKEND_URL='https://127.0.0.1:18000/SECRET'; WEBPASS_ENABLED='1'; WEBPASS='0123456789abcdef0123456789abcdef'; HASH_MANAGED='0'; INTERNAL_PORT=16060; HTTP_PORT=16080; HTTPS_PORT=16443; ACME_ROOT="$tmp/acme"
  site="$tmp/webpass-base.conf"; render_site "$site"
  grep -q 'sub_filter_types text/html text/css application/javascript text/javascript application/json application/xml;' "$site"
  grep -q 'proxy_set_header Accept-Encoding "";' "$site"
  grep -q 'proxy_set_header X-Forwarded-Server \$host;' "$site"
  grep -q 'proxy_set_header Host 127.0.0.1;' "$site"
  grep -q 'rewrite \^/0123456789abcdef0123456789abcdef/?(.*)\$ /SECRET/\$1 break;' "$site"
  grep -q 'proxy_redirect https://127.0.0.1:18000/SECRET/ /0123456789abcdef0123456789abcdef/;' "$site" && grep -q 'proxy_redirect ~^https?://127.0.0.1(:18000)?/SECRET' "$site"
  grep -q 'location / { return 404; }' "$site"

  WEBPASS_ENABLED='0'; WEBPASS=''; site="$tmp/root-base.conf"; render_site "$site"
  grep -q 'location \^~ /SECRET/' "$site"
  grep -q 'rewrite \^/(.*)\$ /SECRET/\$1 break;' "$site"
  grep -q 'sub_filter "/SECRET/" "/";' "$site"

  BACKEND_URL='https://127.0.0.1:18000/'; WEBPASS_ENABLED='1'; WEBPASS='fedcba9876543210fedcba9876543210'; site="$tmp/webpass-root.conf"; render_site "$site"
  grep -q 'rewrite \^/fedcba9876543210fedcba9876543210/?(.*)\$ /\$1 break;' "$site"
  grep -q 'proxy_redirect https://127.0.0.1:18000/ /fedcba9876543210fedcba9876543210/;' "$site"

  WEBPASS_ENABLED='0'; WEBPASS=''; site="$tmp/root-root.conf"; render_site "$site"
  grep -q 'proxy_pass https://127.0.0.1:18000;' "$site"

  ! grep -nE '\beval\b' "$0" | grep -v 'grep -nE' | grep -q . || { echo '[FAIL] eval found.' >&2; return 1; }
  ! grep -qE 'shopdegeris\.ir|81\.12\.33\.233|85\.133\.221\.53' "$0" || { echo '[FAIL] private test values found.' >&2; return 1; }
  for marker in 'Change Backend Link / URL' 'Change WebPass Proxy' 'Change Proxy Domain' 'Remove WebPass' 'Enable WebPass' 'Remove 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 Proxy' 'dsadmin'; do grep -qF "$marker" "$0" || { echo "[FAIL] missing $marker" >&2; return 1; }; done
  grep -qF 'Remove only this project' "$0" || { echo '[FAIL] preflight stale-link cleanup missing.' >&2; return 1; }
  grep -qF 'NEVER remove the canonical managed link' "$0" || { echo '[FAIL] canonical Nginx link protection missing.' >&2; return 1; }
  grep -qF 'ensure_own_link' "$0" || { echo '[FAIL] canonical link bootstrap missing.' >&2; return 1; }
  grep -qF '^ensure_nginx(){' "$0" || { echo '[FAIL] ensure_nginx function missing.' >&2; return 1; }
  grep -qF '^acme_local_self_test(){' "$0" || { echo '[FAIL] ACME local self-test helper missing.' >&2; return 1; }
  grep -qF '^obtain_certificate(){' "$0" || { echo '[FAIL] obtain_certificate function missing.' >&2; return 1; }
  grep -qF -- '-H "Host: ${DOMAIN}"' "$0" || { echo '[FAIL] ACME Host-header local test missing.' >&2; return 1; }
  grep -qF 'cmp -s "$token_file" "$body_file"' "$0" || { echo '[FAIL] ACME body integrity check missing.' >&2; return 1; }
  grep -qF 'chmod 644 "$token_file"' "$0" || { echo '[FAIL] ACME token readability fix missing.' >&2; return 1; }
  grep -qF 'chown www-data:www-data "$token_file"' "$0" || { echo '[FAIL] ACME token ownership fix missing.' >&2; return 1; }
  grep -qF -- '-H "Host: ${DOMAIN}"' "$0" || { echo '[FAIL] ACME Host-header local test missing.' >&2; return 1; }
  grep -qF '^generate_webpass(){' "$0" || { echo '[FAIL] generate_webpass function missing.' >&2; return 1; }
  grep -q '^prompt_webpass(){' "$0" || { echo '[FAIL] custom WebPass prompt missing.' >&2; return 1; }
  grep -qF 'public_smoke_test' "$0" || { echo '[FAIL] post-install public smoke test missing.' >&2; return 1; }
  for fn in change_backend change_webpass change_domain remove_webpass enable_webpass remove_all test_all reload_nginx show_status; do grep -q "^${fn}(){" "$0" || { echo "[FAIL] missing function ${fn}" >&2; return 1; }; done
  grep -qF 'nginx_explicitly_includes_own_site' "$0" || { echo '[FAIL] explicit-include uninstall guard missing.' >&2; return 1; }
  grep -qF 'Remove 𝐃𝐞𝐠𝐞𝐫𝐢𝐬𝐕𝐏𝐍 proxy completely? [y/N]' "$0" || { echo '[FAIL] Y/N uninstall confirmation missing.' >&2; return 1; }
  grep -qF "ACME_ROOT='/var/www/degeris-acme'" "$0" || { echo '[FAIL] safe ACME webroot missing.' >&2; return 1; }
  grep -qF 'chown -R www-data:www-data "$ACME_ROOT"' "$0" || { echo '[FAIL] ACME permissions repair missing.' >&2; return 1; }
  grep -qF 'exit 0' "$0" || { echo '[FAIL] uninstall exit guard missing.' >&2; return 1; }
  grep -qF 'remove_certificate' "$0" || { echo '[FAIL] certificate cleanup helper missing.' >&2; return 1; }
  local init_block cleanup_line ensure_line link_line
  init_block="$(sed -n '/^initial_install(){/,/^}/p' "$0")"
  cleanup_line="$(grep -n 'remove_own_stale_links' <<<"$init_block" | head -1 | cut -d: -f1)"
  ensure_line="$(grep -n '^  ensure_nginx$' <<<"$init_block" | head -1 | cut -d: -f1)"
  link_line="$(grep -n '^  ensure_own_link$' <<<"$init_block" | head -1 | cut -d: -f1)"
  [[ -n "$cleanup_line" && -n "$link_line" && -n "$ensure_line" ]] || { echo '[FAIL] install ordering audit failed.' >&2; return 1; }
  (( cleanup_line < link_line && link_line < ensure_line )) || { echo '[FAIL] cleanup -> canonical link -> ensure_nginx ordering failed.' >&2; return 1; }

  rootcfg="$tmp/nginx.conf"
  cat > "$rootcfg" <<EOF
worker_processes 1;
pid $tmp/nginx.pid;
error_log $tmp/error.log notice;
events { worker_connections 64; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    server_names_hash_bucket_size 64;
    include $tmp/*.nginx-site.conf;
}
EOF
  for mode in webpass-base root-base webpass-root root-root; do
    cp "$tmp/$mode.conf" "$tmp/$mode.nginx-site.conf"
    sed -i \
      -e "s#/etc/letsencrypt/live/${DOMAIN}/fullchain.pem#$certdir/cert.pem#g" \
      -e "s#/etc/letsencrypt/live/${DOMAIN}/privkey.pem#$certdir/key.pem#g" \
      -e 's/listen 127.0.0.1:16060;/listen 127.0.0.1:16060;/g' \
      -e 's/listen 16080;/listen 16080;/g' \
      -e 's/listen \[::\]:16080;/listen [::]:16080;/g' \
      -e 's/listen 16443 ssl;/listen 16443 ssl;/g' \
      -e 's/listen \[::\]:16443 ssl;/listen [::]:16443 ssl;/g' \
      -e "s#root ${ACME_ROOT};#root $tmp/acme;#g" \
      "$tmp/$mode.nginx-site.conf"
    nginx -t -c "$rootcfg" >/dev/null 2>&1 || { echo "[FAIL] nginx syntax for $mode" >&2; nginx -t -c "$rootcfg" 2>&1 || true; return 1; }
    rm -f "$tmp/$mode.nginx-site.conf"
  done
  grep -qF -- 'certbot certonly --webroot -w "$ACME_ROOT" -d "$DOMAIN"' "$0" || { echo '[FAIL] certbot webroot ACME flow missing' >&2; return 1; }
  grep -qF -- 'certbot certonly --standalone -d "$DOMAIN"' "$0" || { echo '[FAIL] certbot standalone ACME fallback missing' >&2; return 1; }
  grep -qF 'proxy_set_header Host ${BHOST};' "$0" || { echo '[FAIL] backend Host header must omit the backend port.' >&2; return 1; }
  grep -qF 'proxy_set_header X-Forwarded-Port 443;' "$0" || { echo '[FAIL] forwarded HTTPS port header missing.' >&2; return 1; }
  grep -qF 'proxy_set_header Forwarded "proto=https;host=\$host;port=443";' "$0" || { echo '[FAIL] RFC Forwarded HTTPS authority header missing.' >&2; return 1; }
  grep -qF 'proxy_redirect ~^https?://${BHOST}(:[0-9]+)?' "$0" || { echo '[FAIL] strict backend-port stripping redirect guard missing.' >&2; return 1; }
  grep -qF 'proxy_redirect ~^https?://${BHOST}(:${BPORT})?' "$0" || { echo '[FAIL] scheme-independent backend redirect guard missing.' >&2; return 1; }
  grep -qF 'remove_own_explicit_includes' "$0" || { echo '[FAIL] explicit nginx include cleanup missing.' >&2; return 1; }
  grep -qF 'proxy_redirect ~^https?://${BHOST}(:${BPORT})?' "$0" || { echo '[FAIL] port-stripping proxy_redirect guard missing.' >&2; return 1; }
  grep -qF 'sub_filter "${BSCHEME}://${BHOST}:${BPORT}" "https://${DOMAIN}";' "$0"
  grep -qF 'proxy_redirect ~^//${BHOST}(:${BPORT})?' "$0" || { echo '[FAIL] protocol-relative backend redirect guard missing.' >&2; return 1; } || { echo '[FAIL] backend authority body-port stripping guard missing.' >&2; return 1; }
  bash -n "$0"
  echo '[OK] Static self-test passed. No system changes were made.'
}

if [[ "${1:-}" == '--self-test' ]]; then self_test; exit $?; fi
if [[ "${1:-}" == '--menu' ]]; then menu; exit 0; fi

need_root
exec 9>"$LOCK_FILE"
flock -n 9 || die 'Another DegerisVPN operation is already running.'
initial_install
