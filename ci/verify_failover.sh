#!/usr/bin/env bash
set -euo pipefail

BASE=http://localhost:8080
BLUE_DIRECT=http://localhost:8081
GREEN_DIRECT=http://localhost:8082

get_pool() {
  curl -s -D - "$1" -o /dev/null | grep -i '^X-App-Pool:' | awk '{print $2}' | tr -d '\r' || echo unknown
}

# baseline
for i in $(seq 1 8); do
  code=$(curl -s -o /dev/null -w "%{http_code}" $BASE/version) || code=000
  pool=$(get_pool $BASE/version || echo "unknown")
  if [ "$code" != "200" ] || [ "$pool" != "blue" ]; then
    echo "Baseline check failed: status=$code pool=$pool"; exit 1
  fi
done
echo "Baseline OK (blue)"

# induce chaos on blue
curl -s -X POST "${BLUE_DIRECT}/chaos/start?mode=error" || true

# poll for ~10s
end=$(( $(date +%s) + 10 ))
count=0; green=0; bad=0
while [ $(date +%s) -lt $end ]; do
  code=$(curl -s -o /dev/null -w "%{http_code}" $BASE/version) || code=000
  pool=$(get_pool $BASE/version || echo "unknown")
  count=$((count+1))
  if [ "$code" != "200" ]; then bad=$((bad+1)); fi
  if [ "$pool" = "green" ]; then green=$((green+1)); fi
  sleep 0.2
done

echo "Requests=$count green=$green bad=$bad"
pct_green=$((100 * green / count))
if [ "$bad" -ne 0 ]; then
  echo "FAIL: observed non-200 responses during failover"; exit 2
fi
if [ "$pct_green" -lt 95 ]; then
  echo "FAIL: only ${pct_green}% responses from green (<95%)"; exit 3
fi
echo "Failover verification OK"

# stop chaos
curl -s -X POST "${BLUE_DIRECT}/chaos/stop" || true
