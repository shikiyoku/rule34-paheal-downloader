[CmdletBinding()]
Param
(
  [ValidateScript({Test-Path $_ -PathType 'Container'})]
  [string] $Path = "X:\pictures\rule34\"
)

Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"

$tagsArtist = Read-TagsFile "$PSScriptRoot\tags_artist.txt"
$tagsCharacter = Read-TagsFile "$PSScriptRoot\tags_character.txt"
$tagsExclude = Read-TagsFile "$PSScriptRoot\tags_exclude.txt"

$exclude = $tagsExclude + $tagsArtist + $tagsCharacter

# Tags count hash table
$tagsHash = @{}

# Get filenames
$fileNames = Get-ChildItem $path -Name -File #-Recurse

foreach ($fileName in $fileNames) {
  $tags = Get-TagsFromFileName -FileName $fileName
  foreach ($tag in $tags) {
    if ($exclude -notcontains $tag) {
      $tagsHash.Set_Item($tag, $tagsHash.Get_Item($tag) + 1)
    }
  }
}

$tagsHash.GetEnumerator() | Sort-Object -Descending Value  | Select-Object Key, Value | Export-Csv  -Path "Tags_Frequency.csv" -NoTypeInformation -Delimiter ";"