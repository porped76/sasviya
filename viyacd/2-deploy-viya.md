## Outline

There are three sections in this project:

- [Deploy the infrastructure, namelly Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL](./1-deploy-aks-postgresql.md)
- *YOU ARE HERE =>* [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
- [Deploy Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)

## Move with the following steps to deploy SAS Viya on top of AKS:

```bash
# Create a namespace folder
mkdir -p ~/clouddrive/project/deploy/$NS

# Create the namespace through a manifest and then aplly it
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

# Set the created $NS as default
kubectl config set-context --current --namespace=$NS

# Copy the Ingress deployment manifests from the payload directory
cp ~/clouddrive/payload/nginx/mandatory.yaml ~/clouddrive/project/deploy/$NS
cp ~/clouddrive/payload/nginx/cloud-generic.yaml ~/clouddrive/project/deploy/$NS

# Use ansible to update the Ingress deployment with the authorized IP ranges
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

# Apply
ansible-playbook /tmp/insertAuthorizeIPs.yml --diff
ansible localhost -m lineinfile -a "dest=~/clouddrive/project/deploy/$NS/cloud-generic.yaml state='absent' line='# BEGIN ANSIBLE MANAGED BLOCK'"
ansible localhost -m lineinfile -a "dest=~/clouddrive/project/deploy/$NS/cloud-generic.yaml state='absent' line='# END ANSIBLE MANAGED BLOCK'"

# Deploy and configure the Ingress controller (ngnix)
kubectl apply -f ~/clouddrive/project/deploy/$NS/mandatory.yaml
kubectl apply -f ~/clouddrive/project/deploy/$NS/cloud-generic.yaml

# Check it
kubectl get svc -n ingress-nginx

# Copy the kustomize tool and save the the PATH info for the next you login and check Kustomize
cp -n ~/clouddrive/payload/kustomize/kustomize ~/bin
$HOME/bin/kustomize version

# Copy the gelldap deployment artifacts
cp -R ~/clouddrive/payload/gelldap ~/clouddrive/project/

# Deploy GELLDAP into the $NS namespace
cd ~/clouddrive/project/gelldap/
kustomize build ./no_TLS/ | kubectl -n $NS apply -f -

# Confirm that the gelldap pod is running
kubectl -n $NS get all,cm -l app.kubernetes.io/part-of=gelldap

# Create custom StorageClass to support RWX
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

# Create the storage class
kubectl apply -f StorageClass-RWX.yaml

# Copy the OKViya script from the payload directory
cp ~/clouddrive/payload/gel_OKViya4/gel_OKViya4.sh* ~/clouddrive/project/deploy/$NS

# Install yq
VERSION=3.4.0
BINARY=yq_linux_386
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O $HOME/bin/yq &&\
    chmod +x $HOME/bin/yq
$HOME/bin/yq --version

# Install cert-manager through Helm
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.12.0

# Install Metrics server (for HPA: Horizontal Pod Autoscaler)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

# Set the order and copy the deployment assets from the payload archive to the deploy $NS directory
ORDER=9CDZDD
CADENCE_VERSION=2020.0.6
ORDER_FILE=$(ls -t ~/clouddrive/payload/orders | grep ${ORDER} | grep ${CADENCE_VERSION} | head -n 1)
echo $ORDER_FILE
cp ~/clouddrive/payload/orders/${ORDER_FILE} ~/clouddrive/project/deploy/$NS
cd ~/clouddrive/project/deploy/$NS
rm -Rf sas-bases
tar xvf $ORDER_FILE && rm -f $ORDER_FILE

# Create a site-config directory
mkdir -p ~/clouddrive/project/deploy/$NS/site-config/ && cd ~/clouddrive/project/deploy/$NS

# Copy the gelldap sitedefault.yaml with the LDAP configurations to the site-default directory
cp ~/clouddrive/project/gelldap/no_TLS/gelldap-sitedefault.yaml ~/clouddrive/project/deploy/$NS/site-config/

# Create the patches directory with the custom storage class to support RWX access for components that needs it (CAS, backup manager, etc...) and to use an external Azure PG
mkdir -p ~/clouddrive/project/deploy/$NS/site-config/patches
cat > ~/clouddrive/project/deploy/$NS/site-config/patches/storage-class.yaml <<-EOF
kind: PersistentStorageClass
metadata:
  name: wildcard
spec:
  storageClassName: sas-azurefile #local-nfs
EOF

# Get the Load Balancer Public IP ID (as defined in the Azure Cloud)
PublicIPId=$(az network lb show -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOC} \
-n kubernetes --query "frontendIpConfigurations[].publicIpAddress.id" --out table |grep kubernetes)
echo $PublicIPId

# Use the ID to associate a DNS alias
az network public-ip update -g MC_${PERFIX}-k8s-rg_${PERFIX}-k8s-aks_${LOC} \
--ids $PublicIPId --dns-name ${PERFIX}-k8s

# Create the kustomization.yaml file with the external PostgreSQL DB configuration and the reference to the storage class path
INGRESS_SUFFIX=${PERFIX}-k8s.${LOC}.cloudapp.azure.com
cat > ~/clouddrive/project/deploy/$NS/kustomization.yaml <<-EOF
---
namespace: $NS
resources:
  - sas-bases/base
  - sas-bases/overlays/network/ingress
#  - sas-bases/overlays/internal-postgres
#  - sas-bases/overlays/crunchydata
  - sas-bases/overlays/cas-mpp
transformers:
  - sas-bases/overlays/required/transformers.yaml
#  - sas-bases/overlays/internal-postgres/internal-postgres-transformer.yaml
  - sas-bases/overlays/external-postgres/external-postgres-transformer.yaml

# Set a custom Storage Class for PersistentVolumeClaims, as it's not currently possible to change the default SC in AKS
# A new SC is required to support ReadWriteMany access. Note that annotationSelector is how to limit which PV use azurefiles/RWX versus default RWO
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

  - name: sas-consul-config            ## This injects content into consul. You can add, but not replace
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

# Build the manifest files with Kustomize
cd ~/clouddrive/project/deploy/$NS
kustomize build -o site.yaml

# Start SAS Viya deployment. It will take [~45] minutes
# Apply the "cluster-wide" configuration
# The kubectl apply command might cause a message in the following format to be displayed:
# unable to recognize "site.yaml": no matches for kind "foo" in version "bar"
# If this message is displayed, it can safely be ignored
kubectl apply -n ${NS} --selector="sas.com/admin=cluster-wide" -f site.yaml --prune
# Wait for custom resource deployment to be deployed
kubectl -n ${NS} wait --for condition=established --timeout=60s -l "sas.com/admin=cluster-wide" crd
# Apply the "cluster-local" configuration and delete all the other "cluster local" resources that are not in the file (essentially config maps)
kubectl apply -n ${NS} --selector="sas.com/admin=cluster-local" -f site.yaml --prune
# Apply the configuration that matches label "sas.com/admin=namespace" and delete all the other resources that are not in the file and match label "sas.com/admin=namespace"
kubectl apply -n ${NS} --selector="sas.com/admin=namespace" -f site.yaml --prune

# Simple way to Monitor the Viya deployment
watch kubectl get pods -o wide -n $NS

# Advanced way to Monitor the Viya deployment. Force the $NS and the $PERFIX variables
#SessName=deploy_watch
#tmux new -s $SessName -d
#tmux send-keys -t $SessName "NS=$NS && PERFIX=$PERFIX && export KUBECONFIG=~/.kube/${PERFIX}-aks-kubeconfig.conf &&\
#time ~/clouddrive/project/deploy/$NS/gel_OKViya4.sh -n $NS --wait --pod-status"  C-m
#tmux split-window -v -t $SessName
#tmux send-keys -t $SessName "NS=$NS && PERFIX=$PERFIX && export KUBECONFIG=~/.kube/${PERFIX}-aks-kubeconfig.conf &&\
#watch 'kubectl get pods -o wide -n $NS | grep 0/ | grep -v Completed '"  C-m
#tmux attach -t $SessName

# Make sure that you are using the Cary Direct VPN (profile 3 usually) and then connect to SAS Viya applications
# The GEL Open LDAP is deployed as a container and the passwords of the users are "lnxsas". The "sasadm" is an unrestricted administrator
echo "Open SAS Viya Applications at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/"

# Optional: Delete the namespace
# kubectl delete ns $NS
```

Move to the next step and [Deploy Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)