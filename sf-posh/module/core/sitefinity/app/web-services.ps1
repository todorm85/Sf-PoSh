function sf-wcf-invoke {
    param(
        $path = "Sitefinity/Services/ModulesService/modules?skip=0&take=50",
        $method = "GET",
        $body,
        $contentType = "application/json"
    )

    sf-auth-basic
    $authHeaderVal = sf-auth-basic-getHeaderValue
    $headers = @{
        "Pragma"="no-cache";
        "Cache-Control"="no-cache";
        "Accept"="*/*"; 
        "Authorization"=$authHeaderVal
    }
    
    $baseUrl = sf-iis-site-getUrl
    if ($method -eq "GET") {
        Invoke-WebRequest -Uri "$baseUrl/$path" -Method $method -Headers $headers
    } else {
        Invoke-WebRequest -Uri "$baseUrl/$path" -Method $method -Headers $headers -Body $body -ContentType $contentType
    }
}

function sf-date-convertToJSFormat {
    param (
        [datetime]$date
    )
    
    $timestamp = [Math]::Floor(1000 * (Get-Date $date -UFormat %s))
    $timestamp
}