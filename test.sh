#!/bin/bash
EC2_IP="3.90.109.123"

echo "🧪 Final Validation Test"
echo "========================"

# Test 1
echo "Test 1: Baseline (Blue active)..."
POOL=$(curl -s -I http://$EC2_IP:8080/version | grep X-App-Pool | awk '{print $2}' | tr -d '\r')
if [ "$POOL" = "blue" ]; then
  echo "✅ Blue is active"
else
  echo "❌ Expected blue, got: $POOL"
  exit 1
fi

# Test 2
echo "Test 2: Triggering chaos..."
curl -s -X POST http://$EC2_IP:8081/chaos/start?mode=error
sleep 2

# Test 3
echo "Test 3: Verifying failover (20 requests)..."
FAILURES=0
GREEN_COUNT=0
for i in {1..20}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$EC2_IP:8080/version)
  if [ "$CODE" != "200" ]; then
    FAILURES=$((FAILURES + 1))
  fi
  POOL=$(curl -s -I http://$EC2_IP:8080/version | grep X-App-Pool | awk '{print $2}' | tr -d '\r')
  if [ "$POOL" = "green" ]; then
    GREEN_COUNT=$((GREEN_COUNT + 1))
  fi
  sleep 0.3
done

echo "Results: $FAILURES failures, $GREEN_COUNT/20 from Green"

if [ $FAILURES -eq 0 ]; then
  echo "✅ Zero failures"
else
  echo "❌ Had $FAILURES failures"
  exit 1
fi

if [ $GREEN_COUNT -ge 19 ]; then
  echo "✅ Traffic switched to Green ($GREEN_COUNT/20)"
else
  echo "❌ Only $GREEN_COUNT/20 from Green (need ≥19)"
  exit 1
fi

# Cleanup
curl -s -X POST http://$EC2_IP:8081/chaos/stop

echo ""
echo "🎉 ALL TESTS PASSED - Ready for grader!"