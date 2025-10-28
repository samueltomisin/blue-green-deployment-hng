# 🚀 Blue/Green Deployment with Nginx Upstreams (Auto-Failover + Manual Toggle)

## 📋 Overview
This project implements a *Blue/Green deployment* pattern using Docker-Compose and Nginx as the load balancer.  
Two identical Node.js services (`blue` and `green`) run behind Nginx.  
By default, all traffic goes to the *Blue* service.  
If Blue fails (returns 5xx or times out), Nginx automatically fails over to Green — ensuring zero failed requests and zero downtime

The grader (or CI) verifies this behavior automatically.

### Nginx Responsibilities
- Detect primary failure via `max_fails` and `fail_timeout`
- Retry on `error`, `timeout`, or `5xx`
- Forward app headers (`X-App-Pool`, `X-Release-Id`) unchanged
- Support manual toggle via `$ACTIVE_POOL`

---

## 🛠️ Requirements
- Docker ≥ 24.x
- Docker Compose plugin
- Unix-like shell (Linux / macOS / WSL)

---

## ⚙️ Environment Variables

Create a `.env` file (or use `.env.example` as a reference):

```env
# Container images (provided by grader)
BLUE_IMAGE=yimikaade/wonderful:devops-stage-t
GREEN_IMAGE=yimikaade/wonderful:devops-stage-two

# Which pool is active by default
ACTIVE_POOL=blue

# Identifiers for each release
RELEASE_ID_BLUE=blue-001
RELEASE_ID_GREEN=green-001


Generate Nginx config:
   ./nginx/generate-nginx-conf.sh

Start services:
   docker compose up -d

Confirm baseline (should be blue):
   curl -i http://localhost:8080/version
   #Expect HTTP/1.1 200 and headers:
   #X-App-Pool: blue
   #X-Release-Id: <RELEASE_ID_BLUE>

Trigger chaos (simulate Blue failure):
   curl -s -X POST "http://localhost:8081/chaos/start?mode=error"

Immediately poll the public endpoint:
   for i in {1..30}; do curl -s -D - http://localhost:8080/version | sed -n '1,6p'; sleep 0.25; done
   #Expect HTTP 200 responses, X-App-Pool: green within a few requests.

 Stop chaos:
   curl -s -X POST "http://localhost:8081/chaos/stop"


