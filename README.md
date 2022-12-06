# Bicep deploy of AVD with Azure AD join (Cloud only)
Used Bicep as a Domain Specific Language (DSL) to deploy a traditional Hub and Spoke architecture.  Solution secured using Azure Firewall and Azure Bastion.  Used Win 11 Ent Single-Session with a Personal Host Pool.  In turn, delivering a 1-2-1 mapping of users to their persistent desktop with Automatic assignment.  Also showcased the use of Azure Compute Gallery, to store a sysprep/ generalised image with all the required bits for Session Hosts.
<br><br>
Note. The deployment creates a new Resource Group, Azure Compute Gallery and Image definition/ version, unless these elements are already in place.  The deployment doesn't require line of sight of Windows Server AD, since makes use of Azure AD join (Cloud only) and Data RBAC role assignments.
<br><br><br>
<img src="https://github.com/gamcmaho/avdcloudonly/blob/main/BicepAvdCloudOnly.jpg">
<br><br>
<h3>First generate a Token Expiration (now + 24 hours)</h3>
Using PowerShell run,<br><br>
$((get-date).ToUniversalTime().AddHours(24).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
<br><br>
Note.  The maximum life time of a token is 30 days.
<br><br>
<h3>Git Clone the repo to your local device</h3>
git clone https://github.com/gamcmaho/avdcloudonly.git
<br><br>
Create a new Resource Group in your Subscription
<br><br>
az login<br>
az account set -s "&ltsubscription name&gt"<br>
az group create --name "&ltresource group name&gt" --location "&ltlocation&gt"<br><br>
<h3>Use existing Azure Compute Gallery, or deploy a new gallery</h3>
To deploy a new gallery:
<br><br>
After cloning the repo, change to the "gallery" subdirectory of the "avdcloudonly" directory<br>
Modify the "parameters.gallery.json" providing values for:
<br><br>
location<br>
azure_compute_gallery_name
<br><br>
Note.  The Azure Compute Gallery name should be unique
<br><br><br>
Then deploy a new Azure Compute Gallery by running:<br><br>
az deployment group create -g "&ltresource group name&gt" --template-file "gallery.bicep" --parameters "parameters.gallery.json"
<br><br>
<h3>Use existing Master image in your Azure Compute Gallery, or capture a new image</h3>
To prepare and capture a new image:
<br><br>
Deploy a Windows 11 Ent Single-Session VM from the Azure Marketplace, e.g. win11-22h2<br>
Install the latest Windows updates<br><br>
Sysprep and Generalise by running %WINDIR%\system32\sysprep\sysprep.exe /generalize /shutdown /oobe<br>
From the virtual machine blade, once stopped, capture an image and store in your Azure Compute Gallery<br>
Then make a note of the Image URL for later reference.  See example Image URL below:
<br><br>
/subscriptions/&ltsubscription id&gt/resourceGroups/&ltresource group name&gt/providers/Microsoft.Compute/galleries/&ltAzure compute gallery name&gt/images/&ltimage name&gt
<br><br>
<h3>Deploy Networking, Security and AVD Hierarchy</h3>
Change to the "avdcloudonly" directory and modify the "parameters.main.json" providing values for:<br><br>
location<br>
token_expiration_time
<br><br>
az deployment group create -g "&ltresource group name&gt" --template-file "main.bicep" --parameters "parameters.main.json"
<br><br>
<h3>Create a Security Group and Test Users assigned to that group in Azure AD</h3>
<br>Nb.  Where possible, avoid RBAC assignment to individual Test Users and instead assign to the Security Group.  This will futureproof and enable movers, leavers and joiners.
<br><br>
<h3>Grant Data RBAC role assignment, either Administrator or Regular user</h3>
Using the Azure Portal, grant Data RBAC "Virtual Machine Administrator Login" or "Virtual Machine User Login" to your Security Group in Azure AD scoped to the Resource Group.
<br><br>
<h3>Grant Desktop Application Group assignment to your Security Group</h3>
Using Azure Portal, navigate to AVD -> Application Groups -> Desktop Application Group -> Assignments and add your Security Group
<br><br>
<h3>Once the main deployment has completed, deploy one or more Session Hosts</h3>
Modify the "parameters.compute.json" providing values for:<br><br>
location<br>
vm_gallery_image_id<br>
vm_size<br>
total_instances
<br><br>
az deployment group create -g "&ltresource group name&gt" --template-file "compute.bicep" --parameters "parameters.compute.json"
<br><br>
Note. The compute deployment requires input from the user, namely: Registration Token, Username and Password.  These are handled as Secure parameters and should be kept private.  The credentials relate to the Local Admin user on each Session Host and the token enables registration to the Host Pool.<br><br>
For Registration Token, navigate to AVD -> Host Pools -> Registration key, then securely copy and keep private.
<br><br>
<h3>Once the compute deployment has completed, prove Test Users can access their persistent desktops</h3>
Navigate to the AVD Web Client URL below:<br><br>
https://client.wvd.microsoft.com/arm/webclient/index.html
<br><br>
<h3>Congratulations, you're up and running with AVD!</h3>
