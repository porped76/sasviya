## Outline

There are three sections in this project:

- *YOU ARE HERE =>* [Deploy the infrastructure, namelly Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL](./1-deploy-aks-postgresql.md)
- [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
- [Deploy Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)

## Login to the Cloud Shell from this URL: https://shell.azure.com/ or ssh to *YOUR_SAS_USERNAME*@cldlgn.fyi.sas.com
## cloudbox and then execute the az login command, following the instructions to login to Azure Cloud with the Azure CLI
## Cloud Shell is automatically authenticated under the initial account signed-in with. 

```bash
# Run 'az login' only if you are logged in to YOUR_SAS_USERNAME@cldlgn.fyi.sas.com cloudbox or if you need to use
# a different account in the Cloud Shell
#az login
```
## Edit the following options according your needs:

```bash
# Set the shell to use vi-mode:
set -o vi
# Exported variables
# Define the ACCOUNT of the Azure subscription
ACCOUNT=SESA
# Define the LOC of the Azure location
LOC=eastus
# Define your SAS userid. To avoid any conflict with the Azure created objects, the usage of your $SASUID is advised
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
# Define the PERFIX of the Azure created objects
PERFIX=$SASUID
# Save the PERFIX info for next time you login
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PERFIX' line='export PERFIX=$PERFIX'" --diff
# Define the NS of the Azure Kubernetes Services cluster
NS=sasviya-prod
# Define the cloudbox IP
CLOUDBOXIP=$(curl ifconfig.me)
# Define k8s config
KUBECONFIG=~/.kube/${PERFIX}-aks-kubeconfig.conf
# Export the KUBECONFIG variable for the next you login
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export KUBECONFIG' line='export KUBECONFIG=$KUBECONFIG'" --diff
# Export the PATH variable fot the bin directory for the next you login
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PATH' line='export PATH=$PATH:$HOME/bin'" --diff

# Configure the Azure default location and set the subscription
az configure --defaults location="${ACCOUNT}"
az account set -s "${ACCOUNT}"

# If needed, create an Azure Service Principal and get associated Password and ID. You only have to do it once!
#SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
#SP_PASSWD=$(az ad sp create-for-rbac --skip-assignment --name http://${SASUID} --query password --output tsv)
#SP_APPID=$(az ad sp show --id http://${SASUID} --query appId --output tsv)
# Give the "Contributor" role to your Azure SP
# You only have to do it once !
#az role assignment create --assignee $SP_APPID --role Contributor
#az account list --query "[?name=='${ACCOUNT}'].{name:name}"

# Clone the Git project and extract the payloads tarball (Open LDAP and sitedefault.yaml, license and useful deployment artifacts)
rm -Rf  ~/viya && rm -Rf  ~/clouddrive/payload && rm -Rf ~/clouddrive/ops && rm -Rf ~/clouddrive/project && mkdir -p ~/clouddrive
git clone https://github.com/porped76/viya.git
cp ~/viya/viyacd/payload*.tgz ~/clouddrive/payload.tgz
cd ~/clouddrive && tar -zxf payload.tgz && rm -f payload.tgz

```

```bash
###
# If you want that this deployment script work at the first run, I encourage you to don't edit any line below this one, unless you
# know what you are doing ;-)
###

# Stayin on the Terraform 13.1 version as the required version
TFVERS=0.13.1
echo "[INFO] installing terraform $TFVERS..."
mkdir -p ~/bin
cd ~/bin
rm -Rf ~/bin/terraform
curl -o terraform.zip -s https://releases.hashicorp.com/terraform/${TFVERS}/terraform_${TFVERS}_linux_amd64.zip
unzip terraform.zip && rm -f terraform.zip
$HOME/bin/terraform version

# Create the working directory
mkdir -p ~/clouddrive/project/aks/azure-aks-4-viya-master/
cp -R ~/clouddrive/payload/aks_tf/* ~/clouddrive/project/aks/azure-aks-4-viya-master/

# Export the Terraform needed variables to a centralized file
export SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
export SP_PASSWD=$(az ad sp create-for-rbac --skip-assignment --name http://${SASUID} --query password --output tsv)
export SP_APPID=$(az ad sp show --id http://${SASUID} --query appId --output tsv)
export ARM_SUBSCRIPTION_ID=$(az account list --query "[?name=='${ACCOUNT}'].{id:id}" -o tsv)
export ARM_TENANT_ID=$(az account list --query "[?name=='${ACCOUNT}'].{tenantId:tenantId}" -o tsv)
export ARM_CLIENT_ID=${SP_APPID}
export ARM_CLIENT_SECRET=${SP_PASSWD}
export TF_VAR_client_id=${SP_APPID}
export TF_VAR_client_secret=${SP_PASSWD}

printf "
SASUID                -->   ${SASUID}
SP_PASSWD             -->   ${SP_PASSWD}
SP_APPID              -->   ${SP_APPID}
ARM_SUBSCRIPTION_ID   -->   ${ARM_SUBSCRIPTION_ID}
ARM_TENANT_ID         -->   ${ARM_TENANT_ID}
ARM_CLIENT_ID         -->   ${ARM_CLIENT_ID}
ARM_CLIENT_SECRET     -->   ${ARM_CLIENT_SECRET}
TF_VAR_client_id      -->   ${TF_VAR_client_id}
TF_VAR_client_secret  -->   ${TF_VAR_client_secret}\n"

# Initialize Terraform
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
$HOME/bin/terraform init

# Ensure that there is a .ssh dir in $HOME
ansible localhost -m file -a "path=$HOME/.ssh mode=0700 state=directory"

# Ensure that there is an ssh key that we can use
ansible localhost -m openssh_keypair -a "path=~/.ssh/id_rsa type=rsa size=2048" --diff

# Populate the TF variables file
cd ~/clouddrive/project/aks/azure-aks-4-viya-master

# Add the cloudbox IP to the authorized public access point and save TF_VARS to a centralized file
tee  ~/clouddrive/project/aks/azure-aks-4-viya-master/gel-vars.tfvars > /dev/null << EOF
prefix         = "${PERFIX}-k8s"
location       = "${LOC}"
ssh_public_key = "~/.ssh/id_rsa.pub"

# Define AKS version
kubernetes_version                   = "1.18.8"

# Define AKS end point public accesses CIDRS to Marlow, Cary and Azure Cloud Shell
cluster_endpoint_public_access_cidrs = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$CLOUDBOXIP/32"]

# No jump host machine is required
create_jump_public_ip = false

# No nfs server
storage_type = "dev"

# Define node pools of the AKS compute resources
# Default (system) nodepool
default_nodepool_node_count          = 1
default_nodepool_vm_type             = "Standard_D5_v2"

tags                                 = { "project_name" = "sasviya", "environment" = "sasviya-prod" }
# add anything else

# CAS nodepool
create_cas_nodepool       = true
cas_nodepool_node_count   = 1
cas_nodepool_min_nodes    = 1
cas_nodepool_auto_scaling = true
cas_nodepool_vm_type      = "Standard_E4s_v3"

# Compute nodepool
create_compute_nodepool       = true
compute_nodepool_node_count   = 1
compute_nodepool_min_nodes    = 1
compute_nodepool_auto_scaling = true
compute_nodepool_vm_type      = "Standard_E4s_v3"

# CAS Stateless nodepool
create_stateless_nodepool       = true
stateless_nodepool_node_count   = 1
stateless_nodepool_min_nodes    = 1
stateless_nodepool_auto_scaling = true
stateless_nodepool_vm_type      = "Standard_D4s_v3"

# CAS Stateful nodepool
create_stateful_nodepool       = true
stateful_nodepool_node_count   = 1
stateful_nodepool_min_nodes    = 1
# increasing default max nodes to support viya-monitoring tools
stateful_nodepool_max_nodes    = 5
stateful_nodepool_auto_scaling = true
stateful_nodepool_vm_type      = "Standard_D8s_v3"

# No need for a connect node_pool
create_connect_nodepool = false

# Azure Postgres values configuration
create_postgres                  = true
postgres_administrator_password  = "LNX_sas_123"
postgres_ssl_enforcement_enabled = false
postgres_firewall_rules          = [{ "name" = "AzureServices", "start_ip" = "0.0.0.0", "end_ip" = "0.0.0.0" },
{ "name" = "VnetAccess", "start_ip" = "192.168.1.0", "end_ip" = "192.168.2.255" }]

# Azure Container Registry (ACR) that can be defined to use external orders and pull images from SAS Hosted registries
create_container_registry           = false
container_registry_sku              = "Standard"
container_registry_admin_enabled    = "false"
container_registry_geo_replica_locs = null
EOF

# Generate the Terraform plan corresponding to the AKS cluster with multiple node pools
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
$HOME/bin/terraform plan -input=false \
    -var-file=./gel-vars.tfvars \
    -out ./my-aks.plan

# Deploy the AKS cluster and PostgreSQL with the Terraform plan. It will take [~10] minutes
TFPLAN=my-aks.plan
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
time $HOME/bin/terraform apply "./${TFPLAN}"

# Generate the configuration file
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
mkdir -p ~/.kube
$HOME/bin/terraform output kube_config > ~/.kube/${PERFIX}-aks-kubeconfig.conf
az aks get-credentials --resource-group ${PERFIX}-k8s-rg --name ${PERFIX}-k8s-aks --overwrite-existing

# Disable the authorized IP range for the Kubernetes API
az aks update -n ${PERFIX}-k8s-aks -g ${PERFIX}-k8s-rg --api-server-authorized-ip-ranges ""

# Configure kubectl auto-completion
source <(kubectl completion bash)
ansible localhost \
    -m lineinfile \
    -a "dest=~/.bashrc \
        line='source <(kubectl completion bash)' \
        state=present" \
    --diff

```

Move to the next step and [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
