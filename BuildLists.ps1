#region startup

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

if (!(Test-Path ".\Sources")) { $null = New-Item ".\Sources" -ItemType Directory -Force }
if (!(Test-Path ".\Lists")) { $null = New-Item ".\Lists" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Misc")) { $null = New-Item ".\Lists\Misc" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Misc\ASN")) { $null = New-Item ".\Lists\Misc\ASN" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Misc\ORG")) { $null = New-Item ".\Lists\Misc\ORG" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\IANA")) { $null = New-Item ".\Lists\IANA" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\IANA\Global")) { $null = New-Item ".\Lists\IANA\Global" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\IANA\Separated")) { $null = New-Item ".\Lists\IANA\Separated" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Region")) { $null = New-Item ".\Lists\Region" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Region\Global")) { $null = New-Item ".\Lists\Region\Global" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Region\All")) { $null = New-Item ".\Lists\Region\All" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Region\Separated")) { $null = New-Item ".\Lists\Region\Separated" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Country")) { $null = New-Item ".\Lists\Country" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Country\Global")) { $null = New-Item ".\Lists\Country\Global" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Country\All")) { $null = New-Item ".\Lists\Country\All" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\Country\Separated")) { $null = New-Item ".\Lists\Country\Separated" -ItemType Directory -Force }
if (!(Test-Path ".\Lists\World")) { $null = New-Item ".\Lists\World" -ItemType Directory -Force }

$Sources = [ordered]@{
    'delegated-iana-latest'             = 'https://ftp.apnic.net/stats/iana/delegated-iana-latest'
    'delegated-afrinic-extended-latest' = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-extended-latest'
    'delegated-apnic-extended-latest'   = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-extended-latest'
    'delegated-arin-extended-latest'    = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'delegated-lacnic-extended-latest'  = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-extended-latest'
    'delegated-ripencc-extended-latest' = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-extended-latest'
    'asnames'                           = 'https://ftp.ripe.net/ripe/asnames/asn.txt'
    'alloclist'                         = 'https://ftp.apnic.net/stats/ripe-ncc/membership/alloclist.txt'
}

#endregion startup

#region download
<#
$Sources.GetEnumerator() | ForEach-Object -Parallel {
    try {
        Write-Output "$($_.Key) = $($_.Value)"
        $content = Invoke-RestMethod -Uri $_.Value
        Set-Content ".\Sources\$($_.Key).txt" -Value $content -Force
    } catch {
        Write-Output "Error downloading $($_.Value)"
    }
} -ThrottleLimit 8
#>
#endregion download

#region process

[PSCustomObject]$World = [ordered]@{
    IANA_Reserved     = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Available    = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Allocated    = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Available  = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Reserved   = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Country_Allocated = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Country_Assigned  = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    ASN               = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    ORG               = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
}

#region ASN

Write-Output "Processing ASN"
$file = Get-Content ".\Sources\asnames.txt"
$file | ForEach-Object {
    if (-not ([string]::IsNullOrEmpty($_))) {
        $split = $_ -split ' '
        $number = $split[0]
        $country = $split[-1]
        $name = $_ -replace "^$number\s|\s$country$", ""
        $name = $name.Substring(0, $name.Length - 1)
                ($World.ASN).Add(
            [ordered]@{
                'number'  = $number
                'name'    = $name
                'country' = $country
            }
        )
    }
}

#endregion ASN

#region ORG

Write-Output "Processing ORG"
$file = Get-Content ".\Sources\alloclist.txt"
for ($i = 0; $i -lt $file.Length; $i++) {
    if ($file[$i] -match "^\S.*") {
        $shortname = $file[$i].Trim()
        $fullname = $file[$i + 1].Trim()
        $i = $i + 2
        while ($i -lt $file.Length -and $file[$i] -notmatch "^\S") {
            if (-not ([string]::IsNullOrEmpty($file[$i]))) {
                $parts = $file[$i] -split '\s+'
                $split = $parts[2].split('/')
                if ($parts[2].Trim() -like '*.*') {
                    ($World.ORG).Add(
                        @{
                            'shortname'    = $shortname
                            'fullname'     = $fullname
                            'version'      = 'ipv4'
                            'ip'           = $split[0]
                            'prefixlength' = $split[1]
                        }
                    )
                } else {
                    ($World.ORG).Add(
                        @{
                            'shortname'    = $shortname
                            'fullname'     = $fullname
                            'version'      = 'ipv6'
                            'ip'           = $split[0]
                            'prefixlength' = $split[1]
                        }
                    )
                }
            }
            $i++
        }
    }
}

#endregion ORG

#region Delegated

Write-Output "Processing Delegated"
$Sources.GetEnumerator() | ForEach-Object -Parallel {
    if ($_.Key -like 'delegated*' ) {
        Write-Output "$($_.Key)"
        $null = Get-Content ".\Sources\$($_.Key).txt" | Where-Object { $_ -match 'ipv4|ipv6' } | ForEach-Object {
            $split = $_.Split('|')
            if ($split[1] -eq 'ZZ') {
                if ($split[6] -eq 'Reserved') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Reserved).Add(
                                @{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.IANA_Reserved).Add(
                                @{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                }
                            )
                        }
                    }
                } elseif ($split[6] -eq 'allocated') {
                    switch ($split[2]) {
                        'ipv4' {
                                ($using:World.IANA_Allocated).Add(
                                @{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                }
                            )
                        }
                        'ipv6' {
                                ($using:World.IANA_Allocated).Add(
                                @{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                }
                            )
                        }
                    }
                } elseif ($split[6] -eq 'available') {
                    switch ($split[2]) {
                        'ipv4' {
                                ($using:World.IANA_Available).Add(
                                @{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                }
                            )
                        }
                        'ipv6' {
                                ($using:World.IANA_Available).Add(
                                @{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                }
                            )
                        }
                    }
                }
            } else {
                if ($split[6] -eq 'Reserved') {
                    switch ($split[2]) {
                        'ipv4' {
                        ($using:World.Region_Reserved).Add(
                                @{
                                    'region'       = $split[0]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                }
                            )
                        }
                        'ipv6' {
                        ($using:World.Region_Reserved).Add(
                                @{
                                    'region'       = $split[0]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                }
                            )
                        }
                    }
                } elseif ($split[6] -eq 'allocated') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.Country_Allocated).Add(
                                @{
                                    'region'       = $split[0]
                                    'country'      = $split[1]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                    'org'          = "n/a"
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.Country_Allocated).Add(
                                @{
                                    'region'       = $split[0]
                                    'country'      = $split[1]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                    'org'          = "n/a"
                                }
                            )
                        }
                    }
                } elseif ($split[6] -eq 'assigned') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.Country_Assigned).Add(
                                @{
                                    'region'       = $split[0]
                                    'country'      = $split[1]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                    'org'          = "n/a"
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.Country_Assigned).Add(
                                @{
                                    'region'       = $split[0]
                                    'country'      = $split[1]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                    'org'          = "n/a"
                                }
                            )
                        }
                    }
                } elseif ($split[6] -eq 'available') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.Region_Available).Add(
                                @{
                                    'region'       = $split[0]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.Region_Available).Add(
                                @{
                                    'region'       = $split[0]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                }
                            )
                        }
                    }
                }
            }
        }
    }
} -ThrottleLimit 6

#endregion Delegated

#region Injecting ORG

Write-Output "Injecting ORGs"
$CountryHashtable = @{}
$World.Country_Allocated | ForEach-Object {
    $key = $_.ip + '/' + $_.prefixlength
    $CountryHashtable[$key] = $_
}
foreach ($org in $World.ORG) {
    $key = $org.ip + '/' + $org.prefixlength
    if ($Country = $CountryHashtable[$key]) {
        $Country.org = "$($org.shortname);$($org.fullname)"
    }
}
Write-Output "Injected $(($world.Country_Allocated | Where-Object { $_.org -ne "n/a" }).count) ORGs"

#endregion Injecting ORG

#endregion Process

#region Sorting

Write-Output "Sorting ASN"
$World.ASN = $World.ASN | Sort-Object {
    $_.number -as [Int64]
}

Write-Output "Sorting ORG"
$World.ORG = $World.ORG | Sort-Object shortname, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting IANA_Reserved"
$World.IANA_Reserved = $World.IANA_Reserved |
Sort-Object version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting IANA_Allocated"
$World.IANA_Allocated = $World.IANA_Allocated |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting IANA_Available"
$World.IANA_Available = $World.IANA_Available |
Sort-Object {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting Region_Reserved"
$World.Region_Reserved = $World.Region_Reserved |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting Region_Available"
$World.Region_Available = $World.Region_Available |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting Country_Assigned"
$World.Country_Assigned = $World.Country_Assigned |
Sort-Object region, country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting Country_Allocated"
$World.Country_Allocated = $World.Country_Allocated |
Sort-Object region, country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

#endregion Sorting

#region Export

#region Misc

Write-Output "Exporting ASN"
$World.ASN | Export-Csv -Path ".\Lists\Misc\ASN\ASN.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
$World.ASN | ConvertTo-Json -Depth 99 -Compress | Out-File ".\Lists\Misc\ASN\ASN.json"

Write-Output "Exporting ORG"
$World.ORG |
Select-Object shortname, fullname, version, ip, prefixlength |
ConvertTo-Json -Depth 99 -Compress | Out-File .\Lists\Misc\ORG\ORG.json

#endregion Misc

#region IANA

Write-Output "Exporting IANA_Global"
$World.IANA_Reserved + $World.IANA_Allocated + $World.IANA_Available |
Select-Object state, version, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Global\IANA_Global.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Global_IPV4"
$World.IANA_Reserved + $World.IANA_Allocated + $World.IANA_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object state, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Global\IANA_Global_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Global_IPV6"
$World.IANA_Reserved + $World.IANA_Allocated + $World.IANA_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object state, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Global\IANA_Global_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Reserved"
$World.IANA_Reserved |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Reserved_IPV4"
$World.IANA_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Reserved_IPV6"
$World.IANA_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available"
$World.IANA_Available |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available_IPV4"
$World.IANA_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available_IPV6"
$World.IANA_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated"
$World.IANA_Allocated |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated_IPV4"
$World.IANA_Allocated |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Allocated_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated_IPV6"
$World.IANA_Allocated |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\IANA\Separated\IANA_Allocated_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

#endregion IANA

#region Region

Write-Output "Exporting Region_Global"
$World.Region_Reserved + $World.Region_Available |
Select-Object region, state, version, ip, prefixlength |
Sort-Object region, state, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
} | Export-Csv -Path ".\Lists\Region\Global\Region_Global.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_Global_IPV4"
$World.Region_Reserved + $World.Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, state, ip, prefixlength |
Sort-Object region, state, {
    $_.ip -as [version]
} | Export-Csv -Path ".\Lists\Region\Global\Region_Global_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_Global_IPV6"
$World.Region_Reserved + $World.Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, state, ip, prefixlength |
Sort-Object region, state, {
    [int64]('0x' + $_.ip.Replace(":", ""))
} | Export-Csv -Path ".\Lists\Region\Global\Region_Global_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Available"
$World.Region_Available |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Available_IPV4"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Available_IPV6"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Reserved"
$World.Region_Reserved |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Reserved_IPV4"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_All_Reserved_IPV6"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\Lists\Region\All\Region_All_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Region_Separated_Available"
$World.Region_Available |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object version, ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Region_Separated_Available_IPV4"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Region_Separated_Available_IPV6"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Region_Separated_Reserved"
$World.Region_Reserved |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object version, ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Region_Separated_Reserved_IPV4"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Region_Separated_Reserved_IPV6"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\Lists\Region\Separated\$($_.Name)_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

#endregion Region

#region Country

Write-Output "Exporting Country_Global"
$World.Country_Allocated + $World.Country_Assigned |
Select-Object region, country, state, version, ip, prefixlength, org |
Sort-Object region, country, state, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
} | Export-Csv -Path ".\Lists\Country\Global\Country_Global.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_Global_IPV4"
$World.Country_Allocated + $World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, country, state, ip, prefixlength, org |
Sort-Object region, country, state, {
    $_.ip -as [version]
} | Export-Csv -Path ".\Lists\Country\Global\Country_Global_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_Global_IPV6"
$World.Country_Allocated + $World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, country, state, ip, prefixlength, org |
Sort-Object region, country, state, {
    [int64]('0x' + $_.ip.Replace(":", ""))
} | Export-Csv -Path ".\Lists\Country\Global\Country_Global_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Allocated"
$World.Country_Allocated |
Select-Object region, country, version, ip, prefixlength, org |
Export-Csv -Path ".\Lists\Country\All\Country_All_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Allocated_IPV4"
$World.Country_Allocated |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, country, ip, prefixlength, org |
Export-Csv -Path ".\Lists\Country\All\Country_All_Allocated_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Allocated_IPV6"
$World.Country_Allocated |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, country, ip, prefixlength, org |
Export-Csv -Path ".\Lists\Country\All\Country_All_Allocated_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Assigned"
$World.Country_Assigned |
Select-Object region, country, version, ip, prefixlength |
Export-Csv -Path ".\Lists\Country\All\Country_All_Assigned.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Assigned_IPV4"
$World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, country, ip, prefixlength |
Export-Csv -Path ".\Lists\Country\All\Country_All_Assigned_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_All_Assigned_IPV6"
$World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, country, ip, prefixlength |
Export-Csv -Path ".\Lists\Country\All\Country_All_Assigned_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting Country_Separated_Allocated"
$World.Country_Allocated | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, version, ip, prefixlength, org |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Country_Separated_Allocated_IPV4"
$World.Country_Allocated |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength, org |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Allocated_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Country_Separated_Allocated_IPV6"
$World.Country_Allocated |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength, org |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Allocated_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Country_Separated_Assigned"
$World.Country_Assigned | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, version, ip, prefixlength |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Assigned.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Country_Separated_Assigned_IPV4"
$World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Assigned_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting Country_Separated_Assigned_IPV6"
$World.Country_Assigned |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength |
    Export-Csv -Path ".\Lists\Country\Separated\$($_.Name)_Assigned_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32
#endregion Country

Write-Output "Exporting World"
$World | ConvertTo-Json -Depth 99 -Compress | Out-File .\Lists\World\World.json

#endregion Export
