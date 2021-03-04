# Kudu-API
A powershell module to access Azure Kudu

# Usage
```powershell
[CmdletBinding()]
Param()
 
Import-Module .\Kudu-Api -Verbose:$false
 
$sitename = 'mywebapp'
$username = '$mywebapp'
$password = 'your-publishing-or-deployment-password'
 
# Create a token for the site
$token = New-KuduAuthorizationToken $username $password
 
# Create a hash table with the site name and token
# By using @site we can supply the -SiteName and -Token arguments
$site = @{ SiteName = $sitename; Token = $token }
 
# Get the Kudu version
"Kudu version: $((Get-KuduEnvironment @site).version)"
 
# Get the contents of the wwwroot-folder
(Get-KuduChildItem @site '/site/wwwroot').Path
```
