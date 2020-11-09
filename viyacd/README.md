# SAS deployment instructions based on Terraform Infrastructure-as-Code (IaC) tool to deploy SAS Viya 4 (cadence 2020.0.6) on Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL.

## Version 2020.0.6 from 09NOV2020 tunned by pedro.dias@sas.com for the IBERIA team.

# This project represents an evolution of the content that will be delivered by the Global Enablement Learning training course PSGEL255, that is being prepared by the GEL team and is planned to be rolled out during November.

# BIG congratulations for the incredible work that was done by Raphael.Poumarede@sas.com, Erwan.Granger@sas.com, Frederik.Vandenberghe@sas.com and the rest of the contributors of the GEL and GTP teams. All the credits are for their work!!

## SAS deployed software is based on 9CDZDD order. Check the order at: http://comsat.sas.com/ "Order Number" "equals to" filter to your order number. 

## The GEL Open LDAP is deployed as a container and the passwords of the users are "lnxsas". The "sasadm" is an unrestricted administrator.

## No valid TLS certifications are applied.

## In order to facilitate the firewall rules to access the Azure environment, having a VPN tunnel Direct to Cary is required (profile 3 usually).

## The entire deployment will take [~1] hour.

## The architecture of the SAS environment is represented by the following compute resources:
*Five AKS node pools with VMs that will support the k8s cluster (each VM have 200 GB of storage):*
- 1 x Standard_D5_v2 for system (node_count=1)
- 1 x Standard_E4s_v3 for CAS (node_count=1 with auto_scaling max_nodes=5)
- 1 x Standard_E4s_v3 for Compute (node_count=1 with auto_scaling max_nodes=5)
- 1 x Standard_D4s_v3 for Stateless Services (node_count=1 with auto_scaling max_nodes=5)
- 1 x Standard_D8s_v3 for Stateful Services  (node_count=1 with auto_scaling max_nodes=3)

*One managed database-as-a-service (DBaaS) of Azure DB for PostgreSQL:*
- 1 x Azure DB for PostgreSQL, 32 vCores and 50 GB of storage (SKU: GP_Gen5_32)

*Plenty of other objects, such as:*
- 1 x Resource Group for AKS and the PostgreSQL Database
- 1 x Network Security Group for AKS and the PostgreSQL Database
- 1 x Virtual Network for AKS and the PostgreSQL Database
- 1 x Resource Group for the AKS nodes
- 1 x Network Security Group for AKS nodes
- 1 x Route Table for AKS nodes
- 4 x Storage Accounts, general purpose v2, one for each AKS node
- 4 x Standard SSD disk, one for each AKS node
- 1 x Standard load balancer for AKS
- 2 x Standard public IP addresses, one for k8s and another for the load balancer
- 1 x DNS alias on the public IP address

![Deployed Architecture](./deployed-architecture.png)

## SAS deployed software:
*Order: 9CDZDD*

- SAS Data Preparation
- SAS Data Quality
- SAS Econometrics
- SAS Event Stream Manager
- SAS Event Stream Processing
- SAS In-Database Technologies for Hadoop
- SAS In-Database Technologies for Spark
- SAS In-Database Technologies for Teradata
- SAS Intelligent Decisioning
- SAS Model Manager
- SAS Optimization
- SAS Text Analytics for French
- SAS Text Analytics for Italian
- SAS Text Analytics for Spanish
- SAS Visual Analytics
- SAS Visual Data Mining and Machine Learning
- SAS Visual Forecasting
- SAS Visual Statistics
- SAS Visual Text Analytics
- SAS/ACCESS Interface to Amazon Redshift
- SAS/ACCESS Interface to DB2
- SAS/ACCESS Interface to Google BigQuery
- SAS/ACCESS Interface to Greenplum
- SAS/ACCESS Interface to HAWQ
- SAS/ACCESS Interface to Hadoop
- SAS/ACCESS Interface to Impala
- SAS/ACCESS Interface to JDBC
- SAS/ACCESS Interface to Microsoft SQL Server
- SAS/ACCESS Interface to MongoDB
- SAS/ACCESS Interface to MySQL
- SAS/ACCESS Interface to Netezza
- SAS/ACCESS Interface to ODBC
- SAS/ACCESS Interface to Oracle
- SAS/ACCESS Interface to PC Files
- SAS/ACCESS Interface to PostgreSQL
- SAS/ACCESS Interface to R/3
- SAS/ACCESS Interface to SAP ASE
- SAS/ACCESS Interface to SAP HANA
- SAS/ACCESS Interface to Salesforce
- SAS/ACCESS Interface to Snowflake
- SAS/ACCESS Interface to Spark
- SAS/ACCESS Interface to Teradata
- SAS/ACCESS Interface to Vertica
- SAS/CONNECT
- SAS/QC
- Risk Modeling Add-on for - SAS Visual Data Mining and Machine Learning

## Outline
There are three sections in this project:

- [Deploy the infrastructure, namelly Azure Kubernetes Service (AKS) and Azure Database for PostgreSQL](./1-deploy-aks-postgresql.md)
- [Deploy SAS Viya on top of the prepared infrastructure](./2-deploy-viya.md)
- [Deploy the Ops4Viya monitoring and logging tools](./3-deploy-ops4viya.md)

## Let's get started!
*[Pull the trigger and begin your deployment journey](./1-deploy-aks-postgresql.md)*

## In a rush??
*[Deploy it in one shot!](./666-in-a-rush.md)*

## Contributions
This project wouldn't be what it is without the continuous feedback I have to receive.
All contributions are welcome, so please raise an issue and address it to me ;-)

#
*Useful reading:*
- *[SAS Viya Administration 2020.0.6](https://go.documentation.sas.com/?cdcId=sasadmincdc&cdcVersion=v_006&docsetId=sasadminwlcm&docsetTarget=home.htm&locale=en)*
- *[SAS Viya Operations 2020.0.6](https://go.documentation.sas.com/?cdcId=itopscdc&cdcVersion=v_006&docsetId=itopswlcm&docsetTarget=home.htm&locale=en)*
