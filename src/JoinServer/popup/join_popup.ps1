# =====================================================================
#  JoinServer — окошко «IP → Подключиться» поверх игры
#  by whivipe / dreadhunger.fun
#
#  Два режима:
#    -Watch   сторож: висит скрыто, пока жива игра, и ждёт файл
#             open_popup.flag (его пишет мод по клавише O) → показывает окно.
#    (без)    просто показать окно один раз (запасной путь из мода).
#
#  Результат окна: join_target.txt = адрес, join_now.flag = «заходи сейчас».
#  Мод JoinServer видит join_now.flag и зовёт ConnectToURI.
#  Файл в UTF-8 с BOM — иначе PowerShell 5.1 покажет кракозябры.
# =====================================================================
param([switch]$Watch, [switch]$Warm)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Игра (UE4) зажимает курсор в своём окне (ClipCursor) и прячет его.
# Отпускаем зажим, тащим окно на передний план и ставим курсор в поле.
Add-Type -Namespace Win -Name U32 -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool ClipCursor(IntPtr rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern int ShowCursor(bool show);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool ReleaseCapture();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
'@

function Grab-Input($form, $tb, [bool]$moveCursor) {
  try {
    # процесс сторожа запущен скрытым (STARTUPINFO=SW_HIDE) — первое окно
    # WinForms наследует это и остаётся невидимым; показываем явно
    [Win.U32]::ShowWindow($form.Handle, 5) | Out-Null   # SW_SHOW
    $form.Visible = $true
    [Win.U32]::ClipCursor([IntPtr]::Zero)
    [Win.U32]::ReleaseCapture() | Out-Null
    if ([Win.U32]::GetForegroundWindow() -ne $form.Handle) {
      # трюк с Alt: без него Windows не даёт фоновому процессу забрать фокус
      [Win.U32]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
      [Win.U32]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
      [Win.U32]::SetForegroundWindow($form.Handle) | Out-Null
    }
    $form.Activate()
    if ($moveCursor) {
      $pt = $tb.PointToScreen((New-Object System.Drawing.Point([int]($tb.Width / 2), [int]($tb.Height / 2))))
      [Win.U32]::SetCursorPos($pt.X, $pt.Y) | Out-Null
    }
    while ([Win.U32]::ShowCursor($true) -lt 0) { }
  } catch { }
}

$SaveDir    = Join-Path $env:LOCALAPPDATA 'DreadHunger\Saved\SaveData'
$TargetFile = Join-Path $SaveDir 'join_target.txt'
$OpenFlag   = Join-Path $SaveDir 'open_popup.flag'
$JoinFlag   = Join-Path $SaveDir 'join_now.flag'
$AliveFile  = Join-Path $SaveDir 'popup_watcher.alive'
$DbgFile    = Join-Path $env:LOCALAPPDATA 'DreadHunger\Saved\Logs\join_popup.log'
function Dbg([string]$m) { try { Add-Content -Path $DbgFile -Value ((Get-Date).ToString('HH:mm:ss.fff') + ' ' + $m) -Encoding UTF8 } catch { } }
if (-not (Test-Path $SaveDir)) { New-Item -ItemType Directory -Path $SaveDir -Force | Out-Null }

# палитра сайта (style.css :root)
$C_BG    = [System.Drawing.Color]::FromArgb(8, 12, 17)
$C_CARD  = [System.Drawing.Color]::FromArgb(20, 28, 37)
$C_LINE  = [System.Drawing.Color]::FromArgb(35, 47, 60)
$C_TEXT  = [System.Drawing.Color]::FromArgb(233, 241, 247)
$C_MUTED = [System.Drawing.Color]::FromArgb(127, 143, 160)
$C_ACC   = [System.Drawing.Color]::FromArgb(90, 212, 230)
$C_RED   = [System.Drawing.Color]::FromArgb(252, 68, 69)

function Normalize([string]$raw) {
  if (-not $raw) { return $null }
  $m = [regex]::Match($raw, '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?::(\d{1,5}))?')
  if (-not $m.Success) { return $null }
  $port = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { '7777' }
  return $m.Groups[1].Value + ':' + $port
}

function Show-JoinDialog {
  # общее состояние диалога: хэш-таблица передаётся в замыкания по ссылке
  $st = @{ armed = $false; result = $null; ticks = 0 }
  $last = ''
  if (Test-Path $TargetFile) { try { $last = (Get-Content $TargetFile -First 1).Trim() } catch { } }

  $f = New-Object System.Windows.Forms.Form
  $f.Text            = 'Dread Hunger — заход на сервер'
  $f.FormBorderStyle = 'FixedDialog'
  $f.MaximizeBox     = $false; $f.MinimizeBox = $false
  $f.StartPosition   = 'CenterScreen'
  $f.TopMost         = $true
  $f.ClientSize      = New-Object System.Drawing.Size(420, 222)
  $f.BackColor       = $C_BG
  $f.ForeColor       = $C_TEXT
  $f.Font            = New-Object System.Drawing.Font('Segoe UI', 10)
  $f.KeyPreview      = $true

  $title = New-Object System.Windows.Forms.Label
  $title.Text = 'ЗАЙТИ НА СЕРВЕР'; $title.ForeColor = $C_ACC
  $title.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
  $title.Location = New-Object System.Drawing.Point(20, 16); $title.AutoSize = $true
  $f.Controls.Add($title)

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = 'IP-адрес сервера (ip или ip:порт, порт по умолчанию 7777)'
  $lbl.ForeColor = $C_MUTED; $lbl.Location = New-Object System.Drawing.Point(20, 48); $lbl.AutoSize = $true
  $f.Controls.Add($lbl)

  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = New-Object System.Drawing.Point(20, 72); $tb.Size = New-Object System.Drawing.Size(380, 30)
  $tb.Font = New-Object System.Drawing.Font('Consolas', 13)
  $tb.BackColor = $C_CARD; $tb.ForeColor = $C_TEXT; $tb.BorderStyle = 'FixedSingle'
  $tb.Text = $last
  $f.Controls.Add($tb)

  $err = New-Object System.Windows.Forms.Label
  $err.Text = ''; $err.ForeColor = $C_RED
  $err.Location = New-Object System.Drawing.Point(20, 108); $err.AutoSize = $true
  $f.Controls.Add($err)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'ПОДКЛЮЧИТЬСЯ'; $ok.FlatStyle = 'Flat'; $ok.FlatAppearance.BorderSize = 0
  $ok.BackColor = $C_ACC; $ok.ForeColor = $C_BG
  $ok.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $ok.Location = New-Object System.Drawing.Point(20, 140); $ok.Size = New-Object System.Drawing.Size(200, 38)
  $f.Controls.Add($ok)

  $paste = New-Object System.Windows.Forms.Button
  $paste.Text = 'Вставить'; $paste.FlatStyle = 'Flat'; $paste.FlatAppearance.BorderColor = $C_LINE
  $paste.BackColor = $C_CARD; $paste.ForeColor = $C_TEXT
  $paste.Location = New-Object System.Drawing.Point(230, 140); $paste.Size = New-Object System.Drawing.Size(84, 38)
  $f.Controls.Add($paste)

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Отмена'; $cancel.FlatStyle = 'Flat'; $cancel.FlatAppearance.BorderColor = $C_LINE
  $cancel.BackColor = $C_CARD; $cancel.ForeColor = $C_MUTED
  $cancel.Location = New-Object System.Drawing.Point(324, 140); $cancel.Size = New-Object System.Drawing.Size(76, 38)
  $f.Controls.Add($cancel)

  $hint = New-Object System.Windows.Forms.Label
  $hint.Text = 'Enter — подключиться · Ctrl+V или «Вставить» — адрес из буфера · Esc — закрыть'
  $hint.ForeColor = $C_MUTED; $hint.Font = New-Object System.Drawing.Font('Segoe UI', 8)
  $hint.Location = New-Object System.Drawing.Point(20, 190); $hint.AutoSize = $true
  $f.Controls.Add($hint)

    $submit = {
    $uri = Normalize $tb.Text
    if (-not $uri) { $err.Text = 'Не похоже на адрес. Пример: 203.0.113.5:7777'; return }
    $st.result = $uri
    $f.Close()
  }
  $ok.Add_Click($submit.GetNewClosure())
  $paste.Add_Click({
    try {
      $clip = [System.Windows.Forms.Clipboard]::GetText()
      $u = Normalize $clip
      if ($u) { $tb.Text = $u; $err.Text = '' } else { $err.Text = 'В буфере нет адреса вида 203.0.113.5:7777' }
    } catch { $err.Text = 'Не удалось прочитать буфер обмена' }
    $tb.Focus()
  }.GetNewClosure())
  $cancel.Add_Click({ $f.Close() }.GetNewClosure())
  $f.Add_KeyDown({
    if ($_.KeyCode -eq 'Return') { $_.SuppressKeyPress = $true; & $submit }
    elseif ($_.KeyCode -eq 'Escape') { $f.Close() }
  }.GetNewClosure())
  # первые 3 секунды каждые 200 мс возвращаем себе мышь и фокус — игра
  # может перехватить их обратно, когда её окно перерисуется
  $grab = New-Object System.Windows.Forms.Timer
  $grab.Interval = 200
    $grab.Add_Tick({
    $st.ticks++
    Grab-Input $f $tb $false
    if ($st.ticks -ge 6) { $grab.Stop() }
  }.GetNewClosure())
  # «я жив» и пока окно открыто — иначе мод решит, что сторожа нет, и поднимет второго
  $beat = New-Object System.Windows.Forms.Timer
  $beat.Interval = 1000
  $beat.Add_Tick({ try { [IO.File]::WriteAllText($AliveFile, [string][DateTime]::UtcNow.Ticks) } catch { } }.GetNewClosure())
  # кликнули по игре мимо окна — окно исчезает (не висит поверх игры).
  # Первые секунды не реагируем: пока отбираем фокус у игры, он может мигать.
    $arm = New-Object System.Windows.Forms.Timer
  $arm.Interval = 1500
  $arm.Add_Tick({ $st.armed = $true; $arm.Stop() }.GetNewClosure())
  $f.Add_Deactivate({ if ($st.armed) { $f.Close() } }.GetNewClosure())

  $f.Add_Shown({ Grab-Input $f $tb $true; $tb.Focus(); $tb.SelectAll(); $grab.Start(); $beat.Start(); $arm.Start() }.GetNewClosure())
  $f.Add_FormClosed({ $grab.Stop(); $beat.Stop(); $arm.Stop() }.GetNewClosure())

  Dbg "dialog: show (last='$last')"
  try { [System.Windows.Forms.Application]::Run($f) } catch { Dbg "dialog: Run error: $_" }
  Dbg "dialog: closed, result='$($st.result)'"
  $f.Dispose()

  if ($st.result) {
    [IO.File]::WriteAllText($TargetFile, $st.result + "`n")
    [IO.File]::WriteAllText($JoinFlag,   $st.result + "`n")
    Press-GameKey
  }
}

# После ввода — вернуть окно игре (заход делает мод по join_now.flag)
function Press-GameKey {
  try {
    $g = Get-Process -Name 'DreadHunger-Win64-Shipping' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $g -or $g.MainWindowHandle -eq [IntPtr]::Zero) { return }
    [Win.U32]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Win.U32]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [Win.U32]::SetForegroundWindow($g.MainWindowHandle) | Out-Null
  } catch { }
}

# -Warm: «тёплый» процесс. Всё уже загружено (Forms, P/Invoke) — ждём флаг и показываем окно
# мгновенно, вместо запуска нового powershell на каждое нажатие (это и были 2-3 секунды).
if ($Warm) {
  Dbg "warm: ready pid=$PID"
  while ($true) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $OpenFlag) { Remove-Item $OpenFlag -Force -ErrorAction SilentlyContinue; break }
    if (-not (Get-Process -Name 'DreadHunger-Win64-Shipping' -ErrorAction SilentlyContinue)) { exit 0 }
  }
  Show-JoinDialog; exit 0
}
if (-not $Watch) { Show-JoinDialog; exit 0 }

# ---------- сторож: живём, пока жива игра ----------
# второй сторож не нужен: если чужой heartbeat свежее 3 с — уходим
if (Test-Path $AliveFile) {
  try {
    $t = [long](Get-Content $AliveFile -Raw).Trim()
    if (([DateTime]::UtcNow.Ticks - $t) -lt 30000000) { Dbg "watcher: another alive, exit"; exit 0 }
  } catch { }
}
Dbg "watcher: start pid=$PID"
function Spawn-Warm {
  Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"' + $PSCommandPath + '"'), '-Warm')
}
$child = Spawn-Warm
$idle = 0
while ($true) {
  Start-Sleep -Milliseconds 150
  # «я жив» раз в ~секунду (мод читает файл; писать чаще — ловить sharing violation)
  if (($idle % 7) -eq 0) { try { [IO.File]::WriteAllText($AliveFile, [string][DateTime]::UtcNow.Ticks) } catch { } }
  # тёплый процесс показал окно и вышел (или упал) — сразу греем следующий
  if ($child.HasExited) { Dbg "watcher: warm exited, respawn"; $child = Spawn-Warm }
  # игра закрылась — уходим (проверяем раз в ~3 с, не каждый тик)
  $idle++
  if ($idle -ge 20) {
    $idle = 0
    if (-not (Get-Process -Name 'DreadHunger-Win64-Shipping' -ErrorAction SilentlyContinue)) {
      try { if (-not $child.HasExited) { $child.Kill() } } catch { }
      break
    }
  }
}
