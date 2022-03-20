[CmdletBinding()]
<#
.SYNOPSIS
     Collect and search Nasuni audit logs
.DESCRIPTION
     Collects all audit logs from specified dates, and then searches to find a specific string.
     Useful to finding what happened to a specific file or folder, when you don't know which filer the action took place on.
.NOTES
     Author     : Sean McGrath
.LINK
    https://github.com/wipash/ops-scripts
#>

Param (
    [Parameter()]
    [string[]] $Dates,
    [Parameter()]
    [string[]] $Volumes,
    [Parameter()]
    [string] $Search,
    [Parameter()]
    [string] $FilerPath,
    [Parameter()]
    [string] $OutputFolder = 'D:\audit\'
)

function Add-TextToPipelineInput ($text) {
    process {
        ForEach-Object { $text + ',' + $_ }
    }
}

$searchresults = @()

foreach ($volume in $Volumes) {
    foreach ($date in $Dates) {

        $localtemp = "$($OutputFolder)$($date)-$($volume)\"
        if (!(Test-Path -Path $localtemp -PathType Container)) {

            New-Item -ItemType Directory -Force -Path $localtemp | Out-Null
            Get-ChildItem "$FilerPath$volume\.nasuni\audit" | ForEach-Object {
                $filername = $_.Name
                $datefolder = "$($_.FullName)\$date"
                Get-ChildItem $datefolder -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Output "Getting $volume - $date - $filername"
                    $destinationname = "$($localtemp)\$($filername)-$($date)-$($volume)-$($_.Name)"
                    Copy-Item -Path $_.FullName -Destination $destinationname
                }
            }
        }

        Write-Output "Searching $volume - $date"
        Get-ChildItem $localtemp | ForEach-Object {
            $filername = $($_.Name).Substring(0, $($_.Name).IndexOf("-$date"))
            $searchresults += Select-String -InputObject $_ -Pattern $Search | Select-Object -ExpandProperty Line | Add-TextToPipelineInput -text $volume | Add-TextToPipelineInput -text $filername
        }
    }
}

if ($searchresults) {
    $outputfilename = "results-$($Dates -join '-')-$($Volumes -join '-')-$($Search).csv"
    [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object { $outputfilename = $outputfilename.Replace($_, '.') }
    $header = 'filer', 'volume', 'timestamp(UTC)', 'category', 'event type', 'path/from', 'new path/to', 'user', 'group', 'sid', 'share/export name', 'volume type', 'client IP', 'snapshot timestamp(UTC)', 'shared link'
    $searchresults | ConvertFrom-Csv -Header $header | Sort-Object 'timestamp(UTC)' | Export-Csv -Path "$OutputFolder$outputfilename" -NoTypeInformation
    Write-Output "Found $($searchresults.Count) lines for $Search on $date"
}
else {
    Write-Output "No results for $Search on dates $($Dates -join '-')"
}
