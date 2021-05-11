# 1-deploy-aks-postgresql.md
ACCOUNT=SESA
LOCATION=eastus
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
SASEMAIL=$(az ad signed-in-user show --query userPrincipalName | sed  's|["\ ]||g')
PERFIX=$SASUID
ansible localhost -m lineinfile -a "dest=~/.profile regexp='^export PERFIX' line='export PERFIX=$SASUID'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PERFIX' line='export PERFIX=$SASUID'" --diff
NS=sasviya-prod
ansible localhost -m lineinfile -a "dest=~/.profile regexp='^export NS' line='export NS=$NS'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export NS' line='export NS=$NS'" --diff
GRAFANA_PASSWORD=Password123
KIBANA_PASSWORD=Password123
BASTIONIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
TFVERS=0.13.6
K8SVER=1.18.14
KUSTOMIZEVER=3.7.0
YQVER=jq-1.6
YQBIN=jq-linux64
KUBECONFIG=~/.kube/config
ansible localhost -m lineinfile -a "dest=~/.profile regexp='^export KUBECONFIG' line='export KUBECONFIG=$KUBECONFIG'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export KUBECONFIG' line='export KUBECONFIG=$KUBECONFIG'" --diff
ansible localhost -m lineinfile -a "dest=~/.profile regexp='^export PATH' line='export PATH=$HOME/bin:$PATH'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PATH' line='export PATH=$HOME/bin:$PATH'" --diff
ansible localhost -m lineinfile -a "dest=~/.profile line='source <(kubectl completion bash)'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc line='source <(kubectl completion bash)'" --diff
source ~/.profile
az configure --defaults location="${LOCATION}"
az account set -s "${ACCOUNT}"
echo "[INFO] installing terraform $TFVERS..."
mkdir -p ~/bin
cd ~/bin
rm -Rf ~/bin/terraform
curl -o terraform.zip -s https://releases.hashicorp.com/terraform/${TFVERS}/terraform_${TFVERS}_linux_amd64.zip
unzip terraform.zip && rm -f terraform.zip
~/bin/terraform version
mkdir -p ~/clouddrive/project/${NS}
TFCREDFILE=~/clouddrive/project/${NS}/TF_CLIENT_CREDS
if [ -f "$TFCREDFILE" ]; then
    echo "Using the existing Terraform credentials file"
    cd ~/clouddrive/project/${NS} && ./TF_CLIENT_CREDS
else
    echo "No existing Terraform credentials file... Get required variables for Terraform credentials file"
    TF_VAR_subscription_id=$(az account list --query "[?name=='${ACCOUNT}'].{id:id}" -o tsv)
    TF_VAR_tenant_id=$(az account list --query "[?name=='${ACCOUNT}'].{tenantId:tenantId}" -o tsv)
    TF_VAR_client_secret=$(az ad sp create-for-rbac --skip-assignment --name http://${SASUID} --query password --output tsv)
    TF_VAR_client_id=$(az ad sp show --id http://${SASUID} --query appId --output tsv)
    echo "export TF_VAR_subscription_id=${TF_VAR_subscription_id}" > $TFCREDFILE
    echo "export TF_VAR_tenant_id=${TF_VAR_tenant_id}" >> $TFCREDFILE
    echo "export TF_VAR_client_id=${TF_VAR_client_id}" >> $TFCREDFILE
    echo "export TF_VAR_client_secret=${TF_VAR_client_secret}" >> $TFCREDFILE
    chmod u+x $TFCREDFILE && cd ~/clouddrive/project/${NS} && ./TF_CLIENT_CREDS
    ansible localhost -m lineinfile -a "dest=~/.profile line='source ~/clouddrive/project/${NS}/TF_CLIENT_CREDS'" --diff
fi
ansible localhost -m file -a "path=~/.ssh mode=0700 state=directory"
ansible localhost -m openssh_keypair -a "path=~/.ssh/id_rsa type=rsa size=2048" --diff
cd ~/clouddrive/project/${NS} && git clone https://github.com/sassoftware/viya4-iac-azure.git
cd ~/clouddrive/project/${NS}/viya4-iac-azure && git fetch --all && IAC_AZURE_TAG=latest
~/bin/terraform init

tee ~/clouddrive/project/${NS}/viya4-iac-azure/terraform.tfvars > /dev/null << EOF
subscription_id                       = "${TF_VAR_subscription_id}"
tenant_id                             = "${TF_VAR_tenant_id}"
prefix                                = "${PERFIX}-viya"
location                              = "${LOCATION}"
ssh_public_key                        = "~/.ssh/id_rsa.pub"
tags                                  = { "project_name" = "sasviya", environment = "${NS}", "resourceowner" = "${SASEMAIL}" }
default_public_access_cidrs           = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$BASTIONIP/32"]
vnet_address_space                    = "192.168.0.0/16"

# Set to true/false the creation of the jump host
create_jump_vm                        = true
create_jump_public_ip                 = true
jump_vm_zone                          = null
jump_vm_admin                         = "jumpadmin"
jump_vm_machine_type                  = "Standard_B2s"
jump_rwx_filestore_path               = "/viya-share"
#vm_public_access_cidrs               = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$BASTIONIP/32"]

# Define storage type. "standard" creates NFS server VM and "ha" creates Azure Netapp Files
storage_type                          = "standard"
create_nfs_public_ip                  = false
nfs_vm_zone                           = null
nfs_vm_admin                          = "nfsadmin"
nfs_vm_machine_type                   = "Standard_D8s_v4"
nfs_raid_disk_size                    = 128
nfs_raid_disk_type                    = "Standard_LRS"
#nfs_raid_disk_zones                  = []

# Set to true/false the creation of Azure Container Registry
create_container_registry             = false
#container_registry_sku               = "Standard"
#container_registry_admin_enabled     = true
#container_registry_geo_replica_locs  = null
#acr_public_access_cidrs              = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$BASTIONIP/32"]

# Set to true/false the creation of Azure PostgreSQL
create_postgres                       = true
postgres_sku_name                     = "GP_Gen5_8"
postgres_storage_mb                   = 51200
postgres_server_version               = 11
postgres_db_names                     = []
postgres_backup_retention_days        = 7
postgres_geo_redundant_backup_enabled = false
postgres_administrator_login          = "pgadmin"
postgres_administrator_password       = "LNX_sas_123"
postgres_ssl_enforcement_enabled      = true
#postgres_public_access_cidrs         = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$BASTIONIP/32"]

# Set to true/false the enablement of Azure Monitor
create_aks_azure_monitor              = false
#enable_log_analytics_workspace       = true
#log_analytics_workspace_sku          = "PerGB2018"
#log_retention_in_days                = 30
#log_analytics_solution_name          = "ContainerInsights"
#log_analytics_solution_publisher     = "Microsoft"
#log_analytics_solution_product       = "OMSGallery/ContainerInsights"

# Define AKS configurations
kubernetes_version                    = "${K8SVER}"
aks_network_plugin                    = "kubenet"
aks_network_policy                    = "azure"
aks_dns_service_ip                    = "10.0.0.10"
aks_docker_bridge_cidr                = "172.17.0.1/16"
aks_outbound_type                     = "loadBalancer"
aks_pod_cidr                          = "10.244.0.0/16"
aks_service_cidr                      = "10.0.0.0/16"
node_vm_admin                         = "nodeadmin"
#cluster_endpoint_public_access_cidrs = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$BASTIONIP/32"]

# Define node pools proximity placement and number of availability zones
node_pools_availability_zone          = "1"
node_pools_proximity_placement        = false

# Default (system) nodepool
default_nodepool_vm_type              = "Standard_D8s_v4"
default_nodepool_os_disk_size         = 128
default_nodepool_min_nodes            = 1
default_nodepool_max_nodes            = 2
default_nodepool_availability_zones   = ["1"]

# Define user node pools configurations
node_pools = {
# CAS nodepool
  cas = {
    "machine_type" = "Standard_E8ds_v4"
    "os_disk_size" = 200
    "min_nodes"    = 1
    "max_nodes"    = 5
    "max_pods"     = 110
    "node_taints"  = ["workload.sas.com/class=cas:NoSchedule"]
    "node_labels"  = {
      "workload.sas.com/class" = "cas"
    }
  },
# Compute nodepool
  compute = {
    "machine_type" = "Standard_E2ds_v4"
    "os_disk_size" = 200
    "min_nodes"    = 1
    "max_nodes"    = 2
    "max_pods"     = 110
    "node_taints"  = ["workload.sas.com/class=compute:NoSchedule"]
    "node_labels"  = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },
# ESP nodepool
#  realtime = {
#    "machine_type" = "Standard_E8ds_v4"
#    "os_disk_size" = 200
#    "min_nodes"    = 1
#    "max_nodes"    = 2
#    "max_pods"     = 110
#    "node_taints"  = ["workload.sas.com/class=esp:NoSchedule"]
#    "node_labels"  = {
#      "workload.sas.com/class" = "esp"
#    }
#  },
# MAS nodepool
#  realtime = {
#    "machine_type" = "Standard_E8ds_v4"
#    "os_disk_size" = 200
#    "min_nodes"    = 1
#    "max_nodes"    = 2
#    "max_pods"     = 110
#    "node_taints"  = ["workload.sas.com/class=mas:NoSchedule"]
#    "node_labels"  = {
#      "workload.sas.com/class" = "mas"
#    }
#  },
# Connect nodepool
     connect = {
      "machine_type" = "Standard_E2ds_v4"
      "os_disk_size" = 200
      "min_nodes"    = 1
      "max_nodes"    = 2
      "max_pods"     = 110
      "node_taints"  = ["workload.sas.com/class=connect:NoSchedule"]
      "node_labels"  = {
        "workload.sas.com/class"        = "connect"
        "launcher.sas.com/prepullImage" = "sas-programming-environment"
      }
    },
# Stateless nodepool
  stateless = {
    "machine_type" = "Standard_E8ds_v4"
    "os_disk_size" = 200
    "min_nodes"    = 1
    "max_nodes"    = 2
    "max_pods"     = 110
    "node_taints"  = ["workload.sas.com/class=stateless:NoSchedule"]
    "node_labels"  = {
      "workload.sas.com/class" = "stateless"
    }
  },
# Stateful nodepool
  stateful = {
    "machine_type" = "Standard_E8ds_v4"
    "os_disk_size" = 200
    "min_nodes"    = 1
    "max_nodes"    = 3
    "max_pods"     = 110
    "node_taints"  = ["workload.sas.com/class=stateful:NoSchedule"]
    "node_labels"  = {
      "workload.sas.com/class" = "stateful"
    }
  }
}
EOF
cd ~/clouddrive/project/${NS}/viya4-iac-azure && ~/bin/terraform plan -input=false \
    -var-file=./terraform.tfvars -out ./my-aks.plan
cd ~/clouddrive/project/${NS}/viya4-iac-azure && time ~/bin/terraform apply ./my-aks.plan 2>&1 \
| tee -a ./my-aks-apply.log
mkdir -p ~/.kube && az aks get-credentials --resource-group ${PERFIX}-viya-rg --name ${PERFIX}-viya-aks \
--overwrite-existing
az aks update -n ${PERFIX}-viya-aks -g ${PERFIX}-viya-rg --api-server-authorized-ip-ranges ""

# 2-deploy-viya-prereqs.md
wget -O ~/bin/kubectl \
https://storage.googleapis.com/kubernetes-release/release/v${K8SVER}/bin/linux/amd64/kubectl && \
chmod 755 ~/bin/kubectl && kubectl version
wget -O ~/bin/install_kustomize.sh \
https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh && \
cd ~/bin && bash ./install_kustomize.sh ${KUSTOMIZEVER} && rm ./install_kustomize.sh
wget -O ~/bin/yq https://github.com/stedolan/jq/releases/download/${YQVER}/${YQBIN} && \
chmod 755 ~/bin/yq && ~/bin/yq --version
cd ~/clouddrive/project/${NS} && git clone https://github.com/sassoftware/viya4-deployment.git
cd ~/clouddrive/project/${NS}/viya4-deployment && pip3 install --user -r requirements.txt
ansible-galaxy collection install -r requirements.yaml -f

tee ~/clouddrive/project/${NS}/viya4-deployment/ansible-vars-iac.yaml > /dev/null << EOF
## Cluster
PROVIDER: azure
CLUSTER_NAME: ${PERFIX}-viya-aks
NAMESPACE: ${NS}

## MISC
DEPLOY: false # Set to false to stop at generating the manifest
LOADBALANCER_SOURCE_RANGES: ['109.232.56.224/27', '149.173.0.0/16', '194.206.69.176/28', '$BASTIONIP/32']

## Storage
V4_CFG_MANAGE_STORAGE: true
V4_CFG_STORAGECLASS: "sas"
V4_CFG_RWX_FILESTORE_PATH: '/export'
V4_CFG_RWX_FILESTORE_ASTORES_PATH: '/export/${NS}/astores'
V4_CFG_RWX_FILESTORE_BIN_PATH: '/export/${NS}/bin'
V4_CFG_RWX_FILESTORE_DATA_PATH: '/export/${NS}/data'
V4_CFG_RWX_FILESTORE_HOMES_PATH: '/export/${NS}/homes'

## SAS API Access
V4_CFG_ORDER_NUMBER: 9CJMFS # Replace by your order
V4_CFG_CADENCE_NAME: stable # Replace by your cadence
V4_CFG_CADENCE_VERSION: 2020.1.5 # Replace by your cadence version
V4_CFG_SAS_API_KEY: 'wPG4GEkT9m5fQHhl3eCg2p9OzSiDcefF' # Replace by your SAS API key from: https://apiportal.sas.com portal
V4_CFG_SAS_API_SECRET: 'GTQMAFdGY7WsiEZN' # Replace by your SAS API secret from: https://apiportal.sas.com portal

## CR Access
#V4_CFG_CR_USER: ${PERFIX}viyaacr
#V4_CFG_CR_PASSWORD: $(az acr credential show -n ${PERFIX}viyaacr --query passwords[0].value)
#V4_CFG_CR_URL: https://${PERFIX}viyaacr.azurecr.io

## Ingress
V4_CFG_INGRESS_TYPE: ingress
V4_CFG_INGRESS_FQDN: ${PERFIX}-viya.${LOCATION}.cloudapp.azure.com
V4_CFG_TLS_MODE: "full-stack" # [full-stack|front-door|disabled]

## Postgres
V4_CFG_POSTGRES_TYPE: external #[internal|external]

## LDAP
V4_CFG_EMBEDDED_LDAP_ENABLE: true

## Consul UI
V4_CFG_CONSUL_ENABLE_LOADBALANCER: false

## SAS/CONNECT
V4_CFG_CONNECT_ENABLE_LOADBALANCER: true
V4_CFG_CONNECT_FQDN: connect-${PERFIX}-viya.${LOCATION}.cloudapp.azure.com

## CAS
V4_CFG_CAS_WORKER_COUNT: 2
#V4_CFG_CAS_ENABLE_BACKUP_CONTROLLER: true
V4_CFG_CAS_ENABLE_LOADBALANCER: true
V4_CFG_CAS_FQDN: cas-${PERFIX}-viya.${LOCATION}.cloudapp.azure.com

## Monitoring and Logging
## uncomment and update the below values when deploying the tools based on path (default)
## or based on host
#V4M_NODE_PLACEMENT_ENABLE: true
#V4M_STORAGECLASS: "sas"
#V4M_BASE_DOMAIN: ${PERFIX}-viya.${LOCATION}.cloudapp.azure.com
# Monitoring
#V4M_GRAFANA_PASSWORD: ${GRAFANA_PASSWORD}
#V4M_PROMETHEUS_FQDN: prometheus.${PERFIX}-viya.${LOCATION}.cloudapp.azure.com
#V4M_GRAFANA_FQDN: grafana.${PERFIX}-viya.${LOCATION}.cloudapp.azure.com 
#V4M_ALERTMANAGER_FQDN: alertmanager.${PERFIX}-viya.${LOCATION}.cloudapp.azure.com
# Logging
#V4M_KIBANA_PASSWORD: ${KIBANA_PASSWORD}
#V4M_KIBANA_FQDN: kibana.${PERFIX}-viya.${LOCATION}.cloudapp.azure.com
#V4M_ELASTICSEARCH_FQDN: elasticsearch.${PERFIX}-viya.eastus.cloudapp.azure.com
EOF

source ~/.profile && export ANSIBLE_CONFIG=./ansible.cfg && \
mkdir ~/clouddrive/project/${NS}/viya4-deployment/customizations
time ansible-playbook \
  -e BASE_DIR=~/clouddrive/project/${NS}/viya4-deployment/customizations \
  -e KUBECONFIG=~/.kube/config \
  -e CONFIG=~/clouddrive/project/${NS}/viya4-deployment/ansible-vars-iac.yaml \
  -e TFSTATE=~/clouddrive/project/${NS}/viya4-iac-azure/terraform.tfstate \
  -e JUMP_SVR_PRIVATE_KEY=~/.ssh/id_rsa \
  ./playbooks/playbook.yaml \
  --tags "baseline,viya,install" -vvv
ls -ltr ~/clouddrive/project/${NS}/viya4-deployment/customizations/${PERFIX}-viya-aks/${NS}
JUMPIP=$(az network public-ip show -g ${PERFIX}-viya-rg -n ${PERFIX}-viya-jump-public_ip \
--query "ipAddress" --out table | tail -1)
echo $JUMPIP
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa jumpadmin@$JUMPIP "ls -ltr /viya-share/${NS}"
scp ~/.ssh/id_rsa* ~/.ssh/id_rsa jumpadmin@$JUMPIP:~/.ssh/
kubectl get deployment -n ingress-nginx && echo && kubectl get svc -n ingress-nginx
kubectl get deployment metrics-server -n kube-system && echo &&  kubectl get svc -n kube-system
kubectl get deployment cert-manager -n cert-manager && echo &&  kubectl get svc -n cert-manager
kubectl get storageclass sas
VIYAPUBLICIP=$(az network lb show -g MC_${PERFIX}-viya-rg_${PERFIX}-viya-aks_${LOCATION} -n kubernetes \
--query "frontendIpConfigurations[].publicIpAddress.id" --out table |grep kubernetes)
echo $VIYAPUBLICIP
az network public-ip update -g MC_${PERFIX}-viya-rg_${PERFIX}-viya-aks_${LOCATION} --ids $VIYAPUBLICIP \
--dns-name ${PERFIX}-viya
cd ~/clouddrive/project/${NS} && git clone https://github.com/sassoftware/viya4-ark.git
cd ~/clouddrive/project/${NS}/viya4-ark && pip3 install --user -r requirements.txt
NGINXNS="ingress-nginx"
NGINXCONT="ingress-nginx-controller"
INGRESSIP=$(kubectl -n $NGINXNS get service ${NGINXCONT} -o jsonpath='{.status.loadBalancer.ingress[*].ip}')
echo $INGRESSIP
INGRESSPORT=$(kubectl -n $NGINXNS get service ${NGINXCONT} -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
echo $INGRESSPORT
python3 viya-ark.py pre-install-report --ingress=nginx -H ${INGRESSIP} -p ${INGRESSPORT} -n default

# 3-deploy-viya.md
ansible localhost -m lineinfile -a \
    "dest=~/clouddrive/project/${NS}/viya4-deployment/ansible-vars-iac.yaml \
    regexp='DEPLOY: false # Set to false to stop at generating the manifest' \
    line='DEPLOY: true # Set to false to stop at generating the manifest' \
    state=present" \
     --diff
cd ~/clouddrive/project/${NS}/viya4-deployment && \
source ~/.profile && export ANSIBLE_CONFIG=./ansible.cfg && time ansible-playbook \
  -e BASE_DIR=~/clouddrive/project/${NS}/viya4-deployment/customizations \
  -e KUBECONFIG=~/.kube/config \
  -e CONFIG=~/clouddrive/project/${NS}/viya4-deployment/ansible-vars-iac.yaml \
  -e TFSTATE=~/clouddrive/project/${NS}/viya4-iac-azure/terraform.tfstate \
  -e JUMP_SVR_PRIVATE_KEY=~/.ssh/id_rsa \
  ./playbooks/playbook.yaml \
  --tags "viya,install" -vvv
sleep 3600
kubectl config set-context --current --namespace=${NS}
CONNECTPUBLICIP=$(az network lb show -g MC_${PERFIX}-viya-rg_${PERFIX}-viya-aks_${LOCATION} -n kubernetes \
--query "frontendIpConfigurations[].publicIpAddress.id" --out table | grep kubernetes | tail -2 | head -1)
echo $CONNECTPUBLICIP
az network public-ip update -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOCATION} --ids $CONNECTPUBLICIP \
--dns-name connect-${PERFIX}-viya
CASPUBLICIP=$(az network lb show -g MC_${PERFIX}-viya-rg_${PERFIX}-viya-aks_${LOCATION} -n kubernetes \
--query "frontendIpConfigurations[].publicIpAddress.id" --out table | grep kubernetes | tail -1)
echo $CASPUBLICIP
az network public-ip update -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOCATION} --ids $CASPUBLICIP \
--dns-name cas-${PERFIX}-viya

# 4-deploy-ops4viya.md
cd ~/clouddrive/project/${NS}/ && \
git clone --branch stable https://github.com/sassoftware/viya4-monitoring-kubernetes/ && \
cd ./viya4-monitoring-kubernetes && mkdir -p ./customizations/monitoring ./customizations/logging
cp ./samples/ingress/monitoring/user-values-prom-path.yaml \
./customizations/monitoring/user-values-prom-operator.yaml
cp ./monitoring/user-values-pushgateway.yaml ./customizations/monitoring/

tee ./customizations/monitoring/user.env > /dev/null << EOF
#NGINX_NS=${NGINXNS}
#NGINX_SVCNAME=${NGINXCONT}
MON_NS=monitoring
TLS_ENABLED=true
MON_NODE_PLACEMENT_ENABLE=true
GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
EOF

sed -i 's/host.mycluster.example.com/${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/g' \
./customizations/monitoring/user-values-prom-operator.yaml
sed -i 's/#   storageClass: myStorageClass/   storageClass: sas/g' \
./customizations/monitoring/user-values-pushgateway.yaml
cp ./samples/ingress/logging/user-values-elasticsearch-path.yaml \
./customizations/logging/user-values-elasticsearch-open.yaml

tee ./customizations/logging/user.env > /dev/null << EOF
#NGINX_NS=${NGINXNS}
#NGINX_SVCNAME=${NGINXCONT}
LOG_NS=logging
TLS_ENABLED=true
MON_NODE_PLACEMENT_ENABLE=true
ES_ADMIN_PASSWD=${KIBANA_PASSWORD}
EOF

sed -i 's/host.mycluster.example.com/${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/g' \
./customizations/logging/user-values-elasticsearch-open.yaml
export USER_DIR=~/clouddrive/project/${NS}/viya4-monitoring-kubernetes/customizations && \
./monitoring/bin/deploy_monitoring_cluster.sh && \
VIYA_NS=${NS} ./monitoring/bin/deploy_monitoring_viya.sh
export USER_DIR=~/clouddrive/project/${NS}/viya4-monitoring-kubernetes/customizations && \
./logging/bin/deploy_logging_open.sh
echo "Open SAS Viya products: https://${PERFIX}-viya.${LOCATION}.cloudapp.azure.com"
echo "Access the connect server through: connect-${PERFIX}-viya.${LOCATION}.cloudapp.azure.com:17551"
echo "Access the cas server through: cas-${PERFIX}-viya.${LOCATION}.cloudapp.azure.com:5570"
echo "Open Grafana at https://${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/grafana"
echo "Open Kibana at http://${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/kibana"
echo "Open Prometheus at https://${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/prometheus"
echo "Open AlertManager at https://${PERFIX}-viya.${LOCATION}.cloudapp.azure.com/alertManager"
