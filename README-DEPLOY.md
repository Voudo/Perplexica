# Perplexica — GitHub CI/CD Deploy

Fully automated deploy of Perplexica backend to DigitalOcean.
Every push to `master` provisions infrastructure (if needed) and deploys the app.
Zero manual steps after the one-time secret setup below.

## Architecture

```
GitHub push → Actions → Terraform provisions DO Droplet (once)
                      → SSH deploys Docker Compose (every push)
                      → Perplexica + Ollama running on Droplet
```

**Stack:**
- Perplexica backend (`/api/search` endpoint)
- Ollama with `nomic-embed-text` (free, no API key needed)
- Claude (Anthropic) as the LLM
- Terraform state stored in DigitalOcean Spaces (so Droplet isn't recreated on every push)

**Cost:** ~$24/month (2vCPU / 4GB Droplet)

---

## One-Time Setup (5 minutes)

### Step 1 — Fork this repo
Fork to your GitHub account.

### Step 2 — Create a DigitalOcean API Token
1. Go to https://cloud.digitalocean.com/account/api/tokens
2. Click **Generate New Token**
3. Name it `perplexica-deploy`, enable Read + Write
4. Copy the token

### Step 3 — Create a DigitalOcean Space (for Terraform state)
1. Go to https://cloud.digitalocean.com/spaces
2. Create a Space named `perplexica-tfstate` in `nyc3`
3. Go to **Manage Keys** → generate a Spaces access key
4. Copy the Access Key and Secret Key

### Step 4 — Generate an SSH keypair
Run this locally (or anywhere — you just need the key pair):
```bash
ssh-keygen -t ed25519 -f perplexica-deploy-key -N ""
# Creates: perplexica-deploy-key (private) and perplexica-deploy-key.pub (public)
cat perplexica-deploy-key      # this is SSH_PRIVATE_KEY
cat perplexica-deploy-key.pub  # this is SSH_PUBLIC_KEY
```

### Step 5 — Add GitHub Secrets
Go to your fork → **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Where to get it |
|---|---|
| `DO_TOKEN` | DigitalOcean API token from Step 2 |
| `SPACES_ACCESS_KEY` | DO Spaces access key from Step 3 |
| `SPACES_SECRET_KEY` | DO Spaces secret key from Step 3 |
| `SSH_PRIVATE_KEY` | Contents of `perplexica-deploy-key` from Step 4 |
| `SSH_PUBLIC_KEY` | Contents of `perplexica-deploy-key.pub` from Step 4 |
| `ANTHROPIC_API_KEY` | Your Anthropic API key (`sk-ant-...`) |

### Step 6 — Push to master
```bash
git push origin master
```

That's it. Watch the Actions tab. Your API will be live at:
```
http://YOUR_DROPLET_IP:3000/api/search
```
The IP is printed at the end of the deploy workflow.

---

## Usage

```js
const res = await fetch("http://YOUR_DROPLET_IP:3000/api/search", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    query: "What is the latest in AI regulation?",
    focusMode: "webSearch",         // webSearch | academicSearch | youtubeSearch | redditSearch
    chatModel: {
      provider: "anthropic",
      model: "claude-haiku-4-5"     // fast + cheap
    },
    embeddingModel: {
      provider: "ollama",
      model: "nomic-embed-text"     // free, runs on the droplet
    }
  })
});

const { message, sources } = await res.json();
```

```python
import httpx

res = httpx.post("http://YOUR_DROPLET_IP:3000/api/search", json={
    "query": "What is the latest in AI regulation?",
    "focusMode": "webSearch",
    "chatModel": {"provider": "anthropic", "model": "claude-haiku-4-5"},
    "embeddingModel": {"provider": "ollama", "model": "nomic-embed-text"}
})
data = res.json()
print(data["message"])
print(data["sources"])
```

---

## Logging & Troubleshooting

### CI Diagnostics
Every deploy prints a **Diagnostic Report** at the end of the "Deploy via SSH" step showing:
- Container status and health for all 3 services (Perplexica, Ollama, SearXNG)
- Ollama model list (confirms `nomic-embed-text` is loaded)
- System memory and disk usage
- Recent logs from each container

If any service is unhealthy, the deploy **fails** and the logs are printed inline.

### Live Debugging via SSH
```bash
ssh root@YOUR_DROPLET_IP
cd /opt/perplexica

# Container status with health
docker compose ps

# Follow all logs live
docker compose logs -f

# Perplexica logs only (includes SearXNG output)
docker compose logs -f perplexica

# Ollama logs only
docker compose logs -f ollama

# Check SearXNG inside the Perplexica container
docker compose exec perplexica curl -s http://localhost:8080

# Check Ollama health
docker compose exec ollama curl -s http://localhost:11434/api/tags

# List Ollama models
docker compose exec ollama ollama list

# System resources
free -h && df -h /
```

### Log Rotation
Logs use the `json-file` driver with 10MB max-size and 3 rotated files per container (30MB max per service). Docker manages rotation automatically.

---

## Tearing Down
To destroy the Droplet and stop paying:
Go to **Actions → Destroy Infrastructure → Run workflow**

Terraform will cleanly remove the Droplet and firewall.
The Spaces bucket (tfstate) will remain so you can redeploy later.