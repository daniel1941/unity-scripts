param(
    [Parameter(Mandatory=$false)]
    [string]$Url = "https://vtllpagtmncbkywsqccd.supabase.co/rest/v1/rpc/rewards_get_allocations",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "<key>",
    
    [Parameter(Mandatory=$false)]
    [string]$BearerToken = "<bearer>"
)

$Body = @{
    "skip" = $null
    "take" = $null
} | ConvertTo-Json

# Headers
$Headers = @{
    "apikey"        = $ApiKey
    "Authorization" = "Bearer $BearerToken"
    "Content-Type"  = "application/json"
}

# Send POST request
$response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body $Body

# Load license mappings
$licenses = Get-Content -Path ".\licenses.json" | ConvertFrom-Json

# Group by date and licenseId, then display
$groupedData = $response | Group-Object { ([DateTime]$_.completedAt).Date }, licenseId | ForEach-Object {
    $date = ([DateTime]$_.Group[0].completedAt).ToString("yyyy-MM-dd")
    $licenseId = $_.Group[0].licenseId
    $totalAmount = ($_.Group | Measure-Object -Property amountMicros -Sum).Sum / 1000000
    $count = $_.Count
    
    # Find device name from licenses.json
    $license = $licenses | Where-Object { $_.licenseId -eq $licenseId }
    $deviceName = if ($license) { $license.deviceName } else { $licenseId.Substring($licenseId.Length - 4) }
    
    [PSCustomObject]@{
        Date = $date
        DeviceName = $deviceName
        LicenseId = $licenseId
        Count = $count
        TotalAmount = $totalAmount
        AverageAmount = $totalAmount / $count
        Allocations = $_.Group
    }
}

$groupedData | Sort-Object Date, @{Expression={$_.deviceName}; Descending=$false} | Format-Table Date, DeviceName, Count, @{Name="TotalAmount";Expression={$_.TotalAmount.ToString("F6")}}, @{Name="AverageAmount";Expression={$_.AverageAmount.ToString("F6")}} -AutoSize

# Calculate and display totals
$totalCount = ($groupedData | Measure-Object -Property Count -Sum).Sum
$totalAmount = ($groupedData | Measure-Object -Property TotalAmount -Sum).Sum

# Average per device
$averagePerDevice = $groupedData | Group-Object DeviceName | ForEach-Object {
    [PSCustomObject]@{
        DeviceName = $_.Name
        AverageAmount = ($_.Group | Measure-Object -Property TotalAmount -Average).Average
    }
}

# Average per day
$averagePerDay = $groupedData | Group-Object Date | ForEach-Object {
    [PSCustomObject]@{
        Date = $_.Name
        AverageAmount = ($_.Group | Measure-Object -Property TotalAmount -Average).Average
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total Records: $totalCount"
Write-Host "Total Amount: $($totalAmount.ToString("F6"))"

Write-Host "`n=== Average Per Device ===" -ForegroundColor Yellow
$averagePerDevice | Format-Table DeviceName, @{Name="AverageAmount";Expression={$_.AverageAmount.ToString("F6")}} -AutoSize

Write-Host "`n=== Average Per Day ===" -ForegroundColor Yellow
$averagePerDay | Format-Table Date, @{Name="AverageAmount";Expression={$_.AverageAmount.ToString("F6")}} -AutoSize


