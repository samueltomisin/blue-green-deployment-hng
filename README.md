# Blue/Green with Nginx Upstreams - Quickstart

1. Copy .env.example -> .env and set BLUE_IMAGE and GREEN_IMAGE to the image(s) you were provided:
   cp .env.example .env
   # edit .env and replace YOUR_PROVIDED_IMAGE_HERE with the image name provided to you

2. Generate Nginx config:
   ./nginx/generate-nginx-conf.sh

3. Start services:
   docker compose up -d

4. Confirm baseline (should be blue):
   curl -i http://localhost:8080/version
   # Expect HTTP/1.1 200 and headers:
   # X-App-Pool: blue
   # X-Release-Id: <RELEASE_ID_BLUE>

5. Trigger chaos (simulate Blue failure):
   curl -s -X POST "http://localhost:8081/chaos/start?mode=error"

6. Immediately poll the public endpoint:
   for i in {1..30}; do curl -s -D - http://localhost:8080/version | sed -n '1,6p'; sleep 0.25; done
   # Expect HTTP 200 responses, X-App-Pool: green within a few requests.

7. Stop chaos:
   curl -s -X POST "http://localhost:8081/chaos/stop"

8. Run CI verification locally:
   ./ci/verify_failover.sh
