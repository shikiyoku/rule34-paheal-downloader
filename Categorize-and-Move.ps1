[CmdletBinding()]
Param()

Import-Module "$PSScriptRoot\Modules\Config-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Get-Destination.psm1"
Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Categorize.psm1"

$config = Read-Config -RequiredParams @("SrcPath", "DestPath", "TagsFilePath")

function Move-ToTypeSubfolders {
  Param
  (
    [Parameter(Mandatory)]
    [string] $SrcPath
  )

  $clusters = 
  @([pscustomobject]@{subFolder = "_animated"; filter = "*.gif"},
    [pscustomobject]@{subFolder = "_video"; filter = @("*.mp4", "*.webm")})
  
  $typeFolders = [System.Collections.ArrayList]@()

  $typeFolders.Add($SrcPath) | Out-Null

  Write-Host "Clustering by file types...."

  # Move files with specified types to specified subfolders
  foreach ($cluster in $clusters) {
    $typeFolders.Add((Join-Path $SrcPath $cluster.subFolder)) | Out-Null
    $clusterFiles = Get-ChildItem -Path $SrcPath\* -File -Include $cluster.filter
    
    if ($clusterFiles.length -gt 0) {
      $clusterPath = Get-Destination $cluster.subFolder $SrcPath
      Write-Host "Moving to $($clusterPath)"
      $clusterFiles | Move-Item -Destination $clusterPath
    }
  }

  return $typeFolders
}

function Move-ToTagSubfolders {
  Param
  (
    [Parameter(Mandatory)]
    [System.Collections.ArrayList] $FolderPaths,

    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string] $TagsFilePath
  )

  Write-Host "Clustering by tags..."

  $tags = Read-TagsFile $TagsFilePath

  foreach ($folderPath in $FolderPaths) {
    if (Test-Path $folderPath) {
      Categorize -Path $folderPath -Tags $tags
    }
  }
}

if (-not (Test-Path $config.DestPath -PathType 'Container')) {
  Write-Error "$($config.DestPath) doesn't exist"
  Exit
}

if (-not (Test-Path $config.SrcPath -PathType 'Container')) {
  Write-Error "$($config.SrcPath) doesn't exist"
  Exit
}

$typeFolders = Move-ToTypeSubfolders $config.SrcPath
Move-ToTagSubfolders $typeFolders $config.TagsFilePath

if ($config.SrcPath -ne $config.DestPath) {
  Write-Host "Moving to destination"

  Move-Item -Path "$($config.SrcPath)\*" -Destination $config.DestPath
}
