# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
function KickstartMSI () {
    if ($env:MSI_SECRET) {
        if(-not ($Env:AADConDone)) {
            Disable-AzContextAutosave -Scope Process | Out-Null
            Connect-AzAccount -Identity
            $Env:AADConDone = $true
        }
    }
}


#load config file with names for the required resources
    if(test-path .\FAconfig.xml){

        #delete this file from the function if there are issues with LogAnalytics, or some workspace parameters change.
        $FAConfigImport = Import-Clixml .\FAConfig.xml
        $Env:PortalLAWorkspaceName = $FAConfigImport.PortalLAWorkspaceName
        $Env:PortalRGName = $FAConfigImport.PortalRGName
        $Env:KeyVaultName = $FAConfigImport.KeyVaultName
    } else {
        throw "FAConfig.xml missing! He's dead Jim!"
    }

#Get username of authenticated user from http headers
function get-AuthenticatedUser () {
    # Get the ID Token from the header (called "access_token" for some reason!)
    $access_token = $Request.Headers.'x-ms-token-aad-access-token'
    
    # I am interested in the body, so split it along dots... and the second part is the body (first is header, last is signature)
    $bodyBase64 = ($access_token -split '\.')[1]
    
    # Pad what I got above. Need this hack to workaround this error:
    # MethodInvocationException: Exception calling "FromBase64String" with "1" argument(s): "The input is not a valid Base-64 string as it contains a non-base 64 character, more than two padding characters, or an illegal character among the padding characters."
    switch ($bodyBase64.Length % 4) {
        0 { break }
        2 { $bodyBase64 += '==' }
        3 { $bodyBase64 += '=' }
    }
    
    # Convert the Base64 to get JSON; then convert this JSON to as HashTable
    $claims = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($bodyBase64)) | ConvertFrom-Json -Depth 10
    return $claims
}

#LogAnalytics stuff

    #check for cached values for loganalytics access - otherwise generate and export
    if(test-path .\LAinfo.xml){

        #delete this file from the function if there are issues with LogAnalytics, or some workspace parameters change.
        $LAValuesImport = Import-Clixml .\LAinfo.xml

        $Env:sharedKey = $LAValuesImport.key
        $Env:customerId = $LAValuesImport.id

    } else {
        #Get LogAnalytics Workspace info and export to cache file
        $LAWorkspace = Get-AzOperationalInsightsWorkspace -Name $Env:PortalLAWorkspaceName  -ResourceGroupName $Env:PortalRGName
        $LAWorkspaceSharedKeys = $LAWorkspace | Get-AzOperationalInsightsWorkspaceSharedKey 
        $Env:sharedKey = [string]$LAWorkspaceSharedKeys.PrimarySharedKey
        $Env:customerId = [string]$LAWorkspace.customerId.Guid

        $LAValues = @{
            "key" = $Env:sharedKey;
            "id" = $Env:customerId;
        }
        $LAValues | Export-Clixml LAinfo.xml -Force
    }

    # Create the function to create the authorization signature
    Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
    {
        $xHeaders = "x-ms-date:" + $date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

        $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($sharedKey)

        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.Key = $keyBytes
        $calculatedHash = $sha256.ComputeHash($bytesToHash)
        $encodedHash = [Convert]::ToBase64String($calculatedHash)
        $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
        return $authorization
    }

    # Create the function to create and post the request
    Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
    {
        $method = "POST"
        $contentType = "application/json"
        $resource = "/api/logs"
        $rfc1123date = [DateTime]::UtcNow.ToString("r")
        $contentLength = $body.Length
        $signature = Build-Signature `
            -customerId $customerId `
            -sharedKey $sharedKey `
            -date $rfc1123date `
            -contentLength $contentLength `
            -method $method `
            -contentType $contentType `
            -resource $resource
        $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

        # Optional name of a field that includes the timestamp for the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
        $TimeStampField = ""

        $headers = @{
            "Authorization" = $signature;
            "Log-Type" = $logType;
            "x-ms-date" = $rfc1123date;
            "time-generated-field" = $TimeStampField;
        }

        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
        return $response.StatusCode

    }
