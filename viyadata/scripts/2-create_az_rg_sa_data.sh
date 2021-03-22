### Exported variables

# Define the account of the Azure subscription
ACCOUNT="GELDM"
# Define the LOC of the Azure location
LOCATION="eastus"
# Define your SAS userid. To avoid any conflict with the Azure created objects, the usage of your $SASUID is advised
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
# Define the resource group the Azure created objects
RESOURCE_GROUP="${SASUID}-rg"
# Define the Azure storage account name
STORAGE_ACCOUNT_NAME="${SASUID}adls2"
# Define the container name of the Azure storage account
CONTAINER_NAME="fsdata"
# Install az extensions automatically
az config set extension.use_dynamic_install=yes_without_prompt
# Configure the Azure default location and set the subscription
az configure --defaults location=${LOCATION}
az account set -s ${ACCOUNT}

### Creates a resource group, storage account and blob container

# Create a resource group
echo "Creating a resource group at Azure"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create a storage account
echo "Creating an adls2 storage account at Azure"
az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP \
-l $LOCATION \
--sku Standard_LRS \
--access-tier Hot \
--enable-hierarchical-namespace true \
--kind StorageV2 

# Export the connection string as an environment variable, this is used when creating the Azure file share
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -o tsv)

# Create the blob Storage
echo "Creating Blob Container at Azure Storage account "
az storage container create -n $CONTAINER_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING --fail-on-exist

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Echo storage account name and key
echo "Storage account name:" $STORAGE_ACCOUNT_NAME
echo "Blob Storage Container name:" $CONTAINER_NAME

# Create directories in the blob storage container
az storage fs directory create -n csv -f $CONTAINER_NAME && \
az storage fs directory create -n filename -f $CONTAINER_NAME && \
az storage fs directory create -n orc -f $CONTAINER_NAME && \
az storage fs directory create -n orc_n_files -f $CONTAINER_NAME && \
az storage fs directory create -n parquet -f $CONTAINER_NAME

# List the data files from fsdata blob container
echo "List files from fsdata blob Container "
az storage blob list \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING \
--output table
