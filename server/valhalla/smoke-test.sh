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

echo "--- what guidance data does the server send for this route?"
JSON=$(curl -s -X POST "$URL/route" -H 'Content-Type: application/json' -d '{
  "locations": [{"lat": 3.1579, "lon": 101.7116}, {"lat": 2.9264, "lon": 101.6964}],
  "costing": "auto", "alternates": 2}')
echo "exit signs (sign blocks): $(echo "$JSON" | grep -o '"sign"' | wc -l)"
echo "toll flags (has_toll):    $(echo "$JSON" | grep -o '"has_toll":true' | wc -l)"
echo "alternate routes:         $(echo "$JSON" | grep -o '"alternates"' | wc -l)"
OSRM=$(curl -s -X POST "$URL/route" -H 'Content-Type: application/json' -d '{
  "locations": [{"lat": 3.1579, "lon": 101.7116}, {"lat": 2.9264, "lon": 101.6964}],
  "costing": "auto", "format": "osrm", "banner_instructions": true}')
echo "lane data (OSRM format, word lanes): $(echo "$OSRM" | grep -o '"lanes"' | wc -l)"
echo "banner instructions:                 $(echo "$OSRM" | grep -o '"bannerInstructions"' | wc -l)"
# Lane guidance is not part of Valhalla's standard JSON. If the lane count above is 0, the app cannot
# show lanes from this server; exit signs are what is available.
