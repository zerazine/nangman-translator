param([string]$Branch = 'main')
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http
$base = "https://raw.githubusercontent.com/zerazine/nangman-translator/$Branch/app/"
$http0 = New-Object System.Net.Http.HttpClient
$J = $http0.GetStringAsync($base + 'version.json?t=' + [DateTime]::UtcNow.Ticks).Result | ConvertFrom-Json
Write-Host ("시험 대상: 최신 {0} ({1}) · 파일 {2}개 · {3}" -f $J.v, $J.ver, @($J.files).Count, $base)
$rec = Join-Path $env:LOCALAPPDATA 'NangmanTranslator'
$addon = Join-Path $env:RUNNER_TEMP 'wowupd\_forever_\Interface\AddOns\NangmanTranslator'
$fails = 0; $rows = @()
$vers = @(Get-ChildItem (Join-Path $PSScriptRoot 'oldupd') -Filter 'upd*.ps1' | ForEach-Object { [int]($_.BaseName -replace '\D', '') } | Where-Object { $_ -lt [int]$J.v } | Sort-Object)
foreach ($v in $vers) {
  $vl = $(if ($v -ge 200) { '2.' + $(if ($v -eq 200) { '0' } else { '{0:00}' -f ($v - 200) }) } else { "1.$v" })
  $Dir = $(if ($v -le 32) { 'C:\낭만타우렌_번역기' } else { Join-Path $env:LOCALAPPDATA 'Programs\NangmanTranslator' })
  foreach ($d in @($Dir, $addon, $rec)) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force } ; [void](New-Item -ItemType Directory -Path $d -Force) }
  [IO.File]::WriteAllText((Join-Path $Dir 'NangmanTranslator.ps1'), "# old $vl")
  [IO.File]::WriteAllText((Join-Path $Dir 'settings.json'), '{"keep":1}')
  [IO.File]::WriteAllText((Join-Path $addon 'Core.lua'), '-- old')
  [IO.File]::WriteAllLines((Join-Path $rec 'installed.txt'), [string[]]@("version=$vl", "addon=$addon", "dir=$Dir"), (New-Object Text.UTF8Encoding($true)))
  $script:logs = New-Object System.Collections.ArrayList
  function Log($m) { [void]$script:logs.Add([string]$m) }
  function Add-Line($x) { }
  function Save-Cfg { }
  $state = @{ inputOn = $false; sending = $false }; $S = @{ uid = 'selftest' }; $Tier = 'gemma'
  $DictHttp = New-Object System.Net.Http.HttpClient
  . (Join-Path $PSScriptRoot "oldupd\upd$v.ps1")
  $AppBase = $base; $Upd.checkAt = [DateTime]::Now.AddHours(-10)
  $t0 = [DateTime]::Now; $done = $false
  while (([DateTime]::Now - $t0).TotalSeconds -lt 240) {
    & $script:TickSB
    if (@($script:logs | Where-Object { $_ -match '업데이트 끝|실패|건너뜀|틀림|확인:' }).Count) { $done = $true; break }
    Start-Sleep -Milliseconds 100
  }
  $bad = @()
  foreach ($f in @($J.files)) {
    $p = [string]$f.p
    $tg = $(if ($p -match '^app/(.+)$') { Join-Path $Dir ($Matches[1] -replace '/', '\') } else { Join-Path $addon (($p -replace '^addon/NangmanTranslator/', '') -replace '/', '\') })
    $h = ''; if (Test-Path -LiteralPath $tg) { $h = (Get-FileHash -LiteralPath $tg -Algorithm SHA256).Hash.ToLower() }
    if ($h -ne ([string]$f.sha256).ToLower()) { $bad += $p }
  }
  $verOk = @([IO.File]::ReadAllLines((Join-Path $rec 'installed.txt')) | Where-Object { $_ -eq ('version=' + $J.ver) }).Count -eq 1
  $keep = (Test-Path -LiteralPath (Join-Path $Dir 'settings.json')) -and ([IO.File]::ReadAllText((Join-Path $Dir 'settings.json')) -eq '{"keep":1}')
  $ok = $done -and $bad.Count -eq 0 -and $verOk -and $keep
  if (-not $ok) { $fails++ }
  $rows += ('{0} {1} → {2} · 파일 {3}/{4} 맞음 · 설치 기록 {5} · 내 설정 {6} · {7}' -f $(if ($ok) { '통과' } else { '실패' }), $vl, $J.ver, (@($J.files).Count - $bad.Count), @($J.files).Count, $(if ($verOk) { 'OK' } else { 'X' }), $(if ($keep) { '그대로' } else { 'X' }), (($script:logs | Select-Object -Last 2) -join ' / '))
  if ($bad.Count) { $rows += ('   안 맞은 파일: ' + ($bad -join ', ')) }
}
foreach ($d in @('C:\낭만타우렌_번역기', (Join-Path $env:LOCALAPPDATA 'Programs\NangmanTranslator'), $rec)) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force } }
$rows | ForEach-Object { Write-Host $_ }
if ($fails) { throw ("옛 버전 업데이트 시험 실패 {0}개" -f $fails) }
Write-Host ("결과: 옛 버전 {0}개 모두 최신으로 바로 업데이트됨" -f $vers.Count)
