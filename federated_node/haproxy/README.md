# HAProxy installation for federated node in Safespring
This guide explains how to deploy a federated node for the Big Picture project to Safespring.

## Prerequisites
In order to be able to deploy the federated node (and the haproxy specifically), you need to have [openstack client](https://docs.openstack.org/python-openstackclient/pike/), [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) and [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed in your machine. Also, this guide assumes that you have a [vault](https://www.vaultproject.io/) instance that can provide tokens and sign certificates and that you have access to a project in SSC.

##  Get the RC file
The first step includes getting the RC file for the API access to the openstack environment running on safespring.

### First time user
If this is the **the first time** that you use the API access, start by downloading the RC file from the OpenStack environment. First, you need to go to your OpenStack environment, click on `identity`, `application credentials`, and create an application credential. You should download the OpenStack RC file that contains the environment variables that are necessary to run Openstack command-line clients.


Place the RC file at the root folder and source it using
```bash
source <RC_FILE_NAME>
```

To verify you have sourced the correct environment. Try to list all the images in the openstack environment using this command:
```bash
openstack image list
```

## Haproxy configuration
The commited files under the `haproxy` directory are the ones used for the creation of this guide. However, some changes in the files are needed in order to deploy on different regions.

**Note:** The guide assumes that no DNS entries have been used for the services. If that is not the case, change all the `nip.io` references to the actual DNS entry.

## Create security groups
The security groups for the haproxy need to be create manually. Specifically, two different security groups should be created using the interface. The names of the security groups are the recommended ones. If you decide to change them, you need to replace them in the `secgroups` list in `terraform.tfvars`.

The `external` security group allows for:
- Engress for IPv4 and IPv6 for everyone
- SSH (Ingress - IPv4 - TCP - port 22) for Uppsala, Umeå, and Linköping IPs (130.239.0.0/16, 130.238.0.0/16 and 130.236.0.0/15 respetively)
- HTTP (Ingress - IPv4 - TCP - port 80) for everyone (0.0.0.0/0)
- HTTPS (Ingress - IPv4 - TCP - port 443) for everyone (0.0.0.0/0)


The `BIGPICTURE` security group allows for:
- Engress for IPv4 and IPv6 for everyone
- Ingress TCP with all ports for everyone
- Ingress UDP with all ports for everyone

## Terraform updates
The names of the available resources (such as available images, flavors, volumes etc) vary in different openstack installations. Therefore, some changes in the terraform code might be required.

### Update the terraform.tfvars file
The `terraform.tfvars` file contains information about the instance that will be created.

- To check the images available in your setup, run
```bash
openstack image list
```
and change the `image_name` to the one you selected from the list returned by the command. ubuntu-20.04 was used when creating this guide.

- To check the flavors available in your setup, run
```bash
openstack flavor list
```
and change the `flavor_name` to the one you selected from the list returned by the command. 1 VCPU/512MB RAM instance was used for the haproxy when creating this guide.

- The `id_rsa` key is the default key for the deployment. The `terraform.tfvars` currently contains the `bigpic` key instead. If you prefer to change that, create an rsa key and update the `ssh_key_path` with the location of the key. To create the key run
```bash
ssh-keygen -f <KEY_NAME> -t rsa
```
**Note:** Make sure to avoid using a password for this key
### Update the main.tf file
The `main.tf` file contains information about the network to be used for the instance.

- To check the networks available in your setup, run
```bash
openstack network list
```
and change the  `uuid` and `name` variables under the `network` definition to the one you selected from the list returned by the command. In this case, the internal network should be used.

## Deployment
Now the configuration should be up-to-date and you can create the instance for the haproxy. First, export the vault location using
```bash
export VAULT_ADDR=<VAULT_ADDRESS>
```
and login to vault using
```bash
vault login --method=userpass username=<VAULT_USERNAME>
```
You can remove the `terraform.tfstate` and `inventory` files from the `haproxy` folder and run
```bash
terraform init
```

To plan the deployment run
```bash
terraform plan
```

If everything looks fine, run
```bash
terraform apply
```
and type yes in the prompt. This should try to create the instance and run the ansible playbook (last line in the `main.tf` file). **NOTE:** Be patient since the process takes some time, since the instance is restarted during configuration (the timeout is set in 10 minutes).

If the process work as expected, the instance for the haproxy should now be created. You can make sure it exists by checking the safespring interface of your project, under `compute/instances`.

### Information about updating HAProxy configuration

After any changes to the config has been done they can be applied by running the command below. The `--skip-tags` allows for not running parts of the playbook if they are not being changed.

```sh
ansible-playbook -i inventory haproxy-config.yml --skip-tags 'cron,LE'
```

If another ssh key is to be used than what's default `id_rsa` it can be specified with the `--extra-vars "pubkey=<NAME_OF_PUBLIC_KEY>"`

If the HAproxy should terminate any other TLS connection we can rewrite the playbook to iterate over a list of hostnames but for now that is a bit of unnecessary work.

You should now be able to see the statistics report from the haproxy by accessing `<https://stats.<HAPROXY_IP>.nip.io/>` in your browser. You can get the haproxy ip using the safespring interface of your project. :smiley: