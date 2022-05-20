ssh_user     = "ubuntu"
image_name   = "ubuntu-20.04"
flavor_name  = "l2.c2r4.100"
secgroups    = ["external", "BIGPICTURE", "default"]
ssh_key_path = "/home/shreyas/BP/BigPicture-Deployment/haproxy/07-vm"

cloud_init_data = <<-EOT
#cloud-config
# If an authorized key is needed for disaster recovery place it here
# ssh_authorized_keys:
#   - ssh-bigpic AAAAC3NzaC1lZDI1NTE5AAAAIBWFY9V1smKmjLWWCqgEvj8QpLPeVwGujdSbOHOiIfFt

write_files:
  - path: /etc/ssh/trusted-ca-keys.pem
    permissions: '0644'
    owner: root:root
    encoding: b64
    content: |
      c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJocnVyNnR0clFyeHBFRHY2NXU0b0luUFh1a1kzSUZuQ1VXcEYvSHZjZE8K

  - path: /etc/systemd/system/haproxy.service.d/override.conf
    permissions: '0640'
    owner: root:root
    content: |
      [Service]
      LimitNOFILE=1048576
      LimitNPROC=64000

runcmd:
  - echo "TrustedUserCAKeys /etc/ssh/trusted-ca-keys.pem" >> /etc/ssh/sshd_config

package_update: true
packages:
  - haproxy
package_upgrade: true
power_state:
  mode: reboot
EOT
