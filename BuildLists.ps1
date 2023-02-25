#region startup

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
if (!(Test-Path ".\sources")) { $null = New-Item ".\sources" -ItemType Directory -Force }
if (!(Test-Path ".\lists")) { $null = New-Item ".\lists" -ItemType Directory -Force }
if (!(Test-Path ".\lists\CountryGlobal")) { $null = New-Item ".\lists\CountryGlobal" -ItemType Directory -Force }
if (!(Test-Path ".\lists\CountrySeparated")) { $null = New-Item ".\lists\CountrySeparated" -ItemType Directory -Force }
if (!(Test-Path ".\lists\IANA")) { $null = New-Item ".\lists\IANA" -ItemType Directory -Force }
if (!(Test-Path ".\lists\RegionGlobal")) { $null = New-Item ".\lists\RegionGlobal" -ItemType Directory -Force }
if (!(Test-Path ".\lists\RegionSeparated")) { $null = New-Item ".\lists\RegionSeparated" -ItemType Directory -Force }
if (!(Test-Path ".\lists\World")) { $null = New-Item ".\lists\World" -ItemType Directory -Force }

$delegated_sources = [ordered]@{
    'delegated-iana-latest'             = 'https://ftp.apnic.net/stats/iana/delegated-iana-latest'
    'delegated-afrinic-extended-latest' = 'https://ftp.apnic.net/stats/afrinic/delegated-afrinic-extended-latest'
    'delegated-apnic-extended-latest'   = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-extended-latest'
    'delegated-arin-extended-latest'    = 'https://ftp.apnic.net/stats/arin/delegated-arin-extended-latest'
    'delegated-lacnic-extended-latest'  = 'https://ftp.apnic.net/stats/lacnic/delegated-lacnic-extended-latest'
    'delegated-ripencc-extended-latest' = 'https://ftp.apnic.net/stats/ripe-ncc/delegated-ripencc-extended-latest'
}

#endregion startup

#region download

$delegated_sources.GetEnumerator() | ForEach-Object -Parallel {
    try {
        Write-Output "$($_.Key) = $($_.Value)"
        $content = Invoke-RestMethod -Uri $_.Value
        Set-Content ".\sources\$($_.Key).txt" -Value $content -Force
    } catch {
        Write-Output "Error downloading $($_.Value)"
    }

} -ThrottleLimit 6

#endregion download

#region process

[PSCustomObject]$World = [ordered]@{
    IANA_Reserved    = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Available   = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Allocated   = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Available = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Reserved  = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Country          = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
}

$delegated_sources.GetEnumerator() | ForEach-Object -Parallel {
    Write-Output "$($_.Key)"
    $null = Get-Content ".\sources\$($_.Key).txt" | Where-Object { $_ -match 'ipv4|ipv6' } | ForEach-Object {
        $split = $_.Split('|')
        if ($split[1] -eq 'ZZ') {
            if ($split[6] -eq 'Reserved') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.IANA_Reserved).Add(@{
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:World.IANA_Reserved).Add(@{
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                            })
                    }
                }
            } else {
                if ($split[6] -ne 'available') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Allocated).Add(@{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                })
                        }
                        'ipv6' {
                            ($using:World.IANA_Allocated).Add(@{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                })
                        }
                    }
                } else {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Available).Add(@{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                })
                        }
                        'ipv6' {
                            ($using:World.IANA_Available).Add(@{
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                })
                        }
                    }
                }
            }
        } else {
            if ($split[6] -eq 'allocated' -or $split[6] -eq 'assigned') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Country).Add(@{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:World.Country).Add(@{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                            })
                    }
                }
            } elseif ($split[6] -eq 'available') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Region_Available).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:World.Region_Available).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                            })
                    }
                }
            } elseif ($split[6] -eq 'Reserved') {
                switch ($split[2]) {
                    'ipv4' {
                    ($using:World.Region_Reserved).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                    ($using:World.Region_Reserved).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                            })
                    }
                }
            }
        }
    }
} -ThrottleLimit 32

#endregion Process

#region Sorting

Write-Output "Sorting IANA_Reserved"
$World.IANA_Reserved = $World.IANA_Reserved |
Sort-Object version, {
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

Write-Output "Sorting IANA_Allocated"
$World.IANA_Allocated = $World.IANA_Allocated |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting RegionGlobal_Available"
$World.Region_Available = $World.Region_Available |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting RegionGlobal_Reserved"
$World.Region_Reserved = $World.Region_Reserved |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting CountryGlobal"
$World.Country = $World.Country |
Sort-Object region, country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

#endregion Sorting

#region Export

Write-Output "Exporting IANA_Reserved"
$World.IANA_Reserved |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Reserved_IPV4"
$World.IANA_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Reserved_IPV6"
$World.IANA_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available"
$World.IANA_Available |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available_IPV4"
$World.IANA_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Available_IPV6"
$World.IANA_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\lists\IANA\IANA_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated"
$World.IANA_Allocated |
Select-Object region, version, ip, prefixlength, state |
Export-Csv -Path ".\lists\IANA\IANA_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated_IPV4"
$World.IANA_Allocated |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength, state |
Export-Csv -Path ".\lists\IANA\IANA_Allocated_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting IANA_Allocated_IPV6"
$World.IANA_Allocated |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength, state |
Export-Csv -Path ".\lists\IANA\IANA_Allocated_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Available"
$World.Region_Available |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Available_IPV4"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Available_IPV6"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Reserved"
$World.Region_Reserved |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Reserved_IPV4"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionGlobal_Reserved_IPV6"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\lists\RegionGlobal\RegionGlobal_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting RegionSeparated_Available"
$World.Region_Available |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object version, ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting RegionSeparated_Available_IPV4"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting RegionSeparated_Available_IPV6"
$World.Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting RegionSeparated_Reserved"
$World.Region_Reserved |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object version, ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting RegionSeparated_Reserved_IPV4"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting RegionSeparated_Reserved_IPV6"
$World.Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\lists\RegionSeparated\$($_.Name)_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting CountryGlobal"
$World.Country |
Select-Object region, country, version, ip, prefixlength, state |
Export-Csv -Path ".\lists\CountryGlobal\CountryGlobal.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting CountryGlobal_IPV4"
$World.Country |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object region, country, ip, prefixlength, state |
Export-Csv -Path ".\lists\CountryGlobal\CountryGlobal_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting CountryGlobal_IPV6"
$World.Country |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object region, country, ip, prefixlength, state |
Export-Csv -Path ".\lists\CountryGlobal\CountryGlobal_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Exporting CountrySeparated"
$World.Country | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, version, ip, prefixlength, state |
    Export-Csv -Path ".\lists\CountrySeparated\$($_.Name).csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting CountrySeparated_IPV4"
$World.Country |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength, state |
    Export-Csv -Path ".\lists\CountrySeparated\$($_.Name)_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting CountrySeparated_IPV6"
$World.Country |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Select-Object region, ip, prefixlength, state |
    Export-Csv -Path ".\lists\CountrySeparated\$($_.Name)_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 32

Write-Output "Exporting World"
$World | ConvertTo-Json -Depth 99 | Out-File .\lists\World\World.json
$World | ConvertTo-Json -Depth 99 -Compress | Out-File .\lists\World\World_compressed.json

#endregion Export
