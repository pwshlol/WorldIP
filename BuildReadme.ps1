#region startup
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
#endregion startup

#region data
$CountryGlobal = Import-Csv -Path '.\csv\CountryGlobal\CountryGlobal.csv'
$CountryGlobal_IPV4 = Import-Csv -Path '.\csv\CountryGlobal\CountryGlobal_IPV4.csv'
$CountryGlobal_IPV6 = Import-Csv -Path '.\csv\CountryGlobal\CountryGlobal_IPV6.csv'
$Regions = $CountryGlobal | Select-Object region -Unique
$Countries = $CountryGlobal | Select-Object country -Unique
#endregion data

$README = "# WorldIP

{Country_Count} Countries in {Region_Count} regions

{CIDR_Count} CIDR - {CIDR_IPV4_Count} IPV4 - {CIDR_IPV6_Count} IPV6
"

$README = $README -replace '{Country_Count}', $($Countries.Count)
$README = $README -replace '{Region_Count}', $($Regions.Count)
$README = $README -replace '{CIDR_Count}', $($CountryGlobal.Count)
$README = $README -replace '{CIDR_IPV4_Count}', $($CountryGlobal_IPV4.Count)
$README = $README -replace '{CIDR_IPV6_Count}', $($CountryGlobal_IPV6.Count)

"<----------------------->"
($README).Trim()
"<----------------------->"

($README).Trim() | Set-Content .\README.md
