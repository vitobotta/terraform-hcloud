output "server_ips" {
  value = {
    for server in hcloud_server.server :
    server.name => server.ipv4_address
  }
}

output "floating_ip" {
  value = hcloud_floating_ip.default.ip_address
}
