using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Interop;

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("a5cd92ff-29be-454c-8d04-d82879fb3f1b")]
public interface IFTRVDM {
  [PreserveSig] int IsWindowOnCurrentVirtualDesktop(IntPtr h, out bool on);
  [PreserveSig] int GetWindowDesktopId(IntPtr h, out Guid id);
  [PreserveSig] int MoveWindowToDesktop(IntPtr h, [MarshalAs(UnmanagedType.LPStruct)] Guid id);
}
[ComImport, Guid("aa509086-5ca9-4c25-8f95-589d3c07b48a")] public class FTRCVDM { }

public static class FTR {
  // ---------- 창 ----------
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
  [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
  [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint type);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);

  static IFTRVDM vdm;
  public static bool FollowDesktop(IntPtr mine, IntPtr wow) {
    try {
      if (vdm == null) vdm = (IFTRVDM)new FTRCVDM();
      Guid a, b;
      if (vdm.GetWindowDesktopId(wow, out a) != 0 || a == Guid.Empty) return false;
      if (vdm.GetWindowDesktopId(mine, out b) == 0 && a == b) return true;
      return vdm.MoveWindowToDesktop(mine, a) == 0;
    } catch { return false; }
  }

  // 와우 창 찾기 (클래식·포에버·베타 모두 'waApplication Window' 창)
  static IntPtr wowCache = IntPtr.Zero;
  public static IntPtr FindWow() {
    if (wowCache != IntPtr.Zero && IsWindow(wowCache)) return wowCache;
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      StringBuilder c = new StringBuilder(64); GetClassName(h, c, 64);
      if (c.ToString() == "waApplication Window") { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    wowCache = found;
    return found;
  }
  // 와우 그림 영역(제목줄 뺀 안쪽)의 화면 위치·크기
  public static int[] ClientRect(IntPtr h) {
    RECT r; if (!GetClientRect(h, out r)) return null;
    POINT p = new POINT(); p.X = 0; p.Y = 0; ClientToScreen(h, ref p);
    return new int[] { p.X, p.Y, r.R - r.L, r.B - r.T };
  }
  public static int[] Cursor() { POINT p; GetCursorPos(out p); return new int[] { p.X, p.Y }; }
  public static IntPtr Foreground() { return GetForegroundWindow(); }
  public static void ClickThrough(IntPtr h, bool on) {
    int ex = GetWindowLong(h, -20);
    ex |= 0x80000 | 0x80;   // 레이어드 · Alt+Tab 숨김
    if (on) ex |= 0x20; else ex &= ~0x20;
    SetWindowLong(h, -20, ex);
  }
  public static void NoActivate(IntPtr h, bool on) {
    int ex = GetWindowLong(h, -20);
    if (on) ex |= 0x08000000; else ex &= ~0x08000000;
    SetWindowLong(h, -20, ex);
  }
  public static void Place(IntPtr h, int x, int y, int w, int hh) { SetWindowPos(h, new IntPtr(-1), x, y, w, hh, 0x0010); }
  public static void Focus(IntPtr h) {
    if (h == IntPtr.Zero || !IsWindow(h)) return;
    if (IsIconic(h)) ShowWindow(h, 9);
    IntPtr fg = GetForegroundWindow();
    uint pid;
    uint a = GetCurrentThreadId(), b = GetWindowThreadProcessId(fg, out pid);
    bool att = (b != 0 && a != b) && AttachThreadInput(a, b, true);
    BringWindowToTop(h); SetForegroundWindow(h);
    if (att) AttachThreadInput(a, b, false);
  }
  // ---------- 키 ----------
  static void Key(byte vk, bool up) { keybd_event(vk, (byte)MapVirtualKey(vk, 0), up ? 2u : 0u, UIntPtr.Zero); }
  public static void Tap(byte vk) { Key(vk, false); Thread.Sleep(15); Key(vk, true); }
  public static void CtrlV() { Key(0x11, false); Thread.Sleep(10); Key(0x56, false); Thread.Sleep(15); Key(0x56, true); Thread.Sleep(10); Key(0x11, true); }
  // ---------- 단축키 (와우가 앞에 있을 때만 잡음) ----------
  public static Action<int> OnHotKey;
  static bool hooked = false;
  public static bool Hotkey(IntPtr h, bool on) {
    if (!hooked) { HwndSource s = HwndSource.FromHwnd(h); if (s != null) { s.AddHook(Hook); hooked = true; } }
    if (on) return RegisterHotKey(h, 7, 0x4 | 0x4000, 0x0D);   // Shift+Enter
    UnregisterHotKey(h, 7); return true;
  }
  // (2026-10-25) 번역이 켜져 있으면 그냥 Enter도 번역 입력칸으로 (게임에서 다른 입력칸에 글을 쓰는 중엔 안 잡음)
  public static bool HotkeyEnter(IntPtr h, bool on) {
    if (!hooked) { HwndSource s = HwndSource.FromHwnd(h); if (s != null) { s.AddHook(Hook); hooked = true; } }
    if (on) return RegisterHotKey(h, 8, 0x4000, 0x0D);   // Enter
    UnregisterHotKey(h, 8); return true;
  }
  static IntPtr Hook(IntPtr hwnd, int msg, IntPtr w, IntPtr l, ref bool handled) {
    if (msg == 0x0312 && OnHotKey != null) { OnHotKey(w.ToInt32()); handled = true; }
    return IntPtr.Zero;
  }

  // ---------- 색 점 줄 읽기 (따로 도는 일꾼) ----------
  public const int CELL = 3, HEAD = 10, PAYLOAD = 130;   // (2026-10-25) 200 → 130칸: 줄 길이 420픽셀 (방송 화면 왼쪽 자르는 440픽셀 안쪽)
  public static ConcurrentQueue<string> Records = new ConcurrentQueue<string>();
  public static volatile string Status = "시작 전";
  public static volatile int Packets = 0, Drops = 0;
  public static long LastPacketTick = 0;
  // (2026-10-25) 컴퓨터를 25일 넘게 안 끄면 시계 숫자가 한 바퀴 돌아도 맞게
  public static int SincePacket() { return LastPacketTick == 0 ? int.MaxValue : unchecked(Environment.TickCount - (int)LastPacketTick); }
  static Thread worker;
  static int lastSeq = -1;
  static List<byte> buf = new List<byte>();
  static bool skipToNl = false;
  public static volatile int Mode = 0;   // (2026-11-14) 색 읽기 방식 (0 = 원래대로 · 1~4 = 색각 보정 필터 25~100%)
  static int FailStreak = 0;
  public static void Start() {
    if (worker != null) return;
    worker = new Thread(Loop); worker.IsBackground = true; worker.Priority = ThreadPriority.AboveNormal; worker.Start();
  }
  static void Loop() {
    int w = (HEAD + PAYLOAD) * CELL;
    Bitmap bmp = new Bitmap(w, CELL, PixelFormat.Format32bppArgb);
    Graphics g = Graphics.FromImage(bmp);
    while (true) {
      try {
        IntPtr wow = FindWow();
        if (wow == IntPtr.Zero) { Status = "와우 없음"; Thread.Sleep(1000); continue; }
        int[] cr = ClientRect(wow);
        if (cr == null || cr[2] < w) { Thread.Sleep(500); continue; }
        g.CopyFromScreen(cr[0], cr[1] + cr[3] - CELL, 0, 0, new Size(w, CELL), CopyPixelOperation.SourceCopy);   // (2026-10-25) 왼쪽 위 → 왼쪽 맨 아래
        Read(bmp);
      } catch (Exception e) { Status = "읽기 오류: " + e.Message; Thread.Sleep(300); }
      // (2026-10-25) 대화가 3초 넘게 없으면 0.06초 간격으로 쉬엄쉬엄 (애드온은 한 조각을 0.1초 보여 주므로 놓치지 않음)
      Thread.Sleep(SincePacket() < 3000 ? 25 : 60);
    }
  }
  static int[] Px(BitmapData d, int x) {
    int o = d.Stride * (CELL / 2) + x * 4;
    return new int[] { Marshal.ReadByte(d.Scan0, o + 2), Marshal.ReadByte(d.Scan0, o + 1), Marshal.ReadByte(d.Scan0, o) };
  }
  // (2026-11-14) 한 가지 방식으로 머리(번호·길이·검산값)와 내용을 읽고 검산까지 맞으면 true
  //   필터 공식은 실제 사용자 화면(신호캡처.png)에서 구함: 빨강 그대로 · 초록 += 0.25×(빨강−초록) · 파랑 += 0.3125×(빨강−초록) (필터 강도 50%) → 강도에 비례
  static bool Try(BitmapData d, int[][] cal, int m, out int[] vals, out int seq, out int n, out int sum, ref bool lenBad, ref bool dup) {
    vals = null; seq = -1; n = 0; sum = 0;
    int[][] pal = null;
    if (m > 0) {
      double s = m * 0.25, fg = 0.5 * s, fb = 0.625 * s;
      pal = new int[64][];
      for (int v = 0; v < 64; v++) {
        double r = cal[v >> 4][0], g = cal[(v >> 2) & 3][1], b = cal[v & 3][2];
        double g2 = g + fg * (r - g), b2 = b + fb * (r - g);
        pal[v] = new int[] { (int)r, (int)Math.Max(0, Math.Min(255, g2)), (int)Math.Max(0, Math.Min(255, b2)) };
      }
    }
    Func<int, int> V = delegate(int i) {
      int[] p = Px(d, i * CELL + CELL / 2);
      if (pal == null) {
        int v = 0;
        for (int c = 0; c < 3; c++) {
          int lv = 0, best = 9999;
          for (int k = 0; k < 4; k++) { int dd = Math.Abs(p[c] - cal[k][c]); if (dd < best) { best = dd; lv = k; } }
          v = v * 4 + lv;
        }
        return v;
      }
      int bv = 0, bd = int.MaxValue;
      for (int v = 0; v < 64; v++) { int dr = p[0] - pal[v][0], dg = p[1] - pal[v][1], db = p[2] - pal[v][2]; int dd = dr * dr + dg * dg + db * db; if (dd < bd) { bd = dd; bv = v; } }
      return bv;
    };
    seq = V(4) * 64 + V(5);
    n = V(6) * 64 + V(7);
    sum = V(8) * 64 + V(9);
    if (n <= 0 || n > PAYLOAD) { lenBad = true; return false; }   // (2026-10-27) 빈 신호(0칸)는 애드온이 안 보냄 → 무시
    if (seq == lastSeq) { dup = true; return false; }
    vals = new int[n]; int s2 = 0;
    for (int i = 0; i < n; i++) { vals[i] = V(HEAD + i); s2 = (s2 + vals[i] * (((i + 1) % 7) + 1)) % 4096; }
    return s2 == sum;
  }
  static void Read(Bitmap bmp) {
    BitmapData d = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    try {
      int[][] cal = new int[4][];
      for (int k = 0; k < 4; k++) cal[k] = Px(d, k * CELL + CELL / 2);
      // 기준 칸 확인: 회색 4단계가 차례로 밝아져야 함
      for (int c = 0; c < 3; c++) {
        // (2026-10-27) 고침: 예전엔 아래 '{ ... return; }' 이 주석 뒤에 붙어 있어 이 검사가 꺼져 있었음
        //  → 줄이 숨은 동안 까만 바닥을 '번호 0 신호'로 잘못 읽고, 다음 진짜 신호를 '놓침'으로 보고 그 대화 한 줄을 버림 (길드 글 빠짐의 원인)
        if (!(cal[0][c] < cal[1][c] - 14 && cal[1][c] < cal[2][c] - 14 && cal[2][c] < cal[3][c] - 14)) { Status = "신호 없음"; return; }   // (2026-10-25) 어두운 색(40씩 차이)으로 바꿔서 기준도 맞춤
        if (Math.Abs(cal[0][c] - cal[0][0]) > 30 || Math.Abs(cal[3][c] - cal[3][0]) > 30) { Status = "신호 없음"; return; }
      }
      // (2026-11-14 대표) 색 읽기 방식: 0 = 원래대로(칸마다 회색 기준과 가장 가까운 단계) · 1~4 = 와우 '색각 보정 필터'(25·50·75·100%)로 색이 바뀐 화면을 거꾸로 맞춰 읽기
      //   보통 PC는 0번만 씀. 신호를 한 번도 못 받은 채 기준 칸은 맞는데 검산만 15번 넘게 틀리면 그때만 1~4번을 시험하고, 검산이 맞는 방식을 기억해 씀 (원래 방식이 다시 맞으면 바로 0번으로)
      int[] tries = Mode == 0 ? new int[] { 0 } : new int[] { Mode, 0 };
      int[] vals = null; int seq = -1, n = 0, sum = 0, used = -1; bool lenBad = false, dup = false;
      for (int ti = 0; ti < tries.Length && used < 0; ti++) {
        int m = tries[ti];
        if (Try(d, cal, m, out vals, out seq, out n, out sum, ref lenBad, ref dup)) used = m;
        if (dup) { Status = "연결됨"; return; }
      }
      if (used < 0 && Mode == 0 && Packets == 0) {
        if (++FailStreak >= 15) {
          for (int m = 1; m <= 4 && used < 0; m++) {
            if (Try(d, cal, m, out vals, out seq, out n, out sum, ref lenBad, ref dup)) used = m;
            if (dup) { Status = "연결됨"; return; }
          }
        }
      }
      if (used < 0) { Status = lenBad ? "잘못된 길이" : "검산 틀림"; return; }   // 화면이 바뀌는 중간에 찍힘 → 다음에 다시 읽음
      if (used != Mode) { Mode = used; FailStreak = 0; }
      if (lastSeq >= 0 && seq != (lastSeq + 1) % 4096) { Drops++; skipToNl = true; }
      lastSeq = seq; Packets++;
      LastPacketTick = Environment.TickCount;
      Status = "연결됨";
      // 6비트 → 바이트
      int acc = 0, bits = 0;
      for (int i = 0; i < n; i++) {
        acc = (acc << 6) | vals[i]; bits += 6;
        if (bits >= 8) { bits -= 8; byte b = (byte)((acc >> bits) & 0xFF); Feed(b); }
      }
    } finally { bmp.UnlockBits(d); }
  }
  static void Feed(byte b) {
    if (b == 10) {
      if (!skipToNl && buf.Count > 0) Records.Enqueue(Encoding.UTF8.GetString(buf.ToArray()));
      buf.Clear(); skipToNl = false; return;
    }
    if (!skipToNl) { buf.Add(b); if (buf.Count > 65536) { buf.Clear(); skipToNl = true; } }   // (2026-10-25) 줄바꿈이 안 오면 끝없이 커지지 않게
  }
}

// ---------- 글자 그리기 (게임 채팅처럼 또렷하게: GDI+ 격자 맞춤 + 1픽셀 검은 그림자) ----------
public static class FTRText {
  static System.Drawing.Text.PrivateFontCollection pfc;
  static FontFamily fam;
  static FontStyle style = FontStyle.Regular;
  public static string Init(string path) {
    try {
      pfc = new System.Drawing.Text.PrivateFontCollection(); pfc.AddFontFile(path); fam = pfc.Families[0];
      style = fam.IsStyleAvailable(FontStyle.Bold) && !fam.IsStyleAvailable(FontStyle.Regular) ? FontStyle.Bold : (fam.IsStyleAvailable(FontStyle.Regular) ? FontStyle.Regular : FontStyle.Bold);
      return fam.Name;
    } catch (Exception e) { fam = new FontFamily("Malgun Gothic"); style = FontStyle.Bold; return "fallback: " + e.Message; }
  }
  struct Tok { public string t; public int c; public bool sp; }
  // texts/cols: 색 조각들 · em: 글자 크기(px) · maxW: 줄 너비(px) · lineH: 줄 높이(px) · tag: 앞에 붙는 작은 꼬리표(없으면 null)
  public static System.Windows.Media.Imaging.BitmapSource Render(string[] texts, int[] cols, float em, int maxW, float lineH, float sh, string tag, int tagCol, float tagEm) {
    if (maxW < 20) maxW = 20;
    Font f = new Font(fam, em, style, GraphicsUnit.Pixel);
    Font tf = tag != null ? new Font(fam, tagEm, style, GraphicsUnit.Pixel) : null;
    StringFormat sf = (StringFormat)StringFormat.GenericTypographic.Clone();
    sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap;
    List<Tok> toks = new List<Tok>();
    for (int i = 0; i < texts.Length; i++) {
      string t = texts[i] ?? ""; int k = 0;
      while (k < t.Length) {
        bool sp = t[k] == ' '; int j = k;
        while (j < t.Length && (t[j] == ' ') == sp) j++;
        Tok tk; tk.t = t.Substring(k, j - k); tk.c = cols[i]; tk.sp = sp; toks.Add(tk); k = j;
      }
    }
    using (Bitmap probe = new Bitmap(1, 1)) using (Graphics pg = Graphics.FromImage(probe)) {
      pg.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
      // 줄 나누기
      float x0 = 0;
      float tagW = 0;
      if (tf != null) { tagW = pg.MeasureString(tag, tf, PointF.Empty, sf).Width + tagEm * 0.9f; x0 = tagW + em * 0.35f; }
      List<List<KeyValuePair<float, Tok>>> lines = new List<List<KeyValuePair<float, Tok>>>();
      List<KeyValuePair<float, Tok>> cur = new List<KeyValuePair<float, Tok>>(); float x = x0;
      foreach (Tok tk0 in toks) {
        Tok tk = tk0;
        float w = pg.MeasureString(tk.t, f, PointF.Empty, sf).Width;
        if (!tk.sp && x + w > maxW && cur.Count > 0) { lines.Add(cur); cur = new List<KeyValuePair<float, Tok>>(); x = x0; }
        if (tk.sp && cur.Count == 0 && lines.Count > 0) continue;
        // 한 낱말이 줄보다 길면 글자 단위로 자름
        if (!tk.sp && w > maxW - x0) {
          string rest = tk.t;
          while (rest.Length > 0) {
            int n = rest.Length;
            while (n > 1 && x + pg.MeasureString(rest.Substring(0, n), f, PointF.Empty, sf).Width > maxW) n--;
            Tok p; p.t = rest.Substring(0, n); p.c = tk.c; p.sp = false;
            cur.Add(new KeyValuePair<float, Tok>(x, p)); x += pg.MeasureString(p.t, f, PointF.Empty, sf).Width;
            rest = rest.Substring(n);
            if (rest.Length > 0) { lines.Add(cur); cur = new List<KeyValuePair<float, Tok>>(); x = x0; }
          }
          continue;
        }
        cur.Add(new KeyValuePair<float, Tok>(x, tk)); x += w;
      }
      if (cur.Count > 0) lines.Add(cur);
      if (lines.Count == 0) lines.Add(new List<KeyValuePair<float, Tok>>());
      int H = (int)Math.Ceiling(lines.Count * lineH) + 2;
      float maxX = 0;
      foreach (var ln in lines) foreach (var kv in ln) { float e = kv.Key + pg.MeasureString(kv.Value.t, f, PointF.Empty, sf).Width; if (e > maxX) maxX = e; }
      int W = Math.Max(4, (int)Math.Ceiling(maxX + sh + 2));
      using (Bitmap bmp = new Bitmap(W, H, PixelFormat.Format32bppPArgb)) {
        using (Graphics g = Graphics.FromImage(bmp)) {
          g.Clear(Color.Transparent);
          g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
          g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
          float top = (lineH - f.GetHeight(g)) / 2f;
          if (tf != null) {
            float th = tf.GetHeight(g); float ty = top + (f.GetHeight(g) - th) / 2f;
            RectangleF r = new RectangleF(0, ty - 1, tagW, th + 2);
            using (var path = Round(r, Math.Min(r.Height / 2f, tagEm * 0.5f)))
            using (SolidBrush fb = new SolidBrush(Color.FromArgb(70, 200, 165, 90)))
            using (Pen pn = new Pen(Color.FromArgb(150, 225, 190, 110), 1f)) { g.FillPath(fb, path); g.DrawPath(pn, path); }
            using (SolidBrush tb = new SolidBrush(Color.FromArgb(tagCol))) g.DrawString(tag, tf, tb, tagEm * 0.45f, ty, sf);
          }
          using (SolidBrush shb = new SolidBrush(Color.FromArgb(235, 0, 0, 0))) {
            for (int li = 0; li < lines.Count; li++) foreach (var kv in lines[li]) if (!kv.Value.sp) g.DrawString(kv.Value.t, f, shb, kv.Key + sh, li * lineH + top + sh, sf);
          }
          for (int li = 0; li < lines.Count; li++) foreach (var kv in lines[li]) if (!kv.Value.sp) using (SolidBrush b = new SolidBrush(Color.FromArgb(kv.Value.c))) g.DrawString(kv.Value.t, f, b, kv.Key, li * lineH + top, sf);
        }
        BitmapData d = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
        try {
          var src = System.Windows.Media.Imaging.BitmapSource.Create(W, H, 96, 96, System.Windows.Media.PixelFormats.Pbgra32, null, d.Scan0, d.Stride * H, d.Stride);
          src.Freeze();
          return src;
        } finally { bmp.UnlockBits(d); f.Dispose(); if (tf != null) tf.Dispose(); }
      }
    }
  }
  static System.Drawing.Drawing2D.GraphicsPath Round(RectangleF r, float rad) {
    var p = new System.Drawing.Drawing2D.GraphicsPath(); float d = rad * 2;
    p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90); p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90); p.CloseFigure();
    return p;
  }
}
