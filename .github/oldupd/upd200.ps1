function Dict-Hex([byte[]]$b) { return (($b | ForEach-Object { $_.ToString('x2') }) -join '') }

$APPV = 200
$APPVS = '2.' + ($APPV - 200)
$AppBase = 'https://zerazine.github.io/nangman-translator/app/'
$Upd = @{ task = $null; kind = ''; j = $null; queue = (New-Object System.Collections.ArrayList); cur = $null; got = @{}; ready = $false; checkAt = [DateTime]::Now.AddHours(-3).AddSeconds(5); waitLog = $false }
function Upd-AddonDir {
  try { foreach ($l in [IO.File]::ReadAllLines((Join-Path $env:LOCALAPPDATA 'NangmanTranslator\installed.txt'))) { if ($l -match '^\W*addon=(.+)$') { $d = $Matches[1].Trim(); if ($d -and (Test-Path -LiteralPath $d)) { return $d } } } } catch {}
  return $null
}
function Upd-Target([string]$p) {
  if ($p -match '\.\.' -or $p -notmatch '^(app|addon)/[A-Za-z0-9_\-/]+(\.[A-Za-z0-9]+)?$') { return $null }
  if ($p -match '^app/(.+)$') { $rel = $Matches[1]; if ($rel -match '(?i)^(settings\.json|translate-config.*|dict(\.good|\.bak)?\.dat|tier\.txt|installed\.txt)$') { return $null }; return (Join-Path $Dir ($rel -replace '/', '\')) }
  if ($p -match '^addon/NangmanTranslator/(.+)$') { $ad = Upd-AddonDir; if (-not $ad) { return $null }; return (Join-Path $ad ($Matches[1] -replace '/', '\')) }
  return $null
}
function Upd-Sha([byte[]]$b) { return (Dict-Hex ([System.Security.Cryptography.SHA256]::Create().ComputeHash($b))) }
function Upd-FileSha([string]$f) { try { if (Test-Path -LiteralPath $f) { return (Upd-Sha ([IO.File]::ReadAllBytes($f))) } } catch {}; return '' }
function Upd-Reset { $Upd.task = $null; $Upd.j = $null; $Upd.queue.Clear(); $Upd.cur = $null; $Upd.got = @{}; $Upd.ready = $false; $Upd.waitLog = $false }
function Upd-Need { return (([int]$Upd.avail -gt $APPV) -or [bool]$Upd.ready -or ([int]$Dict.remote -gt [int]$S.dictV)) }
function Upd-Paint {
  if (-not $Bar.updS) { return }
  if ($Upd.busyUi -and ([DateTime]::Now - $Upd.busyAt).TotalSeconds -lt 20 -and ($Upd.task -or $Dict.busy -or $Upd.queue.Count -gt 0)) { $Bar.updS.Text = '업데이트 중…'; $Bar.updS.Foreground = Br '#FFE0B95A'; $Bar.updR.Visibility = 'Collapsed'; return }
  $Upd.busyUi = $false
  if ([bool]$Upd.ready -and -not ([int]$Dict.remote -gt [int]$S.dictV)) { $Bar.updS.Text = '받기 끝 · 와우 끄면 적용'; $Bar.updS.Foreground = Br '#FFE0B95A'; $Bar.updR.Visibility = 'Collapsed'; $Bar.updS.ToolTip = '새 버전을 받아 뒀어요 · 와우를 끄면(또는 도우미 재시작) 바로 바뀌어요'; return }
  if (Upd-Need) { $Bar.updS.Text = '업데이트 필요'; $Bar.updS.Foreground = Br '#FFF0B060'; $Bar.updR.Visibility = 'Visible'; $Bar.updR.ToolTip = '누르면 지금 업데이트'; $Bar.updS.ToolTip = $null }
  else { $Bar.updS.Text = '최신 버전'; $Bar.updS.Foreground = Br '#FF8C7A52'; $Bar.updR.Visibility = 'Collapsed'; $Bar.updS.ToolTip = $null }
}
function Upd-Now {
  $Upd.manual = $true; $Upd.busyUi = $true; $Upd.busyAt = [DateTime]::Now
  try { $Dict.manual = $true; Dict-Check } catch {}
  try { if (-not $Upd.ready) { if ([int]$Upd.avail -gt $APPV -and $Upd.j -and -not $Upd.task -and $Upd.queue.Count -eq 0) { $Upd.checkAt = [DateTime]::MinValue }; Upd-Check } } catch {}
  Upd-Paint
}
function Upd-Check { if ($Upd.task -or $Upd.ready -or $Upd.queue.Count -gt 0) { return }; $Upd.checkAt = [DateTime]::Now; $Upd.kind = 'ver'; $Upd.task = $DictHttp.GetStringAsync($AppBase + 'version.json?t=' + [DateTime]::UtcNow.Ticks) }
function Upd-Next {
  if ($Upd.queue.Count -eq 0) { $Upd.ready = $true; Log ('프로그램 새 버전 ' + $Upd.j.v + ' 받기 끝 · 와우가 꺼져 있을 때 바꿈'); return }
  $Upd.cur = $Upd.queue[0]; $Upd.queue.RemoveAt(0)
  $Upd.kind = 'file'; $Upd.task = $DictHttp.GetByteArrayAsync($AppBase + [string]$Upd.j.v + '/' + [string]$Upd.cur.p + '?t=' + [DateTime]::UtcNow.Ticks)
}
function Self-Restart {
  Log '도우미 재시작 (설정 메뉴)'
  try { Save-Cfg } catch {}
  try { if ($Upd.ready) { Upd-Apply; Upd-Reset } } catch { Log ('재시작 때 업데이트 실패 (그대로 씀): ' + $_) }
  try { $mtx.ReleaseMutex() } catch {}
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $Self + '"')) | Out-Null
  [Environment]::Exit(0)
}
function Upd-Apply {
  $items = @($Upd.got.Keys | Sort-Object { if ($_ -match '(?i)NangmanTranslator\.ps1$') { 1 } else { 0 } })
  foreach ($p in $items) {
    $tg = Upd-Target $p; if (-not $tg) { throw ('자리 이상: ' + $p) }
    $dd = Split-Path -Parent $tg; if (-not (Test-Path -LiteralPath $dd)) { [void](New-Item -ItemType Directory -Path $dd -Force) }
    $tmp = $tg + '.new'; [IO.File]::WriteAllBytes($tmp, [byte[]]$Upd.got[$p])
    if ((Upd-FileSha $tmp) -ne ([string]($Upd.j.files | Where-Object { $_.p -eq $p } | Select-Object -First 1).sha256).ToLower()) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; throw ('쓴 파일 검사값 틀림: ' + $p) }
    Move-Item -LiteralPath $tmp -Destination $tg -Force
  }
  try {
    $rf = Join-Path $env:LOCALAPPDATA 'NangmanTranslator\installed.txt'
    if ($Upd.j.ver -and (Test-Path -LiteralPath $rf)) { $ls = @([IO.File]::ReadAllLines($rf) | ForEach-Object { if ($_ -match '^\W*version=') { 'version=' + [string]$Upd.j.ver } else { $_ } }); [IO.File]::WriteAllLines($rf, [string[]]$ls, (New-Object Text.UTF8Encoding($true))) }
  } catch { Log "설치 기록 버전: $_" }
  Log ('프로그램 업데이트 끝: ' + $Upd.j.v + ' (' + [string]$Upd.j.ver + ') · 파일 ' + $items.Count + '개')
  try {
    $vreq = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, 'https://invalid.example/rest/v1/rpc/usage_ver')
    [void]$vreq.Headers.TryAddWithoutValidation('apikey', 'sb_publishable_c6JUbaSwz1LAvxH9nenYXw_hkZOYEkt')
    $vreq.Content = New-Object System.Net.Http.StringContent((@{ p_uid = [string]$S.uid; p_ver = [string]$Upd.j.ver; p_tier = [string]$Tier } | ConvertTo-Json -Compress), [Text.Encoding]::UTF8, 'application/json')
    [void]$DictHttp.SendAsync($vreq)
  } catch {}
  try { Add-Line @{ kind = 'S'; col = 'e0b95a'; text = ('번역기를 새 버전(' + [string]$Upd.j.ver + ')으로 업데이트했어요' + $(if (@($items | Where-Object { $_ -like 'addon/*' }).Count -gt 0) { ' · 게임 쪽은 다음 접속 때 적용돼요' } else { '' })) } | Out-Null } catch {}
}
$script:migClean = Join-Path $Dir 'moved-from.txt'
if (Test-Path -LiteralPath $script:migClean) {
  $MigT = New-Object Windows.Threading.DispatcherTimer; $MigT.Interval = [TimeSpan]::FromSeconds(60)
  $MigT.Add_Tick({
    $MigT.Stop()
    try {
      $od = ([IO.File]::ReadAllText($script:migClean)).Trim()
      if ((Mig-Same $od $MigOld) -and -not (Mig-Same $od $Dir) -and (Test-Path -LiteralPath (Join-Path $od 'NangmanTranslator.ps1'))) { Remove-Item -LiteralPath $od -Recurse -Force -ErrorAction Stop; Log ('예전 설치 폴더 지움: ' + $od) }
      if (-not (Test-Path -LiteralPath $od)) { Remove-Item -LiteralPath $script:migClean -Force -ErrorAction SilentlyContinue }
    } catch { Log ('예전 설치 폴더 지우기 (다음에 다시): ' + $_) }
  })
  $MigT.Start()
}
$script:TickSB = {
  try {
    if ($Bar.cm -and $Bar.cm.IsOpen) { try { Upd-Paint } catch {} }
    if ($Upd.ready) {
      if ([IntPtr]::Zero -ne [IntPtr]::Zero -or $state.inputOn -or $state.sending) { if (-not $Upd.waitLog) { $Upd.waitLog = $true; Log '프로그램 업데이트: 와우가 꺼지면 바꿈' }; return }
      try { Upd-Apply } catch { Log ('프로그램 업데이트 실패 (그대로 씀): ' + $_) }
      Upd-Reset; return
    }
    if (-not $Upd.task) { if ($Upd.queue.Count -eq 0 -and ([DateTime]::Now - $Upd.checkAt).TotalHours -ge 3) { Upd-Check }; return }
    if (-not $Upd.task.IsCompleted) { return }
    $t = $Upd.task; $Upd.task = $null
    if ($t.Status -ne [System.Threading.Tasks.TaskStatus]::RanToCompletion) { $why = ''; try { $why = [string]$t.Exception.InnerException.Message } catch {}; Log ('프로그램 업데이트 ' + $Upd.kind + ' 받기 실패: ' + $why); Upd-Reset; return }
    if ($Upd.kind -eq 'ver') {
      $j = [string]$t.Result | ConvertFrom-Json
      if (-not $j -or [int]$j.v -le $APPV) { $Upd.avail = 0; try { Upd-Paint } catch {}; return }
      $Upd.avail = [int]$j.v
      if ($S.dictAuto -eq $false -and -not $Upd.manual) { Log ('프로그램 새 버전 ' + $j.v + ' 있음 · 자동 업데이트 꺼짐 (메뉴에서 업데이트 필요 표시)'); try { Upd-Paint } catch {}; return }
      $Upd.manual = $false
      $Upd.j = $j; $Upd.queue.Clear(); $Upd.got = @{}
      foreach ($f in @($j.files)) {
        $tg = Upd-Target ([string]$f.p)
        if (-not $tg) { Log ('프로그램 업데이트 건너뜀 (자리 이상 · 애드온 폴더 없음): ' + [string]$f.p); Upd-Reset; return }
        if ((Upd-FileSha $tg) -ne ([string]$f.sha256).ToLower()) { [void]$Upd.queue.Add(@{ p = [string]$f.p; sha = ([string]$f.sha256).ToLower() }) }
      }
      Log ('프로그램 새 버전 ' + $j.v + ' (' + [string]$j.ver + ') · 바뀐 파일 ' + $Upd.queue.Count + '개 받기')
      Upd-Next; return
    }
    if ($Upd.kind -eq 'file') {
      $b = [byte[]]$t.Result
      if ((Upd-Sha $b) -ne $Upd.cur.sha) { Log ('프로그램 업데이트 검사값 틀림 (그대로 씀): ' + $Upd.cur.p); Upd-Reset; return }
      $Upd.got[[string]$Upd.cur.p] = $b
      Upd-Next; return
    }
  } catch { Log "프로그램 업데이트 확인: $_"; Upd-Reset }
}
