## Outline

There are three sections in this project:

- [Deploy the infrastructure, namelly Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL](./1-deploy-aks-postgresql.md)
- [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
- *YOU ARE HERE =>* [Deploy Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)

## Move with the following steps to deploy Ops4Viya monitoring tools:

```bash
## Deploy Ops4Viya monitoring tools
# Prepare the directory for monitoring artifacts
mkdir -p ~/clouddrive/ops/azure-deployment/monitoring
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/monitoring ~/clouddrive/ops/azure-deployment
export WORKING_DIR=~/clouddrive/ops/azure-deployment
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user.env ~/clouddrive/ops/azure-deployment/monitoring

# Create $WORKING_DIR/monitoring/user-values-prom-operator.yaml to replace host.cluster.example.com with ingress host
INGRESS_SUFFIX=${PERFIX}-k8s.${LOC}.cloudapp.azure.com
cat > ~/clouddrive/ops/azure-deployment/monitoring/user-values-prom-operator.yaml << EOF
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

# Deploy the monitoring tool
~/clouddrive/payload/viya4-monitoring/monitoring/bin/deploy_monitoring_cluster.sh

# Temporary fix to allow the push gateway to start in our Viya namespace
cp ~/clouddrive/payload/viya4-monitoring/monitoring/user-values-pushgateway.yaml $WORKING_DIR/monitoring
echo "tolerations:" > $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "  - effect: NoSchedule" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    key: workload.sas.com/class" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml
echo "    value: stateful" >> $WORKING_DIR/monitoring/user-values-pushgateway.yaml

# Deploy the monitoring tools
VIYA_NS=$NS ~/clouddrive/payload/viya4-monitoring/monitoring/bin/deploy_monitoring_viya.sh

# Expose kube-proxy metrics
kubectl create configmap kube-proxy --from-literal=metricsBindAddress=0.0.0.0:10249 -n kube-system
# Restart all kube-proxy pods
kubectl delete po -n kube-system -l component=kube-proxy
# Pods will automatically be recreated

# Connect to Ops4Viya monitoring tools
echo "Open Grafana at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/grafana"
echo "Open Prometheus at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/prometheus"
echo "Open AlertManager at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/alertmanager"

# Optional: Remove Viya Ops4Viya monitoring tools
# Run this section once per Viya namespace VIYA_NS=$NS
#~/clouddrive/payload/viya4-monitoring/monitoring/bin/remove_monitoring_viya.sh
# Remove cluster monitoring
#~/clouddrive/payload/viya4-monitoring/monitoring/bin/remove_monitoring_cluster.sh
```

## Move with the following steps to deploy Ops4Viya logging tools:

```bash
# Deploy the Ops4Viya logging tools
# Prepare the directory for logging artifacts
mkdir -p ~/clouddrive/ops/azure-deployment/logging
cp -R ~/clouddrive/payload/viya4-monitoring/samples/azure-deployment/logging ~/clouddrive/ops/azure-deployment
export WORKING_DIR=~/clouddrive/ops/azure-deployment
cp ~/clouddrive/payload/viya4-monitoring/logging/user.env ~/clouddrive/ops/azure-deployment/logging
echo "ES_KIBANASERVER_PASSWD=\"lnxsas\"" > ~/clouddrive/ops/azure-deployment/logging/user.env
echo "ES_LOGCOLLECTOR_PASSWD=\"lnxsas\"" >> ~/clouddrive/ops/azure-deployment/logging/user.env
echo "ES_METRICGETTER_PASSWD=\"lnxsas\"" >> ~/clouddrive/ops/azure-deployment/logging/user.env

# Edit $WORKING_DIR/logging/user-values-elasticsearch-open.yaml to replace host.cluster.example.com with ingress host
cat > ~/clouddrive/ops/azure-deployment/logging/user-values-elasticsearch-open.yaml << EOF
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

# Deploy the logging tool
sleep 30 && ~/clouddrive/payload/viya4-monitoring/logging/bin/deploy_logging_open.sh

# Connect to Ops4Viya logging tools
echo "Open Kibana at http://${PERFIX}-k8s.${LOC}.cloudapp.azure.com/kibana"

# Optional: Remove Viya Ops4Viya logging tools
#~/clouddrive/payload/viya4-monitoring/logging/bin/remove_logging_open.sh
# then delete namespace
#kubectl delete ns logging

# Optional: Remove the parent Azure Resource group and the entire children objects
#az group delete --resource-group ${PERFIX}-k8s-rg
```

Now what??

Next sections that I'm planning to add to this project (not necessarilly by this order):
- Create your own Viya order
- Get the Viya order with the CLI
- Automate the Viya order update
- Add an Azure Container Registry (ACR)
- Use the mirrormgr to populate the ACR
- Deploy Viya from ACR
- Apply valid TLS certificate
- Add Azure AD authentication
- Deploy the SAS Deployment Operator 
- Deploy GitLab in AKS
- Deploy Jenkins in AKS
- Deploy ArgoCD in AKS
- Manage Viya through GitOps
- Configure SAS/ACCESS Interface to Hadoop
- Fine tuning of Viya ;-)

#
*Useful reading:*
- *[SAS Viya Administration 2020.0.5](https://go.documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=v_005&docsetId=sasadminwlcm&docsetTarget=home.htm&locale=en)*
- *[SAS Viya Operations 2020.0.5](https://go.documentation.sas.com/?cdcId=itopscdc&cdcVersion=v_005&docsetId=itopswlcm&docsetTarget=home.htm&locale=en)*