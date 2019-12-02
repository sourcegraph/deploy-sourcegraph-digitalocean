output "server" {
  value = format("https://%s/", digitalocean_droplet.this.ipv4_address)
}

output "ssh" {
  value = format("ssh root@%s", digitalocean_droplet.this.ipv4_address)
}

output "ip-address" {
  value = format("https://%s:2633/", digitalocean_droplet.this.ipv4_address)
}

output "management-console" {
  value = format("https://%s:2633/", digitalocean_droplet.this.ipv4_address)
}

output "trust-self-signed-cert" {
  value = "${format("scp root@%s", digitalocean_droplet.this.ipv4_address)}:~/sourcegraph-root-ca.zip ./ && unzip sourcegraph-root-ca.zip && mv ./rootCA* \"$(mkcert -CAROOT)\" && mkcert -install"
}
