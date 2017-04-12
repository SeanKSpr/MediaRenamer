<#
.SYNOPSIS

Renames the media files at the provided path (or in the immediate subdirectories of the provided path if the Recurse switch is specified) into a format that
is Plex friendly such as "Show Name - 1.mkv" and "Show Name - S1E1.mkv" in the case that season information is specified through the directory structure. In addition,
the original names of the files within the directories will be saved to a text file in order to potentially revert the rename operation.

.DESCRIPTION

In the case that the Recurse isn't specified, the media files (.mkv, .avi, .mp4) located within the directory at the specified path are renamed into a Plex friendly format.
This format takes the form of "Show Name - 1.mkv" and "Show Name - S1E1.mkv". 

If Recurse is specified, then the provided path is assumed to be a directory containing sub-directories denoting seasons. The name of these folders is used to append the season information
to the contained files during the renamining process (for example a folder named Season 2 will cause the inner files to have S2 as part of their renamed file name).

Currently a text file is also generated containing the original names of the files within the directory. A method will be provided in the future to parse this file and change the names of the 
media files to their original names. 

.PARAMETER Path 

The path to a directory containing media files or immediate subdirectories containing media files to be renamed.

.PARAMETER NewNameForFiles

This is an optional string parameter that will be used to modify the name of the show rather than use the name of the show determined during the parsing process. For instance, passing "Mystery Show" here
while renaming a directory of media files named "Non-mystery Show" will result in all the files being renamed to "Mystery Show". In particular, this is useful for renaming shows from a localized name to
the original name or vice versa.

.EXAMPLE

Rename all the media files at the provided path with the default process. As an example the first file will be renamed to "Name of Show - 1.mkv"

FOLDER STRUCTURE

MediaFolder
    - [MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 2 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 3 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 4 [Quality information][Hash code].mkv

Rename Files -Path C:\MediaFolder 

.EXAMPLE 

Rename all the media files in the immediate subdirectories of the provided path with the default process. As an example the first file will be renamed to "Name of Show - S01E01.mkv"

MediaFolder
    - Season 1
        - [MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 2 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 3 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 4 [Quality information][Hash code].mkv

Rename Files -Path C:\MediaFolder -Recurse

.EXAMPLE

Rename all the media files in the immediate subdirectories of the provided path with a new name. As an example the first file will be renamed to "Localized Show Name - S01E01.mkv"

MediaFolder
    - Season 1
        - [MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 2 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 3 [Quality information][Hash code].mkv
        - [MetaInfo]Name of Show - 4 [Quality information][Hash code].mkv

Rename Files -Path C:\MediaFolder -NewNameForFiles "Localized Show Name" -Recurse 

.NOTES

#>
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

<#

.SYNOPSIS

Renames a media file string to a Plex friendly format

.DESCRIPTION

This method will rename the string provided as the KinoFileName parameter into a Plex friendly format. For example "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv" will be renamed
to just "Name of Show - 1.mkv" if no other parameters are specified. 

Passing a value for NewShowName will rename whatever the show is called to the name you provide. This helps for changing the name of a show between a localized name and the original name.

The SeasonNumber parameter will append the season to the final string to create something like "Name of Show - S01E01.mkv"

.PARAMETER KinoFileName

The media file string to be renamed in its entirety such as "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv"

.PARAMETER NewShowNAme

Optional parameter that will be used to replace the name of the show in the final string

.PARAMETER SeasonNumber

Optional parameter that will be used to append the season of the show to the final string

.EXAMPLE

The following will return "Name of Show - 1"

Rename-String -KinoFileName "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv" 

.EXAMPLE

The following will return "Localized Show Name - 1"

Rename-String -KinoFileName "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv" -NewShowName "Localized Show Name"

.EXAMPLE

The following will return "Localized Show Name - S02E01"

Rename-String -KinoFileName "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv" -NewShowName "Localized Show Name" -SeasonNumber 2

#>
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

<#

.SYNOPSIS

Returns an array of the important parts of the provided string such as the name of the show, season number, episode number, and file extension.

.DESCRIPTION

Uses regular expression patterns to generate a capture group of the relevant portions of the string. These elements include the name of the show, season number, episode number, and file extension.

The information is returned in an array of capture groups from the regex library
Array[0] - The original name of the file
Array[1] - The name of the show
Array[2] - The season number (it's normal for this to not be found)
Array[3] - The episode number
Array[5] - The file extension

.PARAMETER MediaFile

The media file string that will be parsed.

.EXAMPLE

Returns the following Array breakdown.

Array[0] - [MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv
Array[1] - Name of Show
Array[2] - null
Array[3] - 1
Array[5] - .mkv

Get-MediaGroups "[MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv"

#>
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

<#
.SYNOPSIS
Examines the names of the files and directories in the provided path and saves them to a text file called OriginalNames.txt at the same path.

.DESCRIPTION
Examines the names of the files and directories in the provided path and saves them to a text file called OriginalNames.txt at the same path.

The OriginalNames.txt file is only generated if one isn't found at the provided path. This is to help deter accidentally losing the old file names.

This method exists to facilitate future reversion capabilities to undo what was done by the Rename-Files method.

.PARAMETER Path

The path to the directory in which the names of the files and directories contained within will be saved to a text file in the same directory.

.EXAMPLE

The following will write out a text file with the names of the files contained in the follow MediaFolder directory

MediaFolder
    - [MetaInfo]Name of Show - 1 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 2 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 3 [Quality information][Hash code].mkv
    - [MetaInfo]Name of Show - 4 [Quality information][Hash code].mkv

Save-CurrentFileNames -Path C:\MediaFolder

#>
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