#!/usr/bin/env bash
# Checks every URL in sites.txt and emails when one goes down or comes back.
# State (the set of sites that were down last run) lives in state/down.txt,
# carried between runs by the actions cache.
set -euo pipefail

mkdir -p state
touch state/down.txt
: > state/now-down.txt

check() {
  # -w prints 000 itself when there is no response; only the exit code is ignored
  curl -sS -L -o /dev/null -w '%{http_code}' --max-time 20 "$1" 2>/dev/null || true
}

while read -r url; do
  [ -z "$url" ] && continue
  code=$(check "$url")
  if [ "$code" != 200 ]; then
    sleep 20 # one retry so a single slow response doesn't page anyone
    code=$(check "$url")
  fi
  echo "$url $code"
  [ "$code" = 200 ] || echo "$url $code" >> state/now-down.txt
done < sites.txt

went_down=$(grep -vFf <(cut -d' ' -f1 state/down.txt) state/now-down.txt || true)
came_back=$(grep -vFf <(cut -d' ' -f1 state/now-down.txt) state/down.txt | cut -d' ' -f1 || true)
mv state/now-down.txt state/down.txt

send() { # subject, text
  jq -n --arg s "$1" --arg t "$2" --arg to "$ALERT_TO" --arg from "$ALERT_FROM" \
    '{sender:{name:"Uptime monitor",email:$from},to:[{email:$to}],subject:$s,textContent:$t}' |
    curl -sS --fail -X POST https://api.brevo.com/v3/smtp/email \
      -H "api-key: $BREVO_API_KEY" -H 'content-type: application/json' -d @- > /dev/null
}

if [ -n "$went_down" ]; then
  send "DOWN: $(echo "$went_down" | cut -d' ' -f1 | sed 's#https://##' | paste -sd, -)" \
    "These sites failed twice in a row (URL, HTTP status; 000 = no response):

$went_down

Checked from GitHub Actions at $(date -u '+%Y-%m-%d %H:%M UTC'). You'll get another email when they recover."
fi
if [ -n "$came_back" ]; then
  send "RECOVERED: $(echo "$came_back" | sed 's#https://##' | paste -sd, -)" \
    "These sites answer 200 again:

$came_back

Checked at $(date -u '+%Y-%m-%d %H:%M UTC')."
fi
