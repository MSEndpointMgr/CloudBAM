using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$currentUserData = get-AuthenticatedUser
$currentUserName = $currentUserData.name
$currentUserUPN = $currentUserData.upn
$currentUserOID = $currentUserData.oid
$currentUserIP = $currentUserData.ipaddr
Write-Information "This person is using the API : $currentUserName (UPN: $currentUserUPN) (ID: $currentUserOID)"
Write-Information "From IP: $currentUserIP"

# Test if we received a key.
$key = $Request.Query.key
if (-not $key) {
    $key = $Request.Body.key
}

# Test if we received a reason value.
$reason = $Request.Query.reason
if (-not $reason) {
    $reason = $Request.Body.reason
}

# Test if we received a note
$note = $Request.Query.note
if (-not $note) {
    $note = $Request.Body.note
} 
if (-not $note) { $note = "Not supplied"}

#determine if we need authentication with MSI, and kickstart it if so.
if($key -and $reason) {
    KickstartMSI
    
}

#If there was a reason submitted then we know we need to log an audit event and get a key
if ($reason) {

    #format the reasonID
    $reasonText = switch ($reason) {
        1 {"BIOS/TPM Changed"}
        2 {"OS Files Modified"}
        3 {"Lost PIN/Passphrase"}
        999 {"Archive query"}
    }

    #Build Json Object with audit data
    $json = [PSCustomObject]@{
        KeyID = "$key"
        Actor = "$currentUserOID"
        Reason = "$reasonText"
        Note = "$note"
    } | ConvertTo-Json
    #Send stuff to log analytics workspace

    # Specify the name of the record type that you'll be creating
    $logType = "BitLockerPortalAudit"

    # Submit the data to the API endpoint
    write-information "Logging the following JSON: $json"
    write-information "WorkspaceID is: $($Env:customerId)"
    try {
        Post-LogAnalyticsData -customerId $($Env:customerId) -sharedKey $($Env:sharedKey) -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
    } catch {
        write-error "Posting data to LogAnalytics failed!"
    }
     
}

#Determine if we need to output the portal code or search for a key as an API request
if ($key) {
    #init hashtable
    $secrets = @{}
    #Wildcard search via AZ modules (slow - need to convert to direct API request at some point)
    if($reason -eq 999){
    #Query KeyVault for wildcard match and create hashtable
        write-information "Searching key vault for ($key) - this operation will be slow."
        $keys = Get-AzKeyVaultSecret -VaultName $Env:KeyVaultName | where {$_.Name -ilike "$key*"}
        if ($keys) {
            foreach ($result in $keys) {
                $secret = Get-AzKeyVaultSecret -VaultName $Env:KeyVaultName -Name $($result.Name) -AsPlainText
                $secrets["$($result.Name)"] = $secret
            }
        } else {
            $secrets["$key"] = "no match found!"
        }

    } else {

    #use KV API for faster direct query
        write-information "Getting secret from KeyVault via API for name: $key"
        #get access token to vault from MSI
        $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        $kvToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://vault.azure.net").AccessToken
        #form the correct request headers
        $headers = @{ 'Authorization' = "Bearer $kvToken" }
        $queryUrl = "https://$($Env:KeyVaultName).vault.azure.net/secrets/$key" + "?api-version=7.2"
        write-information "Requesting secret from keyvault using this url: $queryUrl"
        $keyResponse = Invoke-RestMethod -Method GET -Uri $queryUrl -Headers $headers
        #validate that a secret was found or tell the user there was no match.
        $foundSecret = $keyResponse.value
        if($foundSecret) {
            $secrets["$key"] = "$foundSecret"
        } else {
            $secrets["$key"] = "no match found!"
        }

    }
  
    #convert hashtable of secret(s) to JSON and return to API caller.
    $body = $secrets | ConvertTo-Json
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        ContentType = "application/json"
        Body = $body
    })

} else {

    #OUTPUT CloudBAM Portal Web
    $body = Get-Content ".\portal.html" -Raw #placed in wwwroot
    $body = $body -replace "xxxxUSERNAMExxxx",$currentUserName
    #Uncomment next line for debug data about user signin - will be stored in meta header in the html output.
    #$body = $body -replace "xxxxAADINFOxxxx",$currentUserData
    

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        ContentType = "text/html"
        Body = $body
    })
}
