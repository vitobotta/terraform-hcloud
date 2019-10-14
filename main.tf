resource "hcloud_ssh_key" "default" {
  name       = var.ssh_public_key_name
  public_key = "${file(var.ssh_public_key)}"
}

resource "hcloud_network" "default" {
  name     = var.private_network_name
  ip_range = var.private_ip_range
}

resource "hcloud_network_subnet" "default" {
  network_id   = "${hcloud_network.default.id}"
  type         = "server"
  network_zone = var.private_network_zone
  ip_range     = var.private_ip_range
}

resource "hcloud_floating_ip" "default" {
  type          = "ipv4"
  home_location = "${var.hcloud_location}"
  name          = var.floating_ip_name
}

resource "hcloud_server" "server" {
  for_each = var.servers

  name        = each.value.name
  image       = each.value.image
  server_type = each.value.server_type
  location    = each.value.location
  backups     = each.value.backups
  ssh_keys    = [var.ssh_public_key_name]

  provisioner "remote-exec" {
    inline = [var.install_ansible_dependencies ? var.ansible_dependencies_install_command : "sleep 0"]

    connection {
      host        = "${self.ipv4_address}"
      type        = "ssh"
      user        = "root"
      private_key = "${file(var.ssh_private_key)}"
    }
  }

  provisioner "ansible" {
    ansible_ssh_settings {
      insecure_no_strict_host_key_checking = true
    }

    plays {
      enabled = var.run_ansible_playbook

      playbook {
        file_path = var.ansible_playbook_path
      }

      extra_vars = {
        cluster_name = "${var.cluster_name}"
        floating_ip  = "${hcloud_floating_ip.default.ip_address}"
        server_name  = each.value.name
        ansible_user = "root"
      }

      vault_id = [var.ansible_vault_password_path]
    }

    connection {
      host = "${self.ipv4_address}"
      type = "ssh"
      user = "root"
    }
  }

  provisioner "remote-exec" {
    inline = [var.run_rancher_deploy ? "${var.rancher_node_command} ${each.value.roles} --internal-address ${each.value.private_ip_address}" : ""]

    connection {
      host        = "${self.ipv4_address}"
      type        = "ssh"
      user        = var.post_ansible_ssh_user
      private_key = "${file(var.ssh_private_key)}"
    }
  }
}

resource "hcloud_server_network" "server_network" {
  for_each = var.servers

  network_id = hcloud_network.default.id
  server_id  = hcloud_server.server[each.key].id
  ip         = each.value.private_ip_address
}

