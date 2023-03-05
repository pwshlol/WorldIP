#region Startup

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$Directories = [ordered]@{
    Sources                  = ".\Sources"
    Lists                    = ".\Lists"
    Misc                     = ".\Lists\Misc"
    IANA                     = ".\Lists\IANA"
    IANA_Global              = ".\Lists\IANA\Global"
    IANA_Separated           = ".\Lists\IANA\Separated"
    IANA_Separated_State     = ".\Lists\IANA\Separated\State"
    Region                   = ".\Lists\Region"
    Region_Global            = ".\Lists\Region\Global"
    Region_Separated         = ".\Lists\Region\Separated"
    Region_Separated_Region  = ".\Lists\Region\Separated\Region"
    Region_Separated_State   = ".\Lists\Region\Separated\State"
    Region_Separated_Country = ".\Lists\Region\Separated\Country"
}
foreach ($directory in $Directories.Values) {
    if (!(Test-Path $directory)) { $null = New-Item $directory -ItemType Directory -Force }
}

$Sources = [ordered]@{
    'delegated-iana-latest'             = 'https://ftp.apnic.net/stats/iana/delegated-iana-latest'
    'delegated-afrinic-extended-latest' = 'https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-extended-latest'
    'delegated-apnic-extended-latest'   = 'https://ftp.apnic.net/stats/apnic/delegated-apnic-extended-latest'
    'delegated-arin-extended-latest'    = 'https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest'
    'delegated-lacnic-extended-latest'  = 'https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-extended-latest'
    'delegated-ripencc-extended-latest' = 'https://ftp.ripe.net/ripe/stats/delegated-ripencc-extended-latest'
    'asnames'                           = 'https://ftp.ripe.net/ripe/asnames/asn.txt'
}

#endregion Startup

#region Download_Sources

Write-Output "Download_Sources"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$Sources.GetEnumerator() | ForEach-Object -Parallel {
    try {
        Write-Output "$($_.Key) = $($_.Value)"
        $content = Invoke-RestMethod -Uri $_.Value
        Set-Content ".\Sources\$($_.Key).txt" -Value $content -Force
    } catch {
        Write-Output "Error downloading $($_.Value)"
    }
} -ThrottleLimit 7

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Download_Sources In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Download_Sources

#region Objects

[PSCustomObject]$World = [ordered]@{
    ASN_IANA         = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    ASN_Region       = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    ASN_Oganizations = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Reserved    = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Available   = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    IANA_Allocated   = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Reserved  = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Available = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Allocated = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
    Region_Assigned  = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
}

#endregion Objects

#region ASN_Process

Write-Output "ASN_Process"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$file = Get-Content ".\Sources\asnames.txt"
$file | ForEach-Object {
    if (-not ([string]::IsNullOrEmpty($_))) {
        $split = $_ -split ' '
        $number = $split[0]
        $country = $split[-1]
        $entry = $_ -replace "^$number\s|\s$country$", ""
        $entry = $entry.Substring(0, $entry.Length - 1)
        ($World.ASN_Oganizations).Add(
            @{
                'number'  = $number
                'org'     = $entry
                'country' = $country
            }
        )
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("ASN_Process In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion ASN_Process

#region ASN_Feed

Write-Output "ASN_Feed"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$Sources.GetEnumerator() | ForEach-Object -Parallel {
    if ($_.Key -match 'delegated' -and $_.Key -match 'iana') {
        Write-Output "ASN Feeding $($_.Key)"
        $null = Get-Content ".\Sources\$($_.Key).txt" | ForEach-Object {
            $split = $_.Split('|')
            if ($_ -match 'asn' -and $_ -notmatch 'summary|available|reserved') {
                ($using:World.ASN_IANA).Add(
                    @{
                        'number' = $split[3]
                        'state'  = $split[6]
                        'region' = $split[7]
                    }
                )
            }
        }
    }
    if ($_.Key -match 'delegated' -and $_.Key -notmatch 'iana' ) {
        Write-Output "ASN Feeding $($_.Key)"
        $null = Get-Content ".\Sources\$($_.Key).txt" | ForEach-Object {
            $split = $_.Split('|')
            if ($_ -match 'asn' -and $_ -notmatch 'summary|available|reserved') {
                ($using:World.ASN_Region).Add(
                    @{
                        'number' = $split[3]
                        'state'  = $split[6]
                        'id'     = $split[7]
                    }
                )
            }
        }
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("ASN_Feed In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion ASN_Feed

#region CIDR_Feed

Write-Output "CIDR_Feed"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$Sources.GetEnumerator() | ForEach-Object -Parallel {
    if ($_.Key -match 'delegated' -and $_.Key -match 'iana') {
        Write-Output "CIDR_Feed $($_.Key)"
        $null = Get-Content ".\Sources\$($_.Key).txt" | Where-Object { $_ -match 'ipv4|ipv6' } | ForEach-Object {
            $split = $_.Split('|')
            if ($_ -match 'ipv4|ipv6' ) {

                if ($split[6] -eq 'Reserved') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Reserved).Add(
                                @{
                                    'region'       = "*"
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.IANA_Reserved).Add(
                                @{
                                    'region'       = "*"
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                    }
                }

                if ($split[6] -eq 'allocated') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Allocated).Add(
                                @{
                                    'region'       = $split[7]
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.IANA_Allocated).Add(
                                @{
                                    'region'       = $split[7]
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                    }
                }

                if ($split[6] -eq 'available') {
                    switch ($split[2]) {
                        'ipv4' {
                            ($using:World.IANA_Available).Add(
                                @{
                                    'region'       = "*"
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                        'ipv6' {
                            ($using:World.IANA_Available).Add(
                                @{
                                    'region'       = "*"
                                    'country'      = "*"
                                    'version'      = $split[2]
                                    'ip'           = $split[3]
                                    'prefixlength' = $split[4]
                                    'state'        = $split[6]
                                    'id'           = "*"
                                    'orgs'         = "*"
                                    'orgsflat'     = "*"
                                }
                            )
                        }
                    }
                }

            }
        }
    }
    if ($_.Key -match 'delegated' -and $_.Key -notmatch 'iana' ) {
        Write-Output "CIDR_Feed $($_.Key)"
        $null = Get-Content ".\Sources\$($_.Key).txt" | Where-Object { $_ -match 'ipv4|ipv6' } | ForEach-Object {
            $split = $_.Split('|')

            if ($split[6] -eq 'Reserved') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Region_Reserved).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = "*"
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                                'id'           = "*"
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                    'ipv6' {
                        ($using:World.Region_Reserved).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = "*"
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                                'id'           = "*"
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                }
            }

            if ($split[6] -eq 'allocated') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Region_Allocated).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                                'id'           = $split[7]
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                    'ipv6' {
                        ($using:World.Region_Allocated).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                                'id'           = $split[7]
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                }
            }

            if ($split[6] -eq 'assigned') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Region_Assigned).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                                'id'           = $split[7]
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                    'ipv6' {
                        ($using:World.Region_Assigned).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = $split[1]
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                                'id'           = $split[7]
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                }
            }

            if ($split[6] -eq 'available') {
                switch ($split[2]) {
                    'ipv4' {
                        ($using:World.Region_Available).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = "*"
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = [string][math]::Round((32 - [Math]::Log($split[4], 2)))
                                'state'        = $split[6]
                                'id'           = "*"
                                'orgs'         = "*"
                                'orgsflat'     = "*"
                            }
                        )
                    }
                    'ipv6' {
                        ($using:World.Region_Available).Add(
                            @{
                                'region'       = $split[0]
                                'country'      = "*"
                                'version'      = $split[2]
                                'ip'           = $split[3]
                                'prefixlength' = $split[4]
                                'state'        = $split[6]
                                'id'           = "*"
                                'orgs'         = "*"
                                'orgsflat'     = "*"

                            }
                        )
                    }
                }
            }
        }
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("CIDR_Feed In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion CIDR_Feed

#region ID_Numbers

Write-Output "ID_Numbers"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$ASN_ORG = [hashtable]::new()
$World.ASN_Oganizations | ForEach-Object {
    $key = $_.number
    $ASN_ORG[$key] = $_
}
$ASN_ID = [Hashtable]::new()
foreach ($Item in $World.ASN_Region) {
    if ($ASN_ID.ContainsKey($Item.id)) {
        if (-not ($ASN_ID[$Item.id] -contains $Item.Number)) {
            $ASN_ID[$Item.id] += $Item.Number
        }
    } else {
        $ASN_ID[$Item.id] = @($Item.Number)
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("ID_Numbers In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion ID_Numbers

#region Numbers_Orgs

Write-Output "Numbers_Orgs"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$ID_ORG_JSON = @{}
foreach ($item in $ASN_ID.GetEnumerator()) {
    $id = $item.Key
    $numbers = $item.Value
    $orgs = foreach ($number in $numbers) {
        if ($ASN_ORG.ContainsKey($number)) {
            $org = $ASN_ORG[$number]
            @{
                number  = $org.number
                country = $org.country
                org     = $org.org
            }
        }
    }
    $ID_ORG_JSON[$id] = $orgs
}
$ID_ORG_CSV = @{}
foreach ($item in $ASN_ID.GetEnumerator()) {
    $id = $item.Key
    $numbers = $item.Value
    $buffer = ""
    $orgs = foreach ($number in $numbers) {
        if ($ASN_ORG.ContainsKey($number)) {
            $org = $ASN_ORG[$number]
            $buffer = $buffer + "[$($org.number);$($org.country);$($org.org)]"
        }
    }
    $buffer = $buffer -replace ",", " "
    $buffer = $buffer -replace '"', " "
    $ID_ORG_CSV[$id] = $buffer
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Numbers_Orgs In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Numbers_Orgs

#region Inject_Orgs

Write-Output "Inject_Orgs"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

$World.Region_Allocated + $World.Region_Assigned | ForEach-Object -ThrottleLimit 16 -Parallel {
    $item_id = $_.id
    if (($using:ID_ORG_JSON).ContainsKey($item_id)) {
        $get = ($using:ID_ORG_JSON)[$item_id]
        $_.orgs = $get
        $get = ($using:ID_ORG_CSV)[$item_id]
        $_.orgsflat = $get
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Inject_Orgs In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Injecting Orgs

#region Sorting

Write-Output "Sorting"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

Write-Output "Sorting_IANA_Reserved"
$World.IANA_Reserved = $World.IANA_Reserved |
Sort-Object version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_IANA_Available"
$World.IANA_Available = $World.IANA_Available |
Sort-Object {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_IANA_Allocated"
$World.IANA_Allocated = $World.IANA_Allocated |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_Region_Reserved"
$World.Region_Reserved = $World.Region_Reserved |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_Region_Available"
$World.Region_Available = $World.Region_Available |
Sort-Object region, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_Region_Allocated"
$World.Region_Allocated = $World.Region_Allocated |
Sort-Object region, country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

Write-Output "Sorting_Region_Assigned"
$World.Region_Assigned = $World.Region_Assigned |
Sort-Object region, country, version, {
    if ($_.version -eq 'ipv4') {
        $_.ip -as [version]
    } else {
        [int64]('0x' + $_.ip.Replace(":", ""))
    }
}

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Sorting In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Sorting

#region Export_Misc

Write-Output "Export_Misc"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

Write-Output "Export_ASN_IANA"
$ToExport = $World.ASN_IANA |
Select-Object number, region, state
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Misc)\ASN_IANA.json"
$ToExport | Export-Csv -Path "$($Directories.Misc)\ASN_IANA.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_ASN_Region"
$ToExport = $World.ASN_Region |
Select-Object number, state, id
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Misc)\ASN_Region.json"
$ToExport | Export-Csv -Path "$($Directories.Misc)\ASN_Region.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_ASN_Oganizations"
$ToExport = $World.ASN_Oganizations |
Select-Object number, country, org
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Misc)\ASN_Oganizations.json"
$ToExport | Export-Csv -Path "$($Directories.Misc)\ASN_Oganizations.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Export_Misc Sorting In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Export_Misc

#region Export_IANA

Write-Output "Export_IANA"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

Write-Output "Export_IANA_Reserved"
$ToExport = $World.IANA_Reserved |
Select-Object ip, prefixlength
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.IANA_Separated_State)\IANA_Reserved.json"
$ToExport | Export-Csv -Path "$($Directories.IANA_Separated_State)\IANA_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_IANA_Available"
$ToExport = $World.IANA_Available |
Select-Object ip, prefixlength
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.IANA_Separated_State)\IANA_Available.json"
$ToExport | Export-Csv -Path "$($Directories.IANA_Separated_State)\IANA_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_IANA_Allocated"
$ToExport = $World.IANA_Allocated |
Select-Object region, ip, prefixlength
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.IANA_Separated_State)\IANA_Allocated.json"
$ToExport | Export-Csv -Path "$($Directories.IANA_Separated_State)\IANA_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_IANA_Global"
$ToExport = $World.IANA_Reserved + $World.IANA_Available + $World.IANA_Allocated |
Select-Object region, ip, prefixlength, state
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.IANA_Global)\IANA_Global.json"
$ToExport | Export-Csv -Path "$($Directories.IANA_Global)\IANA_Global.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Export_IANA In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Export_IANA

#region Export_Region

Write-Output "Export_Region"
$Start = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"

Write-Output "Export_Region_Reserved"
$ToExport = $World.Region_Reserved |
Select-Object region, version, ip, prefixlength
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Region_Separated_State)\Region_Reserved.json"
$ToExport | Export-Csv -Path "$($Directories.Region_Separated_State)\Region_Reserved.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_Region_Available"
$ToExport = $World.Region_Available |
Select-Object region, version, ip, prefixlength
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Region_Separated_State)\Region_Available.json"
$ToExport | Export-Csv -Path "$($Directories.Region_Separated_State)\Region_Available.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_Region_Allocated"
#$ToExport = $World.Region_Allocated |
#Select-Object region, country, version, ip, prefixlength, orgs
#$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Region_Separated_State)\Region_Allocated.json"
$ToExport = $World.Region_Allocated |
Select-Object region, country, version, ip, prefixlength, orgsflat
$ToExport | Export-Csv -Path "$($Directories.Region_Separated_State)\Region_Allocated.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_Region_Assigned"
$ToExport = $World.Region_Assigned |
Select-Object region, country, version, ip, prefixlength, orgs
$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Region_Separated_State)\Region_Assigned.json"
$ToExport = $World.Region_Assigned |
Select-Object region, country, version, ip, prefixlength, orgsflat
$ToExport | Export-Csv -Path "$($Directories.Region_Separated_State)\Region_Assigned.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_Region_Global"
#$ToExport = $World.Region_Reserved + $World.Region_Available + $World.Region_Allocated + $World.Region_Assigned |
#Select-Object region, country, version, ip, prefixlength, state, orgs
#$ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($Directories.Region_Global)\Region_Global.json"
$ToExport = $World.Region_Reserved + $World.Region_Available + $World.Region_Allocated + $World.Region_Assigned |
Select-Object region, country, version, ip, prefixlength, state, orgsflat
$ToExport | Export-Csv -Path "$($Directories.Region_Global)\Region_Global.csv" -NoTypeInformation -UseQuotes AsNeeded -Force

Write-Output "Export_Region_Region"
$World.Region_Reserved + $World.Region_Available + $World.Region_Allocated + $World.Region_Assigned |
Group-Object -Property 'region' |
ForEach-Object -Parallel {
    $ToExport = $_.Group |
    Select-Object country, version, ip, prefixlength, state, orgs
    $ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($using:Directories.Region_Separated_Region)\$($_.Name).json"
    $ToExport = $_.Group |
    Select-Object country, version, ip, prefixlength, state, orgsflat
    $ToExport | Export-Csv -Path "$($using:Directories.Region_Separated_Region)\$($_.Name).csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

Write-Output "Export_Region_Country"
$World.Region_Allocated + $World.Region_Assigned |
Group-Object -Property 'country' |
ForEach-Object -Parallel {
    $ToExport = $_.Group |
    Select-Object region, version, ip, prefixlength, state, orgs
    $ToExport | ConvertTo-Json -Depth 99 -Compress | Out-File "$($using:Directories.Region_Separated_Country)\$($_.Name).json"
    $ToExport = $_.Group |
    Select-Object region, version, ip, prefixlength, state, orgsflat
    $ToExport | Export-Csv -Path "$($using:Directories.Region_Separated_Country)\$($_.Name).csv" -NoTypeInformation -UseQuotes AsNeeded -Force
} -ThrottleLimit 16

$End = Get-Date -AsUTC -UFormat "%Y-%m-%d %H:%M:%S"
$Start_format = [datetime]$Start
$End_format = [datetime]$End
Write-Output ("Export_Region In {0} Minutes and {1} Seconds" -f $(($End_format - $Start_format).Minutes), $(($End_format - $Start_format).Seconds))

#endregion Export_Region
