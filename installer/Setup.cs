using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

static class Prog {
  [STAThread]
  static void Main(string[] a) {
    if (a.Any(x => x.Equals("/run", StringComparison.OrdinalIgnoreCase))) { Setup.RunApp(); return; }
    if (a.Any(x => x.Equals("/selftest-uninst", StringComparison.OrdinalIgnoreCase))) {
      Setup.SelfTest = true;
      new Setup(false).SelfUninst();
      Environment.Exit(0);
      return;
    }
    if (a.Any(x => x.Equals("/selftest", StringComparison.OrdinalIgnoreCase))) {
      try { ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12; } catch { }
      Setup.SelfTest = true;
      foreach (var x in a) { if (x.StartsWith("/forever=", StringComparison.OrdinalIgnoreCase)) Setup.SelfForever = x.Substring(9); if (x.Equals("/noengine", StringComparison.OrdinalIgnoreCase)) Setup.SelfNoEngine = true; }
      Environment.Exit(new Setup(false).RunSelfTest());
      return;
    }
    bool created; var m = new Mutex(true, "NangmanTaurenTranslatorSetup", out created);
    if (!created) { MessageBox.Show("설치·삭제 창이 이미 열려 있어요.\n작업 표시줄에서 그 창을 찾아 주세요 (와우 뒤에 가려져 있을 수 있어요).", Setup.Product, MessageBoxButtons.OK, MessageBoxIcon.Information, MessageBoxDefaultButton.Button1, MessageBoxOptions.DefaultDesktopOnly); return; }
    try { ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12; } catch { }
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);
    Application.Run(new Setup(a.Any(x => x.Equals("/uninstall", StringComparison.OrdinalIgnoreCase))));
    GC.KeepAlive(m);
  }
}

class Setup : Form {
  public const string Product = "낭만타우렌 와우 포에버 번역기";
  static readonly string InstDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\NangmanTranslator");
  static readonly string[] LegacyDirs = { @"C:\낭만타우렌_번역기" };
  const string RunName = "NangmanTaurenTranslator";
  const string UninstKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\NangmanTaurenTranslator";
  const string Version = "2.03";
  static readonly string[] OllamaUrls = { "https://github.com/ollama/ollama/releases/latest/download/OllamaSetup.exe", "https://ollama.com/download/OllamaSetup.exe" };
  static readonly string[] ManifestUrls = { "https://raw.githubusercontent.com/zerazine/nangman-translator/main/model/model.json", "https://zerazine.github.io/nangman-translator/model/model.json" };
  static readonly string RecDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NangmanTranslator");
  static readonly string RecFile = Path.Combine(RecDir, "installed.txt");
  static readonly string LogFile = Path.Combine(Path.GetTempPath(), "NangmanTranslator_setup.log");
  static readonly Color BG = Color.FromArgb(22, 22, 23), PANEL = Color.FromArgb(30, 31, 35), GOLD = Color.FromArgb(224, 185, 90), CREAM = Color.FromArgb(240, 230, 205), DIM = Color.FromArgb(150, 145, 135);

  readonly string Src = AppDomain.CurrentDomain.BaseDirectory;
  string Data { get { return Path.Combine(Src, "data"); } }
  string tier = "high";
  readonly bool uninstallMode;
  public static bool SelfTest, SelfNoEngine; public static string SelfForever;
  Label title, sub, status; TextBox logBox; Button btnMain, btnDel; bool busy; bool installDone;

  public Setup(bool uninstall) {
    uninstallMode = uninstall;
    try { var tf = Path.Combine(Data, "tier.txt"); if (File.Exists(tf)) { var t = File.ReadAllText(tf).Trim().ToLower(); if (t == "low") tier = "low"; else if (t == "high" || t == "mid" || t == "gemma") tier = "high"; } } catch { }
    Text = Product + (uninstall ? " 삭제" : " 설치");
    try { var ico = Path.Combine(Data, @"app\app.ico"); if (!File.Exists(ico)) ico = Path.Combine(InstDir, "app.ico"); if (File.Exists(ico)) Icon = new Icon(ico); } catch { }
    FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
    TopMost = true; Shown += (s0, e0) => { try { Activate(); BringToFront(); } catch { } };
    ClientSize = new Size(560, 400); BackColor = BG; ForeColor = CREAM; Font = new Font("Malgun Gothic", 10f);
    title = new Label { Text = Product, ForeColor = GOLD, Font = new Font("Malgun Gothic", 16f, FontStyle.Bold), AutoSize = true, Location = new Point(24, 20) };
    sub = new Label { Text = uninstall ? "프로그램·번역 모델·게임 애드온·설정·아이콘을 모두 지웁니다. 와우와 다른 애드온은 건드리지 않아요." : TierText() + "\n버튼 하나로 번역 엔진·번역 모델·게임 애드온까지 모두 설치합니다.\n※ 번역 엔진 = Ollama(올라마): 내 PC 안에서 번역하는 무료 공개 프로그램이라 앱 목록에 Ollama가 같이 보여요 (완전 삭제 때 같이 지워져요)", ForeColor = DIM, AutoSize = false, Size = new Size(512, 64), Location = new Point(26, 60) };
    status = new Label { Text = "", ForeColor = CREAM, Font = new Font("Malgun Gothic", 11f, FontStyle.Bold), AutoSize = false, Size = new Size(512, 26), Location = new Point(26, 130) };
    logBox = new TextBox { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = PANEL, ForeColor = CREAM, BorderStyle = BorderStyle.None, Location = new Point(26, 160), Size = new Size(508, 162), Font = new Font("Malgun Gothic", 9.5f) };
    btnMain = MkBtn(uninstall ? "완전 삭제" : "설치", new Point(374, 336), 160, true);
    btnDel = MkBtn("완전 삭제", new Point(26, 336), 120, false);
    btnMain.Click += (s, e) => { if (installDone) { Close(); return; } if (uninstallMode) StartWork(DoUninstall); else StartWork(DoInstall); };
    btnDel.Click += (s, e) => { if (MessageBox.Show("번역기를 완전히 지울까요?\n프로그램·번역 모델·게임 애드온·설정·아이콘이 모두 지워져요.", Product, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes) StartWork(DoUninstall); };
    btnDel.Visible = !uninstall && Installed();
    if (!uninstall && Installed()) { status.Text = "이미 설치되어 있어요. [설치]를 누르면 다시 설치(고치기)해요."; btnMain.Text = "다시 설치 (고치기)"; }
    Controls.AddRange(new Control[] { title, sub, status, logBox, btnMain, btnDel });
    FormClosing += (s, e) => { if (busy) { e.Cancel = true; MessageBox.Show("지금 작업 중이에요. 끝날 때까지 잠시만 기다려 주세요.", Product); } };
  }
  string TierText() {
    if (tier == "low") return "외부 API 버전 · 제미나이·Claude·ChatGPT 등 (본인 키) · 그래픽카드 상관없음";
    return "Gemma 버전 · Gemma 4 E2B (와우 학습판) · 그래픽 메모리 8GB 이상";
  }
  Button MkBtn(string t, Point p, int w, bool primary) {
    var b = new Button { Text = t, Location = p, Size = new Size(w, 40), FlatStyle = FlatStyle.Flat, Font = new Font("Malgun Gothic", 10.5f, FontStyle.Bold), Cursor = Cursors.Hand };
    b.FlatAppearance.BorderColor = GOLD; b.BackColor = primary ? GOLD : BG; b.ForeColor = primary ? Color.FromArgb(26, 20, 5) : GOLD;
    return b;
  }
  static bool Installed() { return File.Exists(Path.Combine(InstDir, "NangmanTranslator.ps1")) || File.Exists(Path.Combine(RecDir, "NangmanTranslator.ps1")) || LegacyDirs.Any(d => File.Exists(Path.Combine(d, "NangmanTranslator.ps1"))); }

  void Ui(Action a) { if (InvokeRequired) Invoke(a); else a(); }
  void Log(string m) {
    try { File.AppendAllText(LogFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + m + "\r\n", Encoding.UTF8); } catch { }
    Ui(() => { logBox.AppendText(m + "\r\n"); });
  }
  void Step(string m) { Log("· " + m); Ui(() => { status.Text = m; }); }
  bool Ask(string m) { if (SelfTest) { Log("  (자동 시험) 질문 → 예: " + m.Replace("\n", " ")); return true; } bool r = false; Ui(() => { r = MessageBox.Show(this, m, Product, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes; }); return r; }
  void Say(string m, MessageBoxIcon ic) { if (SelfTest) { Log("  (자동 시험) 안내: " + m.Replace("\n", " ")); return; } Ui(() => { MessageBox.Show(this, m, Product, MessageBoxButtons.OK, ic); }); }
  void StartWork(Action work) {
    if (busy) return; busy = true; btnMain.Enabled = false; btnDel.Enabled = false;
    var prevText = btnMain.Text; var busyText = uninstallMode || work == (Action)DoUninstall ? "삭제 중…" : "설치 중…";
    btnMain.Text = busyText; btnMain.BackColor = Color.FromArgb(58, 50, 28); btnMain.Cursor = Cursors.Default;
    var th = new Thread(() => {
      try { work(); }
      catch (Exception ex) { Log("오류: " + ex); Ui(() => { status.Text = "문제가 생겼어요"; }); Say("예상 못 한 문제가 생겼어요: " + ex.Message + "\n\n다시 누르면 이어서 해요.\n기록 파일: " + LogFile, MessageBoxIcon.Error); }
      finally { busy = false; Ui(() => { btnMain.Enabled = true; btnDel.Enabled = true; btnMain.BackColor = GOLD; btnMain.Cursor = Cursors.Hand; if (btnMain.Text == busyText) btnMain.Text = prevText; }); }
    });
    th.IsBackground = true; th.SetApartmentState(ApartmentState.STA); th.Start();
  }

  class Gpu { public string Name = ""; public long Bytes; }
  static Gpu BestGpu() {
    var best = new Gpu();
    try {
      using (var cls = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}")) {
        if (cls == null) return best;
        foreach (var n in cls.GetSubKeyNames()) {
          if (!n.All(char.IsDigit)) continue;
          using (var k = cls.OpenSubKey(n)) {
            if (k == null) continue;
            var name = Convert.ToString(k.GetValue("DriverDesc") ?? "");
            long bytes = RegLong(k.GetValue("HardwareInformation.qwMemorySize"));
            if (bytes <= 0) bytes = RegLong(k.GetValue("HardwareInformation.MemorySize"));
            if (bytes > best.Bytes) { best.Bytes = bytes; best.Name = name; }
          }
        }
      }
    } catch { }
    return best;
  }
  static long RegLong(object v) {
    if (v == null) return 0;
    if (v is long) return (long)v;
    if (v is int) return (uint)(int)v;
    var b = v as byte[];
    if (b != null && b.Length > 0) { var p = new byte[8]; Array.Copy(b, p, Math.Min(8, b.Length)); return BitConverter.ToInt64(p, 0); }
    return 0;
  }

  static string FindForever() {
    var c = new List<string>();
    foreach (var rk in new[] { @"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft", @"SOFTWARE\Blizzard Entertainment\World of Warcraft" }) {
      try { using (var k = Registry.LocalMachine.OpenSubKey(rk)) { var p = k == null ? null : k.GetValue("InstallPath") as string; if (!string.IsNullOrEmpty(p)) { p = p.TrimEnd(new[] { '\\' }); c.Add(Path.GetDirectoryName(p)); c.Add(p); } } } catch { }
    }
    foreach (var d in DriveInfo.GetDrives()) {
      try {
        if (d.DriveType != DriveType.Fixed || !d.IsReady) continue;
        var r = d.RootDirectory.FullName;
        foreach (var s in new[] { @"Program Files (x86)\World of Warcraft", @"Program Files\World of Warcraft", "World of Warcraft", @"Games\World of Warcraft", @"Game\World of Warcraft", @"Blizzard\World of Warcraft", @"Battle.net\World of Warcraft" }) c.Add(Path.Combine(r, s));
      } catch { }
    }
    foreach (var p in c) { try { if (string.IsNullOrEmpty(p)) continue; var f = Path.Combine(p, "_forever_"); if (Directory.Exists(f)) return f; if (Path.GetFileName(p) == "_forever_" && Directory.Exists(p)) return p; } catch { } }
    return null;
  }
  static bool WowOn() { return Process.GetProcessesByName("Wow").Length + Process.GetProcessesByName("WowClassic").Length + Process.GetProcessesByName("Wow-64").Length > 0; }
  void WaitWowOff(string why) {
    if (!WowOn()) return;
    Step("와우를 꺼 주세요");
    Log(why);
    Say(why + "\n와우를 끄면 바로 이어서 진행해요.", MessageBoxIcon.Information);
    while (WowOn()) Thread.Sleep(1500);
  }

  static string FindOllama() {
    var l = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    foreach (var p in new[] { Path.Combine(l, @"Programs\Ollama\ollama.exe"), Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Ollama\ollama.exe") }) if (File.Exists(p)) return p;
    foreach (var d in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(new[] { ';' })) { try { var p = Path.Combine(d.Trim(), "ollama.exe"); if (File.Exists(p)) return p; } catch { } }
    return null;
  }
  static string Http(string method, string url, string body, int timeoutMs) {
    var req = (HttpWebRequest)WebRequest.Create(url); req.Method = method; req.Timeout = timeoutMs; req.ReadWriteTimeout = timeoutMs; req.Proxy = null;
    if (body != null) { var b = Encoding.UTF8.GetBytes(body); req.ContentType = "application/json"; req.ContentLength = b.Length; using (var s = req.GetRequestStream()) s.Write(b, 0, b.Length); }
    using (var r = (HttpWebResponse)req.GetResponse()) using (var sr = new StreamReader(r.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
  }
  static bool OllamaUp() { try { Http("GET", "http://127.0.0.1:11434/api/version", null, 2000); return true; } catch { return false; } }
  int Run(string exe, string args, string wd, int timeoutMin) {
    var psi = new ProcessStartInfo(exe, args) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8 };
    if (wd != null) psi.WorkingDirectory = wd;
    psi.EnvironmentVariables["OLLAMA_HOST"] = "127.0.0.1:11434";
    using (var p = Process.Start(psi)) {
      var sb = new StringBuilder();
      p.OutputDataReceived += (s, e) => { if (e.Data != null) lock (sb) sb.AppendLine(e.Data); };
      p.ErrorDataReceived += (s, e) => { if (e.Data != null) lock (sb) sb.AppendLine(e.Data); };
      p.BeginOutputReadLine(); p.BeginErrorReadLine();
      if (!p.WaitForExit(timeoutMin * 60000)) { try { p.Kill(); } catch { } Log("시간 초과: " + exe + " " + args); return -1; }
      p.WaitForExit();
      var o = sb.ToString(); var lines = o.Split(new[] { '\n' }).Where(x => x.Trim().Length > 0 && !x.Contains("%")).ToArray();
      Log("  " + Path.GetFileName(exe) + " → " + p.ExitCode + (lines.Length > 0 ? " · " + string.Join(" / ", lines.Skip(Math.Max(0, lines.Length - 3)).Select(x => x.Trim())) : ""));
      return p.ExitCode;
    }
  }
  void OllamaDiag(string exe) {
    try {
      Log("  [엔진 진단] 위치: " + exe);
      try { var v = FileVersionInfo.GetVersionInfo(exe); Log("  [엔진 진단] 파일 버전: " + (v.ProductVersion ?? v.FileVersion ?? "?")); } catch { }
      Log("  [엔진 진단] OLLAMA_HOST 사용자=" + (Environment.GetEnvironmentVariable("OLLAMA_HOST", EnvironmentVariableTarget.User) ?? "없음") + " · 시스템=" + (Environment.GetEnvironmentVariable("OLLAMA_HOST", EnvironmentVariableTarget.Machine) ?? "없음"));
      Log("  [엔진 진단] OLLAMA_MODELS 사용자=" + (Environment.GetEnvironmentVariable("OLLAMA_MODELS", EnvironmentVariableTarget.User) ?? "없음") + " · 시스템=" + (Environment.GetEnvironmentVariable("OLLAMA_MODELS", EnvironmentVariableTarget.Machine) ?? "없음"));
      var ps = new List<string>(); foreach (var n in new[] { "ollama app", "ollama" }) foreach (var p in Process.GetProcessesByName(n)) ps.Add(p.ProcessName + "#" + p.Id);
      Log("  [엔진 진단] 실행 중: " + (ps.Count == 0 ? "없음" : string.Join(", ", ps.ToArray())));
      var psi = new ProcessStartInfo("netstat", "-ano -p TCP") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true };
      using (var np = Process.Start(psi)) {
        var o = np.StandardOutput.ReadToEnd(); np.WaitForExit(5000); bool any = false;
        foreach (var ln in o.Split(new[] { '\n' })) {
          var t = ln.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
          if (t.Length >= 5 && t[1].EndsWith(":11434")) { string nm = "?"; try { nm = Process.GetProcessById(int.Parse(t[t.Length - 1])).ProcessName; } catch { } Log("  [엔진 진단] 11434 포트: " + t[1] + " " + t[3] + " · " + nm + "#" + t[t.Length - 1]); any = true; }
        }
        if (!any) Log("  [엔진 진단] 11434 포트: 아무도 안 씀");
      }
    } catch (Exception ex) { Log("  [엔진 진단] 실패: " + ex.Message); }
  }
  static void KillOllama() { foreach (var n in new[] { "ollama app", "ollama" }) foreach (var p in Process.GetProcessesByName(n)) { try { p.Kill(); p.WaitForExit(5000); } catch { } } }
  bool WaitUp(int sec) { for (int i = 0; i < sec && !OllamaUp(); i++) Thread.Sleep(1000); return OllamaUp(); }
  void EnsureOllamaRunning(string exe, bool repair = false) {
    if (OllamaUp()) return;
    Step("번역 엔진 켜는 중");
    OllamaDiag(exe);
    var app = Path.Combine(Path.GetDirectoryName(exe), "ollama app.exe");
    if (File.Exists(app)) {
      try { Process.Start(new ProcessStartInfo(app) { UseShellExecute = true, WindowStyle = ProcessWindowStyle.Hidden }); } catch (Exception ex) { Log("  엔진 앱 켜기 실패: " + ex.Message); }
      if (WaitUp(25)) { Log("  엔진 앱으로 켜짐"); return; }
      Log("  엔진 앱으로 25초 안에 안 켜짐 → 직접 켜 봄");
    }
    KillOllama(); Thread.Sleep(1500);
    var slog = Path.Combine(Path.GetTempPath(), "NangmanTranslator_ollama_serve.log");
    try { File.WriteAllText(slog, "", Encoding.UTF8); } catch { }
    try {
      var psi = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe"), "/c \"\"" + exe + "\" serve > \"" + slog + "\" 2>&1\"") { UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden };
      psi.EnvironmentVariables["OLLAMA_HOST"] = "127.0.0.1:11434";
      Process.Start(psi);
    } catch (Exception ex) { Log("  엔진 직접 켜기 실패: " + ex.Message); }
    if (WaitUp(40)) { Log("  엔진 직접 켜기(serve)로 켜짐"); return; }
    try {
      var tail = File.ReadAllLines(slog).Where(x => x.Trim().Length > 0).ToArray();
      Log("  엔진 출력 마지막 줄들:"); foreach (var x in tail.Skip(Math.Max(0, tail.Length - 10))) Log("    " + (x.Length > 300 ? x.Substring(0, 300) : x));
    } catch { Log("  엔진 출력 없음"); }
    if (repair) {
      Log("  엔진이 망가진 것으로 보여 다시 설치해서 고침");
      Step("번역 엔진이 제대로 안 깔려 있어서 다시 설치하는 중");
      InstallOllama(true);
      var e2 = FindOllama() ?? exe;
      EnsureOllamaRunning(e2, false);
      return;
    }
    OllamaDiag(exe);
    throw new Exception("번역 엔진(Ollama)이 켜지지 않았어요.\n\n와우를 완전히 끄고, PC를 다시 시작한 뒤 설치를 다시 눌러 주세요.\n그래도 안 되면 아래 기록 파일을 보내 주세요.");
  }
  string ModelName() { return "nangman-gemma"; }
  void BgSound(string forever) {
    try {
      var wtf = Path.Combine(forever, "WTF"); Directory.CreateDirectory(wtf);
      var cf = Path.Combine(wtf, "Config.wtf");
      const string key = "Sound_EnableSoundWhenGameIsInBackground";
      var ls = File.Exists(cf) ? new List<string>(File.ReadAllLines(cf)) : new List<string>();
      bool hit = false;
      for (int i = 0; i < ls.Count; i++) if (ls[i].StartsWith("SET " + key + " ", StringComparison.OrdinalIgnoreCase)) { ls[i] = "SET " + key + " \"1\""; hit = true; }
      if (!hit) ls.Add("SET " + key + " \"1\"");
      File.WriteAllLines(cf, ls.ToArray(), new UTF8Encoding(false));
      Log("  백그라운드 소리 켬");
    } catch (Exception ex) { Log("  백그라운드 소리: " + ex.Message); }
  }
  static readonly System.Text.RegularExpressions.Regex EngFileErr = new System.Text.RegularExpressions.Regex(@"binary not found|llama-server[^\n]*not found|\.dll[^\n]*(not found|missing)|cannot find the file|no such file", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
  string TryGenerate() {
    try { Http("POST", "http://127.0.0.1:11434/api/generate", "{\"model\":\"" + ModelName() + "\",\"prompt\":\"hi\",\"stream\":false,\"keep_alive\":0,\"options\":{\"num_predict\":1}}", 240000); return null; }
    catch (WebException ex) {
      string b = ex.Message;
      try { if (ex.Response != null) using (var sr = new StreamReader(ex.Response.GetResponseStream(), Encoding.UTF8)) b = sr.ReadToEnd(); } catch { }
      return b ?? "";
    }
    catch (Exception ex) { return ex.Message ?? ""; }
  }
  void EngineCheck(ref string ol) {
    Step("번역 엔진 시험 중");
    var e = TryGenerate();
    if (e == null) { Log("  시험 번역 통과"); return; }
    Log("  시험 번역 실패: " + (e.Length > 300 ? e.Substring(0, 300) : e));
    if (!EngFileErr.IsMatch(e)) return;
    Log("  엔진 파일이 빠져 있어서 다시 설치해서 고침");
    Step("번역 엔진 파일이 빠져 있어서 엔진만 다시 설치해요 (1~3분 · 번역 모델은 그대로)");
    InstallOllama(true);
    ol = FindOllama(); if (ol == null) throw new Exception("번역 엔진 업데이트가 끝나지 않았어요. 다시 눌러 주세요.");
    EnsureOllamaRunning(ol);
    Step("번역 엔진 시험 중");
    e = TryGenerate();
    if (e == null) { Log("  다시 설치 후 시험 번역 통과"); return; }
    Log("  다시 설치 후에도 시험 번역 실패: " + (e.Length > 300 ? e.Substring(0, 300) : e));
    if (EngFileErr.IsMatch(e)) throw new Exception("번역 엔진(Ollama) 파일이 설치 직후 다시 없어졌어요.\n\n백신 프로그램이 Ollama 파일을 지우고 있을 가능성이 커요.\n백신 검역소에서 Ollama 파일을 복원하고, Ollama 폴더를 예외(검사 제외)로 등록한 뒤 설치를 다시 눌러 주세요.");
  }

  static HttpWebRequest Web(string url, long from) {
    var r = (HttpWebRequest)WebRequest.Create(url); r.UserAgent = "NangmanTranslatorSetup/" + Version; r.Timeout = 30000; r.ReadWriteTimeout = 120000; r.AllowAutoRedirect = true;
    if (from > 0) r.AddRange(from);
    return r;
  }
  static string GetText(string url) { using (var resp = (HttpWebResponse)Web(url, 0).GetResponse()) using (var sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd(); }
  void Progress(string label, long done, long total, Stopwatch sw) {
    double mb = done / 1048576.0, sec = Math.Max(0.5, sw.Elapsed.TotalSeconds), speed = mb / sec;
    string t = total > 0 ? string.Format("{0} 받는 중 {1:0}% · {2:0.0}/{3:0.0}GB · 초당 {4:0}MB", label, 100.0 * done / total, done / 1073741824.0, total / 1073741824.0, speed)
                         : string.Format("{0} 받는 중 · {1:0}MB · 초당 {2:0}MB", label, mb, speed);
    if (total > 0 && speed > 0.1) { double left = (total - done) / 1048576.0 / speed; t += left >= 60 ? string.Format(" · 약 {0:0}분 남음", Math.Ceiling(left / 60)) : " · 곧 끝나요"; }
    Ui(() => { status.Text = t; });
  }
  long Fetch(string url, Stream outS, HashAlgorithm h, string label, long doneBefore, long total, Stopwatch sw) {
    long got = 0, expect = -1; int fails = 0;
    while (true) {
      try {
        using (var resp = (HttpWebResponse)Web(url, got).GetResponse()) {
          if (got > 0 && resp.StatusCode != HttpStatusCode.PartialContent) throw new Exception("서버가 이어받기를 지원하지 않음");
          if (expect < 0) expect = resp.ContentLength;
          using (var s = resp.GetResponseStream()) {
            var buf = new byte[1 << 20]; int n; var last = DateTime.MinValue;
            while ((n = s.Read(buf, 0, buf.Length)) > 0) {
              outS.Write(buf, 0, n); if (h != null) h.TransformBlock(buf, 0, n, null, 0); got += n;
              if ((DateTime.Now - last).TotalMilliseconds > 500) { last = DateTime.Now; Progress(label, doneBefore + got, total > 0 ? total : (expect > 0 ? expect : 0), sw); }
            }
          }
        }
        if (expect > 0 && got < expect) throw new IOException("받다가 끊김 (" + got + "/" + expect + ")");
        return got;
      } catch (Exception ex) {
        if (++fails > 6) throw new Exception(label + " 받기가 계속 끊겨요. 인터넷 연결을 확인하고 [다시 설치]를 눌러 주세요. (" + ex.Message + ")");
        Log("  " + label + " 받기 끊김 → 이어받기 " + fails + "/6 · " + ex.Message); Thread.Sleep(3000 * fails);
      }
    }
  }
  class ModelInfo { public string Sha = ""; public long Size; public string[] Parts = new string[0]; }
  ModelInfo ReadModelInfo() {
    string js = null;
    foreach (var u in ManifestUrls) { try { js = GetText(u + "?t=" + DateTime.Now.Ticks); break; } catch (Exception ex) { Log("  모델 정보 못 받음: " + u + " · " + ex.Message); } }
    if (js == null) throw new Exception("번역 모델 정보를 받지 못했어요. 인터넷 연결을 확인하고 [다시 설치]를 눌러 주세요.");
    var j = new System.Web.Script.Serialization.JavaScriptSerializer().DeserializeObject(js) as Dictionary<string, object>;
    if (j == null || !j.ContainsKey("sha256") || !j.ContainsKey("size") || !j.ContainsKey("parts")) throw new Exception("번역 모델 정보가 이상해요. 잠시 뒤 다시 눌러 주세요.");
    var mi = new ModelInfo { Sha = Convert.ToString(j["sha256"]).Trim().ToLower(), Size = Convert.ToInt64(j["size"]) };
    var ps = j["parts"] as object[]; if (ps == null || ps.Length == 0) throw new Exception("번역 모델 정보에 받을 주소가 없어요.");
    mi.Parts = ps.Select(x => Convert.ToString(x)).ToArray();
    return mi;
  }
  string DownloadModel(ModelInfo mi) {
    var dir = Path.Combine(InstDir, "model"); Directory.CreateDirectory(dir);
    var dst = Path.Combine(dir, "nangman-gemma.gguf"); var tmp = dst + ".part";
    try { if (File.Exists(dst) && new FileInfo(dst).Length == mi.Size && File.Exists(dst + ".sha") && File.ReadAllText(dst + ".sha").Trim().ToLower() == mi.Sha) { Log("  번역 모델 파일이 이미 있음 (받기 건너뜀)"); return dst; } } catch { }
    try { var c = new DriveInfo("C"); if (c.AvailableFreeSpace < mi.Size + 1073741824L) throw new Exception(string.Format("C 드라이브 남은 공간이 부족해요 ({0:0.0}GB 남음). 공간을 비운 뒤 다시 눌러 주세요.", c.AvailableFreeSpace / 1073741824.0)); } catch (IOException) { }
    Log(string.Format("  번역 모델 받기 · {0:0.00}GB · 조각 {1}개", mi.Size / 1073741824.0, mi.Parts.Length));
    var sw = Stopwatch.StartNew();
    try {
      using (var sha = SHA256.Create())
      using (var fs = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20)) {
        long done = 0;
        foreach (var u in mi.Parts) done += Fetch(u, fs, sha, "번역 모델", done, mi.Size, sw);
        sha.TransformFinalBlock(new byte[0], 0, 0);
        if (done != mi.Size) throw new Exception(string.Format("받은 번역 모델 크기가 달라요 ({0}/{1}). 다시 눌러 주세요.", done, mi.Size));
        var got = BitConverter.ToString(sha.Hash).Replace("-", "").ToLower();
        if (got != mi.Sha) throw new Exception("받은 번역 모델 파일이 깨졌어요. 다시 눌러 주세요.");
      }
      if (File.Exists(dst)) File.Delete(dst);
      File.Move(tmp, dst); File.WriteAllText(dst + ".sha", mi.Sha);
      Log(string.Format("  번역 모델 받음 · {0:0}분 · 검사 통과", sw.Elapsed.TotalMinutes));
      return dst;
    } catch { try { if (File.Exists(tmp)) File.Delete(tmp); } catch { } throw; }
  }

  static Dictionary<string, string> ReadRec() {
    var d = new Dictionary<string, string>();
    try { if (File.Exists(RecFile)) foreach (var ln in File.ReadAllLines(RecFile, Encoding.UTF8)) { var i = ln.IndexOf('='); if (i > 0) d[ln.Substring(0, i).Trim().TrimStart(new[] { '\uFEFF' })] = ln.Substring(i + 1); } } catch { }
    return d;
  }
  static void WriteRec(Dictionary<string, string> d) { Directory.CreateDirectory(RecDir); File.WriteAllLines(RecFile, d.Select(kv => kv.Key + "=" + kv.Value).ToArray(), new UTF8Encoding(true)); }

  void DelDir(string d, string what) {
    try { if (!Directory.Exists(d)) return; Directory.Delete(d, true); Log("  " + what + " 지움: " + d); return; } catch (Exception ex) { Log("  " + what + " 바로 못 지움(" + ex.Message + ") → 끝난 뒤 지움"); }
    try { Process.Start(new ProcessStartInfo("cmd.exe", "/c for /l %i in (1,1,90) do @(timeout /t 2 /nobreak >nul & rmdir /s /q \"" + d + "\" 2>nul & if not exist \"" + d + "\" exit)") { CreateNoWindow = true, UseShellExecute = false, WorkingDirectory = Path.GetTempPath() }); } catch { }
  }
  static void KillTranslator() {
    try {
      foreach (var p in Process.GetProcessesByName("powershell")) {
        try { var cl = CmdLine(p.Id); if (cl != null && cl.IndexOf("NangmanTranslator.ps1", StringComparison.OrdinalIgnoreCase) >= 0) p.Kill(); } catch { }
      }
    } catch { }
  }
  static string CmdLine(int pid) {
    try {
      var t = Type.GetTypeFromProgID("WbemScripting.SWbemLocator"); var loc = Activator.CreateInstance(t);
      var svc = t.InvokeMember("ConnectServer", System.Reflection.BindingFlags.InvokeMethod, null, loc, new object[] { ".", @"root\cimv2" });
      var set = svc.GetType().InvokeMember("ExecQuery", System.Reflection.BindingFlags.InvokeMethod, null, svc, new object[] { "SELECT CommandLine FROM Win32_Process WHERE ProcessId=" + pid });
      foreach (var o in (System.Collections.IEnumerable)set) { return Convert.ToString(o.GetType().InvokeMember("CommandLine", System.Reflection.BindingFlags.GetProperty, null, o, null)); }
    } catch { }
    return null;
  }
  string lnkNote = "";
  bool SafeShortcut(string lnk, string target, string args, string wd, string icon, string desc) {
    for (int i = 0; i < 2; i++) {
      try {
        if (File.Exists(lnk)) { try { File.SetAttributes(lnk, FileAttributes.Normal); File.Delete(lnk); } catch { } }
        Shortcut(lnk, target, args, wd, icon, desc); return true;
      } catch (Exception ex) {
        var e = ex; while (e.InnerException != null) e = e.InnerException;
        Log("  바로가기 실패 (" + Path.GetFileName(lnk) + "): " + e.Message);
        if (i == 0) icon = "";
      }
    }
    return false;
  }
  [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class CShellLink { }
  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
  interface IShellLinkW {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int cch, IntPtr fd, int flags);
    void GetIDList(out IntPtr ppidl); void SetIDList(IntPtr pidl);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder n, int cch); void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string n);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder d, int cch); void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string d);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder a, int cch); void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string a);
    void GetHotkey(out short k); void SetHotkey(short k);
    void GetShowCmd(out int c); void SetShowCmd(int c);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder p, int cch, out int i); void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string p, int i);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string p, int r);
    void Resolve(IntPtr hwnd, int flags);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string f);
  }
  static void Shortcut(string lnk, string target, string args, string wd, string icon, string desc) {
    Directory.CreateDirectory(Path.GetDirectoryName(lnk));
    var sl = (IShellLinkW)new CShellLink();
    try {
      sl.SetPath(target); sl.SetArguments(args ?? ""); sl.SetWorkingDirectory(wd ?? ""); sl.SetDescription(desc ?? "");
      if (File.Exists(icon)) sl.SetIconLocation(icon, 0);
      ((System.Runtime.InteropServices.ComTypes.IPersistFile)sl).Save(lnk, true);
    } finally { Marshal.ReleaseComObject(sl); }
    if (!File.Exists(lnk)) throw new IOException("바로가기 파일이 안 생김: " + lnk);
  }
  static void CopyDir(string from, string to, Func<string, bool> skip) {
    Directory.CreateDirectory(to);
    foreach (var f in Directory.GetFiles(from)) { var dst = Path.Combine(to, Path.GetFileName(f)); if (skip != null && skip(dst)) continue; if (File.Exists(dst)) File.SetAttributes(dst, FileAttributes.Normal); File.Copy(f, dst, true); }
    foreach (var d in Directory.GetDirectories(from)) CopyDir(d, Path.Combine(to, Path.GetFileName(d)), skip);
  }
  public static void RunApp() {
    try {
      var dir = Path.GetDirectoryName(Application.ExecutablePath); var ps1 = Path.Combine(dir, "NangmanTranslator.ps1");
      if (!File.Exists(ps1)) { dir = InstDir; ps1 = Path.Combine(InstDir, "NangmanTranslator.ps1"); }
      var psi = new ProcessStartInfo(PsExe, "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"") { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = dir };
      psi.EnvironmentVariables["NT_LAUNCH"] = "1";
      Process.Start(psi);
    } catch { }
  }
  static string Launcher { get { return Path.Combine(InstDir, "NangmanTranslator.exe"); } }
  static string PsExe { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"System32\WindowsPowerShell\v1.0\powershell.exe"); } }
  static string PsArgs { get { return "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + Path.Combine(InstDir, "NangmanTranslator.ps1") + "\""; } }
  static string DesktopLnk { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Product + ".lnk"); } }
  static string MenuDir { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), Product); } }

  void InstallOllama(bool upgrade) {
    var setupExe = Path.Combine(Data, @"ollama\OllamaSetup.exe"); bool dl = false;
    if (upgrade || !File.Exists(setupExe)) {
      setupExe = Path.Combine(Path.GetTempPath(), "NangmanTranslator_OllamaSetup.exe"); dl = true;
      Step(upgrade ? "번역 엔진(Ollama) 최신판 받는 중" : "번역 엔진(Ollama) 받는 중");
      Exception le = null;
      foreach (var ou in OllamaUrls) {
        try { using (var fs = new FileStream(setupExe, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20)) Fetch(ou, fs, null, "번역 엔진", 0, 0, Stopwatch.StartNew()); le = null; break; }
        catch (Exception ex) { le = ex; Log("  번역 엔진 받기 실패: " + ou + " · " + ex.Message); }
      }
      if (le != null) throw le;
      if (new FileInfo(setupExe).Length < 50L * 1048576) throw new Exception("번역 엔진 설치 파일이 제대로 받아지지 않았어요. 다시 눌러 주세요.");
    }
    if (upgrade) {
      foreach (var n in new[] { "ollama app", "ollama" }) foreach (var p in Process.GetProcessesByName(n)) { try { p.Kill(); p.WaitForExit(5000); } catch { } }
      Thread.Sleep(1500);
    }
    Log("  ※ 번역 엔진 = Ollama(올라마): 내 PC 안에서 AI 번역 모델을 돌리는 무료 공개 프로그램 (MIT 라이선스)");
    Log("     채팅 내용을 밖으로 보내지 않고 내 PC에서 번역해요 · 윈도우 앱 목록에 'Ollama'로 보여요 · 번역기를 완전 삭제하면 같이 지워져요");
    Step(upgrade ? "번역 엔진 업데이트 중 (1~3분)" : "번역 엔진 설치 중 (1~3분)");
    int rc = Run(setupExe, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-", null, 15);
    Log("  번역 엔진 설치 종료 코드 " + rc);
    if (dl) try { File.Delete(setupExe); } catch { }
  }

  void DoInstall() {
    File.WriteAllText(LogFile, "", Encoding.UTF8);
    Log("===== 설치 시작 " + Version + " · " + tier + " · " + Src);
    WaitWowOff("와우가 켜져 있으면 설치 중에 화면이 꺼지거나 PC가 다시 켜질 수 있어요. 와우를 먼저 완전히 꺼 주세요.");
    var need = new List<string> { @"app\NangmanTranslator.ps1", @"addon\NangmanTranslator" };
    if (tier != "low") need.Add(@"model\Modelfile");
    if (!Directory.Exists(Data)) throw new Exception("설치 자료(data 폴더)를 찾지 못했어요. 받은 zip을 끝까지 푼 뒤, 풀린 폴더 안의 이 파일을 실행해 주세요.");
    foreach (var n in need) { var p = Path.Combine(Data, n); if (!File.Exists(p) && !Directory.Exists(p)) throw new Exception("설치 자료가 빠져 있어요 (" + n + "). 받은 zip을 다시 받아 끝까지 풀어 주세요."); }
    string gguf = null;
    if (tier != "low") gguf = Directory.GetFiles(Path.Combine(Data, "model"), "*.gguf").FirstOrDefault();

    Step("내 PC 확인 중");
    var g = BestGpu(); double gb = g.Bytes / 1073741824.0;
    Log("  그래픽카드: " + (g.Name == "" ? "확인 안 됨" : g.Name) + (g.Bytes > 0 ? string.Format(" · {0:0.#}GB", gb) : ""));
    if (tier != "low") {
      bool nv = g.Name.IndexOf("NVIDIA", StringComparison.OrdinalIgnoreCase) >= 0;
      string warn = null;
      if (g.Bytes > 0 && gb < 7.5) warn = "그래픽 메모리가 8GB보다 작아서 와우와 같이 쓰기엔 무거울 수 있어요. 외부 API 버전을 권해요.";
      if (warn != null && !Ask(warn + string.Format("\n\n(내 그래픽카드: {0} · {1:0.#}GB)\n\n그래도 계속 설치할까요?", g.Name, gb))) { Step("설치를 멈췄어요"); return; }
      if (warn == null && g.Bytes > 0 && gb < 9.5) Say(string.Format("그래픽 메모리 {0:0}GB 카드예요. Gemma 버전을 그대로 설치해요.\n\n다만 번역 모델이 와우와 그래픽 메모리를 나눠 써서, 게임이 버벅이거나 번역이 늦어질 수 있어요.\n그럴 땐 와우 포에버 그래픽 설정(텍스처 해상도·SSAO·그림자 등)을 조금 낮춰 주세요.\n추천 설정은 설명서의 '그래픽 메모리 8GB라면' 칸에 있어요.", gb), MessageBoxIcon.Information);
    }
    double needGB = tier == "low" ? 0.5 : 9;
    try { var c = new DriveInfo("C"); double free = c.AvailableFreeSpace / 1073741824.0; Log(string.Format("  C 드라이브 남은 공간 {0:0}GB", free)); if (free < needGB) throw new Exception(string.Format("C 드라이브 남은 공간이 부족해요 ({0:0.0}GB 남음 · {1:0}GB 필요). 공간을 비운 뒤 다시 눌러 주세요.", free, needGB)); } catch (IOException) { }

    Step("와우 포에버 폴더 찾는 중");
    var forever = SelfTest && !string.IsNullOrEmpty(SelfForever) ? SelfForever : FindForever();
    if (forever == null) {
      Ui(() => {
        using (var fb = new FolderBrowserDialog { Description = "와우 포에버 폴더(_forever_)를 골라 주세요. 보통 World of Warcraft\\_forever_ 입니다." }) {
          if (fb.ShowDialog(this) == DialogResult.OK) { var p = fb.SelectedPath; if (Path.GetFileName(p) != "_forever_" && Directory.Exists(Path.Combine(p, "_forever_"))) p = Path.Combine(p, "_forever_"); forever = p; }
        }
      });
      if (forever == null || !Directory.Exists(forever)) throw new Exception("와우 포에버 폴더(_forever_)를 찾지 못했어요. 다시 눌러서 폴더를 골라 주세요.");
    }
    Log("  와우 포에버: " + forever);

    var rec = ReadRec();
    bool olByUs = rec.ContainsKey("ollamaByUs") && rec["ollamaByUs"] == "1";
    if (tier != "low" && SelfNoEngine) Log("  (자동 시험) 번역 엔진·모델 단계 건너뜀");
    else if (tier != "low") {
      var ol = FindOllama();
      if (ol == null) { InstallOllama(false); ol = FindOllama(); if (ol == null) throw new Exception("번역 엔진 설치가 끝나지 않았어요. 다시 눌러 주세요."); olByUs = true; }
      EnsureOllamaRunning(ol, true);
      ModelInfo mi = null; bool skipModel = false;
      if (gguf == null) {
        Step("번역 모델 정보 확인 중");
        mi = ReadModelInfo();
        string tags = ""; try { tags = Http("GET", "http://127.0.0.1:11434/api/tags", null, 5000); } catch { }
        string had; bool hasTag = tags.Contains("\"" + ModelName() + ":");
        skipModel = rec.TryGetValue("modelSha", out had) && had == mi.Sha && hasTag;
        if (!skipModel && hasTag && !rec.ContainsKey("modelSha") && rec.ContainsKey("version") && mi.Sha == "b56907fa8b52e5254eca67d6e39f52bf55dc3ff7f71f4ee90ae8f521e32c25cc") { skipModel = true; rec["modelSha"] = mi.Sha; }
        if (skipModel) Log("  같은 번역 모델이 이미 들어가 있음 (받기 건너뜀)");
        else gguf = DownloadModel(mi);
      }
      if (!skipModel) {
      Step("번역 모델 넣는 중 (몇 분)");
      var mf = File.ReadAllLines(Path.Combine(Data, @"model\Modelfile"), Encoding.UTF8).ToList();
      int fi = mf.FindIndex(x => x.TrimStart(new[] { ' ', '\t' }).StartsWith("FROM ", StringComparison.OrdinalIgnoreCase));
      var fromLine = "FROM \"" + gguf + "\"";
      if (fi >= 0) mf[fi] = fromLine; else mf.Insert(0, fromLine);
      var tmpMf = Path.Combine(Path.GetTempPath(), "NangmanTranslator_Modelfile");
      File.WriteAllLines(tmpMf, mf.ToArray(), new UTF8Encoding(false));
      int rc2 = Run(ol, "create " + ModelName() + " -f \"" + tmpMf + "\"", Path.GetDirectoryName(gguf), 40);
      if (rc2 != 0) {
        Log("  모델 넣기 실패 → 번역 엔진을 최신으로 올린 뒤 다시 시도");
        InstallOllama(true);
        ol = FindOllama(); if (ol == null) throw new Exception("번역 엔진 업데이트가 끝나지 않았어요. 다시 눌러 주세요.");
        EnsureOllamaRunning(ol);
        Step("번역 모델 넣는 중 (몇 분)");
        rc2 = Run(ol, "create " + ModelName() + " -f \"" + tmpMf + "\"", Path.GetDirectoryName(gguf), 40);
      }
      if (rc2 != 0) throw new Exception("번역 모델을 넣지 못했어요 (종료 코드 " + rc2 + "). 다시 눌러 주세요.");
      try {
        string tg = Http("GET", "http://127.0.0.1:11434/api/tags", null, 5000);
        if (tg.Contains("\"sabi:") || tg.Contains("\"sabi\"")) { Step("예전 번역 모델(사비) 정리 중"); int rr = Run(ol, "rm sabi", null, 2); Log("  예전 사비 모델 정리 · 종료 코드 " + rr); }
      } catch (Exception ex) { Log("  예전 모델 정리: " + ex.Message); }
      if (mi != null) {
        rec["modelSha"] = mi.Sha;
        try { File.Delete(gguf); File.Delete(gguf + ".sha"); Log("  받은 원본 파일 정리"); } catch (Exception ex) { Log("  원본 정리: " + ex.Message); }
      }
      }
      EngineCheck(ref ol);
    }

    Step("프로그램 넣는 중");
    KillTranslator(); Thread.Sleep(800);
    Directory.CreateDirectory(InstDir);
    var movedFrom = new List<string>();
    foreach (var ld in LegacyDirs) {
      try {
        if (!Directory.Exists(ld) || string.Equals(Path.GetFullPath(ld).TrimEnd(new[] { '\\' }), Path.GetFullPath(InstDir).TrimEnd(new[] { '\\' }), StringComparison.OrdinalIgnoreCase)) continue;
        if (!File.Exists(Path.Combine(ld, "NangmanTranslator.ps1"))) continue;
        CopyDir(ld, InstDir, dst => File.Exists(dst) || dst.IndexOf(@"\model\", StringComparison.OrdinalIgnoreCase) >= 0);
        movedFrom.Add(ld); Log("  예전 자리에서 설정 옮겨 옴: " + ld);
      } catch (Exception ex) { Log("  예전 자리 옮기기: " + ex.Message); }
    }
    var oldSet = Path.Combine(RecDir, "settings.json"); var newSet = Path.Combine(InstDir, "settings.json");
    if (File.Exists(oldSet) && !File.Exists(newSet)) { File.Copy(oldSet, newSet); Log("  예전 설정 옮김"); }
    CopyDir(Path.Combine(Data, "app"), InstDir, dst => Path.GetFileName(dst).Equals("settings.json", StringComparison.OrdinalIgnoreCase) && File.Exists(dst));
    File.WriteAllText(Path.Combine(InstDir, "tier.txt"), tier, new UTF8Encoding(false));
    try { string prevTier; if (tier == "high" && rec.TryGetValue("tier", out prevTier) && prevTier == "low") { File.WriteAllText(Path.Combine(InstDir, "tier_switched.txt"), "low>high", new UTF8Encoding(false)); Log("  Gemini → Gemma 버전으로 바꿈 (채널 번역 다시 켜기 표시)"); } } catch { }
    try { File.Copy(Application.ExecutablePath, Path.Combine(InstDir, "Uninstall.exe"), true); } catch (Exception ex) { Log("  삭제 프로그램 복사: " + ex.Message); }
    try { File.Copy(Application.ExecutablePath, Launcher, true); } catch (Exception ex) { Log("  실행기 복사: " + ex.Message); }
    try { if (File.Exists(Path.Combine(RecDir, "NangmanTranslator.ps1"))) { foreach (var f in Directory.GetFiles(RecDir)) if (!Path.GetFileName(f).Equals("installed.txt", StringComparison.OrdinalIgnoreCase)) File.Delete(f); foreach (var d in Directory.GetDirectories(RecDir)) Directory.Delete(d, true); Log("  예전 위치 정리"); } } catch (Exception ex) { Log("  예전 위치 정리: " + ex.Message); }
    var docs = Path.Combine(Data, "docs"); if (Directory.Exists(docs)) try { CopyDir(docs, Path.Combine(InstDir, "docs"), null); } catch { }

    Step("게임 애드온 넣는 중");
    var addon = Path.Combine(forever, @"Interface\AddOns\NangmanTranslator");
    WaitWowOff("와우가 켜져 있어서 애드온을 넣을 수 없어요.");
    try { if (Directory.Exists(addon)) Directory.Delete(addon, true); } catch { }
    CopyDir(Path.Combine(Data, @"addon\NangmanTranslator"), addon, null);
    BgSound(forever);

    Step("아이콘 만드는 중");
    var ico = Path.Combine(InstDir, "app.ico");
    bool useL = File.Exists(Launcher); string lT = useL ? Launcher : PsExe, lA = useL ? "/run" : PsArgs;
    bool deskOk = SafeShortcut(DesktopLnk, lT, lA, InstDir, ico, Product);
    bool menuOk = false;
    try { Directory.CreateDirectory(MenuDir); menuOk = SafeShortcut(Path.Combine(MenuDir, Product + ".lnk"), lT, lA, InstDir, ico, Product); } catch (Exception ex) { Log("  시작 메뉴 폴더: " + ex.Message); }
    try { SafeShortcut(Path.Combine(MenuDir, Product + " 삭제.lnk"), Path.Combine(InstDir, "Uninstall.exe"), "/uninstall", InstDir, ico, Product + " 완전 삭제"); } catch { }
    if (!deskOk) { var alt = Path.Combine(InstDir, Product + ".lnk"); SafeShortcut(alt, lT, lA, InstDir, ico, Product); lnkNote = "\n\n⚠ 바탕화면 아이콘을 만들지 못했어요(백신의 폴더 보호 기능 등). " + (menuOk ? "시작 메뉴에서 '" + Product + "'을 찾아 켜 주세요." : "아래 폴더의 '" + Product + "' 아이콘으로 켜 주세요:\n" + InstDir); }
    using (var k = Registry.CurrentUser.CreateSubKey(UninstKey)) {
      k.SetValue("DisplayName", Product); k.SetValue("DisplayVersion", Version); k.SetValue("Publisher", "낭만타우렌");
      k.SetValue("DisplayIcon", ico); k.SetValue("InstallLocation", InstDir);
      k.SetValue("UninstallString", "\"" + Path.Combine(InstDir, "Uninstall.exe") + "\" /uninstall");
      k.SetValue("NoModify", 1, RegistryValueKind.DWord); k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
    }
    rec["version"] = Version; rec["tier"] = tier; rec["dir"] = InstDir; rec["addon"] = addon; rec["model"] = tier == "low" ? "" : ModelName();
    rec["ollamaByUs"] = olByUs ? "1" : "0"; rec["installed"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
    WriteRec(rec);
    try { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true)) { var v = k == null ? null : k.GetValue(RunName) as string; if (v != null && (!v.Contains(InstDir) || (File.Exists(Launcher) && v.IndexOf("powershell", StringComparison.OrdinalIgnoreCase) >= 0))) { k.SetValue(RunName, File.Exists(Launcher) ? "\"" + Launcher + "\" /run" : "\"" + PsExe + "\" " + PsArgs); Log("  자동 실행 자리 고침"); } } } catch (Exception ex) { Log("  자동 실행 자리: " + ex.Message); }
    foreach (var ld in movedFrom) DelDir(ld, "예전 자리");

    string test = null, gpuNote = "";
    if (tier != "low") {
      Step("시험 번역 중");
      try {
        var body = "{\"model\":\"" + ModelName() + "\",\"stream\":false,\"format\":\"json\",\"think\":false,\"options\":{\"temperature\":0},\"messages\":[{\"role\":\"system\",\"content\":\"너는 와우 채팅 번역기다. 영어 채팅을 한국어 채팅 말투로 옮겨 JSON {\\\"ko\\\":\\\"번역\\\"} 으로만 답한다.\"},{\"role\":\"user\",\"content\":\"LF1M tank\"}]}";
        var res = Http("POST", "http://127.0.0.1:11434/api/chat", body, 180000);
        var ser = new System.Web.Script.Serialization.JavaScriptSerializer();
        var j = ser.DeserializeObject(res) as Dictionary<string, object>;
        var msg = j["message"] as Dictionary<string, object>; var content = Convert.ToString(msg["content"]);
        var inner = ser.DeserializeObject(content) as Dictionary<string, object>;
        test = inner != null && inner.ContainsKey("ko") ? Convert.ToString(inner["ko"]) : content;
        Log("  시험 번역: LF1M tank → " + test);
        try {
          var ps = ser.DeserializeObject(Http("GET", "http://127.0.0.1:11434/api/ps", null, 5000)) as Dictionary<string, object>;
          var ms = ps != null && ps.ContainsKey("models") ? ps["models"] as object[] : null;
          if (ms != null && ms.Length > 0) { var m0 = ms[0] as Dictionary<string, object>; long vr = m0 != null && m0.ContainsKey("size_vram") ? Convert.ToInt64(m0["size_vram"]) : -1; long sz = m0 != null && m0.ContainsKey("size") ? Convert.ToInt64(m0["size"]) : 0;
            Log(string.Format("  그래픽카드 사용: {0:0.0}GB / {1:0.0}GB", vr / 1073741824.0, sz / 1073741824.0));
            if (vr == 0) gpuNote = "\n\n⚠ 번역 엔진이 그래픽카드를 못 쓰고 CPU로 돌고 있어요. 번역이 많이 느리면 그래픽 드라이버를 최신으로 올리거나 외부 API 버전을 써 주세요."; }
        } catch (Exception ex2) { Log("  그래픽카드 사용 확인 실패: " + ex2.Message); }
        Http("POST", "http://127.0.0.1:11434/api/generate", "{\"model\":\"" + ModelName() + "\",\"keep_alive\":0}", 20000);
      } catch (Exception ex) { Log("  시험 번역 실패: " + ex.Message); }
    }

    Step("설치 완료");
    if (!SelfTest) try { var sp = new ProcessStartInfo(PsExe, PsArgs) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = InstDir }; sp.EnvironmentVariables["NT_LAUNCH"] = "1"; Process.Start(sp); } catch (Exception ex) { Log("  켜기: " + ex.Message); }
    Log("완료");
    Ui(() => { btnDel.Visible = true; installDone = true; btnMain.Text = "설치 완료 · 닫기"; });
    Say("✓ 설치 완료!" + (test != null ? "\n\n시험 번역: LF1M tank → " + test : "") + gpuNote + lnkNote + "\n\n번역기가 켜졌어요. 와우를 켜고 채팅창에 /reload 를 입력하세요." + (tier == "low" ? "\n처음 켜면 AI 키를 넣는 창이 떠요." : ""), MessageBoxIcon.Information);
  }

  public int RunSelfTest() {
    var res = new List<string>(); bool ok = true;
    Action<string, bool> chk = (name, pass) => { res.Add((pass ? "통과 " : "실패 ") + name); if (!pass) ok = false; };
    try {
      bool hadOl = FindOllama() != null;
      res.Add("번역 엔진(Ollama) 미리 설치됨: " + (hadOl ? "예" : "아니요"));
      var ld = LegacyDirs[0]; Directory.CreateDirectory(ld);
      File.WriteAllText(Path.Combine(ld, "NangmanTranslator.ps1"), "# old");
      File.WriteAllText(Path.Combine(ld, "settings.json"), "{\"selftest\":1}", new UTF8Encoding(false));
      if (!string.IsNullOrEmpty(SelfForever)) Directory.CreateDirectory(Path.Combine(SelfForever, @"Interface\AddOns"));
      DoInstall();
      chk("프로그램 설치 (" + InstDir + ")", File.Exists(Path.Combine(InstDir, "NangmanTranslator.ps1")) && new FileInfo(Path.Combine(InstDir, "NangmanTranslator.ps1")).Length > 1000);
      chk("사전(암호화본) 설치", File.Exists(Path.Combine(InstDir, "dict.dat")) && !File.Exists(Path.Combine(InstDir, "translate-config.json")));
      chk("예전 자리 설정 옮겨 옴", File.Exists(Path.Combine(InstDir, "settings.json")) && File.ReadAllText(Path.Combine(InstDir, "settings.json")).Contains("selftest"));
      chk("예전 자리 정리", !Directory.Exists(ld) || !File.Exists(Path.Combine(ld, "NangmanTranslator.ps1")));
      var rec = ReadRec(); string ad; chk("설치 기록", rec.TryGetValue("dir", out ad) && ad == InstDir);
      chk("게임 애드온 설치", rec.TryGetValue("addon", out ad) && File.Exists(Path.Combine(ad, "NangmanTranslator.toc")));
      using (var k = Registry.CurrentUser.OpenSubKey(UninstKey)) chk("앱 목록 등록", k != null && Convert.ToString(k.GetValue("InstallLocation")) == InstDir);
      chk("삭제 프로그램", File.Exists(Path.Combine(InstDir, "Uninstall.exe")));
      chk("바탕화면 바로가기", File.Exists(DesktopLnk));
      chk("시작 메뉴 바로가기", File.Exists(Path.Combine(MenuDir, Product + ".lnk")));
      chk("창 없이 켜는 실행기", File.Exists(Launcher));
      Func<string, bool> lnkL = f => { try { return Encoding.Unicode.GetString(File.ReadAllBytes(f)).IndexOf("NangmanTranslator.exe", StringComparison.OrdinalIgnoreCase) >= 0 || Encoding.Default.GetString(File.ReadAllBytes(f)).IndexOf("NangmanTranslator.exe", StringComparison.OrdinalIgnoreCase) >= 0; } catch { return false; } };
      chk("바로가기 = 실행기", lnkL(DesktopLnk) && lnkL(Path.Combine(MenuDir, Product + ".lnk")));
      try {
        var td = Path.Combine(Path.GetTempPath(), "nt_runtest_" + Guid.NewGuid().ToString("N").Substring(0, 8)); Directory.CreateDirectory(td);
        var mark = Path.Combine(td, "ran.txt");
        File.WriteAllText(Path.Combine(td, "NangmanTranslator.ps1"), "Set-Content -LiteralPath '" + mark.Replace("'", "''") + "' -Value ('NT=' + $env:NT_LAUNCH)\r\n", new UTF8Encoding(true));
        File.Copy(Launcher, Path.Combine(td, "NangmanTranslator.exe"), true);
        var rp = Process.Start(new ProcessStartInfo(Path.Combine(td, "NangmanTranslator.exe"), "/run") { UseShellExecute = false }); rp.WaitForExit(15000);
        for (int w = 0; w < 60 && !File.Exists(mark); w++) Thread.Sleep(500);
        string got = File.Exists(mark) ? File.ReadAllText(mark).Trim() : "(안 켜짐)";
        chk("실행기로 켜기 (/run → 번역기, 표시 " + got + ")", got == "NT=1");
        try { Directory.Delete(td, true); } catch { }
      } catch (Exception ex) { chk("실행기로 켜기: " + ex.Message, false); }
      using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")) { var rv = k == null ? null : k.GetValue(RunName) as string; chk("자동 실행 = 실행기 (켜져 있을 때만)", rv == null || rv.Contains("NangmanTranslator.exe")); }
      DoInstall();
      chk("다시 설치(덮어쓰기): 프로그램", File.Exists(Path.Combine(InstDir, "NangmanTranslator.ps1")) && new FileInfo(Path.Combine(InstDir, "NangmanTranslator.ps1")).Length > 1000);
      chk("다시 설치(덮어쓰기): 내 설정 그대로", File.Exists(Path.Combine(InstDir, "settings.json")) && File.ReadAllText(Path.Combine(InstDir, "settings.json")).Contains("selftest"));
      using (var k = Registry.CurrentUser.OpenSubKey(UninstKey)) chk("다시 설치(덮어쓰기): 앱 목록·바로가기", k != null && Convert.ToString(k.GetValue("InstallLocation")) == InstDir && File.Exists(DesktopLnk));
      string svDir = null; if (!string.IsNullOrEmpty(SelfForever)) { svDir = Path.Combine(SelfForever, @"WTF\Account\TEST\SavedVariables"); Directory.CreateDirectory(svDir); File.WriteAllText(Path.Combine(svDir, "NangmanTranslator.lua"), "x"); File.WriteAllText(Path.Combine(svDir, "OtherAddon.lua"), "x"); }
      var instLog = File.Exists(LogFile) ? File.ReadAllText(LogFile) : "";
      var un = Path.Combine(InstDir, "Uninstall.exe");
      using (var up = Process.Start(new ProcessStartInfo(un, "/selftest-uninst") { UseShellExecute = false, WorkingDirectory = Path.GetTempPath() })) { if (!up.WaitForExit(180000)) { try { up.Kill(); } catch { } } }
      res.Add("----- 설치 기록 (설치 단계) -----\n" + instLog);
      for (int w = 0; w < 30 && Directory.Exists(InstDir); w++) Thread.Sleep(1000);
      chk("완전 삭제: 프로그램 폴더 통째로 (삭제 프로그램 포함)", !Directory.Exists(InstDir));
      if (hadOl) {
        for (int w = 0; w < 30 && FindOllama() != null; w++) Thread.Sleep(1000);
        chk("완전 삭제: 번역 엔진(Ollama) 프로그램", FindOllama() == null);
        chk("완전 삭제: 번역 엔진 모델 폴더(.ollama)", !Directory.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".ollama")));
      }
      chk("완전 삭제: 프로그램 폴더", !File.Exists(Path.Combine(InstDir, "NangmanTranslator.ps1")));
      chk("완전 삭제: 게임 애드온", ad == null || !Directory.Exists(ad));
      using (var k = Registry.CurrentUser.OpenSubKey(UninstKey)) chk("완전 삭제: 앱 목록", k == null);
      chk("완전 삭제: 설치 기록", !File.Exists(RecFile));
      chk("완전 삭제: 바로가기", !File.Exists(DesktopLnk) && !Directory.Exists(MenuDir));
      if (svDir != null) { chk("완전 삭제: 우리 애드온 설정만 지움", !File.Exists(Path.Combine(svDir, "NangmanTranslator.lua")) && File.Exists(Path.Combine(svDir, "OtherAddon.lua"))); }
    } catch (Exception ex) { res.Add("실패 예외: " + ex); ok = false; }
    var outF = Path.Combine(Src, "selftest-result.txt");
    try { File.WriteAllLines(outF, res.ToArray(), new UTF8Encoding(false)); File.AppendAllText(outF, (ok ? "\n결과: 모두 통과\n" : "\n결과: 실패\n") , new UTF8Encoding(false)); } catch { }
    return ok ? 0 : 1;
  }

  public void SelfUninst() { DoUninstall(); Thread.Sleep(8000); }
  void DoUninstall() {
    if (uninstallMode && !Ask("번역기를 완전히 지울까요?\n프로그램·번역 모델·게임 애드온·설정·아이콘이 모두 지워져요.")) { Ui(Close); return; }
    Log("===== 완전 삭제 시작");
    var rec = ReadRec();
    Step("번역기 끄는 중"); KillTranslator(); Thread.Sleep(800);
    string addon0; bool hasAddon = rec.TryGetValue("addon", out addon0) && Directory.Exists(addon0);
    if (!hasAddon) { var f0 = FindForever(); hasAddon = f0 != null && Directory.Exists(Path.Combine(f0, @"Interface\AddOns\NangmanTranslator")); }
    if (hasAddon) WaitWowOff("와우가 켜져 있어서 애드온을 지울 수 없어요.");
    try { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true)) { if (k != null) k.DeleteValue(RunName, false); } } catch { }
    Step("게임 애드온 지우는 중");
    string addon; if (rec.TryGetValue("addon", out addon) && Directory.Exists(addon)) { try { Directory.Delete(addon, true); } catch (Exception ex) { Log("  애드온: " + ex.Message); } }
    else { var f = FindForever(); if (f != null) { var a = Path.Combine(f, @"Interface\AddOns\NangmanTranslator"); try { if (Directory.Exists(a)) Directory.Delete(a, true); } catch { } } }
    Step("번역 모델 지우는 중");
    var ol = FindOllama();
    if (ol != null) {
      try { EnsureOllamaRunning(ol); } catch { }
      var ms = new List<string> { "nangman-gemma", "sabi" };
      string rm; if (rec.TryGetValue("model", out rm) && !string.IsNullOrEmpty(rm) && !ms.Contains(rm)) ms.Add(rm);
      foreach (var m in ms) Run(ol, "rm " + m, null, 5);
      bool byUs = rec.ContainsKey("ollamaByUs") && rec["ollamaByUs"] == "1";
      bool others = false;
      try { var r = Http("GET", "http://127.0.0.1:11434/api/tags", null, 5000); others = r.Contains("\"name\""); } catch { }
      bool delEngine = !others || Ask("번역 엔진(Ollama)에 다른 프로그램의 모델이 남아 있어요.\n엔진을 지우면 그 모델들도 같이 지워져요.\n" + (byUs ? "엔진은 번역기를 설치할 때 같이 깔린 거예요. " : "") + "같이 지울까요?");
      if (delEngine) {
        Step("번역 엔진(Ollama) 지우는 중");
        KillOllama(); Thread.Sleep(800);
        var un = Path.Combine(Path.GetDirectoryName(ol), "unins000.exe");
        if (File.Exists(un)) Run(un, "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART", null, 20);
        KillOllama(); Thread.Sleep(1000);
        DelDir(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".ollama"), "엔진 모델 폴더");
        DelDir(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Ollama"), "엔진 기록 폴더");
        DelDir(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\Ollama"), "엔진 폴더");
        try { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true)) { if (k != null) k.DeleteValue("Ollama", false); } } catch { }
      } else Log("  다른 프로그램이 쓰는 모델이 있어 번역 엔진은 남김 (우리 모델만 지움)");
    }
    try {
      string fv = null; string ad0; if (rec.TryGetValue("addon", out ad0) && ad0.IndexOf(@"\Interface\AddOns\", StringComparison.OrdinalIgnoreCase) > 0) fv = ad0.Substring(0, ad0.IndexOf(@"\Interface\AddOns\", StringComparison.OrdinalIgnoreCase)); if (fv == null) fv = FindForever();
      var wtf = fv == null ? null : Path.Combine(fv, @"WTF\Account");
      if (wtf != null && Directory.Exists(wtf)) { int n = 0; foreach (var f in Directory.GetFiles(wtf, "NangmanTranslator.lua*", SearchOption.AllDirectories)) { if (!Path.GetDirectoryName(f).EndsWith("SavedVariables", StringComparison.OrdinalIgnoreCase)) continue; try { File.Delete(f); n++; } catch { } } Log("  애드온 설정 파일 지움: " + n + "개"); }
    } catch (Exception ex) { Log("  애드온 설정 파일: " + ex.Message); }
    foreach (var t in new[] { "NangmanTranslator_ollama_serve.log", "NangmanTranslator_OllamaSetup.exe" }) { try { var tp = Path.Combine(Path.GetTempPath(), t); if (File.Exists(tp)) File.Delete(tp); } catch { } }
    Step("아이콘·기록 지우는 중");
    try { if (File.Exists(DesktopLnk)) File.Delete(DesktopLnk); } catch { }
    try { if (Directory.Exists(MenuDir)) Directory.Delete(MenuDir, true); } catch { }
    try { Registry.CurrentUser.DeleteSubKeyTree(UninstKey, false); } catch { }
    try { if (Directory.Exists(RecDir)) Directory.Delete(RecDir, true); } catch (Exception ex) { Log("  기록: " + ex.Message); }
    var dirs = new List<string> { InstDir }; dirs.AddRange(LegacyDirs);
    string rd; if (rec.TryGetValue("dir", out rd) && !string.IsNullOrEmpty(rd) && File.Exists(Path.Combine(rd, "NangmanTranslator.ps1"))) dirs.Add(rd);
    foreach (var d in dirs.Distinct(StringComparer.OrdinalIgnoreCase)) {
      if (!Directory.Exists(d)) continue;
      if (Application.ExecutablePath.StartsWith(d.TrimEnd(new[] { '\\' }) + "\\", StringComparison.OrdinalIgnoreCase)) { try { Process.Start(new ProcessStartInfo("cmd.exe", "/c for /l %i in (1,1,90) do @(timeout /t 2 /nobreak >nul & rmdir /s /q \"" + d + "\" 2>nul & if not exist \"" + d + "\" exit)") { CreateNoWindow = true, UseShellExecute = false, WorkingDirectory = Path.GetTempPath() }); } catch { } }
      else DelDir(d, "프로그램 폴더");
    }
    try { Process.Start(new ProcessStartInfo("cmd.exe", "/c timeout /t 5 /nobreak >nul & del /f /q \"" + LogFile + "\"") { CreateNoWindow = true, UseShellExecute = false, WorkingDirectory = Path.GetTempPath() }); } catch { }
    Step("완전 삭제 완료");
    Log("완료");
    Say("완전 삭제가 끝났어요. 와우와 다른 애드온은 그대로예요.", MessageBoxIcon.Information);
    Ui(() => { btnDel.Visible = false; btnMain.Text = "설치"; if (uninstallMode) Close(); });
  }
}
