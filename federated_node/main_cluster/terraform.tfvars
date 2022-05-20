ssh_user           = "ubuntu"

image_name         = "ubuntu-20.04"
# specific instances can be changed by setting the appropriate name below
master-1_image_name = ""
master-2_image_name = ""
master-3_image_name = ""
worker-1_image_name = ""

# specific instances can be changed by setting the appropriate name below
master-1_flavor_name = ""
master-2_flavor_name = ""
master-3_flavor_name = ""
# the flavor below is used unless over specifically ridden above
master_flavor_name = "l2.c2r4.100"
# specific instances can be changed by setting the appropriate name below
worker-1_flavor_name = ""
worker-2_flavor_name = ""
worker-3_flavor_name = ""
worker-4_flavor_name = ""
worker-5_flavor_name = ""
# the flavor below is used unless over specifically ridden above
worker_flavor_name = "l2.c4r8.500"

secgroups          = ["BIGPICTURE"]
ssh_key_path       = "~/.ssh/bigpic"


# Replace HAPROXY IP here:
bastion_host = "<HAPROXY-IP>"
bastion_user = "ubuntu"

# RKE stuff
k8s_version    = "v1.20.8-rancher1-1"
cluster_prefix = "bp-federated"
# set this to true if only adding or removing nodes
cluster_update = true
# If the kubernetes api is accessible via a registered domain name, replace HAPROXY IP here:
external_hostname = "k8s.<HAPROXY-IP>.nip.io"

cloud_init_data = <<-EOT
#cloud-config
# If an authorized key is needed for disaster recovery place it here
# ssh_authorized_keys:
#   -

write_files:
  - path: /etc/ssh/trusted-ca-keys.pem
    permissions: '0644'
    owner: root:root
    encoding: b64
    content: |
      c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJocnVyNnR0clFyeHBFRHY2NXU0b0luUFh1a1kzSUZuQ1VXcEYvSHZjZE8K
  - path: "/etc/sysctl.d/90-kubelet.conf"
    owner: root:root
    permissions: '0644'
    content: |
      vm.overcommit_memory=1
      vm.panic_on_oom=0
      kernel.panic=10
      kernel.panic_on_oops=1
      kernel.keys.root_maxbytes=25000000
  - path: "/etc/apt/preferences.d/docker"
    owner: root:root
    permissions: '0600'
    content: |
      Package: docker-ce
      Pin: version 5:19*
      Pin-Priority: 800
apt:
  sources:
    docker.list:
      source: deb [arch=amd64] http://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

groups:
  - docker

system_info:
  default_user:
    groups: [docker]

runcmd:
  - echo "TrustedUserCAKeys /etc/ssh/trusted-ca-keys.pem" >> /etc/ssh/sshd_config
  - sysctl -p /etc/sysctl.d/90-kubelet.conf
  - groupadd --gid 52034 etcd
  - useradd --comment "etcd service account" --uid 52034 --gid 52034 etcd

packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io

package_update: true

package_upgrade: true

power_state:
  mode: reboot
EOT
