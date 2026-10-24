#!/bin/sh
# Usage: ./smoke.sh [base-url]   (default http://localhost:8080)
API=${1:-http://localhost:8080}
DEV=smoke-test-device-0001
echo "--- health";  curl -s "$API/healthz"; echo
echo "--- report police near Bukit Bintang"
curl -s -X POST "$API/v1/reports" -H 'Content-Type: application/json' -H "X-Device-Id: $DEV" \
  -d '{"type":"police","lat":3.1478,"lng":101.6953}'; echo
echo "--- nearby (5 km)"
curl -s "$API/v1/reports?lat=3.1478&lng=101.6953&r=5"; echo
echo "--- same spot again from another device = merged as a confirmation"
curl -s -X POST "$API/v1/reports" -H 'Content-Type: application/json' -H "X-Device-Id: smoke-test-device-0002" \
  -d '{"type":"police","lat":3.1479,"lng":101.6954}'; echo
