## Outline

There are three sections in this project:

- [Deploy the infrastructure, namelly Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL](./1-deploy-aks-postgresql.md)
- [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
- *YOU ARE HERE =>* [Deploy Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)

## Deploy Ops4Viya monitoring tools:

```bash
## Deploy Ops4Viya monitoring tools
# Prepare the directory for monitoring artifacts
mkdir -p ~/clouddrive/ops/azure-deployment/monitoring
export WORKING_DIR=~/clouddrive/ops/azure-deployment
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/monitoring $WORKING_DIR
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user.env $WORKING_DIR/monitoring

# Create $WORKING_DIR/monitoring/user-values-prom-operator.yaml to replace host.cluster.example.com with ingress host
INGRESS_SUFFIX=${PERFIX}-k8s.${LOC}.cloudapp.azure.com
cat >  $WORKING_DIR/monitoring/user-values-prom-operator.yaml << EOF
kubelet:
    serviceMonitor:
        # Azure uses http for kubelet metrics by default
        # See issue: https://github.com/coreos/prometheus-operator/issues/926
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

# Deploy Prometheus Operator 
~/clouddrive/payload/ops4viya/monitoring/bin/deploy_monitoring_cluster.sh

# Temporary fix to allow the push gateway to start in the Viya namespace
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user-values-pushgateway.yaml $WORKING_DIR/monitoring
echo "tolerations:" > $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "  - effect: NoSchedule" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    key: workload.sas.com/class" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    value: stateful" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml

# Deploy Prometheus Pushgateway
VIYA_NS=$NS ~/clouddrive/payload/ops4viya/monitoring/bin/deploy_monitoring_viya.sh

# Expose kube-proxy metrics
kubectl create configmap kube-proxy --from-literal=metricsBindAddress=0.0.0.0:10249 -n kube-system
# Restart all kube-proxy pods
kubectl delete po -n kube-system -l component=kube-proxy
# Pods will automatically be recreated

# Connect to Ops4Viya monitoring tools
echo "Open Grafana at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/grafana"
echo "Open Prometheus at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/prometheus"
echo "Open AlertManager at https://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/alertmanager"

# Optional: Remove SAS Viya monitoring tools
# Remove SAS Viya monitoring tools fro the Viya namespace. Run this section once per Viya namespace VIYA_NS=$NS
# Remote Prometheus Pushgateway
#VIYA_NS=$NS ~/clouddrive/payload/ops4viya/monitoring/bin/remove_monitoring_viya.sh
# Remove Prometheus Operator
#~/clouddrive/payload/ops4viya/monitoring/bin/remove_monitoring_cluster.sh
# then delete namespace
#kubectl delete ns monitoring
```

## Deploy Ops4Viya logging tools:

```bash
# Deploy Ops4Viya logging tools
# Prepare the directory for logging artifacts
mkdir -p ~/clouddrive/ops/azure-deployment/logging
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/logging $WORKING_DIR
cp ~/clouddrive/payload/viya4-monitoring/logging/user.env $WORKING_DIR/logging
echo "ES_KIBANASERVER_PASSWD=\"lnxsas\"" > $WORKING_DIR/logging/user.env
echo "ES_LOGCOLLECTOR_PASSWD=\"lnxsas\"" >> $WORKING_DIR/logging/user.env
echo "ES_METRICGETTER_PASSWD=\"lnxsas\"" >> $WORKING_DIR/logging/user.env

# Edit $WORKING_DIR/logging/user-values-elasticsearch-open.yaml to replace host.cluster.example.com with ingress host
cat > $WORKING_DIR/logging/user-values-elasticsearch-open.yaml << EOF
kibana:
    extraEnvs:
    # Needed for path-based ingress
    - name: SERVER_BASEPATH
      value: /kibana
    # Username & password need to be set here since helm replaces array values
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

# Deploy SAS Viya logging tool
sleep 30 && ~/clouddrive/payload/ops4viya/logging/bin/deploy_logging_open.sh

# Connect to Ops4Viya logging tool
echo "Open Kibana at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/kibana"

# Optional: Remove SAS Viya logging tool
#~/clouddrive/payload/ops4viya/logging/bin/remove_logging_open.sh
# then delete namespace
#kubectl delete ns logging

# Optional: Remove the parent Azure Resource group and the entire children objects
#az group delete --resource-group ${PERFIX}-k8s-rg
```

## Now what??

*Next sections that I'm planning to add to this project (not necessarilly by this order):*
- *Create and use a custom Viya order*
- *Get the Viya order through the CLI tool*
- *Add an Azure Container Registry (ACR)*
- *Use the mirrormgr to populate the ACR*
- *Automate the Viya order update*
- *Deploy Viya from ACR*
- *Add Azure AD authentication*
- *Expose CAS port (5570)*
- *Deploy python engine in AKS with SAS Scripting Wrapper for Analytics Transfer (SWAT) package*
- *Deploy R engine in AKS with SWAT package*
- *Deploy Jupyter Notebook in AKS*
- *Setup Network File System (NFS) for AKS*
- *Deploy GitLab in AKS*
- *Deploy Jenkins in AKS*
- *Deploy ArgoCD in AKS*
- *Manage Viya through GitOps*
- *Deploy Azure Data Lake Storage Gen2 (ADLS)*
- *Configure Viya to access ADLS*
- *Deploy Azure HDInsight*
- *Configure SAS/ACCESS Interface to Hadoop to access HDInsight*
- *Apply valid TLS certificate*
- *Fine tuning Viya ;-)*

#
*Useful reading:*
- *[SAS Viya Administration 2020.0.6](https://go.documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=v_006&docsetId=sasadminwlcm&docsetTarget=home.htm&locale=en)*
- *[SAS Viya Operations 2020.0.6](https://go.documentation.sas.com/?cdcId=itopscdc&cdcVersion=v_006&docsetId=itopswlcm&docsetTarget=home.htm&locale=en)*