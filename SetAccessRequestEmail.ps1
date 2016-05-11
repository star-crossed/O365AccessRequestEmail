# replace these details (also consider using Get-Credential to enter password securely as script runs).. 
$username = "REDACTED" 
$password = "REDACTED" 
$adminUrl = "https://REDACTED-admin.sharepoint.com"

# email address we would like all requests on all sites to go to
$email = "REDACTED"

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force 
$spoCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($username, $securePassword) 
$psCredentials = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# the path here may need to change if you used e.g. C:\Lib.. 
Add-Type -Path "C:\Users\pchoquette\Source\Repos\PnP-Sites-Core\Assemblies\16.1\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "C:\Users\pchoquette\Source\Repos\PnP-Sites-Core\Assemblies\16.1\Microsoft.SharePoint.Client.Runtime.dll" 
# note that you might need some other references (depending on what your script does) for example:
Add-Type -Path "C:\Users\pchoquette\Source\Repos\PnP-Sites-Core\Assemblies\16.1\Microsoft.SharePoint.Client.Taxonomy.dll" 

Connect-SPOService -Url $adminUrl -Credential $psCredentials

Function Set-AccessRequestEmail {
    param (
        $webUrl = $(throw "Please provide a URL"),
        $webCredential = $(throw "Please provide credentials")
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
                    $web.RequestAccessEmail = $email
                    $web.Update()
                    $clientContext.ExecuteQuery()
                } Catch {
                    Write-Warning $_.Exception.Message
                }

                foreach($subweb in $web.Webs) {
                    Set-AccessRequestEmail -webUrl $subweb.Url -webCredential $webCredential
                }
            } Catch {
                Write-Warning $_.Exception.Message
            }
        }
    }
}

Get-SPOSite | % {
    Set-AccessRequestEmail -webUrl $_.Url -webCredential $spoCredentials
}