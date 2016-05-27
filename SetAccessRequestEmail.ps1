[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, HelpMessage="This is the email address to be invited.")]
    [string]$Email,
    
    [Parameter(Mandatory=$true, HelpMessage="This is the URL for the SharePoint Online admin center.")]
    [string]$AdminUrl,

    [Parameter(Mandatory=$false, HelpMessage="This is the credentials used to connect to SharePoint Online.")]
    [System.Management.Automation.PSCredential]$Credentials,
    
    [Parameter(Mandatory=$false, HelpMessage="This is the path to the DLLs for CSOM.")]
    [string]$CSOMPath
)

Set-Strictmode -Version 1

If ($CSOMPath -eq $null -or $CSOMPath -eq "") { $CSOMPath = "." } 
If ($Credentials -eq $null) {
    $Credentials = Get-Credential
}
$spoCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Credentials.UserName, $Credentials.Password)

Add-Type -Path "$CSOMPath\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "$CSOMPath\Microsoft.SharePoint.Client.Runtime.dll" 

Connect-SPOService -Url $AdminUrl -Credential $Credentials

Function Set-AccessRequestEmail {
    param (
        $webUrl = $(throw "Please provide a URL"),
        $webCredential = $(throw "Please provide credentials"),
        $webEmail = $(throw "Please provide an email address")
    )

    process {
        # connect/authenticate to SharePoint Online and get ClientContext object.. 
        $clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($webUrl) 
        $clientContext.Credentials = $webCredential

        if (!$clientContext.ServerObjectIsNull.Value) { 
            Write-Host "Connected to SharePoint Online web: " $webUrl -ForegroundColor Green 

            Try {
                $web = $clientContext.Web
                $clientContext.Load($web)
                $clientContext.Load($web.Webs)
                $clientContext.ExecuteQuery()

                Try {
                    $web.RequestAccessEmail = $webEmail
                    $web.Update()
                    $clientContext.ExecuteQuery()
                } Catch {
                    Write-Warning $_.Exception.Message
                }

                foreach($subweb in $web.Webs) {
                    Set-AccessRequestEmail -webUrl $subweb.Url -webCredential $webCredential -webEmail $webEmail
                }
            } Catch {
                Write-Warning $_.Exception.Message
            }
        }
    }
}

Get-SPOSite | % {
    Set-AccessRequestEmail -webUrl $_.Url -webCredential $spoCredentials -webEmail $Email
}