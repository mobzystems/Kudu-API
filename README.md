# Kudu-API
A Powershell module to access Azure Kudu. It focuses on the *Virtual File System* operations specified in https://github.com/projectkudu/kudu/wiki/REST-API but the rest should be straightforward to add when necessary.

# Usage
```powershell
[CmdletBinding()]
Param()
 
Import-Module .\Kudu-Api
 
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

# Operations
## Basic operations
### New-KuduAuthorizationToken
Create a token used to authorize to Kudu. This token is required for all operations.

    $token = New-KuduAuthorizationToken $username $password

### Get-KuduEnvironment
Get the properties version and siteLastUpdated from the Kudu site. A nice and simple test function:

    Get-KuduEnvironment

## File operations
### Receive-KuduFile
Download a file from Kudu:

    Receive-KuduFile $sitename $token '/site/wwwroot/file-to-download.txt' .\file-to-save-to.txt

### Send-KuduFile
Upload a file to Kudu:

    Send-KuduFile $sitename $token '/site/wwwroot/new-file-name.txt' .\file-to-upload.txt

### Set-KuduFileContent
Set or update the contents of a file on Kudu:

    Set-KuduFileContent $sitename $token '/site/wwwroot/test.txt' "test1`r`nttest2" # Note: two lines

### Remove-KuduFile
Delete a file from Kudu:

    Remove-KuduFile $sitename $token '/site/wwwroot/file-to-delete.txt'

## Folder operations
### Get-KuduChildItem
Get the files and folders in the specified folder:

    Get-KuduChildItem $sitename $token '/site/wwwroot/'

### New-KuduFolder
Create a folder on Kudu:

    New-KuduFolder $sitename $token '/site/wwwroot/folder1/folder2/'

### Remove-KuduFolder
Delete a folder from Kudu:

    Remove-KuduFolder $sitename $token '/site/wwwroot/folder'

### Get-KuduZippedFolder
Download a ZIP file with the contents of the folder:

    Get-KuduZippedFolder $sitename $token '/site/wwwroot/folder' .\zip-file-to-save.zip
