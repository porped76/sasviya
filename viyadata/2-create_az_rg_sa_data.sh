# Set the shell to use vi-mode:
set -o vi
# Exported variables
# Define the ACCOUNT of the Azure subscription
ACCOUNT="SESA"
# Define the LOC of the Azure location
LOCATION="germanywestcentral"
# Define your SAS userid. To avoid any conflict with the Azure created objects, the usage of your $SASUID is advised
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
# Define the resource group the Azure created objects
RESOURCE_GROUP="${SASUID}-rg"
# Define the Azure storage account name
STORAGE_ACCOUNT_NAME="${SASUID}adls2"
# Define the container name of the Azure storage account
CONTAINER_NAME="fsdata"
# Configure the Azure default location and set the subscription
az configure --defaults location=${LOCATION}
az account set -s ${ACCOUNT}

### Creates a Resource group, Storage Account and Blob Container

# Create a resource group
echo "Creating a Resource Group at Azure account "
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create a storage account
echo "Creating an ADLS2 Storage Account at Azure"
az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP \
-l $LOCATION \
--sku Standard_LRS \
--access-tier Hot \
--enable-hierarchical-namespace true \
--kind StorageV2 

# Export the connection string as an environment variable, this is used when creating the Azure file share
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -o tsv)

# Create the Blob Storage
echo "Creating Blob Container at Azure Storage account "
az storage container create -n $CONTAINER_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING --fail-on-exist

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Echo storage account name and key
echo "Storage account name:" $STORAGE_ACCOUNT_NAME
echo "Blob Storage Container name:" $CONTAINER_NAME

### Upload sample data to storage

# Upload sample data directory to blob storage container
echo "Uploading sample data directory to blob Storgae container"
data_folder=sample_data
az storage blob upload \
--name "$data_folder/" \
--file $data_folder/  \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING

# List the data files from fsdata blob container
echo "List files from  fsdata blob Container "
az storage blob list \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING \
--output table
