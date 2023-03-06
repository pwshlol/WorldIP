#region startup
#<#
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

#endregion startup

#region data

Write-Output "Generating Objects from Lists"

$IANA = Import-Csv -Path ".\Lists\IANA\Global\IANA_Global.csv"

$IANA_Reserved = $IANA | Where-Object { $_.state -eq 'reserved' }
$IANA_Reserved_IPV4 = $IANA_Reserved | Where-Object { $_.version -eq 'ipv4' }
$IANA_Reserved_IPV6 = $IANA_Reserved | Where-Object { $_.version -eq 'ipv6' }

$IANA_Available = $IANA | Where-Object { $_.state -eq 'available' }
$IANA_Available_IPV4 = $IANA_Available | Where-Object { $_.version -eq 'ipv4' }
$IANA_Available_IPV6 = $IANA_Available | Where-Object { $_.version -eq 'ipv6' }

$IANA_Allocated = $IANA | Where-Object { $_.state -eq 'allocated' }
$IANA_Allocated_IPV4 = $IANA_Allocated | Where-Object { $_.version -eq 'ipv4' }
$IANA_Allocated_IPV6 = $IANA_Allocated | Where-Object { $_.version -eq 'ipv6' }

$REGION = Import-Csv -Path ".\Lists\Region\Global\Region_Global.csv"

$Region_Reserved = $REGION | Where-Object { $_.state -eq 'reserved' }
$Region_Reserved_IPV4 = $Region_Reserved | Where-Object { $_.version -eq 'ipv4' }
$Region_Reserved_IPV6 = $Region_Reserved | Where-Object { $_.version -eq 'ipv6' }

$Region_Available = $REGION | Where-Object { $_.state -eq 'available' }
$Region_Available_IPV4 = $Region_Available | Where-Object { $_.version -eq 'ipv4' }
$Region_Available_IPV6 = $Region_Available | Where-Object { $_.version -eq 'ipv6' }

$Region_Allocated = $REGION | Where-Object { $_.state -eq 'allocated' }
$Region_Allocated_IPV4 = $Region_Allocated | Where-Object { $_.version -eq 'ipv4' }
$Region_Allocated_IPV6 = $Region_Allocated | Where-Object { $_.version -eq 'ipv6' }

$Region_Assigned = $REGION | Where-Object { $_.state -eq 'assigned' }
$Region_Assigned_IPV4 = $Region_Assigned | Where-Object { $_.version -eq 'ipv4' }
$Region_Assigned_IPV6 = $Region_Assigned | Where-Object { $_.version -eq 'ipv6' }

$Regions_List = $REGION | Select-Object region -Unique | Where-Object { $_.region -ne '*' }
$Countries_List = $REGION | Select-Object country -Unique | Where-Object { $_.country -ne '*' }
#endregion data

#region README

Write-Output "README String"
$README = "# WorldIP

Last update: {DATE}

{Country_Count} Countries in {Region_Count} regions

## IANA Reserved CIDR

{IANA_Reserved}

## IANA Available CIDR

{IANA_Available}

## IANA Allocated CIDR

{Global_IANA_ALLOCATED}
{IANA_ALLOCATED}

## Regions Reserved CIDR

{Global_Regions_Reserved}
{Regions_Reserved}

## Regions Available CIDR

{Global_Regions_Available}
{Regions_Available}

## Country Allocated CIDR

{Global_Region_ALLOCATED}
{Region_ALLOCATED}

## Country Assigned CIDR

{Global_Region_ASSIGNED}
{Region_ASSIGNED}

"

#endregion README

#region Header

Write-Output "replacing header string"
$README = $README -replace '{Country_Count}', $($Countries_List.Count)
$README = $README -replace '{Region_Count}', $($Regions_List.Count)

#endregion Header

# IANA Reserved

Write-Output "replacing IANA Reserved string"
$README = $README -replace '{IANA_Reserved}', "- $($IANA_Reserved.Count) Total | $($IANA_Reserved_IPV4.Count) IPV4 | $($IANA_Reserved_IPV6.Count) IPV6"

# IANA Available

Write-Output "replacing IANA Available string"
$README = $README -replace '{IANA_Available}', "- $($IANA_Available.Count) Total | $($IANA_Available_IPV4.Count) IPV4 | $($IANA_Available_IPV6.Count) IPV6"

# IANA Allocated

Write-Output "replacing IANA Allocated string"
$README = $README -replace '{Global_IANA_ALLOCATED}', "- global : $($IANA_Allocated.Count) Total | $($IANA_Allocated_IPV4.Count) IPV4 | $($IANA_Allocated_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions_List) {
    $count = ($IANA_Allocated | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($IANA_Allocated_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($IANA_Allocated_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{IANA_ALLOCATED}', ($buffer).Trim()

# Region Reserved

Write-Output "replacing Region Reserved string"
$README = $README -replace '{Global_Regions_Reserved}', "- global : $($Region_Reserved.Count) Total | $($Region_Reserved_IPV4.Count) IPV4 | $($Region_Reserved_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions_List) {
    $count = ($Region_Reserved | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_Reserved_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_Reserved_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Reserved}', ($buffer).Trim()

# Region Available

Write-Output "replacing Region Available string"
$README = $README -replace '{Global_Regions_Available}', "- global : $($Region_Available.Count) Total | $($Region_Available_IPV4.Count) IPV4 | $($Region_Available_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions_List) {
    $count = ($Region_Available | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_Available_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_Available_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Available}', ($buffer).Trim()

# Country Allocated

Write-Output "replacing Region Allocated string"
$README = $README -replace '{Global_Region_ALLOCATED}', "- global : $($Region_Allocated.Count) Total | $($Region_Allocated_IPV4.Count) IPV4 | $($Region_Allocated_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions_List) {
    $count = ($Region_Allocated | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_Allocated_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_Allocated_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Region_ALLOCATED}', ($buffer).Trim()

# Country Assigned

Write-Output "replacing Region Assigned string"
$README = $README -replace '{Global_Region_ASSIGNED}', "- global : $($Region_Assigned.Count) Total | $($Region_Assigned_IPV4.Count) IPV4 | $($Region_Assigned_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions_List) {
    $count = ($Region_Assigned | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($Region_Assigned_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($Region_Assigned_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Region_ASSIGNED}', ($buffer).Trim()
#>
#region END

$Date = (Get-Date).ToUniversalTime().ToString("yyyy/MM/dd HH:mm:ss (UTC)")
$README = $README -replace '{DATE}', $($Date)

"<----------------------->"
($README).Trim()
"<----------------------->"

Write-Output "README content : $Date"
($README).Trim() | Set-Content .\README.md

#endregion END
