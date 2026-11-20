param([string]$Zip)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http, System.Security, System.IO.Compression.FileSystem
$t = Join-Path $env:RUNNER_TEMP ('dict_' + [guid]::NewGuid().ToString('N')); [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $Zip), $t)
$app = Get-ChildItem $t -Recurse -Filter NangmanTranslator.ps1 | Select-Object -First 1
$dat = Join-Path $app.DirectoryName 'dict.dat'
$err = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($app.FullName, [ref]$null, [ref]$err)
if ($err.Count) { $err | ForEach-Object { Write-Host $_ }; throw ('번역기 문법 오류 ' + $err.Count + '개') }
Write-Host '통과 번역기 문법 검사'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($app.FullName, [ref]$null, [ref]$null)
function Log($m) { Write-Host ('  (로그) ' + $m) }; function Save-Cfg { }
$script:S = @{ uid = ('c1' + [guid]::NewGuid().ToString('N').Substring(2)) }; $APPV = 0
foreach ($f in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) { if (@('Dict-Dec', 'Dict-IsV2', 'Dict-KeyFetch', 'Dict-AesV2', 'Dict-Dec2', 'Dict-Open', 'Cfg-Lines', 'TrCfg-Apply') -contains $f.Name) { Invoke-Expression $f.Extent.Text } }
foreach ($v in @('$DictKey', '$DictMagic')) { $a = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq $v }, $true) | Select-Object -First 1; if ($a) { Invoke-Expression $a.Extent.Text } }
$p = Dict-Open ([IO.File]::ReadAllBytes($dat))
$c = ([Text.Encoding]::UTF8.GetString($p).TrimStart([char]0xFEFF)) | ConvertFrom-Json; TrCfg-Apply $c
if ($SLANG_IN.Count -lt 1000) { throw ('사전이 이상함: 은어 ' + $SLANG_IN.Count) }
Write-Host ("통과 사전 열쇠 받기·풀기·읽기 · 은어 {0} · 영어 표현 {1} · 지명 {2}" -f $SLANG_IN.Count, $SLANG_OUT.Count, $GLOSS_E.Count)
