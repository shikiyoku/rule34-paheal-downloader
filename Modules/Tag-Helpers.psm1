$invalidFileNameChars = [IO.Path]::GetInvalidFileNameChars()
$idLength = 7
# Id end index
$tagsStartIndex = 10

function Read-TagsFile {
  Param
  (
    [Parameter(Mandatory = $True)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$Path
  )

  $commentMark = ";"

  $tags = Get-Content $Path | Where-Object {$_ -ne "" -and -not $_.StartsWith($commentMark)}

  return $tags
}

function Get-TagsFromFileName {
  Param
  (
    [Parameter(Mandatory = $True)]
    [string] $FileName
  )

  $length = $FileName.LastIndexOf(".") - $tagsStartIndex
  if ($length -lt 0) {
    $length = $FileName - $tagsStartIndex
  }

  # Cut off id and extension parts and split by space character
  $tags = $FileName.Substring($tagsStartIndex, $length).Split(" ")

  return $tags
}

function Get-IdFromFileName {
  Param
  (
    [Parameter(Mandatory = $True)]
    [string]$FileName
  )

  return $FileName.Substring(0, $idLength)
}

function Get-ValidFileName {
  Param(
    [Parameter(Mandatory)]
    [String] $FileName
  )

  # Remove invalid chars
  return ([char[]]$FileName | Where-Object { $invalidFileNameChars -notContains $_ }) -join ''
}