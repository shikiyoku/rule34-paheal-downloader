function Read-Config {
  [CmdletBinding()]
  Param
  (
    [ValidateScript( {Test-Path $_ -PathType Leaf})]
    [string] $ConfigPath = "$($MyInvocation.ScriptName.Split(".")[0]).config",

    [string[]] $RequiredParams
  )

  # Read file containing "key=value" and write to $hash
  $hash = @{}
  Get-Content $ConfigPath |
    ForEach-Object { if ($_ -match "^(.*)=(.*)$") { $hash[$matches[1]] = $matches[2] } }

  if ($PSBoundParameters.ContainsKey('RequiredParams')) {
    $missRequired = $false
    foreach ($param in $RequiredParams) {
      if (-not $hash[$param]) {
        Write-Host "`"$param`" is required" -ForegroundColor Yellow
        $missRequired = $true
      }
    }

    if ($missRequired) {
      exit
    }
  }

  return $hash
}

function Write-Config {
  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory)]
    [Hashtable] $ConfigHash,
    
    [ValidateScript( {Test-Path $_ -PathType Leaf})]
    [string] $ConfigPath = "$($MyInvocation.ScriptName.Split(".")[0]).config"
  )

  $ConfigHash.GetEnumerator() |
    Select-Object Key, Value |
    ForEach-Object { "$($_.Key)=$($_.Value)" } |
    Set-Content $ConfigPath
}
