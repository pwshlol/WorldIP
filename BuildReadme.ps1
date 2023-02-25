#region startup

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

#endregion startup

#region data

Write-Output "Generating Objects from lists"
$CountryGlobal = Import-Csv -Path '.\lists\CountryGlobal\CountryGlobal.csv'
$CountryGlobal_IPV4 = Import-Csv -Path '.\lists\CountryGlobal\CountryGlobal_IPV4.csv'
$CountryGlobal_IPV6 = Import-Csv -Path '.\lists\CountryGlobal\CountryGlobal_IPV6.csv'
$RegionGlobal_Reserved = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Reserved.csv'
$RegionGlobal_Reserved_IPV4 = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Reserved_IPV4.csv'
$RegionGlobal_Reserved_IPV6 = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Reserved_IPV6.csv'
$RegionGlobal_Available = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Available.csv'
$RegionGlobal_Available_IPV4 = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Available_IPV4.csv'
$RegionGlobal_Available_IPV6 = Import-Csv -Path '.\lists\RegionGlobal\RegionGlobal_Available_IPV6.csv'

$IANA_Allocated = Import-Csv -Path '.\lists\IANA\IANA_Allocated.csv'
$IANA_Allocated_IPV4 = Import-Csv -Path '.\lists\IANA\IANA_Allocated_IPV4.csv'
$IANA_Allocated_IPV6 = Import-Csv -Path '.\lists\IANA\IANA_Allocated_IPV6.csv'
$IANA_Reserved = Import-Csv -Path '.\lists\IANA\IANA_Reserved.csv'
$IANA_Reserved_IPV4 = Import-Csv -Path '.\lists\IANA\IANA_Reserved_IPV4.csv'
$IANA_Reserved_IPV6 = Import-Csv -Path '.\lists\IANA\IANA_Reserved_IPV6.csv'
$IANA_Available = Import-Csv -Path '.\lists\IANA\IANA_Available.csv'
$IANA_Available_IPV4 = Import-Csv -Path '.\lists\IANA\IANA_Available_IPV4.csv'
$IANA_Available_IPV6 = Import-Csv -Path '.\lists\IANA\IANA_Available_IPV6.csv'

$Regions = $CountryGlobal | Select-Object region -Unique
$Countries = $CountryGlobal | Select-Object country -Unique
#endregion data

#region README

Write-Output "generating README string"
$README = "# WorldIP

Last update: {DATE}

{Country_Count} Countries in {Region_Count} regions

Regions Allocated/Assigned CIDR :

{Global_Regions_AA_STATS}
{Regions_AA_STATS}

Regions Reserved CIDR :

{Global_Regions_Reserved_STATS}
{Regions_Reserved_STATS}

Regions Available CIDR :

{Global_Regions_Available_STATS}
{Regions_Available_STATS}

IANA Allocated/Assigned CIDR :

{Global_IANA_AA_STATS}
{IANA_AA_STATS}

IANA Reserved CIDR :

{IANA_Reserved_STATS}

IANA Available CIDR :

{IANA_Available_STATS}
"

#endregion README

#region Header

Write-Output "replacing header string"
$README = $README -replace '{Country_Count}', $($Countries.Count)
$README = $README -replace '{Region_Count}', $($Regions.Count)

#endregion Header

#region Regions

# Allocated/Assigned

Write-Output "replacing Regions Allocated/Assigned string"
$README = $README -replace '{Global_Regions_AA_STATS}', "- global : $($CountryGlobal.Count) Total | $($CountryGlobal_IPV4.Count) IPV4 | $($CountryGlobal_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($CountryGlobal | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($CountryGlobal_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($CountryGlobal_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_AA_STATS}', ($buffer).Trim()

# Reserved

Write-Output "replacing Regions Reserved string"
$README = $README -replace '{Global_Regions_Reserved_STATS}', "- global : $($RegionGlobal_Reserved.Count) Total | $($RegionGlobal_Reserved_IPV4.Count) IPV4 | $($RegionGlobal_Reserved_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($RegionGlobal_Reserved | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($RegionGlobal_Reserved_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($RegionGlobal_Reserved_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Reserved_STATS}', ($buffer).Trim()

# Available

Write-Output "replacing Regions Available string"
$README = $README -replace '{Global_Regions_Available_STATS}', "- global : $($RegionGlobal_Available.Count) Total | $($RegionGlobal_Available_IPV4.Count) IPV4 | $($RegionGlobal_Available_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($RegionGlobal_Available | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($RegionGlobal_Available_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($RegionGlobal_Available_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{Regions_Available_STATS}', ($buffer).Trim()

#endregion Regions

#region IANA

# Allocated/Assigned

Write-Output "replacing IANA Allocated/Assigned string"
$README = $README -replace '{Global_IANA_AA_STATS}', "- global : $($IANA_Allocated.Count) Total | $($IANA_Allocated_IPV4.Count) IPV4 | $($IANA_Allocated_IPV6.Count) IPV6"
$buffer = ""
foreach ($region in $Regions) {
    $count = ($IANA_Allocated | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv4 = ($IANA_Allocated_IPV4 | Where-Object { $_.region -eq $($region.region) }).Count
    $count_ipv6 = ($IANA_Allocated_IPV6 | Where-Object { $_.region -eq $($region.region) }).Count
    $buffer += "- $($region.region) : $($count) Total | $($count_ipv4) IPV4 | $($count_ipv6) IPV6`n"
}
$README = $README -replace '{IANA_AA_STATS}', ($buffer).Trim()

# Reserved

Write-Output "replacing IANA Reserved string"
$README = $README -replace '{IANA_Reserved_STATS}', "- $($IANA_Reserved.Count) Total | $($IANA_Reserved_IPV4.Count) IPV4 | $($IANA_Reserved_IPV6.Count) IPV6"

# Available

Write-Output "replacing IANA Available string"
$README = $README -replace '{IANA_Available_STATS}', "- $($IANA_Available.Count) Total | $($IANA_Available_IPV4.Count) IPV4 | $($IANA_Available_IPV6.Count) IPV6"

#endregion IANA

#region END

$Date = (Get-Date).ToUniversalTime().ToString("yyyy/MM/dd HH:mm:ss (UTC)")
$README = $README -replace '{DATE}', $($Date)

"<----------------------->"
($README).Trim()
"<----------------------->"

Write-Output "README content : $Date"
($README).Trim() | Set-Content .\README.md

#endregion END
