terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # Remote state stored in DigitalOcean Spaces (S3-compatible)
  # This means Terraform remembers the Droplet exists between runs
  # so it won't create a new one on every push
  backend "s3" {
    endpoints = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    bucket = "perplexica-tfstate"
    key    = "terraform.tfstate"
    region = "us-east-1" # required by terraform, ignored by DO

    encrypt                     = false
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "digitalocean" {
  token = var.do_token
}

# ── SSH Key ────────────────────────────────────────────────────────────────────
resource "digitalocean_ssh_key" "perplexica" {
  name       = "perplexica-deploy-key"
  public_key = var.ssh_public_key
}

# ── Droplet ────────────────────────────────────────────────────────────────────
resource "digitalocean_droplet" "perplexica" {
  name   = "perplexica"
  region = "nyc3"
  size   = "s-2vcpu-4gb" # 2 vCPU / 4GB RAM — $24/mo, needed for Ollama
  image  = "ubuntu-24-04-x64"

  ssh_keys = [digitalocean_ssh_key.perplexica.fingerprint]

  tags = ["perplexica"]
}

# ── Firewall ───────────────────────────────────────────────────────────────────
resource "digitalocean_firewall" "perplexica" {
  name = "perplexica-firewall"

  droplet_ids = [digitalocean_droplet.perplexica.id]

  # Allow SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow Perplexica API
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Block Ollama from public internet (internal use only)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.perplexica.ipv4_address
}
