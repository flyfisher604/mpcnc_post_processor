<#
  post-run.ps1 -- run the post over one of Autodesk's intermediate .cnc files, under a
  named set of properties, without Fusion.

  What this is and what it may claim is `design.md` -> "Working on the post"; what a row
  settled this way may assert is `findings.md` §4's `utility` method.

  HOW PROPERTIES REACH THE POST
  post.exe takes `--property NAME VALUE`, repeated once per property, and there is no
  property file. VALUE IS EVALUATED AS A JAVASCRIPT LITERAL, which is the whole trick: a
  string or an enum needs quotes INSIDE the argument -- `--property jobSelectedFirmware
  '"Marlin"'` -- while numbers and booleans go bare. All 62 properties are reachable.

  Getting it wrong fails in three ways and only the first is loud:
    jobSelectedFirmware Marlin  -> "Failed to set property" -- an undefined identifier
    mapRapidsSafeZ Retract:15   -> set to a non-string; the post dies in onOpen() with
                                   "str.search is not a function"
    machineTravelZ -2           -> set to the NUMBER -2, and parseMachineCoordinate()
                                   reads the field as EMPTY. The machine frame switches
                                   off, and only WR-2's warning says so.
  So the literal is built from the property's declared type, never from how it looks.

  The utility validates nothing -- `'"Klipper"'` is set as readily as `'"Marlin"'` -- so
  names and enum values are checked here against `post.exe --interrogate` before the run.

  Output goes to Documents\Fusion 360\NC Programs\post-utility, not into the repo, and is
  named <cnc>__<profile> so a re-run cannot destroy another row's evidence.

  Examples:
    .\post-run.ps1 -Cnc "Milling\2D\bore.cnc"
    .\post-run.ps1 -Cnc "Milling\2D\toolchange.cnc" -ProfilePath profiles\manual-change.json
    .\post-run.ps1 -Cnc "Milling\2D\bore.cnc" -Set @{ jobCommentLevel='Debug'; machineHomedAxes='XYZ' }
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Cnc,
  [Alias('Profile')][string]$ProfilePath,
  [hashtable]$Set = @{},
  [string]$Tag,
  [string]$OutDir,
  [string]$Post,
  [switch]$Debugger,
  [switch]$WarningsAsErrors
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- locations -------------------------------------------------------------
$postExe = (Get-ChildItem "$env:LOCALAPPDATA\Autodesk\webdeploy\production" -Recurse -Filter post.exe -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object -First 1).FullName
if (-not $postExe) { throw "post.exe not found under the Fusion webdeploy tree." }

# The .cnc files ship with the Autodesk HSM Post Processor VS Code extension; take the
# newest installed version rather than pinning one.
$ext = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter 'autodesk.hsm-post-processor-*' -ErrorAction SilentlyContinue |
       Sort-Object Name | Select-Object -Last 1
if (-not $ext) { throw "The Autodesk HSM Post Processor extension is not installed, so there are no .cnc files to run." }
$cncRoot = Join-Path $ext.FullName 'res\CNC files'

if (-not $Post)   { $Post   = Join-Path (Split-Path -Parent $here) 'MPCNC_v4.1_Beta3.cps' }
if (-not $OutDir) { $OutDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Fusion 360\NC Programs\post-utility' }

$cncPath = if (Test-Path $Cnc) { (Resolve-Path $Cnc).Path } else { Join-Path $cncRoot $Cnc }
if (-not (Test-Path $cncPath)) { throw "Intermediate file not found: $cncPath" }
if (-not (Test-Path $OutDir))  { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# ---- the property set ------------------------------------------------------
$props = [ordered]@{}
if ($ProfilePath) {
  $pPath = if (Test-Path $ProfilePath) { $ProfilePath } else { Join-Path $here $ProfilePath }
  if (-not (Test-Path $pPath)) { throw "Profile not found: $ProfilePath" }
  $json = Get-Content $pPath -Raw | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) { if ($p.Name -ne '_comment') { $props[$p.Name] = $p.Value } }
  if (-not $Tag) { $Tag = [IO.Path]::GetFileNameWithoutExtension($pPath) }
}
foreach ($k in $Set.Keys) { $props[$k] = $Set[$k] }
if (-not $Tag) { $Tag = 'factory' }

# ---- pre-flight: every name and enum value against --interrogate -----------
$schemaPath = Join-Path $OutDir '_interrogate.json'
& $postExe --interrogate --noheader --nointeraction $Post > $schemaPath
if ($LASTEXITCODE -ne 0) { throw "Interrogation of $Post failed ($LASTEXITCODE)." }
$schema = (Get-Content $schemaPath -Raw | ConvertFrom-Json).properties

$bad = @()
$literals = [ordered]@{}
foreach ($k in $props.Keys) {
  $def = $schema.PSObject.Properties[$k]
  if (-not $def) { $bad += "unknown property '$k'"; continue }
  $d = $def.Value
  $v = $props[$k]
  switch ($d.type) {
    'enum' {
      $ids = @($d.values | ForEach-Object { $_.id })
      if ($ids -notcontains [string]$v) { $bad += "'$k' = '$v' is not one of: $($ids -join ', ')" }
      $literals[$k] = '"' + ([string]$v -replace '"','\"') + '"'
    }
    'boolean' {
      if ("$v" -notmatch '^(true|false)$') { $bad += "'$k' must be true or false, got '$v'" }
      $literals[$k] = "$v".ToLower()
    }
    'string'  { $literals[$k] = '"' + ([string]$v -replace '\\','\\' -replace '"','\"') + '"' }
    default   {
      if ("$v" -notmatch '^-?\d+(\.\d+)?$') { $bad += "'$k' must be numeric, got '$v'" }
      $literals[$k] = "$v"
    }
  }
}
if ($bad.Count) { $bad | ForEach-Object { Write-Host "PROPERTY ERROR: $_" -ForegroundColor Red }; throw "Property set rejected." }

# ---- run -------------------------------------------------------------------
$name    = "{0}__{1}" -f ([IO.Path]::GetFileNameWithoutExtension($cncPath) -replace '\s+','-'), $Tag
$outFile = Join-Path $OutDir "$name.gcode"
$logFile = Join-Path $OutDir "$name.log"

$postArgs = @('--noeditor','--nointeraction','--nobackup','--noprogress','--log', $logFile)
if ($Debugger)         { $postArgs += '--debugall' }
if ($WarningsAsErrors) { $postArgs += '--warningsaserrors' }
foreach ($k in $literals.Keys) { $postArgs += @('--property', $k, $literals[$k]) }
$postArgs += @($Post, $cncPath, $outFile)

# A property value is a JavaScript literal, so a string or an enum carries real quote
# characters -- and PowerShell 5.1 will not quote an argument that already contains one.
# `"Probe Z"` then reaches the CRT bare, splits at the space into two arguments, and every
# --property after it is read one position out: "Expected property but got <output path>".
# So the command line is built to the CRT's own rules rather than left to the heuristic.
function Quote-CrtArg([string]$a) {
  if ($a -notmatch '[\s"]') { return $a }
  '"' + ($a -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}
$cmdLine = ($postArgs | ForEach-Object { Quote-CrtArg $_ }) -join ' '

Write-Host "post : $(Split-Path -Leaf $Post)"
Write-Host "cnc  : $($cncPath.Replace($cncRoot,'<CNC files>'))"
Write-Host "props: $Tag ($($props.Count) overrides)"
$props.GetEnumerator() | ForEach-Object { Write-Host ("       {0} = {1}" -f $_.Key, $_.Value) }

$stdout = Join-Path $OutDir "$name.stdout"
$p = Start-Process -FilePath $postExe -ArgumentList $cmdLine -NoNewWindow -Wait -PassThru `
                   -RedirectStandardOutput $stdout -RedirectStandardError "$stdout.err"
$code = $p.ExitCode
Get-Content $stdout, "$stdout.err" -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host $_ }
Remove-Item $stdout, "$stdout.err" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "exit : $code" -ForegroundColor $(if ($code -eq 0) { 'Green' } else { 'Red' })
if (Test-Path $outFile) { Write-Host "out  : $outFile  ($((Get-Content $outFile).Count) lines)" }
if (Test-Path "$outFile.failed") { Write-Host "out  : $outFile.failed  -- refused, and what it left is not runnable" -ForegroundColor Yellow }
if (Test-Path $logFile) {
  $warn = Select-String -Path $logFile -Pattern 'warning','error' -CaseSensitive:$false
  Write-Host "log  : $logFile  ($($warn.Count) warning/error lines)"
  $warn | Select-Object -First 20 | ForEach-Object { Write-Host "       $($_.Line.Trim())" -ForegroundColor Yellow }
}
exit $code
