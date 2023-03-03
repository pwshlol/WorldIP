#region startup

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

#endregion startup

#region data

Write-Output "Generating Objects from Lists"
$Country_All_Allocated = Import-Csv -Path '.\Lists\Country\All\Country_All_Allocated.csv'
$Country_All_Allocated_IPV4 = Import-Csv -Path '.\Lists\Country\All\Country_All_Allocated_IPV4.csv'
$Country_All_Allocated_IPV6 = Import-Csv -Path '.\Lists\Country\All\Country_All_Allocated_IPV6.csv'
$Country_All_Assigned = Import-Csv -Path '.\Lists\Country\All\Country_All_Assigned.csv'
$Country_All_Assigned_IPV4 = Import-Csv -Path '.\Lists\Country\All\Country_All_Assigned_IPV4.csv'
$Country_All_Assigned_IPV6 = Import-Csv -Path '.\Lists\Country\All\Country_All_Assigned_IPV6.csv'
$Region_All_Reserved = Import-Csv -Path '.\Lists\Region\All\Region_All_Reserved.csv'
$Region_All_Reserved_IPV4 = Import-Csv -Path '.\Lists\Region\All\Region_All_Reserved_IPV4.csv'
$Region_All_Reserved_IPV6 = Import-Csv -Path '.\Lists\Region\All\Region_All_Reserved_IPV6.csv'
$Region_All_Available = Import-Csv -Path '.\Lists\Region\All\Region_All_Available.csv'
$Region_All_Available_IPV4 = Import-Csv -Path '.\Lists\Region\All\Region_All_Available_IPV4.csv'
$Region_All_Available_IPV6 = Import-Csv -Path '.\Lists\Region\All\Region_All_Available_IPV6.csv'

$IANA_Reserved = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Reserved.csv'
$IANA_Reserved_IPV4 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Reserved_IPV4.csv'
$IANA_Reserved_IPV6 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Reserved_IPV6.csv'
$IANA_Allocated = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Allocated.csv'
$IANA_Allocated_IPV4 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Allocated_IPV4.csv'
$IANA_Allocated_IPV6 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Allocated_IPV6.csv'
$IANA_Available = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Available.csv'
$IANA_Available_IPV4 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Available_IPV4.csv'
$IANA_Available_IPV6 = Import-Csv -Path '.\Lists\IANA\Separated\IANA_Available_IPV6.csv'

$Regions = $Country_All_Allocated | Select-Object region -Unique
$Countries = $Country_All_Allocated | Select-Object country -Unique
#endregion data

#region README

Write-Output "generating README string"
$README = "# WorldIP

Last update: {DATE}

{Country_Count} Countries in {Region_Count} regions

## IANA Reserved CIDR

{IANA_Reserved_STATS}

## IANA Allocated CIDR

{Global_IANA_ALLOCATED_STATS}
{IANA_ALLOCATED_STATS}

## IANA Available CIDR

{IANA_Available_STATS}

## Regions Reserved CIDR

{Global_Regions_Reserved_STATS}
{Regions_Reserved_STATS}

## Regions Available CIDR

{Global_Regions_Available_STATS}
{Regions_Available_STATS}

## Country Allocated CIDR

{Global_Country_ALLOCATED_STATS}
{Country_ALLOCATED_STATS}

## Country Assigned CIDR

{Global_Country_ASSIGNED_STATS}
{Country_ASSIGNED_STATS}

"

#endregion README

#region Header

Write-Output "replacing header string"
$README = $README -replace '{Country_Count}', $($Countries.Count)
$README = $README -replace '{Region_Count}', $($Regions.Count)

#endregion Header

# IANA Reserved

Write-Output "replacing IANA Reserved string"
$README = $README -replace '{IANA_Reserved_STATS}', "- $($IANA_Reserved.Count) Total | $($IANA_Reserved_IPV4.Count) IPV4 | $($IANA_Reserved_IPV6.Count) IPV6"

# IANA Allocated

Write-Output "replacing IANA Allocated string"
$README = $README -replace '{Global_IANA_ALLOCATED_STATS}', "- global : $($IANA_Allocated.Count) Total | $($IANA_Allocated_IPV4.Count) IPV4 | $($IANA_Allocated_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($IANA_Allocated | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($IANA_Allocated_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($IANA_Allocated_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{IANA_ALLOCATED_STATS}', ($buffer).Trim()

# IANA Available

Write-Output "replacing IANA Available string"
$README = $README -replace '{IANA_Available_STATS}', "- $($IANA_Available.Count) Total | $($IANA_Available_IPV4.Count) IPV4 | $($IANA_Available_IPV6.Count) IPV6"

# Region Reserved

Write-Output "replacing Regions Reserved string"
$README = $README -replace '{Global_Regions_Reserved_STATS}', "- global : $($Region_All_Reserved.Count) Total | $($Region_All_Reserved_IPV4.Count) IPV4 | $($Region_All_Reserved_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($Region_All_Reserved | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_All_Reserved_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_All_Reserved_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Reserved_STATS}', ($buffer).Trim()

# Region Available

Write-Output "replacing Regions Available string"
$README = $README -replace '{Global_Regions_Available_STATS}', "- global : $($Region_All_Available.Count) Total | $($Region_All_Available_IPV4.Count) IPV4 | $($Region_All_Available_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($Region_All_Available | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_All_Available_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_All_Available_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Available_STATS}', ($buffer).Trim()

# Country Allocated

Write-Output "replacing Country Allocated string"
$README = $README -replace '{Global_Country_ALLOCATED_STATS}', "- global : $($Country_All_Allocated.Count) Total | $($Country_All_Allocated_IPV4.Count) IPV4 | $($Country_All_Allocated_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($Country_All_Allocated | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Country_All_Allocated_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Country_All_Allocated_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Country_ALLOCATED_STATS}', ($buffer).Trim()

# Country Assigned

Write-Output "replacing Country Assigned string"
$README = $README -replace '{Global_Country_ASSIGNED_STATS}', "- global : $($Country_All_Assigned.Count) Total | $($Country_All_Assigned_IPV4.Count) IPV4 | $($Country_All_Assigned_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($Country_All_Assigned | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Country_All_Assigned_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Country_All_Assigned_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Country_ASSIGNED_STATS}', ($buffer).Trim()

#region END

$Date = (Get-Date).ToUniversalTime().ToString("yyyy/MM/dd HH:mm:ss (UTC)")
$README = $README -replace '{DATE}', $($Date)

"<----------------------->"
($README).Trim()
"<----------------------->"

Write-Output "README content : $Date"
($README).Trim() | Set-Content .\README.md

#endregion END
