My Blue/Green Deployment - How I Built It
The Problem
I needed to deploy two versions of a Node.js app (Blue and Green) where:

Blue serves all traffic normally
If Blue crashes, Green takes over automatically
Users never see errors during the take over
Everything runs on EC2 with Docker.

My Solution - The Big Picture
I put Nginx in front of both apps. When a request comes in:

Nginx tries Blue first
If Blue is down or returns an error, Nginx immediately retries the same request to Green
The user gets a response from Green without ever knowing Blue failed. 

Nginx retries within the same request and the user doesn't see the failure cause the backup is has taken over.


This is the Critical Config that made it work
nginxupstream app_backend {
    server app_blue:8081 max_fails=2 fail_timeout=5s;
    server app_green:8082 backup;
}

proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
proxy_connect_timeout 2s;
proxy_read_timeout 3s;

Here's what each part does:
backup is on Green: Green sits lazy until Blue fails. This keeps it simple.
max_fails=2 fail_timeout=5s: After 2 failures, mark Blue as down for 5 seconds. This is fast enough to catch crashes quickly.
proxy_next_upstream: This tells Nginx "if you get an error or timeout from Blue, try Green immediately." This is why users see zero errors.
Timeouts (2-3 seconds): I made these tight so Nginx detects failures fast. The task said requests must complete in under 10 seconds, so:

Try Blue: 2s connect + 3s read = 5s max
Retry to Green: 2s + 3s = 5s max
Total worst case: 10s 

If I made timeouts longer (like 5s each), I'd risk hitting the 10s limit.

How I Handle the Ports
The grader needs to trigger chaos directly on Blue and Green, so I exposed:

8080 → Nginx (main entry point)
8081 → Blue (for chaos testing)
8082 → Green (for chaos testing)

Inside Docker, each app listens on its respective port (8081 for Blue, 8082 for Green). Nginx talks to them using app_blue:8081 and app_green:8082
Important: I used 0.0.0.0:8080:80 in docker-compose instead of just 8080:80. This binds to all network interfaces so the EC2 public IP works. Without the 0.0.0.0, it only works on localhost and EC2 public IP won't work.

Environment Variables - Making It Flexible
Everything is controlled by a .env file:
bash
BLUE_IMAGE=app_blue
GREEN_IMAGE=app_green
RELEASE_ID_BLUE=blue-001
RELEASE_ID_GREEN=green-002
The grader can change these without touching my code. Blue and Green pass these to the app as environment variables, and the app returns them in headers so we can verify which version served the request.

Testing My Setup
I wrote a simple script that:

Checks Blue is serving traffic
Crashes Blue using the chaos endpoint
Sends 20 requests and counts failures
Verifies ≥95% came from Green

The key metric: zero failed requests. If I see any non-200 responses, something's wrong with my timeout or retry config.

What Could Go Wrong (And My Solutions)
Problem: Timeouts too short → Blue times out even when healthy
Solution: 3 seconds is the sweet spot. Not too aggressive, not too slow.

Problem: No backup directive → Both Blue and Green get traffic
Solution: Use backup on Green so it only activates when needed.

Problem: Not retrying on timeouts → Users see errors when Blue hangs
Solution: proxy_next_upstream timeout catches hung connections.

Problem: EC2 ports not accessible from outside
Solution: AWS Security Group must allow ports 8080-8082 from 0.0.0.0/0

Why This Design Works

Simple: Just Nginx + 2 app containers. No complex orchestration.
Fast failover: 2-3 second timeouts mean we detect failures quickly.
Zero downtime: Nginx retries happen within the same user request.
Easy to test: Can trigger failures manually and see the switch happen.
Production-ready: Same pattern used in real deployments, just simplified.

The beauty is that from the user's perspective, nothing changes. They send a request to port 8080 and get a 200 response. They don't know Blue crashed and Green took over - that all happens behind the scenes in Nginx.