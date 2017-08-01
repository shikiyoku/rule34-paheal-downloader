[CmdletBinding()]
Param
(
  [ValidateScript( {Test-Path $_ -PathType 'Container'})]
  [string] $SrcPath = "X:\pictures\rule34",#"C:\Download\rule34\ready",

  [ValidateScript( {Test-Path $_ -PathType 'Container'})]
  [string] $DestPath = "X:\pictures\rule34",

  [ValidateScript( {Test-Path $_ -PathType Leaf})]
  [string] $TagsFilePath = ".\tags_series.txt"
)

Import-Module "$PSScriptRoot\Modules\Get-Destination.psm1"
Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Categorize.psm1"

$clusters = 
@([pscustomobject]@{subFolder = "_animated"; filter = "*.gif"},
  [pscustomobject]@{subFolder = "_video"; filter = @("*.mp4", "*.webm")})

# Remove duplicate downloads (not actual anymore)
#Remove-Item -Path $SrcPath\* -Include @("*(1)*", "*(2)*")

$clusteredFolders = [System.Collections.ArrayList]@()

$clusteredFolders.Add($SrcPath) | Out-Null

Write-Host "Clustering by file types...."

# Move files with specified types to specified subfolders
foreach ($cluster in $clusters) {
  $clusteredFolders.Add((Join-Path $SrcPath $cluster.subFolder)) | Out-Null
  $clusterFiles = Get-ChildItem -Path $SrcPath\* -File -Include $cluster.filter
  
  if ($clusterFiles.length -gt 0) {
    $clusterPath = Get-Destination $cluster.subFolder $SrcPath
    Write-Host "Moving to $($clusterPath)"
    $clusterFiles | Move-Item -Destination $clusterPath
  }
}

Write-Host "Clustering by tags..."

$tags = Read-TagsFile $TagsFilePath

foreach ($clusteredFolder in $clusteredFolders) {
  if (Test-Path $clusteredFolder) {
    Categorize -Path $clusteredFolder -Tags $tags
  }
}

if ($SrcPath -ne $DestPath) {
  Write-Host "Moving to destination"

  Move-Item -Path $SrcPath\* -Destination $DestPath
}
