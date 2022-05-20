# Cluster deployment procedure for federated node in Safespring

This guide explains how to deploy a federated node for the Big Picture project to Safespring. Specifically, it focuses on the main cluster and kubernetes. The main cluster consists of 2 master and 2 worker nodes.

## Prerequisites
In order to be able to deploy the federated node (and the main cluster specifically), you need to have finished the deployment of the haproxy explained under `federated_node/haproxy`. Additionally, you need to have [openstack client](https://docs.openstack.org/python-openstackclient/pike/), [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) and [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed in your machine. Also, this guide assumes that you have a [vault](https://www.vaultproject.io/) instance that can provide tokens and sign certificates and that you have access to a project in safespring.

##  Get the RC file
The first step includes getting the RC file for the API access to the openstack environment running on Safespring.

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

## Main cluster configuration
The commited files under the `federated_node/main_cluster` directory are the ones used for the creation of this guide. However, some changes in the files are needed in order to deploy on different regions.

**Note:** The guide assumes that no DNS entries have been used for the services. If that is not the case, change all the `nip.io` references to the actual DNS entries.

## Security groups
During the deployment of the `haproxy`, two security groups were created. If the do not already exist in your deployment, follow the [Create security groups](https://github.com/NBISweden/BigPicture-Deployment/tree/feature/feature-haproxy/federated_node/haproxy#create-security-groups) section to create them.

## Terraform updates
The names of the available resources (such as available images, flavors, volumes etc) vary in different openstack installations. Therefore, some changes in the terraform code might be required.

### Update the terraform.tfvars file
The `terraform.tfvars` file contains information about the instance that will be created.

- To check the images available in your setup, run
```bash
openstack image list
```
and change the `image_name` to the one you selected from the list returned by the command. Ubuntu 20 was used when creating this guide.

- To check the flavors available in your setup, run
```bash
openstack flavor list
```
and change the `flavor_name` to the one you selected from the list returned by the command. 1 VCPU/1GB RAM instances were used for the master nodes and 2 VCPU/4GB RAM instances for the worker nodes when creating this guide.

- Each worker node should have a persistent storage attached to it. You can change the size of the volume using the `size` variable under `openstack_blockstorage_volume_v2` for each of the workers. 200GB were used when creating this guide.

- The `id_rsa` key is the default key for the deployment. The `terraform.tfvars` currently contains the `bigpic` key instead. If you prefer to change that, create an rsa key and update the `ssh_key_path` with the location of the key. To create the key run
```bash
ssh-keygen -f <KEY_NAME> -t rsa
```
**Note:** Make sure to avoid using a password for this key

- Finally, make sure that the `bastion_host` and `external_hostname` are pointing to the haproxy ip.

### Update the main.tf file
The `main.tf` file contains information about the network to be used for the instance.

- To check the networks available in your setup, run
```bash
openstack network list
```
and change the `uuid` (`ID` in the openstack response) and `name` variables under the `network` definition to the one you selected from the list returned by the command. In this case, the internal network should be used.

## Deployment
Now the configuration should be up-to-date and you can create the instances for the main cluster. First, export the vault location using
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

**Note:** If you are using `macOS`, you may need to change the `ansible_ssh_common_args` in the `inventory` file to
```bash
ansible_ssh_common_args: -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ubuntu@130.238.28.17 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i <PATH_TO_PUBLIC_KEY>" -i <PATH_TO_PUBLIC_KEY>
```

To plan the deployment run
```bash
terraform plan
```

If everything looks fine, run
```bash
terraform apply
```
and type yes in the prompt. This should try to create the instances for the master and worker nodes and run the ansible playbook (last line in the `main.tf` file).
**NOTE:** Be patient since the process takes some time, since the instance is restarted during configuration (the timeout is set in 10 minutes).

If the process worked as expected, the master and worker instances for the cluster should now be created. You can make sure they exist by checking the SNIC user interface of your project, under `compute/instances`.

## Update and run ansible playbook
The next step includes the update of the haproxy configuration, in order to use the correct ips for the created nodes. Using the SNIC user interface of your project, under `compute/instances`,
- copy the ips of the worker nodes to the `federated_node/haproxy/haproxy-config.yml` under `backend bp-main-backend` and `backend bp-main-backend-http`
- copy the ips of the master nodes to the `federated_node/haproxy/haproxy-config.yml` under `backend bp-main-k8s`
and run this ansible playbook, exluding the Let's encrypt and cron job tags.
```bash
cd ../haproxy
ansible-playbook haproxy-config.yml --skip-tags='LE,cron' --extra-vars 'pubkey=<PUBLIC_KEY_NAME>' -i inventory
```

## Testing the kubernetes cluster
If everything went as expected, you now should be able to get the `kubeconfig` file from the `terraform.tfstate` file under `federated_node/main_cluster`. If the file is not encrypted, use
```bash
cd ../main_cluster
sops -e -i terraform.tfstate
```
to encrypt it. To get the `kubeconfig.yml` and therefore access to the kubernetes API, run
``` bash
sops -d terraform.tfstate | jq -r '.. |."kube_config_yaml"? | select(. != null)' | sed -e 's/server: "https:\/\/10.65.*"/server: "https:\/\/k8s.<HAPROXY_IP>.nip.io"/' > kubeconfig.yml
```
where the `<HAPROXY_IP>` is the ip of the instance created when following the guide under `federated_node/haproxy`.

Export the `kubeconfig.yml` in the KUBECONFIG environment variable running
```bash
export KUBECONFIG=kubeconfig.yml
```
and try running any kubectl command, such as
```bash
kubectl get nodes
```
If you are able to see the master and worker nodes, the deployment of the main cluster should be successful! :smile:

## Configure the deployment

Changing the number of deployed nodes requires changes to both the tfvars file ans the `main.tf` file.

Changing the size of the instance or the base image can be done in the `tfvars` file for any configured node.
