# Import the Microsoft repository key
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Create local azure-cli repository information
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo

# Install dnf tool
sudo yum install -y dnf

# Install azure-cli tools with the dnf install command
sudo dnf install azure-cli

# Download azcopy tool
wget https://aka.ms/downloadazcopy-v10-linux

# Install azcopy tool
tar zxvf downloadazcopy-v10-linux && sudo chown root:root azcopy_linux_amd64_*/azcopy && sudo chmod 755 azcopy_linux_amd64_*/azcopy && sudo mv azcopy_linux_amd64_*/azcopy /usr/bin && sudo rm -rf downloadazcopy-v10-linux && sudo rm -rf azcopy_linux_amd64_*