variable "do_token" {
  description = "DigitalOcean API token"
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to install on the droplet"
}
