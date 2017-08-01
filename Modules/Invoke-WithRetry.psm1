# https://gist.github.com/alexbevi/34b700ff7c7c53c7780b
function Invoke-WithRetry {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline, Mandatory)]
    $Command,
    $RetryDelay = 5,
    $MaxRetries = 5
  )

  $currentRetry = 0
  $success = $false
  $cmd = $Command.ToString()

  do {
    try {
      $result = & $Command
      $success = $true

      return $result
    }
    catch [System.Exception] {
      $currentRetry = $currentRetry + 1

      Write-Host " Failed to execute [$cmd]: $($_.Exception.Message)"

      if ($currentRetry -gt $MaxRetries) {
        throw
      }
      else {
        Write-Host "  Waiting $RetryDelay second(s) before attempt #$currentRetry of [$cmd]"

        Start-Sleep -s $RetryDelay
      }
    }
  } while (!$success);
}
