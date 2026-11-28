param([string]$Dir, [switch]$Clean)
$ErrorActionPreference = 'Stop'
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal' } catch {}
$U8 = New-Object Text.UTF8Encoding($false)
$InfoF = Join-Path $Dir 'model_upd.json'
$StF = Join-Path $Dir 'model_get.json'
$LogF = Join-Path $Dir 'model_get.log'
$DgF = Join-Path $Dir 'model_v2.dg'
$V2 = 'nangman-gemma-v2'; $V1 = 'nangman-gemma'
function Log($m) { try { [IO.File]::AppendAllText($LogF, ('[{0}] {1}' -f (Get-Date -Format 'MM-dd HH:mm:ss'), $m) + "`r`n", $U8) } catch {} }
function St($h) { $h.at = (Get-Date -Format 's'); $t = $StF + '.tmp'; [IO.File]::WriteAllText($t, ($h | ConvertTo-Json -Compress), $U8); Move-Item -LiteralPath $t -Destination $StF -Force }
function Ollama-Exe {
  foreach ($d in @((Join-Path $env:LOCALAPPDATA 'Programs\Ollama'), (Join-Path $env:ProgramFiles 'Ollama'))) { $x = Join-Path $d 'ollama.exe'; if (Test-Path -LiteralPath $x) { return $x } }
  $c = Get-Command 'ollama.exe' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { return $c.Source }
  throw '번역 엔진(ollama)을 찾지 못함'
}
function Run-Ol([string]$a) {
  $p = Start-Process -FilePath (Ollama-Exe) -ArgumentList $a -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput ($LogF + '.o') -RedirectStandardError ($LogF + '.e')
  try { Log ('ollama ' + $a + ' -> ' + $p.ExitCode + ' ' + ([IO.File]::ReadAllText($LogF + '.e')).Trim()) } catch {}
  return $p.ExitCode
}
function Tags { try { return (Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10).models | ForEach-Object { [string]$_.name } } catch { return @() } }
function Dig([string]$n) { try { return [string]((Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10).models | Where-Object { [string]$_.name -eq ($n + ':latest') } | Select-Object -First 1).digest } catch { return '' } }
function Keep-Dg { $d = Dig $V2; if ($d) { try { [IO.File]::WriteAllText($DgF, $d, $U8) } catch {} } }
$mtx = New-Object Threading.Mutex($false, 'Local\NangmanModelGet')
$own = $false; try { $own = $mtx.WaitOne(0) } catch [Threading.AbandonedMutexException] { $own = $true }
if (-not $own) { exit 0 }
try {
  if ($Clean) {
    St @{ st = 'cleaning' }
    $tg = @(Tags)
    if (-not ($tg -contains ($V2 + ':latest'))) {
      $dg = ''; try { $dg = ([IO.File]::ReadAllText($DgF)).Trim() } catch {}
      if ($dg -and (Dig $V1) -eq $dg) { St @{ st = 'cleaned' }; Log '이미 정리됨'; exit 0 }
      throw 'V2가 엔진에 없음'
    }
    if ($tg -contains ($V1 + ':latest')) { if ((Run-Ol ('rm ' + $V1)) -ne 0) { throw 'V1 지우기 실패' } }
    if ((Run-Ol ('cp ' + $V2 + ' ' + $V1)) -ne 0) { throw 'V2 이름 바꾸기 실패' }
    if (-not (@(Tags) -contains ($V1 + ':latest'))) { throw '이름 바꾼 V2가 안 보임' }
    [void](Run-Ol ('rm ' + $V2))
    St @{ st = 'cleaned' }; Log '정리 끝'
    exit 0
  }
  $info = [IO.File]::ReadAllText($InfoF) | ConvertFrom-Json
  $parts = @($info.parts); $psz = @($info.psize); $size = [long]$info.size; $sha = ([string]$info.sha256).ToLower()
  if ($parts.Count -eq 0 -or $psz.Count -ne $parts.Count -or $size -le 0 -or $sha.Length -ne 64) { throw '모델 정보가 이상함' }
  $md = Join-Path $Dir 'model\v2'; [void](New-Item -ItemType Directory -Force -Path $md)
  $gguf = Join-Path $md 'nangman-gemma.gguf'
  if (@(Tags) -contains ($V2 + ':latest')) { Keep-Dg; St @{ st = 'ready' }; Log '이미 엔진에 있음'; exit 0 }
  $have = 0L; for ($i = 0; $i -lt $parts.Count; $i++) { $pf = Join-Path $md ('part' + ($i + 1)); if (Test-Path -LiteralPath $pf) { $have += (Get-Item -LiteralPath $pf).Length } }
  $drv = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($md))
  if ($drv.AvailableFreeSpace -lt ($size * 2 - $have + 2GB)) { St @{ st = 'fail'; err = 'disk'; need = [math]::Ceiling(($size * 2 - $have + 2GB) / 1GB) }; Log '디스크 부족'; exit 0 }
  $buf = New-Object byte[] (1MB); $got = $have; $last = [DateTime]::MinValue; $sw = [Diagnostics.Stopwatch]::StartNew(); $cap = 15MB
  for ($i = 0; $i -lt $parts.Count; $i++) {
    $pf = Join-Path $md ('part' + ($i + 1)); $want = [long]$psz[$i]
    $cur = 0L; if (Test-Path -LiteralPath $pf) { $cur = (Get-Item -LiteralPath $pf).Length }
    if ($cur -gt $want) { Remove-Item -LiteralPath $pf -Force; $got -= $cur; $cur = 0L }
    $tries = 0
    while ($cur -lt $want) {
      try {
        $rq = [Net.HttpWebRequest]::Create([string]$parts[$i]); $rq.Timeout = 30000; $rq.ReadWriteTimeout = 60000; $rq.UserAgent = 'NangmanTranslator'
        if ($cur -gt 0) { $rq.AddRange($cur) }
        $rs = $rq.GetResponse()
        try {
          if ($cur -gt 0 -and [int]$rs.StatusCode -ne 206) { $cur = 0L; $got = 0L; for ($k = 0; $k -lt $i; $k++) { $got += [long]$psz[$k] } }
          $st = $rs.GetResponseStream(); $fs = New-Object IO.FileStream($pf, $(if ($cur -gt 0) { 'Append' } else { 'Create' }), 'Write', 'Read')
          try {
            while ($true) {
              $n = $st.Read($buf, 0, $buf.Length); if ($n -le 0) { break }
              $fs.Write($buf, 0, $n); $cur += $n; $got += $n
              if (([DateTime]::Now - $last).TotalSeconds -ge 1) { $last = [DateTime]::Now; St @{ st = 'dl'; got = $got; total = $size } }
              $el = $sw.Elapsed.TotalSeconds; $done = $got - $have; if ($el -gt 0 -and $done / $el -gt $cap) { Start-Sleep -Milliseconds ([int](($done / $cap - $el) * 1000)) }
            }
          } finally { $fs.Close(); $st.Close() }
        } finally { $rs.Close() }
        if ($cur -lt $want) { throw ('조각 덜 받음 ' + $cur + '/' + $want) }
      } catch {
        $tries++; Log ('받기 오류 part' + ($i + 1) + ': ' + $_)
        if ($tries -ge 6) { St @{ st = 'fail'; err = 'net'; got = $got; total = $size }; exit 0 }
        Start-Sleep -Seconds ([math]::Min(60, 5 * $tries))
        if (Test-Path -LiteralPath $pf) { $cur = (Get-Item -LiteralPath $pf).Length } else { $cur = 0L }
      }
    }
  }
  St @{ st = 'verify'; got = $size; total = $size }
  $hs = [Security.Cryptography.SHA256]::Create(); $out = New-Object IO.FileStream($gguf, 'Create', 'Write', 'None'); $tot = 0L
  try {
    for ($i = 0; $i -lt $parts.Count; $i++) {
      $pf = Join-Path $md ('part' + ($i + 1)); $in = [IO.File]::OpenRead($pf)
      try { while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $n); [void]$hs.TransformBlock($buf, 0, $n, $null, 0); $tot += $n } } finally { $in.Close() }
    }
  } finally { $out.Close() }
  [void]$hs.TransformFinalBlock((New-Object byte[] 0), 0, 0)
  $hex = ([BitConverter]::ToString($hs.Hash) -replace '-', '').ToLower()
  if ($tot -ne $size -or $hex -ne $sha) {
    Log ('검사값 틀림 ' + $tot + ' ' + $hex)
    for ($i = 0; $i -lt $parts.Count; $i++) { Remove-Item -LiteralPath (Join-Path $md ('part' + ($i + 1))) -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $gguf -Force -ErrorAction SilentlyContinue
    St @{ st = 'fail'; err = 'sha' }; exit 0
  }
  for ($i = 0; $i -lt $parts.Count; $i++) { Remove-Item -LiteralPath (Join-Path $md ('part' + ($i + 1))) -Force -ErrorAction SilentlyContinue }
  St @{ st = 'create' }
  $mf = ''
  try { if ((Run-Ol ('show --modelfile ' + $V1)) -eq 0) { $mf = [IO.File]::ReadAllText($LogF + '.o') } } catch {}
  $lines = @($mf -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*FROM\s' })
  if (-not ($lines -match '^\s*TEMPLATE')) { $lines = @('TEMPLATE {{ .Prompt }}', 'RENDERER gemma4', 'PARSER gemma4', 'PARAMETER temperature 1', 'PARAMETER top_k 64', 'PARAMETER top_p 0.95') }
  $mfp = Join-Path $md 'Modelfile'
  [IO.File]::WriteAllText($mfp, (('FROM "' + $gguf + '"') + "`n" + ($lines -join "`n")), $U8)
  $rc = Run-Ol ('create ' + $V2 + ' -f "' + $mfp + '"')
  if ($rc -ne 0 -or -not (@(Tags) -contains ($V2 + ':latest'))) { St @{ st = 'fail'; err = 'create' }; exit 0 }
  Remove-Item -LiteralPath $gguf -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $mfp -Force -ErrorAction SilentlyContinue
  Keep-Dg
  St @{ st = 'ready' }; Log '받기·넣기 끝'
} catch { Log ('멈춤: ' + $_); try { St @{ st = 'fail'; err = 'x'; msg = [string]$_ } } catch {} }
finally { try { $mtx.ReleaseMutex() } catch {} }
