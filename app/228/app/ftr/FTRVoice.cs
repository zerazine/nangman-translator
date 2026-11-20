using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class FVDevEnum { }
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVIDevEnum {
  [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out FVIDevCol devices);
}
[ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVIDevCol {
  [PreserveSig] int GetCount(out int n);
  [PreserveSig] int Item(int i, out FVIDev dev);
}
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVIDev {
  [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr prm, [MarshalAs(UnmanagedType.IUnknown)] out object o);
}
[ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVISessMgr2 {
  [PreserveSig] int GetAudioSessionControl(IntPtr g, int f, out IntPtr c);
  [PreserveSig] int GetSimpleAudioVolume(IntPtr g, int f, out IntPtr v);
  [PreserveSig] int GetSessionEnumerator(out FVISessEnum e);
}
[ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVISessEnum {
  [PreserveSig] int GetCount(out int n);
  [PreserveSig] int GetSession(int i, out FVISessCtl2 s);
}
[ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVISessCtl2 {
  [PreserveSig] int S0(); [PreserveSig] int S1(); [PreserveSig] int S2(); [PreserveSig] int S3(); [PreserveSig] int S4();
  [PreserveSig] int S5(); [PreserveSig] int S6(); [PreserveSig] int S7(); [PreserveSig] int S8();
  [PreserveSig] int S9(); [PreserveSig] int S10();
  [PreserveSig] int GetProcessId(out uint pid);
}
[ComImport, Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface FVIMeter {
  [PreserveSig] int GetPeakValue(out float peak);
}

public static class FTRVoice {
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);
  [DllImport("user32.dll")] static extern bool GetLayeredWindowAttributes(IntPtr h, out uint key, out byte alpha, out uint flags);
  [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr h, IntPtr rgn, bool redraw);
  [DllImport("user32.dll")] static extern int GetWindowRgnBox(IntPtr h, out FVRect r);
  [DllImport("gdi32.dll")] static extern IntPtr CreateRectRgn(int l, int t, int r, int b);
  [StructLayout(LayoutKind.Sequential)] struct FVRect { public int L, T, R, B; }
  delegate bool FVEnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(FVEnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out FVRect r);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  public static volatile string WinInfo = "";
  static Dictionary<uint, bool> lcIds = new Dictionary<uint, bool>();
  static int idsAt = -100000;
  static int infoAt = -100000;
  static int findFail = 0;
  static List<IntPtr> LcWindows() {
    List<IntPtr> list = new List<IntPtr>();
    if (unchecked(Environment.TickCount - idsAt) > 2000) {
      idsAt = Environment.TickCount; lcIds.Clear();
      try { foreach (Process p in Process.GetProcessesByName("LiveCaptions")) { lcIds[(uint)p.Id] = true; p.Dispose(); } } catch { }
    }
    Dictionary<uint, bool> ids = lcIds;
    if (ids.Count == 0) return list;
    bool wantInfo = unchecked(Environment.TickCount - infoAt) > 5000;
    if (wantInfo) infoAt = Environment.TickCount;
    StringBuilder info = wantInfo ? new StringBuilder() : null;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (ids.ContainsKey(pid)) {
        list.Add(h);
        if (info == null) return true;
        StringBuilder cn = new StringBuilder(128); GetClassName(h, cn, 128);
        FVRect r; GetWindowRect(h, out r);
        info.Append(cn.ToString()).Append(IsWindowVisible(h) ? "(보임)" : "(숨음)").Append(" ").Append(r.L).Append(",").Append(r.T).Append(" ").Append(r.R - r.L).Append("x").Append(r.B - r.T).Append(" | ");
      }
      return true;
    }, IntPtr.Zero);
    if (info != null) WinInfo = info.ToString();
    return list;
  }
  static void HideAll() { foreach (IntPtr h in LcWindows()) if (!HiddenOne(h)) HideOne(h); }
  static bool AllHidden() { foreach (IntPtr h in LcWindows()) if (IsWindowVisible(h) && !HiddenOne(h)) return false; return true; }
  static bool StillHidden() { return AllHidden(); }
  static bool HiddenOne(IntPtr lcHwnd) {
    if (!IsWindowVisible(lcHwnd)) return true;
    FVRect wr; return GetWindowRect(lcHwnd, out wr) && wr.L <= -10000;
  }

  public static volatile bool Enabled = true;
  public static volatile bool AnyAudio = false;
  public static string[] Apps = new string[] { "Discord" };
  public static volatile string Status = "꺼짐";
  public static volatile bool ShowLC = false;
  public static volatile bool KeepLC = false;
  public static void ShowNow() { try { Unhide(); } catch { } }
  public static void HideNow() { try { HideAll(); } catch { } }
  public static volatile string Caption = "";
  public static float Peak = 0f;
  public static int LastVoiceTick = 0;
  public static bool EverVoice = false;
  public static ConcurrentQueue<string> Sentences = new ConcurrentQueue<string>();
  public static volatile string LastError = "";

  static Thread th;
  static bool startedLC = false;
  static int appGoneTick = 0;

  public static void Start() {
    if (th != null) return;
    beat = Environment.TickCount;
    th = new Thread(Loop);
    th.IsBackground = true;
    th.SetApartmentState(ApartmentState.MTA);
    th.Start();
    Thread wd = new Thread(Watch); wd.IsBackground = true; wd.Start();
  }
  static volatile int beat = 0;
  static void Watch() {
    while (true) {
      try {
        int now = Environment.TickCount;
        if (Enabled && unchecked(now - beat) > 6000 && unchecked(now - restartAt) > 30000) {
          restartAt = now; LastError = "자막 응답 없음 → 다시 켬";
          foreach (Process p in Process.GetProcessesByName("LiveCaptions")) { try { p.Kill(); } catch { } p.Dispose(); }
          startedLC = true;
        }
      } catch { }
      Thread.Sleep(1000);
    }
  }

  static List<FVIMeter> meters = new List<FVIMeter>();
  static int meterAt = -100000;
  static bool AppRunning() {
    foreach (string a in Apps) { try { if (Process.GetProcessesByName(a).Length > 0) return true; } catch { } }
    return false;
  }
  static void RefreshMeters() {
    foreach (FVIMeter m in meters) { try { Marshal.ReleaseComObject(m); } catch { } }
    meters.Clear();
    HashPids();
    if (pids.Count == 0 && !AnyAudio) return;
    List<object> junk = new List<object>();
    try {
      FVIDevEnum en = (FVIDevEnum)(new FVDevEnum()); junk.Add(en);
      FVIDevCol col;
      if (en.EnumAudioEndpoints(0, 1, out col) != 0 || col == null) return;
      junk.Add(col);
      int n; col.GetCount(out n);
      Guid iid = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
      for (int i = 0; i < n; i++) {
        FVIDev dev; if (col.Item(i, out dev) != 0 || dev == null) continue;
        junk.Add(dev);
        object o; if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0 || o == null) continue;
        junk.Add(o);
        FVISessMgr2 mgr = (FVISessMgr2)o;
        FVISessEnum se; if (mgr.GetSessionEnumerator(out se) != 0 || se == null) continue;
        junk.Add(se);
        int sc; se.GetCount(out sc);
        for (int k = 0; k < sc; k++) {
          FVISessCtl2 s; if (se.GetSession(k, out s) != 0 || s == null) continue;
          uint pid; s.GetProcessId(out pid);
          FVIMeter m = (AnyAudio || pids.ContainsKey((int)pid)) ? (s as FVIMeter) : null;
          if (m != null) meters.Add(m); else junk.Add(s);
        }
      }
    } catch (Exception e) { LastError = "소리: " + e.Message; }
    finally { foreach (object j in junk) { try { Marshal.ReleaseComObject(j); } catch { } } }
  }
  static Dictionary<int, bool> pids = new Dictionary<int, bool>();
  static void HashPids() {
    pids.Clear();
    foreach (string a in Apps) {
      try { foreach (Process p in Process.GetProcessesByName(a)) { pids[p.Id] = true; p.Dispose(); } } catch { }
    }
  }
  static void PollMeters() {
    float mx = 0f;
    for (int i = meters.Count - 1; i >= 0; i--) {
      try { float v; if (meters[i].GetPeakValue(out v) == 0 && v > mx) mx = v; } catch { meters.RemoveAt(i); }
    }
    Peak = mx;
    if (mx > 0.015f) { LastVoiceTick = Environment.TickCount; EverVoice = true; }
    if (mx > 0.03f) voiceSince += 100;
  }

  static AutomationElement lcWin = null, lcText = null;
  static IntPtr lcHwnd = IntPtr.Zero;
  static int findAt = -100000;
  static bool FindLC() {
    if (lcText != null) return true;
    foreach (IntPtr hw0 in LcWindows()) {
      StringBuilder c0 = new StringBuilder(64); GetClassName(hw0, c0, 64);
      if (!ShowLC && c0.ToString() == "LiveCaptionsDesktopWindow" && IsWindowVisible(hw0) && !HiddenOne(hw0)) HideOne(hw0);
      else if (ShowLC && c0.ToString() == "LiveCaptionsDesktopWindow" && (!IsWindowVisible(hw0) || HiddenOne(hw0))) UnhideOne(hw0);
    }
    if (unchecked(Environment.TickCount - findAt) < 1000) return false;
    findAt = Environment.TickCount;
    try {
      Process[] ps = Process.GetProcessesByName("LiveCaptions");
      if (ps.Length == 0) {
        Process.Start("LiveCaptions.exe"); startedLC = true; Status = "라이브 캡션 켜는 중";
        return false;
      }
      foreach (Process p in ps) p.Dispose();
      idsAt = -100000;
      bool sawWin = false;
      foreach (IntPtr hw in LcWindows()) {
        StringBuilder cn = new StringBuilder(64); GetClassName(hw, cn, 64);
        if (cn.ToString() != "LiveCaptionsDesktopWindow") continue;
        sawWin = true;
        if (!IsWindowVisible(hw) && ShowLC) { UnhideOne(hw); Thread.Sleep(400); }
        else if (!IsWindowVisible(hw)) {
          SetWindowPos(hw, new IntPtr(1), -20000, -20000, 0, 0, 0x0001 | 0x0010);
          ShowWindow(hw, 4);
          Thread.Sleep(400);
        }
        AutomationElement w = AutomationElement.FromHandle(hw);
        if (w == null) continue;
        AutomationElement t = w.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.AutomationIdProperty, "CaptionsTextBlock"));
        if (t == null) continue;
        lcWin = w; lcText = t; lcHwnd = new IntPtr(w.Current.NativeWindowHandle);
        if (!ShowLC) Hide();
        Seed();
        Status = "켜짐"; findFail = 0;
        return true;
      }
      Status = sawWin ? "자막 기다리는 중" : "라이브 캡션 창 찾는 중";
      if (sawWin && (voiceSince <= 8000 || unchecked(Environment.TickCount - restartAt) <= 60000)) { findFail = 0; return false; }
      if (sawWin) { restartAt = Environment.TickCount; voiceSince = 0; findFail = Environment.TickCount - 9000; }
      if (findFail == 0) findFail = Environment.TickCount;
      else if (unchecked(Environment.TickCount - findFail) > 8000) {
        findFail = 0; LastError = "자막 창을 못 찾아 다시 켬";
        foreach (Process p in Process.GetProcessesByName("LiveCaptions")) { try { p.Kill(); } catch { } p.Dispose(); }
        startedLC = true; idsAt = -100000; findAt = Environment.TickCount - 1000;
      }
    } catch (Exception e) { LastError = "캡션 찾기: " + e.Message; lcWin = null; lcText = null; }
    return false;
  }
  static void Hide() { HideAll(); }
  static void HideOne(IntPtr lcHwnd) {
    try {
      SetWindowPos(lcHwnd, new IntPtr(-2), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010);
      SetWindowPos(lcHwnd, new IntPtr(1), -20000, -20000, 0, 0, 0x0001 | 0x0010);
    } catch { }
  }
  delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time);
  [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint evMin, uint evMax, IntPtr hmod, WinEventProc cb, uint pid, uint tid, uint flags);
  [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr h);
  static WinEventProc hookCb;
  static IntPtr hookH = IntPtr.Zero;
  static uint hookPid = 0;
  static IntPtr showH = IntPtr.Zero;
  public static void HookTick() {
    try { if (showH == IntPtr.Zero) { if (hookCb == null) hookCb = OnWinEvent; showH = SetWinEventHook(0x8002, 0x8002, IntPtr.Zero, hookCb, 0, 0, 0); } } catch { }
    try {
      uint pid = 0;
      Process[] ps = Process.GetProcessesByName("LiveCaptions");
      if (ps.Length > 0) pid = (uint)ps[0].Id;
      foreach (Process p in ps) p.Dispose();
      if (!Enabled) pid = 0;
      if (pid == hookPid) return;
      if (hookH != IntPtr.Zero) { UnhookWinEvent(hookH); hookH = IntPtr.Zero; }
      hookPid = pid;
      if (pid == 0) return;
      if (hookCb == null) hookCb = OnWinEvent;
      hookH = SetWinEventHook(0x8002, 0x800B, IntPtr.Zero, hookCb, pid, 0, 0);
    } catch { }
  }
  static void OnWinEvent(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time) {
    try {
      if (idObj != 0 || hwnd == IntPtr.Zero || !Enabled || ShowLC) return;
      StringBuilder cn = new StringBuilder(64); GetClassName(hwnd, cn, 64);
      if (cn.ToString() != "LiveCaptionsDesktopWindow") return;
      if (IsWindowVisible(hwnd) && !HiddenOne(hwnd)) HideOne(hwnd);
    } catch { }
  }
  static void Unhide() { foreach (IntPtr h in LcWindows()) UnhideOne(h); }
  static void UnhideOne(IntPtr lcHwnd) {
    try {
      SetWindowRgn(lcHwnd, IntPtr.Zero, true);
      SetLayeredWindowAttributes(lcHwnd, 0, 255, 2);
      FVRect wr; if (GetWindowRect(lcHwnd, out wr) && wr.L < -10000) SetWindowPos(lcHwnd, new IntPtr(-1), 100, 20, 0, 0, 0x0001 | 0x0010);
      else SetWindowPos(lcHwnd, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010);
      StringBuilder cn = new StringBuilder(64); GetClassName(lcHwnd, cn, 64);
      if (cn.ToString() == "LiveCaptionsDesktopWindow") ShowWindow(lcHwnd, 4);
      int ex = GetWindowLong(lcHwnd, -20);
      SetWindowLong(lcHwnd, -20, ex & ~(0x80 | 0x80000 | 0x20));
    } catch { }
  }
  static int hideAt = 0;
  static volatile int restartAt = -100000;
  static int voiceSince = 0;
  static void StopLC() {
    lcWin = null; lcText = null; lcHwnd = IntPtr.Zero;
    startedLC = false;
    try { foreach (Process p in Process.GetProcessesByName("LiveCaptions")) { try { p.Kill(); } catch { } p.Dispose(); } } catch { }
  }

  static string prevText = "";
  static int changeTick = 0;
  static Dictionary<string, int> done = new Dictionary<string, int>();
  static Queue<string> doneOrder = new Queue<string>();
  static Regex sentRx = new Regex(@"[^.?!]+[.?!]+", RegexOptions.Compiled);
  static string Key(string s) {
    StringBuilder b = new StringBuilder();
    foreach (char c in s.ToLowerInvariant()) if (char.IsLetterOrDigit(c)) b.Append(c);
    return b.ToString();
  }
  static void Mark(string k) {
    if (k.Length == 0 || done.ContainsKey(k)) return;
    done[k] = 1; doneOrder.Enqueue(k);
    while (doneOrder.Count > 300) done.Remove(doneOrder.Dequeue());
  }
  static List<string> Split(string text, out string rest) {
    List<string> list = new List<string>();
    int end = 0;
    foreach (Match m in sentRx.Matches(text)) { list.Add(m.Value.Trim()); end = m.Index + m.Length; }
    rest = text.Substring(end).Trim();
    return list;
  }
  static void Seed() {
    string t = Read(); string rest;
    foreach (string s in Split(t, out rest)) Mark(Key(s));
    if (rest.Length > 0) Mark(Key(rest));
    prevText = t; changeTick = Environment.TickCount;
  }
  public static string TestText = null;
  public static void TestScan() { Scan(); }
  static string Read() {
    if (TestText != null) return TestText;
    if (lcText == null) return "";
    try { string s = lcText.Current.Name; return s == null ? "" : s.Replace("\r", " ").Replace("\n", " "); }
    catch (Exception) { lcText = null; lcWin = null; return ""; }
  }
  static void Emit(string s) {
    string k = Key(s);
    if (k.Length < 2 || done.ContainsKey(k)) return;
    Mark(k);
    bool voice = AnyAudio || unchecked(Environment.TickCount - LastVoiceTick) < 4000;
    if (!voice) return;
    buf = buf.Length == 0 ? s : buf + " " + s;
    bufAt = Environment.TickCount;
    if (Words(buf).Length >= 5) Flush();
  }
  static string buf = "";
  static int bufAt = 0;
  static List<KeyValuePair<int, string[]>> recent = new List<KeyValuePair<int, string[]>>();
  static string Dedup(string text) {
    int now = Environment.TickCount;
    recent.RemoveAll(delegate (KeyValuePair<int, string[]> r) { return unchecked(now - r.Key) > 12000; });
    string[] raw = Words(text);
    List<string> w = new List<string>(); foreach (string x in raw) w.Add(Key(x));
    List<string> past = new List<string>(); foreach (KeyValuePair<int, string[]> r in recent) past.AddRange(r.Value);
    if (past.Count > 0 && w.Count > 0) {
      Dictionary<string, int> bag = new Dictionary<string, int>();
      foreach (string x in past) { int c; bag.TryGetValue(x, out c); bag[x] = c + 1; }
      int hit = 0; foreach (string x in w) { int c; if (bag.TryGetValue(x, out c) && c > 0) { hit++; bag[x] = c - 1; } }
      if (hit * 4 >= w.Count * 3) return "";
      for (int guard = 0; guard < 3; guard++) {
        int bi = -1, bl = 0;
        for (int i = 0; i < w.Count; i++)
          for (int j = 0; j < past.Count; j++) {
            int l = 0; while (i + l < w.Count && j + l < past.Count && w[i + l] == past[j + l]) l++;
            if (l > bl) { bl = l; bi = i; }
          }
        if (bl < 4) break;
        List<string> nr = new List<string>(), nw = new List<string>();
        for (int i = 0; i < w.Count; i++) if (i < bi || i >= bi + bl) { nr.Add(raw[i]); nw.Add(w[i]); }
        raw = nr.ToArray(); w = nw;
      }
      if (w.Count < 2) return "";
    }
    recent.Add(new KeyValuePair<int, string[]>(now, w.ToArray()));
    return string.Join(" ", raw);
  }
  static string[] SubArr(string[] a, int from) { string[] r = new string[a.Length - from]; Array.Copy(a, from, r, 0, r.Length); return r; }
  static void Flush() { if (buf.Length > 0) { string t = Dedup(buf); buf = ""; if (t.Length > 0) Sentences.Enqueue(t); } }
  static void FlushIfOld() { if (buf.Length > 0 && unchecked(Environment.TickCount - bufAt) > 1200) Flush(); }
  static List<string> partial = new List<string>();
  static string[] Words(string s) { return s.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries); }
  static int Matched(string[] w) {
    if (partial.Count == 0 || w.Length < partial.Count) return 0;
    int same = 0;
    for (int i = 0; i < partial.Count; i++) if (Key(w[i]) == partial[i]) same++;
    return (same * 10 >= partial.Count * 8) ? partial.Count : 0;
  }
  static void SetPartial(string[] w, int n) { partial.Clear(); for (int i = 0; i < n; i++) partial.Add(Key(w[i])); }
  static void EmitSentence(string sent) {
    string k = Key(sent);
    if (k.Length < 2 || done.ContainsKey(k)) return;
    string[] w = Words(sent);
    int m = Matched(w);
    if (m > 0) {
      Mark(k); partial.Clear();
      if (w.Length > m) Emit(string.Join(" ", w, m, w.Length - m));
      return;
    }
    Emit(sent);
  }
  static void Scan() {
    string t = Read();
    Caption = t;
    int now = Environment.TickCount;
    if (t != prevText) { prevText = t; changeTick = now; voiceSince = 0; }
    int still = unchecked(now - changeTick);
    string rest;
    List<string> ss = Split(t, out rest);
    for (int i = 0; i < ss.Count; i++) {
      bool last = (i == ss.Count - 1) && rest.Length == 0;
      if (last && still < 400) continue;
      EmitSentence(ss[i]);
    }
    if (rest.Length == 0) return;
    string[] w = Words(rest);
    int m = Matched(w);
    if (m == 0 && partial.Count > 0 && w.Length >= partial.Count) partial.Clear();
    int left = w.Length - m;
    if (still >= 600 && left >= 2) {
      Emit(string.Join(" ", w, m, left)); SetPartial(w, w.Length);
    } else if (left >= 12) {
      int n = w.Length - 3;
      Emit(string.Join(" ", w, m, n - m)); SetPartial(w, n);
    }
  }

  static void Loop() {
    int lastScan = 0;
    while (true) {
      try {
        bool on = Enabled && (AnyAudio || AppRunning0());
        if (!on) {
          if (lcText != null || startedLC) { if (appGoneTick == 0) appGoneTick = Environment.TickCount; if ((!Enabled && !KeepLC) || unchecked(Environment.TickCount - appGoneTick) > 30000) { StopLC(); } }
          Status = Enabled ? "디스코드 꺼짐" : "꺼짐";
          beat = Environment.TickCount;
          Thread.Sleep(1000); continue;
        }
        appGoneTick = 0;
        if (unchecked(Environment.TickCount - meterAt) > 5000) { meterAt = Environment.TickCount; RefreshMeters(); }
        PollMeters();
        if (unchecked(Environment.TickCount - lastScan) >= 250) {
          lastScan = Environment.TickCount;
          if (FindLC()) {
            if (lcHwnd != IntPtr.Zero && unchecked(Environment.TickCount - hideAt) >= 500) { hideAt = Environment.TickCount; if (!ShowLC && !StillHidden()) Hide(); else if (ShowLC) Unhide(); }
            Scan();
            FlushIfOld();
            int nowT = Environment.TickCount;
            if (!AnyAudio && voiceSince > 8000 && unchecked(nowT - restartAt) > 60000) {
              restartAt = nowT; LastError = "자막이 멈춰서 다시 켬";
              try { foreach (Process p in Process.GetProcessesByName("LiveCaptions")) { p.Kill(); p.Dispose(); } } catch { }
              lcWin = null; lcText = null; lcHwnd = IntPtr.Zero; startedLC = true; findAt = nowT - 1500; changeTick = nowT; voiceSince = 0;
            }
          }
        }
      } catch (Exception e) { LastError = e.Message; }
      beat = Environment.TickCount;
      Thread.Sleep(100);
    }
  }
  public static void Shutdown() { Enabled = false; try { StopLC(); } catch { } }
  static int appAt = -100000; static bool appCache = false;
  static bool AppRunning0() {
    if (unchecked(Environment.TickCount - appAt) > 3000) { appAt = Environment.TickCount; appCache = AppRunning(); }
    return appCache;
  }
}
