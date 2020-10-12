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

# Dates to search, comma separated
$dates = "20180822", "20180823"

# Volumes to search audit logs for, comma separated
$volumes = "PrimaryVolume", "Archive"

# String to search for
$searchstring = "Example/path"

# Folder to output results csv
$outfolder = "D:\audit\"

# Folder to store dated folders of raw audit logs
$rawauditfolder = "D:\audit\"

# Path to the local filer
$auditpath = "\\local-filer.domain.com\"

function Prepend-Text ($text) {
    process {
        ForEach-Object { $text + "," + $_ }
    }
}

$searchresults = @()

foreach ($volume in $volumes) {
    foreach ($date in $dates) {

        $localtemp = "$($rawauditfolder)$($date)-$($volume)\"
        if (!(Test-Path -Path $localtemp -PathType Container)) {

            New-Item -ItemType Directory -Force -Path $localtemp | Out-Null
            Get-ChildItem "$auditpath$volume\.nasuni\audit" | ForEach-Object {
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
            $searchresults += Select-String -InputObject $_ -Pattern $searchstring | Select-Object -ExpandProperty Line | Prepend-Text -text $volume | Prepend-Text -text $filername
        }
    }
}

if ($searchresults) {
    $outputfilename = "results-$($dates -join '-')-$($volumes -join '-')-$($searchstring).csv"
    [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object { $outputfilename = $outputfilename.Replace($_, '.') }
    $header = "filer", "volume", "timestamp(UTC)", "category", "event type", "path/from", "new path/to", "user", "group", "sid", "share/export name", "volume type", "client IP", "snapshot timestamp(UTC)", "shared link"
    $searchresults | ConvertFrom-Csv -Header $header | Sort-Object "timestamp(UTC)" | Export-Csv -Path "$outfolder$outputfilename" -NoTypeInformation
    Write-Output "Found $($searchresults.Count) lines for $searchstring on $date"
}
else {
    Write-Output "No results for $searchstring on dates $($dates -join '-')"
}
