[CmdletBinding()]
Param (
  [int] $StartPage = 1,
  
  [ValidateScript({Test-Path $_ -PathType Container})]
  [string] $DestinationRoot = "C:\Download\rule34"
)

Import-Module "$PSScriptRoot\Modules\Get-Destination.psm1"
Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Categorize.psm1"
Import-Module "$PSScriptRoot\Modules\Invoke-WithRetry.psm1"

$pageUrlTemplate = "http://rule34.paheal.net/post/list/{0}"
$imageOnlyLinkText = "Image Only"

function Get-Feed {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory)]
    [int] $StartPage,
    
    [Parameter(Mandatory)]
    [string] $DestinationRoot
  )

  $stopIdFileName = "$($MyInvocation.ScriptName.Split(".")[0]).stopId.txt"
  # Subfolder with current date as name
  $destination = Get-Destination -Name (Get-Date -Format yyyy-MM-dd) -ParentFolder $DestinationRoot
  $errorsFile = Join-Path $destination "errors.csv"
  $imagesFile = Join-Path $destination "media.csv"

  # Check if stop id file exists and get stop id from it
  if ((-not $PSBoundParameters.ContainsKey('StopId')) -and (Test-Path $stopIdFileName -PathType Leaf)) {
    $StopId = Get-Content -LiteralPath $stopIdFileName -Tail 1
  }

  $loadMore = $true
  $pageNumber = $StartPage
  $images = [System.Collections.ArrayList]@()

  Write-Host "Collecting media URLs"

  if (Test-Path $imagesFile -PathType Leaf) {
    Write-Host "  Loading from $imagesFile"
    $images = Import-Csv -Path $imagesFile -Delimiter ";"
  }
  else {
    do {
      Write-Host "  Page #$pageNumber"

      $imageUrls = Get-PageImageUrls $pageNumber

      foreach ($imageUrl in $imageUrls) {
        $uri = [System.Uri]$imageUrl
        $fileName = Get-ValidFileName $uri.LocalPath.Split("/")[-1]
        $id = Get-IdFromFileName $fileName

        # Stop image found - stop downloading
        if ($id -eq $StopId) {
          $loadMore = $false
          break
        }

        $images.Add([PSCustomObject]@{Id = $id; Uri = $uri; FileName = $fileName}) | Out-Null
      }

      $pageNumber += 1
    } while ($loadMore)

    # Save images data
    $images | Export-Csv -Path $imagesFile -NoTypeInformation -Delimiter ";"
  }

  $imageCount = $images.Count;
  Write-Host "Downloading $imageCount media..."

  $webClient = New-Object System.Net.WebClient

  for ($imageIndex = 0; $imageIndex -lt $imageCount; $imageIndex++) {
    $imageNumber = $imageIndex + 1
    [int]$percentProcessed = ($imageNumber / $imageCount) * 100
    Write-Progress -Activity "Downloading media ($imageNumber/$imageCount)" -Status "$percentProcessed%" -PercentComplete ($percentProcessed)
    Save-Image $webClient $images[$imageIndex] $destination $errorsFile
  }

  $webClient.Dispose()

  # Remember new stop id
  Add-Content -LiteralPath $stopIdFileName -Value ([Environment]::NewLine + $images[0].Id)

  Move-TrashImages $destination
}

function Get-PageImageUrls {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory)]
    [int] $PageNumber
  )

  $pageUrl = $pageUrlTemplate -f $PageNumber

  $pageWebResponse = Invoke-WithRetry { Invoke-WebRequest -Uri $pageUrl }

  return $pageWebResponse | Select-Object -ExpandProperty Links | Where-Object innerText -eq $imageOnlyLinkText | Select-Object -ExpandProperty href
}

function Save-Image {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory)]
    [System.Net.WebClient] $webClient,

    [Parameter(Mandatory)]
    [PSCustomObject] $Image,

    [Parameter(Mandatory)]
    [string] $Destination,

    [Parameter(Mandatory)]
    [string] $ErrorsFile
  )

  $saveAs = Join-Path $Destination $Image.FileName

  try {
    Invoke-WithRetry { $webClient.DownloadFile($Image.Uri, $saveAs) }
  }
  catch {
    $Image | Add-Member –MemberType NoteProperty –Name Error –Value $_.Exception.Message
    $Image | Export-Csv -Path $ErrorsFile -Append  -NoTypeInformation -Delimiter ";"  -Encoding UTF8
  }
}

function Move-TrashImages {
  Param (
    [ValidateScript( {Test-Path $_ -PathType Container})]
    [string] $SrcPath
  )

  Write-Host "Moving trash images"

  $destPath = Get-Destination "trash" -ParentFolder $SrcPath
  $tags = Read-TagsFile "$PSScriptRoot\tags_trash.txt"

  Categorize -Path $SrcPath -Tags $tags -Destination $destPath
}

function Move-TrashImageBatch {
  Param (
    [ValidateScript( {Test-Path $_ -PathType Container})]
    [string] $PathRoot
  )

  $folders = Get-ChildItem -Path $PathRoot -Directory -Exclude "ready"
  foreach ($folder in $folders) { 
    Move-TrashImages $folder
  }
}

Get-Feed $StartPage $DestinationRoot
#Move-TrashImageBatch "C:\Download\rule34\"
#Move-TrashImages "C:\Download\rule34\2017-07-25\trash"