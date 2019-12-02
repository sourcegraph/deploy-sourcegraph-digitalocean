provider "digitalocean" {
}

resource "digitalocean_ssh_key" "this" {
  count      = var.ssh_key_file == "" ? 0 : 1
  name       = var.ssh_key_name != "" ? var.ssh_key_name : var.app_name
  public_key = file(var.ssh_key_file)
}

resource "digitalocean_droplet" "this" {
  image     = "docker-18-04"
  name      = var.app_name
  region    = var.region
  size      = var.size
  ssh_keys  = [digitalocean_ssh_key.this[0].id]
  user_data = file("resources/user-data.sh")
}
