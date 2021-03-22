# Define your SAS userid. To avoid any conflict with the Azure created objects, the usage of your $SASUID is advised
SASUID=$(az ad signed-in-user show --query mailNickname | sed -e 's/^"//' -e 's/"$//')
# Remove the parent resource group and the entire children objects
az group delete --resource-group ${SASUID}-rg
