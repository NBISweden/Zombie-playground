terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.43.0"
    }

    rke = {
      source  = "rancher/rke"
      version = "~> 1.2.3"
    }

  }
  required_version = ">= 0.13"
}
