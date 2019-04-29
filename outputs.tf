output "Server" {
  value = "${format("https://%s/", digitalocean_droplet.this.ipv4_address)}"
}

output "SSH" {
  value = "${format("ssh root@%s", digitalocean_droplet.this.ipv4_address)}"
}

output "Management console" {
  value = "${format("https://%s:2633/", digitalocean_droplet.this.ipv4_address)}"
}

output "Command to have the self-signed certificate trusted by this machine" {
  value = "${format("scp root@%s", digitalocean_droplet.this.ipv4_address)}:~/sourcegraph-root-ca.zip ./ && unzip sourcegraph-root-ca.zip && mv ./rootCA* \"$(mkcert -CAROOT)\" && mkcert -install"
}
