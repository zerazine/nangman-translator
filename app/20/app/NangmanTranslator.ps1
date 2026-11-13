# 낭만타우렌 와우 포에버 번역기 (공유판) — 와우 채팅창 자리 위에 겹쳐 뜨는 번역 대화창
# 게임 애드온(NangmanTranslator)이 화면 왼쪽 위 얇은 색 점 줄로 대화를 내보내면 그 색을 읽어 번역해서 보여 줌
# 답장: Shift+Enter(와우가 앞에 있을 때) 또는 입력줄 클릭 → 한국어로 쓰고 Enter → 번역해서 와우 채팅으로 보냄
# Tab = 보낼 곳 바꾸기 · Esc = 취소 · 탭 오른쪽 클릭 = 이 탭에 보일 대화 고르기 · 톱니 = 설정
# 받기 번역 = 사비(내 컴퓨터 Ollama) · 보내기 번역 = 사비 또는 제미나이(설정에서 고름)
# 저작권: 제작자 낭만타우렌 (배틀태그 하르만#31615) · 수정·재배포 불가
$ErrorActionPreference = 'Stop'
$Self = $MyInvocation.MyCommand.Path
$Dir = Split-Path -Parent $Self
$A = Join-Path $Dir 'ftr'
$Cfg = Join-Path $Dir 'settings.json'
$LogFile = Join-Path $Dir 'translate-error.log'
function Log($m) { try { if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt 1MB) { Move-Item -LiteralPath $LogFile ($LogFile -replace '\.log$', '.old.log') -Force }; Add-Content -Encoding UTF8 $LogFile ("[{0}] {1}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $m) } catch {} }   # (2026-10-25) 1MB 넘으면 넘김
trap { Log ("멈춤: " + $_ + " @ " + $_.InvocationInfo.ScriptLineNumber); break }

$mtx = New-Object System.Threading.Mutex($false, 'NangmanTranslatorSingle')
# (2026-10-25) 새 버전으로 다시 켜질 때 앞 프로그램이 완전히 꺼질 때까지 최대 8초 기다림 (바로 포기하면 아무것도 안 켜진 채로 남았음)
$got = $false
try { $got = $mtx.WaitOne(8000) } catch [System.Threading.AbandonedMutexException] { $got = $true }
if (-not $got) { exit }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Net.Http
Add-Type -AssemblyName System.Xaml
$refs = @([System.Drawing.Bitmap].Assembly.Location, [System.Windows.Interop.HwndSource].Assembly.Location, [System.Windows.DependencyObject].Assembly.Location, [System.Windows.Window].Assembly.Location, [System.Xaml.XamlReader].Assembly.Location)
try {
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $A 'FTR.cs'), [Text.Encoding]::UTF8)) -ReferencedAssemblies $refs
} catch { Log "C# 준비 실패: $_"; throw }
try { Add-Type -Namespace FTRK -Name Keys -MemberDefinition '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);' } catch { Log "키 상태 준비: $_" }
try { Add-Type -Namespace FTRK -Name Cur -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct CI { public int cb; public int flags; public IntPtr h; public int x; public int y; }
[DllImport("user32.dll")] static extern bool GetCursorInfo(ref CI ci);
public static bool Showing() { CI c = new CI(); c.cb = Marshal.SizeOf(typeof(CI)); if (!GetCursorInfo(ref c)) return true; return (c.flags & 1) != 0; }
'@ } catch { Log "커서 보임 확인 준비: $_" }   # (2026-11-02) 가운데 파티 대화 휠: 시점 돌리기(커서 숨김) 중엔 휠을 안 가로챔
# (2026-11-03) 가운데 파티 대화: 휠만 가로채고 클릭은 늘 게임으로 (경매인·NPC·확인 창 클릭이 막히던 것)
#  따로 도는 작은 스레드에서 마우스 휠만 봄 · 칸 안에서 굴린 휠만 모아 두고 나머지는 그대로 통과
try { Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Threading;
namespace FTRK {
public static class Wheel {
  delegate IntPtr Proc(int n, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] struct MS { public int x; public int y; public uint data; public uint flags; public uint time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr h; public uint m; public IntPtr w; public IntPtr l; public uint t; public int x; public int y; }
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, Proc p, IntPtr mod, uint tid);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int n, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint a, uint b);
  [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
  static Proc keep; static IntPtr hook = IntPtr.Zero; static Thread th;
  public static volatile bool On; public static volatile int L, T, R, B; static int pend;
  public static void Start() {
    if (th != null) return;
    th = new Thread(() => { keep = Cb; hook = SetWindowsHookEx(14, keep, GetModuleHandle(null), 0); MSG m; while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) { } });
    th.IsBackground = true; th.Start();
  }
  static IntPtr Cb(int n, IntPtr w, IntPtr l) {
    if (n >= 0 && On && (int)w == 0x020A) {
      MS m = (MS)Marshal.PtrToStructure(l, typeof(MS));
      if (m.x >= L && m.x <= R && m.y >= T && m.y <= B) { Interlocked.Add(ref pend, (short)(m.data >> 16)); return (IntPtr)1; }
    }
    return CallNextHookEx(hook, n, w, l);
  }
  public static int Take() { return Interlocked.Exchange(ref pend, 0); }
}
}
'@; [FTRK.Wheel]::Start() } catch { Log "가운데 휠 준비: $_" }
try { Add-Type -Namespace FTRK -Name Kb -MemberDefinition '[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);' } catch { Log "신호 키 준비: $_" }
# (공유판) 위쪽 도우미 바: GPU·VRAM(엔비디아 NVML → 없으면 nvidia-smi → 없으면 '—') · CPU · RAM — 1초마다 아주 가볍게
try { Add-Type -TypeDefinition @'
using System; using System.Diagnostics; using System.Runtime.InteropServices; using System.Threading;
namespace FTRK {
public static class Stats {
  [StructLayout(LayoutKind.Sequential)] struct FT { public uint lo; public uint hi; }
  [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out FT idle, out FT kernel, out FT user);
  [StructLayout(LayoutKind.Sequential)] class MEM { public uint len = 64; public uint load; public ulong total; public ulong avail; public ulong tp; public ulong ap; public ulong tv; public ulong av; public ulong ave; }
  [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx([In, Out] MEM m);
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr LoadLibrary(string p);
  [StructLayout(LayoutKind.Sequential)] struct NU { public uint gpu; public uint mem; }
  [StructLayout(LayoutKind.Sequential)] struct NM { public ulong total; public ulong free; public ulong used; }
  [DllImport("nvml.dll")] static extern int nvmlInit_v2();
  [DllImport("nvml.dll")] static extern int nvmlDeviceGetHandleByIndex_v2(uint i, out IntPtr d);
  [DllImport("nvml.dll")] static extern int nvmlDeviceGetUtilizationRates(IntPtr d, out NU u);
  [DllImport("nvml.dll")] static extern int nvmlDeviceGetMemoryInfo(IntPtr d, out NM m);
  [DllImport("nvml.dll")] static extern int nvmlDeviceGetTemperature(IntPtr d, int sensor, out uint t);
  static ulong pI, pT; static int nv = 0; static IntPtr dev = IntPtr.Zero;
  static volatile bool smiBusy = false, smiDead = false; static int smiAt = 0;
  public static volatile int Cpu = -1, Gpu = -1, TempC = -1; public static volatile float RamUsedGB = -1, RamTotalGB = -1, VramUsedGB = -1, VramTotalGB = -1;
  static ulong U(FT f) { return ((ulong)f.hi << 32) | f.lo; }
  public static void Poll() {
    try { FT i, k, u; if (GetSystemTimes(out i, out k, out u)) { ulong ii = U(i), tt = U(k) + U(u); if (pT != 0 && tt > pT) { Cpu = (int)Math.Round(100.0 * (1.0 - (double)(ii - pI) / (double)(tt - pT))); if (Cpu < 0) Cpu = 0; if (Cpu > 100) Cpu = 100; } pI = ii; pT = tt; } } catch { }
    try { MEM m = new MEM(); if (GlobalMemoryStatusEx(m)) { RamTotalGB = (float)(m.total / 1073741824.0); RamUsedGB = (float)((m.total - m.avail) / 1073741824.0); } } catch { }
    if (nv == 0) {
      nv = -1;
      try {
        if (LoadLibrary("nvml.dll") == IntPtr.Zero) { string pf = Environment.GetEnvironmentVariable("ProgramW6432"); if (string.IsNullOrEmpty(pf)) pf = Environment.GetEnvironmentVariable("ProgramFiles"); LoadLibrary(System.IO.Path.Combine(pf ?? "C:\\Program Files", "NVIDIA Corporation\\NVSMI\\nvml.dll")); }
        if (nvmlInit_v2() == 0 && nvmlDeviceGetHandleByIndex_v2(0, out dev) == 0) nv = 1;
      } catch { nv = -1; }
    }
    if (nv == 1) {
      try { NU u; if (nvmlDeviceGetUtilizationRates(dev, out u) == 0) Gpu = (int)u.gpu; NM g; try { uint tc; if (nvmlDeviceGetTemperature(dev, 0, out tc) == 0) TempC = (int)tc; } catch { } if (nvmlDeviceGetMemoryInfo(dev, out g) == 0) { VramUsedGB = (float)(g.used / 1073741824.0); VramTotalGB = (float)(g.total / 1073741824.0); } } catch { nv = -1; }
      return;
    }
    if (smiDead || smiBusy || unchecked(Environment.TickCount - smiAt) < 3000) return;
    smiBusy = true; smiAt = Environment.TickCount;
    ThreadPool.QueueUserWorkItem(delegate {
      try {
        ProcessStartInfo si = new ProcessStartInfo("nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits");
        si.UseShellExecute = false; si.RedirectStandardOutput = true; si.CreateNoWindow = true;
        using (Process p = Process.Start(si)) {
          string o = p.StandardOutput.ReadToEnd(); p.WaitForExit(4000);
          string[] a = o.Split('\n')[0].Split(',');
          if (a.Length >= 3) { Gpu = int.Parse(a[0].Trim()); VramUsedGB = (float)(double.Parse(a[1].Trim(), System.Globalization.CultureInfo.InvariantCulture) / 1024.0); VramTotalGB = (float)(double.Parse(a[2].Trim(), System.Globalization.CultureInfo.InvariantCulture) / 1024.0); if (a.Length >= 4) { int tt2; if (int.TryParse(a[3].Trim(), out tt2)) TempC = tt2; } }
        }
      } catch { smiDead = true; }
      smiBusy = false;
    });
  }
}
}
'@ } catch { Log "도우미 바 상태 준비: $_" }
try { Add-Type -AssemblyName System.Security } catch { Log "암호화 준비: $_" }
[FTR]::SetProcessDPIAware() | Out-Null
$fontInfo = [FTRText]::Init((Join-Path $A 'GJ_MapleBold.ttf')); if ($fontInfo -notmatch 'Maple') { Log "글꼴: $fontInfo" }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------- 설정 ----------
function ConvertTo-Hash($o) {
  if ($null -eq $o) { return $null }
  if ($o -is [System.Management.Automation.PSCustomObject]) { $h = @{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hash $p.Value }; return $h }
  if ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) { return ,@($o | ForEach-Object { ConvertTo-Hash $_ }) }
  return $o
}
# (공유판) 기본: 받기·보내기 모두 사비(내 컴퓨터 Ollama 127.0.0.1:11434 · 모델 sabi) · 제미나이는 보내기에서 고를 때만 · 키는 윈도우 DPAPI로 암호화해서 settings.json 에
$S = @{ model = 'gemini-3.5-flash-lite'; localHost = 'http://127.0.0.1:11434'; localModel = 'sabi'; sendEng = 'local'; keyEnc = ''; tab = 'all'; bg = 0.2; usage = @{}; outLang = @{}; tabf = @{}; feedLines = 7; feedOff = $true   # (2026-11-13 대표) 처음 설치 = 가운데 파티글 꺼짐 (설정·입력줄 '가운데'로 켬)
  tr = @{ party = $true; raid = $true; inst = $true; whisper = $true; lfg = $true; say = $true; guild = $true; trade = $true; general = $true; otherch = $true } }   # 기본 = 모든 대화 번역 (북미 서버)
try {
  if (Test-Path $Cfg) {
    $j = ConvertTo-Hash (Get-Content $Cfg -Raw -Encoding UTF8 | ConvertFrom-Json)
    foreach ($k in @($j.Keys)) { if ($k -eq 'tr') { foreach ($t in @($j.tr.Keys)) { $S.tr[$t] = [bool]$j.tr[$t] } } elseif ($k -notin @('localHost', 'localModel', 'key')) { $S[$k] = $j[$k] } }   # (공유판) 엔진 주소·모델은 늘 내 컴퓨터 사비
  }
} catch { Log "설정 읽기: $_" }
if (-not $S.tabsVer) { $S.tabsVer = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }   # 탭 설정 맞추기 기준
$nw0 = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); if ([int64]$S.tabsVer -gt $nw0 + 60) { $S.tabsVer = $nw0 }   # (2026-11-09) 번호가 미래로 앞서 있으면 바로잡음
if (-not $S.fz) { $S.fz = 12 }; if ($null -eq $S.fade) { $S.fade = 60 }   # (2026-10-31) 번역창 글자 크기 · 글 사라짐(초 · 0 = 안 사라짐)
if (-not $S.trAllV1) { foreach ($k in @('party', 'raid', 'inst', 'whisper', 'lfg', 'say', 'guild', 'trade', 'general', 'otherch')) { $S.tr[$k] = $true }; $S.trAllV1 = $true }
# (2026-11-12 대표) 설치 단계: 설치 폴더의 tier.txt (high = Gemma · mid = Qwen3 · low = Gemini) · 없으면 mid
$Tier = 'mid'; try { $tf = Join-Path $Dir 'tier.txt'; if (Test-Path -LiteralPath $tf) { $t0 = ([IO.File]::ReadAllText($tf)).Trim().ToLower(); if ($t0 -in @('high', 'mid', 'low')) { $Tier = $t0 } } } catch {}
if ($Tier -eq 'high') { $S.localModel = 'nangman-gemma' }
if ($Tier -eq 'low') {
  $S.sendEng = 'gemini'
  if (-not $S.lowInit) { foreach ($k in @('lfg', 'say', 'trade', 'general', 'otherch')) { $S.tr[$k] = $false }; $S.lowInit = $true }   # 최저(Gemini): 처음엔 파티·공격대·인던·귓말·길드만 (사용량 아끼기)
}
function Save-Cfg {
  try { ($S | ConvertTo-Json -Depth 6) | Set-Content -Path $Cfg -Encoding UTF8 } catch { Log "설정 저장: $_" }
}
# (공유판) 제미나이 API 키: 윈도우 DPAPI(현재 사용자)로 암호화해서 settings.json 의 keyEnc 에만 둠 · 기록(log)에 절대 안 남김 · 화면엔 끝 4자리만
$KEY_ENT = [Text.Encoding]::UTF8.GetBytes('NangmanTranslator.gemini')
$script:keyPlain = $null; $script:keyEncSeen = $null
function Key-Save([string]$k) {
  $k = ([string]$k).Trim()
  if (-not $k) { $S.keyEnc = ''; $script:keyPlain = ''; $script:keyEncSeen = ''; Save-Cfg; return $true }
  try {
    $b = [System.Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($k), $KEY_ENT, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $S.keyEnc = [Convert]::ToBase64String($b); $script:keyPlain = $k; $script:keyEncSeen = $S.keyEnc; Save-Cfg; return $true
  } catch { Log '제미나이 키 저장 실패 (암호화 안 됨)'; return $false }
}
function Api-Key {
  $e0 = [string]$S.keyEnc
  if (-not $e0) { return '' }
  if ($e0 -eq $script:keyEncSeen -and $null -ne $script:keyPlain) { return [string]$script:keyPlain }
  $script:keyEncSeen = $e0; $script:keyPlain = ''
  try { $script:keyPlain = [Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($e0), $KEY_ENT, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)) } catch { Log '저장된 제미나이 키를 읽을 수 없음 (다시 저장 필요)' }
  return [string]$script:keyPlain
}
function Key-Hint { $k = Api-Key; if (-not $k) { return '' }; if ($k.Length -le 8) { return '저장됨' }; return ('저장됨 (…' + $k.Substring($k.Length - 4) + ')') }

# ---------- 그림 ----------
function Br($hex) { (New-Object System.Windows.Media.BrushConverter).ConvertFromString($hex) }
function HexBr($h) { if (-not $h -or $h.Length -lt 6) { $h = 'ffffff' }; return Br ('#FF' + $h.Substring(0, 6)) }
$IMG = @{}
function Img($name) {
  # (공유판) 그림 파일이 없거나 깨져도 멈추지 않음 (없으면 $null)
  if (-not $IMG.ContainsKey($name)) {
    $bi = $null
    try {
      $ip = Join-Path $A "$name.png"
      if (Test-Path -LiteralPath $ip) { $bi = New-Object System.Windows.Media.Imaging.BitmapImage; [void]$bi.BeginInit(); $bi.UriSource = New-Object Uri $ip; $bi.CacheOption = 'OnLoad'; [void]$bi.EndInit(); [void]$bi.Freeze() }
    } catch { $bi = $null; Log "그림 못 읽음: $name" }
    $IMG[$name] = $bi
  }
  if ($null -eq $IMG[$name]) { return $null }
  return ,$IMG[$name]
}
$FONT = New-Object System.Windows.Media.FontFamily ((New-Object Uri ($A.TrimEnd('\') + '\')), './#Maplestory')
# (2026-11-04) 창 틀 글씨(위 탭·OFF · 아래 보낼 곳·입력 안내·한→영·번역 ON · 줄 앞 채널 배지) = 이사만루체 Medium · 채팅 내용은 메이플 그대로
$UIF = New-Object System.Windows.Media.FontFamily ((New-Object Uri ($A.TrimEnd('\') + '\')), './#esamanru')
$UIF_OK = Test-Path (Join-Path $A 'GJ_UI.ttf')
function UIF($t) { if ($UIF_OK -and $t) { $t.FontFamily = $UIF; $t.FontWeight = 'Medium' } }
# ---------- (2026-11-13 대표) 대화창 글꼴 고르기 : maple(메이플스토리 · 기본) · game(내 와우 Fonts 폴더 글꼴) · malgun(맑은 고딕) · gulim(굴림) ----------
#  번역대화창 글 · 입력칸 · 가운데 파티글 글만 바뀜 (창 틀·설정 글씨는 그대로)
$script:gfAt = [DateTime]::MinValue; $script:gfFF = $null
function Game-FontDir {
  $c = @()
  try { $rf = Join-Path $env:LOCALAPPDATA 'NangmanTranslator\installed.txt'; if (Test-Path -LiteralPath $rf) { foreach ($l in [IO.File]::ReadAllLines($rf)) { if ($l -match '^\W*addon=(.+)$') { $c += (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Matches[1].Trim()))) 'Fonts') } } } } catch {}
  try { foreach ($pr in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Wow' })) { try { if ($pr.Path) { $c += (Join-Path (Split-Path -Parent $pr.Path) 'Fonts') } } catch {} } } catch {}
  $c += 'C:\Program Files (x86)\World of Warcraft\_forever_\Fonts'
  foreach ($d in $c) { if ($d -and (Test-Path -LiteralPath $d)) { return $d } }
  return $null
}
function Game-Font {
  if (([DateTime]::Now - $script:gfAt).TotalSeconds -lt 60) { return $script:gfFF }
  $script:gfAt = [DateTime]::Now; $script:gfFF = $null
  try {
    $fd = Game-FontDir; if (-not $fd) { return $null }
    $fs = @(); foreach ($n in @('ARIALN.TTF', 'FRIZQT__.TTF', '2002.TTF', '2002B.TTF')) { $fs += (Join-Path $fd $n) }
    foreach ($x in @(Get-ChildItem -LiteralPath $fd -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(ttf|otf)$' })) { $fs += $x.FullName }
    foreach ($f in $fs) {
      if (-not (Test-Path -LiteralPath $f)) { continue }
      try {
        $gt = New-Object System.Windows.Media.GlyphTypeface (New-Object Uri $f)
        if (-not $gt.CharacterToGlyphMap.ContainsKey(0xAC00)) { continue }   # 한글이 있는 글꼴만
        $fam = $gt.FamilyNames[[System.Windows.Markup.XmlLanguage]::GetLanguage('en-us')]; if (-not $fam) { $fam = @($gt.FamilyNames.Values)[0] }
        if (-not $fam) { continue }
        $script:gfFF = New-Object System.Windows.Media.FontFamily ((New-Object Uri ($fd.TrimEnd('\') + '\')), ('./#' + $fam))
        return $script:gfFF
      } catch {}
    }
  } catch { Log "와우 글꼴 찾기: $_" }
  return $null
}
function Chat-FontPick([string]$k) {
  switch ($k) {
    'malgun' { return (New-Object System.Windows.Media.FontFamily 'Malgun Gothic') }
    'gulim' { return (New-Object System.Windows.Media.FontFamily 'Gulim') }
    'game' { $g = Game-Font; if ($g) { return $g }; return (New-Object System.Windows.Media.FontFamily 'Malgun Gothic') }
  }
  return $FONT
}
function Font-Tree($el) {
  if (-not $el) { return }
  if ($el -is [System.Windows.Controls.TextBlock] -and $el.FontFamily -ne $UIF) { $el.FontFamily = $script:CFONT }
  foreach ($c in @([System.Windows.LogicalTreeHelper]::GetChildren($el))) { if ($c -is [System.Windows.DependencyObject]) { Font-Tree $c } }
}
function Chat-FontSet([string]$k) {
  if ($k -notin @('maple', 'game', 'malgun', 'gulim')) { $k = 'maple' }
  $S.chatFont = $k; Save-Cfg
  if ($k -eq 'game') { $script:gfAt = [DateTime]::MinValue }
  $script:CFONT = Chat-FontPick $k
  try { $Inp.FontFamily = $script:CFONT } catch {}
  try { Redraw-All } catch { Log "글꼴 다시 그리기: $_" }
  foreach ($w0 in @($Feed.win, $Lfg.win)) { try { if ($w0) { Font-Tree $w0.Content } } catch {} }
  Log ('대화창 글꼴: ' + $k)
}
$CFONT = $FONT
try { $CFONT = Chat-FontPick ([string]$S.chatFont) } catch { Log "글꼴 고르기: $_" }
function Sx-FontGrid {
  $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 2; $ug.Rows = 2
  $cur = $(if ($S.chatFont) { [string]$S.chatFont } else { 'maple' })
  $hasG = $null -ne (Game-Font)
  foreach ($it in @(@('maple', '메이플스토리'), @('game', '와우 글꼴'), @('malgun', '맑은 고딕'), @('gulim', '굴림'))) {
    $on = ($it[0] -eq $cur)
    $b = New-Object System.Windows.Controls.Border; $b.Height = 30; $b.CornerRadius = New-Object System.Windows.CornerRadius(6); $b.Margin = New-Object System.Windows.Thickness(0, 0, 5, 5)
    $b.Background = $(if ($on) { Br '#E6B98E5F' } else { Br '#0DFFFFFF' })
    $l = TB $it[1] 12 $(if ($on) { Br '#FF141414' } else { Br '#FFB8B8B8' }); $l.FontWeight = 'Bold'; $l.HorizontalAlignment = 'Center'; $l.VerticalAlignment = 'Center'
    try { $l.FontFamily = (Chat-FontPick $it[0]) } catch {}
    if ($it[0] -eq 'game') { $b.ToolTip = $(if ($hasG) { '내 와우 Fonts 폴더 글꼴 그대로 (게임 화면과 같은 느낌)' } else { '와우 Fonts 폴더에 한글 글꼴이 없어서 맑은 고딕으로 보여요' }) }
    $b.Child = $l; Sx-Click $b @{ kind = 'cfont'; v = $it[0] }
    [void]$ug.Children.Add($b)
  }
  [void]$popS.Children.Add($ug)
}

$CREAM = Br '#FFF0F0F0'; $GOLD = Br '#FFE3C39A'; $SUBC = Br '#FFD0D0D0'; $MUTED = Br '#FF8A8A8A'   # (2026-11-03) 새 디자인 A안: 검은사막 느낌 무채색 + 구릿빛 포인트
function New-Shadow { $e = New-Object System.Windows.Media.Effects.DropShadowEffect; $e.Color = [System.Windows.Media.Colors]::Black; $e.ShadowDepth = 1; $e.Direction = 315; $e.BlurRadius = 2.5; $e.Opacity = 0.85; $e.RenderingBias = 'Quality'; return $e }
# 글자 그림자: 게임 채팅처럼 검은 글자를 오른쪽 아래로 1픽셀 깔기 (번지는 효과는 글자가 뿌옇게 돼서 안 씀)
$ShT = New-Object System.Windows.Media.TranslateTransform(1, 1)
function Shadow-Of($tb) {
  $sh = TB '' $tb.FontSize (Br '#E6000000')
  $sh.TextWrapping = $tb.TextWrapping; $sh.LineHeight = $tb.LineHeight; $sh.LineStackingStrategy = $tb.LineStackingStrategy; $sh.MaxWidth = $tb.MaxWidth
  $sh.RenderTransform = $ShT; $sh.IsHitTestVisible = $false
  $g = New-Object System.Windows.Controls.Grid
  [void]$g.Children.Add($sh); [void]$g.Children.Add($tb)
  return @{ grid = $g; sh = $sh }
}
function Sync-Shadow($tb, $sh) {
  if ($tb.Inlines.Count -gt 0) { $sh.Text = (@($tb.Inlines) | ForEach-Object { $_.Text }) -join '' } else { $sh.Text = $tb.Text }
}
function New-Outline { $e = New-Object System.Windows.Media.Effects.DropShadowEffect; $e.Color = [System.Windows.Media.Colors]::Black; $e.ShadowDepth = 0; $e.BlurRadius = 3; $e.Opacity = 1; return $e }
function TB($text, $size, $brush) {
  $t = New-Object System.Windows.Controls.TextBlock
  $t.FontFamily = $FONT; $t.FontWeight = 'Bold'; $t.FontSize = $size; $t.Foreground = $brush
  if ($null -ne $text) { $t.Text = $text }
  return $t
}
# (2026-11-03) 새 디자인 A안: 글자 탭 (메달 대신) · disc는 안 보이는 자리표시 · glow = 주황 점(귓말 알림) · ul = 고른 탭 밑줄
function New-TabT([double]$w, $label) {
  $g = New-Object System.Windows.Controls.Grid; $g.Width = $w; $g.Height = 28; $g.Background = Br '#01000000'   # (2026-11-04) 탭 줄 24→28 (입력줄 30과 비슷하게)
  $hb = New-Object System.Windows.Controls.Border; $hb.CornerRadius = New-Object System.Windows.CornerRadius(4, 4, 0, 0); $hb.Margin = New-Object System.Windows.Thickness(1, 2, 1, 0); $hb.IsHitTestVisible = $false; [void]$g.Children.Add($hb)
  $im = New-Object System.Windows.Controls.Image; $im.Visibility = 'Collapsed'; [void]$g.Children.Add($im)
  $t = TB $label 11.5 (Br '#FFA3A3A3'); UIF $t; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'; $t.IsHitTestVisible = $false; $t.Margin = New-Object System.Windows.Thickness(0, 1, 0, 0)
  [void]$g.Children.Add($t)
  $ul = New-Object System.Windows.Shapes.Rectangle; $ul.Height = 2; $ul.Fill = Br '#FFB98E5F'; $ul.VerticalAlignment = 'Bottom'; $ul.Margin = New-Object System.Windows.Thickness(6, 0, 6, 0); $ul.Visibility = 'Hidden'; $ul.IsHitTestVisible = $false
  [void]$g.Children.Add($ul)
  $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 6; $dot.Height = 6; $dot.Fill = Br '#FFE9A23B'; $dot.HorizontalAlignment = 'Right'; $dot.VerticalAlignment = 'Top'; $dot.Margin = New-Object System.Windows.Thickness(0, 4, 3, 0); $dot.Opacity = 0; $dot.IsHitTestVisible = $false
  [void]$g.Children.Add($dot)
  $g.Cursor = [System.Windows.Input.Cursors]::Hand
  return @{ root = $g; disc = $im; glow = $dot; text = $t; ring = $null; ul = $ul; hb = $hb }
}
# (2026-11-03) 새 디자인 A안: 작은 알약 버튼 (켜짐 = 구릿빛)
function New-Pill([double]$w, $label) {
  $g = New-Object System.Windows.Controls.Grid; $g.Height = 20; if ($w -gt 0) { $g.Width = $w }
  $b = New-Object System.Windows.Controls.Border; $b.CornerRadius = New-Object System.Windows.CornerRadius(10); $b.BorderThickness = New-Object System.Windows.Thickness(1)
  [void]$g.Children.Add($b)
  $t = TB $label 10.5 (Br '#FF8A8A8A'); UIF $t; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'; $t.IsHitTestVisible = $false; $t.Margin = New-Object System.Windows.Thickness(9, 0, 9, 0)
  [void]$g.Children.Add($t)
  $im = New-Object System.Windows.Controls.Image; $im.Visibility = 'Collapsed'; [void]$g.Children.Add($im)
  $g.Cursor = [System.Windows.Input.Cursors]::Hand
  $h = @{ root = $g; bg = $b; text = $t; disc = $im; glow = $im; ring = $null }
  Pill-Paint $h $false
  return $h
}
function Pill-Paint($p, [bool]$on) {
  $p.bg.Background = $(if ($on) { Br '#2EB98E5F' } else { Br '#0AFFFFFF' })
  $p.bg.BorderBrush = $(if ($on) { Br '#CCB98E5F' } else { Br '#26FFFFFF' })
  $p.text.Foreground = $(if ($on) { Br '#FFE3C39A' } else { Br '#FF8A8A8A' })
}
# ---------- 창 ----------
$PW = 440; $PH = 230; $TOP = 18
$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'; $win.AllowsTransparency = $true; $win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true; $win.ShowInTaskbar = $false; $win.ShowActivated = $false; $win.ResizeMode = 'NoResize'
$win.Title = '낭만타우렌 번역창'; $win.Width = 10; $win.Height = 10; $win.Left = -3000; $win.Top = -3000
$win.UseLayoutRounding = $true; $win.SnapsToDevicePixels = $true
$Root = New-Object System.Windows.Controls.Grid
$Root.HorizontalAlignment = 'Left'; $Root.VerticalAlignment = 'Top'
$Scale = New-Object System.Windows.Media.ScaleTransform(1, 1)
$Root.LayoutTransform = $Scale
$Outer = New-Object System.Windows.Controls.Grid
$win.Content = $Outer
[void]$Outer.Children.Add($Root)
$Panel = New-Object System.Windows.Controls.Grid
$Panel.Margin = New-Object System.Windows.Thickness(0, $TOP, 0, 0)
$Panel.Width = $PW; $Panel.Height = $PH
$Panel.Background = Br '#01000000'
[void]$Root.Children.Add($Panel)

# 겉모습(판·금테·탭·입력줄) 한 묶음 → 가만히 두면 흐려지고 글자만 남음
$Chrome = New-Object System.Windows.Controls.Grid
[void]$Panel.Children.Add($Chrome)
$Fill = New-Object System.Windows.Controls.Border; $Fill.CornerRadius = New-Object System.Windows.CornerRadius(6); $Fill.Background = Br '#F0111112'; $Fill.IsHitTestVisible = $false   # (2026-11-03) 새 디자인: 금테·9조각 판 대신 테두리 없는 반투명 판
$Fill.Opacity = [double]$S.bg
[void]$Chrome.Children.Add($Fill)
$HeadBar = New-Object System.Windows.Controls.Border; $HeadBar.Height = 28; $HeadBar.VerticalAlignment = 'Top'; $HeadBar.CornerRadius = New-Object System.Windows.CornerRadius(6, 6, 0, 0); $HeadBar.Background = Br '#14FFFFFF'; $HeadBar.IsHitTestVisible = $false
[void]$Chrome.Children.Add($HeadBar)

# 메시지
$Sv = New-Object System.Windows.Controls.ScrollViewer
$Sv.VerticalScrollBarVisibility = 'Hidden'; $Sv.HorizontalScrollBarVisibility = 'Disabled'
$Sv.HorizontalAlignment = 'Left'; $Sv.VerticalAlignment = 'Top'
$Sv.Focusable = $false
$SvIn = New-Object System.Windows.Controls.Grid
$Lines = New-Object System.Windows.Controls.StackPanel
$Lines.VerticalAlignment = 'Bottom'
[void]$SvIn.Children.Add($Lines)
$Sv.Content = $SvIn
$Sv.Add_SizeChanged({ $SvIn.MinHeight = $Sv.ViewportHeight })
[void]$Outer.Children.Add($Sv)

# 번역 미리보기 (입력줄 바로 위)
$Prev = TB '' 10.5 $GOLD
$Prev.VerticalAlignment = 'Bottom'; $Prev.Margin = New-Object System.Windows.Thickness(20, 0, 14, 36); $Prev.TextTrimming = 'CharacterEllipsis'
$PrevS = Shadow-Of $Prev
$PrevG = $PrevS.grid; $PrevG.VerticalAlignment = 'Bottom'; $PrevG.Margin = $Prev.Margin; $Prev.Margin = New-Object System.Windows.Thickness(0)
$PrevS.sh.TextTrimming = 'CharacterEllipsis'
$PrevG.Visibility = 'Collapsed'
[void]$Panel.Children.Add($PrevG)

# 위쪽 메달 탭
$TabCanvas = New-Object System.Windows.Controls.Canvas
$TabCanvas.ClipToBounds = $false
# (2026-11-03) 탭 줄 빈 곳을 끌면 대화창 옮기기 (Ctrl+오른쪽 클릭 = 잠금/풀기)
$MoveStrip = New-Object System.Windows.Controls.Border; $MoveStrip.Height = 28; $MoveStrip.VerticalAlignment = 'Top'; $MoveStrip.Background = Br '#01000000'
[void]$Chrome.Children.Add($MoveStrip)
[void]$Chrome.Children.Add($TabCanvas)
$TABS = @(
  @{ key = 'all'; label = '전체'; name = '전체' },
  @{ key = 'party'; label = '파티'; name = '파티 · 공대 · 인던' },
  @{ key = 'guild'; label = '길드'; name = '길드' },
  @{ key = 'whisper'; label = '귓말'; name = '귓말' }
)
$Medals = @{}
# (2026-11-08 대표) 마지막 탭 옆 [+] = 탭 추가 · 만든 탭은 $S.ctabs(@{key=c1; label; auto}) 에 저장 · 기본 4개 탭은 그대로
$BASETABS = $TABS
$script:PlusM = $null
function CTabs {
  $r = New-Object System.Collections.ArrayList
  foreach ($x in @($S.ctabs)) { if ($x -and $x.key) { [void]$r.Add(@{ key = [string]$x.key; label = [string]$x.label; auto = [bool]$x.auto }) } }
  return ,$r
}
function Tab-Label($k) {
  $k = [string]$k
  if ($TABLABEL -and $TABLABEL.ContainsKey($k)) { return [string]$TABLABEL[$k] }
  foreach ($c in (CTabs)) { if ($c.key -eq $k) { return $c.label } }
  return '전체'
}
function Place-Plus {
  if (-not $script:PlusM) { return }
  $n = @($script:TABS).Count; $x = 8 + $n * 52
  $pw0 = $(if ($script:PWnow) { [double]$script:PWnow } else { [double]$PW })
  $lim = $pw0 - 40; try { if ($TrLab -and $TrLab.ActualWidth -gt 0) { $lim -= $TrLab.ActualWidth } else { $lim -= 50 } } catch { $lim -= 50 }   # 공유판: 오른쪽 '번역 켜짐' 글씨 앞까지
  [System.Windows.Controls.Canvas]::SetLeft($script:PlusM.root, $x + 2); [System.Windows.Controls.Canvas]::SetTop($script:PlusM.root, 0)
  $room = (($x + 50) -le $lim) -and ((CTabs).Count -lt 4)
  $script:PlusM.root.Visibility = $(if ($room) { 'Visible' } else { 'Collapsed' })
}
function Paint-Tabs {
  $k = [string]$S.tab
  foreach ($tb in @($script:TABS)) { $m = $Medals[$tb.key]; if (-not $m) { continue }; $on = ($tb.key -eq $k); $m.text.Foreground = $(if ($on) { Br '#FFFFFFFF' } else { Br '#FFA3A3A3' }); if ($m.ul) { $m.ul.Visibility = $(if ($on) { 'Visible' } else { 'Hidden' }) }; if ($m.hb) { $m.hb.Background = $(if ($on) { Br '#17FFFFFF' } else { $null }) }; if ($on) { $m.glow.Opacity = 0 } }
}
function Build-Tabs {
  foreach ($m in @($Medals.Values)) { try { $TabCanvas.Children.Remove($m.root) } catch {} }
  $Medals.Clear()
  if ($script:PlusM) { try { $TabCanvas.Children.Remove($script:PlusM.root) } catch {} }
  $lst = New-Object System.Collections.ArrayList
  foreach ($tb in $BASETABS) { [void]$lst.Add($tb) }
  foreach ($c in (CTabs)) { [void]$lst.Add(@{ key = $c.key; label = $c.label; name = $c.label; custom = $true }) }
  $script:TABS = $lst.ToArray()
  for ($i = 0; $i -lt $script:TABS.Count; $i++) {
    $tb = $script:TABS[$i]
    $m = New-TabT 50 $tb.label
    [System.Windows.Controls.Canvas]::SetLeft($m.root, 8 + $i * 52); [System.Windows.Controls.Canvas]::SetTop($m.root, 0)
    $m.root.Tag = $tb.key
    $m.root.ToolTip = $tb.name + ' · 오른쪽 클릭: 보일 대화 고르기'
    $m.root.Add_MouseLeftButtonUp({ param($snd, $e) Select-Tab ([string]$snd.Tag); $e.Handled = $true })
    $m.root.Add_MouseRightButtonUp({ param($snd, $e) Show-TabMenu $snd ([string]$snd.Tag); $e.Handled = $true })
    [void]$TabCanvas.Children.Insert(0, $m.root)
    $Medals[$tb.key] = $m
  }
  $p = New-TabT 24 '+'; $p.text.FontSize = 15; $p.text.Foreground = Br '#FFB98E5F'; $p.text.Margin = New-Object System.Windows.Thickness(0, -1, 0, 0); $p.ul.Visibility = 'Collapsed'
  $p.root.ToolTip = '탭 추가'
  $p.root.Add_MouseLeftButtonUp({ param($snd, $e) try { Add-CTab } catch { Log "탭 추가: $_" }; $e.Handled = $true })
  $p.root.Add_MouseEnter({ try { $script:PlusM.hb.Background = Br '#17FFFFFF' } catch {} })
  $p.root.Add_MouseLeave({ try { $script:PlusM.hb.Background = $null } catch {} })
  [void]$TabCanvas.Children.Insert(0, $p.root)
  $script:PlusM = $p
  Place-Plus
  Paint-Tabs
}
function Add-CTab {
  $l = CTabs; if ($l.Count -ge 4) { return }
  if ($script:PlusM -and $script:PlusM.root.Visibility -ne 'Visible') { return }
  $i = 1; while (@($l | Where-Object { $_.key -eq ('c' + $i) }).Count -gt 0) { $i++ }
  $k = 'c' + $i
  [void]$l.Add(@{ key = $k; label = '새 탭'; auto = $true })
  $S.ctabs = @($l.ToArray())
  if ($S.tabf -is [hashtable]) { [void]$S.tabf.Remove($k) }
  Save-Cfg; Tabs-Changed; Build-Tabs; Select-Tab $k
  $m = $Medals[$k]; if ($m) { Show-TabMenu $m.root $k }
}
function Del-CTab($k) {
  $l = CTabs; $n = New-Object System.Collections.ArrayList
  foreach ($c in $l) { if ($c.key -ne $k) { [void]$n.Add($c) } }
  $S.ctabs = @($n.ToArray())
  if ($S.tabf -is [hashtable]) { [void]$S.tabf.Remove($k) }
  $Pop.IsOpen = $false
  if ([string]$S.tab -eq $k) { $S.tab = 'all' }
  Save-Cfg; Tabs-Changed; Build-Tabs; Select-Tab ([string]$S.tab)
}
function Set-CTabLabel($k, [string]$label, [bool]$auto) {
  $label = ([string]$label).Trim(); if ($label.Length -gt 4) { $label = $label.Substring(0, 4) }
  if (-not $label) { $label = '새 탭'; $auto = $true }
  $l = CTabs; $ch = $false
  foreach ($c in $l) { if ($c.key -eq $k -and ($c.label -ne $label -or $c.auto -ne $auto)) { $c.label = $label; $c.auto = $auto; $ch = $true } }
  if (-not $ch) { return }
  $S.ctabs = @($l.ToArray()); Save-Cfg; Tabs-Changed
  $m = $Medals[$k]; if ($m) { $m.text.Text = $label; $m.root.ToolTip = $label + ' · 오른쪽 클릭: 보일 대화 고르기' }
}
Build-Tabs
# 오른쪽 위 '번' 메달 + 상태 글씨
$TrM = New-TabT 24 ([string][char]0xE713); $TrM.text.FontFamily = 'Segoe MDL2 Assets, Segoe UI Symbol'; $TrM.text.FontWeight = 'Normal'; $TrM.text.FontSize = 13; $TrM.text.Margin = New-Object System.Windows.Thickness(0); $TrM.hb.Visibility = 'Collapsed'   # (2026-11-03) 톱니 가운데 정렬·크기 맞춤
[System.Windows.Controls.Canvas]::SetLeft($TrM.root, $PW - 28); [System.Windows.Controls.Canvas]::SetTop($TrM.root, 0); $TrM.ul.Visibility = 'Collapsed'
$TrM.root.ToolTip = '번역 설정'
$TrM.root.Add_MouseLeftButtonUp({ param($snd, $e) Show-Menu $snd; $e.Handled = $true })
$TrM.root.Add_MouseRightButtonUp({ param($snd, $e) Show-Menu $snd; $e.Handled = $true })
[void]$TabCanvas.Children.Add($TrM.root)
$TrM.glow.Opacity = 0
try { foreach ($tb0 in $TABS) { $m0 = $Medals[$tb0.key]; $on0 = ($tb0.key -eq [string]$S.tab); $m0.text.Foreground = $(if ($on0) { Br '#FFFFFFFF' } else { Br '#FFA3A3A3' }); $m0.ul.Visibility = $(if ($on0) { 'Visible' } else { 'Hidden' }); $m0.hb.Background = $(if ($on0) { Br '#17FFFFFF' } else { $null }) } } catch {}
$TrLab = TB '번역 켜짐' 10 $MUTED
$TrLab.HorizontalAlignment = 'Right'; $TrLab.IsHitTestVisible = $false
[System.Windows.Controls.Canvas]::SetTop($TrLab, 7)
[void]$TabCanvas.Children.Add($TrLab)
$TrLab.Add_SizeChanged({ $pw0 = $(if ($script:PWnow) { [double]$script:PWnow } else { [double]$PW }); [System.Windows.Controls.Canvas]::SetLeft($TrLab, $pw0 - 36 - $TrLab.ActualWidth) })
# 금테 입력줄
$Cap = New-Object System.Windows.Controls.Grid
$Cap.Height = 30; $Cap.VerticalAlignment = 'Bottom'; $Cap.Margin = New-Object System.Windows.Thickness(0)   # (2026-11-03) 시안대로 창 아래 평평한 띠
$Cap.Cursor = [System.Windows.Input.Cursors]::IBeam
[void]$Chrome.Children.Add($Cap)
# (2026-11-03) 오른쪽 아래 모서리 끌기 = 크기 (마우스 올렸을 때만 보임)
$Grip = New-Object System.Windows.Controls.Canvas; $Grip.Width = 12; $Grip.Height = 12; $Grip.HorizontalAlignment = 'Right'; $Grip.VerticalAlignment = 'Bottom'; $Grip.Margin = New-Object System.Windows.Thickness(0, 0, 1, 1)
$Grip.Background = Br '#01000000'; $Grip.Cursor = [System.Windows.Input.Cursors]::SizeNWSE; $Grip.Visibility = 'Collapsed'
foreach ($gq in @(@(10, 3, 3, 10), @(10, 7, 7, 10))) { $gl = New-Object System.Windows.Shapes.Line; $gl.X1 = $gq[0]; $gl.Y1 = $gq[1]; $gl.X2 = $gq[2]; $gl.Y2 = $gq[3]; $gl.Stroke = Br '#99B98E5F'; $gl.StrokeThickness = 1.2; $gl.StrokeStartLineCap = 'Round'; $gl.StrokeEndLineCap = 'Round'; [void]$Grip.Children.Add($gl) }
[void]$Root.Children.Add($Grip)
$script:uiDrag = $null; $script:geoOv = $null; $script:ovUntil = [DateTime]::MinValue
function Ui-DragStart($el, [string]$mode) {
  if ($S.uiLock) { return }
  $g0 = $(if ($script:geoOv) { $script:geoOv } else { $state.geo }); if (-not $g0) { return }
  $script:uiDrag = @{ m = $mode; c0 = [FTR]::Cursor(); g0 = $g0.Clone(); el = $el }
  [void]$el.CaptureMouse()
}
function Ui-DragMove {
  $d = $script:uiDrag; if (-not $d) { return }
  $c = [FTR]::Cursor(); $dx = $c[0] - $d.c0[0]; $dy = $c[1] - $d.c0[1]; $g = $d.g0.Clone()
  if ($d.m -eq 'move') { $g.x = $d.g0.x + $dx; $g.y = $d.g0.y + $dy }
  else { $g.w = [int][math]::Max(240 * $g.s, $d.g0.w + $dx); $g.h = [int][math]::Max(120 * $g.s, $d.g0.h + $dy) }
  $script:geoOv = $g; Place-Win
}
function Ui-DragEnd {
  $d = $script:uiDrag; if (-not $d) { return }
  $script:uiDrag = $null; try { $d.el.ReleaseMouseCapture() } catch {}
  $g = $script:geoOv; if (-not $g) { return }
  $s0 = [double]$d.g0.s
  if ($d.m -eq 'move') { $ux = [int][math]::Round(($g.x - $d.g0.x) / $s0); $uy = [int][math]::Round(($g.y - $d.g0.y) / $s0); if ($ux -ne 0 -or $uy -ne 0) { $GC.nudge[0] += $ux; $GC.nudge[1] -= $uy; Game-Cmd '' } }
  else { $uw = [int][math]::Round(($g.w - $d.g0.w) / $s0); $uh = [int][math]::Round(($g.h - $d.g0.h) / $s0); if ($uw -ne 0 -or $uh -ne 0) { $GC.nudge[1] -= $uh; $GC.nudge[2] += $uw; $GC.nudge[3] += $uh; Game-Cmd '' } }
  $script:ovUntil = [DateTime]::Now.AddSeconds(3.5)   # 게임에 들어가 새 자리를 알려 줄 때까지 끈 자리 그대로 유지
}
foreach ($dg in @(@($MoveStrip, 'move'), @($Grip, 'size'))) {
  $dg[0].Tag = $dg[1]
  $dg[0].Add_MouseLeftButtonDown({ param($snd, $e) Ui-DragStart $snd ([string]$snd.Tag); $e.Handled = $true })
  $dg[0].Add_MouseMove({ param($snd, $e) if ($script:uiDrag) { Ui-DragMove } })
  $dg[0].Add_MouseLeftButtonUp({ param($snd, $e) Ui-DragEnd; $e.Handled = $true })
  $dg[0].Add_LostMouseCapture({ param($snd, $e) if ($script:uiDrag) { Ui-DragEnd } })
}
function Ui-LockPaint { $MoveStrip.Cursor = $(if ($S.uiLock) { $null } else { [System.Windows.Input.Cursors]::SizeAll }) }
Ui-LockPaint
# Ctrl+오른쪽 클릭 = 대화창 위치·크기 잠금/풀기 (다른 애드온과 같게)
$Outer.Add_PreviewMouseRightButtonUp({ param($snd, $e)
  if (([FTRK.Keys]::GetAsyncKeyState(0x11) -band 0x8000) -ne 0) {
    $S.uiLock = -not [bool]$S.uiLock; Save-Cfg; Ui-LockPaint
    try { [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = $(if ($S.uiLock) { '대화창 위치·크기 잠금' } else { '대화창 위치·크기 풀림 — 탭 줄 끌기 = 이동 · 오른쪽 아래 모서리 끌기 = 크기' }) }) } catch {}
    $e.Handled = $true
  }
})
$capBg = New-Object System.Windows.Controls.Border
$capBg.Margin = New-Object System.Windows.Thickness(0); $capBg.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 6, 6); $capBg.Background = Br '#0AFFFFFF'   # (2026-11-03) 새 디자인: 금테 없는 평평한 입력줄
[void]$Cap.Children.Add($capBg)
$capG = New-Object System.Windows.Controls.Grid; $capG.IsHitTestVisible = $false
[void]$Cap.Children.Add($capG)
$ChM = New-Pill 0 '일반 ▾'; $ChM.text.Margin = New-Object System.Windows.Thickness(8, 0, 8, 0); $ChM.text.FontSize = 11; $ChM.root.Height = 21
$ChM.bg.CornerRadius = New-Object System.Windows.CornerRadius(3); $ChM.bg.BorderThickness = New-Object System.Windows.Thickness(0)
$ChM.root.HorizontalAlignment = 'Left'; $ChM.root.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
# (2026-11-03) 입력칸 폭: 왼쪽 = 보낼 곳 버튼 폭 · 오른쪽 = 번역ON·가운데 버튼 자리(가운데 입력칸에선 '한' 버튼만)
function Dock-Fit { try { $Dock.Margin = New-Object System.Windows.Thickness(($ChM.root.ActualWidth + 14), 0, $(if ($CIn.on) { 40 } else { 108 }), 0) } catch {} }
$ChM.root.Add_SizeChanged({ Dock-Fit })
$ChM.root.ToolTip = '보낼 곳 (Tab으로 바꾸기)'
$ChM.root.Add_MouseLeftButtonUp({ param($snd, $e) Cycle-Target; $e.Handled = $true })
[void]$Cap.Children.Add($ChM.root)
# (2026-11-03) 새 디자인 A안: 입력줄 오른쪽 = '번역 ON/OFF'(잠깐 멈춤) · '가운데'(가운데 파티글 켜기/끄기 · 오른쪽 클릭 = 설정)
$Gear = @{ root = (New-Object System.Windows.Controls.StackPanel) }; $Gear.root.Orientation = 'Horizontal'
$Gear.root.HorizontalAlignment = 'Right'; $Gear.root.VerticalAlignment = 'Center'; $Gear.root.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0)
$TrP = New-Pill 0 '번역 ON'; $TrP.root.ToolTip = '번역 켜기 / 끄기 (끄면 와우 기본 대화창 · 미니맵 버튼·위쪽 도우미 바와 같이 움직여요)'; [void]$Gear.root.Children.Add($TrP.root)
$CenP = New-Pill 28 ''; $CenP.root.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0); $CenP.root.ToolTip = '가운데 파티글 켜기/끄기 · 오른쪽 클릭 = 띄울 대화 고르기'; [void]$Gear.root.Children.Add($CenP.root)
# (2026-11-03) 시안대로 '가운데'는 글씨 대신 작은 화면 그림
$CenIc = New-Object System.Windows.Controls.Canvas; $CenIc.Width = 14; $CenIc.Height = 14; $CenIc.IsHitTestVisible = $false; $CenIc.HorizontalAlignment = 'Center'; $CenIc.VerticalAlignment = 'Center'
$cRect = New-Object System.Windows.Shapes.Rectangle; $cRect.Width = 12.5; $cRect.Height = 10; $cRect.RadiusX = 1.6; $cRect.RadiusY = 1.6; $cRect.StrokeThickness = 1.5
[System.Windows.Controls.Canvas]::SetLeft($cRect, 0.75); [System.Windows.Controls.Canvas]::SetTop($cRect, 2); [void]$CenIc.Children.Add($cRect)
$cLine = New-Object System.Windows.Shapes.Line; $cLine.X1 = 4.5; $cLine.X2 = 9.5; $cLine.Y1 = 7; $cLine.Y2 = 7; $cLine.StrokeThickness = 1.5; $cLine.StrokeStartLineCap = 'Round'; $cLine.StrokeEndLineCap = 'Round'; [void]$CenIc.Children.Add($cLine)
[void]$CenP.root.Children.Add($CenIc)
function Pills-Paint { Pill-Paint $TrP (-not [bool]$S.pause); $TrP.text.Text = $(if ($S.pause) { '번역 OFF' } else { '번역 ON' }); Pill-Paint $CenP (-not [bool]$S.feedOff); $cRect.Stroke = $CenP.text.Foreground; $cLine.Stroke = $CenP.text.Foreground }
$TrP.root.Add_MouseLeftButtonDown({ param($snd, $e) $e.Handled = $true })
$TrP.root.Add_MouseLeftButtonUp({ param($snd, $e) try { Tr-Set ([bool]$S.pause) } catch { Log "번역 켜기/끄기 버튼: $_" }; $e.Handled = $true })
$CenP.root.Add_MouseLeftButtonDown({ param($snd, $e) $e.Handled = $true })
$CenP.root.Add_MouseLeftButtonUp({ param($snd, $e) try { $S.feedOff = -not [bool]$S.feedOff; Save-Cfg; Pills-Paint; Feed-GameSync; Cen-Moved } catch { Log "가운데 버튼: $_" }; $e.Handled = $true })
# (2026-11-13 대표) 입력하는 중에 파티글을 끄면 가운데 입력칸이 숨으면서 키보드가 어디에도 안 먹었음 → 입력칸을 본 대화창으로 옮기고 그대로 이어서 입력
# (2026-11-13 대표) 게임 쪽 파티글(번역 끈 기본 대화창일 때 가운데 줄·가운데 입력줄)도 이 스위치와 같이 켜고 끔
$script:feedSyncAt = [DateTime]::MinValue
function Feed-GameSync { $script:feedSyncAt = [DateTime]::Now; Game-Cmd ('/ntchat feed ' + $(if ($S.feedOff) { '0' } else { '1' })) }
function Cen-Moved {
  if (-not $state.inputOn) { return }
  if ($S.feedOff -and $CIn.on) {
    try { CIn-Close } catch {}
    [FTR]::NoActivate($script:hwnd, $false); [FTR]::ClickThrough($script:hwnd, $false)
    [FTR]::Focus($script:hwnd); $win.Activate() | Out-Null; $Inp.Focus() | Out-Null; [System.Windows.Input.Keyboard]::Focus($Inp) | Out-Null
  }
}
$CenP.root.Add_MouseRightButtonUp({ param($snd, $e) Show-Menu $snd; $e.Handled = $true })
Pills-Paint
# (2026-11-01) 톱니를 누르면 아래 입력줄(Cap)의 '누르면 입력 시작'이 먼저 받아서 입력칸이 가운데로 옮겨 가며 톱니가 숨어 메뉴가 안 열렸음 → 누름을 여기서 막음 (한/영 버튼과 같게)
[void]$Cap.Children.Add($Gear.root)
# (2026-10-30) 가운데 입력칸에선 톱니 대신 지금 키보드 언어(한/영) 표시
$ImeM = New-Pill 28 '한'; $ImeM.text.Margin = New-Object System.Windows.Thickness(0); $ImeM.text.FontSize = 11; Pill-Paint $ImeM $true
$ImeM.root.HorizontalAlignment = 'Right'; $ImeM.root.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0); $ImeM.root.Visibility = 'Collapsed'; $ImeM.root.IsHitTestVisible = $false
[void]$Cap.Children.Add($ImeM.root)
$script:imeAt = [DateTime]::MinValue
function Ime-Paint {
  if (([DateTime]::Now - $script:imeAt).TotalMilliseconds -lt 120) { return }
  $script:imeAt = [DateTime]::Now
  $ko = $false
  try { $ko = (([System.Windows.Input.InputMethod]::Current.ImeConversionMode.ToString()) -match 'Native') -and ([System.Windows.Input.InputMethod]::Current.ImeState -ne 'Off') } catch {}
  $t = $(if ($ko) { '한' } else { '영' }); if ($ImeM.text.Text -ne $t) { $ImeM.text.Text = $t }
}
$Dock = New-Object System.Windows.Controls.DockPanel
$Dock.Margin = New-Object System.Windows.Thickness(66, 0, 128, 0); $Dock.LastChildFill = $true
[void]$Cap.Children.Add($Dock)
$Lang = TB '' 10.5 $GOLD; UIF $Lang; $Lang.VerticalAlignment = 'Center'
# (2026-10-26) '한 → 영' 글씨를 누르면 보낼 언어 고르기 (마우스 올리면 살짝 빛남)
$LangB = New-Object System.Windows.Controls.Border
$LangB.Child = $Lang; $LangB.VerticalAlignment = 'Center'; $LangB.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)
$LangB.Padding = New-Object System.Windows.Thickness(6, 1, 6, 1); $LangB.CornerRadius = New-Object System.Windows.CornerRadius(8)
$LangB.Background = Br '#01000000'; $LangB.BorderThickness = New-Object System.Windows.Thickness(1); $LangB.BorderBrush = [System.Windows.Media.Brushes]::Transparent
$LangB.Cursor = [System.Windows.Input.Cursors]::Hand; $LangB.ToolTip = '보낼 언어 고르기'
$LangB.Add_MouseEnter({ $LangB.Background = Br '#2EB98E5F'; $LangB.BorderBrush = Br '#B3E3C39A' })
$LangB.Add_MouseLeave({ $LangB.Background = Br '#01000000'; $LangB.BorderBrush = [System.Windows.Media.Brushes]::Transparent })
# 누를 때는 입력줄로 안 넘어가게만 막고, 손을 뗄 때 목록을 엶 (누를 때 열면 손 떼는 순간 바로 닫혔음)
$LangB.Add_MouseLeftButtonDown({ param($snd, $e) $e.Handled = $true })
$LangB.Add_MouseLeftButtonUp({ param($snd, $e) $e.Handled = $true; Show-LangMenu $LangB })
[System.Windows.Controls.DockPanel]::SetDock($LangB, 'Right'); [void]$Dock.Children.Add($LangB)
$Who = TB '' 11.5 (HexBr 'ff80ff'); $Who.VerticalAlignment = 'Center'; $Who.MaxWidth = 120; $Who.TextTrimming = 'CharacterEllipsis'   # (2026-11-03) 긴 채널 이름이 입력칸을 다 먹던 것
[System.Windows.Controls.DockPanel]::SetDock($Who, 'Left'); [void]$Dock.Children.Add($Who)
$InGrid = New-Object System.Windows.Controls.Grid
[void]$Dock.Children.Add($InGrid)
$PhT = TB '메시지 입력…' 11.5 $MUTED; UIF $PhT; $PhT.VerticalAlignment = 'Center'; $PhT.IsHitTestVisible = $false
[void]$InGrid.Children.Add($PhT)
$Inp = New-Object System.Windows.Controls.TextBox
$Inp.FontFamily = $CFONT; $Inp.FontWeight = 'Bold'; $Inp.FontSize = 11.5;  $Inp.Foreground = $CREAM; $Inp.CaretBrush = $GOLD
$Inp.Background = [System.Windows.Media.Brushes]::Transparent; $Inp.BorderThickness = New-Object System.Windows.Thickness(0)
$Inp.VerticalAlignment = 'Center'; $Inp.Padding = New-Object System.Windows.Thickness(0); $Inp.SelectionBrush = Br '#80B98E5F'
[System.Windows.Input.InputMethod]::SetPreferredImeState($Inp, 'On')
[System.Windows.Input.InputMethod]::SetPreferredImeConversionMode($Inp, 'Native')
[void]$InGrid.Children.Add($Inp)
$Cap.Add_MouseLeftButtonDown({ Enter-Input })

# ---------- 번역할 곳 고르기 (메달 오른쪽 클릭 · 톱니) ----------
# (2026-10-26) 게임 대화창 설정과 같은 순서 · c = 게임에서 정한 '가운데' 칸 글자 (보이기만)
$TRCATS = @(
  @{ k = 'say'; n = '일반 대화 · 외침'; c = 's' }, @{ k = 'party'; n = '파티'; c = 'p' }, @{ k = 'raid'; n = '공격대'; c = 'r' }, @{ k = 'inst'; n = '인던 대화'; c = 'i' },
  @{ k = 'guild'; n = '길드 · 관리자'; c = 'g' }, @{ k = 'whisper'; n = '귓말'; c = 'w' },
  @{ k = 'lfg'; n = '파티찾기 채널'; c = 'c' }, @{ k = 'general'; n = '공개 · 일반 채널'; c = 'c' }, @{ k = 'trade'; n = '거래 채널'; c = 'c' }, @{ k = 'otherch'; n = '그 밖의 채널'; c = 'c' }
)
$Pop = New-Object System.Windows.Controls.Primitives.Popup
$Pop.AllowsTransparency = $true; $Pop.StaysOpen = $false; $Pop.Placement = 'Top'
$popB = New-Object System.Windows.Controls.Border
$popB.Background = Br '#F2161617'; $popB.BorderBrush = Br '#1FFFFFFF'; $popB.BorderThickness = New-Object System.Windows.Thickness(1); $popB.CornerRadius = New-Object System.Windows.CornerRadius(8)
$popB.Padding = New-Object System.Windows.Thickness(14, 10, 14, 10)
$popS = New-Object System.Windows.Controls.StackPanel
$popSv = New-Object System.Windows.Controls.ScrollViewer; $popSv.VerticalScrollBarVisibility = 'Hidden'; $popSv.HorizontalScrollBarVisibility = 'Disabled'; $popSv.Content = $popS   # (공유판) 설정이 길어져서 휠로 내려 보기
$popB.Child = $popSv
$popRoot = New-Object System.Windows.Controls.Grid
$popRoot.LayoutTransform = $Scale
[void]$popRoot.Children.Add($popB)
$Pop.Child = $popRoot
# ---------- (2026-10-31) 대화창 설정 (번역창 메뉴 안) ----------
#  번역창 자체 설정(글자·배경·사라짐)은 바로 · 게임 쪽(가운데 글자·가운데 칸·위치·크기·채널)은 '/ntchat …'을 모아서 0.9초 뒤 한 번에 게임에 입력
$script:feedHold = [DateTime]::MinValue
$script:Chans = @{ joined = (New-Object System.Collections.ArrayList); server = @() }
$GC = @{ nudge = @(0, 0, 0, 0); cfont = $null; lines = (New-Object System.Collections.ArrayList) }
$GcT = New-Object Windows.Threading.DispatcherTimer
$GcT.Interval = [TimeSpan]::FromMilliseconds(900)
$GcT.Add_Tick({
  $GcT.Stop()
  try {
    $ls = @()
    if ($null -ne $GC.cfont) { $ls += ('/ntchat cfont ' + $GC.cfont) }
    $n = $GC.nudge; if ($n[0] -ne 0 -or $n[1] -ne 0 -or $n[2] -ne 0 -or $n[3] -ne 0) { $ls += ('/ntchat nudge {0} {1} {2} {3}' -f $n[0], $n[1], $n[2], $n[3]) }
    foreach ($l in $GC.lines) { $ls += [string]$l }
    $GC.cfont = $null; $GC.nudge = @(0, 0, 0, 0); $GC.lines.Clear()
    if ($ls.Count -eq 0) { return }
    if ([FTR]::FindWow() -eq [IntPtr]::Zero) { Set-Prev '게임이 안 켜져 있어요'; $PrevG.Visibility = 'Visible'; return }
    $was = $Pop.IsOpen
    $script:feedHold = [DateTime]::Now.AddSeconds(4)
    Send-WowNow $ls $true $true
    if ($was) { $Pop.IsOpen = $true; if ($script:popMode -eq 'set') { Build-SetMenu } elseif ($script:popMode -eq 'tr') { Build-Menu } }
  } catch { Log "대화창 설정 보내기: $_" }
})
# 게임 기본대화창과 탭·보일 대화 설정을 하나로 · 마지막에 바꾼 쪽이 이김
#  번역창 → 게임: '/ntchat tabs 번호 순서/개수 내용' · 게임 → 번역창: 신호 줄 'T' (번호 · 내용) · 내용 약속은 게임 애드온 Chat.lua와 같음
$TCF = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($kv in @(@('party','p'),@('raid','r'),@('inst','i'),@('whisper','w'),@('guild','g'),@('say','s'),@('lfg','l'),@('general','n'),@('trade','t'),@('otherch','o'),@('sys','y'),@('loot','b'),@('xp','x'),@('npc','m'),@('ch:general','G'),@('ch:trade','T'),@('ch:localdefense','D'),@('ch:lookingforgroup','L'),@('ch:worlddefense','W'))) { $TCF[$kv[0]] = $kv[1] }
$TCR = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($k0 in @($TCF.Keys)) { $TCR[$TCF[$k0]] = $k0 }
function Tabs-Clean([string]$s) { $s = [regex]::Replace([string]$s, '\s', '_'); return [regex]::Replace($s, '[/~,=#;+\-|]', '') }
function Tabs-Pack {
  $cs = @(); foreach ($c in (CTabs)) { $cs += ('{0}~{1}~{2}' -f $c.key, (Tabs-Clean $c.label), $(if ($c.auto) { '1' } else { '0' })) }
  $segs = New-Object System.Collections.ArrayList; [void]$segs.Add('C=' + ($cs -join ','))
  if ($S.tabf -is [hashtable]) {
    foreach ($tk in @($S.tabf.Keys)) {
      $f = $S.tabf[$tk]; if (-not ($f -is [hashtable])) { continue }
      $e = New-Object System.Text.StringBuilder
      foreach ($k in @($f.Keys)) {
        $sg = $(if ([bool]$f[$k]) { '+' } else { '-' })
        $ks = [string]$k
        if ($TCF.ContainsKey($ks)) { [void]$e.Append($sg + $TCF[$ks]) }
        elseif ($ks.StartsWith('ch:')) { [void]$e.Append($sg + '#' + (Tabs-Clean $ks.Substring(3)) + ';') }
      }
      [void]$segs.Add((Tabs-Clean ([string]$tk)) + '=' + $e.ToString())
    }
  }
  return ($segs -join '/')
}
function Tabs-Apply([string]$tstr) {   # (2026-11-12) 파워셸은 변수 대소문자를 안 가려서 $s 가 설정 $S 를 가리고 있었음 → 게임 탭 설정이 안 들어오던 것
  $ct = New-Object System.Collections.ArrayList; $tf = @{}
  foreach ($seg in ($tstr -split '/')) {
    $i = $seg.IndexOf('='); if ($i -lt 1) { continue }
    $k = $seg.Substring(0, $i); $v = $seg.Substring($i + 1)
    if ($k -ceq 'C') {
      foreach ($it in ($v -split ',')) { $m = [regex]::Match($it, '^(c\d+)~([^~]*)~([01])$'); if ($m.Success) { [void]$ct.Add(@{ key = $m.Groups[1].Value; label = ($m.Groups[2].Value -replace '_', ' '); auto = ($m.Groups[3].Value -eq '1') }) } }
    } else {
      $f = @{}; $p = 0
      while ($p -lt $v.Length) {
        $on = ([string]$v[$p] -eq '+'); $p++
        if ($p -ge $v.Length) { break }
        $c = [string]$v[$p]
        if ($c -eq '#') { $j = $v.IndexOf(';', $p); if ($j -lt 0) { $j = $v.Length }; $f['ch:' + ($v.Substring($p + 1, $j - $p - 1) -replace '_', ' ')] = $on; $p = $j + 1 }
        else { if ($TCR.ContainsKey($c)) { $f[$TCR[$c]] = $on }; $p++ }
      }
      $tf[$k] = $f
    }
  }
  $S.ctabs = @($ct.ToArray()); $S.tabf = $tf
}
function Tabs-Push {
  try {
    $tstr = Tabs-Pack; $v = [int64]$S.tabsVer   # (2026-11-12) $s → $tstr (설정 $S 를 가려서 번호가 0으로 가던 것)
    $parts = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $tstr.Length; $i += 110) { [void]$parts.Add($tstr.Substring($i, [math]::Min(110, $tstr.Length - $i))) }
    if ($parts.Count -eq 0) { [void]$parts.Add('C=') }
    for ($i = 0; $i -lt $parts.Count; $i++) { Game-Cmd ('/ntchat tabs {0} {1}/{2} {3}' -f $v, ($i + 1), $parts.Count, $parts[$i]) }
  } catch { Log "탭 보내기: $_" }
}
function Tabs-Changed {
  $nw = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $S.tabsVer = [math]::Max([int64]$S.tabsVer + 1, $nw)
  $script:tabsMine = $true   # (2026-11-11) 이번에 켠 뒤 번역창에서 탭을 바꿨다는 표시 (이때만 번역창 쪽이 게임을 덮어씀)
  Save-Cfg; Tabs-Push
}
function Game-Cmd([string]$line) { if ($line) { [void]$GC.lines.Add($line) }; $script:feedHold = [DateTime]::Now.AddSeconds(15); $GcT.Stop(); $GcT.Start() }
$CENTERKEY = @{ s = 'say'; p = 'party'; r = 'raid'; i = 'inst'; g = 'guild'; w = 'whisper'; c = 'channel' }
function Center-Toggle([string]$ch) {
  if (-not $CENTERKEY[$ch]) { return }
  $m = [string]$Feed.mask; if ($m -eq '-') { $m = '' }
  $on = $m.Contains($ch)
  $m = $(if ($on) { $m.Replace($ch, '') } else { $m + $ch }); if (-not $m) { $m = '-' }
  $Feed.mask = $m
  Game-Cmd ('/ntchat center {0} {1}' -f $CENTERKEY[$ch], $(if ($on) { 0 } else { 1 }))
}
function Set-Prev($t) { $Prev.Text = $t; $PrevS.sh.Text = $t }
# (2026-10-26) 열린 메뉴를 연 버튼으로 다시 누르면 닫히게 (누르는 순간 '바깥 클릭'으로 닫혔다가 손 뗄 때 다시 열리던 것)
$script:popClosedAt = [DateTime]::MinValue; $script:popKey = ''
$Pop.Add_Closed({ $script:popClosedAt = [DateTime]::Now })
function Pop-Again([string]$key) {
  $again = ($script:popKey -eq $key) -and (([DateTime]::Now - $script:popClosedAt).TotalMilliseconds -lt 400)
  $script:popKey = $key
  if ($again) { $script:popKey = '' }
  return $again
}
# ===== (2026-11-04) 톱니 설정 = 승인한 시안 '대화창 설정' 패널 모양 (A안) =====
#  섹션 머리띠 + 둥근 스위치 + 채널 칩 + 크기 버튼 · 클릭은 전부 Sx-Do 한 곳에서 처리 (Tag = 할 일)
$SXW = 392
function Sx-Click($el, $tag) {
  $el.Tag = $tag; $el.Cursor = [System.Windows.Input.Cursors]::Hand; $el.Background = $(if ($el.Background) { $el.Background } else { Br '#01000000' })
  $el.Add_MouseLeftButtonDown({ param($snd, $e) $e.Handled = $true })
  $el.Add_MouseLeftButtonUp({ param($snd, $e) try { Sx-Do $snd.Tag } catch { Log "설정 클릭: $_" }; $e.Handled = $true })
}
function Sx-Do($t) {
  switch ([string]$t.kind) {
    'close' { $Pop.IsOpen = $false; return }
    'quit' { $Pop.IsOpen = $false; Tr-Quit; return }
    'help' { $Pop.IsOpen = $false; foreach ($hl in @('── 번역 대화창 사용법 ──', '· 답장: 와우 화면에서 Shift+Enter 또는 아래 입력칸 클릭 → 한국어로 쓰고 Enter = 번역해서 게임에 보냄', '· Tab = 보낼 곳(일반·파티·귓말 등) 바꾸기 · Esc = 입력 취소', '· 탭 오른쪽 클릭 = 그 탭에 보일 대화 고르기', '· 창 옮기기 = 위쪽 탭 줄 끌기 · 크기 = 맨 오른쪽 아래 구석의 금색 빗금 끌기 (마우스를 올리면 보여요)', '· Ctrl + 오른쪽 클릭 = 위치·크기 잠금 / 풀기 (잠겨 있으면 빗금이 안 보여요)', '· [번역 ON] = 받은 말 번역 켜기·끄기 · 톱니(설정) = 번역할 대화 · 가운데 파티글 · 글자 크기 등', '· 엉망이 되면 설정 맨 아래 [위치·크기 처음대로]')) { try { [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = $hl }) } catch {} }; return }   # (2026-11-12 대표) 설정 → 사용법 = 대화창에 사용법 몇 줄
    'pause' { Tr-Set ([bool]$S.pause) }   # (공유판) 번역 켜기/끄기 = 미니맵 버튼·도우미 바·번역 ON 알약과 같은 상태
    'feed' { $S.feedOff = -not [bool]$S.feedOff; Save-Cfg; Pills-Paint; Feed-GameSync; try { Cen-Moved } catch {} }
    'tr' { $S.tr[[string]$t.k] = -not [bool]$S.tr[[string]$t.k]; Save-Cfg }
    'tab' { $ff = Tab-Filt ([string]$S.tab); $ff[[string]$t.k] = -not (Tab-On $ff ([string]$t.k)); Save-Cfg; Tabs-Changed; Apply-AllTabs }
    'cen' { Center-Toggle ([string]$t.k) }
    'cenx' {   # (2026-11-08) 채널 칩: 게임 쪽 '채널'이 꺼져 있으면 이 채널만 켠 채로 켬 · 켜져 있으면 이 채널만 켜고 끔
      $k = [string]$t.k
      if (-not ([string]$Feed.mask).Contains('c')) {
        $lst = @(); foreach ($j in @($script:Chans.joined)) { $b0 = Cen-ChBase $j.name; if ($b0 -and $b0 -ne $k -and $lst -notcontains $b0) { $lst += $b0 } }
        $S.cenChOff = ($lst -join '|'); Save-Cfg; Cen-SyncGame; Center-Toggle 'c'
        $Feed.mask = ([string]$Feed.mask) + 'c'   # 게임이 알려 주기 전에도 칩이 바로 켜져 보이게
      } else {
        $lst = @(([string]$S.cenChOff -split '\|') | Where-Object { $_ }); if ($lst -contains $k) { $lst = @($lst | Where-Object { $_ -ne $k }) } else { $lst += $k }; $S.cenChOff = ($lst -join '|'); Save-Cfg; Cen-SyncGame
      }
    }
    'cench' { $lst = @(([string]$S.cenChOff -split '\|') | Where-Object { $_ }); $k = [string]$t.k; if ($lst -contains $k) { $lst = @($lst | Where-Object { $_ -ne $k }) } else { $lst += $k }; $S.cenChOff = ($lst -join '|'); Save-Cfg; Cen-SyncGame }   # (2026-11-05) 채널별 가운데 파티글
    'fz' { $S.fz = [int]$t.v; Save-Cfg; Redraw-All }
    'cfont' { Chat-FontSet ([string]$t.v) }
    'fzd' { $S.fz = [math]::Max(10, [math]::Min(20, [int]$S.fz + [int]$t.v)); Save-Cfg; Redraw-All }
    'cfz' { $Feed.font = [int]$t.v; $GC.cfont = [int]$t.v; Game-Cmd ''; try { Feed-Make; Feed-Place } catch {} }
    'fade' { $S.fade = [int]$t.v; Save-Cfg }
    'join' { Game-Cmd ('/ntchat join ' + [string]$t.k) }
    'leave' { Game-Cmd ('/ntchat leave ' + [string]$t.k) }
    'reset' { $GC.nudge = @(0, 0, 0, 0); Game-Cmd '/ntchat reset' }
    'fedit' { $Pop.IsOpen = $false; FEd-Start; return }   # (공유판) 가운데 파티글 위치·크기 조절 모드
    'sendeng' { $S.sendEng = $(if ([int]$t.v -eq 2) { 'gemini' } else { 'local' }); Save-Cfg; if ($S.sendEng -eq 'gemini' -and -not (Api-Key)) { $Pop.IsOpen = $false; Key-Dialog; return } }
    'key' { $Pop.IsOpen = $false; Key-Dialog; return }
    'donate' { $script:dnOpen = -not [bool]$script:dnOpen; Build-Menu; if ($script:dnOpen) { try { [void]$popSv.Dispatcher.BeginInvoke([System.Action]{ try { $popSv.ScrollToEnd() } catch {} }, [System.Windows.Threading.DispatcherPriority]::Loaded) } catch {} }; return }
  }
  Build-Menu
}
function Sx-Head([string]$text, [string]$badge = '', [string]$right = '', [bool]$warm = $true) {   # (2026-11-04) 인자 이름을 $gold로 했다가 전역 $GOLD(글자 색)를 가려서 멈췄음 → $warm
  $d = New-Object System.Windows.Controls.DockPanel; $d.LastChildFill = $false; $d.Background = Br '#12FFFFFF'
  $d.Margin = New-Object System.Windows.Thickness(-14, 12, -14, 7)
  $t = TB $text 12 (Br '#FFE6E6E6'); $t.FontWeight = 'Bold'; $t.VerticalAlignment = 'Center'; $t.Margin = New-Object System.Windows.Thickness(14, 5, 0, 5)
  [System.Windows.Controls.DockPanel]::SetDock($t, 'Left'); [void]$d.Children.Add($t)
  if ($badge) {
    $b = New-Object System.Windows.Controls.Border; $b.CornerRadius = New-Object System.Windows.CornerRadius(8); $b.Padding = New-Object System.Windows.Thickness(7, 0, 7, 1); $b.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0); $b.VerticalAlignment = 'Center'
    $b.Background = $(if ($warm) { Br '#2EB98E5F' } else { Br '#14FFFFFF' })
    $b.Child = (TB $badge 10.5 $(if ($warm) { Br '#FFE3C39A' } else { Br '#FFD0D0D0' }))
    [System.Windows.Controls.DockPanel]::SetDock($b, 'Left'); [void]$d.Children.Add($b)
  }
  if ($right) { $r = TB $right 12 $GOLD; $r.VerticalAlignment = 'Center'; $r.Margin = New-Object System.Windows.Thickness(0, 0, 14, 0); [System.Windows.Controls.DockPanel]::SetDock($r, 'Right'); [void]$d.Children.Add($r) }
  [void]$popS.Children.Add($d)
}
function Sx-Switch([string]$label, [bool]$on, $tag, [string]$sub = '') {
  $b = New-Object System.Windows.Controls.Border; $b.Height = 38; $b.CornerRadius = New-Object System.Windows.CornerRadius(6); $b.Background = Br '#0AFFFFFF'; $b.Margin = New-Object System.Windows.Thickness(0, 0, 8, 8)
  $d = New-Object System.Windows.Controls.DockPanel; $d.Margin = New-Object System.Windows.Thickness(12, 0, 10, 0)
  $tr = New-Object System.Windows.Controls.Grid; $tr.Width = 34; $tr.Height = 18; $tr.VerticalAlignment = 'Center'
  $tk = New-Object System.Windows.Controls.Border; $tk.CornerRadius = New-Object System.Windows.CornerRadius(9); $tk.Background = $(if ($on) { Br '#FFB98E5F' } else { Br '#26FFFFFF' }); [void]$tr.Children.Add($tk)
  $kn = New-Object System.Windows.Shapes.Ellipse; $kn.Width = 14; $kn.Height = 14; $kn.Fill = Br '#FFFFFFFF'; $kn.HorizontalAlignment = $(if ($on) { 'Right' } else { 'Left' }); $kn.Margin = New-Object System.Windows.Thickness(2, 0, 2, 0); [void]$tr.Children.Add($kn)
  [System.Windows.Controls.DockPanel]::SetDock($tr, 'Right'); [void]$d.Children.Add($tr)
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Center'
  $l = TB $label 12.5 $(if ($on) { $CREAM } else { $SUBC }); [void]$sp.Children.Add($l)
  if ($sub) { $s2 = TB $sub 9.5 $MUTED; [void]$sp.Children.Add($s2) }
  [void]$d.Children.Add($sp)
  $b.Child = $d; Sx-Click $b $tag
  return $b
}
function Sx-Chip([string]$label, [string]$color, [bool]$on, $tag) {
  $b = New-Object System.Windows.Controls.Border; $b.Height = 26; $b.CornerRadius = New-Object System.Windows.CornerRadius(13); $b.Padding = New-Object System.Windows.Thickness(10, 0, 11, 0); $b.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
  $b.Background = $(if ($on) { Br '#38B98E5F' } else { Br '#0DFFFFFF' })
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'
  if ($color) { $dt = New-Object System.Windows.Shapes.Ellipse; $dt.Width = 8; $dt.Height = 8; $dt.Fill = Br $color; $dt.VerticalAlignment = 'Center'; $dt.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0); if (-not $on) { $dt.Opacity = 0.5 }; [void]$sp.Children.Add($dt) }
  $l = TB $label 11.5 $(if ($on) { Br '#FFE3C39A' } else { $MUTED }); $l.FontWeight = 'Bold'; $l.VerticalAlignment = 'Center'; [void]$sp.Children.Add($l)
  $b.Child = $sp; Sx-Click $b $tag
  return $b
}
# (2026-11-13 대표 A안) 가운데 파티글 설정을 금테 카드 하나로 · 머리줄 = 제목 + 켜기 스위치 · 꺼져 있으면 머리줄만 (아래 항목 접힘)
function Sx-FeedCard([scriptblock]$body) {
  $on = -not [bool]$S.feedOff
  $card = New-Object System.Windows.Controls.Border; $card.BorderBrush = Br '#FF6E5A35'; $card.BorderThickness = New-Object System.Windows.Thickness(3, 1, 1, 1)
  $card.CornerRadius = New-Object System.Windows.CornerRadius(8); $card.Background = Br '#0DE0B95A'; $card.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
  $card.Padding = New-Object System.Windows.Thickness(12, 0, 12, $(if ($on) { 12 } else { 0 }))
  $st = New-Object System.Windows.Controls.StackPanel
  $hd = New-Object System.Windows.Controls.DockPanel; $hd.LastChildFill = $false; $hd.Margin = New-Object System.Windows.Thickness(0, 10, 0, $(if ($on) { 4 } else { 10 }))
  $tr = New-Object System.Windows.Controls.Grid; $tr.Width = 34; $tr.Height = 18; $tr.VerticalAlignment = 'Center'
  $tk = New-Object System.Windows.Controls.Border; $tk.CornerRadius = New-Object System.Windows.CornerRadius(9); $tk.Background = $(if ($on) { Br '#FFB98E5F' } else { Br '#26FFFFFF' }); [void]$tr.Children.Add($tk)
  $kn = New-Object System.Windows.Shapes.Ellipse; $kn.Width = 14; $kn.Height = 14; $kn.Fill = $(if ($on) { Br '#FFFFFFFF' } else { Br '#FF9A9A9A' }); $kn.HorizontalAlignment = $(if ($on) { 'Right' } else { 'Left' }); $kn.Margin = New-Object System.Windows.Thickness(2, 0, 2, 0); [void]$tr.Children.Add($kn)
  [System.Windows.Controls.DockPanel]::SetDock($tr, 'Right'); [void]$hd.Children.Add($tr)
  $tsp = New-Object System.Windows.Controls.StackPanel; $tsp.VerticalAlignment = 'Center'
  $tt = TB '가운데 파티글' 13.5 $GOLD; $tt.FontWeight = 'Bold'; [void]$tsp.Children.Add($tt)
  [void]$tsp.Children.Add((TB $(if ($on) { '화면 가운데(캐릭터 머리 위)에 파티 대화를 크게' } else { '와이드 모니터처럼 화면이 넓으면 켜 보세요' }) 10 (Br '#FFBFAE86')))
  [System.Windows.Controls.DockPanel]::SetDock($tsp, 'Left'); [void]$hd.Children.Add($tsp)
  Sx-Click $hd @{ kind = 'feed' }
  [void]$st.Children.Add($hd); $card.Child = $st; [void]$popS.Children.Add($card)
  if ($on) { $popS = $st; & $body }
}
function Sx-Sub([string]$t, [double]$top = 8) { $x = TB $t 10.5 $MUTED; $x.Margin = New-Object System.Windows.Thickness(2, $top, 0, 4); [void]$popS.Children.Add($x) }
function Sx-Step([string]$label, [int]$val, [string]$kind, [string]$suf = '') {
  $b = New-Object System.Windows.Controls.Border; $b.Height = 38; $b.CornerRadius = New-Object System.Windows.CornerRadius(6); $b.Background = Br '#0AFFFFFF'; $b.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
  $d = New-Object System.Windows.Controls.DockPanel; $d.Margin = New-Object System.Windows.Thickness(12, 0, 8, 0); $d.LastChildFill = $false
  $t = TB $label 12.5 $CREAM; $t.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($t, 'Left'); [void]$d.Children.Add($t)
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($sp, 'Right')
  foreach ($q in @(@([string][char]0x2212, -1), @('', 0), @('+', 1))) {
    if ($q[1] -eq 0) { $v = TB ([string]$val + $suf) 13 $GOLD; $v.MinWidth = 34; $v.TextAlignment = 'Center'; $v.VerticalAlignment = 'Center'; [void]$sp.Children.Add($v); continue }
    $k = New-Object System.Windows.Controls.Border; $k.Width = 26; $k.Height = 24; $k.CornerRadius = New-Object System.Windows.CornerRadius(4); $k.Background = Br '#1FFFFFFF'
    $kt = TB $q[0] 13 $CREAM; $kt.HorizontalAlignment = 'Center'; $kt.VerticalAlignment = 'Center'; $k.Child = $kt
    Sx-Click $k @{ kind = $kind; v = [int]$q[1] }; [void]$sp.Children.Add($k)
  }
  [void]$d.Children.Add($sp); $b.Child = $d; [void]$popS.Children.Add($b)
}
function Sx-Seg($items, $cur, [string]$kind) {
  # items = @(@(값, '이름'), …) · 지금 값과 가장 가까운 것을 칠함
  $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = @($items).Count; $ug.Rows = 1
  $best = $null; $bd = 1e9; foreach ($it in $items) { $dd = [math]::Abs([double]$it[0] - [double]$cur); if ($it[0] -eq 0 -and $cur -ne 0) { $dd = 1e8 }; if ($dd -lt $bd) { $bd = $dd; $best = $it[0] } }
  foreach ($it in $items) {
    $on = ($it[0] -eq $best)
    $b = New-Object System.Windows.Controls.Border; $b.Height = 30; $b.CornerRadius = New-Object System.Windows.CornerRadius(6); $b.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0)
    $b.Background = $(if ($on) { Br '#E6B98E5F' } else { Br '#0DFFFFFF' })
    $l = TB $it[1] 11.5 $(if ($on) { Br '#FF141414' } else { Br '#FFB8B8B8' }); $l.FontWeight = 'Bold'; $l.HorizontalAlignment = 'Center'; $l.VerticalAlignment = 'Center'
    $b.Child = $l; Sx-Click $b @{ kind = $kind; v = $it[0] }
    [void]$ug.Children.Add($b)
  }
  [void]$popS.Children.Add($ug)
}
function Sx-Slider([double]$v01) {
  # 배경 진하기: 끌거나 누르면 바로 바뀜 (메뉴를 다시 그리지 않고 막대만)
  $g = New-Object System.Windows.Controls.Grid; $g.Height = 22; $g.Background = Br '#01000000'; $g.Cursor = [System.Windows.Input.Cursors]::Hand; $g.Margin = New-Object System.Windows.Thickness(0, 0, 0, 2)
  $tk = New-Object System.Windows.Controls.Border; $tk.Height = 4; $tk.CornerRadius = New-Object System.Windows.CornerRadius(2); $tk.Background = Br '#26FFFFFF'; $tk.VerticalAlignment = 'Center'; [void]$g.Children.Add($tk)
  $fl = New-Object System.Windows.Controls.Border; $fl.Height = 4; $fl.CornerRadius = New-Object System.Windows.CornerRadius(2); $fl.Background = Br '#FFB98E5F'; $fl.VerticalAlignment = 'Center'; $fl.HorizontalAlignment = 'Left'; [void]$g.Children.Add($fl)
  $kn = New-Object System.Windows.Shapes.Ellipse; $kn.Width = 14; $kn.Height = 14; $kn.Fill = Br '#FFE3C39A'; $kn.HorizontalAlignment = 'Left'; $kn.VerticalAlignment = 'Center'; [void]$g.Children.Add($kn)
  $W = $SXW - 4
  $fl.Width = [math]::Max(0, $v01 * $W); $kn.Margin = New-Object System.Windows.Thickness(([math]::Max(0, $v01 * $W - 7)), 0, 0, 0)
  $g.Tag = @{ fl = $fl; kn = $kn; W = $W }
  $g.Add_MouseLeftButtonDown({ param($snd, $e) Sx-SlideSet $snd $e; [void]$snd.CaptureMouse(); $e.Handled = $true })
  $g.Add_MouseMove({ param($snd, $e) if ($snd.IsMouseCaptured) { Sx-SlideSet $snd $e } })
  $g.Add_MouseLeftButtonUp({ param($snd, $e) if ($snd.IsMouseCaptured) { $snd.ReleaseMouseCapture(); try { Save-Cfg } catch {} }; $e.Handled = $true })
  [void]$popS.Children.Add($g)
}
function Sx-SlideSet($snd, $e) {
  $p = $e.GetPosition($snd).X; $tg = $snd.Tag
  $x = [math]::Round([math]::Min(1.0, [math]::Max(0.0, $p / $tg.W)) * 20) / 20
  $tg.fl.Width = $x * $tg.W; $tg.kn.Margin = New-Object System.Windows.Thickness(([math]::Max(0, $x * $tg.W - 7)), 0, 0, 0)
  $S.bg = $x; $Fill.Opacity = $x
  try { if ($script:sxBgLab) { $script:sxBgLab.Text = ('{0}%' -f [int][math]::Round($x * 100)) } } catch {}
}
function Build-Menu {
  $popS.Children.Clear(); $popS.Width = $SXW
  # 머리줄
  $hd = New-Object System.Windows.Controls.DockPanel; $hd.LastChildFill = $false; $hd.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)
  $tab = [string]$S.tab; $tl = Tab-Label $tab
  $ht = TB '대화창 설정' 13.5 (Br '#FFFFFFFF'); $ht.FontWeight = 'Bold'; $ht.VerticalAlignment = 'Center'
  [System.Windows.Controls.DockPanel]::SetDock($ht, 'Left'); [void]$hd.Children.Add($ht)
  $x = TB ([string][char]0x00D7) 18 (Br '#FFA3A3A3'); $x.VerticalAlignment = 'Center'; $x.Padding = New-Object System.Windows.Thickness(6, 0, 2, 2)
  [System.Windows.Controls.DockPanel]::SetDock($x, 'Right'); Sx-Click $x @{ kind = 'close' }; [void]$hd.Children.Add($x)
  [void]$popS.Children.Add($hd)
  # 번역
  Sx-Head '번역'
  $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 1; $ug.Margin = New-Object System.Windows.Thickness(0, 0, -8, 0)
  [void]$ug.Children.Add((Sx-Switch '번역' (-not [bool]$S.pause) @{ kind = 'pause' } '끄면 와우 기본 대화창으로'))   # (2026-11-13) 파티글 켜기는 아래 파티글 카드 머리줄로
  [void]$popS.Children.Add($ug)
  # 번역할 대화
  Sx-Head '번역할 대화' '모든 탭 공통' '' $false
  $wp = New-Object System.Windows.Controls.WrapPanel
  foreach ($c in $TRCATS) { $nm = $TABSHORT[$c.k]; if (-not $nm) { $nm = $c.n }; [void]$wp.Children.Add((Sx-Chip $nm $TABCOL[$c.k] ([bool]$S.tr[$c.k]) @{ kind = 'tr'; k = $c.k })) }
  [void]$popS.Children.Add($wp)
  # (공유판) 보내기 번역: 자체 번역(사비) / 제미나이 · 제미나이가 안 되면(오류·한도) 그 글만 사비로
  Sx-Head '보내기 번역' '받기는 늘 자체 번역' '' $false
  Sx-Seg @(@(1, '자체 번역'), @(2, '제미나이 번역')) $(if ([string]$S.sendEng -eq 'gemini') { 2 } else { 1 }) 'sendeng'
  $kb = New-Object System.Windows.Controls.Border; $kb.Height = 38; $kb.CornerRadius = New-Object System.Windows.CornerRadius(6); $kb.Background = Br '#0AFFFFFF'; $kb.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
  $kd = New-Object System.Windows.Controls.DockPanel; $kd.Margin = New-Object System.Windows.Thickness(12, 0, 8, 0); $kd.LastChildFill = $true
  $kbt = New-Object System.Windows.Controls.Border; $kbt.CornerRadius = New-Object System.Windows.CornerRadius(4); $kbt.Padding = New-Object System.Windows.Thickness(12, 3, 12, 4); $kbt.VerticalAlignment = 'Center'; $kbt.Background = Br '#E6B98E5F'
  $kbt.Child = (TB $(if (Api-Key) { '바꾸기' } else { '넣기' }) 11.5 (Br '#FF141414')); [System.Windows.Controls.DockPanel]::SetDock($kbt, 'Right'); [void]$kd.Children.Add($kbt)
  $ksp = New-Object System.Windows.Controls.StackPanel; $ksp.VerticalAlignment = 'Center'
  # (2026-11-13 대표) 제목 옆 '(선택사항)' · 아래 부연 설명 (Gemini 버전은 키가 꼭 있어야 해서 '(필수)')
  $ktr = New-Object System.Windows.Controls.StackPanel; $ktr.Orientation = 'Horizontal'
  [void]$ktr.Children.Add((TB '제미나이 API 키' 12.5 $CREAM))
  $kopt = TB $(if ($Tier -eq 'low') { '(필수)' } else { '(선택사항)' }) 10.5 $MUTED; $kopt.Margin = New-Object System.Windows.Thickness(6, 1, 0, 0); $kopt.VerticalAlignment = 'Center'; [void]$ktr.Children.Add($kopt)
  [void]$ksp.Children.Add($ktr)
  $kh = Key-Hint; $kdesc = $(if ($Tier -eq 'low') { '받기·보내기 번역에 써요' } else { '보내는 번역 품질이 더 완성도 있어요' })
  [void]$ksp.Children.Add((TB $(if ($kh) { '●●●●●●●● ' + $kh + ' · ' + $kdesc } else { $kdesc }) 9.5 $MUTED))
  [void]$kd.Children.Add($ksp); $kb.Child = $kd; Sx-Click $kb @{ kind = 'key' }
  [void]$popS.Children.Add($kb)
  # (2026-11-13 대표 A안) 대화창 칸: 글자 크기 · 배경 진하기 · 글 사라짐
  Sx-Head '대화창'
  Sx-Step '글자 크기' ([int]$S.fz) 'fzd'
  $cfl = TB '글꼴' 12.5 $CREAM; $cfl.Margin = New-Object System.Windows.Thickness(2, 12, 0, 6); [void]$popS.Children.Add($cfl)   # (2026-11-13 대표) 대화창 글꼴 고르기
  Sx-FontGrid
  $bgr = New-Object System.Windows.Controls.DockPanel; $bgr.LastChildFill = $false; $bgr.Margin = New-Object System.Windows.Thickness(2, 12, 2, 2)
  $bgl = TB '배경 진하기' 12.5 $CREAM; [System.Windows.Controls.DockPanel]::SetDock($bgl, 'Left'); [void]$bgr.Children.Add($bgl)
  $script:sxBgLab = TB ('{0}%' -f [int][math]::Round([double]$S.bg * 100)) 12 $GOLD; [System.Windows.Controls.DockPanel]::SetDock($script:sxBgLab, 'Right'); [void]$bgr.Children.Add($script:sxBgLab)
  [void]$popS.Children.Add($bgr)
  Sx-Slider ([double]$S.bg)
  $fdl = TB '글 사라짐' 12.5 $CREAM; $fdl.Margin = New-Object System.Windows.Thickness(2, 10, 0, 6); [void]$popS.Children.Add($fdl)
  Sx-Seg @(@(15, '15초'), @(30, '30초'), @(60, '1분'), @(120, '2분'), @(0, '안 사라짐')) ([int]$S.fade) 'fade'
  # (2026-11-13 대표 A안) 가운데 파티글 카드
  Sx-FeedCard {
  Sx-Sub '띄울 대화 (모든 탭 공통)' 2
  if ($null -eq $Feed.mask) {
    $nt = TB '게임이 켜지면 고를 수 있어요' 11 $MUTED; [void]$popS.Children.Add($nt)
  } else {
    $wp2 = New-Object System.Windows.Controls.WrapPanel
    foreach ($cc in @(@('p', '파티', '#FFAAAAFF'), @('r', '공격대', '#FFFF7F00'), @('i', '인던', '#FFAAD4FF'), @('g', '길드', '#FF40FF40'), @('w', '귓말', '#FFFF80FF'), @('s', '일반 · 외침', '#FFFFFFFF'))) {
      [void]$wp2.Children.Add((Sx-Chip $cc[1] $cc[2] (([string]$Feed.mask).Contains($cc[0])) @{ kind = 'cen'; k = $cc[0] }))
    }
    [void]$popS.Children.Add($wp2)
    # (2026-11-08 대표) 채널도 처음부터 하나씩 따로 (예전 '채널' 한 칸을 켜야 아래에 나오던 것 → 공개·거래·수비·파티찾기·개인 채널을 바로)
    Sx-Sub '채널 — 하나씩 따로'
    if (@($script:Chans.joined).Count -eq 0) {
      $nt2 = TB '게임에서 채널 목록을 받으면 나와요' 11 $MUTED; [void]$popS.Children.Add($nt2)
    } else {
      $wp2c = New-Object System.Windows.Controls.WrapPanel; $seenC = @{}
      $cOn = ([string]$Feed.mask).Contains('c')
      foreach ($j in @($script:Chans.joined)) {
        $base = Cen-ChBase $j.name; if (-not $base -or $seenC[$base]) { continue }; $seenC[$base] = $true
        $col = $(if (No-TrChan $base) { '#FF6FD3FF' } else { '#FFFFC0C0' })
        $ck = Ch-Key $j.name; $nm = $base; foreach ($fx in $CHFIX) { if ($fx.k -eq $ck) { $nm = $fx.n } }
        [void]$wp2c.Children.Add((Sx-Chip ('{0}. {1}' -f $j.n, $nm) $col ($cOn -and -not (Cen-ChOff $base)) @{ kind = 'cenx'; k = $base }))
      }
      [void]$popS.Children.Add($wp2c)
    }
  }
  # (공유판) 가운데 파티글 위치 · 크기 조절 모드
  $fb0 = New-Object System.Windows.Controls.Border; $fb0.Height = 38; $fb0.CornerRadius = New-Object System.Windows.CornerRadius(6); $fb0.Background = Br '#0AFFFFFF'; $fb0.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
  $fd0 = New-Object System.Windows.Controls.DockPanel; $fd0.Margin = New-Object System.Windows.Thickness(12, 0, 8, 0); $fd0.LastChildFill = $true
  $fbt = New-Object System.Windows.Controls.Border; $fbt.CornerRadius = New-Object System.Windows.CornerRadius(4); $fbt.Padding = New-Object System.Windows.Thickness(12, 3, 12, 4); $fbt.VerticalAlignment = 'Center'; $fbt.Background = Br '#E6B98E5F'
  $fbt.Child = (TB '조절하기' 11.5 (Br '#FF141414')); [System.Windows.Controls.DockPanel]::SetDock($fbt, 'Right'); [void]$fd0.Children.Add($fbt)
  $fsp = New-Object System.Windows.Controls.StackPanel; $fsp.VerticalAlignment = 'Center'
  [void]$fsp.Children.Add((TB '위치 · 크기 · 줄 수 · 글자 · 사라짐' 12.5 $CREAM)); [void]$fsp.Children.Add((TB $(if ($S.feedBox -is [hashtable]) { '직접 맞춘 자리 · ' + [string](Feed-Max) + '줄 · 글자 ' + [string][int](FeedFz) + ' · ' + [string](Feed-Sec) + '초' } else { '처음 자리 · ' + [string](Feed-Max) + '줄 · 글자 ' + [string][int](FeedFz) + ' · ' + [string](Feed-Sec) + '초' }) 9.5 $MUTED))
  [void]$fd0.Children.Add($fsp); $fb0.Child = $fd0; Sx-Click $fb0 @{ kind = 'fedit' }
  [void]$popS.Children.Add($fb0)
  }
  # (2026-11-13 대표) 채널 칸은 뺌 — 탭 오른쪽 클릭 메뉴의 '채널'과 중복 (개인판과 같게)
  # 아래줄: 자리·끄기·상태
  $ft = New-Object System.Windows.Controls.DockPanel; $ft.LastChildFill = $false; $ft.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
  $a0 = TB '사용법' 11.5 $GOLD; $a0.VerticalAlignment = 'Center'; $a0.Margin = New-Object System.Windows.Thickness(0, 0, 14, 0); Sx-Click $a0 @{ kind = 'help' }; [System.Windows.Controls.DockPanel]::SetDock($a0, 'Left'); [void]$ft.Children.Add($a0)   # (2026-11-12 대표) 대화창 안에서 바로 보는 사용법
  $a2 = TB '대화창 위치·크기 처음대로' 11.5 (Br '#FFE08A70'); $a2.VerticalAlignment = 'Center'; Sx-Click $a2 @{ kind = 'reset' }; [System.Windows.Controls.DockPanel]::SetDock($a2, 'Left'); [void]$ft.Children.Add($a2)
  $a3 = TB '번역창 끄기' 11.5 (Br '#FFE08A70'); $a3.VerticalAlignment = 'Center'; Sx-Click $a3 @{ kind = 'quit' }; [System.Windows.Controls.DockPanel]::SetDock($a3, 'Right'); [void]$ft.Children.Add($a3)
  [void]$popS.Children.Add($ft)
  $ew = @(); foreach ($b in @($script:BE)) { if ($b.kind -eq 'gemini' -and [string]$S.sendEng -ne 'gemini') { continue }; $w = $(if ($b.kind -eq 'gemini') { $(if (Api-Key) { '보내기용' } else { '키 없음' }) } elseif ($b.noModel) { '모델 없음' } elseif ($b.st -eq 'up') { '켜짐' } elseif ($b.st -eq 'down') { '준비 중' } else { '확인 중' }); $ew += ($b.short + ' ' + $w) }
  $sep = New-Object System.Windows.Controls.Border; $sep.Height = 1; $sep.Background = Br '#14FFFFFF'; $sep.Margin = New-Object System.Windows.Thickness(-14, 10, -14, 6); [void]$popS.Children.Add($sep)
  $i1 = TB ('번역 엔진 · ' + ($ew -join ' → ')) 9.5 $MUTED; $i1.TextWrapping = 'Wrap'; [void]$popS.Children.Add($i1)
  $i2 = TB ('받은 신호 {0} · 놓침 {1} · {2}' -f [FTR]::Packets, [FTR]::Drops, [FTR]::Status) 9.5 $MUTED; [void]$popS.Children.Add($i2)
  $i3 = TB '탭 오른쪽 클릭: 그 탭에 보일 대화 · Ctrl + 오른쪽 클릭: 창 위치 잠금·풀기 · 게임 쪽 설정은 1초 뒤 게임에 들어가요' 9.5 $MUTED; $i3.TextWrapping = 'Wrap'; [void]$popS.Children.Add($i3)
  # (공유판) 후원하기 — 설정 맨 아래
  # (2026-11-13 대표) 처음엔 '후원하기' 줄만 · 누르면 아래로 펼침 (설정 창을 닫으면 다시 접힘)
  Sx-Head '후원하기' '' $(if ($script:dnOpen) { '접기 ▴' } else { '펼치기 ▾' })
  Sx-Click $popS.Children[$popS.Children.Count - 1] @{ kind = 'donate' }
  if (-not $script:dnOpen) { return }
  $dn1 = TB '보내 주신 후원은 디스코드 음성 실시간 번역 등 앞으로의 업데이트에 큰 힘이 됩니다.' 12 $CREAM; $dn1.TextWrapping = 'Wrap'; [void]$popS.Children.Add($dn1)
  $dn2 = TB '카카오뱅크 3333-01-2216439 · 예금주 허수호' 12 $GOLD; $dn2.Margin = New-Object System.Windows.Thickness(0, 3, 0, 8); $dn2.TextWrapping = 'Wrap'; [void]$popS.Children.Add($dn2)
  $qrRow = New-Object System.Windows.Controls.StackPanel; $qrRow.Orientation = 'Horizontal'; $qrRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
  foreach ($qq in @(@('kakao_qr', '카카오페이로 송금됩니다.'), @('naver_qr', '네이버페이로 송금됩니다.'))) {
    $qsp = New-Object System.Windows.Controls.StackPanel; $qsp.Width = 132; $qsp.Margin = New-Object System.Windows.Thickness(0, 0, 14, 0)
    $qb = New-Object System.Windows.Controls.Border; $qb.Width = 104; $qb.Height = 104; $qb.Background = Br '#FFFFFFFF'; $qb.CornerRadius = New-Object System.Windows.CornerRadius(4); $qb.Padding = New-Object System.Windows.Thickness(4); $qb.HorizontalAlignment = 'Center'
    $qbmp = Img $qq[0]
    if ($qbmp) { $qim = New-Object System.Windows.Controls.Image; $qim.Source = $qbmp; $qim.Stretch = 'Uniform'; [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($qim, 'HighQuality'); $qb.Child = $qim }
    else { $qx = TB 'QR' 12 (Br '#FF8A8A8A'); $qx.HorizontalAlignment = 'Center'; $qx.VerticalAlignment = 'Center'; $qb.Child = $qx }
    [void]$qsp.Children.Add($qb)
    $qc = TB $qq[1] 9.5 $SUBC; $qc.TextWrapping = 'Wrap'; $qc.TextAlignment = 'Center'; $qc.HorizontalAlignment = 'Center'; $qc.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)
    [void]$qsp.Children.Add($qc); [void]$qrRow.Children.Add($qsp)
  }
  [void]$popS.Children.Add($qrRow)
}
function Build-SetMenu { Build-Menu }
$Pop.Add_Closed({ $script:dnOpen = $false; try { $Pop.Placement = 'Top' } catch {}; try { $Pop.StaysOpen = $false } catch {}; try { if ($script:tabNameBox) { Tab-NameEnd $script:tabNameBox $true; $script:tabNameBox = $null } } catch {} })   # (2026-11-04) 톱니 설정만 아래로 펼침 · 닫히면 원래대로(위로)
function Show-Menu($anchor) {
  if (Pop-Again ('tr' + $anchor.GetHashCode())) { return }
  $script:popMode = 'tr'; Build-Menu; $Pop.PlacementTarget = $anchor
  try { $popSv.MaxHeight = [System.Windows.SystemParameters]::WorkArea.Height * 0.9 / [math]::Max(0.5, $Scale.ScaleY); $popSv.ScrollToTop() } catch {}
  $Pop.Placement = $(if ($anchor -eq $TrM.root) { 'Bottom' } else { 'Top' })
  $Pop.IsOpen = $true
}


# ---------- (2026-10-26) 탭마다 보일 대화 고르기 (게임 안 대화창과 같은 방식 · 탭 메달 오른쪽 클릭) ----------
$TABCATS = @(
  @{ k = 'party'; n = '파티' }, @{ k = 'raid'; n = '공격대' }, @{ k = 'inst'; n = '인던 대화' }, @{ k = 'whisper'; n = '귓말' },
  @{ k = 'guild'; n = '길드 · 관리자' }, @{ k = 'say'; n = '일반 대화 · 외침' }, @{ k = 'lfg'; n = '파티찾기 채널' },
  @{ k = 'general'; n = '공개 · 일반 채널' }, @{ k = 'trade'; n = '거래 채널' }, @{ k = 'otherch'; n = '그 밖의 채널' },
  @{ k = 'sys'; n = '시스템 · 그 밖 알림' },
  @{ k = 'loot'; n = '전리품 · 돈' }, @{ k = 'xp'; n = '경험치 · 숙련도' }, @{ k = 'npc'; n = 'NPC 대사' }   # 게임 대화창과 같은 칸 (게임 대화창에만 나오는 글)
)
$TABDEF = @{
  all = @{ party = $true; raid = $true; inst = $true; whisper = $true; guild = $true; say = $true; lfg = $true; general = $true; trade = $true; otherch = $true; sys = $true; loot = $true; xp = $true; npc = $true }
  party = @{ party = $true; raid = $true; inst = $true }
  guild = @{ guild = $true }
  whisper = @{ whisper = $true }
}
$TABLABEL = @{ all = '전체'; party = '파티'; guild = '길드'; whisper = '귓말' }
# (2026-11-08 대표) 공개 채널 나누기: 채널마다 따로 고르는 키 (예전 '공개 채널' 한 칸 = 공개·수비·세계수비)
$CHFIX = @(
  @{ k = 'ch:general'; n = '공개'; rx = '(?i)^(general|공개)' },
  @{ k = 'ch:trade'; n = '거래'; rx = '(?i)^(trade|거래)' },
  @{ k = 'ch:localdefense'; n = '수비'; rx = '(?i)^(localdefense|수비|지역 ?방어)' },
  @{ k = 'ch:lookingforgroup'; n = '파티찾기'; rx = '(?i)^(lookingforgroup|lfg|파티 ?찾기)' },
  @{ k = 'ch:worlddefense'; n = '세계수비'; rx = '(?i)^(worlddefense|세계 ?방어|세계 ?수비)' }
)
$CHOLD = @{ 'ch:general' = 'general'; 'ch:trade' = 'trade'; 'ch:localdefense' = 'general'; 'ch:lookingforgroup' = 'lfg'; 'ch:worlddefense' = 'general' }
function Ch-Key($cname) {
  $b = Cen-ChBase $cname; if (-not $b) { return '' }
  foreach ($c in $CHFIX) { if ($b -match $c.rx) { return $c.k } }
  return ('ch:' + $b.ToLower())
}
# 이 탭에서 이 키를 볼지 (아직 안 고른 채널은 예전 칸 값을 따름 · 처음 보는 개인 채널 = 예전 '그 밖 채널')
function Tab-On($f, [string]$key) {
  if ($f.ContainsKey($key)) { return [bool]$f[$key] }
  if ($key.StartsWith('ch:')) { $o = $CHOLD[$key]; if (-not $o) { $o = 'otherch' }; return [bool]$f[$o] }
  if ($script:popTab -and ($key -eq 'loot' -or $key -eq 'xp' -or $key -eq 'npc')) { $d = $TABDEF[[string]$script:popTab]; if (-not $d) { $d = $(if ([string]$script:popTab -match '^c\d+$') { @{} } else { $TABDEF['all'] }) }; return [bool]$d[$key] }
  return $false
}
function Tab-Filt($tab) {
  if (-not ($S.tabf -is [hashtable])) { $S.tabf = @{} }
  if (-not ($S.tabf[$tab] -is [hashtable])) {
    $d = $TABDEF[$tab]; if (-not $d) { $d = $(if ([string]$tab -match '^c\d+$') { @{} } else { $TABDEF['all'] }) }   # (2026-11-08) + 로 만든 탭은 처음엔 아무것도 안 보임 → 고르기
    $h = @{}; foreach ($c in $TABCATS) { $h[$c.k] = [bool]$d[$c.k] }
    $S.tabf[$tab] = $h
  }
  return $S.tabf[$tab]
}
function Pop-Title($text) {
  $t = TB $text 12 (Br '#FFE3C39A'); $t.HorizontalAlignment = 'Center'; $t.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
  [void]$popS.Children.Add($t)
}
function Pop-Sep {
  $sep = New-Object System.Windows.Controls.Border; $sep.Height = 1; $sep.Background = Br '#1FFFFFFF'; $sep.Margin = New-Object System.Windows.Thickness(0, 6, 0, 4)
  [void]$popS.Children.Add($sep)
}
# (2026-11-03) 새 디자인 A안: 탭 오른쪽 클릭 = '이 탭에 보일 대화'만 깔끔하게 (3칸 체크 + 채널 색 점)
$TABCOL = @{ party = '#FFAAAAFF'; raid = '#FFFF7F00'; inst = '#FFAAD4FF'; whisper = '#FFFF80FF'; guild = '#FF40FF40'; say = '#FFFFFFFF'; lfg = '#FFFFC0C0'; general = '#FFFFC0C0'; trade = '#FFFFC0C0'; otherch = '#FFFFC0C0'; sys = '#FFFFFF00'; loot = '#FF00AA00'; xp = '#FF6E6EFF'; npc = '#FFFFFF9E' }
$TABSHORT = @{ party = '파티'; raid = '공격대'; inst = '인던'; whisper = '귓말'; guild = '길드'; say = '일반 · 외침'; lfg = '파티찾기'; general = '공개 채널'; trade = '거래'; otherch = '그 밖 채널'; sys = '시스템'; loot = '전리품 · 돈'; xp = '경험치 · 숙련도'; npc = 'NPC 대사' }
function Tab-Row($key, $label, $col, $tip) {
  $f = Tab-Filt $script:popTab
  $on = Tab-On $f $key
  $row = New-Object System.Windows.Controls.DockPanel; $row.Width = 132; $row.Height = 28; $row.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0); $row.Background = Br '#01000000'; $row.Cursor = [System.Windows.Input.Cursors]::Hand; $row.LastChildFill = $true
  $box = New-Object System.Windows.Controls.Border; $box.Width = 16; $box.Height = 16; $box.CornerRadius = New-Object System.Windows.CornerRadius(3); $box.BorderThickness = New-Object System.Windows.Thickness(1)
  $box.Background = $(if ($on) { Br '#FFB98E5F' } else { Br '#59000000' }); $box.BorderBrush = $(if ($on) { Br '#FFB98E5F' } else { Br '#47FFFFFF' })
  if ($on) { $ck = New-Object System.Windows.Controls.TextBlock; $ck.Text = [string][char]0x2714; $ck.FontFamily = 'Segoe UI Symbol'; $ck.FontSize = 10; $ck.Foreground = Br '#FF141414'; $ck.HorizontalAlignment = 'Center'; $ck.VerticalAlignment = 'Center'; $box.Child = $ck }
  [System.Windows.Controls.DockPanel]::SetDock($box, 'Left'); [void]$row.Children.Add($box)
  $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 8; $dot.Height = 8; $dot.Fill = Br $col; $dot.VerticalAlignment = 'Center'; $dot.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
  [System.Windows.Controls.DockPanel]::SetDock($dot, 'Right'); [void]$row.Children.Add($dot)
  $l = TB $label 12 $(if ($on) { $CREAM } else { $MUTED }); $l.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0); $l.VerticalAlignment = 'Center'; $l.TextTrimming = 'CharacterEllipsis'
  [void]$row.Children.Add($l)
  $row.Tag = @{ k = $key; n = $label }; if ($tip) { $row.ToolTip = $tip }
  $row.Add_MouseLeftButtonUp({ param($snd, $e)
    try {
      $tk = $script:popTab; $ff = Tab-Filt $tk; $kk = [string]$snd.Tag.k
      $ff[$kk] = -not (Tab-On $ff $kk)
      Save-Cfg; Tabs-Changed; Apply-AllTabs
      # (2026-11-08) 이름을 직접 안 정한 탭은 첫 번째로 고른 대화 이름을 탭 이름으로
      foreach ($c in (CTabs)) { if ($c.key -eq $tk -and $c.auto) { $nm = ''; foreach ($q in $script:tabRowOrder) { if (Tab-On $ff $q.k) { $nm = $q.n; break } }; Set-CTabLabel $tk $nm $true } }
      Build-TabMenu
    } catch { Log "탭 고르기: $_" }
    $e.Handled = $true })
  [void]$script:tabRowOrder.Add(@{ k = $key; n = $label })
  return $row
}
function Tab-Grp([string]$text) {
  $g = TB $text 10.5 $MUTED; $g.Margin = New-Object System.Windows.Thickness(0, 6, 0, 3); [void]$popS.Children.Add($g)
}
function Tab-NameEnd($tbx, [bool]$back) {
  if (-not $tbx -or $tbx.Tag.done) { return }
  $tbx.Tag.done = $true
  try { Set-CTabLabel ([string]$tbx.Tag.k) ([string]$tbx.Text) $false } catch {}
  try { [FTR]::NoActivate($script:hwnd, $true) } catch {}
  try { $Pop.StaysOpen = $false } catch {}
  if ($back -and -not $state.inputOn) { try { $w = [FTR]::FindWow(); if ($w -ne [IntPtr]::Zero) { [FTR]::Focus($w) } } catch {} }
}
function Build-TabMenu {
  $popS.Children.Clear()
  $k = $script:popTab
  $script:tabRowOrder = New-Object System.Collections.ArrayList
  $isC = ([string]$k -match '^c\d+$')
  $hd = New-Object System.Windows.Controls.StackPanel; $hd.Orientation = 'Horizontal'; $hd.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
  $ht = TB '이 탭에 보일 대화' 12.5 $CREAM; $ht.VerticalAlignment = 'Center'; [void]$hd.Children.Add($ht)
  if ($isC) {
    # (2026-11-08) 만든 탭 = 이름 칸 (4글자 · Enter 또는 창 닫으면 저장)
    $nb = New-Object System.Windows.Controls.Border; $nb.CornerRadius = New-Object System.Windows.CornerRadius(6); $nb.BorderThickness = New-Object System.Windows.Thickness(1); $nb.BorderBrush = Br '#FFB98E5F'; $nb.Background = Br '#FF0C0C0D'; $nb.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0); $nb.Padding = New-Object System.Windows.Thickness(6, 1, 6, 1); $nb.VerticalAlignment = 'Center'
    $nsp = New-Object System.Windows.Controls.StackPanel; $nsp.Orientation = 'Horizontal'
    $tbx = New-Object System.Windows.Controls.TextBox; $tbx.Width = 64; $tbx.MaxLength = 4; $tbx.Background = $null; $tbx.BorderThickness = New-Object System.Windows.Thickness(0); $tbx.Foreground = Br '#FFFFE7B0'; $tbx.CaretBrush = Br '#FFFFE7B0'; $tbx.FontSize = 12; $tbx.VerticalAlignment = 'Center'
    $tbx.Text = (Tab-Label $k); $tbx.Tag = @{ k = $k; done = $false }
    $tbx.Add_PreviewMouseLeftButtonDown({ param($snd, $e)
      # (2026-11-11 공유판 제보: 이름 칸을 누르면 창이 바로 닫힘) 번역창을 활성화하는 순간 바깥 클릭으로 보고 메뉴가 닫히던 것 → 이름 쓰는 동안은 안 닫히게
      try { $Pop.StaysOpen = $true } catch {}
      try { [FTR]::NoActivate($script:hwnd, $false); [FTR]::Focus($script:hwnd); $win.Activate() | Out-Null } catch {}
      $snd.Tag.done = $false
      if (-not $snd.IsKeyboardFocusWithin) { $snd.Focus() | Out-Null; $snd.SelectAll(); $e.Handled = $true } })
    $tbx.Add_KeyDown({ param($snd, $e) if ($e.Key -eq 'Return' -or $e.Key -eq 'Escape') { Tab-NameEnd $snd $true; $e.Handled = $true } })
    $tbx.Add_LostKeyboardFocus({ param($snd, $e) Tab-NameEnd $snd $false })
    $script:tabNameBox = $tbx
    [void]$nsp.Children.Add($tbx)
    $pen = TB ([string][char]0x270E + ' 이름') 10 $MUTED; $pen.VerticalAlignment = 'Center'; $pen.IsHitTestVisible = $false; $pen.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0); [void]$nsp.Children.Add($pen)
    $nb.Child = $nsp; [void]$hd.Children.Add($nb)
  } else {
    $script:tabNameBox = $null
    $hc = New-Object System.Windows.Controls.Border; $hc.CornerRadius = New-Object System.Windows.CornerRadius(8); $hc.Background = Br '#2EB98E5F'; $hc.Padding = New-Object System.Windows.Thickness(7, 1, 7, 1); $hc.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0); $hc.VerticalAlignment = 'Center'
    $hc.Child = (TB ((Tab-Label $k) + ' 탭만') 10.5 (Br '#FFE3C39A')); [void]$hd.Children.Add($hc)
  }
  [void]$popS.Children.Add($hd)
  # 나와 하는 대화
  Tab-Grp '나와 하는 대화'
  $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 3
  foreach ($q in @('party', 'raid', 'inst', 'whisper', 'guild', 'say')) {
    $c = $TABCATS | Where-Object { $_.k -eq $q } | Select-Object -First 1
    [void]$ug.Children.Add((Tab-Row $q $TABSHORT[$q] $TABCOL[$q] $c.n))
  }
  [void]$popS.Children.Add($ug)
  # 채널 — 하나씩 따로 (기본 5개 + 들어가 있는 개인 채널 + 대화창에 들어온 채널)
  Tab-Grp '채널 — 하나씩 따로'
  $ug2 = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug2.Columns = 3
  $seen = @{}
  foreach ($c in $CHFIX) { $seen[$c.k] = $true; [void]$ug2.Children.Add((Tab-Row $c.k $c.n '#FFFFC0C0' $null)) }
  foreach ($j in @($script:Chans.joined)) {
    $ck = Ch-Key $j.name; if (-not $ck -or $seen[$ck]) { continue }; $seen[$ck] = $true
    $nm = ('{0}. {1}' -f $j.n, (Cen-ChBase $j.name))
    $col = $(if (No-TrChan $j.name) { '#FF6FD3FF' } else { '#FFFFC0C0' })
    [void]$ug2.Children.Add((Tab-Row $ck $nm $col ([string]$j.name)))
  }
  foreach ($LL in $LineList) {
    $ck = [string]$LL.chk; if (-not $ck -or $seen[$ck]) { continue }; $seen[$ck] = $true
    $nm = Cen-ChBase $LL.rec.cname
    [void]$ug2.Children.Add((Tab-Row $ck $nm '#FFFFC0C0' ([string]$LL.rec.cname)))
  }
  [void]$popS.Children.Add($ug2)
  # 그 밖
  Tab-Grp '그 밖'
  $ug3 = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug3.Columns = 3
  [void]$ug3.Children.Add((Tab-Row 'sys' $TABSHORT['sys'] $TABCOL['sys'] '시스템 · 그 밖 알림'))
  foreach ($q in @('loot', 'xp', 'npc')) { [void]$ug3.Children.Add((Tab-Row $q $TABSHORT[$q] $TABCOL[$q] '게임 대화창에 나오는 글 (게임 대화창과 설정을 같이 씀)')) }
  [void]$popS.Children.Add($ug3)
  $ft = New-Object System.Windows.Controls.DockPanel; $ft.LastChildFill = $false; $ft.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
  if ($isC) {
    $dl = TB '이 탭 지우기' 10.5 (Br '#FFE08A7A'); $dl.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.DockPanel]::SetDock($dl, 'Left'); [void]$ft.Children.Add($dl)
    $dl.Add_MouseLeftButtonUp({ param($snd, $e) try { Del-CTab $script:popTab } catch { Log "탭 지우기: $_" }; $e.Handled = $true })
  }
  $rs = TB '처음대로' 10.5 $MUTED; $rs.Cursor = [System.Windows.Input.Cursors]::Hand
  [System.Windows.Controls.DockPanel]::SetDock($rs, 'Right'); [void]$ft.Children.Add($rs)
  $rs.Add_MouseLeftButtonUp({ param($snd, $e) [void]$S.tabf.Remove($script:popTab); Save-Cfg; Tabs-Changed; Apply-AllTabs; Build-TabMenu; $e.Handled = $true })
  [void]$popS.Children.Add($ft)
}
function Show-TabMenu($anchor, $key) {
  if (Pop-Again ('tab' + $key)) { return }
  $script:popMode = 'tab'; $script:popTab = $key
  Build-TabMenu; $Pop.PlacementTarget = $anchor; $Pop.IsOpen = $true
}
function Apply-AllTabs { foreach ($L in $LineList) { Apply-TabTo $L }; $Sv.ScrollToEnd() }

# ---------- (2026-10-26) 보낼 언어 고르기 ('한 → 영' 클릭 · 보낼 곳마다 따로 기억) ----------
$LANGORDER = @('EN', 'JA', 'ZH', 'DE', 'FR', 'RU', 'ES', 'PT', 'IT', 'PL', 'TR', 'NL', 'SV')
function Out-Key($tg) {
  if (-not $tg) { return 'party' }
  $k = TrCat $tg.t $tg.cname
  if ($k -eq 'other') { $k = 'say' }
  return $k
}
function Out-Pick($k) {
  if (-not ($S.outLang -is [hashtable])) { $S.outLang = @{} }
  $v = [string]$S.outLang[$k]
  if (-not $v) { $v = $(if ($k -eq 'whisper') { 'AUTO' } else { 'EN' }) }   # 처음: 귓말은 상대 언어 따라가기 · 나머지는 영어
  return $v
}
function Radio-Row($text, $on, $tag, [double]$w) {
  $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object System.Windows.Thickness(0, 3, 0, 3); $row.Background = Br '#01000000'; $row.Cursor = [System.Windows.Input.Cursors]::Hand
  if ($w -gt 0) { $row.Width = $w }
  $rb = New-Object System.Windows.Controls.Border; $rb.Width = 14; $rb.Height = 14; $rb.CornerRadius = New-Object System.Windows.CornerRadius(7); $rb.Background = Br '#E6050505'; $rb.BorderBrush = Br '#FFB98E5F'; $rb.BorderThickness = New-Object System.Windows.Thickness(1)
  if ($on) { $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 6; $dot.Height = 6; $dot.Fill = Br '#FFFFE2A0'; $dot.HorizontalAlignment = 'Center'; $dot.VerticalAlignment = 'Center'; $rb.Child = $dot }
  [void]$row.Children.Add($rb)
  $l = TB $text 12 $(if ($on) { $CREAM } else { $MUTED }); $l.Margin = New-Object System.Windows.Thickness(7, 0, 0, 0); $l.VerticalAlignment = 'Center'
  [void]$row.Children.Add($l)
  $row.Tag = $tag
  $row.Add_MouseLeftButtonUp({ param($snd, $e) Pick-Lang ([string]$snd.Tag); $e.Handled = $true })
  return $row
}
function Build-LangMenu {
  $popS.Children.Clear()
  $k = $script:popOut
  $nm = ($TABCATS | Where-Object { $_.k -eq $k } | Select-Object -First 1).n
  if (-not $nm) { $nm = '일반 대화' }
  Pop-Title ('보낼 언어 · ' + $nm)
  $cur = Out-Pick $k
  $ar = Radio-Row '자동' ($cur -eq 'AUTO') 'AUTO' 0
  $an = TB '마지막에 말한 외국인 언어로' 10 $MUTED; $an.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0); $an.VerticalAlignment = 'Center'
  [void]$ar.Children.Add($an)
  [void]$popS.Children.Add($ar)
  Pop-Sep
  $wp = New-Object System.Windows.Controls.WrapPanel; $wp.Width = 220
  foreach ($c in $LANGORDER) { [void]$wp.Children.Add((Radio-Row $LANGNAME[$c] ($cur -eq $c) $c 110)) }
  [void]$popS.Children.Add($wp)
  $nt = TB '보낼 곳(파티·길드·귓말…)마다 따로 기억' 9.5 $MUTED; $nt.HorizontalAlignment = 'Center'; $nt.Margin = New-Object System.Windows.Thickness(0, 7, 0, 0)
  [void]$popS.Children.Add($nt)
}
function Show-LangMenu($anchor) {
  if (-not $state.target) { Enter-Input; return }
  if (Pop-Again 'lang') { return }
  $script:langIn = $state.inputOn
  $script:popMode = 'lang'; $script:popOut = Out-Key $state.target
  Build-LangMenu; $Pop.PlacementTarget = $anchor; $Pop.IsOpen = $true
}
function Pick-Lang($code) {
  if (-not ($S.outLang -is [hashtable])) { $S.outLang = @{} }
  $k = $script:popOut
  $S.outLang[$k] = $code
  $S.tr[$k] = $true    # 언어를 골랐으면 그 곳은 번역 켜기
  Save-Cfg
  $Pop.IsOpen = $false
  Paint-Target; Kick-Preview
  if ($script:langIn -and -not $state.inputOn) { Enter-Input }
}

# ---------- 채팅 줄 ----------
$state = @{ me = ''; realm = ''; myHex = 'ff7d0a'; test = $false; geo = $null; hover = $false; inputOn = $false; chromeA = 1.0; idle = 0.0; prevFg = [IntPtr]::Zero; hk = $false; target = $null; lastTarget = $null; lastForeign = $null; lastForeignAt = [DateTime]::MinValue; prevText = ''; prevOut = ''; prevLang = ''; prevAt = [DateTime]::MinValue; sending = $false; editing = $false; vis = $true; off = $false }
$Sent = @{}       # 내가 보낸 번역문 → 내가 쓴 한국어
$LangOf = @{}     # 사람 → 그 사람이 쓰는 언어
$BnId = @{}      # (2026-10-30) 배틀넷 친구 이름 → 배틀넷 번호 (배틀넷 귓말 답장용)
function Tell-Tg($name) { $n = [string]$name; if ($BnId[$n]) { return @{ t = 'BN_WHISPER'; name = $n; bn = $BnId[$n] } }; return @{ t = 'WHISPER'; name = $n } }
$LangCat = @{}    # 번역 분류 → 마지막 외국어
$Cache = @{}      # 원문 → 번역
$Pending = New-Object System.Collections.ArrayList
$Http = New-Object System.Net.Http.HttpClient
$Http.Timeout = [TimeSpan]::FromSeconds(30)
$CHT = @{ SAY = @('일', 'say', '/s '); YELL = @('외', 'yell', '/y '); EMOTE = @('감', 'emote', '/e '); PARTY = @('파', 'party', '/p '); PARTY_LEADER = @('파', 'party', '/p ')
  RAID = @('공', 'raid', '/ra '); RAID_LEADER = @('공', 'raid', '/ra '); RAID_WARNING = @('경', 'rw', '/rw '); INSTANCE_CHAT = @('인', 'raid', '/i '); INSTANCE_CHAT_LEADER = @('인', 'raid', '/i ')
  GUILD = @('길', 'guild', '/g '); OFFICER = @('관', 'officer', '/o '); WHISPER = @('귓', 'whisper', '/w '); WHISPER_INFORM = @('귓', 'whisper', '/w '); BN_WHISPER = @('귓', 'bn', ''); BN_WHISPER_INFORM = @('귓', 'bn', ''); CHANNEL = @('채', 'channel', '/') }
$PREFIX = @{ PARTY = '[파티] '; PARTY_LEADER = '[파티장] '; RAID = '[공격대] '; RAID_LEADER = '[공격대장] '; RAID_WARNING = '[공격대 경보] '; INSTANCE_CHAT = '[인스턴스] '; INSTANCE_CHAT_LEADER = '[인스턴스 지휘관] '; GUILD = '[길드] '; OFFICER = '[관리자] ' }
$LANGNAME = @{ EN = '영어'; DE = '독일어'; FR = '프랑스어'; RU = '러시아어'; ES = '스페인어'; PT = '포르투갈어'; IT = '이탈리아어'; PL = '폴란드어'; JA = '일본어'; ZH = '중국어'; TR = '터키어'; NL = '네덜란드어'; SV = '스웨덴어' }
$LANGSHORT = @{ EN = '영'; DE = '독'; FR = '불'; RU = '러'; ES = '스'; PT = '포'; IT = '이'; PL = '폴'; JA = '일'; ZH = '중'; TR = '터'; NL = '네'; SV = '스웨' }

# (2026-10-31) /1 같은 채널 번호의 이름: 받은 채널 글에서 기억한 것 → 저장해 둔 것 → 보통 번호 (1 공개 · 2 거래 · 3 수비 · 4 파티찾기)
#  예전엔 번역창을 다시 켠 뒤 그 채널 글을 아직 못 받았으면 이름이 '채널'이 돼서 번역이 꺼진 채로 나갔음
function Chan-Name([string]$n) {
  if ($ChanNames[$n]) { return $ChanNames[$n] }
  try { if ($S.chanNames -and $S.chanNames[$n]) { return [string]$S.chanNames[$n] } } catch {}
  switch ($n) { '1' { return 'General' } '2' { return 'Trade' } '3' { return 'LocalDefense' } '4' { return 'LookingForGroup' } }
  return '채널'
}
function TrCat($t, $cname) {
  switch -Regex ($t) {
    '^(SAY|YELL|EMOTE)$' { return 'say' }
    '^PARTY' { return 'party' }
    '^RAID' { return 'raid' }
    '^INSTANCE' { return 'inst' }
    '^(GUILD|OFFICER)$' { return 'guild' }
    'WHISPER' { return 'whisper' }
    '^CHANNEL$' {
      if ($cname -match '(?i)lookingforgroup|파티찾기|파티 찾기|lfg|구인') { return 'lfg' }
      if ($cname -match '(?i)trade|거래') { return 'trade' }
      if ($cname -match '(?i)general|공개|일반|localdefense|worlddefense|수비') { return 'general' }
      return 'otherch'
    }
  }
  return 'other'
}
function TabOf($t) {
  if ($t -match '^(PARTY|RAID|INSTANCE)') { return 'party' }
  if ($t -match '^(GUILD|OFFICER)$') { return 'guild' }
  if ($t -match 'WHISPER') { return 'whisper' }
  return 'all'
}
function Short($n) { if (-not $n) { return '' }; $p = $n.Split('-'); if ($p.Count -gt 1 -and $state.realm -and ($p[1] -eq $state.realm -or $p[1] -eq ($state.realm -replace '\s', ''))) { return $p[0] }; return $n }
# 와우 글자 꾸밈(|c색 |r |H링크|h[이름]|h |T그림|t)을 색 조각으로
function Parse-Wow([string]$s, [string]$base) {
  $out = New-Object System.Collections.ArrayList
  $cur = $base; $stack = New-Object System.Collections.Stack
  $lnk = $null   # (2026-10-27) 지금 글자가 속한 링크 (item:12345:... 등) · 클릭하면 게임에서 그 창을 열기 위해
  $re = [regex]'\|c([0-9a-fA-F]{8})|\|r|\|H[^|]*\|h|\|h|\|T[^|]*\|t|\|A[^|]*\|a|\|n|\{rt\d\}|\{[a-z]+\d?\}'
  $pos = 0
  foreach ($m in $re.Matches($s)) {
    if ($m.Index -gt $pos) { [void]$out.Add(@($s.Substring($pos, $m.Index - $pos), $cur, $lnk)) }
    $v = $m.Value
    if ($v.StartsWith('|c')) { $stack.Push($cur); $cur = $m.Groups[1].Value.Substring(2) }
    elseif ($v -eq '|r') { if ($stack.Count) { $cur = $stack.Pop() } else { $cur = $base } }
    elseif ($v.StartsWith('|H') -and $v.Length -gt 4) { $lnk = $v.Substring(2, $v.Length - 4) }
    elseif ($v -eq '|h') { $lnk = $null }
    $pos = $m.Index + $m.Length
  }
  if ($pos -lt $s.Length) { [void]$out.Add(@($s.Substring($pos), $cur, $lnk)) }
  return ,$out
}
function Plain([string]$s) { return (((Parse-Wow $s 'ffffff') | ForEach-Object { $_[0] }) -join '') }
function Add-Run($tb, $text, $hex, $tag) {
  $r = New-Object System.Windows.Documents.Run($text)
  $r.Foreground = HexBr $hex
  if ($tag) { $r.Tag = $tag; $r.Cursor = [System.Windows.Input.Cursors]::Hand }
  [void]$tb.Inlines.Add($r)
  return $r
}
$LineList = New-Object System.Collections.ArrayList
$SeenC = New-Object 'System.Collections.Generic.HashSet[string]'   # (2026-10-27) 이미 받은 대화 번호 (게임이 다시 보내도 두 번 안 뜨게)
# 채팅 줄: 라이브 채팅 오버레이와 같은 방식 (확대 없이 실제 크기로 · 은은한 검은 번짐 테두리)
$script:K = 1.2187       # 게임 UI 1칸 = 몇 픽셀
$script:Dpi = 1.0
$FSZ = 1.05              # 글자 크기 보정 (게임 글자와 같은 폭)
function U([double]$v) { return $v * $script:K / $script:Dpi }   # 게임 UI 칸 → 화면 크기
function New-Halo { $e = New-Object System.Windows.Media.Effects.DropShadowEffect; $e.Color = [System.Windows.Media.Colors]::Black; $e.ShadowDepth = 0; $e.BlurRadius = 5; $e.Opacity = 1; return $e }
$Lines.Effect = $null   # (2026-10-30) 번역 대화창도 번짐 테두리 빼고 글씨만
function Line-TB([double]$size) {
  $t = New-Object System.Windows.Controls.TextBlock
  $t.FontFamily = $script:CFONT; $t.FontWeight = 'Bold'; $t.FontSize = (U ($size * $FSZ * ([double]$S.fz / 12.0))); $t.TextWrapping = 'Wrap'
  $t.LineStackingStrategy = 'BlockLineHeight'
  return $t
}
function Add-Line($rec, $before = $null) {
  $box = New-Object System.Windows.Controls.StackPanel
  $L = @{ box = $box; main = $null; sub = $null; body = $null; subTag = $null; subText = $null; at = [DateTime]::Now; tab = 'all'; rec = $rec }
  $box.Tag = $L
  # (2026-10-30) 대화창이 숨겨진 상태면 새 줄도 처음부터 투명하게 (예전엔 다음 계산 때까지 0.2초쯤 보여서 줄이 올라올 때마다 깜빡였음)
  if (-not ($state.vis -or $state.hover -or $state.inUse -or $Pop.IsOpen)) { $box.Opacity = 0 }
  if ($rec.kind -ne 'S') { $L.tab = TabOf $rec.t }
  $L.cat = 'sys'
  if ($rec.kind -ne 'S') { $L.cat = TrCat $rec.t $rec.cname; if ($L.cat -eq 'other') { $L.cat = 'sys' } }
  $L.chk = $(if ($rec.kind -ne 'S' -and [string]$rec.t -eq 'CHANNEL') { Ch-Key $rec.cname } else { '' })   # (2026-11-08) 채널마다 따로
  Build-Line $L
  # (2026-10-27) 늦게 받은 대화(다시 보내기)는 원래 순서 자리에 끼움
  $ci = -1; $li = -1
  if ($before) { $ci = $Lines.Children.IndexOf($before.box); $li = $LineList.IndexOf($before) }
  if ($ci -ge 0 -and $li -ge 0) { [void]$Lines.Children.Insert($ci, $box); [void]$LineList.Insert($li, $L) }
  else { [void]$Lines.Children.Add($box); [void]$LineList.Add($L) }
  while ($LineList.Count -gt 300) { $Lines.Children.Remove($LineList[0].box); $LineList.RemoveAt(0) }
  Apply-TabTo $L
  if ($Sv.VerticalOffset -ge $Sv.ScrollableHeight - 4) { $Sv.ScrollToEnd() }
  return $L
}
function Build-Line($L) {
  $L.box.Children.Clear()
  $bg0 = $null; if ($L.rec.kind -ne 'S') { try { $bg0 = Chan-Badge $L.rec } catch {} }
  $L.hasB = [bool]$bg0
  $L.box.Background = $(if ($L.rec.call) { Br '#1FFF9A40' } elseif ([string]$L.rec.t -eq 'CHANNEL' -and (No-TrChan $L.rec.cname)) { Br '#1A4FB8FF' } else { $null })   # (2026-11-05) krus 줄은 옅은 하늘색 바탕   # (2026-11-03 A안) 이름 불린 줄은 옅은 주황 바탕
  $dp = New-Object System.Windows.Controls.DockPanel; $dp.LastChildFill = $true
  if ($bg0) { [System.Windows.Controls.DockPanel]::SetDock($bg0, 'Left'); [void]$dp.Children.Add($bg0) }
  $L.col = New-Object System.Windows.Controls.StackPanel; [void]$dp.Children.Add($L.col)
  [void]$L.box.Children.Add($dp)
  $kz0 = [double]$FSZ * ([double]$S.fz / 12.0)
  $main = Line-TB 12; $main.LineHeight = (U (16.5 * $kz0))   # (2026-11-03) 줄 간격 좁힘 (21 → 글자 크기 x1.4)
  $L.box.Margin = New-Object System.Windows.Thickness(0, 0, 0, (U (4 * $kz0)))
  $L.main = $main
  [void]$L.col.Children.Add($main)
  Fill-Main $L
  $L.sub = $null
  if ($L.subText) { Build-Sub $L }
}
# 채팅 한 줄 (번역문이 있으면 번역문을 위에)
# (2026-10-31) 내 이름(또는 앞부분 4글자 이상 · 대소문자 상관없이)을 부른 글인지 · 한글 이름은 이름 전체나 앞 두 글자
function Name-Call([string]$msg) {
  $me = [string]$state.me; if (-not $me -or -not $msg) { return '' }
  $m = $msg -replace '\|H[^|]*\|h', '' -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|[rh]', ''
  if ($me -match '^[A-Za-z]+$') {
    $low = $me.ToLower()
    foreach ($mm in [regex]::Matches($m, '[A-Za-z]+')) {
      $w = $mm.Value.ToLower()
      if (($w.Length -ge 4 -and $low.StartsWith($w)) -or $w.StartsWith($low)) { return $mm.Value }
    }
    return ''
  }
  if ($m.Contains($me)) { return $me }
  if ($me.Length -ge 3 -and $m.Contains($me.Substring(0, 2))) { return $me.Substring(0, 2) }
  return ''
}
function Add-CallRun($main, [string]$text, $col, $tag, [string]$word) {
  if (-not $word -or -not $text) { [void](Add-Run $main $text $col $tag); return }
  $parts = [regex]::Split($text, '(' + [regex]::Escape($word) + ')', 'IgnoreCase')
  foreach ($pt in $parts) {
    if (-not $pt) { continue }
    if ($pt -ieq $word) { [void](Add-Run $main $pt 'ff9a40' $tag) } else { [void](Add-Run $main $pt $col $tag) }
  }
}
# (2026-11-03) 새 디자인: 줄 앞 채널 배지 (둥근 알약 · 채널 색)
function Chan-Badge($r) {
  $t = [string]$r.t; $n = $null; $c = 'ffffff'
  switch -Regex ($t) {
    '^PARTY' { $n = '파티'; $c = 'aaaaff' } '^INSTANCE' { $n = '인던'; $c = 'aad4ff' } '^RAID_WARNING$' { $n = '경보'; $c = 'ff4809' } '^RAID' { $n = '공대'; $c = 'ff7f00' }
    '^GUILD$' { $n = '길드'; $c = '40ff40' } '^OFFICER$' { $n = '관리'; $c = '40c040' } 'WHISPER' { $n = '귓'; $c = 'ff80ff' }
    '^SAY$' { $n = '일반'; $c = 'ffffff' } '^YELL$' { $n = '외침'; $c = 'ff4040' }
    '^CHANNEL$' {
      $cn = [string]$r.cname; $c = 'ffc0c0'
      if (No-TrChan $cn) { $n = '한인'; $c = '6fd3ff'; break }   # (2026-11-05) krus 채널은 눈에 띄는 하늘색 배지
      if ($cn -match '(?i)trade|거래') { $n = '거래' } elseif ($cn -match '(?i)lookingforgroup|lfg|파티 ?찾기') { $n = '파찾' } elseif ($cn -match '(?i)general|공개') { $n = '공개' } elseif ($cn -match '(?i)localdefense|수비') { $n = '수비' } elseif ($cn) { $n = $(if ($cn.Length -gt 5) { $cn.Substring(0, 5) } else { $cn }) } else { $n = [string]$r.cnum }
    }
  }
  if (-not $n) { return $null }
  if ($r.call) { $c = 'ff9a40' }   # (2026-11-03 A안) 공개 채널에서 내 이름이 불리면 배지를 주황으로
  # (2026-11-03) 시안 C안 그대로: 고정 폭 둥근 알약 · 글자 11/13 비율 · 왼쪽 칸에 따로 (원문 줄이 글 칸에 맞춰 정렬)
  $kz = [double]$FSZ * ([double]$S.fz / 12.0)
  $b = New-Object System.Windows.Controls.Border; $b.CornerRadius = New-Object System.Windows.CornerRadius((U (9 * $kz))); $b.Padding = New-Object System.Windows.Thickness((U 5), 0, (U 5), 0)
  $b.MinWidth = (U (36 * $kz)); $b.Height = (U (15.5 * $kz)); $b.VerticalAlignment = 'Center'
  $cc = [System.Windows.Media.ColorConverter]::ConvertFromString('#' + $c)
  $b.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(56, $cc.R, $cc.G, $cc.B))
  $tx = Line-TB 10.2; UIF $tx; $tx.Text = $n; $tx.TextWrapping = 'NoWrap'; $tx.HorizontalAlignment = 'Center'; $tx.VerticalAlignment = 'Center'; $tx.LineHeight = [double]::NaN; $tx.LineStackingStrategy = 'MaxHeight'
  $tx.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb([byte][math]::Min(255, $cc.R + 30), [byte][math]::Min(255, $cc.G + 30), [byte][math]::Min(255, $cc.B + 30)))
  $b.Child = $tx
  $hold = New-Object System.Windows.Controls.Grid; $hold.Height = (U (16.5 * $kz)); $hold.VerticalAlignment = 'Top'; $hold.Margin = New-Object System.Windows.Thickness(0, (U (1.5 * $kz)), (U 7), 0)   # (2026-11-03) 이름 글자 높이에 맞춤
  [void]$hold.Children.Add($b)
  return $hold
}
function Fill-Main($L) {
  $r = $L.rec; $main = $L.main; $main.Inlines.Clear()
  if ($r.kind -eq 'S') { foreach ($p in (Parse-Wow $r.text $r.col)) { [void](Add-Run $main $p[0] $p[1] $null) }; return }
  $col = $r.col; $who = Short $r.sender; $nameHex = $(if ($r.cls) { $r.cls } else { $col })
  $bdg = [bool]$L.hasB
  switch -Regex ($r.t) {
    '^WHISPER$' { [void](Add-Run $main "$who" $nameHex $null); [void](Add-Run $main ' : ' $col $null) }
    '^WHISPER_INFORM$' { [void](Add-Run $main ('→ ' + $who) $nameHex $null); [void](Add-Run $main ' : ' $col $null) }
    '^BN_WHISPER$' { [void](Add-Run $main "$who" $col $null); [void](Add-Run $main ' : ' $col $null) }
    '^BN_WHISPER_INFORM$' { [void](Add-Run $main ('→ ' + $who) $col $null); [void](Add-Run $main ' : ' $col $null) }
    '^EMOTE$' { [void](Add-Run $main "$who " $nameHex $null) }
    '^CHANNEL$' { if (-not $bdg) { [void](Add-Run $main ("[{0}. {1}] " -f $r.cnum, $r.cname) $col $null) }; [void](Add-Run $main "$who" $nameHex $null); [void](Add-Run $main ' : ' $col $null) }
    '^YELL$' { [void](Add-Run $main "$who" $nameHex $null); [void](Add-Run $main ' : ' $col $null) }
    default { if ($PREFIX[$r.t] -and -not $bdg) { [void](Add-Run $main $PREFIX[$r.t] $col $null) }; [void](Add-Run $main "$who" $nameHex $null); [void](Add-Run $main ' : ' $col $null) }
  }
  # (2026-10-31) 공개 채널·일반 대화에서 나를 부른 단어만 주황으로 강조 (글은 채널 색 그대로 · 게임 대화창과 같게)
  if ($L.body) {
    # (2026-11-02) 번역문 속 [아이템 이름]도 원문 링크처럼 누를 수 있게 (원문의 링크 이름과 똑같은 [ ]만 · 색도 원문 아이템 색)
    $lkm = @{}
    foreach ($p in (Parse-Wow $r.msg $col)) { if ($p[2] -and ([string]$p[0]) -match '^\[.+\]$' -and -not $lkm.ContainsKey([string]$p[0])) { $lkm[[string]$p[0]] = @([string]$p[2], $p[1]) } }
    $bd = [string]$L.body; $pos = 0
    # (2026-11-03 A안) 번역문에서 내 이름이 빠졌으면 앞에 붙임 (예: 'Are you from America Ostalo?' → '미국에서 왔음?' 이던 것)
    if ($r.call -and $bd.IndexOf([string]$r.call, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $bd = [string]$r.call + ', ' + $bd }
    if ($lkm.Count -gt 0) {
      foreach ($mm in [regex]::Matches($bd, '\[[^\[\]]+\]')) {
        if (-not $lkm.ContainsKey($mm.Value)) { continue }
        if ($mm.Index -gt $pos) { Add-CallRun $main $bd.Substring($pos, $mm.Index - $pos) $col $null ([string]$r.call) }
        $lv = $lkm[$mm.Value]; [void](Add-Run $main $mm.Value $lv[1] @{ link = $lv[0] })
        $pos = $mm.Index + $mm.Length
      }
    }
    if ($pos -lt $bd.Length) { Add-CallRun $main $bd.Substring($pos) $col $null ([string]$r.call) }
  }
  else { foreach ($p in (Parse-Wow $r.msg $col)) { Add-CallRun $main $p[0] $p[1] $(if ($p[2]) { @{ link = [string]$p[2] } } else { $null }) $(if ($p[2]) { '' } else { [string]$r.call }) } }
}
function Render-Main($L, $body) { if ($null -ne $body) { $L.body = $body }; Fill-Main $L }
function Build-Sub($L) {
  if (-not $L.col) { return }
  if ($L.sub) { $L.col.Children.Remove($L.sub) }
  # (2026-11-03) 시안대로: 원문은 글 칸 아래에 회색으로 · 영어면 EN 표시 없음 (다른 언어만 작게 표시)
  $kz0 = [double]$FSZ * ([double]$S.fz / 12.0)
  $sp = New-Object System.Windows.Controls.DockPanel; $sp.LastChildFill = $true; $sp.Margin = New-Object System.Windows.Thickness(0, (U 2), 0, 0)   # (2026-11-13 대표 · 사용자 요청) 번역 줄과 원문 사이 2 띄움
  if ($L.subTag -and [string]$L.subTag -ne 'EN') {
    $pb = New-Object System.Windows.Controls.Border; $pb.CornerRadius = New-Object System.Windows.CornerRadius((U 4)); $pb.Background = Br '#46C8A55A'; $pb.BorderBrush = Br '#96E1BE6E'; $pb.BorderThickness = New-Object System.Windows.Thickness(0.8)
    $pb.Padding = New-Object System.Windows.Thickness((U 3.5), 0, (U 3.5), 0); $pb.Margin = New-Object System.Windows.Thickness(0, (U 2), (U 5), 0); $pb.VerticalAlignment = 'Top'
    $pt = Line-TB 8; $pt.Text = $L.subTag; $pt.Foreground = Br '#FFFFE09A'; $pt.TextWrapping = 'NoWrap'; $pb.Child = $pt
    [System.Windows.Controls.DockPanel]::SetDock($pb, 'Left'); [void]$sp.Children.Add($pb)
  }
  $t = Line-TB 10.2; $t.Foreground = Br '#FFDED4BA'; $t.LineHeight = (U (14 * $kz0))   # (2026-11-13 대표 A안) 원문 = 연한 상아색 (회색은 잡템 같았음)
  if ($L.rec -and $L.rec.call) { foreach ($pt in [regex]::Split([string]$L.subText, '(' + [regex]::Escape([string]$L.rec.call) + ')', 'IgnoreCase')) { if (-not $pt) { continue }; $rn = New-Object System.Windows.Documents.Run($pt); if ($pt -ieq [string]$L.rec.call) { $rn.Foreground = HexBr 'ff9a40' }; [void]$t.Inlines.Add($rn) } }   # (2026-11-03 A안) 원문 줄의 내 이름도 주황
  else { $t.Text = $L.subText }
  [void]$sp.Children.Add($t)
  $L.sub = $sp
  [void]$L.col.Children.Add($sp)
}
function Set-Sub($L, $tag, $text) {
  $L.subTag = $tag; $L.subText = $text
  Build-Sub $L
  if ($Sv.VerticalOffset -ge $Sv.ScrollableHeight - 40) { $Sv.ScrollToEnd() }
}
$script:PWu = $PW
# 화면 크기가 바뀌면 다시 그림
function Redraw-All { foreach ($L in $LineList) { Build-Line $L } }
function Apply-TabTo($L) {
  # (2026-10-26) 탭마다 고른 대화 종류만 보이게
  $f = Tab-Filt ([string]$S.tab)
  $kk = $(if ($L.chk) { [string]$L.chk } else { [string]$L.cat })
  $L.box.Visibility = $(if (Tab-On $f $kk) { 'Visible' } else { 'Collapsed' })
}
function Select-Tab($k) {
  $S.tab = $k; Save-Cfg; $script:trDirty = $true
  if (-not $Medals.ContainsKey([string]$k)) { $k = 'all'; $S.tab = 'all' }   # (2026-11-08) 지운 탭이면 전체로
  Paint-Tabs
  foreach ($L in $LineList) { Apply-TabTo $L }
  $Sv.ScrollToEnd()
}
# (2026-10-27) 아이템·주문·퀘스트 링크 [이름]을 누르면 게임에서 그 정보 창을 엶 (게임 대화창에서 누른 것과 같음)
#  게임 채팅에 '/ntlink item:12345:…'를 대신 입력 → 게임 애드온이 게임의 링크 열기(SetItemRef)를 부름
function Show-Link([string]$lk) {
  if ($lk -notmatch '^(item|spell|quest|enchant|talent|achievement):[0-9:\-]+$') { return }
  Send-Wow @("/ntlink $lk") $true
}
$Lines.Add_MouseLeftButtonUp({ param($snd, $e)
  $o = $e.OriginalSource
  if ($o -is [System.Windows.Documents.Run] -and $o.Tag -is [hashtable] -and $o.Tag.link) { Show-Link $o.Tag.link; $e.Handled = $true; return }
  # (2026-10-27) 글자 조각(Run · 아이템 링크 [ ] 글씨 등)을 누르면 VisualTreeHelper가 오류를 내며 번역창이 꺼졌음 → 글자 조각은 논리 부모로 올라감
  while ($o -and -not ($o -is [System.Windows.Controls.StackPanel] -and $o.Tag -is [hashtable])) {
    if ($o -is [System.Windows.Media.Visual] -or $o -is [System.Windows.Media.Media3D.Visual3D]) { $o = [System.Windows.Media.VisualTreeHelper]::GetParent($o) }
    elseif ($o -is [System.Windows.FrameworkContentElement]) { $o = $o.Parent }
    elseif ($o -is [System.Windows.DependencyObject]) { $o = [System.Windows.LogicalTreeHelper]::GetParent($o) }
    else { $o = $null }
  }
  if ($o -and $o.Tag.rec.kind -eq 'C' -and -not $o.Tag.rec.me -and $o.Tag.rec.sender) {
    $state.target = Tell-Tg $o.Tag.rec.sender
    Enter-Input
  }
})

# (2026-11-07) 번역 대화창에서 이름(줄) 오른쪽 클릭 = 메뉴: 파티 초대 · 귓속말 · 정보 보기 · 친구 추가 (게임 대화창과 같게)
function Line-Rec($o) {
  while ($o -and -not ($o -is [System.Windows.Controls.StackPanel] -and $o.Tag -is [hashtable])) {
    if ($o -is [System.Windows.Media.Visual] -or $o -is [System.Windows.Media.Media3D.Visual3D]) { $o = [System.Windows.Media.VisualTreeHelper]::GetParent($o) }
    elseif ($o -is [System.Windows.FrameworkContentElement]) { $o = $o.Parent }
    elseif ($o -is [System.Windows.DependencyObject]) { $o = [System.Windows.LogicalTreeHelper]::GetParent($o) }
    else { $o = $null }
  }
  if ($o) { return $o.Tag.rec }; return $null
}
function Build-NameMenu {
  $popS.Children.Clear()
  $n = [string]$script:popName; $short = ($n -split '-')[0]
  Pop-Title $short
  $items = New-Object System.Collections.ArrayList
  $bn = [bool]$BnId[$n]
  if (-not $bn) { [void]$items.Add(@('파티 초대', "/invite $n")) }
  [void]$items.Add(@('귓속말', ''))
  if (-not $bn) { [void]$items.Add(@('정보 보기', "/who $short")); [void]$items.Add(@('친구 추가', "/friend $n")) }
  foreach ($it in $items) {
    $row = New-Object System.Windows.Controls.Border; $row.Width = 150; $row.Height = 28; $row.CornerRadius = New-Object System.Windows.CornerRadius(4); $row.Background = Br '#01000000'; $row.Cursor = [System.Windows.Input.Cursors]::Hand
    $l = TB $it[0] 12.5 $CREAM; $l.VerticalAlignment = 'Center'; $l.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0); $row.Child = $l
    $row.Tag = @{ cmd = [string]$it[1]; name = $n }
    $row.Add_MouseEnter({ param($snd, $e) $snd.Background = Br '#22FFFFFF' })
    $row.Add_MouseLeave({ param($snd, $e) $snd.Background = Br '#01000000' })
    $row.Add_MouseLeftButtonUp({ param($snd, $e)
      $tg = $snd.Tag; $Pop.IsOpen = $false; $e.Handled = $true
      try { if ($tg.cmd) { Send-Wow @($tg.cmd) $true } else { $state.target = Tell-Tg $tg.name; Enter-Input } } catch { Log "이름 메뉴: $_" } })
    [void]$popS.Children.Add($row)
  }
}
$Lines.Add_MouseRightButtonUp({ param($snd, $e)
  if (([FTRK.Keys]::GetAsyncKeyState(0x11) -band 0x8000) -ne 0) { return }   # Ctrl+오른쪽 클릭 = 대화창 잠금 (그대로)
  try {
    $r = Line-Rec $e.OriginalSource
    if (-not $r -or $r.kind -ne 'C' -or $r.me -or -not $r.sender) { return }
    $script:popMode = 'name'; $script:popName = [string]$r.sender
    Build-NameMenu; $Pop.PlacementTarget = $Lines; $Pop.Placement = 'MousePoint'; $Pop.IsOpen = $true; $e.Handled = $true
  } catch { Log "이름 메뉴: $_" }
})

# ---------- 번역 (2026-10-30) 지시문·사전은 translate-config.json 에서 읽음 (고치면 다시 켜지 않아도 2초 안에 반영) ----------
#  파일이 깨지면(쉼표·따옴표 실수) 이전 내용을 그대로 쓰고 translate-error.log 에 몇째 줄인지 적음
$TrCfgFile = Join-Path $Dir 'translate-config.json'
$TrCfgGood = Join-Path $A 'translate-config.good.json'   # 마지막으로 잘 읽힌 내용 (켤 때 원본이 깨져 있으면 이걸로 켬)
# 파일도 예비본도 없을 때만 쓰는 최소 지시문
$SYS_IN = "너는 월드 오브 워크래프트 게임 채팅 번역기다. 채팅 한 줄을 자연스러운 한국어 채팅 말투로 옮긴다. 원문에 없는 내용은 덧붙이지 않는다.`nJSON으로만 답: {""lang"":""원문 언어 코드(EN 등)"",""ko"":""번역문""}`n원문이 한국어면 lang은 KO, ko는 원문 그대로."
$SYS_OUT_T = "너는 월드 오브 워크래프트 게임 채팅 번역기다. 한국어 채팅 한 줄을 {lang}로, 그 언어권 와우 유저가 쓰는 짧은 말투로 옮긴다. 원문에 없는 내용은 덧붙이지 않는다.`nJSON으로만 답: {""text"":""번역문""}"
$SYS_VOICE = "너는 월드 오브 워크래프트 디스코드 음성 통역기다. 영어 말을 짧고 자연스러운 한국어로 옮긴다. 원문에 없는 내용은 덧붙이지 않는다.`nJSON으로만 답: {""ko"":""번역문""}"
$GLOSS_HEAD = '[던전·지역 이름 사전]'
$GLOSS_E = @(); $SLANG_IN = @(); $SLANG_OUT = @(); $script:VCALLS = @()
$script:cfgStamp = ''; $script:cfgErrAt = [DateTime]::MinValue
function Cfg-Lines($v) { if ($null -eq $v) { return '' }; return ((@($v) | ForEach-Object { [string]$_ }) -join "`n").Trim() }
function TrCfg-Apply($c) {
  # 전부 검사한 뒤 한꺼번에 바꿈 (중간에 틀린 게 있으면 아무것도 안 바뀜)
  $si = Cfg-Lines $c.sys_in; $so = Cfg-Lines $c.sys_out; $sv = Cfg-Lines $c.sys_voice
  if (-not $si -or -not $so -or -not $sv) { throw 'sys_in · sys_out · sys_voice 중 비어 있는 게 있어요' }
  $gl = New-Object System.Collections.ArrayList
  foreach ($e in @($c.gloss)) {
    $a = @($e); if ($a.Count -lt 2) { throw ("gloss 항목 모양이 틀려요: " + ($a -join ' , ')) }
    try { $rx = New-Object Text.RegularExpressions.Regex([string]$a[0], 'IgnoreCase') } catch { throw ("gloss 찾는 말 틀림: " + $a[0]) }
    [void]$gl.Add(@([string]$a[0], [string]$a[1], $rx))
  }
  $sl = New-Object System.Collections.ArrayList
  foreach ($e in @($c.slang_in)) {
    $a = @($e); if ($a.Count -lt 2) { throw ("slang_in 항목 모양이 틀려요: " + ($a -join ' , ')) }
    $opt = 'IgnoreCase'; if ($a.Count -gt 2 -and [string]$a[2] -eq 'cs') { $opt = 'None' }
    try { $rx = New-Object Text.RegularExpressions.Regex(('(?<![\p{L}\p{N}])(' + [string]$a[0] + ')(?![\p{L}\p{N}])'), $opt) } catch { throw ("slang_in 찾는 말 틀림: " + $a[0]) }
    [void]$sl.Add(@([string]$a[0], [string]$a[1], $rx))
  }
  # (2026-11-01) 사전 겹침 검사: 같은 말이 서로 다른 두 항목에 들어 있으면 로그에 남김 (힌트끼리 싸우지 않게 정리할 때 씀)
  try {
    $tk = @{}; $dup = New-Object System.Collections.ArrayList
    foreach ($x in $sl) {
      $p = [string]$x[0]; if ($p -match '[\(\)\[\]\\\?\*\+]') { continue }
      foreach ($w in ($p.ToLower() -split '\|')) { $w = $w.Trim(); if (-not $w) { continue }; if ($tk.ContainsKey($w)) { if ($tk[$w] -ne $p -and -not $dup.Contains($w)) { [void]$dup.Add($w) } } else { $tk[$w] = $p } }
    }
    if ($dup.Count -gt 0) { Log ("사전 겹침(같은 말이 두 항목에): " + (@($dup | Select-Object -First 15) -join ', ')) }
  } catch {}
  $sw = New-Object System.Collections.ArrayList
  foreach ($e in @($c.slang_out)) { $a = @($e); if ($a.Count -lt 2 -or -not [string]$a[0]) { throw ("slang_out 항목 모양이 틀려요: " + ($a -join ' , ')) }; [void]$sw.Add(@([string]$a[0], [string]$a[1])) }
  # (2026-10-31) 음성 레이드 콜 사전: 짧은 말이 이 목록과 통째로 맞으면 AI 없이 바로 이 한국어 (늘 정확 · 더 빠름)
  $vc = New-Object System.Collections.ArrayList
  foreach ($e in @($c.voice_calls)) {
    $a = @($e); if ($a.Count -lt 2) { throw ("voice_calls 항목 모양이 틀려요: " + ($a -join ' , ')) }
    try { $rx = New-Object Text.RegularExpressions.Regex(('^(?:(?:ok(?:ay)?|alright|all right|guys|everyone|everybody|and|now|so|go|yo|hey)\s+)*(?:' + [string]$a[0] + ')(?:\s+(?:guys|everyone|everybody|now|please|pls|asap))*$'), 'IgnoreCase') } catch { throw ("voice_calls 찾는 말 틀림: " + $a[0]) }
    [void]$vc.Add(@([string]$a[0], [string]$a[1], $rx))
  }
  # (2026-11-01) pre_fix: 뜻이 하나뿐인 와우 용어는 모델에 보내기 전에 원문에서 한국어 용어로 바꿔 넣음 (4B가 힌트를 무시해도 그대로 나오게)
  $pf = New-Object System.Collections.ArrayList
  foreach ($e in @($c.pre_fix)) {
    if ($null -eq $e) { continue }
    $a = @($e); if ($a.Count -lt 2) { throw ("pre_fix 항목 모양이 틀려요: " + ($a -join ' , ')) }
    $fl = $(if ($a.Count -gt 2) { [string]$a[2] } else { '' })   # 'cs' = 대소문자 구별 · 'voice' = 음성에만 · 'voice-cs' = 둘 다
    $opt = 'IgnoreCase'; if ($fl -match 'cs') { $opt = 'None' }
    try { $rx = New-Object Text.RegularExpressions.Regex(('(?<![\p{L}\p{N}])(?<![가-힣]\([^()]*)(' + [string]$a[0] + ')(?![\p{L}\p{N}])'), $opt) } catch { throw ("pre_fix 찾는 말 틀림: " + $a[0]) }   # (2026-11-04) 앞 규칙이 넣은 '마나 연소(Mana Burn)' 괄호 속 영어는 다시 안 바꿈
    [void]$pf.Add(@($rx, [string]$a[1], ($fl -match 'voice')))
  }
  # (2026-11-01) ko_fix: 받은 채팅 번역 결과에 남은 약어를 늘 같은 한국어로 (모델이 힌트를 무시해도) · [아이템] 안은 안 건드림
  $kf = New-Object System.Collections.ArrayList
  foreach ($e in @($c.ko_fix)) {
    if ($null -eq $e) { continue }
    $a = @($e); if ($a.Count -lt 2) { throw ("ko_fix 항목 모양이 틀려요: " + ($a -join ' , ')) }
    try { $rx = New-Object Text.RegularExpressions.Regex(('(?<![A-Za-z0-9])(?<![가-힣]\([^()]*)(' + [string]$a[0] + ')(?![A-Za-z0-9])'), 'IgnoreCase') } catch { throw ("ko_fix 찾는 말 틀림: " + $a[0]) }   # (2026-11-04) '카라잔(Karazhan)'의 괄호 속 영어 이름은 안 바꿈
    [void]$kf.Add(@($rx, [string]$a[1]))
  }
  $script:SYS_IN = $si; $script:SYS_OUT_T = $so; $script:SYS_VOICE = $sv
  $script:KO_FIX = $kf.ToArray()
  $script:PRE_FIX = $pf.ToArray()
  $script:VCALLS = $vc.ToArray()
  $script:WHISPER_PROMPT = Cfg-Lines $c.whisper_prompt
  if ($c.gloss_head) { $script:GLOSS_HEAD = [string]$c.gloss_head }
  $script:GLOSS_E = $gl.ToArray(); $script:SLANG_IN = $sl.ToArray(); $script:SLANG_OUT = $sw.ToArray()
}
function TrCfg-Read([string]$path) {
  $txt = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
  try { $c = $txt | ConvertFrom-Json } catch {
    $m = "$_"; if ($m -match '\((\d+)\)') { $pos = [Math]::Min([int]$matches[1], $txt.Length); $m = ("{0}번째 줄 근처 · {1}" -f (($txt.Substring(0, $pos) -split "`n").Count), $m) }
    throw ("JSON 모양 틀림 (쉼표·따옴표·괄호 확인) · " + $m)
  }
  TrCfg-Apply $c
}
function TrCfg-Load([bool]$first = $false) {
  try { $script:cfgStamp = [string](Get-Item -LiteralPath $TrCfgFile -ErrorAction Stop).LastWriteTimeUtc.Ticks } catch { $script:cfgStamp = 'none' }
  try {
    TrCfg-Read $TrCfgFile
    try { Copy-Item -LiteralPath $TrCfgFile -Destination $TrCfgGood -Force } catch {}
    Log ("번역 사전 읽음: 은어 {0} · 영어 표현 {1} · 지명 {2} · 음성 콜 {3}" -f $SLANG_IN.Count, $SLANG_OUT.Count, $GLOSS_E.Count, @($script:VCALLS).Count)
    $script:cfgErrAt = [DateTime]::MinValue
    try { $Cache.Clear() } catch {}   # 지시문이 바뀌었으니 예전 번역 기억은 버림
  } catch {
    Log ("translate-config.json 읽기 실패 → " + $(if ($first) { '예비본으로 켬' } else { '이전 내용 그대로 씀' }) + " · $_")
    $script:cfgErrAt = [DateTime]::Now
    if ($first -and (Test-Path -LiteralPath $TrCfgGood)) { try { TrCfg-Read $TrCfgGood } catch { Log "예비본도 읽기 실패: $_" } }
  }
  try { Paint-Status } catch {}
}
function Sys-Out($lang, [string]$t = '') {
  $n = $LANGNAME[$lang]; if (-not $n) { $n = '영어' }
  return $SYS_OUT_T.Replace('{lang}', $n) + (Gloss-For $t)
}
function Slang-In([string]$t) {
  if (-not $t) { return '' }
  # (2026-11-01) 사전이 커져도 힌트가 넘치지 않게 (만 개가 돼도 빠르고 정확하게)
  #  ① 같은 자리에 걸린 짧은 말은 그 자리를 덮는 더 긴 구절에 양보 (rez sick 이 걸리면 sick 은 안 붙임)
  #  ② 같은 말·같은 뜻은 한 번만  ③ 한 줄에 최대 6개 · 긴 구절(더 구체적인 것) 먼저 고르고 원문 순서대로 보냄
  $hit = @()
  try {
    $hs = New-Object System.Collections.ArrayList
    $br = [regex]::Matches($t, '\[[^\[\]]+\]')   # (2026-11-01) [아이템] 이름 속 일부 단어(예: [Azerothian Diamond]의 diamond=마름모 징표)는 힌트 안 붙임 · 이름 전체가 사전에 있으면 붙임
    foreach ($e in $SLANG_IN) { $m = $e[2].Match($t); if ($m.Success -and $m.Length -gt 0) {
      $inItem = $false; foreach ($b in $br) { if ($m.Index -gt $b.Index -and ($m.Index + $m.Length) -lt ($b.Index + $b.Length) -and $m.Length -lt ($b.Length - 2)) { $inItem = $true; break } }
      if (-not $inItem) { [void]$hs.Add(@($m.Index, $m.Length, $m.Value, [string]$e[1])) } } }
    if ($hs.Count -eq 0) { return '' }
    $byLen = @($hs | Sort-Object -Property @{ Expression = { $_[1] }; Descending = $true })
    $keep = New-Object System.Collections.ArrayList; $seen = @{}
    foreach ($h in $byLen) {
      $inside = $false
      foreach ($k in $keep) { if ($h[0] -lt ($k[0] + $k[1]) -and ($h[0] + $h[1]) -gt $k[0] -and $h[1] -lt $k[1]) { $inside = $true; break } }
      if ($inside) { continue }
      $key = ([string]$h[2]).ToLower() + '=' + $h[3]; if ($seen.ContainsKey($key)) { continue }; $seen[$key] = 1
      [void]$keep.Add($h)
      if ($keep.Count -ge 6) { break }
    }
    $hit = @($keep | Sort-Object -Property @{ Expression = { $_[0] } } | ForEach-Object { '- ' + $_[2] + ' = ' + $_[3] })
  } catch {
    Log "은어 힌트 고르기: $_ (예전 방식으로)"
    $hit = @(); foreach ($e in $SLANG_IN) { $m = $e[2].Match($t); if ($m.Success) { $hit += ('- ' + $m.Value + ' = ' + $e[1]) } }
  }
  if ($hit.Count -eq 0) { return '' }
  return "`n[이 줄에 나온 와우 은어 후보 · 게임 얘기로 쓰였을 때만 이 뜻 · 평범한 영어 문장이면 무시하고 보통 뜻으로 · 원문에 없는 말은 쓰지 말 것]`n" + ($hit -join "`n")
}
function Slang-Out([string]$t) {
  if (-not $t) { return '' }
  $hit = @()
  foreach ($e in $SLANG_OUT) { if ($t.Contains($e[0])) { $hit += ('- ' + $e[0] + ' → ' + $e[1]) } }
  if ($hit.Count -eq 0) { return '' }
  return "`n[이 줄에 나온 말의 와우 영어 표현 · 그 단어 자리에만 쓰고 문장의 나머지 뜻은 전부 그대로 옮길 것 · 다른 언어면 그 언어권 관례로]`n" + ($hit -join "`n")
}
# (2026-11-01) 받은 채팅 번역 마무리: ① [아이템] 이름은 원문 그대로(사전에 그 이름 전체가 있으면 그 한국어) ② 남은 던전 약어 등은 ko_fix 대로
function Ko-Fix([string]$src, $j) {
  $ko = [string]$j.ko
  if (-not $ko -or [string]$j.lang -eq 'KO') { return $j }
  try {
    $sb = [regex]::Matches($src, '\[[^\[\]]+\]'); $kb = [regex]::Matches($ko, '\[[^\[\]]+\]')
    if ($sb.Count -gt 0 -and $sb.Count -eq $kb.Count) {
      for ($i = $kb.Count - 1; $i -ge 0; $i--) {
        $name = $sb[$i].Value.Substring(1, $sb[$i].Value.Length - 2); $rep = $name
        foreach ($e in $SLANG_IN) { $m = $e[2].Match($name); if ($m.Success -and $m.Length -eq $name.Length) { $rep = (([string]$e[1]) -split '\s*[(·]')[0].Trim(); break } }
        $ko = $ko.Substring(0, $kb[$i].Index) + '[' + $rep + ']' + $ko.Substring($kb[$i].Index + $kb[$i].Length)
      }
    }
    if ($KO_FIX -and $KO_FIX.Count -gt 0) {
      $parts = [regex]::Split($ko, '(\[[^\[\]]+\])')
      for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i].StartsWith('[')) { continue }
        foreach ($f in $KO_FIX) { $parts[$i] = $f[0].Replace($parts[$i], $f[1]) }
      }
      $ko = $parts -join ''
    }
    $j.ko = $ko
  } catch { try { Log "번역 마무리: $_" } catch {} }
  return $j
}
# (2026-11-01) 모델에 보낼 원문만 바꿈 (화면·기억에는 원래 영어 그대로) · [아이템] 안은 안 건드림
function Pre-Fix([string]$t, [bool]$voice = $false) {
  if (-not $t -or -not $PRE_FIX -or $PRE_FIX.Count -eq 0) { return $t }
  try {
    $parts = [regex]::Split($t, '(\[[^\[\]]+\])')
    # (2026-11-03) 전부 대문자로 친 글(NAH KEEPING ALL MY GOLD…)은 4B가 뜻을 자주 틀려서 4글자 이상 단어만 소문자로 (MT·SP 같은 짧은 약어는 그대로)
    $nl = $t -replace '\[[^\[\]]+\]', ''; $lc = ([regex]::Matches($nl, '[A-Za-z]')).Count; $uc = ([regex]::Matches($nl, '[A-Z]')).Count
    $caps = (-not $voice) -and $lc -ge 8 -and $uc -ge ($lc * 0.8)
    for ($i = 0; $i -lt $parts.Count; $i++) {
      if ($parts[$i].StartsWith('[')) { continue }
      if ($caps) { $parts[$i] = [regex]::Replace($parts[$i], '[A-Za-z]{4,}', { param($m) $m.Value.ToLower() }) }
      foreach ($f in $PRE_FIX) { if ($f[2] -and -not $voice) { continue }; $parts[$i] = $f[0].Replace($parts[$i], $f[1]) }   # 음성 전용(kick=차단 · MC=정신 지배)은 채팅엔 안 씀
    }
    return ($parts -join '')
  } catch { return $t }
}
function Gloss-For([string]$t) {
  if (-not $t) { return '' }
  $hit = @()
  foreach ($e in $GLOSS_E) { if ($e[2].IsMatch($t)) { $hit += ('- ' + $e[1]); if ($hit.Count -ge 4) { break } } }   # (2026-11-01) 지명 힌트도 한 줄에 최대 4개
  if ($hit.Count -eq 0) { return '' }
  return "`n" + $GLOSS_HEAD + "`n" + ($hit -join "`n")
}
TrCfg-Load $true

# ---------- 번역 엔진 (공유판): 사비 = 내 컴퓨터 Ollama(127.0.0.1:11434 · 모델 sabi) · 제미나이 = 보내기에서 고른 때만 ----------
#  사비가 아직 켜지는 중이면(Ollama 준비 중) 조용히 다시 확인하다가 연결되면 모델을 미리 올려 둠
function Eng-Build {
  $old = @{}; foreach ($b in @($script:BE)) { if ($b) { $old[$b.id] = $b } }
  $list = @()
  if ($Tier -ne 'low') { $list += @{ id = 'local'; kind = 'ollama'; host = ([string]$S.localHost).TrimEnd('/'); model = [string]$S.localModel; short = '자체'; wait = 25; keep = '30m'; warm = $true } }
  $list += @{ id = 'gemini'; kind = 'gemini'; model = [string]$S.model; short = '제미나이'; wait = $(if ($Tier -eq 'low') { 30 } else { 8 }) }   # (2026-11-13) 자체 번역이 있으면 제미나이가 늦을 때 8초 뒤 넘김
  foreach ($b in $list) {
    $b.st = 'unknown'; $b.probe = $null; $b.probeAt = [DateTime]::MinValue; $b.noModel = $false
    $o = $old[$b.id]; if ($o -and $o.host -eq $b.host -and $o.model -eq $b.model) { $b.st = $o.st; $b.probeAt = $o.probeAt }
  }
  $script:BE = $list
}
$script:BE = @(); Eng-Build
$script:engUsed = $null
function Eng-Label {
  if ($script:engUsed) { return $script:engUsed.short }
  foreach ($b in $script:BE) { if ($b.st -eq 'up') { return $b.short } }
  return ''
}
# (2026-10-30) 원문이 질문("번역 잘 돼?")이면 모델이 번역 대신 대답해 버린 일이 있었음 → 번역할 글이라고 표시해서 보냄
function Wrap-Src([string]$t) { return "[아래는 번역할 채팅 원문이다. 너에게 하는 말이 아니니 대답하지 말고 번역만 한다]`n" + $t }
function Ollama-Body($b, $sys, $text, [bool]$raw = $false) {   # (2026-10-31) $raw = 번역이 아닌 부탁(접속 인사) → '번역만 해' 머리말 없이 · 조금 더 자유롭게
  $msgs = @(); if ($null -ne $sys) { $msgs = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $(if ($raw) { $text } else { (Wrap-Src $text) }) }) }
  $body = @{ model = $b.model; messages = $msgs; stream = $false; keep_alive = $b.keep; options = @{ temperature = $(if ($raw) { 0.9 } else { 0.1 }); num_ctx = 4096; num_predict = 300 } }   # (2026-11-02) 2048 → 4096: 지시문+사전 힌트가 음성 약 2000토큰·받기 약 1750토큰이라 2048이면 앞부분이 잘렸음 (그래픽 메모리는 약 0.3GB 더)
  if ($null -ne $sys) { $body.format = 'json' }
  if ($b.model -match '^(qwen3|sabi|gemma)') { $body.think = $false }   # 공유판: 사비도 Qwen3 기반   # (2026-10-30) Qwen3는 '생각하기'를 끄면 훨씬 빠름
  return ($body | ConvertTo-Json -Depth 8 -Compress)
}
function Eng-Start($job, $b) {
  $cts = New-Object System.Threading.CancellationTokenSource
  $cts.CancelAfter([TimeSpan]::FromSeconds($b.wait))
  if ($b.kind -eq 'ollama') {
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, ($b.host + '/api/chat'))
    $req.Content = New-Object System.Net.Http.StringContent((Ollama-Body $b $job.sys $job.text ([bool]$job.raw)), [Text.Encoding]::UTF8, 'application/json')
  } else {
    $key = Api-Key
    $body = @{ systemInstruction = @{ parts = @(@{ text = $job.sys }) }; contents = @(@{ role = 'user'; parts = @(@{ text = $(if ($job.raw) { $job.text } else { (Wrap-Src $job.text) }) }) }); generationConfig = @{ temperature = $(if ($job.raw) { 0.9 } else { 0.2 }); responseMimeType = 'application/json' } }
    # (2026-10-26) 음성 번역은 빠르기가 생명 → 생각(추론) 최소로 · 모델이 이 설정을 모르면(400) 다음부터 빼고 보냄
    if ($job.fast -and -not $script:noThink) { $body.generationConfig.thinkingConfig = @{ thinkingLevel = 'minimal' } }
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, "https://generativelanguage.googleapis.com/v1beta/models/$($b.model):generateContent")
    $req.Headers.Add('x-goog-api-key', $key)
    $req.Content = New-Object System.Net.Http.StringContent(($body | ConvertTo-Json -Depth 8 -Compress), [Text.Encoding]::UTF8, 'application/json')
  }
  $job.be = $b; $job.cts = $cts; $job.t1 = [DateTime]::Now; $job.kicked = $false
  $job.task = $Http.SendAsync($req, $cts.Token)
}
function Eng-Next($job) {
  # 다음으로 쓸 수 있는 엔진 시작 · 없으면 $false
  $L = @($job.list)
  while ($job.i + 1 -lt $L.Count) {
    $job.i++; $b = $L[$job.i]
    if ($b.kind -eq 'ollama' -and ($b.st -eq 'down' -or $b.noModel -or $b.full)) { continue }
    if ($b.kind -eq 'gemini' -and -not (Api-Key)) { continue }
    if ($b.kind -eq 'gemini' -and $job.way -ne 'out' -and $Tier -ne 'low') { continue }   # (공유판) 받는 말은 늘 사비 · 제미나이는 보내기에서 고른 때만
    try { Eng-Start $job $b; return $true } catch { Log ("{0} 보내기 실패: {1}" -f $b.short, $_) }
  }
  return $false
}
$script:noThink = $false
# (공유판) 보내는 말: 설정 '보내기 번역'이 제미나이이고 키가 있으면 제미나이 먼저 → 실패하면 사비 · 아니면 사비만
function Out-List {
  $L = @()
  if ([string]$S.sendEng -eq 'gemini' -and (Api-Key)) { foreach ($b in $script:BE) { if ($b.id -eq 'gemini') { $L += $b } } }
  foreach ($b in $script:BE) { if ($b.kind -eq 'ollama') { $L += $b } }
  return ,$L
}
# 받는 말: 늘 사비만
function In-List {
  $L = @(); foreach ($b in $script:BE) { if ($b.kind -eq $(if ($Tier -eq 'low') { 'gemini' } else { 'ollama' })) { $L += $b } }   # (2026-11-12) 최저 단계는 받는 말도 Gemini
  return ,$L
}
function Gem-Send($sys, $text, [bool]$fast = $false, [string]$way = 'in', [bool]$raw = $false) {   # (주의) 이름을 $dir 로 하면 PowerShell은 대소문자를 안 가려서 폴더($Dir)를 가려 버림
  $job = @{ sys = $sys; text = $text; fast = $fast; i = -1; done = $false; res = $null; t0 = [DateTime]::Now; raw = $raw; way = $way }
  $job.list = $(if ($way -eq 'out') { Out-List } else { In-List })
  if (Eng-Next $job) { return $job }
  # 꺼져 있다고 알고 있어도 한 번은 다시 시도 (상태가 오래됐을 수 있음)
  $job.i = -1; foreach ($b in $script:BE) { if ($b.kind -eq 'ollama') { $b.st = 'unknown' } }
  if (Eng-Next $job) { return $job }
  return $null
}
function Norm-Lang([string]$l) {
  $l = $l.Trim(); if ($l.Length -eq 2) { return $l.ToUpper() }
  $map = @{ english = 'EN'; german = 'DE'; deutsch = 'DE'; french = 'FR'; russian = 'RU'; spanish = 'ES'; portuguese = 'PT'; italian = 'IT'; polish = 'PL'; japanese = 'JA'; chinese = 'ZH'; turkish = 'TR'; dutch = 'NL'; swedish = 'SV'; korean = 'KO' }
  $k = $map[$l.ToLower()]; if ($k) { return $k }; return $l.ToUpper()
}
function Parse-Json([string]$out) {
  # 모델이 ```json ... ``` 으로 감싸거나 앞뒤에 말을 붙여도 { } 만 꺼내서 읽음
  $out = [string]$out -replace '\s*/no_?think\b', ''   # (2026-11-01) 채팅 번역에도 모델 지시어 '/no_think'가 따라 붙던 것 지움 (음성은 Voice-Show에서)
  $s = ($out -replace '^\s*```(json)?', '' -replace '```\s*$', '').Trim()
  try { return ($s | ConvertFrom-Json) } catch {}
  $m = [regex]::Match($s, '\{[\s\S]*\}'); if ($m.Success) { try { return ($m.Value | ConvertFrom-Json) } catch {} }
  return $null
}
function Eng-Read($job) {
  # 끝난 요청 하나 읽기 → @{ json; raw } 또는 @{ err; down }
  $b = $job.be; $t = $job.task
  try { $job.cts.Dispose() } catch {}
  if ($t.IsCanceled) { if ($b.st -eq 'down') { return @{ err = ("{0} 연결 안 됨" -f $b.short); down = $true } }; return @{ err = ("{0} 응답 시간 초과({1}초)" -f $b.short, $b.wait); down = $true } }
  if ($t.IsFaulted) { return @{ err = ("{0} 연결 안 됨" -f $b.short); down = $true } }
  $resp = $t.Result
  $txt = ''; try { $txt = $resp.Content.ReadAsStringAsync().Result } finally { $sc = $resp.IsSuccessStatusCode; $code = [int]$resp.StatusCode; $resp.Dispose() }
  $bj = $null; try { $bj = $txt | ConvertFrom-Json } catch {}
  $mk = Get-Date -Format 'yyyy-MM'
  if ($b.kind -eq 'ollama') {
    if (-not $sc) {
      $em = ''; if ($bj -and $bj.error) { $em = [string]$bj.error }
      if ($code -eq 404 -or $em -match 'not found') { $b.noModel = $true; return @{ err = ("{0} 모델을 찾을 수 없음 (설치를 다시 해 주세요)" -f $b.short) } }
      return @{ err = ("{0} 오류 {1} {2}" -f $b.short, $code, $em) }
    }
    $out = ''; try { $out = [string]$bj.message.content } catch {}
    # (2026-10-30) 시간 나눠 보기: 읽기(지시문 처리) · 쓰기(번역문 생성) · 모델 올리기
    try { Dbg ("{0} 시간 · 읽기 {1}토큰 {2}ms · 쓰기 {3}토큰 {4}ms · 올리기 {5}ms" -f $b.short, [int]$bj.prompt_eval_count, [int]([double]$bj.prompt_eval_duration / 1e6), [int]$bj.eval_count, [int]([double]$bj.eval_duration / 1e6), [int]([double]$bj.load_duration / 1e6)) } catch {}
    try { if (-not $S.usage[$mk]) { $S.usage[$mk] = @{ calls = 0; inT = 0; outT = 0 } }; $um = $S.usage[$mk]; $um.lCalls = [int]$um.lCalls + 1 } catch {}
  } else {
    if (-not $sc) { $em = ''; if ($bj -and $bj.error) { $em = $bj.error.message }; return @{ err = ("번역 오류 {0} {1}" -f $code, $em) } }
    $out = ''
    try { $out = (@($bj.candidates[0].content.parts) | ForEach-Object { if ($_.text -and -not $_.thought) { $_.text } }) -join '' } catch {}
    try {
      $u = $bj.usageMetadata
      if (-not $S.usage[$mk]) { $S.usage[$mk] = @{ calls = 0; inT = 0; outT = 0 } }
      $S.usage[$mk].calls++; $S.usage[$mk].inT += [int]$u.promptTokenCount; $S.usage[$mk].outT += [int]$u.candidatesTokenCount
      if ($job.kind -eq 'voice') { # (2026-10-26) 그중 디스코드 음성만 따로 (도우미 사용량 화면에 따로 보임)
        $um = $S.usage[$mk]
        $um.vCalls = [int]$um.vCalls + 1; $um.vInT = [int]$um.vInT + [int]$u.promptTokenCount; $um.vOutT = [int]$um.vOutT + [int]$u.candidatesTokenCount
      }
    } catch {}
  }
  $j = Parse-Json $out
  if (-not $j) { return @{ err = ("{0} 답이 JSON이 아님" -f $b.short); raw = $out } }
  $names = @($j.PSObject.Properties | ForEach-Object { $_.Name })
  if ($names -contains 'lang' -and $j.lang) { $j.lang = Norm-Lang ([string]$j.lang) }
  # 번역 안 하고 원문을 그대로 돌려준 답·한국어가 남은 영어 답은 다음 엔진으로 (작은 모델 대비)
  $src = ([string]$job.text).Trim()
  if ($names -contains 'ko' -and $j.ko -and $j.lang -ne 'KO' -and ([string]$j.ko).Trim() -eq $src -and $src -match '[A-Za-z]+\s+[A-Za-z]+' -and $src -notmatch '[가-힣]') { return @{ err = ("{0} 번역 안 된 답" -f $b.short); raw = $out } }
  # (2026-10-30) 번역 대신 대답·설명을 한 답은 다음 엔진으로 (게임에 그대로 보내지는 일 막기)
  if ($names -contains 'text') {
    $tt = [string]$j.text
    # (2026-10-30) 뜻이 빠진 짧은 답 거르기 (예: '서버 열리기 전에 하드코어나 같이 하자' → 'wanna group? hc')
    $hn = ([regex]::Matches($src, '[가-힣]')).Count
    if ($hn -ge 10 -and $tt.Length -lt $hn * 0.9) { return @{ err = ("{0} 뜻이 빠진 짧은 답" -f $b.short); raw = $out } }
    if ($tt -match "(?i)\b(i('|’)?ll translate|i will translate|translat(e|ed|ion|ing) (the|this|it|your)|chat line|from korean|in korean|into english|to english|here('|’)?s the|as an ai|natural and concise)\b" -or $tt.Length -gt ($src.Length * 4 + 40)) { return @{ err = ("{0} 번역 대신 대답한 답" -f $b.short); raw = $out } }
  }
  if ($names -contains 'ko' -and ([string]$j.ko) -match '번역(해|하겠|된 |문|입니다|했)' -and $src -notmatch '(?i)translat') { return @{ err = ("{0} 번역 대신 대답한 답" -f $b.short); raw = $out } }
  # (2026-10-30) 한국어 번역에 엉뚱한 나라 글자(태국·라오스·러시아 문자 등)가 섞이면 다음 엔진으로 (작은 모델이 가끔 깨짐 · 예: '두ສາມ일')
  $odd = '[\p{L}-[\p{IsHangulSyllables}\p{IsHangulJamo}\p{IsHangulCompatibilityJamo}\p{IsBasicLatin}\p{IsLatin-1Supplement}\p{IsLatinExtended-A}]]'
  if ($names -contains 'ko' -and ([string]$j.ko) -match $odd -and $src -notmatch $odd) { return @{ err = ("{0} 깨진 글자 섞인 답" -f $b.short); raw = $out } }
  # (2026-10-30) 한자(중국어 글자)가 섞인 답은 다음 엔진으로 (Qwen 같은 모델 대비 · 원문에 한자가 있었으면 그대로 둠)
  $outTxt = [string]$j.ko + [string]$j.text
  if ($outTxt -match '\p{IsCJKUnifiedIdeographs}' -and $src -notmatch '\p{IsCJKUnifiedIdeographs}') { return @{ err = ("{0} 한자 섞인 답" -f $b.short); raw = $out } }
  # (2026-11-04) 같은 구절을 4번 넘게 이어 쓰는 고장 답(예: '그럴 리 없음... 그럴 리 없음...' ×14)은 다음 엔진으로
  #  원문에 같은 반복이 있으면 그대로 둠 · 'ㅋㅋㅋㅋ'·'하하하하'처럼 한 글자 반복은 제외 · 다른 엔진도 없으면 반복을 한 번으로 줄여서 씀
  $rpt = '(.{3,40}?)(?:[\s.…,!~]*\1){3,}'
  foreach ($fld in @('ko', 'text')) {
    $rv = [string]$j.$fld
    if (-not $rv) { continue }
    $hitRep = $false
    foreach ($mm in [regex]::Matches($rv, $rpt)) { $u = ($mm.Groups[1].Value -replace '[\s\p{P}]', ''); if ((@($u.ToCharArray() | Select-Object -Unique)).Count -ge 2) { $hitRep = $true; break } }
    if ($hitRep -and -not [regex]::IsMatch($src, $rpt)) {
      $jc = $null; try { $jc = ($j | ConvertTo-Json -Depth 4 | ConvertFrom-Json) } catch {}
      if ($jc) { try { $jc.$fld = [regex]::Replace([string]$jc.$fld, '(.{3,40}?)(?:[\s.…,!~]*\1)+', '$1') } catch {}; $job.spare = @{ json = $jc; raw = $out } }
      return @{ err = ("{0} 같은 말 반복 고장 답" -f $b.short); raw = $out }
    }
  }
  # (2026-11-03) 받은 말 번역에 일반 영어 단어가 잔뜩 남은 답은 다음 엔진으로 (예: 'Tomorrow Night'·'Recruiting'을 그대로 둠)
  #  [아이템]·{징표}·대문자 약어(SR·MS)는 빼고 셈 · 사람 이름 1~2개 정도는 괜찮게 3단어 이상 + 글자 비율 35% 이상일 때만
  if ($names -contains 'ko' -and $j.ko -and -not $job.raw) {
    $kk = ([string]$j.ko) -replace '\[[^\]]*\]', '' -replace '\{[^}]*\}', '' -replace '(?<=[가-힣])\([^()]*\)', ''   # (2026-11-04) '카라잔(Karazhan)'처럼 한글 뒤 괄호 속 영어 원래 이름은 안 셈
    $lw = @([regex]::Matches($kk, '\b[A-Za-z]*[a-z][A-Za-z]*\b') | Where-Object { $_.Value.Length -ge 4 })
    if ($lw.Count -ge 3) {
      $ll = 0; foreach ($m in $lw) { $ll += $m.Value.Length }
      $hl = ([regex]::Matches($kk, '[가-힣]')).Count
      if ($ll -gt ($ll + $hl) * 0.35) { $job.spare = @{ json = $j; raw = $out }; return @{ err = ("{0} 영어가 많이 남은 답" -f $b.short); raw = $out } }
    }
  }
  # (2026-10-31) 접속 인사(raw)는 한국어 답이 정상
  if (-not $job.raw -and $names -contains 'text' -and ([string]$j.text) -match '[가-힣]') { return @{ err = ("{0} 한국어가 남은 답" -f $b.short); raw = $out } }
  return @{ json = $j; raw = $out }
}
function Job-Ready($job) {
  # 번역 요청이 끝났는지 · 실패면 다음 엔진으로 넘기고 계속 기다림
  if ($job.done) { return $true }
  $b = $job.be
  if (-not $job.task.IsCompleted) {
    if ($b.kind -eq 'ollama') {
      if ($b.st -eq 'down') { try { $job.cts.Cancel() } catch {}; return $false }   # 확인해 보니 꺼져 있음 → 취소되면 다음으로
      # 2.5초 안에 답이 없으면 살아 있는지 바로 확인 (켜져 있으면 모델 올리는 중이니 계속 기다림)
      if (-not $job.kicked -and ([DateTime]::Now - $job.t1).TotalSeconds -ge 2.5) { $job.kicked = $true; Probe-Start $b $true }
    }
    return $false
  }
  $r = Eng-Read $job
  if ($r.err) {
    Dbg ("엔진 실패 · " + $r.err)
    if ($r.down -and $b.kind -eq 'ollama' -and $b.st -ne 'down') { $b.st = 'down'; $b.probeAt = [DateTime]::Now; Log ($r.err + ' → 다음 엔진으로') ; Paint-Status }
    if ($b.kind -eq 'gemini') { $job.fellBack = [string]$r.err }   # (공유판) 제미나이 실패 → 이 글만 사비로 (알림 한 줄)
    if (Eng-Next $job) { return $false }
    if ($job.spare -and [string]$r.err -match '영어가 많이 남은|반복 고장') { $job.res = $job.spare; $job.done = $true; return $true }   # (2026-11-03) 다른 엔진도 같으면 그나마 나은 답이라도 씀
    $job.res = $r; $job.done = $true; return $true
  }
  if ($b.kind -eq 'ollama' -and $b.st -ne 'up') { $b.st = 'up' }
  if ($script:engUsed -ne $b) { $script:engUsed = $b; Log ("번역 엔진: " + $b.short + $(if ($b.model) { ' ' + $b.model } else { '' })); Paint-Status }
  Dbg ("{0} {1}ms" -f $b.short, [int]([DateTime]::Now - $job.t0).TotalMilliseconds)
  $job.res = $r; $job.done = $true; return $true
}
function Gem-Read($job, [string]$kind = '') { return $job.res }
# 사비(Ollama)가 살아 있는지 2초짜리 확인 (모델 목록만 물어봄 · 모델을 깨우거나 붙잡지 않음)
function Probe-Start($b, [bool]$force = $false) {
  if ($b.kind -ne 'ollama' -or $b.probe) { return }
  if (-not $force -and ([DateTime]::Now - $b.probeAt).TotalSeconds -lt 1) { return }
  $cts = New-Object System.Threading.CancellationTokenSource; $cts.CancelAfter(3000)
  $b.probeAt = [DateTime]::Now; $b.probeCts = $cts
  try { $b.probe = $Http.GetAsync(($b.host + '/api/tags'), $cts.Token) } catch { $b.probe = $null; $b.st = 'down' }
}
function Warm-Up($b) {
  # 연결되자마자 모델을 미리 올려 둠 → 첫 문장도 바로 번역 (1시간 아무 요청 없으면 Ollama가 알아서 내림)
  try {
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, ($b.host + '/api/chat'))
    $req.Content = New-Object System.Net.Http.StringContent((Ollama-Body $b $null $null), [Text.Encoding]::UTF8, 'application/json')
    $script:warmTasks.Add($Http.SendAsync($req)) | Out-Null
  } catch {}
}
$script:warmTasks = New-Object System.Collections.ArrayList
$script:engTickAt = [DateTime]::MinValue; $script:cfgTickAt = [DateTime]::MinValue
function Eng-Tick {
  $now = [DateTime]::Now
  if (($now - $script:engTickAt).TotalMilliseconds -lt 200) { return }
  $script:engTickAt = $now
  foreach ($b in $script:BE) {
    if ($b.kind -ne 'ollama') { continue }
    if ($b.probe) {
      if (-not $b.probe.IsCompleted) { continue }
      $ok = $false; $models = ''
      try { if ($b.probe.Status -eq 'RanToCompletion') { $rp = $b.probe.Result; $ok = $rp.IsSuccessStatusCode; if ($ok) { $models = $rp.Content.ReadAsStringAsync().Result }; $rp.Dispose() } } catch {}
      try { $b.probeCts.Dispose() } catch {}
      $b.probe = $null
      # 켜져 있던 엔진은 바로 한 번 더 확인하고, 두 번 연속 실패해야 꺼짐 처리
      if (-not $ok -and $b.st -eq 'up' -and -not $b.fail1) { $b.fail1 = $true; Probe-Start $b $true; continue }
      $b.fail1 = $false
      $was = $b.st; $b.st = $(if ($ok) { 'up' } else { 'down' })
      if (-not $ok -and $Tier -ne 'low' -and ([string]$b.host) -match '127\.0\.0\.1|localhost') { try { Ollama-Start } catch {} }   # (2026-11-13) 내 PC 엔진이 꺼져 있으면 (2분에 한 번까지) 다시 켜 봄
      if ($ok) {
        $mn = $b.model; if ($mn -notmatch ':') { $mn += ':latest' }   # llama3.1 이라고만 쓰면 llama3.1:latest
        $b.noModel = ($models -and $models -notmatch ('"' + [regex]::Escape($mn) + '"'))
        if ($was -ne 'up') { Log ("{0} Ollama 연결됨 ({1}){2}" -f $b.short, $b.host, $(if ($b.noModel) { " · 모델 $($b.model) 없음" } else { '' })); if ($b.warm -and -not $b.noModel -and -not $b.full) { Warm-Up $b } }
      } elseif ($was -eq 'up') { Log ("{0} Ollama 응답 없음 → 다음 엔진 사용" -f $b.short) }
      if ($was -ne $b.st) { Paint-Status }
    } else {
      $gap = $(if ($b.st -eq 'up') { 60 } else { 15 })
      if (($now - $b.probeAt).TotalSeconds -ge $gap) { Probe-Start $b }
    }
  }
  for ($i = $script:warmTasks.Count - 1; $i -ge 0; $i--) { $wt = $script:warmTasks[$i]; if ($wt.IsCompleted) { try { if ($wt.Status -eq 'RanToCompletion') { $wt.Result.Dispose() } } catch {}; $script:warmTasks.RemoveAt($i) } }
  # 2초마다: 사전 파일이 바뀌었으면 다시 읽음
  if (($now - $script:cfgTickAt).TotalSeconds -ge 2) {
    $script:cfgTickAt = $now
    $st = 'none'; try { $st = [string](Get-Item -LiteralPath $TrCfgFile -ErrorAction Stop).LastWriteTimeUtc.Ticks } catch {}
    if ($st -ne $script:cfgStamp) { TrCfg-Load }
    if ($script:cfgErrAt -ne [DateTime]::MinValue -and ($now - $script:cfgErrAt).TotalSeconds -ge 30) { $script:cfgErrAt = [DateTime]::MinValue; Paint-Status }
  }
}
# (공유판) 켤 때: 사비 엔진(Ollama)이 2초 안에 대답이 없으면 조용히 켬 ('ollama app.exe' → 없으면 'ollama.exe serve') · 그 뒤로는 위 확인이 알아서 계속 다시 붙음
$script:olChk = $null; $script:olStartAt = [DateTime]::MinValue
function Ollama-Kick {
  if ($Tier -eq 'low') { return }   # 최저 단계는 Ollama 없음
  try {
    $cts = New-Object System.Threading.CancellationTokenSource; $cts.CancelAfter(2000)
    $script:olChk = @{ t = $Http.GetAsync(([string]$S.localHost).TrimEnd('/') + '/api/version', $cts.Token); cts = $cts }
  } catch { $script:olChk = $null; Ollama-Start }
}
# (2026-11-13 대표 · 사용자 제보 '자체 연결 안 됨') 엔진이 Program Files 쪽에 깔린 경우도 찾음 · 쓰는 중에 엔진이 꺼져도 2분마다 다시 켜 봄
function Ollama-Dirs {
  $d = @(); foreach ($r in @($env:LOCALAPPDATA + '\Programs', $env:ProgramFiles, $env:ProgramW6432, ${env:ProgramFiles(x86)})) { if ($r) { $d += (Join-Path $r 'Ollama') } }
  return $d
}
function Ollama-Start {
  if (([DateTime]::Now - $script:olStartAt).TotalSeconds -lt 120) { return }
  $script:olStartAt = [DateTime]::Now
  try {
    foreach ($od in @(Ollama-Dirs)) { $app = Join-Path $od 'ollama app.exe'; if (Test-Path -LiteralPath $app) { Start-Process -FilePath $app -WindowStyle Hidden | Out-Null; Log ('사비 엔진(Ollama) 켜는 중 (ollama app · ' + $od + ')'); return } }
    $exe = $null; foreach ($od in @(Ollama-Dirs)) { $x = Join-Path $od 'ollama.exe'; if (-not $exe -and (Test-Path -LiteralPath $x)) { $exe = $x } }
    if (-not $exe) { $cmd = Get-Command 'ollama.exe' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($cmd) { $exe = $cmd.Source } }
    if ($exe) { Start-Process -FilePath $exe -ArgumentList 'serve' -WindowStyle Hidden | Out-Null; Log '사비 엔진(Ollama) 켜는 중 (ollama serve)' }
    else { Log '사비 엔진(Ollama)을 찾을 수 없음 (설치를 다시 해 주세요)' }
  } catch { Log "사비 엔진 켜기: $_" }
}
function Ollama-Tick {
  $c = $script:olChk; if (-not $c -or -not $c.t.IsCompleted) { return }
  $script:olChk = $null
  $ok = $false
  try { if ($c.t.Status -eq 'RanToCompletion') { $ok = $c.t.Result.IsSuccessStatusCode; $c.t.Result.Dispose() } } catch {}
  try { $c.cts.Dispose() } catch {}
  if (-not $ok) { Ollama-Start; foreach ($b in $script:BE) { if ($b.kind -eq 'ollama') { $b.probeAt = [DateTime]::Now.AddSeconds(-10) } } }
}
Ollama-Kick
foreach ($b in $script:BE) { Probe-Start $b $true }
# (2026-11-01) 모델이 번역 대신 지시문을 뱉었는지 — 화면에 넣지 않음
function Leak-Ko([string]$ko) { if ($ko -match '([가-힣A-Za-z]{2,}\S{0,3})(?:\s+\1){5,}') { return $true }; return ($ko -match '대괄호|지시문|번역문|번역기|JSON|아이템·퀘스트·주문|앞 대화|채팅방 ·|아래는 번역할|번역할 채팅|채팅 원문|너에게 하는 말|대답하지 말고|번역만 한다|원문이 한국어거나|lang[는은] ?KO|ko[는은] 원문') -or ($ko -match '\n\S{2,24}: ') }
function Is-Foreign([string]$t) {
  if (-not $t) { return $false }
  if ($t -match '[가-힣ㄱ-ㆎ]') { return $false }
  return ($t -match '\p{L}.*\p{L}')
}
# (2026-11-05) 한인 채널 krus 는 받는 말·보내는 말 모두 번역 안 함 (한국어 그대로 보냄)
function No-TrChan($cname) { return ([string]$cname) -match '(?i)(^|[^a-z])krus([^a-z]|$)' }
function Tr-Out($tg) { if (No-TrChan $tg.cname) { return $false }; return ((-not [bool]$S.pause) -and [bool]$S.tr[(TrCat $tg.t $tg.cname)]) }   # (2026-11-03) 보낼 때 번역할지 (번역 ON/OFF 버튼 반영)
function Want-Tr($rec) {
  if ($S.pause) { return $false }
  if (No-TrChan $rec.cname) { return $false }   # (2026-11-05) krus 채널은 원문 그대로   # (2026-11-03) 번역 잠깐 멈춤 → 원문 그대로
  $c = TrCat $rec.t $rec.cname
  return [bool]$S.tr[$c]
}
function In-Way($rec) { return 'in' }   # (공유판) 받는 말은 늘 사비 하나
# (2026-11-01) 앞 대화 함께 보기: 거래 채널만 빼고 같은 채널(귓속말은 같은 상대)의 바로 앞 3줄(3분 이내)을 참고로 같이 보냄
#  → 비꼬기·농담·누구한테 한 말인지 판단
$CtxBuf = @{}
function Ctx-Key($rec) {
  # (2026-11-01) 대도시 거래 채널만 빼고 전부 (귓속말은 상대별로 따로 기억)
  if ([string]$rec.t -eq 'EMOTE') { return $null }
  $c = TrCat $rec.t $rec.cname
  if ($c -eq 'trade') { return $null }
  if ($c -eq 'whisper') { return ('w:' + (Short $rec.sender)) }
  if ($c -eq 'otherch') { return ('ch:' + [string]$rec.cname) }
  return $c
}
function Ctx-Take($rec, [string]$p) {
  $k = Ctx-Key $rec; if (-not $k) { return '' }
  if (-not $CtxBuf[$k]) { $CtxBuf[$k] = New-Object System.Collections.ArrayList }
  $b = $CtxBuf[$k]; $now = [DateTime]::Now; $who = Short $rec.sender
  # ① 채팅방 바로 앞 3줄(3분 이내 · 대화 흐름) ② 같은 사람이 그 전에 한 말 2줄(5분 이내 · 그 사람 말의 이어짐)
  $recent = @($b | Where-Object { ($now - $_.at).TotalSeconds -le 180 } | Select-Object -Last 3)
  $mine = @($b | Where-Object { $_.who -eq $who -and ($now - $_.at).TotalSeconds -le 300 -and $recent -notcontains $_ } | Select-Object -Last 2)
  $t = [string]$p; if ($t.Length -gt 140) { $t = $t.Substring(0, 140) }
  [void]$b.Add(@{ at = $now; who = $who; s = ($who + ': ' + $t) }); while ($b.Count -gt 20) { $b.RemoveAt(0) }
  $out = @()
  if ($mine.Count -gt 0) { $out += ('(' + $who + '가 조금 전에 한 말)'); $out += @($mine | ForEach-Object { $_.s }) }
  if ($recent.Count -gt 0) { if ($mine.Count -gt 0) { $out += '(바로 앞 대화)' }; $out += @($recent | ForEach-Object { $_.s }) }
  return ($out -join "`n")
}
function Queue-In($L) {
  $p = Plain $L.rec.msg
  $ctx = [string]$L.ctx
  if (-not $ctx -and $Cache[$p]) { Done-In $L $Cache[$p]; return }
  $cx = ''; if ($ctx) { $cx = "`n[앞 대화 · 같은 채팅방 · 참고만 하고 이 줄들은 번역하지 말 것 · 비꼬기·농담·누구에게 한 말인지 판단에만 쓰고 맨 아래 원문 한 줄만 번역한다]`n" + $ctx }
  $task = Gem-Send ($SYS_IN + (Gloss-For $p) + (Slang-In $p) + $cx) (Pre-Fix $p) $false (In-Way $L.rec)
  if (-not $task) { Set-Sub $L $null '(번역 엔진 준비 중 - 이 줄은 원문 그대로)'; return }
  [void]$Pending.Add(@{ kind = 'in'; task = $task; L = $L; src = $p })
}
function Done-In($L, $res) {
  $lang = [string]$res.lang; $ko = [string]$res.ko
  if (-not $ko -or $lang -eq 'KO') { return }
  # (2026-10-31) 모델이 번역 대신 지시문 문장을 뱉는 경우(예: "대괄호 [ ] 안의 아이템…") → 버리고 원문 그대로 둠
  if (Leak-Ko $ko) { Dbg ("받은 번역 버림(지시문) · " + $ko); return }   # (2026-11-01) Wrap-Src 지시문("아래는 번역할 채팅 원문…")도 막음
  $r = $L.rec
  if ($LangOf.Count -ge 5000) { $LangOf.Clear() }   # (2026-10-25) 끝없이 커지지 않게
  $LangOf[$r.sender] = $lang
  $LangCat[(TrCat $r.t $r.cname)] = $lang
  Render-Main $L $ko
  Set-Sub $L $lang (Plain $r.msg)
  if ($L.feed) { Feed-Tr $L.feed $ko (Plain $r.msg) }
}
function Out-Lang($tg) {
  # (2026-10-26) 보낼 곳마다 고른 언어 · '자동' = 귓말은 그 사람이 쓰던 언어, 나머지는 그 곳에서 마지막에 말한 외국인 언어 (없으면 영어)
  $k = Out-Key $tg
  $v = Out-Pick $k
  if ($v -ne 'AUTO') { return $v }
  if ($tg -and $tg.t -match '^(BN_)?WHISPER$' -and $LangOf[$tg.name]) { return $LangOf[$tg.name] }
  if ($LangCat[$k]) { return $LangCat[$k] }
  return 'EN'
}

# ---------- 받은 기록 처리 ----------
$DbgFile = Join-Path $Dir 'translate-debug.log'
$script:dbgN = 0
function Dbg($m) { try { $script:dbgN++; if ($script:dbgN % 400 -eq 0 -and (Test-Path $DbgFile)) { Remove-Item $DbgFile -ErrorAction SilentlyContinue }; Add-Content -Encoding UTF8 $DbgFile ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) } catch {} }
function Handle($line) {
  $f = $line.Split("`t")
  $isReplay = ($f[0] -eq 'C' -and $f.Count -gt 12 -and $f[12] -eq '1')
  if ($f[0] -ne 'P' -and $f[0] -ne 'G' -and -not $isReplay) { Dbg ($line.Substring(0, [math]::Min(160, $line.Length))) }
  switch ($f[0]) {
    'P' {
      $state.off = $false
      $state.me = $f[1]; $state.realm = $f[2]; if ($f[3]) { $state.myHex = $f[3] }
      try { Tr-Follow $true } catch { Log "번역 켜짐 맞추기: $_" }   # (공유판) 게임 = 번역대화창 모드 → 프로그램도 켜짐
      $t = ($f[4] -eq '1')
      if ($t -ne $state.test) { $state.test = $t; Paint-Status }
      # (2026-11-01) 게임 대화창 설정 '글자 크기'를 번역창 글자 크기로 (같은 숫자 · 기본 12) · 바뀌었을 때만 다시 그림
      #  게임 쪽 값이 '바뀐 때'만 따라감 → 번역창 톱니에서 따로 바꾼 크기는 게임에서 다시 바꾸기 전까지 그대로
      try { $gz = 0; if ($f.Count -gt 6 -and [int]::TryParse([string]$f[6], [ref]$gz) -and $gz -ge 9 -and $gz -le 20 -and $gz -ne [int]$S.gameFz) { $S.gameFz = $gz; if ($gz -ne [int]$S.fz) { $S.fz = $gz; Redraw-All }; Save-Cfg } } catch { Log "대화창 글자 크기 맞추기: $_" }
    }
    'X' { $state.off = $true; if ($state.inputOn) { Exit-Input $false }; try { Tr-OffRec $f } catch { Log "번역 꺼짐 맞추기: $_" } }   # (공유판) 게임 = 기본 대화창 모드
    # (2026-10-25) 게임이 '입력칸 열어 줘'(Shift+Enter로 번역을 막 켰을 때) · '이 사람에게 귓말 답장'(가운데 귓말 이름 클릭)
    'I' { $state.wantInput = [DateTime]::Now }
    'Q' { $state.combat = ([string]$f[1] -eq '1'); $state.combatAt = [DateTime]::Now }
    'U' { $state.popup = ([string]$f[1] -eq '1') }   # (2026-11-03) 게임 확인 창이 떠 있음 → 가운데 파티 대화가 클릭 안 가로챔   # (2026-11-02) 게임: 전투 시작(1)·끝(0) → 가운데 파티 대화가 전투 중엔 휠·클릭 안 가로챔
    'L' { Lfg-Show $f }
    'F' {
      $Feed.geo = @{ x = [int]$f[1]; y = [int]$f[2]; w = [int]$f[3]; s = [double]::Parse($f[4], [Globalization.CultureInfo]::InvariantCulture); edit = ($f[5] -eq '1'); h = $(if ($f.Count -gt 6 -and $f[6]) { [int]$f[6] } else { 0 }); mv = ($f.Count -gt 9 -and [string]$f[9] -eq '1') }
      $fHold = ([DateTime]::Now -lt $script:feedHold)   # (2026-10-31) 번역창 메뉴에서 막 바꾼 값이 게임에 들어가기 전
      if ($f.Count -gt 7 -and $f[7] -and -not $fHold) { $Feed.mask = [string]$f[7] }   # (2026-10-26) 가운데에 띄울 종류 ('-' = 없음)
      if ($f.Count -gt 8 -and $f[8] -and -not $fHold) { $fz = 0.0; if ([double]::TryParse([string]$f[8], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$fz) -and $fz -gt 0) { $Feed.font = $fz } }   # (2026-10-27) 글자 크기 = 게임 대화창 설정 '파티클 글자'
      if ($Feed.geo.edit -and $Feed.win) { $Feed.sp.Children.Clear(); $Feed.list.Clear(); $Feed.win.Hide() }
      #  (2026-11-13 대표) 게임 대화창 톱니에서 켜고 끈 것도 이 프로그램이 따라감 · 마지막에 바꾼 쪽이 이김 (여기서 막 바꿨으면 30초 동안은 게임 쪽 답을 기다림)
      if ($f.Count -gt 10 -and $f[10] -and -not $fHold) { $gOn = ([string]$f[10] -eq '1'); if ($gOn -ne (-not [bool]$S.feedOff) -and ([DateTime]::Now - $script:feedSyncAt).TotalSeconds -gt 30) { $S.feedOff = -not $gOn; Save-Cfg; Pills-Paint; try { Cen-Moved } catch {}; if ($Pop.IsOpen -and $script:popMode -eq 'tr') { try { Build-Menu } catch {} } } }
      try { Feed-Sync $fHold } catch { Log "파티글 자리 맞추기: $_" }
      Feed-Make; Feed-Place
    }
    'N' {   # (2026-10-31) 게임: 들어가 있는 채널(번호=이름;…) · 서버 채널 이름(;…)
      $jl = New-Object System.Collections.ArrayList
      foreach ($p0 in ([string]$f[1]).Split(';')) { if ($p0 -match '^(\d+)=(.+)$') { [void]$jl.Add(@{ n = $Matches[1]; name = $Matches[2] }); $ChanNames[$Matches[1]] = $Matches[2] } }
      $sl = @(); if ($f.Count -gt 2) { $sl = @(([string]$f[2]).Split(';') | Where-Object { $_ }) }
      $script:Chans = @{ joined = $jl; server = $sl }
      if ($Pop.IsOpen -and $script:popMode -eq 'set') { Build-SetMenu }
    }
    'O' { try { $S.cenChOff = (([string]$f[1]) -replace ',', '|'); Save-Cfg; if ($Pop.IsOpen -and $script:popMode -eq 'set') { Build-SetMenu } } catch { Log "채널별 가운데: $_" } }   # (2026-11-09) 게임 대화창 톱니에서 바꾼 '가운데 파티글 채널별 끄기'
    'T' {   # (2026-11-09) 게임 기본대화창의 탭 설정 (번호 · 내용) → 더 새것이면 받고, 번역창이 더 새것이면 게임에 보냄
      try {
        $gv = [int64]$f[1]; $mv = [int64]$S.tabsVer
        if ($gv -gt $mv) { $script:tabsMine = $false; Tabs-Apply ([string]$f[2]); $S.tabsVer = $gv; Save-Cfg; Build-Tabs; Select-Tab ([string]$S.tab); if ($Pop.IsOpen -and $script:popMode -eq 'tab') { $Pop.IsOpen = $false }; Log '게임 대화창 탭 설정 받음' }
        elseif ($gv -lt $mv) {
          # (2026-11-09 공유판 제보) 내용이 같으면 번호만 맞추고 안 보냄 · 보내는 건 1분에 한 번 · 내가 입력 중이면 안 보냄
          #  (게임에 명령어를 대신 치는 동안 창이 멈춘 것처럼 보이고 채팅창에 명령어가 쭉쭉 쳐지던 것)
          $c0 = $S.ctabs; $t0 = $S.tabf; $mine = Tabs-Pack
          $theirs = ''; try { Tabs-Apply ([string]$f[2]); $theirs = Tabs-Pack } catch {}
          $S.ctabs = $c0; $S.tabf = $t0
          if ($mine -ceq $theirs) { $S.tabsVer = $gv; Save-Cfg; $script:tabsMine = $false }
          # (2026-11-11 공유판 제보: 게임에서 만든 탭이 사라지고, 새 탭 이름을 바꾸려 하면 창이 바로 꺼짐)
          #  번역기를 다시 켜면(업데이트 등) 번역창의 예전 탭 설정이 게임 쪽 새 설정을 덮어쓰던 것
          #  → 이번에 켠 뒤 번역창에서 탭을 바꾼 적이 없으면 게임 쪽 설정을 그대로 받음 (게임이 기준)
          elseif (-not $script:tabsMine -and -not ($Pop.IsOpen -and $script:popMode -eq 'tab')) { Tabs-Apply ([string]$f[2]); $S.tabsVer = $gv; Save-Cfg; Build-Tabs; Select-Tab ([string]$S.tab); if ($Pop.IsOpen -and $script:popMode -eq 'tab') { $Pop.IsOpen = $false }; Log '게임 대화창 탭 설정 받음 (게임 기준)' }
          elseif (-not $state.inputOn -and (-not $script:tabsPushAt -or ([DateTime]::Now - $script:tabsPushAt).TotalSeconds -gt 60)) { $script:tabsPushAt = [DateTime]::Now; Tabs-Push }
        }
      } catch { Log "탭 맞추기: $_" }
    }
    'R' { if ($f[1]) { $state.target = Tell-Tg $f[1]; $state.wantInput = [DateTime]::Now } }
    'J' { if ($f[1]) { $state.target = @{ t = [string]$f[1] }; $state.lastTarget = $state.target; $S.lastTarget = $state.target; try { Paint-Target } catch {} } }   # (2026-10-31) 파티에 들어가면 입력칸 = 파티
    'E' { $state.editing = ($f[1] -eq '1') }
    'Y' {   # (2026-10-30) 게임 메모장 '복사' → PC 클립보드 (나눠서 옴: 번호 · 순서 · 전체 개수 · 내용)
      try {
        $cid = [string]$f[1]; $i = [int]$f[2]; $n = [int]$f[3]; $tx = $(if ($f.Count -gt 4) { ($f[4..($f.Count - 1)] -join ' ') } else { '' })
        if (-not $script:CopyBuf -or $script:CopyBuf.id -ne $cid) { $script:CopyBuf = @{ id = $cid; n = $n; parts = @{} } }
        $script:CopyBuf.parts[$i] = $tx
        if ($script:CopyBuf.parts.Count -ge $n) {
          $all = (1..$n | ForEach-Object { [string]$script:CopyBuf.parts[$_] }) -join ''
          $all = $all.Replace([string][char]31, "`r`n")
          [System.Windows.Clipboard]::SetText($all)
          $script:CopyBuf = $null
          Dbg ("메모 복사 → 클립보드 {0}자" -f $all.Length)
          [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = '메모를 PC 클립보드에 복사했어요 (Ctrl+V로 붙여넣기)' })
        }
      } catch { Log "메모 복사: $_" }
    }
    'H' { if ($f.Count -gt 2) { Link-Add $f[1] (($f[2..($f.Count - 1)]) -join "`t") } }   # (2026-10-27) 게임에서 시프트 클릭한 링크
    'K' { $state.kb = ($f[1] -eq '1'); if ($state.kb -and $state.hkE) { [void][FTR]::HotkeyEnter($script:hwnd, $false); $state.hkE = $false } }
    'V' {
      # (2026-10-30) 대화창을 숨겨 둔 상태에서 우리가 글을 보낼 때(게임 입력칸을 잠깐 씀) 게임이 대화창을 잠깐 보여 주는 것은 무시 → 왼쪽 창이 번쩍 안 뜨게
      $v = ($f[1] -eq '1')
      if ($v -and -not $state.vis -and $state.sentAt -and ([DateTime]::Now - $state.sentAt).TotalSeconds -lt 6) { $state.visHeld = $true }
      else { $state.vis = $v; $state.visHeld = $false }
    }
    'G' {
      $gv = (($f[1..($f.Count - 1)] -join ' ').Trim()) -split '\s+'
      $state.geo = @{ x = [int]$gv[0]; y = [int]$gv[1]; w = [int]$gv[2]; h = [int]$gv[3]; s = [double]::Parse($gv[4], [Globalization.CultureInfo]::InvariantCulture) }
      Place-Win
    }
    'S' {
      $tx = ($f[2..($f.Count - 1)] -join ' ')
      # 플레이어 대화 줄(이름 링크에 대화 번호·종류가 들어 있음)은 'C'로 따로 와서 여기선 건너뜀 (두 번 뜨는 것 방지)
      if ($tx -match '\|H(BN)?player:[^|]*:\d+:[A-Z_0-9]+') { return }
      [void](Add-Line @{ kind = 'S'; col = $f[1]; text = $tx })
      # (2026-11-13) 파티·공대가 아니거나 귓말 상대가 없어서 게임이 안 보낸 글은 '안 보여서 한 번 더 보냄'을 하지 않음 (같은 오류가 두 번 뜨던 것)
      if ($script:echoW -and $tx -match '속해 있지 않습니다|찾을 수 없습니다|접속 중이 아닙니다|not in a (party|raid)|No player named|is not online|not currently playing') { $script:echoW = $null; Dbg ('보낸 글 확인 끝: 게임이 안 보냄 (' + $tx + ')') }
    }
    'C' {
      $rec = @{ kind = 'C'; t = $f[1]; cnum = $f[2]; cname = $f[3]; sender = $f[4]; cls = $f[5]; col = $f[6]; msg = $f[7]; me = ($f[8] -eq '1'); test = ($f[9] -eq '1') }
      # (2026-10-27) 대화 번호(접속번호:줄번호)로 같은 줄은 한 번만 · 다시 보낸 줄 중 못 받았던 것만 순서 자리에 끼움
      $before = $null
      if ($f.Count -gt 11 -and $f[11]) {
        $rec.sid = [string]$f[11]; $no = 0; [void][int]::TryParse([string]$f[10], [ref]$no); $rec.no = $no
        $key = $rec.sid + ':' + $rec.no
        if ($SeenC.Contains($key)) { return }
        if ($SeenC.Count -gt 5000) { $SeenC.Clear() }
        [void]$SeenC.Add($key)
        if ($isReplay) {
          Dbg ('다시 받음(놓쳤던 대화): ' + $line.Substring(0, [math]::Min(140, $line.Length)))
          foreach ($o in $LineList) { if ($o.rec.sid -eq $rec.sid -and $o.rec.no -gt $rec.no) { $before = $o; break } }
        }
      }
      # (2026-10-31) 내가 보낸 글이 게임에서 돌아오면: 미리 띄워 둔 줄을 진짜 줄로 바꿈
      if ($rec.me -and -not $isReplay) {
        $MyCol[$rec.t] = $rec.col; if ($rec.cls) { $MyCol['cls_' + $rec.t] = $rec.cls }
        $pk = (Plain $rec.msg).Trim(); $LL = $LocalEcho[$pk]
        if ($LL) {
          $LocalEcho.Remove($pk)
          $LL.rec = $rec; $LL.tab = TabOf $rec.t; $LL.cat = TrCat $rec.t $rec.cname; if ($LL.cat -eq 'other') { $LL.cat = 'sys' }
          $LL.chk = $(if ([string]$rec.t -eq 'CHANNEL') { Ch-Key $rec.cname } else { '' })
          Build-Line $LL; Apply-TabTo $LL
          try { [void](Ctx-Take $rec $pk) } catch {}   # (2026-11-01) 내가 보낸 말도 앞 대화로 기억
          if ((Feed-Want $rec) -and -not $state.off) { $LL.feed = Feed-Add $rec }
          try { Echo-Seen $pk } catch {}
          return
        }
      }
      if (-not $rec.me -and [string]$rec.t -match '^(SAY|CHANNEL)$') { try { $rec.call = Name-Call ([string]$rec.msg) } catch {} }
      $L = Add-Line $rec $before
      $p = Plain $rec.msg
      try { $L.ctx = Ctx-Take $rec $p } catch {}   # (2026-11-01) 앞 대화 기억 (이 줄을 넣기 전 3줄이 이 줄의 참고)
      if ((Feed-Want $rec) -and -not $state.off -and -not $isReplay) { $L.feed = Feed-Add $rec }
      if ($rec.test) { $FakeNames[$rec.sender] = $true }
      if ($rec.t -eq 'CHANNEL' -and $rec.cnum) { $ChanNames[$rec.cnum] = $rec.cname; try { if (-not ($S.chanNames -is [hashtable])) { $S.chanNames = @{} }; $S.chanNames[[string]$rec.cnum] = [string]$rec.cname } catch {} }   # (2026-10-31) 번역창을 다시 켜도 채널 이름 기억
      if ($rec.t -match '^BN_WHISPER' -and $rec.cnum -match '^\d+$') { $BnId[[string]$rec.sender] = $rec.cnum }   # (2026-10-30) 배틀넷 귓말: 게임이 보낸 배틀넷 번호 기억
      if ($rec.t -match '^(BN_)?WHISPER$' -and -not $rec.me) { $state.lastWhisper = $rec.sender }
      if ($rec.me) {
        try { Echo-Seen $p } catch {}
        $ko = $Sent[$p.Trim()]
        if ($ko) { Set-Sub $L '보냄' $ko }
        return
      }
      if ((Want-Tr $rec) -and (Is-Foreign $p)) {
        Queue-In $L
        if (-not $isReplay) {
          $state.lastForeign = $(if ($rec.t -match 'WHISPER') { Tell-Tg $rec.sender } else { @{ t = $rec.t; name = $rec.sender; cnum = $rec.cnum; cname = $rec.cname } })
          $state.lastForeignAt = [DateTime]::Now
        }
      }
      if ($rec.t -match '^(BN_)?WHISPER$' -and -not $state.inputOn) { $Medals['whisper'].glow.Opacity = $(if ($S.tab -ne 'whisper') { 0.9 } else { 0 }) }
    }
  }
}
function Paint-Status {
  if ($state.test) { $TrLab.Text = '테스트 모드'; $TrLab.Foreground = Br '#FFFF9E4D' }
  elseif ($S.pause) { $TrLab.Text = '' }
  else {
    # 평소엔 안 보임 · 사비가 준비 중(꺼짐)·모델 없음·사전 파일 오류일 때만 표시
    $t = ''; $col = $MUTED; $b0 = $(if ($script:BE.Count -gt 0) { $script:BE[0] } else { $null })
    if ($b0 -and $b0.kind -eq 'ollama' -and ($b0.st -eq 'down' -or $b0.noModel)) { $t = $(if ($b0.noModel) { '번역 모델 없음 (다시 설치해 주세요)' } else { '번역 엔진 준비 중…' }); $col = Br '#FFFFB36B' }
    if ($script:cfgErrAt -ne [DateTime]::MinValue -and ([DateTime]::Now - $script:cfgErrAt).TotalSeconds -lt 30) { $t = '사전 파일 오류 (로그 확인)'; $col = Br '#FFFF7A5C' }
    $TrLab.Text = $t; $TrLab.Foreground = $col
  }
}

# ---------- 보낼 곳 · 입력 ----------
function Target-Info($tg) {
  if (-not $tg) { $tg = @{ t = 'SAY' } }
  $c = $CHT[$tg.t]; if (-not $c) { $c = $CHT['SAY'] }
  return $c
}
# (2026-10-31) 저장해 둔 마지막 채널(예: 예전 '1. 채널')의 이름을 지금 아는 이름으로 다시 맞춤 → 공개 채널인데 '번역 안 함'으로 나가던 것 고침
function Fix-ChanTg($tg) {
  if ($tg -and $tg.t -eq 'CHANNEL' -and $tg.cnum) { $n = Chan-Name ([string]$tg.cnum); if ($n -and $n -ne '채널') { $tg.cname = $n } }
}
function Paint-Target {
  $tg = $state.target
  Fix-ChanTg $tg
  $c = Target-Info $tg
  $chn = @{ say = '일반'; yell = '외침'; emote = '감정'; party = '파티'; raid = '공대'; rw = '경보'; guild = '길드'; officer = '관리'; whisper = '귓말'; bn = '귓말'; channel = '채널' }[[string]$c[1]]; if (-not $chn) { $chn = $c[0] }
  # (2026-11-03) 시안대로 보낼 곳 버튼 = 채널 색 옅은 배경 + 채널 색 글씨 + ▾
  $hx = @{ say = 'ffffff'; yell = 'ff4040'; emote = 'ff8040'; party = 'aaaaff'; raid = 'ff7f00'; rw = 'ff4809'; guild = '40ff40'; officer = '40c040'; whisper = 'ff80ff'; bn = '00fff6'; channel = 'ffc0c0' }[[string]$c[1]]; if (-not $hx) { $hx = 'ffffff' }
  $cc = [System.Windows.Media.ColorConverter]::ConvertFromString('#' + $hx)
  $ChM.text.Text = $chn + ' ▾'; $ChM.bg.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(38, $cc.R, $cc.G, $cc.B))
  $ChM.text.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb([byte][math]::Min(255, $cc.R + 15), [byte][math]::Min(255, $cc.G + 15), [byte][math]::Min(255, $cc.B + 15)))
  if ($tg -and $tg.t -match '^(BN_)?WHISPER$') { $Who.Text = (Short $tg.name) + ' → '; $Who.Visibility = 'Visible' }
  elseif ($tg -and $tg.t -eq 'CHANNEL') { $Who.Text = ("{0}. {1} → " -f $tg.cnum, ([string]$tg.cname -replace '\s*-\s.*$', '')); $Who.Foreground = HexBr 'ffc0c0'; $Who.Visibility = 'Visible' }
  else { $Who.Text = ''; $Who.Visibility = 'Collapsed' }
  if ($tg -and $tg.t -match '^(BN_)?WHISPER$') { $Who.Foreground = HexBr 'ff80ff' }
  $wantTr = $tg -and (Tr-Out $tg)
  if ($wantTr) { $lg = Out-Lang $tg; $sh = $LANGSHORT[$lg]; if (-not $sh) { $sh = $lg }; $Lang.Text = '한 → ' + $sh } else { $Lang.Text = '번역 안 함' }
}
function Cycle-Target {
  $order = @(@{ t = 'SAY' }, @{ t = 'PARTY' }, @{ t = 'RAID' }, @{ t = 'INSTANCE_CHAT' }, @{ t = 'GUILD' })
  if ($state.lastForeign -and $state.lastForeign.t -match '^(BN_)?WHISPER$') { $order += $state.lastForeign }
  if ($state.lastForeign -and $state.lastForeign.t -eq 'CHANNEL') { $order += $state.lastForeign }
  $cur = $state.target; $i = -1
  for ($k = 0; $k -lt $order.Count; $k++) { if ($cur -and $order[$k].t -eq $cur.t -and $order[$k].name -eq $cur.name) { $i = $k } }
  $state.target = $order[($i + 1) % $order.Count]
  Paint-Target; Kick-Preview
}
function Enter-Input {
  $fg = [FTR]::Foreground(); if ($fg -ne $script:hwnd) { $state.prevFg = $fg }
  if (-not $state.target) {
    # (2026-10-30) 마지막으로 쓴 채널 그대로 (예전엔 최근 외국어 글(파티 모집 등) 채널로 먼저 바뀌어서 불편했음)
    if ($state.lastTarget) { $state.target = $state.lastTarget }
    elseif ($S.lastTarget -is [hashtable] -and $S.lastTarget.t) { $state.target = $S.lastTarget }   # 번역기를 다시 켠 뒤에도 기억
    elseif ($state.lastForeign -and ([DateTime]::Now - $state.lastForeignAt).TotalMinutes -lt 3) { $state.target = $state.lastForeign }
    else { $state.target = @{ t = 'PARTY' } }
  }
  $state.inputOn = $true
  $ih = $script:hwnd; $iw = $win
  try { if (CIn-Open) { $ih = $CIn.hwnd; $iw = $CIn.win } } catch { Log "가운데 입력칸: $_" }
  [FTR]::NoActivate($ih, $false)
  [FTR]::ClickThrough($ih, $false)
  Paint-Target
  [FTR]::Focus($ih)
  $iw.Activate() | Out-Null
  $Inp.Focus() | Out-Null
  [System.Windows.Input.Keyboard]::Focus($Inp) | Out-Null
}
function Exit-Input([bool]$back) {
  $state.inputOn = $false; $state.offAt = $null
  $state.idle = 99   # (2026-10-27) 보내기·취소 뒤에도 판이 바로 사라짐 (마우스가 판 위에 있으면 그대로 보임)
  $Inp.Text = ''; $PrevG.Visibility = 'Collapsed'
  if ($state.target) { $state.lastTarget = $state.target; $S.lastTarget = $state.target }
  $state.target = $null
  [FTR]::NoActivate($script:hwnd, $true)
  try { CIn-Close } catch {}
  if ($back) { $w = [FTR]::FindWow(); if ($w -ne [IntPtr]::Zero) { [FTR]::Focus($w); Start-Sleep -Milliseconds 40; Tr-Signal $false } }
}
# 와우처럼 /s /g /p /ra /i /w 이름 /r /숫자 + 띄어쓰기 → 보낼 곳이 바뀌고 앞 글자는 지워짐
$ChanNames = @{}
$FakeNames = @{}
# 한글 자판으로 친 명령어(/ㄴ, /ㅔ, /ㅎ ...)를 영어 자판 글자로 (와우처럼)
$KOKEY = @{ 'ㅂ' = 'q'; 'ㅈ' = 'w'; 'ㄷ' = 'e'; 'ㄱ' = 'r'; 'ㅅ' = 't'; 'ㅛ' = 'y'; 'ㅕ' = 'u'; 'ㅑ' = 'i'; 'ㅐ' = 'o'; 'ㅔ' = 'p'
  'ㅁ' = 'a'; 'ㄴ' = 's'; 'ㅇ' = 'd'; 'ㄹ' = 'f'; 'ㅎ' = 'g'; 'ㅗ' = 'h'; 'ㅓ' = 'j'; 'ㅏ' = 'k'; 'ㅣ' = 'l'
  'ㅋ' = 'z'; 'ㅌ' = 'x'; 'ㅊ' = 'c'; 'ㅍ' = 'v'; 'ㅠ' = 'b'; 'ㅜ' = 'n'; 'ㅡ' = 'm'
  'ㅃ' = 'Q'; 'ㅉ' = 'W'; 'ㄸ' = 'E'; 'ㄲ' = 'R'; 'ㅆ' = 'T'; 'ㅒ' = 'O'; 'ㅖ' = 'P'
  'ㅘ' = 'hk'; 'ㅙ' = 'ho'; 'ㅚ' = 'hl'; 'ㅝ' = 'nj'; 'ㅞ' = 'np'; 'ㅟ' = 'nl'; 'ㅢ' = 'ml'
  'ㄳ' = 'rt'; 'ㄵ' = 'sw'; 'ㄶ' = 'sg'; 'ㄺ' = 'fr'; 'ㄻ' = 'fa'; 'ㄼ' = 'fq'; 'ㄽ' = 'ft'; 'ㄾ' = 'fx'; 'ㄿ' = 'fv'; 'ㅀ' = 'fg'; 'ㅄ' = 'qt' }
$CHO = @('ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ')
$JUNG = @('ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ')
$JONG = @('','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ','ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ','ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ')
function Ko-Keys([string]$w) {
  # 이미 낱말로 쓰는 한글 명령어(/길, /파, /귓 ...)는 그대로 둠
  if ($w -match '^(말|일반|외|외침|파|파티|길|길드|관|관리자|공|공대|공격대|경보|인|인던|답|답장|귓|귓말)$') { return $w }
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $w.ToCharArray()) {
    $c = [int]$ch
    if ($c -ge 0xAC00 -and $c -le 0xD7A3) {
      $i = $c - 0xAC00; $jo = $i % 28; $ju = [math]::Floor($i / 28) % 21; $ch0 = [math]::Floor($i / 588)
      foreach ($j in @($CHO[$ch0], $JUNG[$ju], $JONG[$jo])) { if ($j) { [void]$sb.Append($KOKEY[$j]) } }
    } elseif ($KOKEY.ContainsKey([string]$ch)) { [void]$sb.Append($KOKEY[[string]$ch]) }
    else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}
function Parse-Slash {
  $t0 = $Inp.Text
  if (-not $t0.StartsWith('/')) { return $false }
  $m = [regex]::Match($t0, '^/(\S+) (.*)$', 'Singleline'); if (-not $m.Success) { return $false }
  $cmd = (Ko-Keys $m.Groups[1].Value).ToLower(); $rest = $m.Groups[2].Value; $tg = $null
  switch -Regex ($cmd) {
    '^(s|say|말|일반)$' { $tg = @{ t = 'SAY' } }
    '^(y|yell|sh|shout|외|외침)$' { $tg = @{ t = 'YELL' } }
    '^(p|party|파|파티)$' { $tg = @{ t = 'PARTY' } }
    '^(g|guild|길|길드)$' { $tg = @{ t = 'GUILD' } }
    '^(o|officer|관|관리자)$' { $tg = @{ t = 'OFFICER' } }
    '^(ra|raid|공|공대|공격대)$' { $tg = @{ t = 'RAID' } }
    '^(rw|경보)$' { $tg = @{ t = 'RAID_WARNING' } }
    '^(i|instance|인|인던)$' { $tg = @{ t = 'INSTANCE_CHAT' } }
    '^(r|reply|답|답장)$' { if ($state.lastWhisper) { $tg = Tell-Tg $state.lastWhisper } }   # (2026-10-30) 배틀넷 귓말에도 답장
    '^(w|whisper|t|tell|귓|귓말)$' {
      $m2 = [regex]::Match($rest, '^(\S+) (.*)$', 'Singleline')
      if (-not $m2.Success) { return $false }
      $tg = Tell-Tg $m2.Groups[1].Value; $rest = $m2.Groups[2].Value
    }
    '^\d+$' { $tg = @{ t = 'CHANNEL'; cnum = $cmd; cname = (Chan-Name $cmd) } }
  }
  if (-not $tg) { return $false }
  $state.target = $tg
  $Inp.Text = $rest; $Inp.CaretIndex = $rest.Length
  Paint-Target
  return $true
}
$Inp.Add_TextChanged({
  if (Parse-Slash) { return }
  $PhT.Visibility = $(if ($Inp.Text) { 'Collapsed' } else { 'Visible' }); Kick-Preview
})
$PrevTimer = New-Object Windows.Threading.DispatcherTimer
$PrevTimer.Interval = [TimeSpan]::FromMilliseconds(650)
function Kick-Preview { $PrevTimer.Stop(); if ($Inp.Text.Trim() -and -not $Inp.Text.StartsWith('/')) { $PrevTimer.Start() } else { $PrevG.Visibility = 'Collapsed' } }
$PrevTimer.Add_Tick({
  $PrevTimer.Stop()
  $txt = $Inp.Text.Trim(); $tg = $state.target
  if ($txt -and $tg -and (Tr-Out $tg)) { $lq = Laugh-Out $txt; if ($lq) { Set-Prev ('→  ' + $lq); $PrevG.Visibility = 'Visible'; return } }
  if (-not $txt -or -not $tg -or -not (Tr-Out $tg) -or $txt -notmatch '[가-힣]') { $PrevG.Visibility = 'Collapsed'; return }
  $lg = Out-Lang $tg
  if ($state.prevText -eq $txt -and $state.prevLang -eq $lg -and $state.prevOut) { return }
  $task = Gem-Send ((Sys-Out $lg $txt) + (Link-Rule (Link-Tok $txt)) + (Slang-Out $txt)) (Link-Tok $txt) $false 'out'
  if ($task) { [void]$Pending.Add(@{ kind = 'prev'; task = $task; src = $txt; lang = $lg }) }   # (2026-10-30) '번역 중…' 글씨는 안 띄움 (요청) · 번역이 오면 바로 보임
})
$Inp.Add_PreviewKeyDown({ param($snd, $e)
  if ($e.Key -eq 'Escape') { Exit-Input $true; $e.Handled = $true; return }
  if ($e.Key -eq 'Tab') { Cycle-Target; $e.Handled = $true; return }
  if ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') {
    $e.Handled = $true
    if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) { }
    Do-Send
  }
})
function Prefix-For($tg) {
  $c = Target-Info $tg
  # 테스트 모드의 가짜 외국인은 진짜 사람이 아니라서, 그 사람에게 가는 귓말은 내 캐릭에게로
  if ($tg.t -eq 'WHISPER' -and $FakeNames[$tg.name] -and $state.me) { return "/w $($state.me) " }
  # 테스트 모드: 파티·공대·인던·길드는 실제로 안 들어가 있을 수 있어서 내 캐릭에게 귓말로 (일반 대화·외침·채널은 진짜로 나감)
  if ($state.test -and $state.me -and $tg.t -match '^(PARTY|RAID|RAID_WARNING|INSTANCE_CHAT|GUILD|OFFICER)$') { return "/w $($state.me) " }
  switch ($tg.t) {
    'WHISPER' { $n = $tg.name; if ($state.test -and $state.me) { $n = $state.me }; return "/w $n " }
    'CHANNEL' { return "/$($tg.cnum) " }
    'BN_WHISPER' { return "/ntbn $($tg.bn) " }   # (2026-10-30) 배틀넷 귓말: 게임 애드온이 배틀넷 번호로 보냄
    default { return $c[2] }
  }
}
# (2026-10-26) 한글 문장 없이 초성(ㅋㅋ·ㅇㅇ·ㄱㄱ·ㅠㅠ 등)만 (또는 영어+초성) 친 채팅은 제미나이에 안 보내고 바로 바꿈 (비용 0 · 지연 0)
#  ㅋ 1~3개 = lol · 4개 이상 = lmao · ㅎ = haha · ㅇㅇ = yep · ㄱㄱ = go go ... (예: "ok ㅋㅋ" → "ok lol")
#  완성된 한글이 있거나 모르는 초성이 섞이면 원래대로 (번역기/원문 그대로)
$JAMO_MAP = @{ 'ㅅㄱ'='gg'; 'ㄱㅅ'='ty'; 'ㄳ'='ty'; 'ㅇㅋ'='ok'; 'ㅈㅅ'='sry'; 'ㅊㅋ'='gz'; 'ㅎㅇ'='hi'; 'ㅂㅂ'='bye'; 'ㅂㅇ'='bye'; 'ㄹㅇ'='fr'; 'ㅇㅈ'='true'; 'ㅁㄹ'='idk'; 'ㄱㅊ'='np' }
$JAMO_RX = New-Object Text.RegularExpressions.Regex('ㅅㄱㅇ+|ㅅㄱ|ㄱㅅ|ㄳ|ㅇㅋ|ㅈㅅ|ㅊㅋ|ㅎㅇ|ㅂㅂ|ㅂㅇ|ㄹㅇ|ㅇㅈ|ㅁㄹ|ㄱㅊ|[ㅋㅎ]+|ㅇ+|ㄱ+|ㄴ+|[ㅠㅜ]+|ㄷ+')
function Laugh-Out([string]$t) {
  if (-not $t -or $t -match '[가-힣]' -or $t -notmatch '[ㄱ-ㅎㅏ-ㅣ]') { return '' }
  $o = $JAMO_RX.Replace($t, { param($m)
    $v = $m.Value; $r = $JAMO_MAP[$v]
    if (-not $r) {
      if ($v -match '^ㅅㄱㅇ+$') { $r = 'gg' }
      elseif ($v -match '^[ㅋㅎ]+$') { $k = ([regex]::Matches($v, 'ㅋ')).Count; if ($k -eq 0) { $r = 'haha' } elseif ($k -ge 4) { $r = 'lmao' } else { $r = 'lol' } }
      elseif ($v -match '^ㅇ+$') { $r = 'yep' }
      elseif ($v -match '^ㄱ+$') { if ($v.Length -ge 2) { $r = 'go go' } else { $r = 'go' } }
      elseif ($v -match '^ㄴ+$') { $r = 'nope' }
      elseif ($v -match '^[ㅠㅜ]+$') { $r = 'T_T' }
      elseif ($v -match '^ㄷ+$') { $r = 'omg' }
    }
    ' ' + $r + ' ' })
  if ($o -match '[ㄱ-ㅎㅏ-ㅣ]') { return '' }
  $o = ($o -replace '\s+', ' ') -replace ' +([!?.,~])', '$1'
  return $o.Trim()
}
# ---------- (2026-10-27) 아이템 링크: 번역창에 쓰는 중 게임에서 시프트 클릭 → 입력줄에 [이름] ----------
#  번역은 [이름] 자리를 {L번호}로 바꿔 보내 링크를 건드리지 않게 하고, 게임엔 {fkl번호}로 붙여 넣으면 툴킷이 진짜 링크로 바꿈
$LinkFull = @{}; $LinkByName = @{}
function Link-Name([string]$full) { $m = [regex]::Match($full, '\|h(\[[^\]|]*\])\|h'); if ($m.Success) { return $m.Groups[1].Value }; return '' }
function Link-Add($id, [string]$full) {
  $id = [string]$id; $nm = Link-Name $full
  if (-not $id -or -not $nm) { return }
  $LinkFull[$id] = $full; $LinkByName[$nm] = $id
  $recent = $state.offAt -and (([DateTime]::Now - $state.offAt).TotalSeconds -lt 30)
  if (-not ($state.inputOn -or $Inp.Text -or $recent)) { return }   # 번역창에 쓰는 중이 아니면 무시 (게임과 똑같이)
  $t = $Inp.Text
  $c = $(if ($state.inputOn) { $Inp.CaretIndex } else { [int]$state.caret })
  $c = [math]::Min([math]::Max(0, $c), $t.Length)
  $ins = $nm; if ($c -gt 0 -and $t[$c - 1] -ne ' ') { $ins = ' ' + $ins }; if ($c -ge $t.Length -or $t[$c] -ne ' ') { $ins += ' ' }
  $Inp.Text = $t.Insert($c, $ins)
  if (-not $state.inputOn) { Enter-Input }
  $Inp.CaretIndex = $c + $ins.Length
}
# 게임(툴킷)에 '번역창에 쓰는 중'(Ctrl+F11) / '끝'(Ctrl+F12) 신호 · 와우가 앞에 있을 때만 · 사용자가 누르고 있는 Ctrl은 건드리지 않음
function Tr-Signal([bool]$on) {
  try {
    $w = [FTR]::FindWow(); $front = ($w -ne [IntPtr]::Zero -and [FTR]::Foreground() -eq $w)
    Dbg ("쓰는 중 신호 {0} · 와우 앞 {1}" -f $on, $front)
    if (-not $front) { return }
    $vk = [byte]$(if ($on) { 0x7A } else { 0x7B })
    $held = ([FTRK.Keys]::GetAsyncKeyState(0x11) -band 0x8000) -ne 0
    if (-not $held) { [FTRK.Kb]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero) }
    [FTRK.Kb]::keybd_event($vk, 0, 0, [UIntPtr]::Zero); [FTRK.Kb]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
    if (-not $held) { [FTRK.Kb]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero) }
  } catch { Log "신호 키: $_" }
}
function Link-Tok([string]$t) { foreach ($k in $LinkByName.Keys) { $t = $t.Replace($k, '{L' + $LinkByName[$k] + '}') }; return $t }
function Link-Show([string]$t) { foreach ($k in $LinkByName.Keys) { $t = $t.Replace('{L' + $LinkByName[$k] + '}', $k) }; return $t }
function Link-Game([string]$src, [string]$out) {
  # 번역이 링크 자리를 빼먹었으면 끝에 붙임
  foreach ($m in [regex]::Matches($src, '\{L(\d+)\}')) { if (-not $out.Contains($m.Value)) { $out = $out.TrimEnd() + ' ' + $m.Value } }
  return [regex]::Replace($out, '\{L(\d+)\}', '{fkl$1}')
}
function Link-Rule([string]$t) { if ($t -match '\{L\d+\}') { return "`n- {L1}처럼 중괄호로 된 표시는 아이템 링크 자리다. 번역하지 말고 글자 그대로 알맞은 자리에 둔다." }; return '' }
# (2026-11-07) 파티찾기·거래 광고(LFM·LFG·LF·WTS·WTB가 들어간 글)는 LFM·LFG·던전 줄임말·DPS를 대문자로 (북미 광고 관례)
$AdDung = 'RFC|WC|DM|VC|SFK|BFD|STOCKS|GNOMER|GNOMERE?GAN|RFK|SM|GY|LIB|ARM|ARMS|CATH|RFD|ULDA|ZF|MARA|ST|BRD|LBRS|UBRS|SCHOLO|STRAT|UDSTRAT|MC|ONY|ZG|BWL|AQ|AQ20|AQ40|NAXX|RAMPS|BF|SH|SP|UB|SV|MT|AC|SETH|SL|OHB|BM|MECH|BOT|ARC|MGT|KARA|GRUUL|MAG|SSC|TK|ZA|BT|HYJAL|ROL|LOR|UC|TB|ORG|OG|SW|DAL|COD|ES|ESW|DME|DMN|DMW|ULD|HR|SR|MS|OS|GS|OT|PST|INV|GDKP|AH|JC|OCE|GTG|G2G|AV|AB|WSG'
function Ad-Caps([string]$o) {
  if (-not $o -or $o -notmatch '(?i)(^|[^a-z])(lfm|lfg|lf\d*m?|wts|wtb|wtt)([^a-z]|$)') { return $o }
  $o = [regex]::Replace($o, '(?i)(?<![a-z{])(lfm|lfg|lf\d*m?|wts|wtb|wtt|dps|' + $AdDung + ')(?![a-z}])', { param($m) $m.Value.ToUpper() })
  return $o
}
function Msg-Bytes([string]$t) {
  $n = [Text.Encoding]::UTF8.GetByteCount($t)
  foreach ($m in [regex]::Matches($t, '\{fkl(\d+)\}')) { $f = $LinkFull[$m.Groups[1].Value]; if ($f) { $n += [Text.Encoding]::UTF8.GetByteCount($f) - $m.Length } }
  return $n
}
function Do-Send {
  if ($state.sending) { return }
  $txt = $Inp.Text.Trim(); $tg = $state.target
  Fix-ChanTg $tg
  if (-not $txt) { Exit-Input $true; return }
  # (2026-10-31) 직접 친 명령어(/run 등)는 앞 표시({fks}) 없이 그대로 → 게임 애드온이 입력줄 글자를 고치지 않아야 /run 허용 창·/console 등이 막히지 않음
  if ($txt.StartsWith('/')) { Exit-Input $true; Send-Wow @($txt) $false $false $true; return }
  $lq = Laugh-Out $txt
  if ($lq -and $tg -and (Tr-Out $tg)) { Finish-Send $tg $txt $lq; return }
  $wantTr = $tg -and (Tr-Out $tg) -and ($txt -match '[가-힣]')
  if (-not $wantTr) { $pre = Prefix-For $tg; $tk = Link-Tok $txt; Exit-Input $true; Send-Wow (Split-Msg $pre (Link-Game $tk $tk)) $false $true; return }
  $lg = Out-Lang $tg
  if ($state.prevText -eq $txt -and $state.prevLang -eq $lg -and $state.prevOut) { Finish-Send $tg $txt $state.prevOut; return }
  $task = Gem-Send ((Sys-Out $lg $txt) + (Link-Rule (Link-Tok $txt)) + (Slang-Out $txt)) (Link-Tok $txt) $false 'out'
  if (-not $task) { Set-Prev ('번역 엔진 연결 안 됨'); $PrevG.Visibility = 'Visible'; return }
  $state.sending = $true
  # (2026-10-30) '번역해서 보내는 중…' 글씨는 안 띄움 (방송에 거슬림) · 오류일 때만 알려 줌
  [void]$Pending.Add(@{ kind = 'send'; task = $task; src = $txt; lang = $lg; tg = $tg })
  Exit-Input $true   # (2026-10-30) Enter 치면 번역을 기다리지 않고 바로 창이 닫히고 게임으로 (번역이 오면 알아서 보냄)
}
# (2026-10-30) 번역이 실패하면 쓴 글을 그대로 다시 열어 줌 (Enter = 다시 보내기)
function Send-Fail($p, [string]$msg) {
  $state.sending = $false
  if (-not $state.inputOn) { $state.target = $p.tg; Enter-Input; $Inp.Text = [string]$p.src; $Inp.CaretIndex = $Inp.Text.Length }
  Set-Prev $msg; $PrevG.Visibility = 'Visible'
}
function Finish-Send($tg, $ko, $out) {
  $state.sending = $false
  $Sent[(Link-Show $out).Trim()] = $ko
  $pre = Prefix-For $tg
  $g = Link-Game (Link-Tok $ko) $out
  Exit-Input $true
  $parts = Split-Msg $pre $g
  Send-Wow $parts $false $true
  # (2026-10-31) 내 글 바로 표시는 게임에 보낸 직후에 (보내기를 절대 늦추지 않게)
  if (@($parts).Count -eq 1 -and $script:swQ.Count -gt 0) { $script:swQ[$script:swQ.Count - 1].echoLocal = @{ tg = $tg; msg = (Link-Show $out).Trim(); ko = $ko } }
}
# (2026-10-31) Enter 치는 순간 내 글을 번역창에 바로 표시 (게임에서 돌아오기까지 1초쯤 기다리지 않게)
#  · 게임에서 내 글이 돌아오면 그 줄을 진짜 줄로 바꿔 끼움 (두 번 안 나옴) · 색은 전에 게임에서 받은 내 글 색을 기억해서 씀
$LocalEcho = @{}; $MyCol = @{}
$EchoCol = @{ SAY = 'ffffff'; PARTY = 'aaaaff'; PARTY_LEADER = '76c8ff'; RAID = 'ff7f00'; RAID_LEADER = 'ff4809'; GUILD = '40ff40'; OFFICER = '40c040'; YELL = 'ff4040'; WHISPER_INFORM = 'ff80ff'; BN_WHISPER_INFORM = '00faf6'; CHANNEL = 'ffc0c0'; INSTANCE_CHAT = 'ff7f00' }
function Local-Echo($tg, [string]$msg, [string]$ko) {
  if (-not $tg -or -not $msg -or -not $state.me) { return }
  $t = [string]$tg.t; $who = $state.me; $cls = $state.myHex
  if ($t -eq 'WHISPER') { $t = 'WHISPER_INFORM'; $who = [string]$tg.name; $cls = '' }
  elseif ($t -eq 'BN_WHISPER') { $t = 'BN_WHISPER_INFORM'; $who = [string]$tg.name; $cls = '' }
  $col = $(if ($MyCol[$t]) { $MyCol[$t] } elseif ($EchoCol[$t]) { $EchoCol[$t] } else { 'ffffff' })
  if ($MyCol['cls_' + $t]) { $cls = $MyCol['cls_' + $t] }
  $rec = @{ kind = 'C'; t = $t; cnum = [string]$tg.cnum; cname = [string]$tg.cname; sender = $who; cls = $cls; col = $col; msg = $msg; me = $true; test = $false; local = $true }
  $L = Add-Line $rec
  Set-Sub $L '보냄' $ko
  $LocalEcho[$msg] = $L
  if ($LocalEcho.Count -gt 30) { $LocalEcho.Clear() }
}
# 와우 한 번에 보낼 수 있는 길이(255바이트) 넘으면 낱말 단위로 나눔
function Split-Msg($pre, $text) {
  $max = 244 - [Text.Encoding]::UTF8.GetByteCount($pre)   # (2026-10-30) 앞 표시 {fks} 몫 6바이트
  $out = New-Object System.Collections.ArrayList; $cur = ''
  foreach ($w in ($text -split ' ')) {
    $t = $(if ($cur) { "$cur $w" } else { $w })
    if ((Msg-Bytes $t) -gt $max -and $cur) { [void]$out.Add($pre + $cur); $cur = $w } else { $cur = $t }
  }
  if ($cur) { [void]$out.Add($pre + $cur) }
  return ,$out
}
# 와우에 대신 입력: 와우 앞으로 → Enter → 붙여넣기 → Enter (클립보드는 원래대로)
# (2026-10-30) 엔터를 누른 손이 아직 키에서 안 떨어졌거나 한글 입력기가 마지막 글자를 마무리하는 중에 와우로 넘어가면
#  그 엔터가 와우에 한 번 더 들어가 입력줄이 열렸다 닫히며 글이 사라지는 일이 있었음 (ㅋㅋㅋ 빡치네 처럼 한글로 끝나는 말)
#  → 엔터 키가 올라오고 입력기가 정리될 때까지 아주 잠깐(보통 0.1초 안팎) 기다렸다가 보냄
$script:swQ = New-Object System.Collections.ArrayList
$SwT = New-Object Windows.Threading.DispatcherTimer
$SwT.Interval = [TimeSpan]::FromMilliseconds(30)
$SwT.Add_Tick({
  try {
    if ($script:swQ.Count -eq 0) { $SwT.Stop(); return }
    $q = $script:swQ[0]
    $held = ([FTRK.Keys]::GetAsyncKeyState(0x0D) -band 0x8000) -ne 0   # (2026-10-31) 실제 키 상태 (창이 바뀌면 WPF 쪽 상태가 '눌림'으로 남아 0.9초를 늘 기다리던 것)
    if ($held -and ([DateTime]::Now - $q.at).TotalMilliseconds -lt 900) { $q.up = $null; return }
    if (-not $q.up) { $q.up = [DateTime]::Now; return }
    if (([DateTime]::Now - $q.up).TotalMilliseconds -lt 60) { return }
    $script:swQ.RemoveAt(0)
    $t0 = [DateTime]::Now
    # (2026-10-31) 내 글 바로 표시(10ms 안팎)를 게임 입력(0.5초)보다 먼저 → 번역창엔 Enter 직후 바로 보임
    if ($q.echoLocal) { try { Local-Echo $q.echoLocal.tg $q.echoLocal.msg $q.echoLocal.ko } catch { Log "바로 보이기: $_" } }
    $t1 = [DateTime]::Now
    Send-WowNow $q.lines $q.keep ([bool]$q.raw)
    if ($q.echo) { Await-Echo $q.lines }
    if ($q.echoLocal) { Dbg ("보내기 시간: Enter→표시 {0}ms · 바로 표시 {1}ms · 게임 입력 {2}ms" -f [int]($t0 - $q.at).TotalMilliseconds, [int]($t1 - $t0).TotalMilliseconds, [int]([DateTime]::Now - $t1).TotalMilliseconds) }
  } catch { Log "보내기 대기: $_" }
})
function Send-Wow($lines, [bool]$keepTab = $false, [bool]$echo = $false, [bool]$raw = $false) {
  [void]$script:swQ.Add(@{ lines = $lines; keep = $keepTab; echo = $echo; raw = $raw; at = [DateTime]::Now; up = $null })
  $SwT.Start()
}
# (2026-10-30) 보낸 글이 게임에서 실제로 나갔는지 확인 (내 글이 게임에서 돌아오는지) · 4초 안에 안 돌아오면 한 번만 다시 보냄
$script:echoW = $null
function Await-Echo($lines) {
  $b = @(); foreach ($l in @($lines)) { $t = [string]$l; if ($t -match '\{fkl') { return }; $b += $t }
  if ($b.Count -eq 0) { return }
  $script:echoW = @{ lines = $b; at = [DateTime]::Now; drops = [FTR]::Drops; tries = 0 }
}
function Echo-Seen([string]$p) {
  $w = $script:echoW; if (-not $w) { return }
  # 와우 욕설 필터가 글을 바꿔서 돌려줄 수도 있어서(!@#$) 내 글이 하나라도 돌아오면 나간 걸로 봄
  $script:echoW = $null
}
$EchoT = New-Object Windows.Threading.DispatcherTimer
$EchoT.Interval = [TimeSpan]::FromMilliseconds(500)
$EchoT.Add_Tick({
  try {
    $w = $script:echoW; if (-not $w) { return }
    if (([DateTime]::Now - $w.at).TotalSeconds -lt 4) { return }
    $script:echoW = $null
    # 게임 신호가 끊겼거나 신호를 놓친 적이 있으면 실제로는 나갔을 수도 있어서 다시 안 보냄 (두 번 나가는 것 방지)
    if ($w.tries -ge 1 -or [FTR]::SincePacket() -gt 15000 -or [FTR]::Drops -ne $w.drops) { Dbg ("보낸 글 확인 안 됨 (다시 안 보냄): " + ($w.lines -join ' | ')); return }
    Dbg ("보낸 글이 게임에서 안 보여서 한 번 더 보냄: " + ($w.lines -join ' | '))
    Send-WowNow $w.lines $false
    $script:echoW = @{ lines = $w.lines; at = [DateTime]::Now; drops = [FTR]::Drops; tries = 1 }
  } catch { Log "보낸 글 확인: $_" }
})
$EchoT.Start()
# (공유판) 번역 켜기/끄기 = 한 가지 상태: 번역대화창 '번역 ON' 알약 · 위쪽 도우미 바 알약 · 설정 '번역' · 게임 미니맵 버튼(번역/대화창)이 늘 같이 움직임
#  · 프로그램에서 바꾸면 → 게임에 '/nttr 켜기' 또는 '/nttr 끄기'를 대신 입력 (게임이 번역대화창 / 기본 대화창으로 바꿈)
#  · 게임에서 바꾸면(미니맵 버튼) → 게임이 보내는 신호 P(번역대화창 모드) / X(기본 대화창 모드)를 프로그램이 따라감
#  · 프로그램에서 막 바꾼 뒤 8초 동안은 게임의 옛 신호를 무시 (게임에 들어가 새 신호가 올 때까지)
$script:trHold = [DateTime]::MinValue; $script:quitting = $false
function Tr-Paint {
  try { Pills-Paint } catch {}
  try { Bar-Paint } catch {}
  try { Paint-Status } catch {}
  try { Paint-Target } catch {}
  try { if ($Pop.IsOpen -and $script:popMode -eq 'tr') { Build-Menu } } catch {}
}
function Tr-Set([bool]$on, [bool]$fromGame = $false) {
  $S.pause = -not $on; Save-Cfg
  if (-not $fromGame) {
    $script:trHold = [DateTime]::Now.AddSeconds(8)
    if ([FTR]::FindWow() -ne [IntPtr]::Zero -and [FTR]::SincePacket() -lt 40000) { Log ('번역 ' + $(if ($on) { '켬 (/nttr 켜기)' } else { '끔 (/nttr 끄기)' })); Send-Wow @($(if ($on) { '/nttr 켜기' } else { '/nttr 끄기' })) $true $false $true }
  }
  Tr-Paint
}
# X 신호: [1] 게임 입력칸에 쓰는 중 · [2] 전투 중 · [3] userOff (1 = 사용자가 직접 끔 → 프로그램도 꺼짐 · 0 = 한 번도 안 고름(처음 설치) → 프로그램이 켜져 있으면 번역창으로 바꿔 줌)
#  필드 없는 X = 게임이 막 끈 순간 → 프로그램도 꺼짐
$script:autoOnAt = [DateTime]::MinValue
function Tr-OffRec($f) {
  if ($f.Count -gt 3 -and [string]$f[3] -eq '0') { if (-not [bool]$S.pause) { Auto-On $f }; return }
  Tr-Follow $false
}
function Auto-On($f) {
  if ($script:quitting -or [DateTime]::Now -lt $script:trHold) { return }
  if (([DateTime]::Now - $script:autoOnAt).TotalSeconds -lt 20) { return }
  if ($f.Count -gt 1 -and $f[1] -eq '1') { return }
  if ($f.Count -gt 2 -and $f[2] -eq '1') { return }
  $w = [FTR]::FindWow(); if ($w -eq [IntPtr]::Zero) { return }
  if ([FTR]::Foreground() -ne $w) { return }
  if ($state.sending -or $state.inputOn -or $script:swQ.Count -gt 0) { return }
  $script:autoOnAt = [DateTime]::Now
  Log '게임이 아직 번역을 고른 적 없음 → 번역창으로 바꿈 (/nttr 켜기)'
  Send-Wow @('/nttr 켜기') $true $false $true
}
function Tr-Follow([bool]$gameOn) {
  if ($script:quitting -or [DateTime]::Now -lt $script:trHold) { return }
  if ($gameOn -eq (-not [bool]$S.pause)) { return }
  Log ('게임에서 번역 ' + $(if ($gameOn) { '켬' } else { '끔' }) + ' → 프로그램도 같이')
  Tr-Set $gameOn $true
}
function Tr-Quit {
  if ($script:quitting) { return }
  $script:quitting = $true
  try {
    $w = [FTR]::FindWow()
    if ($w -ne [IntPtr]::Zero -and -not $state.off -and [FTR]::SincePacket() -lt 40000) { Log '번역창 끔 → 게임 대화창으로 (/nttr 끄기)'; Send-WowNow @('/nttr 끄기') $true $true }
  } catch { Log "번역 끄기: $_" }
  $win.Close()
}
function Send-WowNow($lines, [bool]$keepTab = $false, [bool]$raw = $false) {
  # 보낸 글이 지금 고른 탭에서 안 보이면 '전체' 탭으로 (링크 열기 명령은 탭 그대로)
  # (2026-11-08 대표) 말을 보내도 고른 탭은 그대로 (예전엔 보내면 '전체' 탭으로 바뀌었음)
  $w = [FTR]::FindWow(); if ($w -eq [IntPtr]::Zero) { Dbg '보내기: 와우 창 없음'; return }
  $state.sentAt = [DateTime]::Now
  if ($state.hkE) { [void][FTR]::HotkeyEnter($script:hwnd, $false); $state.hkE = $false }   # 와우에 대신 누르는 Enter를 우리가 가로채지 않게
  foreach ($l0 in $lines) { Dbg ("보냄 → " + $l0) }
  $old = $null; try { if ([System.Windows.Clipboard]::ContainsText()) { $old = [System.Windows.Clipboard]::GetText() } } catch {}
  foreach ($l in $lines) {
    try {
      [System.Windows.Clipboard]::SetText($(if ($raw) { [string]$l } else { '{fks}' + $l }))   # (2026-10-30) 앞 표시: 게임이 그 앞에 끼어든 글자(이동 중 W 등)를 버림
      [FTR]::Focus($w); Start-Sleep -Milliseconds 90
      [FTR]::Tap(0x0D); Start-Sleep -Milliseconds 110
      [FTR]::CtrlV(); Start-Sleep -Milliseconds 70
      [FTR]::Tap(0x0D); Start-Sleep -Milliseconds 160
    } catch { Log "보내기: $_" }
  }
  try { if ($null -ne $old) { [System.Windows.Clipboard]::SetText($old) } } catch {}
}

# ---------- 창 위치 (와우 채팅창 자리) ----------
function Place-Win {
  $g = $(if ($script:geoOv) { $script:geoOv } else { $state.geo }); if (-not $g -or -not $script:hwnd) { return }
  $w = [FTR]::FindWow(); if ($w -eq [IntPtr]::Zero) { return }
  $cr = [FTR]::ClientRect($w); if (-not $cr) { return }
  $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  $k = $g.s / $dpi
  $Scale.ScaleX = $k; $Scale.ScaleY = $k
  if ([math]::Abs($script:K - $g.s) -gt 0.0001 -or [math]::Abs($script:Dpi - $dpi) -gt 0.0001 -or [math]::Abs($script:PWu - $g.w / $g.s) -gt 0.5) { $script:K = $g.s; $script:Dpi = $dpi; $script:PWu = $g.w / $g.s; if (-not $script:uiDrag) { Redraw-All } }
  $Sv.Margin = New-Object System.Windows.Thickness((12 * $k), (($TOP + 34) * $k), 0, 0)   # (2026-11-03) 새 디자인: 탭 줄과 글 사이 여백
  $Sv.Width = ($g.w / $g.s - 24) * $k; $Sv.Height = ($g.h / $g.s - 68) * $k
  $script:PWu = $g.w / $g.s
  $ShT.X = 1 / $g.s; $ShT.Y = 1 / $g.s
  $Panel.Width = $g.w / $g.s; $Panel.Height = $g.h / $g.s
  $script:PWnow = $Panel.Width
  [System.Windows.Controls.Canvas]::SetLeft($TrM.root, $Panel.Width - 28)
  [System.Windows.Controls.Canvas]::SetLeft($TrLab, $Panel.Width - 36 - $TrLab.ActualWidth)
  try { Place-Plus } catch {}
  $topPx = [int]($TOP * $g.s)
  $key = "$($cr[0]),$($cr[1]),$($g.x),$($g.y),$($g.w),$($g.h)"
  if ($script:placed -ne $key) {
    $script:placed = $key
    [FTR]::Place($script:hwnd, $cr[0] + $g.x, $cr[1] + $g.y - $topPx, $g.w + 2, $g.h + $topPx + 2)
  }
}

# ---------- (2026-10-25) 파티 모집 알림 카드 (번역 켜져 있을 때) ----------
# 게임이 내 레벨 인던 모집 글을 찾으면 'L' 로 알려 줌 → 게임 카드 자리에 같은 모양으로 띄우고 외국어면 번역해서 바꿔 끼움
# 클릭 = 그 사람에게 귓말 답장 (번역 입력칸) · 10초 뒤 1초 동안 사라짐
$Lfg = @{ win = $null; hwnd = [IntPtr]::Zero; at = [DateTime]::MinValue; rec = $null; key = 0 }
function Lfg-Make {
  if ($Lfg.win) { return }
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
  $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = New-Object System.Windows.Thickness(10, 6, 10, 8); $sp.Effect = New-Halo
  $sp.Background = [System.Windows.Media.Brushes]::Transparent
  $h = New-Object System.Windows.Controls.TextBlock; $h.FontFamily = $script:CFONT; $h.FontWeight = 'Bold'; $h.TextWrapping = 'Wrap'
  $b = New-Object System.Windows.Controls.TextBlock; $b.FontFamily = $script:CFONT; $b.FontWeight = 'Bold'; $b.TextWrapping = 'Wrap'; $b.Foreground = HexBr 'dfe6f0'
  $o = New-Object System.Windows.Controls.TextBlock; $o.FontFamily = $script:CFONT; $o.FontWeight = 'Bold'; $o.TextWrapping = 'Wrap'; $o.Foreground = HexBr 'a8a294'; $o.Visibility = 'Collapsed'
  [void]$sp.Children.Add($h); [void]$sp.Children.Add($b); [void]$sp.Children.Add($o)
  $bd = New-Object System.Windows.Controls.Border; $bd.Background = Br '#01000000'; $bd.Child = $sp; $bd.Cursor = [System.Windows.Input.Cursors]::Hand
  $w.Content = $bd
  $w.Add_MouseLeftButtonUp({
    try { $r = $Lfg.rec; $Lfg.win.Hide(); if ($r -and $r.sender) { $state.target = @{ t = 'WHISPER'; name = $r.sender }; Enter-Input } } catch { Log "모집 카드: $_" }
  })
  # (2026-10-25) Ctrl+오른쪽 클릭: 이 카드는 번역 프로그램이 그린 거라 게임의 이동 모드를 켤 수 없어서 → 방법 안내
  $w.Add_MouseRightButtonUp({
    try {
      if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) {
        $Lfg.orig.Text = '이 카드는 위치를 옮길 수 없어요'; $Lfg.orig.Visibility = 'Visible'; $Lfg.at = [DateTime]::Now
      }
    } catch {}
  })
  $Lfg.win = $w; $Lfg.head = $h; $Lfg.body = $b; $Lfg.orig = $o
  $w.Show(); $Lfg.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle; [FTR]::NoActivate($Lfg.hwnd, $true); $w.Hide()
}
function Lfg-Show($f) {
  Lfg-Make
  # f: L 이름 추천낮음 추천높음 색 보낸이(표시) 보낸이(전체) 글 x(가운데·px) y(위·px) 배율
  $rec = @{ name = $f[1]; lo = $f[2]; hi = $f[3]; hex = $f[4]; who = $f[5]; sender = $f[6]; msg = $f[7]; x = [int]$f[8]; y = [int]$f[9]; s = [double]::Parse($f[10], [Globalization.CultureInfo]::InvariantCulture) }
  $Lfg.rec = $rec; $Lfg.key++
  $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  $k = $rec.s / $dpi
  $Lfg.head.FontSize = 15 * $k; $Lfg.body.FontSize = 14 * $k; $Lfg.orig.FontSize = 11.5 * $k
  $Lfg.head.MaxWidth = 440 * $k; $Lfg.body.MaxWidth = 440 * $k; $Lfg.orig.MaxWidth = 440 * $k
  # (2026-10-25) 줄 사이 조금 넓게 (제목 ↔ 번역문 ↔ 원문)
  $Lfg.body.Margin = New-Object System.Windows.Thickness(0, (10 * $k), 0, 0); $Lfg.orig.Margin = New-Object System.Windows.Thickness(0, (7 * $k), 0, 0)
  $Lfg.head.Inlines.Clear()
  [void](Add-Run $Lfg.head '파티 모집  ' 'f5d17a' $null); [void](Add-Run $Lfg.head ($rec.name + '  ') 'ffffff' $null)
  [void](Add-Run $Lfg.head ('추천 ' + $rec.lo + '~' + $rec.hi + '  ') $rec.hex $null); [void](Add-Run $Lfg.head ('· ' + $rec.who) '8a93a8' $null)
  $p = Plain $rec.msg
  $Lfg.body.Text = $p; $Lfg.orig.Visibility = 'Collapsed'; $Lfg.orig.Text = ''
  if (Is-Foreign $p) {
    if ($Cache[$p]) { Lfg-Done $Lfg.key $Cache[$p] $p }
    else {
      # (2026-10-25) 어떤 인던 모집 글인지 알려 줌 → 인던 줄임말(HOT, SM 등)을 엉뚱하게 옮기지 않게
      $hint = "`n[참고] 이 글은 '" + $rec.name + "' 인던 파티 모집 글이에요. 글 속 인던 줄임말은 '" + $rec.name + "'(으)로 옮기세요."
      $task = Gem-Send ($SYS_IN + (Gloss-For $p) + (Slang-In $p) + $hint) (Pre-Fix $p) $false 'in'   # (2026-11-01) 파티 모집 글(공개 채널) = PC 4B 먼저
      if ($task) { [void]$Pending.Add(@{ kind = 'lfg'; task = $task; key = $Lfg.key; src = $p }); $Lfg.orig.Text = '번역 중…'; $Lfg.orig.Visibility = 'Visible' }
    }
  }
  $Lfg.at = [DateTime]::Now; $Lfg.win.Opacity = 1
  $Lfg.win.Show(); $Lfg.win.UpdateLayout()
  $wow = [FTR]::FindWow(); $cr = $(if ($wow -ne [IntPtr]::Zero) { [FTR]::ClientRect($wow) } else { $null })
  if ($cr) { $Lfg.win.Left = ($cr[0] + $rec.x) / $dpi - $Lfg.win.ActualWidth / 2; $Lfg.win.Top = ($cr[1] + $rec.y) / $dpi - 6 }
}
function Lfg-Done($key, $res, $src) {
  if ($key -ne $Lfg.key -or -not $Lfg.win) { return }
  $ko = [string]$res.ko
  if (-not $ko -or [string]$res.lang -eq 'KO') { $Lfg.orig.Visibility = 'Collapsed'; return }
  $Lfg.body.Text = $ko; $Lfg.orig.Text = $src; $Lfg.orig.Visibility = 'Visible'
  $Lfg.win.UpdateLayout()
  $rec = $Lfg.rec; $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  $wow = [FTR]::FindWow(); $cr = $(if ($wow -ne [IntPtr]::Zero) { [FTR]::ClientRect($wow) } else { $null })
  if ($cr) { $Lfg.win.Left = ($cr[0] + $rec.x) / $dpi - $Lfg.win.ActualWidth / 2 }
}
function Lfg-Tick {
  if (-not $Lfg.win -or -not $Lfg.win.IsVisible) { return }
  $age = ([DateTime]::Now - $Lfg.at).TotalSeconds
  if ($age -gt 11) { $Lfg.win.Hide() } elseif ($age -gt 10) { $Lfg.win.Opacity = 11 - $age }
}

# ---------- (2026-10-25) 화면 가운데 파티 대화 줄 (번역 켜져 있을 때 · 게임 줄 대신 같은 자리에) ----------
# 파티·공대·인던·귓말만 · 외국어는 번역문 크게 + 원문 아래 작게 · 10초 뒤 사라짐 · 최대 7줄 · 귓말 이름 클릭 = 답장
$FEEDT = @{ PARTY = 'aad4ff'; PARTY_LEADER = 'aad4ff'; INSTANCE_CHAT = 'aad4ff'; INSTANCE_CHAT_LEADER = 'aad4ff'; RAID = 'ff9a5a'; RAID_LEADER = 'ff9a5a'; RAID_WARNING = 'ff5a5a'
  WHISPER = 'ff80ff'; WHISPER_INFORM = 'ff80ff'; BN_WHISPER = 'ff80ff'; BN_WHISPER_INFORM = 'ff80ff'
  SAY = 'ffffff'; YELL = 'ff4040'; GUILD = '40ff40'; OFFICER = '40c040'; CHANNEL = 'ffc0c0' }   # (2026-10-26) 게임 대화창 설정 '가운데' 별 칸으로 고르는 것
# (2026-10-26) 가운데 줄에 띄울지: 게임이 알려 준 종류(mask: s일반 p파티 r공대 i인던 g길드 w귓말 c채널) · 옛 게임 애드온이면 예전처럼 파티·공대·인던·귓말
function Feed-Want($rec) {
  if ($S.feedOff) { return $false }   # (2026-11-03) 입력줄 '가운데' 버튼으로 끔
  if ($rec.call -and -not $rec.me) { return $true }   # (2026-11-03 A안) 공개 채널에서 내 이름을 부른 줄은 가운데에도 띄움
  $t = [string]$rec.t
  if (-not $FEEDT.ContainsKey($t)) { return $false }
  $m = $Feed.mask
  if ($null -eq $m) { return [bool]($t -match '^(PARTY|INSTANCE|RAID|WHISPER|BN_WHISPER)') }
  $c = ''
  switch -Regex ($t) { '^(SAY|YELL)$' { $c = 's' } '^PARTY' { $c = 'p' } '^RAID' { $c = 'r' } '^INSTANCE' { $c = 'i' } '^(GUILD|OFFICER)$' { $c = 'g' } 'WHISPER' { $c = 'w' } '^CHANNEL$' { $c = 'c' } }
  if ($c -eq 'c' -and $m.Contains('c') -and (Cen-ChOff $rec.cname)) { return $false }   # (2026-11-05) 채널은 채널마다 따로 끄고 켬
  return [bool]($c -and $m.Contains($c))
}
# (2026-11-05) 가운데 파티글: 채널별로 끈 목록 ($S.cenChOff = '공개|거래' 처럼 채널 앞 이름)
function Cen-ChBase($nm) { $b = ([string]$nm -replace '^\s*\d+\.\s*', ''); $b = (($b -split ' - ')[0]).Trim(); return ($b -replace '\s+\d+$', '') }   # '파티찾기 6' 처럼 뒤에 붙는 번호도 뗌
function Cen-SyncGame { Game-Cmd ('/ntchat choff ' + (([string]$S.cenChOff) -replace '\|', ',')) }   # (2026-11-09) 채널별 끄기를 게임 대화창 톱니에도 똑같이
function Cen-ChOff($nm) { $b = Cen-ChBase $nm; if (-not $b) { return $false }; return ('|' + [string]$S.cenChOff + '|').Contains('|' + $b + '|') }
$Feed = @{ win = $null; hwnd = [IntPtr]::Zero; geo = $null; grid = $null; list = (New-Object System.Collections.ArrayList); ct = $true; mask = $null; font = 13.0; hist = (New-Object System.Collections.ArrayList); histOn = $false; off = 0; histAt = [DateTime]::MinValue; bgOn = $false }   # (2026-11-02) hist = 지난 파티 대화 50줄 (휠로 보기)
# (2026-10-27) 가운데 줄 글자 크기 (게임 설정 따름, 기본 13)
function FeedFz { if ($Feed -and $Feed.font -gt 0) { [double]$Feed.font } else { 13.0 } }
# (공유판) 가운데 파티글 자리: 조절 모드에서 직접 맞춘 자리($S.feedBox · 와우 화면 픽셀 · x=왼쪽 · y=아래쪽 · w · h)가 있으면 그 자리, 없으면 게임 애드온이 알려 준 자리
function Feed-Max { $n = 7; try { if ([int]$S.feedLines -ge 1) { $n = [math]::Min(12, [int]$S.feedLines) } } catch {}; return $n }
# (공유판) 프로그램에서 맞춘 자리($S.feedBox)와 게임 애드온의 파티글 자리를 같게 유지
#  · 게임 안에서 직접 옮겼으면(F 신호의 '옮기는 중'이 켜졌다 꺼짐) 그 자리를 따름 · 그 밖에 자리가 다르면(애드온 초기화 등) 30초 간격으로 최대 3번 '/ntchat feedpos'로 다시 알려 줌
$script:fMoved = $false; $script:fSyncAt = [DateTime]::MinValue; $script:fSyncN = 0
function Feed-Sync([bool]$hold) {
  $g = $Feed.geo; if (-not $g -or $script:fedit) { return }
  if ($g.mv -or $g.edit) { $script:fMoved = $true; return }
  $b = $S.feedBox; if (-not ($b -is [hashtable])) { $script:fMoved = $false; return }
  $diff = ([math]::Abs([int]$b.x - [int]$g.x) -gt 3) -or ([math]::Abs([int]$b.y - [int]$g.y) -gt 3) -or ([math]::Abs([int]$b.w - [int]$g.w) -gt 3) -or ([int]$g.h -gt 0 -and [math]::Abs([int]$b.h - [int]$g.h) -gt 3)
  if ($script:fMoved) { $script:fMoved = $false; if ($diff) { [void]$S.Remove('feedBox'); Save-Cfg; Log '게임에서 파티글 자리를 옮겨서 그 자리를 따름' }; return }
  if (-not $diff -or $hold) { return }
  if (([DateTime]::Now - $script:fSyncAt).TotalSeconds -lt 30 -or $script:fSyncN -ge 3) { return }   # 한 번 켤 때 최대 3번까지만
  $script:fSyncAt = [DateTime]::Now; $script:fSyncN++
  Game-Cmd ('/ntchat feedpos {0} {1} {2} {3}' -f [int]$b.x, [int]$b.y, [int]$b.w, [int]$b.h)
}
function FGeo {
  $g = $Feed.geo
  $b = $S.feedBox
  if ($script:fedit -and $script:fbox) { $b = $script:fbox }
  if (-not ($b -is [hashtable])) { return $g }
  $s0 = 1.0; if ($g -and $g.s) { $s0 = [double]$g.s } elseif ($state.geo -and $state.geo.s) { $s0 = [double]$state.geo.s }
  $ed0 = $false; $mv0 = $false; if (-not $script:fedit -and $g) { $ed0 = [bool]$g.edit; $mv0 = [bool]$g.mv }
  return @{ x = [int]$b.x; y = [int]$b.y; w = [int]$b.w; h = [int]$b.h; s = $s0; edit = $ed0; mv = $mv0 }
}
function Feed-Make {
  if ($Feed.win) { return }
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
  $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'
  $g = New-Object System.Windows.Controls.Grid
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Bottom'
  $e = New-Object System.Windows.Media.Effects.DropShadowEffect; $e.Color = [System.Windows.Media.Color]::FromRgb(51, 24, 4); $e.ShadowDepth = 1.4; $e.Direction = 315; $e.BlurRadius = 1.5; $e.Opacity = 0.9
  $sp.Effect = $null   # (2026-11-02) 가운데 파티 대화도 그림자 없이 글씨만 (번역 대화창과 같게)
  [void]$g.Children.Add($sp); $w.Content = $g
  $Feed.win = $w; $Feed.sp = $sp; $Feed.grid = $g
  # (공유판) 조절 모드: 끌기 = 이동 · 오른쪽 아래 네모 = 크기
  $w.Add_MouseLeftButtonDown({ param($s2, $e2) if ($script:fedit) { try { FEd-Down $e2 } catch { Log "파티글 조절: $_" }; $e2.Handled = $true } })
  $w.Add_MouseMove({ param($s2, $e2) if ($script:fedit -and $script:fdrag) { try { FEd-Move } catch {} } })
  $w.Add_LostMouseCapture({ param($s2, $e2) $script:fdrag = $null })
  $w.Add_MouseWheel({ param($s2, $e2) if ($script:fedit) { $e2.Handled = $true; return }; try { Feed-Wheel ([int]$e2.Delta) } catch { Log "가운데 줄 휠: $_" }; $e2.Handled = $true })
  $w.Add_MouseLeftButtonUp({ if ($script:fedit) { try { $script:fdrag = $null; $Feed.win.ReleaseMouseCapture() } catch {}; return }; try { if ($Feed.hot -is [hashtable]) { if ($Feed.hot.link) { Show-Link ([string]$Feed.hot.link) } } elseif ($Feed.hot) { $state.target = Tell-Tg $Feed.hot; Enter-Input } } catch { Log "가운데 줄 답장: $_" } })   # (2026-11-02) [아이템] 누르면 게임 툴팁
  $w.Show(); $Feed.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle
  [FTR]::NoActivate($Feed.hwnd, $true); [FTR]::ClickThrough($Feed.hwnd, $true); $Feed.ct = $true
  $w.Hide()
}
# ---------- (2026-10-30) 입력칸을 화면 가운데 파티 대화 바로 아래에 (요청 A안) ----------
#  입력을 시작하면 금테 입력줄·번역 미리보기를 가운데 창으로 옮겼다가, 끝나면 원래 채팅창 자리로 되돌림
#  가운데 파티 대화 자리를 아직 모르면(게임에서 안 알려 줌) 예전처럼 채팅창에서 입력
$CIn = @{ win = $null; hwnd = [IntPtr]::Zero; grid = $null; on = $false }
function CIn-Make {
  if ($CIn.win) { return }
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
  $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'
  $w.UseLayoutRounding = $true; $w.SnapsToDevicePixels = $true
  $g = New-Object System.Windows.Controls.Grid; $g.HorizontalAlignment = 'Left'; $g.VerticalAlignment = 'Top'
  $CIn.scale = New-Object System.Windows.Media.ScaleTransform(1, 1); $g.LayoutTransform = $CIn.scale
  $w.Content = $g; $CIn.win = $w; $CIn.grid = $g
  $w.Add_Deactivated($OnDeact)
  $w.Show(); $CIn.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle
  [FTR]::NoActivate($CIn.hwnd, $true)
  $w.Hide()
}
function CIn-Open {
  if ($S.feedOff) { return $false }   # (2026-11-13 대표) 파티글을 끄면 입력은 본 대화창에서 · 켜면 파티글 아래로 따라감
  $g = FGeo; if (-not $g -or -not $state.geo) { return $false }
  $wow = [FTR]::FindWow(); if ($wow -eq [IntPtr]::Zero) { return $false }
  $cr = [FTR]::ClientRect($wow); if (-not $cr) { return $false }
  CIn-Make
  $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  $k = $Scale.ScaleX; $CIn.scale.ScaleX = $k; $CIn.scale.ScaleY = $k
  if (-not $CIn.on) {
    [void]$Chrome.Children.Remove($Cap); [void]$Panel.Children.Remove($PrevG)
    $CIn.grid.Width = $Panel.Width; $CIn.grid.Height = 84
    [void]$CIn.grid.Children.Add($PrevG); [void]$CIn.grid.Children.Add($Cap)
    # (2026-10-30) 가운데에선 간단하게: 금테·'한 → 영'·'(Shift+Enter)' 안내 빼고 입력칸만
    $capG.Visibility = 'Collapsed'; $LangB.Visibility = 'Collapsed'; $PhT.Text = '메시지 입력…'
    # (2026-10-30) 가운데에선 번역 미리보기를 입력줄 아래로
    $CIn.capM = $Cap.Margin; $CIn.prevM = $PrevG.Margin
    $Cap.VerticalAlignment = 'Top'; $Cap.Margin = New-Object System.Windows.Thickness(8, 4, 8, 0); $capBg.CornerRadius = New-Object System.Windows.CornerRadius(6); $capBg.Background = Br '#E0111112'
    $PrevG.VerticalAlignment = 'Top'; $PrevG.Margin = New-Object System.Windows.Thickness(20, 40, 14, 0)
    $Gear.root.Visibility = 'Collapsed'; $ImeM.root.Visibility = 'Visible'
    $CIn.on = $true; Dock-Fit
  }
  # 가운데 파티 대화 칸의 맨 아래(마지막 줄 바로 밑)에 가운데 맞춤
  $fx = ($cr[0] + $g.x) / $dpi; $fw = $g.w / $dpi; $fb = ($cr[1] + $g.y) / $dpi
  $CIn.win.Width = $Panel.Width * $k + 2; $CIn.win.Height = 84 * $k + 2
  $CIn.win.Left = $fx + ($fw - $CIn.win.Width) / 2; $CIn.win.Top = $fb + 14 * $k
  $CIn.win.Show()
  return $true
}
function CIn-Close {
  if (-not $CIn.on) { return }
  [void]$CIn.grid.Children.Remove($PrevG); [void]$CIn.grid.Children.Remove($Cap)
  [void]$Chrome.Children.Add($Cap); [void]$Panel.Children.Add($PrevG)
  $capG.Visibility = 'Visible'; $LangB.Visibility = 'Visible'; $PhT.Text = '메시지 입력…'
  $capBg.CornerRadius = New-Object System.Windows.CornerRadius(0, 0, 6, 6); $capBg.Background = Br '#0AFFFFFF'
  $Cap.VerticalAlignment = 'Bottom'; $Cap.Margin = $CIn.capM; $PrevG.VerticalAlignment = 'Bottom'; $PrevG.Margin = $CIn.prevM
  $Gear.root.Visibility = 'Visible'; $ImeM.root.Visibility = 'Collapsed'
  $CIn.on = $false; Dock-Fit
  try { [FTR]::NoActivate($CIn.hwnd, $true); $CIn.win.Hide() } catch {}
}
# (2026-11-02) 가운데 파티 대화: 휠로 지난 대화 보기 (휠 그대로)
#  가운데 칸 위에 마우스 커서가 보일 때(시점 돌리기 중 아님) 휠↑ = 지난 대화 · 휠↓ = 최근 쪽 · 맨 아래에서 휠↓ 또는 8초 손 안 대면 원래대로
function Feed-Push($FL) {
  if ($FL.rec) { $FL.box.Tag = $FL; [void]$Feed.hist.Add($FL); while ($Feed.hist.Count -gt 50) { $Feed.hist.RemoveAt(0) } }
  [void]$Feed.list.Add($FL)
  if ($Feed.histOn) { if ($FL.rec) { $Feed.off = [math]::Min($Feed.off + 1, [math]::Max(0, $Feed.hist.Count - 1)) } }
  elseif (-not $script:fedit) { [void]$Feed.sp.Children.Add($FL.box) }
  while ($Feed.list.Count -gt (Feed-Max)) { if (-not $Feed.histOn) { $Feed.sp.Children.Remove($Feed.list[0].box) }; $Feed.list.RemoveAt(0) }
}
function Feed-Hist {
  $Feed.sp.Children.Clear()
  if (-not $Feed.histOn) { foreach ($x in $Feed.list) { [void]$Feed.sp.Children.Add($x.box) }; return }
  $n = $Feed.hist.Count; $end = $n - $Feed.off; if ($end -lt 1) { $end = [math]::Min(1, $n) }
  $start = [math]::Max(0, $end - (Feed-Max))
  for ($i = $start; $i -lt $end; $i++) { $b = $Feed.hist[$i].box; $b.Opacity = 1; [void]$Feed.sp.Children.Add($b) }
  try {
    $Feed.sp.UpdateLayout()
    $tot = 0.0; foreach ($c in $Feed.sp.Children) { $tot += $c.DesiredSize.Height }
    while ($Feed.sp.Children.Count -gt 1 -and $tot -gt $Feed.win.Height + 1) { $tot -= $Feed.sp.Children[0].DesiredSize.Height; $Feed.sp.Children.RemoveAt(0) }
  } catch {}
}
function Feed-Wheel([int]$d) {
  $n = $Feed.hist.Count; if ($n -eq 0) { return }
  $Feed.histAt = [DateTime]::Now
  if ($d -gt 0) { if (-not $Feed.histOn) { $Feed.histOn = $true; $Feed.off = 0 } elseif ($Feed.off -lt $n - 1) { $Feed.off++ } }
  else { if (-not $Feed.histOn) { return }; if ($Feed.off -le 0) { $Feed.histOn = $false } else { $Feed.off-- } }
  Feed-Hist
}
function Feed-Place {
  $g = FGeo; if (-not $g -or -not $Feed.win) { return }
  $wow = [FTR]::FindWow(); if ($wow -eq [IntPtr]::Zero) { return }
  $cr = [FTR]::ClientRect($wow); if (-not $cr) { return }
  $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  $Feed.k = $g.s / $dpi
  # (2026-10-26) 게임에서 정한 파티 대화 칸 높이 안에서만 (예전엔 520 고정이라 줄이 많으면 칸 위로 계속 올라갔음)
  $Feed.win.Width = $g.w / $dpi; $Feed.win.Height = $(if ($g.h -gt 0) { $g.h / $dpi } else { 520 * $Feed.k })
  $Feed.win.Left = ($cr[0] + $g.x) / $dpi; $Feed.win.Top = ($cr[1] + $g.y) / $dpi - $Feed.win.Height
}
function Feed-Add($rec) {
  # (2026-10-27) 가운데 줄 글자 15 → 13 · 원문 11.5 → 10 (음성 줄도 같이)
  $fg0 = FGeo; if (-not $fg0 -or $fg0.edit) { return $null }
  Feed-Make
  $k = $(if ($Feed.k) { $Feed.k } else { 1.2 })
  $box = New-Object System.Windows.Controls.StackPanel; $box.Margin = New-Object System.Windows.Thickness(0, 0, 0, (10 * $k)); $box.Opacity = 0
  $main = New-Object System.Windows.Controls.TextBlock; $main.FontFamily = $script:CFONT; $main.FontWeight = 'Bold'; $main.FontSize = (FeedFz) * $k; $main.TextWrapping = 'Wrap'; $main.TextAlignment = 'Center'
  $sub = New-Object System.Windows.Controls.TextBlock; $sub.FontFamily = $script:CFONT; $sub.FontWeight = 'Bold'; $sub.FontSize = (FeedFz) * 0.77 * $k; $sub.TextWrapping = 'Wrap'; $sub.TextAlignment = 'Center'; $sub.Foreground = HexBr 'c9c2b0'; $sub.Opacity = 0.85; $sub.Visibility = 'Collapsed'; $sub.Margin = New-Object System.Windows.Thickness(0, (3 * $k), 0, 0)
  [void]$box.Children.Add($main); [void]$box.Children.Add($sub)
  $whisper = ($rec.t -match 'WHISPER'); $mine = $rec.me
  $who = ([string]$rec.sender) -replace '-.*$', ''
  if ($rec.t -like 'BN_*') { $who = Plain $rec.sender }
  $nameHex = $(if ($rec.cls) { $rec.cls } else { 'ffd27a' })
  if ($mine) { $nameHex = 'ffe9b8' }   # (2026-10-30) 내가 쓴 글은 직업 상관없이 이름을 음성 번역 글자와 같은 금빛으로
  $mc = $FEEDT[$rec.t]
  if ([string]$rec.t -eq 'CHANNEL' -and (No-TrChan $rec.cname)) { $mc = '6fd3ff' }   # (2026-11-05) 가운데 파티글에서도 krus 글은 하늘색
  $FL = @{ box = $box; main = $main; sub = $sub; at = [DateTime]::Now; rec = $rec; mc = $mc; who = $who; nameHex = $nameHex; pre = $(if ($whisper -and $mine) { '→ ' } else { '' }); tag = $(if ($whisper -and $rec.t -notlike 'BN_*') { $rec.sender } else { $null }) }
  Feed-Text $FL (Plain $rec.msg)
  Feed-Push $FL
  if (-not $Feed.win.IsVisible) { $Feed.win.Show() }
  Feed-Place
  return $FL
}
# (2026-11-02) 글 속 [아이템 이름]을 원문 링크와 맞춰 누를 수 있는 조각으로 (가운데 파티 대화 줄용 · 원문이든 번역문이든)
function Add-LinkedText($tb, [string]$text, $col, [string]$raw) {
  $lkm = @{}
  if ($raw) { foreach ($p in (Parse-Wow $raw $col)) { if ($p[2] -and ([string]$p[0]) -match '^\[.+\]$' -and -not $lkm.ContainsKey([string]$p[0])) { $lkm[[string]$p[0]] = @([string]$p[2], $p[1]) } } }
  $pos = 0
  if ($lkm.Count -gt 0) {
    foreach ($mm in [regex]::Matches($text, '\[[^\[\]]+\]')) {
      if (-not $lkm.ContainsKey($mm.Value)) { continue }
      if ($mm.Index -gt $pos) { [void](Add-Run $tb $text.Substring($pos, $mm.Index - $pos) $col $null) }
      $lv = $lkm[$mm.Value]; [void](Add-Run $tb $mm.Value $lv[1] @{ link = $lv[0] })
      $pos = $mm.Index + $mm.Length
    }
  }
  if ($pos -lt $text.Length) { [void](Add-Run $tb $text.Substring($pos) $col $null) }
}
function Feed-Text($FL, [string]$text) {
  $FL.main.Inlines.Clear()
  if ($FL.pre) { [void](Add-Run $FL.main $FL.pre 'ff80ff' $null) }
  $nr = Add-Run $FL.main $FL.who $FL.nameHex $FL.tag
  [void](Add-Run $FL.main '  ' $FL.mc $null)
  Add-LinkedText $FL.main $text $FL.mc ([string]$FL.rec.msg)
}
function Feed-Tr($FL, [string]$ko, [string]$src) {
  if (-not $FL -or -not $FL.box) { return }
  Feed-Text $FL $ko
  $FL.sub.Text = $src; $FL.sub.Visibility = 'Visible'
}
function Feed-Tick {
  if ($script:fedit) { try { FEd-Tick } catch { Log "파티글 조절: $_" }; return }
  if (-not $Feed.win -or -not $Feed.win.IsVisible) { return }
  $now = [DateTime]::Now
  for ($i = $Feed.list.Count - 1; $i -ge 0; $i--) {
    if ($Feed.histOn) { break }   # (2026-11-02) 지난 대화 보는 중엔 사라지기 멈춤
    $FL = $Feed.list[$i]; $t = ($now - $FL.at).TotalSeconds
    $fs = [int]$S.feedSec; if ($fs -lt 5) { $fs = 15 }   # (2026-11-13 대표) 파티글 사라짐 = [조절하기]에서 (기본 15초)
    $o = $(if ($t -lt 0.2) { $t / 0.2 } elseif ($t -gt $fs) { 1 - ($t - $fs) / 0.6 } else { 1 })   # (2026-10-30) 10초 → 15초 (요청)
    if ($FL.voice) { $o = $(if ($t -gt $fs) { 0 } else { 1 }) }   # (2026-10-26) 음성 줄은 서서히 효과 없이 바로 (투명 창 다시 그리기를 줄여 게임 끊김 방지)
    if ($o -le 0) { $Feed.sp.Children.Remove($FL.box); $Feed.list.RemoveAt($i); continue }
    $FL.box.Opacity = $o
  }
  # 칸 높이를 넘으면 맨 위(오래된) 줄부터 바로 뺌
  if (-not $Feed.histOn) { try {
    $Feed.sp.UpdateLayout()
    $tot = 0.0; foreach ($FL2 in $Feed.list) { $tot += $FL2.box.DesiredSize.Height }   # (줄마다 실제 필요한 높이 합)
    while ($Feed.list.Count -gt 1 -and $tot -gt $Feed.win.Height + 1) { $tot -= $Feed.list[0].box.DesiredSize.Height; $Feed.sp.Children.Remove($Feed.list[0].box); $Feed.list.RemoveAt(0) }
  } catch {} }
  if ($Feed.list.Count -eq 0 -and -not $Feed.histOn -and $Feed.hist.Count -eq 0) { $Feed.win.Hide(); return }   # (2026-11-02) 지난 대화가 있으면 빈 칸도 휠 받게 남겨 둠
  # 귓말 이름 위에 마우스가 오면 그때만 클릭 받기 (나머지는 뒤의 게임으로 통과)
  $over = $false; $Feed.hot = $null; $Feed.region = $false
  # 와우를 보고 있을 때만 보이기 (다른 프로그램 위에는 안 뜨게)
  $fg = [FTR]::Foreground(); $wh = [FTR]::FindWow()
  $Feed.win.Opacity = $(if ($fg -eq $wh -or $fg -eq $script:hwnd -or $fg -eq $Feed.hwnd -or $fg -eq $Lfg.hwnd -or ($CIn.hwnd -ne [IntPtr]::Zero -and $fg -eq $CIn.hwnd)) { 1 } else { 0 })   # (2026-10-30) 가운데 입력칸에 쓰는 중에도 파티 줄은 계속 보이게
  try {
    $c = [FTR]::Cursor(); $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
    $pt = $Feed.win.PointFromScreen((New-Object System.Windows.Point($c[0], $c[1])))
    $inBox = ($pt.X -ge 0 -and $pt.Y -ge 0 -and $pt.X -le $Feed.win.ActualWidth -and $pt.Y -le $Feed.win.ActualHeight)
    if ($inBox -and $Feed.hist.Count -gt 0 -and $Feed.win.Opacity -ge 1) {   # 와우를 보고 있을 때만 (다른 프로그램 위에선 클릭 안 막음)
      $show = $true; try { $show = [FTRK.Cur]::Showing() } catch {}; if ($show) { $Feed.region = $true } }
    if ($inBox) {
      foreach ($bx in @($Feed.sp.Children)) {
        $FL = $bx.Tag; if (-not ($FL -is [hashtable]) -or -not $FL.main) { continue }
        $pos = $FL.main.GetPositionFromPoint(($Feed.win.TranslatePoint($pt, $FL.main)), $false)
        if ($pos -and $pos.Parent -is [System.Windows.Documents.Run] -and $pos.Parent.Tag) { $over = $true; $Feed.hot = $pos.Parent.Tag; break }
      }
    }
  } catch {}
  # (2026-11-02) 전투 중엔 휠·클릭을 전부 게임으로 (전투 신호가 끊겨도 10분 지나면 풀림)
  if ($state.combat -and $state.combatAt -and ([DateTime]::Now - $state.combatAt).TotalMinutes -gt 10) { $state.combat = $false }
  if ($state.combat) { $over = $false; $Feed.region = $false; $Feed.hot = $null }
  # (2026-11-03) 게임에서 가운데 파티글 위치를 옮기는 중(/파티글·잠금 풀림)이면 클릭·끌기·Ctrl+오른쪽 클릭을 전부 게임으로
  if ((FGeo) -and (FGeo).mv) { $over = $false; $Feed.region = $false; $Feed.hot = $null }
  if ($state.popup) { $over = $false; $Feed.region = $false; $Feed.hot = $null }
  # (2026-11-03) 칸 전체는 휠만 (따로 도는 휠 감시가 받음) · 창이 클릭을 받는 건 귓말 이름 위일 때뿐
  try {
    $wOn = [bool]$Feed.region
    if ($wOn) { $q0 = $Feed.win.PointToScreen((New-Object System.Windows.Point(0, 0))); $q1 = $Feed.win.PointToScreen((New-Object System.Windows.Point($Feed.win.ActualWidth, $Feed.win.ActualHeight))); [FTRK.Wheel]::L = [int]$q0.X; [FTRK.Wheel]::T = [int]$q0.Y; [FTRK.Wheel]::R = [int]$q1.X; [FTRK.Wheel]::B = [int]$q1.Y }
    [FTRK.Wheel]::On = $wOn
    $wd = [FTRK.Wheel]::Take(); if ($wd -ne 0) { $wn = [math]::Max(1, [int]([math]::Abs($wd) / 120)); for ($wi = 0; $wi -lt [math]::Min($wn, 10); $wi++) { Feed-Wheel ([math]::Sign($wd) * 120) } }
  } catch {}
  $hit = $over
  if ($hit -eq $Feed.ct) { $Feed.ct = -not $hit; [FTR]::ClickThrough($Feed.hwnd, $Feed.ct) }
  # (2026-11-02) 빈 자리도 휠을 받으려면 아주 옅은 바탕이 있어야 함 (눈에는 안 보임) · 마우스가 칸 밖이면 다시 완전 투명
  if ($Feed.region -ne $Feed.bgOn) { $Feed.bgOn = $Feed.region; $Feed.win.Background = $(if ($Feed.region) { New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb(1, 0, 0, 0)) } else { [System.Windows.Media.Brushes]::Transparent }) }
  if ($Feed.histOn) { if ($Feed.region) { $Feed.histAt = [DateTime]::Now } elseif (([DateTime]::Now - $Feed.histAt).TotalSeconds -gt 8) { $Feed.histOn = $false; Feed-Hist } }
}

# ---------- (공유판) 가운데 파티글 위치 · 크기 조절 모드 ----------
#  설정 '위치 · 크기 [조절하기]' → 가운데 파티글 칸에 금색 점선 + 연습 글 · 끌기 = 이동 · 오른쪽 아래 네모 = 크기 · 아래 막대 [줄 수] [글자] [처음 자리로] [완료]
#  조절 중엔 그 칸 위 게임 클릭이 막힘 · ESC 또는 완료 = 끝 (저장) · 평소엔 지금처럼 클릭이 게임으로 통과
$script:fedit = $false; $script:fbox = $null; $script:fdrag = $null; $script:fdirty = $false
$FEd = @{ ov = $null; lab = $null; bar = $null; barHwnd = [IntPtr]::Zero; nL = $null; nF = $null; escAt = [DateTime]::MinValue }
function FEd-Start {
  if ($script:fedit) { return }
  $wow = [FTR]::FindWow(); if ($wow -eq [IntPtr]::Zero) { [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = '가운데 파티글 조절은 와우가 켜져 있을 때 할 수 있어요' }); return }
  $cr = [FTR]::ClientRect($wow); if (-not $cr) { return }
  $g = FGeo
  if (-not $g) { $s0 = 1.0; if ($state.geo -and $state.geo.s) { $s0 = [double]$state.geo.s }; $w0 = [int](360 * $s0); $g = @{ x = [int](($cr[2] - $w0) / 2); y = [int]($cr[3] * 0.45); w = $w0; h = [int](140 * $s0); s = $s0 } }
  $h0 = [int]$g.h; if ($h0 -le 0) { $h0 = [int](520 * [double]$g.s) }
  $script:fbox = @{ x = [int]$g.x; y = [int]$g.y; w = [int]$g.w; h = $h0 }
  $script:fdirty = $false; $script:fdrag = $null
  $script:fedit = $true
  try { [FTRK.Wheel]::On = $false } catch {}
  Feed-Make
  if (-not $FEd.ov) {
    $ov = New-Object System.Windows.Controls.Grid
    $rc = New-Object System.Windows.Shapes.Rectangle; $rc.Stroke = Br '#FFD9B26A'; $rc.StrokeThickness = 2; $dc = New-Object System.Windows.Media.DoubleCollection; $dc.Add(4.0); $dc.Add(3.0); $rc.StrokeDashArray = $dc; $rc.Fill = Br '#1AD9B26A'; $rc.RadiusX = 4; $rc.RadiusY = 4
    [void]$ov.Children.Add($rc)
    $lb = New-Object System.Windows.Controls.Border; $lb.Background = Br '#FFD9B26A'; $lb.CornerRadius = New-Object System.Windows.CornerRadius(3); $lb.Padding = New-Object System.Windows.Thickness(7, 1, 7, 2); $lb.HorizontalAlignment = 'Left'; $lb.VerticalAlignment = 'Top'; $lb.Margin = New-Object System.Windows.Thickness(6, 6, 0, 0); $lb.IsHitTestVisible = $false
    $lt = TB '' 11 (Br '#FF111111'); UIF $lt; $lb.Child = $lt; [void]$ov.Children.Add($lb)
    $gp = New-Object System.Windows.Controls.Border; $gp.Width = 16; $gp.Height = 16; $gp.Background = Br '#FFD9B26A'; $gp.CornerRadius = New-Object System.Windows.CornerRadius(2); $gp.HorizontalAlignment = 'Right'; $gp.VerticalAlignment = 'Bottom'; $gp.Cursor = [System.Windows.Input.Cursors]::SizeNWSE
    [void]$ov.Children.Add($gp)
    $ov.Cursor = [System.Windows.Input.Cursors]::SizeAll
    $FEd.ov = $ov; $FEd.lab = $lt
  }
  if (-not $Feed.grid.Children.Contains($FEd.ov)) { [void]$Feed.grid.Children.Add($FEd.ov) }
  FEd-Bar
  [FTR]::ClickThrough($Feed.hwnd, $false); $Feed.ct = $false
  $Feed.win.Background = [System.Windows.Media.Brushes]::Transparent; $Feed.bgOn = $false
  FEd-Samples
  if (-not $Feed.win.IsVisible) { $Feed.win.Show() }
  $Feed.win.Opacity = 1
  Feed-Place; FEd-Paint
  $FEd.escAt = [DateTime]::Now
  Log '가운데 파티글 조절 모드'
}
function FEd-Samples {
  $Feed.sp.Children.Clear()
  $k = $(if ($Feed.k) { $Feed.k } else { 1.2 })
  $samp = @(@('Thrall', '탱 먼저 풀 할 거임, 기다리셈', 'wait, tank pulls first'), @('Jaina', '마나 없음, 잠깐만', 'oom, 1 sec'), @('나', 'ㅇㅋ 물 마시고 감', ''))
  for ($i = 0; $i -lt (Feed-Max); $i++) {
    $sm = $samp[$i % 3]
    $box = New-Object System.Windows.Controls.StackPanel; $box.Margin = New-Object System.Windows.Thickness(0, 0, 0, (10 * $k)); $box.IsHitTestVisible = $false
    $main = New-Object System.Windows.Controls.TextBlock; $main.FontFamily = $script:CFONT; $main.FontWeight = 'Bold'; $main.FontSize = (FeedFz) * $k; $main.TextWrapping = 'Wrap'; $main.TextAlignment = 'Center'
    [void](Add-Run $main $sm[0] $(if ($sm[0] -eq '나') { 'ffe9b8' } else { 'ffd27a' }) $null); [void](Add-Run $main ('  ' + $sm[1]) 'aad4ff' $null)
    [void]$box.Children.Add($main)
    if ($sm[2]) { $sub = New-Object System.Windows.Controls.TextBlock; $sub.FontFamily = $script:CFONT; $sub.FontWeight = 'Bold'; $sub.FontSize = (FeedFz) * 0.77 * $k; $sub.TextWrapping = 'Wrap'; $sub.TextAlignment = 'Center'; $sub.Foreground = HexBr 'c9c2b0'; $sub.Opacity = 0.85; $sub.Margin = New-Object System.Windows.Thickness(0, (3 * $k), 0, 0); $sub.Text = $sm[2]; [void]$box.Children.Add($sub) }
    [void]$Feed.sp.Children.Add($box)
  }
}
function Feed-Sec { $v = [int]$S.feedSec; if ($v -lt 5) { $v = 15 }; return $v }
function FEd-Paint {
  try { if ($FEd.lab) { $FEd.lab.Text = ('폭 {0} · {1}줄 · 글자 {2}' -f [int]$script:fbox.w, (Feed-Max), [int](FeedFz)) } } catch {}
  try { if ($FEd.nL) { $FEd.nL.Text = [string](Feed-Max) }; if ($FEd.nF) { $FEd.nF.Text = [string][int](FeedFz) }; if ($FEd.nS) { $FEd.nS.Text = ([string](Feed-Sec) + '초') } } catch {}
  try {
    if ($FEd.bar -and $Feed.win) {
      $FEd.bar.UpdateLayout()
      $FEd.bar.Left = $Feed.win.Left + ($Feed.win.Width - $FEd.bar.ActualWidth) / 2
      $tp = $Feed.win.Top + $Feed.win.Height + 8
      if ($tp + $FEd.bar.ActualHeight -gt [System.Windows.SystemParameters]::VirtualScreenHeight) { $tp = $Feed.win.Top - $FEd.bar.ActualHeight - 8 }
      $FEd.bar.Top = $tp
    }
  } catch {}
}
function FEd-BtnMake($sp, [string]$label, [string]$tag, [bool]$warm = $false) {
  $b = New-Object System.Windows.Controls.Border; $b.CornerRadius = New-Object System.Windows.CornerRadius(4); $b.Padding = New-Object System.Windows.Thickness(9, 3, 9, 4); $b.Margin = New-Object System.Windows.Thickness(3, 0, 3, 0); $b.VerticalAlignment = 'Center'; $b.Cursor = [System.Windows.Input.Cursors]::Hand
  $b.Background = $(if ($warm) { Br '#E6B98E5F' } else { Br '#1AFFFFFF' })
  $t = TB $label 11.5 $(if ($warm) { Br '#FF141414' } else { $CREAM }); UIF $t; $b.Child = $t; $b.Tag = $tag
  $b.Add_MouseLeftButtonDown({ param($snd, $ev) $ev.Handled = $true })
  $b.Add_MouseLeftButtonUp({ param($snd, $ev) try { FEd-Btn ([string]$snd.Tag) } catch { Log "파티글 조절 버튼: $_" }; $ev.Handled = $true })
  [void]$sp.Children.Add($b)
  return $t
}
function FEd-Bar {
  if (-not $FEd.bar) {
    $w = New-Object System.Windows.Window
    $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
    $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'; $w.UseLayoutRounding = $true
    $bd = New-Object System.Windows.Controls.Border; $bd.Background = Br '#F0111112'; $bd.BorderBrush = Br '#1FFFFFFF'; $bd.BorderThickness = New-Object System.Windows.Thickness(1); $bd.CornerRadius = New-Object System.Windows.CornerRadius(6); $bd.Padding = New-Object System.Windows.Thickness(8, 6, 8, 6)
    $bd.LayoutTransform = $Scale
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    $hint = TB '끌기 = 이동 · 오른쪽 아래 네모 = 크기' 10.5 $MUTED; UIF $hint; $hint.VerticalAlignment = 'Center'; $hint.Margin = New-Object System.Windows.Thickness(2, 0, 10, 0); [void]$sp.Children.Add($hint)
    $l1 = TB '줄 수' 11.5 $SUBC; UIF $l1; $l1.VerticalAlignment = 'Center'; $l1.Margin = New-Object System.Windows.Thickness(4, 0, 2, 0); [void]$sp.Children.Add($l1)
    [void](FEd-BtnMake $sp ([string][char]0x2212) 'l-')
    $FEd.nL = TB '' 12 $GOLD; $FEd.nL.VerticalAlignment = 'Center'; $FEd.nL.MinWidth = 18; $FEd.nL.TextAlignment = 'Center'; [void]$sp.Children.Add($FEd.nL)
    [void](FEd-BtnMake $sp '+' 'l+')
    $l2 = TB '글자' 11.5 $SUBC; UIF $l2; $l2.VerticalAlignment = 'Center'; $l2.Margin = New-Object System.Windows.Thickness(12, 0, 2, 0); [void]$sp.Children.Add($l2)
    [void](FEd-BtnMake $sp ([string][char]0x2212) 'f-')
    $FEd.nF = TB '' 12 $GOLD; $FEd.nF.VerticalAlignment = 'Center'; $FEd.nF.MinWidth = 18; $FEd.nF.TextAlignment = 'Center'; [void]$sp.Children.Add($FEd.nF)
    [void](FEd-BtnMake $sp '+' 'f+')
    $l3 = TB '사라짐' 11.5 $SUBC; UIF $l3; $l3.VerticalAlignment = 'Center'; $l3.Margin = New-Object System.Windows.Thickness(12, 0, 2, 0); [void]$sp.Children.Add($l3)
    [void](FEd-BtnMake $sp ([string][char]0x2212) 's-')
    $FEd.nS = TB '' 12 $GOLD; $FEd.nS.VerticalAlignment = 'Center'; $FEd.nS.MinWidth = 30; $FEd.nS.TextAlignment = 'Center'; [void]$sp.Children.Add($FEd.nS)
    [void](FEd-BtnMake $sp '+' 's+')
    $gap = New-Object System.Windows.Controls.Border; $gap.Width = 10; [void]$sp.Children.Add($gap)
    [void](FEd-BtnMake $sp '처음 자리로' 'reset')
    [void](FEd-BtnMake $sp '완료' 'done' $true)
    $bd.Child = $sp; $w.Content = $bd
    $FEd.bar = $w
    $w.Show(); $FEd.barHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle; [FTR]::NoActivate($FEd.barHwnd, $true)
  }
  if (-not $FEd.bar.IsVisible) { $FEd.bar.Show() }
}
function FEd-Btn([string]$t) {
  switch ($t) {
    'l-' { $S.feedLines = [math]::Max(1, (Feed-Max) - 1); Save-Cfg; FEd-Samples }
    'l+' { $S.feedLines = [math]::Min(12, (Feed-Max) + 1); Save-Cfg; FEd-Samples }
    'f-' { $Feed.font = [math]::Max(9, [int](FeedFz) - 1); $GC.cfont = [int]$Feed.font; Game-Cmd ''; FEd-Samples }
    'f+' { $Feed.font = [math]::Min(24, [int](FeedFz) + 1); $GC.cfont = [int]$Feed.font; Game-Cmd ''; FEd-Samples }
    's-' { $S.feedSec = [math]::Max(5, (Feed-Sec) - 5); Save-Cfg }
    's+' { $S.feedSec = [math]::Min(60, (Feed-Sec) + 5); Save-Cfg }
    'reset' {
      if ($S.ContainsKey('feedBox')) { [void]$S.Remove('feedBox') }
      $S.feedLines = 7; Save-Cfg; $script:fdirty = $false
      Game-Cmd '/ntchat feedreset'   # 게임 속 파티글·가운데 입력칸도 처음 자리로
      $g = $Feed.geo
      if ($g) { $h0 = [int]$g.h; if ($h0 -le 0) { $h0 = [int](520 * [double]$g.s) }; $script:fbox = @{ x = [int]$g.x; y = [int]$g.y; w = [int]$g.w; h = $h0 } }
      else { $cr = $null; $wow = [FTR]::FindWow(); if ($wow -ne [IntPtr]::Zero) { $cr = [FTR]::ClientRect($wow) }; if ($cr) { $w0 = [int]$script:fbox.w; $script:fbox = @{ x = [int](($cr[2] - $w0) / 2); y = [int]($cr[3] * 0.45); w = $w0; h = [int]$script:fbox.h } } }
      Feed-Place; FEd-Samples
    }
    'done' { FEd-End; return }
  }
  FEd-Paint
}
function FEd-Down($ev) {
  $pt = $ev.GetPosition($Feed.win)
  $mode = $(if ($pt.X -ge $Feed.win.ActualWidth - 20 -and $pt.Y -ge $Feed.win.ActualHeight - 20) { 'size' } else { 'move' })
  $script:fdrag = @{ m = $mode; c0 = [FTR]::Cursor(); b0 = $script:fbox.Clone() }
  [void]$Feed.win.CaptureMouse()
}
function FEd-Move {
  $d = $script:fdrag; if (-not $d) { return }
  $c = [FTR]::Cursor(); $dx = $c[0] - $d.c0[0]; $dy = $c[1] - $d.c0[1]
  $b = $d.b0.Clone()
  $cr = $null; $wow = [FTR]::FindWow(); if ($wow -ne [IntPtr]::Zero) { $cr = [FTR]::ClientRect($wow) }
  if ($d.m -eq 'move') {
    $b.x = [int]$d.b0.x + $dx; $b.y = [int]$d.b0.y + $dy
    if ($cr) { $b.x = [int][math]::Min([math]::Max(0, $b.x), [math]::Max(0, $cr[2] - [int]$b.w)); $b.y = [int][math]::Min([math]::Max([int]$b.h, $b.y), $cr[3]) }
  } else {
    $nw = [int][math]::Max(160, [int]$d.b0.w + $dx); $nh = [int][math]::Max(60, [int]$d.b0.h + $dy)
    $b.w = $nw; $b.h = $nh; $b.y = [int]$d.b0.y + ($nh - [int]$d.b0.h)
  }
  $script:fbox = $b; $script:fdirty = $true
  Feed-Place; FEd-Paint
}
function FEd-Tick {
  if (-not $Feed.win) { return }
  if ([FTR]::FindWow() -eq [IntPtr]::Zero) { FEd-End; return }
  if (-not $Feed.win.IsVisible) { $Feed.win.Show() }
  if ($Feed.win.Opacity -lt 1) { $Feed.win.Opacity = 1 }
  try { [FTRK.Wheel]::On = $false } catch {}
  # ESC = 끝 (조절 모드를 켠 직후 0.4초는 무시)
  if ((([DateTime]::Now - $FEd.escAt).TotalMilliseconds -gt 400) -and (([FTRK.Keys]::GetAsyncKeyState(0x1B) -band 0x8000) -ne 0)) { FEd-End; return }
}
function FEd-End {
  if (-not $script:fedit) { return }
  if ($script:fdirty -and $script:fbox) { $S.feedBox = $script:fbox.Clone(); Save-Cfg; Game-Cmd ('/ntchat feedpos {0} {1} {2} {3}' -f [int]$script:fbox.x, [int]$script:fbox.y, [int]$script:fbox.w, [int]$script:fbox.h); Log ('가운데 파티글 자리 저장: x {0} · y {1} · 폭 {2} · 높이 {3}' -f $script:fbox.x, $script:fbox.y, $script:fbox.w, $script:fbox.h) }
  $script:fedit = $false; $script:fdrag = $null; $script:fbox = $null
  try { $Feed.win.ReleaseMouseCapture() } catch {}
  try { if ($FEd.ov -and $Feed.grid.Children.Contains($FEd.ov)) { [void]$Feed.grid.Children.Remove($FEd.ov) } } catch {}
  try { if ($FEd.bar) { $FEd.bar.Hide() } } catch {}
  try { [FTR]::ClickThrough($Feed.hwnd, $true); $Feed.ct = $true } catch {}
  Feed-Hist; Feed-Place
}

# ---------- (공유판) 위쪽 도우미 바: 와우 화면 위쪽 가운데 · [번역 켜짐/꺼짐] + GPU · VRAM · CPU · RAM (1초마다) ----------
#  와우(또는 이 프로그램 창)가 앞에 있을 때만 보임 · 알약 클릭 = 번역 켜기/끄기 (번역대화창 알약·미니맵 버튼과 같은 상태)
$Bar = @{ win = $null; hwnd = [IntPtr]::Zero; at = [DateTime]::MinValue; hub = $null; dot = $null; hubT = $null; v = @{} }
# (2026-11-08 대표) 대표님 도우미 바 모양 그대로 (A안) · 앞의 금색 둥근 아이콘은 빼고 · 알약 두 개: [GPU 사용량·온도 | CPU | RAM] [● 번역]
function Bar-Pill {
  $b = New-Object System.Windows.Controls.Border; $b.Height = 30; $b.CornerRadius = New-Object System.Windows.CornerRadius(15)
  $b.Background = Br '#E6181A1E'; $b.VerticalAlignment = 'Center'
  $e = New-Object System.Windows.Media.Effects.DropShadowEffect; $e.Color = [System.Windows.Media.Colors]::Black; $e.BlurRadius = 10; $e.ShadowDepth = 2; $e.Opacity = 0.55; $e.Direction = 270; $b.Effect = $e
  return $b
}
function Bar-Lab([string]$t) { $l = New-Object System.Windows.Controls.TextBlock; $l.Text = $t; $l.Foreground = Br '#FF8C7A52'; $l.FontSize = 9; $l.FontWeight = 'Bold'; $l.FontFamily = 'Segoe UI'; $l.VerticalAlignment = 'Center'; $l.Margin = New-Object System.Windows.Thickness(0, 1, 5, 0); return $l }
function Bar-Val([string]$hex, [double]$minW) { $v = New-Object System.Windows.Controls.TextBlock; $v.Text = '--'; $v.Foreground = Br $hex; $v.FontSize = 12; $v.FontWeight = 'SemiBold'; $v.FontFamily = 'Segoe UI'; $v.VerticalAlignment = 'Center'; $v.MinWidth = $minW; $v.TextAlignment = 'Right'; return $v }
function Bar-Sep { $r = New-Object System.Windows.Shapes.Rectangle; $r.Width = 1; $r.Height = 12; $r.Fill = Br '#40E8C76A'; $r.Margin = New-Object System.Windows.Thickness(10, 0, 10, 0); $r.VerticalAlignment = 'Center'; return $r }
function Bar-Make {
  if ($Bar.win) { return }
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
  $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'; $w.UseLayoutRounding = $true; $w.SnapsToDevicePixels = $true
  $root = New-Object System.Windows.Controls.StackPanel; $root.Orientation = 'Horizontal'; $root.Margin = New-Object System.Windows.Thickness(10, 4, 10, 12)   # 그림자 자리
  # (2026-11-13 대표) 도우미 바는 대표님 도우미 바와 같은 크기 — 와우 UI 배율($Scale)로 키우지 않음
  # 컴퓨터 상태 알약
  $sys = Bar-Pill; $sys.Padding = New-Object System.Windows.Thickness(12, 0, 12, 0)
  $sys.ToolTip = '그래픽카드 사용량 · 온도 / CPU 사용량 / 메모리(RAM) 사용량'
  $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'; $sp.VerticalAlignment = 'Center'
  [void]$sp.Children.Add((Bar-Lab 'GPU')); $Bar.v.GPU = Bar-Val '#FFE0B95A' 28; [void]$sp.Children.Add($Bar.v.GPU)
  $Bar.v.TEMP = Bar-Val '#FFF6E7BE' 24; $Bar.v.TEMP.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0); [void]$sp.Children.Add($Bar.v.TEMP)
  [void]$sp.Children.Add((Bar-Sep))
  [void]$sp.Children.Add((Bar-Lab 'CPU')); $Bar.v.CPU = Bar-Val '#FFE0B95A' 28; [void]$sp.Children.Add($Bar.v.CPU)
  [void]$sp.Children.Add((Bar-Sep))
  [void]$sp.Children.Add((Bar-Lab 'RAM')); $Bar.v.RAM = Bar-Val '#FFE0B95A' 28; [void]$sp.Children.Add($Bar.v.RAM)
  $sys.Child = $sp; [void]$root.Children.Add($sys)
  # 번역 알약 (● 번역 · 켜짐 = 초록 점 빛남)
  # (2026-11-13 대표) 대표님 도우미 바처럼 [번역 | 설정]을 알약 하나에 (항목 사이 가는 금빛 줄)
  $one = Bar-Pill; $one.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0); $one.Padding = New-Object System.Windows.Thickness(4, 0, 4, 0)
  $osp = New-Object System.Windows.Controls.StackPanel; $osp.Orientation = 'Horizontal'; $osp.VerticalAlignment = 'Center'; $one.Child = $osp; [void]$root.Children.Add($one)
  function Bar-ISep { $r = New-Object System.Windows.Shapes.Rectangle; $r.Width = 1; $r.Height = 12; $r.Fill = Br '#40E8C76A'; $r.Margin = New-Object System.Windows.Thickness(3, 0, 3, 0); $r.VerticalAlignment = 'Center'; return $r }
  $hub = New-Object System.Windows.Controls.Border; $hub.Background = [System.Windows.Media.Brushes]::Transparent; $hub.Cursor = [System.Windows.Input.Cursors]::Hand
  $it = New-Object System.Windows.Controls.Border; $it.CornerRadius = New-Object System.Windows.CornerRadius(11); $it.Padding = New-Object System.Windows.Thickness(7, 3, 8, 3); $it.Background = [System.Windows.Media.Brushes]::Transparent; $it.VerticalAlignment = 'Center'
  $isp = New-Object System.Windows.Controls.StackPanel; $isp.Orientation = 'Horizontal'
  $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 7; $dot.Height = 7; $dot.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0); $dot.VerticalAlignment = 'Center'
  $ht = New-Object System.Windows.Controls.TextBlock; $ht.Text = '번역'; $ht.FontSize = 11.5; $ht.FontFamily = 'Malgun Gothic'; $ht.FontWeight = 'SemiBold'; $ht.VerticalAlignment = 'Center'
  [void]$isp.Children.Add($dot); [void]$isp.Children.Add($ht); $it.Child = $isp; $hub.Child = $it
  # (2026-11-13 대표) [번역]과 [설정] 칸 너비를 똑같이 (번역 쪽 불빛 점 때문에 짝짝이로 보였음) · 글은 칸 가운데
  $isp.HorizontalAlignment = 'Center'; $it.Width = 58; $it.Padding = New-Object System.Windows.Thickness(0, 3, 0, 3)
  $hub.Add_MouseEnter({ try { $Bar.hubIt.Background = Br '#14FFFFFF' } catch {} })
  $hub.Add_MouseLeave({ try { $Bar.hubIt.Background = [System.Windows.Media.Brushes]::Transparent } catch {} })
  $hub.Add_MouseLeftButtonDown({ param($snd, $ev) $ev.Handled = $true })
  $hub.Add_MouseLeftButtonUp({ param($snd, $ev) try { Tr-Set ([bool]$S.pause) } catch { Log "도우미 바 번역 버튼: $_" }; $ev.Handled = $true })
  [void]$osp.Children.Add($hub); [void]$osp.Children.Add((Bar-ISep))
  $Bar.hub = $hub; $Bar.hubIt = $it; $Bar.dot = $dot; $Bar.hubT = $ht
  # (2026-11-13 대표) [사전] 알약은 뺌 — 사전은 자동 업데이트 · 켜기/끄기와 '지금 확인'은 [설정] 메뉴에
  # (2026-11-12 대표) 도우미 바 오른쪽 클릭 = 옵션 (윈도우 시작 시 자동 실행 · 사전 새로 확인)
  $cm = New-Object System.Windows.Controls.ContextMenu
  $miA = New-Object System.Windows.Controls.MenuItem; $miA.Header = '윈도우 시작 시 자동 실행'; $miA.IsCheckable = $true
  $miA.Add_Click({ param($snd, $ev) try { Auto-Set ([bool]$snd.IsChecked) } catch { Log "자동 실행 메뉴: $_" } })
  $miU = New-Object System.Windows.Controls.MenuItem; $miU.Header = '번역 사전 자동 업데이트'; $miU.IsCheckable = $true
  $miU.Add_Click({ param($snd, $ev) try { $S.dictAuto = [bool]$snd.IsChecked; Save-Cfg; if ($S.dictAuto) { Dict-Check } } catch { Log "사전 자동 메뉴: $_" } })
  $miD = New-Object System.Windows.Controls.MenuItem; $miD.Header = '업데이트 지금 확인 (사전·프로그램)'
  $miD.Add_Click({ try { $Dict.manual = $true; Dict-Check } catch {}; try { Upd-Check } catch {} })   # (2026-11-13) 프로그램 새 버전도 같이 확인
  $miH = New-Object System.Windows.Controls.MenuItem; $miH.Header = '설명서 열기 (사용법·자주 묻는 질문)'
  $miH.Add_Click({ try { Start-Process 'https://zerazine.github.io/nangman-translator/' } catch { Log "설명서 열기: $_" } })
  # (2026-11-13 대표) 도우미 바 자동 숨기기(마우스 올리면 나타남) · 위치 고정/풀기(풀면 끌어서 아무 데나) · 처음 자리로
  $miHide = New-Object System.Windows.Controls.MenuItem; $miHide.Header = '도우미 바 자동 숨기기 (마우스 올리면 나타남)'; $miHide.IsCheckable = $true
  $miHide.Add_Click({ param($snd, $ev) try { $S.barAuto = [bool]$snd.IsChecked; Save-Cfg; $Bar.hovAt = [DateTime]::Now } catch { Log "자동 숨기기 메뉴: $_" } })
  $miLock = New-Object System.Windows.Controls.MenuItem; $miLock.Header = '도우미 바 위치 고정 (끄면 끌어서 옮기기)'; $miLock.IsCheckable = $true
  $miLock.Add_Click({ param($snd, $ev) try { $S.barFree = -not [bool]$snd.IsChecked; Save-Cfg; Bar-LockLook } catch { Log "위치 고정 메뉴: $_" } })
  $miHome = New-Object System.Windows.Controls.MenuItem; $miHome.Header = '도우미 바 처음 자리로'
  $miHome.Add_Click({ try { $S.Remove('barDx'); $S.Remove('barDy'); Save-Cfg; $Bar.at = [DateTime]::MinValue; Bar-Tick } catch { Log "처음 자리 메뉴: $_" } })
  $miQ = New-Object System.Windows.Controls.MenuItem; $miQ.Header = '번역기 끄기'   # (2026-11-13 대표) 도우미 바에서 바로 끌 수 있게 (게임 애드온이 없을 때도)
  $miQ.Add_Click({ try { Tr-Quit } catch { Log "번역기 끄기 메뉴: $_" } })
  $miV = New-Object System.Windows.Controls.MenuItem; $miV.IsEnabled = $false; $miV.Header = '버전'   # (2026-11-13 대표) 메뉴 맨 위에 '버전 1.xx'
  # (2026-11-14 대표) 그 아래 '번역 사전 · 2026.11.14' (받은 지 하루 안이면 금색 NEW) · 두 줄 다 보기만 하는 줄 (이름은 연하게 · 값은 금색)
  $miDV = New-Object System.Windows.Controls.MenuItem; $miDV.IsEnabled = $false; $miDV.Header = '번역 사전'
  foreach ($m in @($miV, $miDV)) { $m.Cursor = [System.Windows.Input.Cursors]::Arrow; $m.Padding = New-Object System.Windows.Thickness(0) }
  function Menu-Info($label, $val, [bool]$isNew) {
    $tb = New-Object System.Windows.Controls.TextBlock; $tb.FontSize = 11.5; $tb.VerticalAlignment = 'Center'
    $r1 = New-Object System.Windows.Documents.Run(($label + ' · ')); $r1.Foreground = Br '#FFB8A57A'; [void]$tb.Inlines.Add($r1)
    $r2 = New-Object System.Windows.Documents.Run($val); $r2.Foreground = Br '#FFE0B95A'; [void]$tb.Inlines.Add($r2)
    if ($isNew) {
      # (2026-11-14 대표) NEW 글자 정렬: 글꼴 위아래 여백 때문에 한쪽으로 쏠림 → 글자 모양(잉크) 자체를 정확히 가운데에 놓음
      $ft = New-Object System.Windows.Media.FormattedText('NEW', [Globalization.CultureInfo]::InvariantCulture, [System.Windows.FlowDirection]::LeftToRight, (New-Object System.Windows.Media.Typeface((New-Object System.Windows.Media.FontFamily('Segoe UI')), [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::Bold, [System.Windows.FontStretches]::Normal)), 7.5, (Br '#FF141518'))
      $gb = $ft.BuildGeometry((New-Object System.Windows.Point(0, 0))).Bounds
      $geo = $ft.BuildGeometry((New-Object System.Windows.Point((-$gb.X), (-$gb.Y))))   # 글자 잉크가 (0,0)에서 시작하게 → 좌우·위아래 여백 똑같이
      $pa = New-Object System.Windows.Shapes.Path; $pa.Data = $geo; $pa.Fill = Br '#FF141518'; $pa.HorizontalAlignment = 'Center'; $pa.VerticalAlignment = 'Center'; $pa.SnapsToDevicePixels = $true
      $bd = New-Object System.Windows.Controls.Border; $bd.Background = Br '#FFE0B95A'; $bd.CornerRadius = New-Object System.Windows.CornerRadius(4); $bd.Height = 11; $bd.Width = [Math]::Round($gb.Width) + 8; $bd.CornerRadius = New-Object System.Windows.CornerRadius(3); $bd.Margin = New-Object System.Windows.Thickness(7, 0, 0, 0); $bd.SnapsToDevicePixels = $true; $bd.Child = $pa
      $iu = New-Object System.Windows.Documents.InlineUIContainer($bd); $iu.BaselineAlignment = 'Center'; [void]$tb.Inlines.Add($iu)
    }
    return $tb
  }
  function Dict-LocalDate {
    $d = [string]$S.dictDate
    if (-not $d) { try { $d = (Get-Item -LiteralPath $TrCfgFile).LastWriteTime.ToString('yyyy-MM-dd') } catch { $d = '' } }
    return ($d -replace '-', '.')
  }
  [void]$cm.Items.Add($miV); [void]$cm.Items.Add($miDV); [void]$cm.Items.Add((New-Object System.Windows.Controls.Separator)); [void]$cm.Items.Add($miA); [void]$cm.Items.Add($miU); [void]$cm.Items.Add($miD); [void]$cm.Items.Add((New-Object System.Windows.Controls.Separator)); [void]$cm.Items.Add($miHide); [void]$cm.Items.Add($miLock); [void]$cm.Items.Add((New-Object System.Windows.Controls.Separator)); [void]$cm.Items.Add($miH)   # (2026-11-14 대표) '처음 자리로'·'번역기 끄기'는 뺌
  $cm.Add_Opened({ try { $Bar.miV.Header = (Menu-Info '낭만타우렌 번역기' ('버전 1.' + $APPV) $false) } catch {}; try { $na = $false; try { $na = (([DateTime]::Now - [DateTime]::Parse([string]$S.dictAt)).TotalHours -lt 24) } catch {}; $Bar.miDV.Header = (Menu-Info '번역 사전' (Dict-LocalDate) $na) } catch {}; try { $Bar.miA.IsChecked = (Auto-IsOn) } catch {}; try { $Bar.miU.IsChecked = ($S.dictAuto -ne $false) } catch {}; try { $Bar.miHide.IsChecked = [bool]$S.barAuto; $Bar.miLock.IsChecked = -not [bool]$S.barFree } catch {} })
  $root.ContextMenu = $cm; $Bar.miA = $miA; $Bar.miU = $miU; $Bar.cm = $cm; $Bar.miHide = $miHide; $Bar.miLock = $miLock; $Bar.miHome = $miHome; $Bar.miV = $miV; $Bar.miDV = $miDV
  # (2026-11-13 대표) 위치 고정을 풀면 도우미 바(컴퓨터 상태 칸 등 버튼 아닌 곳)를 끌어서 옮김 · 놓은 자리는 와우 창 기준으로 저장
  $Bar.root = $root
  $root.Add_MouseLeftButtonDown({ param($snd, $ev)
    if (-not [bool]$S.barFree) { return }
    try { $Bar.drag = $true; [System.Windows.Window]::GetWindow($snd).DragMove() } catch {} finally { $Bar.drag = $false }
    try { Bar-SavePos } catch { Log "도우미 바 자리 저장: $_" }
  })
  # (2026-11-13 대표) [설정] 메뉴도 검은 바탕 · 은은한 금테 · 둥근 모서리 (말풍선과 통일)
  try {
    $mx = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"><Style x:Key="DarkCM" TargetType="ContextMenu"><Setter Property="OverridesDefaultStyle" Value="True"/><Setter Property="HasDropShadow" Value="False"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ContextMenu"><Border Background="#F2141518" BorderBrush="#596E5A35" BorderThickness="1" CornerRadius="8" Padding="4" Margin="6"><Border.Effect><DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.5" Color="Black"/></Border.Effect><StackPanel IsItemsHost="True"/></Border></ControlTemplate></Setter.Value></Setter></Style><Style TargetType="MenuItem"><Setter Property="OverridesDefaultStyle" Value="True"/><Setter Property="Foreground" Value="#FFF3E2B3"/><Setter Property="FontFamily" Value="Malgun Gothic"/><Setter Property="FontSize" Value="12"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="MenuItem"><Border x:Name="Bd" Background="Transparent" CornerRadius="5" Padding="8,6,16,6"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock x:Name="Chk" Text="&#x2713;" Foreground="#FFE0B95A" FontWeight="Bold" Visibility="Hidden" VerticalAlignment="Center"/><ContentPresenter Grid.Column="1" ContentSource="Header" VerticalAlignment="Center" RecognizesAccessKey="True"/></Grid></Border><ControlTemplate.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter TargetName="Bd" Property="Background" Value="#FF24262B"/></Trigger><Trigger Property="IsChecked" Value="True"><Setter TargetName="Chk" Property="Visibility" Value="Visible"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style><Style TargetType="Separator"><Setter Property="OverridesDefaultStyle" Value="True"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Separator"><Border Height="1" Background="#33E8C76A" Margin="8,4,8,4"/></ControlTemplate></Setter.Value></Setter></Style></ResourceDictionary>
'@
    $mrd = [System.Windows.Markup.XamlReader]::Parse($mx); $cm.Style = $mrd['DarkCM']; [void]$cm.Resources.MergedDictionaries.Add($mrd)
  } catch { Log "설정 메뉴 모양: $_" }
  # (2026-11-12 대표) [설정] 알약 · 클릭 = 위 옵션 메뉴 (오른쪽 클릭과 같은 메뉴)
  $sp2 = New-Object System.Windows.Controls.Border; $sp2.Background = [System.Windows.Media.Brushes]::Transparent; $sp2.Cursor = [System.Windows.Input.Cursors]::Hand
  $sit = New-Object System.Windows.Controls.Border; $sit.CornerRadius = New-Object System.Windows.CornerRadius(11); $sit.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3); $sit.Background = [System.Windows.Media.Brushes]::Transparent; $sit.VerticalAlignment = 'Center'
  $stx = New-Object System.Windows.Controls.TextBlock; $stx.Text = '설정'; $stx.FontSize = 11.5; $stx.FontFamily = 'Malgun Gothic'; $stx.FontWeight = 'SemiBold'; $stx.VerticalAlignment = 'Center'; $stx.Foreground = Br '#FFF6E7BE'
  $stx.HorizontalAlignment = 'Center'; $sit.Width = 58; $sit.Padding = New-Object System.Windows.Thickness(0, 3, 0, 3)
  $sit.Child = $stx; $sp2.Child = $sit
  $sp2.Add_MouseEnter({ try { $Bar.sit.Background = Br '#14FFFFFF' } catch {} })
  $sp2.Add_MouseLeave({ try { $Bar.sit.Background = [System.Windows.Media.Brushes]::Transparent } catch {} })
  $sp2.Add_MouseLeftButtonDown({ param($snd, $ev) $ev.Handled = $true })
  $sp2.Add_MouseLeftButtonUp({ param($snd, $ev) try { $Bar.cm.PlacementTarget = $Bar.sp2; $Bar.cm.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom; $Bar.cm.IsOpen = $true } catch { Log "설정 버튼: $_" }; $ev.Handled = $true })
  [void]$osp.Children.Add($sp2)
  $Bar.sp2 = $sp2; $Bar.sit = $sit
  # (2026-11-13 대표) 도우미 바 말풍선(툴팁) = 검은 바탕 · 은은한 금테 · 둥근 모서리 · 마우스 올리면 바로
  try {
    $tipX = '<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ToolTip"><Setter Property="HasDropShadow" Value="False"/><Setter Property="FontFamily" Value="Malgun Gothic"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ToolTip"><Border Background="#F2141518" BorderBrush="#596E5A35" BorderThickness="1" CornerRadius="8" Padding="11,7" Margin="6"><Border.Effect><DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.5" Color="Black"/></Border.Effect><ContentPresenter TextElement.Foreground="#FFF3E2B3"/></Border></ControlTemplate></Setter.Value></Setter></Style>'
    $w.Resources.Add([System.Windows.Controls.ToolTip], [System.Windows.Markup.XamlReader]::Parse($tipX))
    foreach ($el in @($sys, $hub, $sp2, $root)) { if ($el) { [System.Windows.Controls.ToolTipService]::SetInitialShowDelay($el, 0); [System.Windows.Controls.ToolTipService]::SetBetweenShowDelay($el, 0) } }
  } catch { Log "도우미 바 말풍선: $_" }
  $w.Content = $root
  $Bar.win = $w
  $w.Show(); $Bar.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($w)).Handle; [FTR]::NoActivate($Bar.hwnd, $true); $w.Hide()
  Bar-Paint; Bar-LockLook
}
function Bar-LockLook {
  if (-not $Bar.root) { return }
  $Bar.root.Cursor = $(if ([bool]$S.barFree) { [System.Windows.Input.Cursors]::SizeAll } else { $null })
}
function Bar-SavePos {
  $wow = [FTR]::FindWow(); if ($wow -eq [IntPtr]::Zero) { return }
  $cr = [FTR]::ClientRect($wow); if (-not $cr) { return }
  $d = 1.0; if ($Bar.dpi) { $d = [double]$Bar.dpi }
  $S.barDx = [Math]::Round($Bar.win.Left - $cr[0] / $d, 1); $S.barDy = [Math]::Round($Bar.win.Top - $cr[1] / $d, 1)
  Save-Cfg
}
# (2026-11-13 대표) 자동 숨기기: 마우스가 도우미 바 위에 오면 나타나고, 벗어나면 0.5초 뒤 사라짐 (사라진 동안은 게임 클릭이 그대로 통과)
function Bar-Hover {
  if (-not $Bar.win) { return }
  $want = 1.0
  if ([bool]$S.barAuto -and $Bar.win.IsVisible) {
    $d = 1.0; if ($Bar.dpi) { $d = [double]$Bar.dpi }
    $p = [FTR]::Cursor(); $x = $p[0] / $d; $y = $p[1] / $d
    $l = $Bar.win.Left; $t = $Bar.win.Top; $r = $l + $Bar.win.ActualWidth; $b = $t + $Bar.win.ActualHeight
    $in = ($x -ge $l + 4 -and $x -le $r - 4 -and $y -ge $t - 2 -and $y -le $b - 6)
    if ($in -or $Bar.drag -or ($Bar.cm -and $Bar.cm.IsOpen)) { $Bar.hovAt = [DateTime]::Now }
    if (-not $Bar.hovAt -or ([DateTime]::Now - $Bar.hovAt).TotalMilliseconds -gt 500) { $want = 0.0 }
  }
  $o = $Bar.win.Opacity
  if ([Math]::Abs($o - $want) -gt 0.01) { $Bar.win.Opacity = $(if ($want -gt $o) { [Math]::Min(1.0, $o + 0.34) } else { [Math]::Max(0.0, $o - 0.2) }) }
}
$BarHT = New-Object Windows.Threading.DispatcherTimer; $BarHT.Interval = [TimeSpan]::FromMilliseconds(60)
$BarHT.Add_Tick({ try { Bar-Hover } catch {} }); $BarHT.Start()
function Bar-Paint {
  if (-not $Bar.dot) { return }
  $on = -not [bool]$S.pause
  if ($on) {
    $Bar.dot.Fill = Br '#FF6FE08A'
    $g = New-Object System.Windows.Media.Effects.DropShadowEffect; $g.Color = [System.Windows.Media.Color]::FromRgb(0x6F, 0xE0, 0x8A); $g.ShadowDepth = 0; $g.BlurRadius = 8; $g.Opacity = 0.9; $Bar.dot.Effect = $g
    $Bar.hubT.Foreground = Br '#FFF3E2B3'; $Bar.hub.ToolTip = '번역 · 켜짐 (클릭 = 끄기 · 와우 기본 대화창으로)'
  } else {
    $Bar.dot.Fill = Br '#FF4A4D55'; $Bar.dot.Effect = $null
    $Bar.hubT.Foreground = Br '#FF8C7A52'; $Bar.hub.ToolTip = '번역 · 꺼짐 (클릭 = 켜기)'
  }
  try { Dict-Paint } catch {}
}
function Bar-Set([string]$k, [string]$t) { $tb = $Bar.v[$k]; if ($tb -and $tb.Text -ne $t) { $tb.Text = $t } }
function Bar-Tick {
  $now = [DateTime]::Now
  if (($now - $Bar.at).TotalMilliseconds -lt 1000) { return }
  $Bar.at = $now
  Bar-Make
  $wow = [FTR]::FindWow(); $fg = [FTR]::Foreground()
  $mine = ($fg -eq $script:hwnd -or $fg -eq $Bar.hwnd -or $fg -eq $Feed.hwnd -or ($CIn.hwnd -ne [IntPtr]::Zero -and $fg -eq $CIn.hwnd) -or ($FEd.barHwnd -ne [IntPtr]::Zero -and $fg -eq $FEd.barHwnd))
  if ($wow -eq [IntPtr]::Zero -or -not ($fg -eq $wow -or $mine)) { if ($Bar.win.IsVisible) { $Bar.win.Hide() }; return }
  try { [FTRK.Stats]::Poll() } catch {}
  try {
    $gp = [int][FTRK.Stats]::Gpu; Bar-Set 'GPU' $(if ($gp -ge 0) { '{0}%' -f $gp } else { '--%' })
    $tc = [int][FTRK.Stats]::TempC; Bar-Set 'TEMP' $(if ($tc -ge 0) { '{0}{1}' -f $tc, [string][char]0xB0 } else { '--' + [string][char]0xB0 })
    $cp = [int][FTRK.Stats]::Cpu; Bar-Set 'CPU' $(if ($cp -ge 0) { '{0}%' -f $cp } else { '--%' })
    $ru = [double][FTRK.Stats]::RamUsedGB; $rt = [double][FTRK.Stats]::RamTotalGB
    Bar-Set 'RAM' $(if ($ru -ge 0 -and $rt -gt 0) { '{0}%' -f [int][Math]::Round(100.0 * $ru / $rt) } else { '--%' })
  } catch {}
  $cr = [FTR]::ClientRect($wow); if (-not $cr) { return }
  $dpi = 1.0; try { $dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch {}
  if (-not $Bar.win.IsVisible) { $Bar.win.Show() }
  $Bar.dpi = $dpi
  if ($Bar.drag) { return }
  if ($null -ne $S.barDx -and $null -ne $S.barDy) {
    # (2026-11-13 대표) 옮겨 둔 자리 (와우 창 기준) · 와우 창 밖으로는 안 나가게
    $L0 = $cr[0] / $dpi; $T0 = $cr[1] / $dpi; $W0 = $cr[2] / $dpi; $H0 = $cr[3] / $dpi
    $x = $L0 + [double]$S.barDx; $y = $T0 + [double]$S.barDy
    $x = [Math]::Max($L0 - 10, [Math]::Min($x, $L0 + $W0 - $Bar.win.ActualWidth + 10)); $y = [Math]::Max($T0 - 4, [Math]::Min($y, $T0 + $H0 - $Bar.win.ActualHeight + 12))
    $Bar.win.Left = $x; $Bar.win.Top = $y
  } else {
    $Bar.win.Left = ($cr[0] + $cr[2] / 2) / $dpi - $Bar.win.ActualWidth / 2
    $Bar.win.Top = $cr[1] / $dpi
  }
}
# 제미나이가 안 돼서 사비로 보낸 때 알림 한 줄 (30초에 한 번까지)
$script:fbAt = [DateTime]::MinValue
function Fb-Note([string]$why) {
  if (([DateTime]::Now - $script:fbAt).TotalSeconds -lt 30) { return }
  $script:fbAt = [DateTime]::Now
  try { $NL = Add-Line @{ kind = 'S'; col = 'ffb36b'; text = '제미나이 번역이 안 돼서 이 글은 자체 번역으로 보냈어요' }; if ($why) { Set-Sub $NL $null $why } } catch {}
}

# ---------- (공유판) 작은 안내 창 (처음 실행 저작권 안내 · 제미나이 키 넣기) — 번역창과 같은 어두운 판 ----------
$COPYRIGHT = '본 북미섭 와우 포에버 전용 번역프로그램의 저작권은 제작자 낭만타우렌 (배틀태그 하르만#31615)에 있으며 어떤 방식으로도 수정과 재배포가 불가합니다.'
$PRODUCT = '낭만타우렌 와우 포에버 번역기'
function New-Dlg([string]$title, [double]$width) {
  $w = New-Object System.Windows.Window
  $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
  $w.Topmost = $true; $w.ShowInTaskbar = $true; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'Height'; $w.Width = $width; $w.WindowStartupLocation = 'CenterScreen'; $w.Title = $title
  $w.UseLayoutRounding = $true
  try { $ico = Join-Path $Dir 'app.ico'; if (Test-Path -LiteralPath $ico) { $w.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri $ico)) } } catch {}
  $bd = New-Object System.Windows.Controls.Border; $bd.Background = Br '#F7161617'; $bd.BorderBrush = Br '#59B98E5F'; $bd.BorderThickness = New-Object System.Windows.Thickness(1); $bd.CornerRadius = New-Object System.Windows.CornerRadius(8); $bd.Padding = New-Object System.Windows.Thickness(22, 18, 22, 18)
  $sp = New-Object System.Windows.Controls.StackPanel
  $t = TB $title 15 $GOLD; UIF $t; $t.TextWrapping = 'Wrap'; $t.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12); [void]$sp.Children.Add($t)
  $body = New-Object System.Windows.Controls.StackPanel; [void]$sp.Children.Add($body)
  $btns = New-Object System.Windows.Controls.StackPanel; $btns.Orientation = 'Horizontal'; $btns.HorizontalAlignment = 'Right'; $btns.Margin = New-Object System.Windows.Thickness(0, 18, 0, 0); [void]$sp.Children.Add($btns)
  $bd.Child = $sp; $w.Content = $bd
  $bd.Add_MouseLeftButtonDown({ param($snd, $ev) try { [System.Windows.Window]::GetWindow($snd).DragMove() } catch {} })
  return @{ win = $w; body = $body; btns = $btns }
}
function Dlg-Btn($d, [string]$label, [bool]$warm, [scriptblock]$act) {
  $b = New-Object System.Windows.Controls.Border; $b.CornerRadius = New-Object System.Windows.CornerRadius(4); $b.Padding = New-Object System.Windows.Thickness(18, 6, 18, 7); $b.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0); $b.Cursor = [System.Windows.Input.Cursors]::Hand
  $b.Background = $(if ($warm) { Br '#E6B98E5F' } else { Br '#1FFFFFFF' })
  $t = TB $label 12.5 $(if ($warm) { Br '#FF141414' } else { $CREAM }); UIF $t; $b.Child = $t; $b.Tag = $act
  $b.Add_MouseLeftButtonDown({ param($snd, $ev) $ev.Handled = $true })
  $b.Add_MouseLeftButtonUp({ param($snd, $ev) try { & $snd.Tag } catch { Log "안내 창 버튼: $_" }; $ev.Handled = $true })
  [void]$d.btns.Children.Add($b)
}
# 처음 실행: 저작권 안내 (한 번만 · [확인]을 누르면 다시 안 나옴)
$script:frWin = $null
function First-Run {
  if ([bool]$S.firstRunOk) { return }
  $d = New-Dlg $PRODUCT 460
  $t = TB $COPYRIGHT 12.5 $CREAM; $t.TextWrapping = 'Wrap'; $t.LineHeight = 21; [void]$d.body.Children.Add($t)
  Dlg-Btn $d '확인' $true { $S.firstRunOk = $true; Save-Cfg; $script:frWin.Close() }
  $script:frWin = $d.win
  [void]$d.win.ShowDialog()
}
# 제미나이 API 키 넣기 (설정 '보내기 번역' 아래 키 칸을 누르면) · 키는 화면에 끝 4자리만
$script:keyWin = $null; $script:keyPw = $null
function Key-Close { try { if ($script:keyWin) { $script:keyWin.Close() } } catch {}; $script:keyWin = $null; $script:keyPw = $null }
function Key-Commit {
  $kpw = $script:keyPw; if (-not $kpw) { return }
  $k = [string]$kpw.Password
  if (-not $k.Trim()) { Key-Close; return }
  if (Key-Save $k) { [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = '제미나이 API 키를 저장했어요 (보내기 번역에서 제미나이를 고르면 써요)' }) }
  else { [void](Add-Line @{ kind = 'S'; col = 'ff7a5c'; text = '제미나이 API 키를 저장하지 못했어요' }) }
  Key-Close
}
function Key-Dialog {
  Key-Close
  $d = New-Dlg '제미나이 API 키' 420
  $t1 = TB 'Google AI Studio에서 받은 키를 붙여 넣고 [저장]을 누르세요. 키는 이 컴퓨터에만 암호화해서 저장돼요.' 11.5 $SUBC; $t1.TextWrapping = 'Wrap'; $t1.LineHeight = 19; [void]$d.body.Children.Add($t1)
  $kh = Key-Hint
  if ($kh) { $t2 = TB ('지금 키: ' + $kh) 11 $MUTED; $t2.Margin = New-Object System.Windows.Thickness(0, 6, 0, 0); [void]$d.body.Children.Add($t2) }
  $pb = New-Object System.Windows.Controls.Border; $pb.Background = Br '#40000000'; $pb.BorderBrush = Br '#40FFFFFF'; $pb.BorderThickness = New-Object System.Windows.Thickness(1); $pb.CornerRadius = New-Object System.Windows.CornerRadius(4); $pb.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0); $pb.Padding = New-Object System.Windows.Thickness(8, 5, 8, 5)
  $kpw = New-Object System.Windows.Controls.PasswordBox; $kpw.Background = [System.Windows.Media.Brushes]::Transparent; $kpw.BorderThickness = New-Object System.Windows.Thickness(0); $kpw.Foreground = $CREAM; $kpw.CaretBrush = $GOLD; $kpw.FontSize = 13; $kpw.PasswordChar = [char]0x25CF
  $pb.Child = $kpw; [void]$d.body.Children.Add($pb)
  $kpw.Add_KeyDown({ param($snd, $ev) if ($ev.Key -eq 'Return' -or $ev.Key -eq 'Enter') { $ev.Handled = $true; Key-Commit } elseif ($ev.Key -eq 'Escape') { $ev.Handled = $true; Key-Close } })
  if ($kh) { Dlg-Btn $d '지우기' $false { [void](Key-Save ''); [void](Add-Line @{ kind = 'S'; col = 'ffd27a'; text = '제미나이 API 키를 지웠어요 (보내기는 자체 번역으로)' }); Key-Close } }
  Dlg-Btn $d '취소' $false { Key-Close }
  Dlg-Btn $d '저장' $true { Key-Commit }
  $script:keyWin = $d.win; $script:keyPw = $kpw
  $d.win.Add_Closed({ $script:keyWin = $null; $script:keyPw = $null })
  $d.win.Add_ContentRendered({ try { $script:keyPw.Focus() | Out-Null; [System.Windows.Input.Keyboard]::Focus($script:keyPw) | Out-Null } catch {} })
  $d.win.Show(); [void]$d.win.Activate()
}

# ---------- 타이머 ----------
$OnDeact = {
  if ($state.inputOn -and -not $state.sending) {
    $state.caret = $Inp.CaretIndex; $state.offAt = [DateTime]::Now   # (2026-10-27) 게임에서 링크 시프트 클릭하러 나간 것일 수 있음
    Start-Sleep -Milliseconds 60; Tr-Signal $true   # (와우가 완전히 앞으로 온 뒤) 입력줄이 열려 있었으면 (글이 비어 있어도) 게임에 '쓰는 중' 신호 → 시프트 클릭 링크가 번역창으로
    $state.inputOn = $false
    $state.idle = 99   # (2026-10-27) 밖을 클릭하면 판(입력줄·탭·테두리)이 4초 기다리지 않고 바로 사라짐 (요청)
    [FTR]::NoActivate($script:hwnd, $true)
    if (-not $Inp.Text) { $PrevG.Visibility = 'Collapsed' }
    try { CIn-Close } catch {}   # (2026-10-30) 가운데 입력칸도 닫고 원래 자리로
  }
  # (2026-10-25) 밖을 클릭하면 입력칸에서 완전히 빠져나옴 (깜빡이는 커서가 남지 않게)
  try { [System.Windows.Input.FocusManager]::SetFocusedElement($win, $null); [System.Windows.Input.Keyboard]::ClearFocus() } catch {}
}
$win.Add_Deactivated($OnDeact)
$win.Add_SourceInitialized({
  $script:hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($win)).Handle
  [FTR]::ClickThrough($script:hwnd, $true)
  [FTR]::NoActivate($script:hwnd, $true)
  [FTR]::OnHotKey = [Action[int]] { param($id) if ($id -eq 7 -or $id -eq 8) { Enter-Input } }
  [FTR]::Start()
})
# ---------- (2026-11-12 대표) 사전 업데이트: GitHub(zerazine/nangman-translator · dict/)의 잠근 사전을 도우미 바 [사전] 한 번으로 ----------
#  켤 때 + 6시간마다 version.json(번호·날짜·검사값)만 확인 → 새 번호면 [사전] 점이 금빛 → 누르면 dict.bin 받기 → 풀기(AES) → 검사값·JSON 확인 → 예전 사전 백업 후 바꿈
#  하나라도 틀리면 쓰던 사전 그대로 · 사전 파일이 바뀌면 위의 2초 확인이 알아서 다시 읽음 (다시 켤 필요 없음)
$DictBase = 'https://zerazine.github.io/nangman-translator/dict/'
$DictKey = [System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes('NangmanTauren.WowForever.dict.v1'))
$DictHttp = New-Object System.Net.Http.HttpClient; $DictHttp.Timeout = [TimeSpan]::FromSeconds(60)
$Dict = @{ remote = 0; rdate = ''; rsha = ''; task = $null; kind = ''; busy = $false; manual = $false; msg = ''; msgAt = [DateTime]::MinValue; checkAt = [DateTime]::Now.AddHours(-6).AddSeconds(8) }
if ($null -eq $S.dictV) { $S.dictV = 0 }
function Dict-Msg([string]$m) {
  $Dict.msg = $m; $Dict.msgAt = [DateTime]::Now; try { Bar-Paint } catch {}
  # (2026-11-13) [사전] 알약이 없어져서 '지금 확인'을 누른 때만 결과를 대화창에 한 줄로
  if ($Dict.manual) {
    $line = @{ '최신' = ('번역 사전은 최신이에요' + $(if ($Dict.rdate) { ' (' + $Dict.rdate + ')' } else { '' })); '받기 실패' = '번역 사전을 받지 못했어요 · 쓰던 사전 그대로 써요'; '실패 · 그대로' = '새 번역 사전에 문제가 있어서 쓰던 사전 그대로 써요' }[$m]
    if ($line) { try { Add-Line @{ kind = 'S'; col = 'e0b95a'; text = $line } | Out-Null } catch {} }
    if ($m -ne '확인 중') { $Dict.manual = $false }
  }
}
function Dict-Hex([byte[]]$b) { return (($b | ForEach-Object { $_.ToString('x2') }) -join '') }
function Dict-Sha([byte[]]$b) {
  $n = $b.Length; $o = 0
  if ($n -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $o = 3 }   # 앞 BOM은 빼고 잼 (올릴 때와 같게)
  return (Dict-Hex ([System.Security.Cryptography.SHA256]::Create().ComputeHash($b, $o, $n - $o)))
}
function Dict-Check {
  if ($Dict.task) { return }
  $Dict.checkAt = [DateTime]::Now; $Dict.kind = 'ver'
  $Dict.task = $DictHttp.GetStringAsync($DictBase + 'version.json?t=' + [DateTime]::UtcNow.Ticks)
}
function Dict-Update {
  if ($Dict.task -or $Dict.busy) { return }
  if ([int]$Dict.remote -le [int]$S.dictV) { Dict-Msg '최신'; Dict-Check; return }
  $Dict.kind = 'bin'; $Dict.busy = $true; try { Bar-Paint } catch {}
  $Dict.task = $DictHttp.GetByteArrayAsync($DictBase + 'dict.bin?t=' + [DateTime]::UtcNow.Ticks)
}
function Dict-Apply([byte[]]$bytes) {
  if ($bytes.Length -lt 48) { throw '받은 파일이 너무 작음' }
  $aes = [System.Security.Cryptography.Aes]::Create()
  $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC; $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
  $aes.Key = $DictKey; $iv = New-Object byte[] 16; [Array]::Copy($bytes, 0, $iv, 0, 16); $aes.IV = $iv
  $dec = $aes.CreateDecryptor().TransformFinalBlock($bytes, 16, $bytes.Length - 16)
  $ms = New-Object System.IO.MemoryStream(, $dec)
  $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
  $out = New-Object System.IO.MemoryStream; $gz.CopyTo($out); $gz.Dispose(); $plain = $out.ToArray()
  if ((Dict-Sha $plain) -ne ([string]$Dict.rsha).ToLower()) { throw '검사값이 안 맞음 (파일이 깨졌을 수 있음)' }
  $txt = [Text.Encoding]::UTF8.GetString($plain).TrimStart([char]0xFEFF)
  $c = $txt | ConvertFrom-Json
  if (-not $c.sys_in -or -not $c.slang_in) { throw '사전 모양이 이상함' }
  $bak = Join-Path $Dir 'translate-config.bak.json'
  try { if (Test-Path -LiteralPath $TrCfgFile) { Copy-Item -LiteralPath $TrCfgFile -Destination $bak -Force } } catch {}
  $tmp = $TrCfgFile + '.new'
  [IO.File]::WriteAllBytes($tmp, $plain)
  Move-Item -LiteralPath $tmp -Destination $TrCfgFile -Force
  $S.dictV = [int]$Dict.remote; $S.dictDate = [string]$Dict.rdate; $S.dictAt = [DateTime]::Now.ToString('o'); Save-Cfg
  Log ('사전 업데이트: ' + $Dict.remote + ' · ' + $Dict.rdate)
  try { Add-Line @{ kind = 'S'; col = 'e0b95a'; text = ('번역 사전을 새로 받았어요 (' + $Dict.rdate + ')') } | Out-Null } catch {}
}
function Dict-Paint {
  if (-not $Bar.ddot) { return }
  if ($Dict.msg -and ([DateTime]::Now - $Dict.msgAt).TotalSeconds -ge 6) { $Dict.msg = '' }
  $new = ([int]$Dict.remote -gt [int]$S.dictV)
  $t = '사전'; if ($Dict.busy) { $t = '받는 중' } elseif ($Dict.msg) { $t = $Dict.msg }
  if ($Bar.dtx.Text -ne $t) { $Bar.dtx.Text = $t }
  if ($new -and -not $Dict.busy) {
    $Bar.ddot.Fill = Br '#FFFFC94A'
    $g = New-Object System.Windows.Media.Effects.DropShadowEffect; $g.Color = [System.Windows.Media.Color]::FromRgb(0xFF, 0xC9, 0x4A); $g.ShadowDepth = 0; $g.BlurRadius = 9; $g.Opacity = 0.95; $Bar.ddot.Effect = $g
    $Bar.dtx.Foreground = Br '#FFF3E2B3'; $Bar.dp.ToolTip = ('새 번역 사전이 있어요 (' + $Dict.rdate + ') · 클릭 = 받기 · 오른쪽 클릭 = 옵션')
  } else {
    $Bar.ddot.Fill = Br '#FF4A4D55'; $Bar.ddot.Effect = $null
    $Bar.dtx.Foreground = Br '#FF8C7A52'; $Bar.dp.ToolTip = '번역 사전 · 최신 (클릭 = 다시 확인 · 오른쪽 클릭 = 옵션)'
  }
}
$DictT = New-Object Windows.Threading.DispatcherTimer
$DictT.Interval = [TimeSpan]::FromMilliseconds(500)
$DictT.Add_Tick({
  try {
    if (-not $Dict.task) {
      if (([DateTime]::Now - $Dict.checkAt).TotalHours -ge 6) { Dict-Check }
      if ($Dict.msg -and ([DateTime]::Now - $Dict.msgAt).TotalSeconds -ge 6) { Dict-Paint }
      return
    }
    if (-not $Dict.task.IsCompleted) { return }
    $t = $Dict.task; $Dict.task = $null; $k = $Dict.kind
    if ($t.Status -ne [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
      $why = ''; try { $why = [string]$t.Exception.InnerException.Message } catch {}
      Log ('사전 ' + $k + ' 받기 실패: ' + $why)
      if ($k -eq 'bin' -or $Dict.manual) { $Dict.busy = $false; Dict-Msg '받기 실패' }
      return
    }
    if ($k -eq 'ver') {
      $j = [string]$t.Result | ConvertFrom-Json
      $Dict.remote = [int]$j.v; $Dict.rdate = [string]$j.date; $Dict.rsha = [string]$j.sha256
      # 설치할 때 들어온 사전이 이미 이 번호와 같으면 점 안 켬
      if ([int]$Dict.remote -gt [int]$S.dictV) { try { if ((Dict-Sha ([IO.File]::ReadAllBytes($TrCfgFile))) -eq $Dict.rsha.ToLower()) { $S.dictV = [int]$Dict.remote; $S.dictDate = [string]$Dict.rdate; Save-Cfg } } catch {} }
      try { Bar-Paint } catch {}
      # (2026-11-12 대표) 새 사전이 있으면 누르지 않아도 알아서 받아서 적용 (실패하면 다음 확인 때 다시)
      # (2026-11-13 대표) 자동 업데이트를 끈 사람은 '지금 확인'을 누른 때만 받음
      if ([int]$Dict.remote -gt [int]$S.dictV) { if ($S.dictAuto -ne $false -or $Dict.manual) { Log ('새 사전 ' + $Dict.remote + ' 적용'); Dict-Update } }
      elseif ($Dict.manual) { Dict-Msg '최신' }
      if ([int]$Dict.remote -eq [int]$S.dictV -and -not $S.dictDate -and $Dict.rdate) { $S.dictDate = [string]$Dict.rdate; Save-Cfg }
    } elseif ($k -eq 'bin') {
      try { Dict-Apply ([byte[]]$t.Result); Dict-Msg '사전 ✓' } catch { Log ('사전 업데이트 실패: ' + $_); Dict-Msg '실패 · 그대로' }
      $Dict.busy = $false; try { Bar-Paint } catch {}
    }
  } catch { Log "사전 확인: $_" }
})
$DictT.Start()
# ---------- (2026-11-13 대표) 프로그램 자동 업데이트: 사전처럼 GitHub(app/version.json)만 확인 → 새 번호면 바뀐 파일만 받아서 검사값(SHA256)이 맞을 때만 바꿈 ----------
#  바꾸는 것: 설치 폴더의 프로그램 파일 · 게임 애드온(NangmanTranslator) 파일만 (사전·내 설정·번역 모델은 절대 안 건드림)
#  와우가 꺼져 있을 때만 바꿈 (켜져 있으면 끌 때까지 기다림) · 프로그램 파일이 바뀌면 아래 '새 버전으로 다시 켜짐'이 알아서 다시 켬 (새 파일에 문법 오류가 있으면 안 켜고 그대로)
#  하나라도 받기 실패·검사값 틀림이면 아무것도 안 바꾸고 다음 확인(6시간 뒤) 때 다시
$APPV = 20
$AppBase = 'https://zerazine.github.io/nangman-translator/app/'
$Upd = @{ task = $null; kind = ''; j = $null; queue = (New-Object System.Collections.ArrayList); cur = $null; got = @{}; ready = $false; checkAt = [DateTime]::Now.AddHours(-6).AddSeconds(25); waitLog = $false }
function Upd-AddonDir {
  try { foreach ($l in [IO.File]::ReadAllLines((Join-Path $env:LOCALAPPDATA 'NangmanTranslator\installed.txt'))) { if ($l -match '^\W*addon=(.+)$') { $d = $Matches[1].Trim(); if ($d -and (Test-Path -LiteralPath $d)) { return $d } } } } catch {}
  return $null
}
function Upd-Target([string]$p) {
  if ($p -match '\.\.' -or $p -notmatch '^(app|addon)/[A-Za-z0-9_\-/]+(\.[A-Za-z0-9]+)?$') { return $null }
  if ($p -match '^app/(.+)$') { $rel = $Matches[1]; if ($rel -match '(?i)^(settings\.json|translate-config.*|tier\.txt|installed\.txt)$') { return $null }; return (Join-Path $Dir ($rel -replace '/', '\')) }
  if ($p -match '^addon/NangmanTranslator/(.+)$') { $ad = Upd-AddonDir; if (-not $ad) { return $null }; return (Join-Path $ad ($Matches[1] -replace '/', '\')) }
  return $null
}
function Upd-Sha([byte[]]$b) { return (Dict-Hex ([System.Security.Cryptography.SHA256]::Create().ComputeHash($b))) }
function Upd-FileSha([string]$f) { try { if (Test-Path -LiteralPath $f) { return (Upd-Sha ([IO.File]::ReadAllBytes($f))) } } catch {}; return '' }
function Upd-Reset { $Upd.task = $null; $Upd.j = $null; $Upd.queue.Clear(); $Upd.cur = $null; $Upd.got = @{}; $Upd.ready = $false; $Upd.waitLog = $false }
function Upd-Check { if ($Upd.task -or $Upd.ready -or $Upd.queue.Count -gt 0) { return }; $Upd.checkAt = [DateTime]::Now; $Upd.kind = 'ver'; $Upd.task = $DictHttp.GetStringAsync($AppBase + 'version.json?t=' + [DateTime]::UtcNow.Ticks) }
function Upd-Next {
  if ($Upd.queue.Count -eq 0) { $Upd.ready = $true; Log ('프로그램 새 버전 ' + $Upd.j.v + ' 받기 끝 · 와우가 꺼져 있을 때 바꿈'); return }
  $Upd.cur = $Upd.queue[0]; $Upd.queue.RemoveAt(0)
  $Upd.kind = 'file'; $Upd.task = $DictHttp.GetByteArrayAsync($AppBase + [string]$Upd.j.v + '/' + [string]$Upd.cur.p + '?t=' + [DateTime]::UtcNow.Ticks)
}
function Upd-Apply {
  $items = @($Upd.got.Keys | Sort-Object { if ($_ -match '(?i)NangmanTranslator\.ps1$') { 1 } else { 0 } })   # 프로그램 본 파일은 맨 마지막에
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
  try { Add-Line @{ kind = 'S'; col = 'e0b95a'; text = ('번역기를 새 버전(' + [string]$Upd.j.ver + ')으로 업데이트했어요' + $(if (@($items | Where-Object { $_ -like 'addon/*' }).Count -gt 0) { ' · 게임 쪽은 다음 접속 때 적용돼요' } else { '' })) } | Out-Null } catch {}
}
$UpdT = New-Object Windows.Threading.DispatcherTimer
$UpdT.Interval = [TimeSpan]::FromSeconds(1)
$UpdT.Add_Tick({
  try {
    if ($Upd.ready) {
      if ([FTR]::FindWow() -ne [IntPtr]::Zero -or $state.inputOn -or $state.sending) { if (-not $Upd.waitLog) { $Upd.waitLog = $true; Log '프로그램 업데이트: 와우가 꺼지면 바꿈' }; return }
      try { Upd-Apply } catch { Log ('프로그램 업데이트 실패 (그대로 씀): ' + $_) }
      Upd-Reset; return
    }
    if (-not $Upd.task) { if ($Upd.queue.Count -eq 0 -and ([DateTime]::Now - $Upd.checkAt).TotalHours -ge 6) { Upd-Check }; return }
    if (-not $Upd.task.IsCompleted) { return }
    $t = $Upd.task; $Upd.task = $null
    if ($t.Status -ne [System.Threading.Tasks.TaskStatus]::RanToCompletion) { $why = ''; try { $why = [string]$t.Exception.InnerException.Message } catch {}; Log ('프로그램 업데이트 ' + $Upd.kind + ' 받기 실패: ' + $why); Upd-Reset; return }
    if ($Upd.kind -eq 'ver') {
      $j = [string]$t.Result | ConvertFrom-Json
      if (-not $j -or [int]$j.v -le $APPV) { return }
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
})
$UpdT.Start()
# ---------- (2026-11-13 대표) 익명 사용 통계: 하루 한 번 '켜졌음' 신호만 보냄 (무작위 번호 · 버전 · Gemma/Gemini 구분) · 채팅 내용·캐릭 이름·배틀태그는 절대 안 보냄 ----------
#  받는 곳: 제작자 Supabase (공개용 키 · 기록 추가만 됨 · 읽기·수정·삭제 불가) · 인터넷이 안 되면 조용히 건너뜀 · 번역 속도와 무관
$UsageUrl = 'https://wxnvgbeahpjudaxjsjmg.supabase.co/rest/v1/usage_ping'
$UsageKey = 'sb_publishable_c6JUbaSwz1LAvxH9nenYXw_hkZOYEkt'
if (-not $S.uid) { $S.uid = [guid]::NewGuid().ToString('N'); Save-Cfg }
$Usage = @{ task = $null; day = ''; next = [DateTime]::Now.AddSeconds(20) }
function Usage-Ping {
  try {
    $today = [DateTime]::Now.ToString('yyyy-MM-dd')
    if ([string]$S.pingDay -eq $today -or $Usage.task) { return }
    $ver = ''; try { foreach ($l in [IO.File]::ReadAllLines((Join-Path $env:LOCALAPPDATA 'NangmanTranslator\installed.txt'))) { if ($l -match '^\W*version=(.+)$') { $ver = $Matches[1].Trim() } } } catch {}
    $body = (@{ uid = [string]$S.uid; ver = $ver; tier = $Tier } | ConvertTo-Json -Compress)
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $UsageUrl)
    [void]$req.Headers.TryAddWithoutValidation('apikey', $UsageKey); [void]$req.Headers.TryAddWithoutValidation('Prefer', 'return=minimal')
    $req.Content = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json')
    $Usage.task = $DictHttp.SendAsync($req); $Usage.day = $today
  } catch { Log "사용 통계 보내기: $_" }
}
$UsageT = New-Object Windows.Threading.DispatcherTimer
$UsageT.Interval = [TimeSpan]::FromSeconds(10)
$UsageT.Add_Tick({
  try {
    if ($Usage.task) {
      if (-not $Usage.task.IsCompleted) { return }
      $t = $Usage.task; $Usage.task = $null; $code = 0
      try { if ($t.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) { $code = [int]$t.Result.StatusCode } } catch {}
      if ($code -eq 201 -or $code -eq 409) { $S.pingDay = $Usage.day; Save-Cfg } else { Log ('사용 통계 보내기 실패 (' + $code + ') · 다음에 다시'); $Usage.next = [DateTime]::Now.AddMinutes(30) }
      return
    }
    if ([DateTime]::Now -ge $Usage.next) { $Usage.next = [DateTime]::Now.AddMinutes(10); Usage-Ping }
  } catch {}
})
$UsageT.Start()
# ---------- (2026-11-12 대표) 윈도우 시작 시 자동 실행 (도우미 바 오른쪽 클릭 메뉴) · 현재 사용자 시작 프로그램(HKCU Run)에 이 프로그램 한 줄 ----------
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; $RunName = 'NangmanTaurenTranslator'
function Auto-Cmd { return ('"' + (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') + '" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Self + '"') }
function Auto-IsOn { try { $v = (Get-ItemProperty -Path $RunKey -Name $RunName -ErrorAction Stop).$RunName; return [bool]$v } catch { return $false } }
function Auto-Set([bool]$on) {
  try {
    if ($on) { New-ItemProperty -Path $RunKey -Name $RunName -Value (Auto-Cmd) -PropertyType String -Force | Out-Null; Log '윈도우 시작 시 자동 실행 켬' }
    else { Remove-ItemProperty -Path $RunKey -Name $RunName -ErrorAction SilentlyContinue; Log '윈도우 시작 시 자동 실행 끔' }
  } catch { Log "자동 실행 설정: $_" }
}
try { if ((Auto-IsOn) -and (Get-ItemProperty -Path $RunKey -Name $RunName -ErrorAction Stop).$RunName -ne (Auto-Cmd)) { Auto-Set $true } } catch {}   # 설치 위치가 바뀌었으면 맞춤
if (-not $S.autoInit) { Auto-Set $true; $S.autoInit = $true; Save-Cfg }   # (2026-11-12 대표) 처음 한 번은 자동 실행을 켜 둠 · 끄면 그대로 꺼진 채 유지 ([설정] 메뉴)
$Main = New-Object Windows.Threading.DispatcherTimer
$Main.Interval = [TimeSpan]::FromMilliseconds(50)
$script:lastFollow = [DateTime]::MinValue
$Main.Add_Tick({
  try {
    # 받은 대화
    $n = 0; $line = $null
    while ($n -lt 40 -and [FTR]::Records.TryDequeue([ref]$line)) { $n++; try { Handle $line } catch { Log "처리: $_ :: $line" } }
    try { Ollama-Tick } catch {}
    Eng-Tick
    if ($CIn.on) { try { Ime-Paint } catch {} }
    # 번역 결과
    for ($i = $Pending.Count - 1; $i -ge 0; $i--) {
      $p = $Pending[$i]
      if (-not (Job-Ready $p.task)) { continue }
      $Pending.RemoveAt($i); $script:trDirty = $true
      $res = Gem-Read $p.task $p.kind
      if ($res.err) {
        if ($p.kind -eq 'send') { if ($p.task.fellBack) { Fb-Note ([string]$p.task.fellBack) }; Send-Fail $p ('→  ' + $res.err + ' (Enter = 다시)') }
        elseif ($p.kind -eq 'in') { Set-Sub $p.L $null ('(' + $res.err + ')') }
        elseif ($p.kind -eq 'lfg' -and $Lfg.orig) { $Lfg.orig.Text = '(' + $res.err + ')' }
        Log $res.err; continue
      }
      $j = $res.json
      if ($j -and ($p.kind -eq 'in' -or $p.kind -eq 'lfg')) {
        # (2026-11-01) 'I'를 '아이가'로 옮긴 답 → 한 번만 다시 (그래도 같으면 영어 원문 그대로)
        if ([string]$j.ko -match '(^|[\s,(])아이(가|는|도|랑)?([\s,.!?~]|$)' -and $p.src -notmatch '(?i)\b(kids?|child|children|baby|babies)\b') {
          if (-not $p.retry) { $t2 = Gem-Send ($SYS_IN + (Gloss-For $p.src) + (Slang-In $p.src)) (Pre-Fix $p.src) $false 'chat'; if ($t2) { $p.task = $t2; $p.retry = $true; [void]$Pending.Add($p); Dbg ("받은 번역 다시('아이') · " + $p.src); continue } }
          $j.ko = $p.src
        }
        $j = Ko-Fix $p.src $j
      }
      switch ($p.kind) {
        'in' { if ($j) { if ($Cache.Count -ge 2000) { $Cache.Clear() }; $Cache[$p.src] = $j; Done-In $p.L $j } }
        'lfg' { if ($j) { if ($Cache.Count -ge 2000) { $Cache.Clear() }; $Cache[$p.src] = $j; Lfg-Done $p.key $j $p.src } }   # (2026-10-25) 번역 기억은 2000줄까지
        'prev' {
          $o = $(if ($j -and $j.text) { [string]$j.text } else { '' }); $o = Ad-Caps $o
          if ($o -and $Inp.Text.Trim() -eq $p.src) { $state.prevText = $p.src; $state.prevOut = $o; $state.prevLang = $p.lang; Set-Prev ('→  ' + (Link-Show $o)); $PrevG.Visibility = 'Visible' }
        }
        'send' { if ($p.task.fellBack) { Fb-Note ([string]$p.task.fellBack) }; $o = $(if ($j -and $j.text) { [string]$j.text } else { '' }); $o = Ad-Caps $o; if ($o) { Finish-Send $p.tg $p.src $o } else { Send-Fail $p '→  번역 실패 (Enter = 다시)' } }
      }
    }
    Lfg-Tick
    Feed-Tick
    try { Bar-Tick } catch { Log "도우미 바: $_" }
    # (2026-10-26) 설정 창이 열려 있을 때 게임 등 바깥을 클릭하면 닫기 (번역창이 앞에 없으면 창이 바깥 클릭을 몰랐음)
    if ($Pop.IsOpen) {
      try {
        $down = ([FTRK.Keys]::GetAsyncKeyState(1) -band 0x8000) -or ([FTRK.Keys]::GetAsyncKeyState(2) -band 0x8000)
        if ($down) {
          $c = [FTR]::Cursor(); $inside = $false
          foreach ($el in @($popB, $Pop.PlacementTarget)) {
            if (-not $el -or -not $el.IsVisible) { continue }
            $pt = $el.PointFromScreen((New-Object System.Windows.Point($c[0], $c[1])))
            if ($pt.X -ge 0 -and $pt.Y -ge 0 -and $pt.X -le $el.ActualWidth -and $pt.Y -le $el.ActualHeight) { $inside = $true }
          }
          if (-not $inside) { $Pop.IsOpen = $false }
        }
      } catch {}
    }
    # (2026-11-13 대표) 도우미 바 [설정] 메뉴도 게임 등 바깥을 클릭하면 닫기 (바는 활성화되지 않는 창이라 바깥 클릭을 몰랐음)
    if ($Bar.cm -and $Bar.cm.IsOpen) {
      try {
        $down = ([FTRK.Keys]::GetAsyncKeyState(1) -band 0x8000) -or ([FTRK.Keys]::GetAsyncKeyState(2) -band 0x8000)
        if ($down) {
          $c = [FTR]::Cursor(); $inside = $false
          foreach ($el in @($Bar.cm, $Bar.sp2)) {
            if (-not $el -or -not $el.IsVisible) { continue }
            $pt = $el.PointFromScreen((New-Object System.Windows.Point($c[0], $c[1])))
            if ($pt.X -ge 0 -and $pt.Y -ge 0 -and $pt.X -le $el.ActualWidth -and $pt.Y -le $el.ActualHeight) { $inside = $true }
          }
          if (-not $inside) { $Bar.cm.IsOpen = $false }
        }
        if (([FTRK.Keys]::GetAsyncKeyState(0x1B) -band 0x8000) -ne 0) { $Bar.cm.IsOpen = $false }   # Esc
      } catch {}
    }
    # 보이기·숨기기
    $wow = [FTR]::FindWow(); $fg = [FTR]::Foreground()
    $live = [FTR]::SincePacket() -lt 40000   # (2026-10-25) 게임은 12초마다 살아 있다고 알림 (예전 5초 · 깜빡임 줄임)
    $show = $live -and -not $state.off -and $state.geo -and $wow -ne [IntPtr]::Zero -and ($fg -eq $wow -or $fg -eq $script:hwnd -or $state.inputOn -or $Pop.IsOpen)
    if ($show) {
      if ($win.Visibility -ne 'Visible') { $win.Visibility = 'Visible'; $script:placed = '' }
      if (([DateTime]::Now - $script:lastFollow).TotalSeconds -gt 2) { $script:lastFollow = [DateTime]::Now; [void][FTR]::FollowDesktop($script:hwnd, $wow); Place-Win }
    } elseif ($win.Visibility -eq 'Visible') { $win.Visibility = 'Hidden' }
    if ($state.wantInput) {
      if (([DateTime]::Now - $state.wantInput).TotalSeconds -gt 6) { $state.wantInput = $null }
      elseif ($show) { $state.wantInput = $null; if ($state.inputOn) { Paint-Target; $Inp.Focus() | Out-Null } else { Enter-Input } }
    }
    # Shift+Enter 는 와우가 앞에 있을 때만 잡음 (다른 프로그램에선 원래대로)
    $wantHk = ($fg -eq $wow -and $wow -ne [IntPtr]::Zero -and $live -and -not $state.off)   # (2026-10-25) 번역을 끄면 바로 놓아 줌 → Shift+Enter가 게임으로 가서 다시 켤 수 있게
    if ($wantHk -ne $state.hk) { [void][FTR]::Hotkey($script:hwnd, $wantHk); $state.hk = $wantHk }
    # (2026-10-25) 그냥 Enter도: 게임에서 대화창·경매장 검색 같은 입력칸에 글 쓰는 중이 아닐 때만
    $wantE = ($wantHk -and -not $state.kb -and -not $state.editing -and -not $state.sending)
    if ($wantE -ne $state.hkE) { [void][FTR]::HotkeyEnter($script:hwnd, $wantE); $state.hkE = $wantE }
    # 마우스 올림 → 판이 보이고 클릭 가능 · 아니면 마우스가 뚫고 지나감
    $c = [FTR]::Cursor()
    $hov = $false
    if ($show) {
      $p0 = $win.PointToScreen((New-Object System.Windows.Point(0, 0)))
      $p1 = $win.PointToScreen((New-Object System.Windows.Point($win.ActualWidth, $win.ActualHeight)))
      $hov = ($c[0] -ge $p0.X -and $c[0] -le $p1.X -and $c[1] -ge $p0.Y -and $c[1] -le $p1.Y)
    }
    # (2026-10-30) 대화창을 숨겨 둔 상태에서 가운데 입력칸으로 쓰는 중이면 왼쪽 대화창(번역창)은 계속 숨김 · 대화창을 켜 둔 상태면 예전처럼 같이 보임
    $inUse = ($state.inputOn -and -not ($CIn.on -and -not $state.vis)) -or [bool]$script:uiDrag
    $gv0 = $(if (($hov -or $script:uiDrag) -and -not $S.uiLock) { 'Visible' } else { 'Collapsed' }); if ($Grip.Visibility -ne $gv0) { $Grip.Visibility = $gv0 }
    if ($script:geoOv -and -not $script:uiDrag -and [DateTime]::Now -gt $script:ovUntil) { $script:geoOv = $null; Place-Win; Redraw-All }
    if ($hov -ne $state.hover -or $inUse -ne $state.inUse) { $state.hover = $hov; $state.inUse = $inUse; [FTR]::ClickThrough($script:hwnd, -not ($hov -or $inUse)) }
    $want = ($hov -or $inUse -or $Pop.IsOpen)
    if ($want) { $state.idle = 0 } else { $state.idle += 0.05 }
    $target = $(if ($want) { 1.0 } elseif ($state.idle -gt 4) { 0.0 } else { 1.0 })
    if ($state.editing -and -not $state.inputOn) { $target = 0.0; $want = $true }
    if ($state.chromeA -ne $target) {
      $state.chromeA = $(if ($target -gt $state.chromeA) { [math]::Min($target, $state.chromeA + 0.3) } else { [math]::Max($target, $state.chromeA - 0.075) })
      $Chrome.Opacity = $state.chromeA
    }
    # 오래된 줄은 흐려짐 (60초) · 마우스 올리면 다시 다 보임
    $now = [DateTime]::Now
    # (2026-10-25) 창이 보일 때만 · 0.25초마다(마우스 올림이 바뀌면 바로) 계산 (예전: 숨어 있어도 0.05초마다 300줄 전부)
    $script:fN = [int]$script:fN + 1
    # 우리가 대신 보내느라 게임 입력칸을 잠깐 쓰는 동안(대화창 숨김 상태)은 '게임에서 쓰는 중'으로 치지 않음
    $edShow = $state.editing -and -not ((-not $state.vis) -and $state.sentAt -and ($now - $state.sentAt).TotalSeconds -lt 6)
    $hovNow = [bool]($hov -or $inUse -or $Pop.IsOpen -or $edShow)
    if ($show -and (($script:fN % 5) -eq 0 -or $hovNow -ne $script:lastHov)) { $script:lastHov = $hovNow
    foreach ($L in $LineList) {
      $age = ($now - $L.at).TotalSeconds
      $o = $(if ($hov -or $inUse -or $Pop.IsOpen -or $edShow) { 1.0 } elseif (-not $state.vis) { 0.0 } elseif ($S.fade -le 0 -or $age -lt $S.fade) { 1.0 } elseif ($age -lt $S.fade + 2) { 1.0 - ($age - $S.fade) / 2 } else { 0.0 })
      if ($L.box.Opacity -ne $o) { $L.box.Opacity = $o }
    }
    }
  } catch { Log "타이머: $_" }
})
$SaveT = New-Object Windows.Threading.DispatcherTimer
$SaveT.Interval = [TimeSpan]::FromMinutes(2)
$SaveT.Add_Tick({ Save-Cfg })
$StT = New-Object Windows.Threading.DispatcherTimer
$StT.Interval = [TimeSpan]::FromSeconds(20)
$StT.Add_Tick({ Dbg ("상태: 신호 {0} · 놓침 {1} · {2} · 입력중 {3} · 보내는중 {4} · 대기 {5}" -f [FTR]::Packets, [FTR]::Drops, [FTR]::Status, $state.inputOn, $state.sending, $Pending.Count) })

Select-Tab ([string]$S.tab)
Paint-Status
$win.Add_Closed({ try { Save-Cfg } catch {}; [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() })
try { First-Run } catch { Log "처음 안내: $_" }
if ($Tier -eq 'low' -and -not (Api-Key)) { try { Key-Dialog } catch { Log "처음 키 넣기: $_" } }   # (2026-11-12) 최저 단계: 키가 없으면 처음에 바로 키 넣기 창   # (공유판) 처음 한 번만: 저작권 안내
$win.Show()
$win.Visibility = 'Hidden'
# (2026-10-25) 이 프로그램 파일(또는 ftr\FTR.cs)이 새로 바뀌면(업데이트) 스스로 다시 켜짐
#   (입력 중·보내는 중이면 끝날 때까지 기다림 · 파일 쓰는 도중에 켜지지 않게 2초 기다렸다가)
function Self-Stamp { try { return ((Get-Item -LiteralPath $Self).LastWriteTimeUtc.Ticks.ToString() + '|' + (Get-Item -LiteralPath (Join-Path $A 'FTR.cs')).LastWriteTimeUtc.Ticks) } catch { return '' } }
$script:stamp0 = Self-Stamp; $script:stampNew = ''; $script:stampAt = [DateTime]::MinValue
$RlT = New-Object Windows.Threading.DispatcherTimer
$RlT.Interval = [TimeSpan]::FromSeconds(3)
$RlT.Add_Tick({
  try {
    $st = Self-Stamp
    if (-not $st -or $st -eq $script:stamp0) { return }
    if ($st -ne $script:stampNew) { $script:stampNew = $st; $script:stampAt = [DateTime]::Now; return }
    if (([DateTime]::Now - $script:stampAt).TotalSeconds -lt 2 -or $state.inputOn -or $state.sending) { return }
    # (2026-10-31) 새 파일에 문법 오류가 있으면 다시 켜지 않고 지금 것 그대로 (켜다가 죽어서 번역창이 사라지는 것 막기)
    $pe = $null; try { [void][System.Management.Automation.Language.Parser]::ParseFile($Self, [ref]$null, [ref]$pe) } catch {}
    if ($pe -and @($pe).Count -gt 0) { $script:stamp0 = $st; Log ("새 버전 문법 오류라 다시 켜지 않음: {0}번째 줄 · {1}" -f @($pe)[0].Extent.StartLineNumber, @($pe)[0].Message); return }
    Log '새 버전으로 다시 켜짐'
    try { Save-Cfg } catch {}
    try { $mtx.ReleaseMutex() } catch {}
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $Self + '"')) | Out-Null
    [Environment]::Exit(0)
  } catch { Log "다시 켜기: $_" }
})
$Main.Start(); $SaveT.Start(); $StT.Start(); $RlT.Start()
[System.Windows.Threading.Dispatcher]::Run()
