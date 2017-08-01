[CmdletBinding()]
Param
(
  [ValidateScript({Test-Path $_ -PathType 'Container'})]
  [string] $Path = "X:\pictures\rule34_get_tags"
)

Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"
#Import-Module "$PSScriptRoot\Modules\Invoke-WithRetry.psm1"
Import-Module "$PSScriptRoot\Modules\Get-Destination.psm1"

$postUrlTemplate = "http://rule34.paheal.net/post/view/{0}"
$fileNameTemplate = "{0} - {1}{2}"
$tagsInputName = "tag_edit__tags"

$files = Get-ChildItem -Path $Path\* -File -Include @("*.mp4", "*.webm", "*.jpg", "*.png", "*.jpeg", "*.gif")
$filesCount = $files.Count
$destination = Get-Destination "updated" $Path
$errorPath = Get-Destination "erroneous" $Path
$errorsFile = Join-Path $errorPath "errors.csv"

for ($fileIndex = 0; $fileIndex -lt $filesCount; $fileIndex++) {
  $fileNumber = $fileIndex + 1
  [int]$percentProcessed = ($fileNumber / $filesCount) * 100
  Write-Progress -Activity "Updating tags ($fileNumber/$filesCount)" -Status "$percentProcessed%" -PercentComplete ($percentProcessed)
  $file = $files[$fileIndex]

  $id = Get-IdFromFileName $file.Name
  $postUrl = $postUrlTemplate -f $id

  try {
    $pageWebResponse = Invoke-WebRequest -Uri $postUrl
    #Invoke-WithRetry { Invoke-WebRequest -Uri $postUrl } -MaxRetries 2
    $tagsSubstring = $pageWebResponse | Select-Object -ExpandProperty InputFields | Where-Object name -eq $tagsInputName | Select-Object -ExpandProperty value
    $newFileName = Get-ValidFileName ($fileNameTemplate -f $id, $tagsSubstring, $file.Extension)

    Move-Item $file -Destination (Join-Path $destination $newFileName) -Force
    #Rename-Item $file -NewName $newFileName
  }
  catch {
    $errorObject = [PSCustomObject]@{File = $file.Name; Error = $_.Exception.Message}
    $errorObject | Export-Csv -Path $errorsFile -Append  -NoTypeInformation -Delimiter ";"  -Encoding UTF8
    Move-Item $file -Destination $errorPath -Force
  }
}
