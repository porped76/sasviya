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

### Uploads sample data to storage

# Download the sample data to the local machine
wget https://github.com/porped76/viya/blob/main/viyacd/sample_data.tgz
tar -zxf sample_data.tgz && rm -f sample_data.tgz

# Upload sample data file to blob storage contianer/fodler
echo "Uploading sample data file to Blob Storgae container/folder  "
data_folder=sample_data
az storage blob upload \
--name "$data_folder/cars.csv" \
--file $data_folder/cars_source.csv  \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING

az storage blob upload \
--name "flight_data/flight_reporting.csv" \
--file "$data_folder/flight_reporting.csv" \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING

number_of_file=5
#echo "Number of Files to copy :"$number_of_file
for ((i=1; i<=$number_of_file; i++)) ;
do
#echo "Number:"$i ;

#Load data to fsdata blob container
az storage blob upload \
--name "baseball/baseball_prqt_$i" \
--file "$data_folder/baseball_prqt_0" \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING 
done ;

# List the data files from fsdata Blob container
echo "List files from  fsdata Blob COntainer "
az storage blob list \
--container-name $CONTAINER_NAME \
--connection-string $AZURE_STORAGE_CONNECTION_STRING \
--output table 

# Create Big data file at local sample_data folder  

rm ./sample_data/big_data_cars.csv
echo "Creating a new Big data file at local sample_data folder .....................   ~2.5GB size  ... in ~5 Min...... " 
for i in {1..70000}; 
do 
	cat ./sample_data/cars_source.csv >> ./sample_data/big_data_cars.csv ;
done
ls -lah ./sample_data/big* 

echo "Uploading data files to Blob container using AZCopy tool from local sample_data folder ........................ " 

end=`date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'`
#echo "expiry time :" $end 

SAS_container_token=`az storage container generate-sas \
--name $CONTAINER_NAME  \
--permissions acdrw \
--expiry $end \
--https-only \
--connection-string $AZURE_STORAGE_CONNECTION_STRING \
-o tsv`

#echo "Container SAS Token:" $SAS_container_token

azcopy copy "./sample_data/" \
"https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/$CONTAINER_NAME/big_data/?$SAS_container_token" \
--recursive=true

echo " Deletng Big data file from local sample_data folder  " 
rm ./sample_data/big_data_cars.csv
