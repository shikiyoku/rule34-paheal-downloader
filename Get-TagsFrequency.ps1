[CmdletBinding()]
Param()

Import-Module "$PSScriptRoot\Modules\Config-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"

$config = Read-Config -RequiredParams @("Path", "TagFilePaths")

if (-not (Test-Path $config.Path -PathType 'Container')) {
  Write-Error "$($config.Path) doesn't exist"
  Exit
}

# tags to exclude
$exclude = @()
$tagFilePaths = $config.TagFilePaths.Split("|")

foreach ($tagFile in $tagFilePaths) {
  $tagFile = $tagFile.Trim()
  if (Test-Path $tagFile -PathType Leaf) {
    $exclude = $exclude + (Read-TagsFile $tagFile)
  }
}

# Tags count hash table
$tagsHash = @{}
# Get filenames
$fileNames = Get-ChildItem $config.Path -Name -File #-Recurse

foreach ($fileName in $fileNames) {
  $tags = Get-TagsFromFileName -FileName $fileName
  foreach ($tag in $tags) {
    if ($exclude -notcontains $tag) {
      $tagsHash.Set_Item($tag, $tagsHash.Get_Item($tag) + 1)
    }
  }
}

$tagsHash.GetEnumerator() | Sort-Object -Descending Value  | Select-Object Key, Value | Export-Csv  -Path "Tags_Frequency.csv" -NoTypeInformation -Delimiter ";"