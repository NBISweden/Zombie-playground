resource "openstack_compute_instance_v2" "haproxy" {
  name            = "haproxy"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  security_groups = flatten(var.secgroups)

  network {
    uuid = "b19680b3-c00e-40f0-ad77-4448e81ae226"
    name = "public"
  }

  config_drive = "true"
  user_data    = var.cloud_init_data
}

resource "time_rotating" "rsa1" {
  rotation_minutes = 5
}

resource "vault_generic_endpoint" "ssh-cert" {
  path = "bp-ssh/sign/main"

  ignore_absent_fields = true
  disable_read         = true
  disable_delete       = true

  write_fields = [
    "signed_key",
  ]

  data_json = jsonencode({
    public_key = file(pathexpand(join(".", [var.ssh_key_path, "pub"]))),
    timestamp  = time_rotating.rsa1.unix
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "local_file" "signed-cert" {
  content         = vault_generic_endpoint.ssh-cert.write_data["signed_key"]
  filename        = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
  file_permission = "660"
}

resource "local_file" "inventory" {
  content         = <<-EOF
    all:
      vars:
        ansible_ssh_private_key_file: ${pathexpand(var.ssh_key_path)}
      hosts:
        haproxy:
          ansible_host: ${openstack_compute_instance_v2.haproxy.access_ip_v4}
          ansible_ssh_common_args: -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
          ansible_user: ${var.ssh_user}
  EOF
  filename        = "inventory"
  file_permission = "660"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "null_resource" "git-hook" {
  provisioner "local-exec" {
    command = "git config core.hooksPath .github/hooks/"
  }
}

resource "null_resource" "check_ssh_connection" {
  depends_on = [local_file.signed-cert, local_file.inventory]

  connection {
    host        = openstack_compute_instance_v2.haproxy.network.0.fixed_ip_v4
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_key_path))
    certificate = file(pathexpand(join("-", [var.ssh_key_path, "cert.pub"])))
    agent       = false
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = ["echo 'Connected!'"]
  }

  provisioner "local-exec" {
    command = "ansible-playbook haproxy-config.yml --extra-vars password=${random_password.password.result} --skip-tags 'configuration' -i inventory"
  }
}
