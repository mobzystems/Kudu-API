<#
    .SYNOPSIS
        Powershell access to the Kudu REST API

    .DESCRIPTION
        See https://github.com/projectkudu/kudu/wiki/REST-API

        All functions take SiteName and Token arguments. SiteName is the part before '.scm.azurewebsites.net'.
        The Token is created by calling New-KuduAuthorizationToken with the publishing user name and password
        of the Azure web App.
#>
[CmdletBinding()]
Param()

Function Get-KuduUrl()
{
    <#
        .SYNOPSIS
        
        Get the Kudu base-url for a site name. The URL ends in a slash
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$SiteName
    )

    return "https://$SiteName.scm.azurewebsites.net/"
}

Function New-KuduAuthorizationToken()
{
    <#
        .SYNOPSIS

        Create a new Kudu authorization token for the Kudu site of an Azure web App
    #>
    [CmdletBinding()]
    Param(
        # The deployment username of the Azure Web App (NOT the FTP username!)
        [Parameter(Mandatory=$true)]
        [string]$Username,
        # The deployment password of the Azure Web App
        [Parameter(Mandatory=$true)]
        [string]$Password
    )

    return [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
}

Function Invoke-KuduApi()
{
    <#
        .SYNOPSIS

        Call the Kudu REST API. SiteName, Token, Method and Path are mandatory.
        Optional Body, InFile and OutFile parameters are passed to Invoke-RestMethod.

        .NOTES

        Do not use this function directly, but rather New-KuduFolder, Receive-KuduFile, etc.
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # The HTTP Method to use
        [Parameter(Mandatory=$true)]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,
         # Relative URL of the Kudu request (after .../api/)
        [Parameter(Mandatory=$true)]
        [string]$Path,
        # An optional body to pass to the request
        [Parameter(Mandatory=$false)]
        [string]$Body,
        # An optional file to pass to the request
        [Parameter(Mandatory=$false)]
        [string]$InFile,
        # An optional file name to store the result in
        [Parameter(Mandatory=$false)]
        [string]$OutFile
    )

    [string]$url = "$(Get-KuduUrl $Sitename)api/$Path";

    $arguments = @{}

    if ($Body) { $arguments.Body = $Body }
    if ($InFile) { $arguments.InFile = $InFile }
    if ($OutFile) { $arguments.OutFile = $OutFile }

    # Call the Kudu service. The If-Match header bypasses ETag checking
    return Invoke-RestMethod `
        -Method $Method `
        -Uri $url `
        -Headers @{ 'Authorization' = "Basic $Token"; 'If-Match' = '*' } `
        -UserAgent 'powershell/1.0' `
        -ContentType 'application/json' `
        @arguments
}

Function EnsureValidPath() {
    <#
        Ensure a pah starts with a slash and optionally ends with one, too
        Ensure it does NOT contain double slashes
    #>
    Param(
        # The VFS path
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # If $true, ensure a trailing slash
        [switch]$IsFolder = $false
    )

    [string]$p = $VfsPath.Trim('/')

    if ($p.Length -eq 0) {
        if ($IsFolder) {
            return '/';
        } else {
            throw "VFS path cannot be empty"
        }
    } else {
        if ($IsFolder) {
            return "/$VfsPath/" # Trailing slash
        } else {
            return "/$VfsPath" # No trailing slash
        }
    }
}

Function Get-KuduEnvironment()
{
    <#
        .SYNOPSIS

        Get the Kudu environment
        Properties: version and siteLastModified
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    return Invoke-KuduApi $SiteName $Token 'GET' 'environment'
}

Function Invoke-KuduCommand()
{
    <#
        .SYNOPSIS

        Execute a command in the Kudu console
        Return the text output of the command
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # A CMD command to execute, e.g. 'dir' or 'type file'
        [Parameter(Mandatory=$true)]
        [string]$Command,
        # The Windows working directory, e.g. D:\home - NOT in VFS format!
        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory
    )

    [string]$body = (ConvertTo-Json @{ command = $Command; dir = $WorkingDirectory })

    return Invoke-KuduApi $SiteName $Token 'POST' 'command' -Body $body
}

Function Get-KuduItem()
{
    <#
        .SYNOPSIS

        Download a file from Kudu vfs (virtual file system)
        If the path ends in a slash, it's interpreted as a 
        directory and its contents are returned. If not, the
        contents of the file are returned

        .NOTES

        Do not use this function directly, but rather Receive-KuduFile and Get-KuduChildItem
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # The VFS path. Must start with a slah.
        # With a trailing slash, the contents of a directory are returned;
        # without one, the contents of a file
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # Save the file under this name. If not specified, return the contents as a string
        [Parameter(Mandatory=$false)]
        [string]$OutFile
    )

    return Invoke-KuduApi $SiteName $Token 'GET' "vfs$VfsPath" -OutFile $OutFile
}

Function Set-KuduItem()
{
    <#
        .SYNOPSIS

        Upload a file to Kudu vfs (virtual file system) OR
        create a Kudu vfs folder (if the Path ends in a slash)

        .NOTES

        Do not use this function directly, but rather Send-KuduFile and New-KuduFolder
     #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # The VFS path. Must start with a slah.
        # With a trailing slash, a folder at this path is created;
        # without one, the specified file is uploaded to this path
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # The local file to upload
        [Parameter(Mandatory=$false)]
        [string]$InFile
    )

    return Invoke-KuduApi $SiteName $Token 'PUT' "vfs$VfsPath" -InFile $InFile
}

Function Remove-KuduItem()
{
    <#
        .SYNOPSIS

        Upload a file to Kudu vfs (virtual file system) OR
        create a Kudu vfs folder (if the Path ends in a slash)

        .NOTES

        Do not use this function directly, but rather Remove-KuduFile and Remove-KuduFolder
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # The VFS path. Must start with a slah.
        # With a trailing slash, a folder at this path is created;
        # without one, the specified file is uploaded to this path
        [Parameter(Mandatory=$true)]
        [string]$VfsPath
    )

    return Invoke-KuduApi $SiteName $Token 'DELETE' "vfs$VfsPath"
}

Function Receive-KuduFile()
{
    <#
        .SYNOPSIS
    
        Download a file from Kudu vfs
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # Must start with BUT NOT END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # Local file to download
        [Parameter(Mandatory=$true)]
        [string]$LocalFile
    )

    return Get-KuduItem $SiteName $Token (EnsureValidPath $VfsPath) -OutFile $LocalFile
}

Function Send-KuduFile()
{
    <#
        .SYNOPSIS

        Upload a file to Kudu vfs
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # Must start with BUT NOT END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # Local file to download
        [Parameter(Mandatory=$true)]
        [string]$LocalFile
    )

    return Set-KuduItem $SiteName $Token (EnsureValidPath $VfsPath) -InFile $LocalFile
}

Function Remove-KuduFile()
{
    <#
        .SYNOPSIS

        Delete a file from Kudu VFS
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # Must start with BUT NOT END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath
    )

    return Remove-KuduItem $SiteName $Token (EnsureValidPath $VfsPath)
}

Function Get-KuduChildItem()
{
    <#
        .SYNOPSIS

        Get the child items in a Kudu vfs folder
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
         # Must start with AND END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath
    )

    return Get-KuduItem $SiteName $Token (EnsureValidPath $VfsPath -IsFolder)
}

Function New-KuduFolder()
{
    <#
        .SYNOPSIS

        Create a Kudu VFS folder. The folder must exist and be empty!
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
         # Must start with AND END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath
    )

    return Set-KuduItem $SiteName $Token (EnsureValidPath $VfsPath -IsFolder)
}

Function Remove-KuduFolder()
{
    <#
        .SYNOPSIS

        Delete a folder from Kudu VFS
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # Must start with AND END WITH a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath
    )

    return Remove-KuduItem $SiteName $Token (EnsureValidPath $VfsPath -IsFolder)
}

Function Get-KuduZippedFolder()
{
    <#
        .SYNOPSIS

        Download a ZIP file of a Kudu vfs folder
    #>
    [CmdletBinding()]
    Param(
        # The Azure Web App name
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        # Created using New-KuduAuthorizationToken
        [Parameter(Mandatory=$true)]
        [string]$Token,
        # Path must start AND END with a slash
        [Parameter(Mandatory=$true)]
        [string]$VfsPath,
        # The local zip file to download
        [Parameter(Mandatory=$true)]
        [string]$OutFile
    )

    return Invoke-KuduApi $SiteName $Token 'GET' "zip$(EnsureValidPath $VfsPath -IsFolder)" -OutFile $OutFile
}

# These do not work, although detailed in https://github.com/c9/vfs-http-adapter
# which Kudu claims to use...

# Function Rename-KuduItem()
# {
#     <#
#         .SYNOPSIS

#         Rename a Kudu vfs file or folder
#     #>
#     [CmdletBinding()]
#     Param(
#         [Parameter(Mandatory=$true)]
#         [string]$SiteName,
#         [Parameter(Mandatory=$true)]
#         [string]$Token,
#         # The VFS path. Must start with a slah.
#         # With a trailing slash, designated a folder;
#         # without one, a file.
#         [Parameter(Mandatory=$true)]
#         [string]$FromVfsPath,
#         [Parameter(Mandatory=$true)]
#         [string]$ToVfsPath
#     )

#     return Invoke-KuduApi $SiteName $Token 'POST' "vfs$FromVfsPath" -Body (ConvertTo-Json @{ moveTo = $ToVfsPath; overwrite = $false} )
# }

# Function Copy-KuduItem()
# {
#     <#
#         .SYNOPSIS

#         Copy a Kudu vfs file or folder
#     #>
#     [CmdletBinding()]
#     Param(
#         [Parameter(Mandatory=$true)]
#         [string]$SiteName,
#         [Parameter(Mandatory=$true)]
#         [string]$Token,
#         # The VFS path. Must start with a slah.
#         # With a trailing slash, designated a folder;
#         # without one, a file.
#         [Parameter(Mandatory=$true)]
#         [string]$FromVfsPath,
#         [Parameter(Mandatory=$true)]
#         [string]$ToVfsPath
#     )

#     return Invoke-KuduApi $SiteName $Token 'POST' "vfs$ToVfsPath" -Body (ConvertTo-Json @{ copyFrom = $FromVfsPath} )
# }

# Export all module members with a dash in the name
Export-ModuleMember '*-*'