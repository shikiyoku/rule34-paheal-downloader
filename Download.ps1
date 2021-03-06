﻿[CmdletBinding()]
Param()

Import-Module "$PSScriptRoot\Modules\Config-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Get-Destination.psm1"
Import-Module "$PSScriptRoot\Modules\Tag-Helpers.psm1"
Import-Module "$PSScriptRoot\Modules\Categorize.psm1"
Import-Module "$PSScriptRoot\Modules\Invoke-WithRetry.psm1"

$config = Read-Config -RequiredParams @("StartPage","DestinationRoot","StopId","TrashTagsFile","ShutdownPC")

$pageUrlTemplate = "http://rule34.paheal.net/post/list/{0}"
$imageOnlyLinkText = "Image Only"

function Get-Feed {
  Param (
    [Parameter(Mandatory)]
    [int] $StartPage,
    
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $DestinationRoot,

    [Parameter(Mandatory)]
    [int] $StopId,

    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string] $TrashTagsFile
  )

  # Subfolder with current date as name
  $destination = Get-Destination -Name (Get-Date -Format yyyy-MM-dd) -ParentFolder $DestinationRoot
  $errorsFile = Join-Path $destination "errors.csv"
  $imagesFile = Join-Path $destination "media.csv"

  $loadMore = $true
  $pageNumber = $StartPage
  $images = [System.Collections.ArrayList]@()

  Write-Host "Collecting media URLs"

  if (Test-Path $imagesFile -PathType Leaf) {
    Write-Host "  Loading from $imagesFile"
    $images = Import-ImagesFile $imagesFile
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
    Export-ImagesFile $imagesFile $images
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

  Move-TrashImages $destination $TrashTagsFile

  # Return new StopId
  return $images[0].Id
}

function Get-PageImageUrls {
  Param (
    [Parameter(Mandatory)]
    [int] $PageNumber
  )

  $pageUrl = $pageUrlTemplate -f $PageNumber

  $pageWebResponse = Invoke-WithRetry { Invoke-WebRequest -Uri $pageUrl }

  return $pageWebResponse | Select-Object -ExpandProperty Links | Where-Object innerText -eq $imageOnlyLinkText | Select-Object -ExpandProperty href
}

function Import-ImagesFile {
  Param (
    [Parameter(Mandatory)]
    $ImagesFile
  )

  Import-Csv -Path $ImagesFile -Delimiter ";"
}

function Export-ImagesFile {
  Param (
    [Parameter(Mandatory)]
    $ImagesFile,

    [Parameter(Mandatory)]
    $Images,

    [switch] $Append
  )

  $Images | Export-Csv -Path $ImagesFile -NoTypeInformation -Delimiter ";"  -Encoding UTF8 -Append:$Append
}

function Save-Image {
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
    Export-ImagesFile $ErrorsFile $Image -Append
  }
}

function Move-TrashImages {
  Param (
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $SrcPath,

    [Parameter(Mandatory)]
    [string] $TrashTagsFile
  )

  Write-Host "Moving trash images"

  $destPath = Get-Destination "trash" -ParentFolder $SrcPath
  $tags = Read-TagsFile $TrashTagsFile

  Categorize -Path $SrcPath -Tags $tags -Destination $destPath
}

function Move-TrashImageBatch {
  Param (
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $PathRoot
  )

  $folders = Get-ChildItem -Path $PathRoot -Directory -Exclude "ready"
  foreach ($folder in $folders) { 
    Move-TrashImages $folder $config.TrashTagsFile
  }
}

function Get-MissingFiles {
   Param (
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string] $Path
  )

  $images = Import-ImagesFile (Join-Path $Path "media.csv")
  $missingImages = [System.Collections.ArrayList]@()

  $imageCount = $images.Count;
  for ($imageIndex = 0; $imageIndex -lt $imageCount; $imageIndex++) {
    $imageNumber = $imageIndex + 1
    [int]$percentProcessed = ($imageNumber / $imageCount) * 100
    Write-Progress -Activity "Validating ($imageNumber/$imageCount)" -Status "$percentProcessed%" -PercentComplete ($percentProcessed)
    
    try {
      $file = Get-ChildItem -Path $Path -Filter "$($images[$imageIndex].FileName)*" -Recurse
    }
    catch {
      Write-Host $images[$imageIndex] -ForegroundColor Green
      Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if($file -eq $null) {
      $missingImages.Add($images[$imageIndex]) | Out-Null
    }
  }

  Export-ImagesFile (Join-Path $Path "missing.csv") $missingImages

  Read-Host -Prompt "Press Enter to exit"
}

#Get-MissingFiles "C:\rule34\2017-08-22"

$config.StopId = Get-Feed $config.StartPage $config.DestinationRoot $config.StopId $config.TrashTagsFile
Write-Config -ConfigHash $config

if ([boolean]::Parse($config.ShutdownPC)) {
  Stop-Computer
}

#Move-TrashImageBatch "C:\rule34\"
#Move-TrashImages "C:\rule34\2017-07-20"