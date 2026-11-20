param([string]$Ver)
$ErrorActionPreference = 'Stop'
$J = Get-Content 'app/version.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$base = Join-Path (Get-Location) ("app/{0}/app" -f $J.v)
Write-Host ("시험 대상: {0} ({1}) · {2}" -f $J.v, $J.ver, $base)
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $base 'NangmanTranslator.ps1'), [ref]$null, [ref]$errs)
if ($errs.Count) { $errs | ForEach-Object { Write-Host ('문법 오류: 줄 {0} · {1}' -f $_.Extent.StartLineNumber, $_.Message) }; throw '프로그램 문법 오류' }
Write-Host '프로그램 문법: 통과'
$ps1 = [IO.File]::ReadAllText((Join-Path $base 'NangmanTranslator.ps1'))
if ($ps1 -notmatch ('\$APPV = ' + $J.v + '\b')) { throw ('프로그램 번호가 version.json(' + $J.v + ')과 다름') }
Write-Host '프로그램 번호: version.json과 같음'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Xaml
$refs = @([System.Drawing.Bitmap].Assembly.Location, [System.Windows.Interop.HwndSource].Assembly.Location, [System.Windows.DependencyObject].Assembly.Location, [System.Windows.Window].Assembly.Location, [System.Xaml.XamlReader].Assembly.Location)
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $base 'ftr\FTR.cs'), [Text.Encoding]::UTF8)) -ReferencedAssemblies $refs
Write-Host 'FTR.cs: 준비됨'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$vrefs = @([System.Windows.Automation.AutomationElement].Assembly.Location, [System.Windows.Automation.ControlType].Assembly.Location)
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $base 'ftr\FTRVoice.cs'), [Text.Encoding]::UTF8)) -ReferencedAssemblies $vrefs
[FTRVoice]::ShowLC = $false; [FTRVoice]::KeepLC = $false; [FTRVoice]::HookTick()
Write-Host ('FTRVoice.cs (디스코드 음성): 준비됨 · 상태 ' + [FTRVoice]::Status)
Write-Host '결과: 프로그램·음성 파일 모두 통과'
