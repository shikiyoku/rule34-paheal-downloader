function Categorize {
  [CmdletBinding(SupportsShouldProcess=$True)]
  Param
  (
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $Path = "X:\pictures\rule34",

    [Parameter(Mandatory = $True)]
    [string[]] $Tags,

    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $Destination
  )

  $tagAliasMarker = ":"

  Import-Module "$PSScriptRoot\Get-Destination.psm1"

  if(!$PSBoundParameters.ContainsKey('Destination')) {
    $Destination = $Path
  }

  foreach ($tag in $Tags) {
    $tagFolder = $tag
    $includeTerms = "* $tag*"

    # There are aliases tags specified
    if ($tag.Contains($tagAliasMarker)) {
      $tagParts = $tag.Split($tagAliasMarker)

      $tagFolder = $tagParts[0].Trim()
      # Wrap aliases tags in tag match term
      $includeTerms = $tagParts[1].Trim().Split(" ") | ForEach-Object { "* $_*" }
    }

    $tagFiles = Get-ChildItem -Path $Path\* -File -Include $includeTerms

    if ($tagFiles.length -gt 0) {
      $tagPath = Get-Destination $tagFolder $Destination
      Write-Host "Moving to $($tagPath)"
      $tagFiles | Move-Item -Destination $tagPath
    }
  }
}
