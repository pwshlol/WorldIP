#region startup
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
if (!(Test-Path ".\sources")) { $null = New-Item ".\sources" -ItemType Directory -Force }
if (!(Test-Path ".\csv")) { $null = New-Item ".\csv" -ItemType Directory -Force }
if (!(Test-Path ".\csv\CountryGlobal")) { $null = New-Item ".\csv\CountryGlobal" -ItemType Directory -Force }
if (!(Test-Path ".\csv\CountrySeparated")) { $null = New-Item ".\csv\CountrySeparated" -ItemType Directory -Force }
if (!(Test-Path ".\csv\IANA")) { $null = New-Item ".\csv\IANA" -ItemType Directory -Force }
if (!(Test-Path ".\csv\RegionGlobal")) { $null = New-Item ".\csv\RegionGlobal" -ItemType Directory -Force }
if (!(Test-Path ".\csv\RegionSeparated")) { $null = New-Item ".\csv\RegionSeparated" -ItemType Directory -Force }
#endregion startup

#region download
$delegated_sources = [ordered]@{
    'delegated-iana-latest'             = 'https://ftp.apnic.net/stats/iana/delegated-iana-latest'
    'delegated-afrinic-extended-latest' = 'https://ftp.apnic.net/stats/afrinic/delegated-afrinic-extended-latest'
    'delegated-apnic-extended-latest'   = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-extended-latest'
    'delegated-arin-extended-latest'    = 'https://ftp.apnic.net/stats/arin/delegated-arin-extended-latest'
    'delegated-lacnic-extended-latest'  = 'https://ftp.apnic.net/stats/lacnic/delegated-lacnic-extended-latest'
    'delegated-ripencc-extended-latest' = 'https://ftp.apnic.net/stats/ripe-ncc/delegated-ripencc-extended-latest'
}
$delegated_sources.GetEnumerator() | ForEach-Object -Parallel {
    try {
        Write-Output ($_.Key = $_.Value)
        $content = Invoke-RestMethod -Uri $_.Value
        Set-Content ".\sources\$($_.Key).txt" -Value $content -Force
    } catch {
        Write-Output ("Error downloading $($_.Value)")
    }

} -ThrottleLimit 6
#endregion download

#region process
$IANA_Reserved = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$IANA_Available = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$IANA_Allocated = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$Region_Available = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$Region_Reserved = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$Country = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()

$delegated_sources.GetEnumerator() | ForEach-Object -Parallel {
    Write-Output ($_.Key)
    $null = Get-Content ".\sources\$($_.Key).txt" | Where-Object { $_ -match 'ipv4|ipv6' } | ForEach-Object {
        $split = $_.Split('|')
        if ($split[1] -eq 'ZZ') {
            if ($split[6] -eq 'Reserved') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:IANA_Reserved).Add(@{
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:IANA_Reserved).Add(@{
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
                            ($using:IANA_Allocated).Add(@{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                })
                        }
                        'ipv6' {
                            ($using:IANA_Allocated).Add(@{
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
                            ($using:IANA_Available).Add(@{
                                    'region'       = $split[7]
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                })
                        }
                        'ipv6' {
                            ($using:IANA_Available).Add(@{
                                    'region'       = $split[7]
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
                        ($using:Country).Add(@{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:Country).Add(@{
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
                        ($using:Region_Available).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                        ($using:Region_Available).Add(@{
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
                    ($using:Region_Reserved).Add(@{
                                'region'       = $split[0]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                            })
                    }
                    'ipv6' {
                    ($using:Region_Reserved).Add(@{
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
} -ThrottleLimit 16

#endregion Process

#region IANA

Write-Output "IANA_Reserved"
$IANA_Reserved |
Sort-Object version |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Reserved_IPV4"
$IANA_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Reserved_IPV6"
$IANA_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Available"
$IANA_Available |
Sort-Object version |
Select-Object version, ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Available_IPV4"
$IANA_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Available_IPV6"
$IANA_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Select-Object ip, prefixlength |
Export-Csv -Path ".\csv\IANA\IANA_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Allocated"
$IANA_Allocated |
Sort-Object region |
Select-Object region, version, ip, prefixlength, state |
Export-Csv -Path ".\csv\IANA\IANA_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Allocated_IPV4"
$IANA_Allocated |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object region |
Select-Object region, ip, prefixlength, state |
Export-Csv -Path ".\csv\IANA\IANA_Allocated_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "IANA_Allocated_IPV6"
$IANA_Allocated |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object region |
Select-Object region, ip, prefixlength, state |
Export-Csv -Path ".\csv\IANA\IANA_Allocated_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

#endregion INANA

#region RegionGlobal

Write-Output "RegionGlobal_Available"
$Region_Available |
Sort-Object region |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "RegionGlobal_Available_IPV4"
$Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object region |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "RegionGlobal_Available_IPV6"
$Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object region |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "RegionGlobal_Reserved"
$Region_Reserved |
Sort-Object region |
Select-Object region, version, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "RegionGlobal_Reserved_IPV4"
$Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object region |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "RegionGlobal_Reserved_IPV6"
$Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object region |
Select-Object region, ip, prefixlength |
Export-Csv -Path ".\csv\RegionGlobal\RegionGlobal_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

#endregion RegionGlobal

#region RegionSeparated

Write-Output "RegionSeparated_Available"
$Region_Available |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object version, ip, prefixlength |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "RegionSeparated_Available_IPV4"
$Region_Available |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Available_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "RegionSeparated_Available_IPV6"
$Region_Available |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Available_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "RegionSeparated_Reserved"
$Region_Reserved |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Select-Object version, ip, prefixlength |
    Sort-Object version |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "RegionSeparated_Reserved_IPV4"
$Region_Reserved |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Reserved_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "RegionSeparated_Reserved_IPV6"
$Region_Reserved |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object ip, prefixlength |
    Export-Csv -Path ".\csv\RegionSeparated\$($_.Name)_Reserved_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

#endregion RegionSeparated

#region CountryGlobal

Write-Output "CountryGlobal"
$Country |
Sort-Object country |
Select-Object region, country, version, ip, prefixlength, state |
Export-Csv -Path ".\csv\CountryGlobal\CountryGlobal.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "CountryGlobal_IPV4"
$Country |
Where-Object { $_.version -EQ 'ipv4' } |
Sort-Object country |
Select-Object region, country, ip, prefixlength, state |
Export-Csv -Path ".\csv\CountryGlobal\CountryGlobal_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "CountryGlobal_IPV6"
$Country |
Where-Object { $_.version -EQ 'ipv6' } |
Sort-Object country |
Select-Object region, country, ip, prefixlength, state |
Export-Csv -Path ".\csv\CountryGlobal\CountryGlobal_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

#endregion CountryGlobal

#region CountrySeparated

Write-Output "CountrySeparated"
$Country | Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |
    Sort-Object version |
    Select-Object region, version, ip, prefixlength, state |
    Export-Csv -Path ".\csv\CountrySeparated\$($_.Name).csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "CountrySeparated_IPV4"
$Country |
Where-Object { $_.version -EQ 'ipv4' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |

    Select-Object region, ip, prefixlength, state |
    Export-Csv -Path ".\csv\CountrySeparated\$($_.Name)_IPV4.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "CountrySeparated_IPV6"
$Country |
Where-Object { $_.version -EQ 'ipv6' } |
Group-Object -Property 'country' | ForEach-Object -Parallel {
    $_.Group |

    Select-Object region, ip, prefixlength, state |
    Export-Csv -Path ".\csv\CountrySeparated\$($_.Name)_IPV6.csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

#endregion CountrySeparated
