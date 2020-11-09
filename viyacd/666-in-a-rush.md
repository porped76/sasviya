viyacd/666-in-a-rush.md

```bash
ACCOUNT=SESA
LOC=eastus
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
PERFIX=$SASUID
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PERFIX' line='export PERFIX=$PERFIX'" --diff
NS=sasviya-prod
CLOUDBOXIP=$(curl ifconfig.me)
KUBECONFIG=~/.kube/${PERFIX}-aks-kubeconfig.conf
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export KUBECONFIG' line='export KUBECONFIG=$KUBECONFIG'" --diff
ansible localhost -m lineinfile -a "dest=~/.bashrc regexp='^export PATH' line='export PATH=$PATH:$HOME/bin'" --diff
az configure --defaults location="${ACCOUNT}"
az account set -s "${ACCOUNT}"
rm -Rf  ~/viya && rm -Rf  ~/clouddrive/payload && rm -Rf ~/clouddrive/ops && rm -Rf ~/clouddrive/project && rm -Rf ~/viya && mkdir -p ~/clouddrive
git clone https://github.com/porped76/viya.git
cp ~/viya/viyacd/payload*.tgz ~/clouddrive/payload.tgz
cd ~/clouddrive && tar -zxf payload.tgz && rm -f payload.tgz
TFVERS=0.13.3
echo "[INFO] installing terraform $TFVERS..."
mkdir -p ~/bin
cd ~/bin
rm -Rf ~/bin/terraform
curl -o terraform.zip -s https://releases.hashicorp.com/terraform/${TFVERS}/terraform_${TFVERS}_linux_amd64.zip
unzip terraform.zip && rm -f terraform.zip
$HOME/bin/terraform version
mkdir -p ~/clouddrive/project/aks/azure-aks-4-viya-master/
cp -R ~/clouddrive/payload/aks_tf/* ~/clouddrive/project/aks/azure-aks-4-viya-master/
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
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
$HOME/bin/terraform init
ansible localhost -m file -a "path=$HOME/.ssh mode=0700 state=directory"
ansible localhost -m openssh_keypair -a "path=~/.ssh/id_rsa type=rsa size=2048" --diff
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
tee  ~/clouddrive/project/aks/azure-aks-4-viya-master/gel-vars.tfvars > /dev/null << EOF
prefix         = "${PERFIX}-k8s"
location       = "${LOC}"
ssh_public_key = "~/.ssh/id_rsa.pub"
kubernetes_version                   = "1.18.6"
cluster_endpoint_public_access_cidrs = ["109.232.56.224/27", "149.173.0.0/16", "194.206.69.176/28", "$CLOUDBOXIP/32"]
create_jump_public_ip = false
storage_type = "dev"
default_nodepool_node_count          = 1
default_nodepool_vm_type             = "Standard_D5_v2"
tags                                 = { "project_name" = "sasviya", "environment" = "sasviya-prod" }
create_cas_nodepool       = true
cas_nodepool_node_count   = 1
cas_nodepool_min_nodes    = 1
cas_nodepool_auto_scaling = true
cas_nodepool_vm_type      = "Standard_E4s_v3"
create_compute_nodepool       = true
compute_nodepool_node_count   = 1
compute_nodepool_min_nodes    = 1
compute_nodepool_auto_scaling = true
compute_nodepool_vm_type      = "Standard_E4s_v3"
create_stateless_nodepool       = true
stateless_nodepool_node_count   = 1
stateless_nodepool_min_nodes    = 1
stateless_nodepool_auto_scaling = true
stateless_nodepool_vm_type      = "Standard_D4s_v3"
create_stateful_nodepool       = true
stateful_nodepool_node_count   = 1
stateful_nodepool_min_nodes    = 1
stateful_nodepool_max_nodes    = 5
stateful_nodepool_auto_scaling = true
stateful_nodepool_vm_type      = "Standard_D8s_v3"
create_connect_nodepool = false
create_postgres                  = true
postgres_administrator_password  = "LNX_sas_123"
postgres_ssl_enforcement_enabled = false
postgres_firewall_rules          = [{ "name" = "AzureServices", "start_ip" = "0.0.0.0", "end_ip" = "0.0.0.0" },
{ "name" = "VnetAccess", "start_ip" = "192.168.1.0", "end_ip" = "192.168.2.255" }]
create_container_registry           = false
container_registry_sku              = "Standard"
container_registry_admin_enabled    = "false"
container_registry_geo_replica_locs = null
EOF
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
$HOME/bin/terraform plan -input=false \
    -var-file=./gel-vars.tfvars \
    -out ./my-aks.plan
TFPLAN=my-aks.plan
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
time $HOME/bin/terraform apply "./${TFPLAN}"
cd ~/clouddrive/project/aks/azure-aks-4-viya-master
mkdir -p ~/.kube
$HOME/bin/terraform output kube_config > ~/.kube/${PERFIX}-aks-kubeconfig.conf
az aks get-credentials --resource-group ${PERFIX}-k8s-rg --name ${PERFIX}-k8s-aks --overwrite-existing
az aks update -n ${PERFIX}-k8s-aks -g ${PERFIX}-k8s-rg --api-server-authorized-ip-ranges ""
source <(kubectl completion bash)
ansible localhost \
    -m lineinfile \
    -a "dest=~/.bashrc \
        line='source <(kubectl completion bash)' \
        state=present" \
    --diff
mkdir -p ~/clouddrive/project/deploy/$NS
cat > ~/clouddrive/project/deploy/$NS/${NS}_namespace.yaml << EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: $NS
  labels:
    name: "$NS"
    owner: "sas.com"
EOF
if kubectl get ns | grep -q "$NS"
then
    echo "Namespace ${NS} already exists"
else
    echo "Creating Namespace ${NS}"
    kubectl apply -f ~/clouddrive/project/deploy/$NS/${NS}_namespace.yaml
fi
kubectl config set-context --current --namespace=$NS
cp ~/clouddrive/payload/nginx/mandatory.yaml ~/clouddrive/project/deploy/$NS
cp ~/clouddrive/payload/nginx/cloud-generic.yaml ~/clouddrive/project/deploy/$NS
cat > /tmp/insertAuthorizeIPs.yml << EOF
---
- hosts: localhost
  tasks:
  - name: Insert Auth IP block in ingress definition
    blockinfile:
      path: ~/clouddrive/project/deploy/$NS/cloud-generic.yaml
      insertafter: "spec:"
      block: |2
          loadBalancerSourceRanges:
          - 10.244.0.0/16 #Pod CIDR
          - 109.232.56.224/27 #Marlow
          - 149.173.0.0/16 #Cary
          - $CLOUDBOXIP/32 #cloudbox IP
EOF
ansible-playbook /tmp/insertAuthorizeIPs.yml --diff
ansible localhost -m lineinfile -a "dest=~/clouddrive/project/deploy/$NS/cloud-generic.yaml state='absent' line='# BEGIN ANSIBLE MANAGED BLOCK'"
ansible localhost -m lineinfile -a "dest=~/clouddrive/project/deploy/$NS/cloud-generic.yaml state='absent' line='# END ANSIBLE MANAGED BLOCK'"
kubectl apply -f ~/clouddrive/project/deploy/$NS/mandatory.yaml
kubectl apply -f ~/clouddrive/project/deploy/$NS/cloud-generic.yaml
kubectl get svc -n ingress-nginx
cp -n ~/clouddrive/payload/kustomize/kustomize ~/bin
$HOME/bin/kustomize version
cp -R ~/clouddrive/payload/gelldap ~/clouddrive/project/
cd ~/clouddrive/project/gelldap/
kustomize build ./no_TLS/ | kubectl -n $NS apply -f -
sleep 30
kubectl -n $NS get all,cm -l app.kubernetes.io/part-of=gelldap
cd ~/clouddrive/project/deploy/$NS
cat << 'EOF' > StorageClass-RWX.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: sas-azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1001
  - gid=1001
parameters:
  skuName: Standard_LRS
allowVolumeExpansion: true
EOF
kubectl apply -f StorageClass-RWX.yaml
cp ~/clouddrive/payload/gel_OKViya4/gel_OKViya4.sh* ~/clouddrive/project/deploy/$NS
VERSION=3.4.0
BINARY=yq_linux_386
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O $HOME/bin/yq &&\
    chmod +x $HOME/bin/yq
$HOME/bin/yq --version
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.12.0
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
ORDER=9CDZDD
CADENCE_VERSION=2020.0.6
ORDER_FILE=$(ls -t ~/clouddrive/payload/orders | grep ${ORDER} | grep ${CADENCE_VERSION} | head -n 1)
echo $ORDER_FILE
cp ~/clouddrive/payload/orders/${ORDER_FILE} ~/clouddrive/project/deploy/$NS
cd ~/clouddrive/project/deploy/$NS
rm -Rf sas-bases
tar xvf $ORDER_FILE && rm -f $ORDER_FILE
mkdir -p ~/clouddrive/project/deploy/$NS/site-config/ && cd ~/clouddrive/project/deploy/$NS
cp ~/clouddrive/project/gelldap/no_TLS/gelldap-sitedefault.yaml ~/clouddrive/project/deploy/$NS/site-config/
mkdir -p ~/clouddrive/project/deploy/$NS/site-config/patches
cat > ~/clouddrive/project/deploy/$NS/site-config/patches/storage-class.yaml <<-EOF
kind: PersistentStorageClass
metadata:
  name: wildcard
spec:
  storageClassName: sas-azurefile
EOF
PublicIPId=$(az network lb show -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOC} \
-n kubernetes --query "frontendIpConfigurations[].publicIpAddress.id" --out table |grep kubernetes)
echo $PublicIPId
az network public-ip update -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOC} \
--ids $PublicIPId --dns-name ${PERFIX}-k8s
INGRESS_SUFFIX=${PERFIX}-k8s.${LOC}.cloudapp.azure.com
cat > ~/clouddrive/project/deploy/$NS/kustomization.yaml <<-EOF
---
namespace: $NS
resources:
  - sas-bases/base
  - sas-bases/overlays/network/ingress
  - sas-bases/overlays/cas-mpp
transformers:
  - sas-bases/overlays/required/transformers.yaml
  - sas-bases/overlays/external-postgres/external-postgres-transformer.yaml

patches:
- path: site-config/patches/storage-class.yaml
  target:
    kind: PersistentVolumeClaim
    annotationSelector: sas.com/component-name in (sas-cas-operator,sas-backup-job,sas-event-stream-processing-studio-app,sas-reference-data-deploy-utilities,sas-data-quality-services,sas-model-publish)

configMapGenerator:
  - name: ingress-input
    behavior: merge
    literals:
      - INGRESS_HOST=${INGRESS_SUFFIX}

  - name: sas-shared-config
    behavior: merge
    literals:
      - CASCFG_SERVICESBASEURL=http://${INGRESS_SUFFIX}
      - SERVICES_BASE_URL=http://${INGRESS_SUFFIX}
      - SAS_SERVICES_URL=http://${INGRESS_SUFFIX}
      - SAS_URL_SERVICE_TEMPLATE=http://@k8s.service.name@

  - name: sas-consul-config
    behavior: merge
    files:
      - SITEDEFAULT_CONF=site-config/gelldap-sitedefault.yaml

  - name: sas-postgres-config
    behavior: merge
    literals:
      - DATABASE_HOST=${PERFIX}-k8s-pgsql.postgres.database.azure.com
      - DATABASE_PORT=5432
      - DATABASE_SSL_ENABLED="false"
      - DATABASE_NAME=SharedServices
      - EXTERNAL_DATABASE="true"
      - SAS_DATABASE_DATABASESERVERNAME="postgres"
      - SPRING_DATASOURCE_URL=jdbc:postgresql://${PERFIX}-k8s-pgsql.postgres.database.azure.com:5432/SharedServices?currentSchema=\${application.schema}

secretGenerator:
  - name: postgres-sas-user
    literals:
      - username=pgadmin@${PERFIX}-k8s-pgsql
      - password=LNX_sas_123
EOF
cd ~/clouddrive/project/deploy/$NS
kustomize build -o site.yaml
sleep 15
kubectl apply -n ${NS} --selector="sas.com/admin=cluster-wide" -f site.yaml --prune
kubectl -n ${NS} wait --for condition=established --timeout=60s -l "sas.com/admin=cluster-wide" crd
kubectl apply -n ${NS} --selector="sas.com/admin=cluster-local" -f site.yaml --prune
kubectl apply -n ${NS} --selector="sas.com/admin=namespace" -f site.yaml --prune
sleep 2700
mkdir -p ~/clouddrive/ops/azure-deployment/monitoring
export WORKING_DIR=~/clouddrive/ops/azure-deployment
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/monitoring $WORKING_DIR
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user.env $WORKING_DIR/monitoring
INGRESS_SUFFIX=${PERFIX}-k8s.${LOC}.cloudapp.azure.com
cat >  $WORKING_DIR/monitoring/user-values-prom-operator.yaml << EOF
kubelet:
    serviceMonitor:
        https: true

prometheus:
    service:
        type: ClusterIP
        nodePort: null
    ingress:
        enabled: true
        annotations:
            kubernetes.io/ingress.class: nginx
        hosts:
        - ${INGRESS_SUFFIX}
        paths:
        - /prometheus
    prometheusSpec:
        routePrefix: /prometheus
        externalUrl: http://${INGRESS_SUFFIX}/prometheus

alertmanager:
    service:
        type: ClusterIP
        nodePort: null
    ingress:
        enabled: true
        annotations:
            kubernetes.io/ingress.class: nginx
        hosts:
        - ${INGRESS_SUFFIX}
        paths:
        - /alertmanager
    alertmanagerSpec:
        routePrefix: /alertmanager
        externalUrl: http://${INGRESS_SUFFIX}/alertmanager

grafana:
    "grafana.ini":
        server:
            protocol: http
            domain: ${INGRESS_SUFFIX}
            root_url: http://${INGRESS_SUFFIX}/grafana
            serve_from_sub_path: true
    service:
        type: ClusterIP
        nodePort: null
    ingress:
        enabled: true
        hosts:
        - ${INGRESS_SUFFIX}
        path: /grafana
    testFramework:
        enabled: false
EOF
~/clouddrive/payload/ops4viya/monitoring/bin/deploy_monitoring_cluster.sh
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user-values-pushgateway.yaml $WORKING_DIR/monitoring
echo "tolerations:" > $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "  - effect: NoSchedule" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    key: workload.sas.com/class" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    value: stateful" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
VIYA_NS=$NS ~/clouddrive/payload/ops4viya/monitoring/bin/deploy_monitoring_viya.sh
kubectl create configmap kube-proxy --from-literal=metricsBindAddress=0.0.0.0:10249 -n kube-system
kubectl delete po -n kube-system -l component=kube-proxy
mkdir -p ~/clouddrive/ops/azure-deployment/logging
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/logging $WORKING_DIR
cp ~/clouddrive/payload/viya4-monitoring/logging/user.env $WORKING_DIR/logging
echo "ES_KIBANASERVER_PASSWD=\"lnxsas\"" > $WORKING_DIR/logging/user.env
echo "ES_LOGCOLLECTOR_PASSWD=\"lnxsas\"" >> $WORKING_DIR/logging/user.env
echo "ES_METRICGETTER_PASSWD=\"lnxsas\"" >> $WORKING_DIR/logging/user.env
cat > $WORKING_DIR/logging/user-values-elasticsearch-open.yaml << EOF
kibana:
    extraEnvs:
    - name: SERVER_BASEPATH
      value: /kibana
    - name: ELASTICSEARCH_USERNAME
      value: admin
    - name: ELASTICSEARCH_PASSWORD
      value: admin

    service:
        type: ClusterIP
        nodePort: null

    ingress:
        annotations:
            kubernetes.io/ingress.class: nginx
            nginx.ingress.kubernetes.io/affinity: "cookie"
            nginx.ingress.kubernetes.io/ssl-redirect: "false"
            nginx.ingress.kubernetes.io/configuration-snippet: |
                rewrite (?i)/kibana/(.*) /\$1 break;
                rewrite (?i)/kibana$ / break;
            nginx.ingress.kubernetes.io/rewrite-target: /kibana
        enabled: true
        hosts:
        - ${INGRESS_SUFFIX}/kibana
EOF
sleep 30 && ~/clouddrive/payload/ops4viya/logging/bin/deploy_logging_open.sh
echo
echo "Open SAS Viya Applications at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/"
echo "Open Grafana at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/grafana"
echo "Open Prometheus at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/prometheus"
echo "Open AlertManager at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/alertmanager"
echo "Open Kibana at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/kibana"
```
