#!/usr/bin/env bash
# Creates or completes .env with random secrets, starts everything and waits until both services are ready.
set -euo pipefail
cd "$(dirname "$0")"

touch .env
if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then echo >> .env; fi

secret() { openssl rand -hex 32; }

# Adds a variable only if .env does not define it yet: existing values are never touched
ensure_var() {
  if ! grep -Eq "^$1=.+" .env; then
    echo "$1=$2" >> .env
    echo "  added $1 to .env"
  fi
}

ensure_var POSTGRES_DB triage_db
ensure_var POSTGRES_USER triage_user
ensure_var POSTGRES_PASSWORD "$(secret)"
ensure_var TRIAGE_SECURITY_APIKEYS "$(secret)"
ensure_var ASSISTANT_SECURITY_APIKEYS "$(secret)"
if [ -n "${GEMINI_API_KEY:-}" ]; then ensure_var GEMINI_API_KEY "$GEMINI_API_KEY"; fi

docker compose up --build -d

echo "Waiting for the services..."
for attempt in $(seq 1 60); do
  if curl -fs http://localhost:8081/actuator/health/readiness > /dev/null \
     && curl -fs http://localhost:8082/actuator/health/readiness > /dev/null; then
    echo "Ready: triage http://localhost:8081  |  assistant http://localhost:8082"
    echo "The API keys are in .env (TRIAGE_SECURITY_APIKEYS / ASSISTANT_SECURITY_APIKEYS), sent in the X-API-Key header."
    exit 0
  fi
  sleep 5
done
echo "The services did not become ready in time. Check: docker compose ps  and  docker compose logs"
exit 1