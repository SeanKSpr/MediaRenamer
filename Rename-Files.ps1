function Rename-Files  {
    param
    (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$false)][string]$NewNameForFiles,
        [switch]$Recurse
    )

    $folders = If ($Recurse) {Get-ChildItem -Path $Path -Directory} Else {, $Path}

    foreach ($folder in $folders) {
        $seasonNumber = $folder -replace '\D+(\d+)', '$1'
        Save-CurrentFileNames -Path $folder
        $files = Get-ChildItem -Path $folder.FullName | Where-Object {$_.Extension -eq ".mkv" -or $_.Extension -eq ".avi" -or $_.Extension -eq ".mp4"}
        $nameOfShow = Split-Path $folder -Leaf

        foreach($file in $files) {
            $fullFilePath = "$($folder.FullName)\\$file"

            $newFileName = If ($Recurse) { Rename-String -KinoFileName $file -NewShowName $NewNameForFiles -SeasonNumber $seasonNumber } 
                           Else { Rename-String -KinoFileName $file -NewShowName $NewNameForFiles } 

            if ($newFileName) { Rename-Item -LiteralPath $fullFilePath -NewName $newFileName }
        }
    }
}

function Rename-String {
    param
    (
        [Parameter(Mandatory=$true)][string]$KinoFileName,
        [Parameter(Mandatory=$false)][string]$NewShowName,
        [Parameter(Mandatory=$false)][string]$SeasonNumber
    )

    
    $captureGroups = Get-MediaGroups -MediaFile $kinoFileName
    
    $nameOfShow = If ($NewShowName) {$NewShowName} Else {$captureGroups[1]}
    $season = If ($captureGroups[2] -and $captureGroups[2].Success) {"S$($captureGroups[2])"} 
              ElseIf ($SeasonNumber) {"S$SeasonNumber"} 
              Else {""}

    $episode = $captureGroups[3]
    $extension = $captureGroups[4]
    
    $newFileName =  "$nameOfShow - $season" + "E$episode" + $extension -replace '\s+', ' '

    return $newFileName 
}

function Get-MediaGroups  {
    param 
    (
        [Parameter(Mandatory=$true)][string]$MediaFile
    )

    $pattern = '(?:(?:\[|\().*?(?:\]|\)))?(.*)\s*\-\s*(?:S(\d+))?E?(\d+)(?:[\-\w\s]*)[\(\[\w\s\]\)]*(.mkv|.mp4|.avi)$'
    $captureGroups = [regex]::Match($MediaFile, $pattern).captures.groups
    if (!$captureGroups) {
        $pattern = '(?:(?:\[|\().*?(?:\]|\)))?(.*?)[\s\-]*(\b\d+\b)\s*\-(?:[\s\w]+)\s*(?:(?:\[|\().*?(?:\]|\)))*(.mkv|.avi|.mp4)$'
        $captureGroups = [regex]::Match($MediaFile, $pattern).captures.groups
    }

    return $captureGroups
}

function Save-CurrentFileNames {
    param
    (
        [Parameter(Mandatory=$true)][string]$Path
    )
    
    $outfile = "$Path\\OriginalNames.txt"

    if (!(Test-Path $outfile)) {
        Get-ChildItem -Path $Path | Format-List -Property Name | Out-File $outfile
    }   
}