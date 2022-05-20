# Define the instance for the master node 1
resource "openstack_compute_instance_v2" "master-1" {
  name            = "${var.cluster_prefix}-master-01"
  image_name      = var.master-1_image_name != "" ? var.master-1_image_name : var.image_name
  flavor_name     = var.master-1_flavor_name != "" ? var.master-1_flavor_name : var.master_flavor_name
  security_groups = flatten(var.secgroups)
  tags            = []

  network {
    uuid = "21dfbb3d-a948-449b-b727-5fdda2026b45"
    name = "default"
  }

  config_drive = "true"
  user_data    = var.cloud_init_data
}

# Define the instance for the master node 1
resource "openstack_compute_instance_v2" "master-2" {
  name            = "${var.cluster_prefix}-master-02"
  image_name      = var.master-2_image_name != "" ? var.master-2_image_name : var.image_name
  flavor_name     = var.master-2_flavor_name != "" ? var.master-2_flavor_name : var.master_flavor_name
  security_groups = flatten(var.secgroups)
  tags            = []

  network {
    uuid = "21dfbb3d-a948-449b-b727-5fdda2026b45"
    name = "default"
  }

  config_drive = "true"
  user_data    = var.cloud_init_data
}

# Define the instance for the worker node 1
resource "openstack_compute_instance_v2" "worker-1" {
  name            = "${var.cluster_prefix}-worker-01"
  image_name      = var.worker-1_image_name != "" ? var.worker-1_image_name : var.image_name
  flavor_name     = var.worker-1_flavor_name != "" ? var.worker-1_flavor_name : var.worker_flavor_name
  security_groups = flatten(var.secgroups)
  tags            = []

  network {
    uuid = "21dfbb3d-a948-449b-b727-5fdda2026b45"
    name = "default"
  }

  config_drive = "true"
  user_data    = var.cloud_init_data
}

# Define the instance for the worker node 2
resource "openstack_compute_instance_v2" "worker-2" {
  name            = "${var.cluster_prefix}-worker-02"
  image_name      = var.worker-2_image_name != "" ? var.worker-2_image_name : var.image_name
  flavor_name     = var.worker-2_flavor_name != "" ? var.worker-2_flavor_name : var.worker_flavor_name
  security_groups = flatten(var.secgroups)
  tags            = []

  network {
    uuid = "21dfbb3d-a948-449b-b727-5fdda2026b45"
    name = "default"
  }

  config_drive = "true"
  user_data    = var.cloud_init_data
}


locals {
  address_list = flatten([
    openstack_compute_instance_v2.master-1.access_ip_v4,
    openstack_compute_instance_v2.master-2.access_ip_v4,
    openstack_compute_instance_v2.worker-1.access_ip_v4,
    openstack_compute_instance_v2.worker-2.access_ip_v4,
  ])
  worker_list = flatten([
    openstack_compute_instance_v2.worker-1.access_ip_v4,
    openstack_compute_instance_v2.worker-2.access_ip_v4,
  ])
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

resource "null_resource" "check_ssh_connection" {
  depends_on = [local_file.signed-cert]
  count      = length(local.address_list)

  connection {
    host                = local.address_list[count.index]
    user                = var.ssh_user
    private_key         = file(pathexpand(var.ssh_key_path))
    certificate         = file(pathexpand(join("-", [var.ssh_key_path, "cert.pub"])))
    agent               = false
    timeout             = "10m"
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = file(pathexpand(var.ssh_key_path))
    bastion_certificate = file(pathexpand(join("-", [var.ssh_key_path, "cert.pub"])))
  }

  provisioner "remote-exec" {
    inline = ["echo 'Connected!'"]
  }
}

resource "random_password" "etcd_key" {
  length           = 32
  special          = true
  override_special = "!@#$%&*_+<>"
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  number           = true
}


resource "rke_cluster" "cluster" {
  depends_on            = [null_resource.check_ssh_connection, local_file.signed-cert]
  ignore_docker_version = false
  disable_port_check    = true
  kubernetes_version    = var.k8s_version
  cluster_name          = var.cluster_prefix
  update_only           = var.cluster_update

  nodes {
    hostname_override = "${var.cluster_prefix}-master-01"
    address           = openstack_compute_instance_v2.master-1.access_ip_v4
    user              = var.ssh_user
    role              = ["controlplane", "etcd"]
    ssh_key_path      = pathexpand(var.ssh_key_path)
    ssh_cert_path     = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
    ssh_agent_auth    = false
    labels            = {}
  }

  nodes {
    hostname_override = "${var.cluster_prefix}-master-02"
    address           = openstack_compute_instance_v2.master-2.access_ip_v4
    user              = var.ssh_user
    role              = ["controlplane", "etcd"]
    ssh_key_path      = pathexpand(var.ssh_key_path)
    ssh_cert_path     = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
    ssh_agent_auth    = false
    labels            = {}
  }

  nodes {
    hostname_override = "${var.cluster_prefix}-worker-01"
    address           = openstack_compute_instance_v2.worker-1.access_ip_v4
    user              = var.ssh_user
    role              = ["worker"]
    ssh_key_path      = pathexpand(var.ssh_key_path)
    ssh_cert_path     = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
    ssh_agent_auth    = false
    labels            = {}
  }
  nodes {
    hostname_override = "${var.cluster_prefix}-worker-02"
    address           = openstack_compute_instance_v2.worker-2.access_ip_v4
    user              = var.ssh_user
    role              = ["worker"]
    ssh_key_path      = pathexpand(var.ssh_key_path)
    ssh_cert_path     = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
    ssh_agent_auth    = false
    labels            = {}
  }

  authentication {
    strategy = "x509"
    sans     = [var.external_hostname]
  }

  authorization {
    mode    = "rbac"
    options = {}
  }

  bastion_host {
    address        = var.bastion_host
    user           = var.bastion_user
    ssh_cert_path  = pathexpand(join("-", [var.ssh_key_path, "cert.pub"]))
    ssh_key_path   = pathexpand(var.ssh_key_path)
    ssh_agent_auth = false
  }


  upgrade_strategy {
    drain = true
    drain_input {
      ignore_daemon_sets = true
      delete_local_data  = true
    }
    max_unavailable_worker       = 1
    max_unavailable_controlplane = 1
  }

  ingress {
    provider      = "nginx"
    node_selector = { "node-role.kubernetes.io/worker" = "true" }
    options       = { "use-proxy-protocol" = "true" }
    extra_args    = {}
  }

  services {

    etcd {
      gid      = 1001
      uid      = 1001
      snapshot = false
      backup_config {
        enabled = false
      }
      extra_args = {
        "election-timeout"   = "5000",
        "heartbeat-interval" = "500",
      }
    }

    kube_api {
      pod_security_policy = true

      audit_log {
        enabled = true
        configuration {
          format     = "json"
          max_age    = 5
          max_backup = 10
          max_size   = 100
          path       = "/var/log/kube-audit/audit-log.json"
          policy     = local.audit_policy
        }
      }
      event_rate_limit {
        enabled       = true
        configuration = local.event_config
      }
      secrets_encryption_config {
        enabled       = true
        custom_config = local.etcd_config
      }
    }

    kube_controller {
      extra_args = {
        "address"                     = "127.0.0.1",
        "feature-gates"               = "RotateKubeletServerCertificate=true",
        "profiling"                   = "false",
        "terminated-pod-gc-threshold" = "1000",
      }
    }

    kubelet {
      extra_binds                  = ["/sbin/apparmor_parser:/sbin/apparmor_parser"]
      fail_swap_on                 = true
      generate_serving_certificate = true
      extra_args = {
        "protect-kernel-defaults" = "true",
        "feature-gates"           = "RotateKubeletServerCertificate=true",
        "tls-cipher-suites"       = "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256"

      }
    }

    scheduler {
      extra_args = {
        "address"   = "127.0.0.1",
        "profiling" = "false"
      }
    }

  }

  addon_job_timeout = 60
  addons            = <<EOL
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: default-psp-role
  namespace: ingress-nginx
rules:
- apiGroups:
  - extensions
  resourceNames:
  - default-psp
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-psp-rolebinding
  namespace: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: default-psp-role
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:serviceaccounts
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:authenticated
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
  annotations:
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'docker/default'
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'docker/default'
spec:
  requiredDropCapabilities:
  - ALL
  privileged: false
  allowPrivilegeEscalation: false
  defaultAllowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  hostNetwork: false
  hostPID: false
  hostIPC: false
  runAsUser:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  seLinux:
    rule: RunAsAny
  fsGroup:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  supplementalGroups:
    rule: MayRunAs
    ranges:
    - min: 1
      max: 65535
  volumes:
  - emptyDir
  - secret
  - persistentVolumeClaim
  - downwardAPI
  - configMap
  - projected
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:restricted
rules:
- apiGroups:
  - extensions
  resourceNames:
  - restricted
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psp:restricted
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:restricted
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated
EOL

}

locals {
  audit_policy = jsonencode({
    "apiVersion" = "audit.k8s.io/v1"
    "kind"       = "Policy"
    "rules" = [
      { "level" = "Metadata" },
    ]
  })

  etcd_config = yamlencode({
    apiVersion = "apiserver.config.k8s.io/v1"
    kind       = "EncryptionConfiguration"
    resources = [
      {
        providers = [
          {
            aescbc = {
              keys = [
                {
                  name   = "key1"
                  secret = base64encode(random_password.etcd_key.result)
                },
              ]
            }
          },
          {
            identity = {}
          },
        ]
        resources = ["secrets", "configmaps"]
      },
    ]
  })

  event_config = yamlencode({
    apiVersion = "eventratelimit.admission.k8s.io/v1alpha1"
    kind       = "Configuration"
    limits = [
      {
        type  = "Server",
        qps   = 5000,
        burst = 20000,
      }
    ]
  })
}

resource "local_file" "inventory" {
  content         = <<-EOT
all:
  vars:
    ansible_ssh_common_args: -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ${var.bastion_user}@${var.bastion_host} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${pathexpand(var.ssh_key_path)}"
    ansible_ssh_private_key_file: ${pathexpand(var.ssh_key_path)}
    ansible_user: ubuntu
  hosts:
  %{for ip in local.worker_list~}
  ${ip}:
  %{endfor~}
EOT
  filename        = "inventory"
  file_permission = "660"
}

resource "null_resource" "git-hook" {
  provisioner "local-exec" {
    command = "git config core.hooksPath .github/hooks/"
  }
}