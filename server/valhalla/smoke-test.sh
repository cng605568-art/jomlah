#!/bin/sh
# Usage: ./smoke-test.sh [base-url]     (default http://localhost:8002)
URL=${1:-http://localhost:8002}
echo "--- status"
curl -s "$URL/status"; echo
echo "--- KLCC -> Putrajaya (first 1500 bytes)"
curl -s -X POST "$URL/route" -H 'Content-Type: application/json' -d '{
  "locations": [{"lat": 3.1579, "lon": 101.7116}, {"lat": 2.9264, "lon": 101.6964}],
  "costing": "auto",
  "directions_options": {"units": "kilometers", "language": "en-US"}
}' | head -c 1500; echo
# Lane check for later: run SPE / SUKE / Federal Highway routes and look at the maneuver
# JSON for lane information. If it is absent, that is an OSM data gap to fix (Lorong Squad).
