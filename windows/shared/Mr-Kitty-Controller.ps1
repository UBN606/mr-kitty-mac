param([switch]$SmokeTest, [switch]$UiSmokeTest, [switch]$Demo)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Windows Alt is the Option-key equivalent. Ctrl-click is supported too.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class KittyDesktop {
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct Point { public int X, Y; }
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public static bool LeftDown() { return (GetAsyncKeyState(0x01) & 0x8000) != 0; }
    public static bool ModifierDown() {
        return (GetAsyncKeyState(0x11) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x12) & 0x8000) != 0;
    }
    public static int[] Cursor() { Point p; GetCursorPos(out p); return new int[] {p.X, p.Y}; }
    public static void VoiceTyping() {
        keybd_event(0x5B, 0, 0, UIntPtr.Zero);
        keybd_event(0x48, 0, 0, UIntPtr.Zero);
        keybd_event(0x48, 0, 2, UIntPtr.Zero);
        keybd_event(0x5B, 0, 2, UIntPtr.Zero);
    }
    public static long[] Find(int processId) {
        long[] best = null;
        int bestArea = 0;
        EnumWindows((hwnd, data) => {
            uint owner;
            GetWindowThreadProcessId(hwnd, out owner);
            if (owner != processId || !IsWindowVisible(hwnd)) return true;
            Rect rect;
            if (!GetWindowRect(hwnd, out rect)) return true;
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;
            if (width < 50 || height < 50 || width > 500 || height > 500) return true;
            int area = width * height;
            if (area > bestArea) {
                bestArea = area;
                best = new long[] {rect.Left, rect.Top, rect.Right, rect.Bottom, hwnd.ToInt64()};
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }
    public static void Hide(long handle) { if (handle != 0) ShowWindowAsync(new IntPtr(handle), 0); }
    public static void Reveal(long handle) { if (handle != 0) ShowWindowAsync(new IntPtr(handle), 4); }
}
'@

function Get-KittyBounds {
    foreach ($petProcess in @(Get-Process -Name CoPet -ErrorAction SilentlyContinue)) {
        $bounds = [KittyDesktop]::Find($petProcess.Id)
        if ($bounds) { return ,$bounds }
    }
    return $null
}

$sitPath = Join-Path $PSScriptRoot 'kitty-sit.png'
$curlPath = Join-Path $PSScriptRoot 'kitty-curl.png'
if (-not (Test-Path -LiteralPath $sitPath) -or -not (Test-Path -LiteralPath $curlPath)) {
    throw 'Mr. Kitty animation frames are missing.'
}
if ($SmokeTest) {
    $bounds = Get-KittyBounds
    if (-not $bounds) { throw 'The visible Mr. Kitty window was not found.' }
    Write-Output "Kitty visible at $($bounds[0..3] -join ','); animation frames present."
    exit 0
}

$createdNew = $false
if (-not $UiSmokeTest) {
    $mutex = New-Object System.Threading.Mutex($true, 'Local\MrKittyController', [ref]$createdNew)
    if (-not $createdNew) { $mutex.Dispose(); exit 0 }
}

$effectXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="192" Height="208" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Topmost="True" ResizeMode="NoResize" Title="Mr. Kitty animation">
  <Canvas x:Name="Stage" Background="Transparent" ClipToBounds="False">
    <Image x:Name="CatFrame" Stretch="Fill" RenderTransformOrigin="0.5,0.65">
      <Image.RenderTransform>
        <TransformGroup>
          <ScaleTransform x:Name="CatScale" ScaleX="1" ScaleY="1"/>
          <RotateTransform x:Name="CatRotate" Angle="0"/>
          <TranslateTransform x:Name="CatMove" X="0" Y="0"/>
        </TransformGroup>
      </Image.RenderTransform>
    </Image>
    <Ellipse x:Name="Biscuit" Width="17" Height="13" Visibility="Collapsed"
             Fill="#FFD79A54" Stroke="#FFFFD7A0" StrokeThickness="2">
      <Ellipse.Effect>
        <DropShadowEffect Color="#FFFFC061" Opacity="0.8" BlurRadius="9" ShadowDepth="0"/>
      </Ellipse.Effect>
    </Ellipse>
  </Canvas>
</Window>
'@
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($effectXaml))
try { $effect = [Windows.Markup.XamlReader]::Load($reader) }
finally { $reader.Dispose() }
$catFrame = $effect.FindName('CatFrame')
$catScale = $effect.FindName('CatScale')
$catRotate = $effect.FindName('CatRotate')
$catMove = $effect.FindName('CatMove')
$biscuit = $effect.FindName('Biscuit')
$sitFrame = [Windows.Media.Imaging.BitmapImage]::new([Uri]::new($sitPath))
$curlFrame = [Windows.Media.Imaging.BitmapImage]::new([Uri]::new($curlPath))

$dockXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="116" Height="30" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Topmost="True" ResizeMode="NoResize" Title="Mr. Kitty chat controls">
  <Border CornerRadius="15" Background="#D827303D" BorderBrush="#88FFFFFF"
          BorderThickness="1" Padding="2">
    <Border.Effect>
      <DropShadowEffect Color="#77000000" BlurRadius="9" ShadowDepth="2" Opacity="0.6"/>
    </Border.Effect>
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
      <Button x:Name="WriteButton" Width="30" Height="24" Padding="0"
              Background="Transparent" BorderThickness="0"
              ToolTip="Write to Kitty" Cursor="Hand">
        <Canvas Width="18" Height="18">
          <Path Data="M 2,15 L 3,18 L 6,17 L 16,7 L 13,4 Z"
                Fill="#FFF3F8FA"/>
          <Path Data="M 11.5,5.5 L 14.5,8.5" Stroke="#FF26303B" StrokeThickness="1"/>
        </Canvas>
      </Button>
      <Button x:Name="VoiceButton" Width="30" Height="24" Padding="0"
              Background="Transparent" BorderThickness="0"
              ToolTip="Speak to Kitty using Windows voice typing" Cursor="Hand">
        <Canvas Width="18" Height="18">
          <Border Width="6" Height="10" CornerRadius="3" BorderBrush="#FFF3F8FA"
                  BorderThickness="1.6" Canvas.Left="6" Canvas.Top="1"/>
          <Path Data="M 3,9 C 3,15 15,15 15,9 M 9,14 L 9,18 M 6,18 L 12,18"
                Stroke="#FFF3F8FA" StrokeThickness="1.6" StrokeStartLineCap="Round"
                StrokeEndLineCap="Round"/>
        </Canvas>
      </Button>
      <Button x:Name="ProviderButton" Width="52" Height="24" FontSize="10" Content="Codex"
              Foreground="White" Background="Transparent" BorderThickness="0"
              ToolTip="Switch Kitty chat between Codex and Claude" Cursor="Hand"/>
    </StackPanel>
  </Border>
</Window>
'@
$composerXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="314" Height="280" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" Topmost="True"
        ResizeMode="NoResize" Title="Talk to Mr. Kitty">
  <Border CornerRadius="18" Background="#EE202834" BorderBrush="#99FFFFFF"
          BorderThickness="1" Padding="12">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="22"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="98"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock x:Name="ChatHeader" Text="Message Kitty - Codex" Foreground="White" FontSize="12" FontWeight="SemiBold"/>
      <TextBox x:Name="ChatText" Grid.Row="1" TextWrapping="Wrap" AcceptsReturn="True"
               VerticalScrollBarVisibility="Auto" Padding="8" FontSize="13"
               Foreground="White" Background="#553B4757" BorderThickness="0"/>
      <ScrollViewer Grid.Row="2" Margin="0,7,0,0" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="ChatAnswer" Text="Kitty's reply will appear here."
                   TextWrapping="Wrap" Foreground="#FFE4EDF2" FontSize="12"/>
      </ScrollViewer>
      <DockPanel Grid.Row="3" Margin="0,9,0,0">
        <TextBlock x:Name="ChatStatus" Text="Enter to send | Shift+Enter for a new line"
                   Foreground="#C9D5DF" FontSize="10" VerticalAlignment="Center"/>
        <Button x:Name="SendButton" Content="Send" Width="56" Height="28"
                Foreground="White" Background="#FF476B77" BorderThickness="0"
                HorizontalAlignment="Right" DockPanel.Dock="Right" Cursor="Hand"/>
      </DockPanel>
    </Grid>
  </Border>
</Window>
'@
function New-KittyWindow([string]$markup) {
    $xml = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($markup))
    try { return [Windows.Markup.XamlReader]::Load($xml) }
    finally { $xml.Dispose() }
}
$dock = New-KittyWindow $dockXaml
$composer = New-KittyWindow $composerXaml
$writeButton = $dock.FindName('WriteButton')
$voiceButton = $dock.FindName('VoiceButton')
$providerButton = $dock.FindName('ProviderButton')
$chatText = $composer.FindName('ChatText')
$chatHeader = $composer.FindName('ChatHeader')
$chatStatus = $composer.FindName('ChatStatus')
$chatAnswerView = $composer.FindName('ChatAnswer')
$sendButton = $composer.FindName('SendButton')
if ($UiSmokeTest) {
    if (-not $writeButton -or -not $voiceButton -or -not $providerButton -or
        -not $chatHeader -or -not $chatText -or -not $sendButton -or -not $chatAnswerView) {
        throw 'Kitty chat controls did not load.'
    }
    if ($dock.Width -gt 120 -or $dock.Height -gt 32 -or
        $writeButton.Content -isnot [Windows.Controls.Canvas] -or
        $voiceButton.Content -isnot [Windows.Controls.Canvas]) {
        throw 'Kitty dock is oversized or its drawn icons did not load.'
    }
    Write-Output 'Kitty text, voice, provider, send, and reply controls loaded.'
    exit 0
}
$runtime = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$script:chatRequest = Join-Path $runtime 'kitty-chat-request.json'
$script:chatResult = Join-Path $runtime 'kitty-chat-result.json'
$script:chatState = Join-Path $runtime 'kitty-chat-state.json'
$script:chatAnswer = ''
$script:chatBusy = $false
$script:chatProvider = 'codex'
$script:lastBounds = $null
$script:lastDockUpdate = [DateTime]::MinValue

function Show-KittyComposer([bool]$voice) {
    if (-not $composer.IsVisible) { $composer.Show() }
    $composer.Activate() | Out-Null
    $chatText.Focus() | Out-Null
    if ($voice) {
        $chatStatus.Text = 'Speak now, review the words, then Send'
        [KittyDesktop]::VoiceTyping()
    }
}
function Switch-KittyProvider {
    if ($script:chatBusy) { return }
    $script:chatProvider = if ($script:chatProvider -eq 'codex') { 'claude' } else { 'codex' }
    $name = if ($script:chatProvider -eq 'codex') { 'Codex' } else { 'Claude' }
    $providerButton.Content = $name
    $chatHeader.Text = "Message Kitty - $name"
    $chatAnswerView.Text = "Kitty will reply from $name."
}
function Send-KittyMessage {
    if ($script:chatBusy) { return }
    $message = $chatText.Text.Trim()
    if (-not $message) { return }
    $backend = Join-Path $PSScriptRoot 'Mr-Kitty-Chat.py'
    $python = $env:MR_KITTY_PYTHON
    if (-not $python) {
        $pythonCommand = Get-Command 'python.exe' -ErrorAction SilentlyContinue
        if ($pythonCommand) { $python = $pythonCommand.Source }
    }
    if (-not $python -or -not (Test-Path -LiteralPath $python) -or
        -not (Test-Path -LiteralPath $backend)) {
        $chatStatus.Text = 'Kitty chat backend is unavailable.'
        return
    }
    if (Test-Path -LiteralPath $script:chatResult) { Remove-Item -LiteralPath $script:chatResult -Force }
    $json = @{message = $message; provider = $script:chatProvider} | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($script:chatRequest, $json, [Text.UTF8Encoding]::new($false))
    $args = @('"' + $backend + '"', '"' + $script:chatRequest + '"',
              '"' + $script:chatResult + '"', '"' + $script:chatState + '"')
    Start-Process -FilePath $python -ArgumentList $args -WindowStyle Hidden
    $script:chatBusy = $true
    $sendButton.IsEnabled = $false
    $providerButton.IsEnabled = $false
    $chatAnswerView.Text = ''
    $chatStatus.Text = 'Kitty is thinking...'
}
$writeButton.Add_Click({ Show-KittyComposer $false })
$voiceButton.Add_Click({ Show-KittyComposer $true })
$providerButton.Add_Click({ Switch-KittyProvider })
$sendButton.Add_Click({ Send-KittyMessage })
$chatText.Add_PreviewKeyDown({
    param($sender, $event)
    if ($event.Key -eq [Windows.Input.Key]::Enter -and
        -not ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift)) {
        $event.Handled = $true
        Send-KittyMessage
    }
})
$composer.Add_Closing({ param($sender, $event) $event.Cancel = $true; $composer.Hide() })

function Update-KittyDock {
    $bounds = Get-KittyBounds
    if ($bounds) { $script:lastBounds = $bounds }
    if (-not $bounds -and -not $script:mode) {
        $dock.Hide()
        $composer.Hide()
        return
    }
    if (-not $script:lastBounds) { return }
    $b = $script:lastBounds
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new([int]$b[0], [int]$b[1])).WorkingArea
    $dock.Left = [Math]::Max($screen.Left, [Math]::Min($screen.Right - $dock.Width, (($b[0] + $b[2] - $dock.Width) / 2)))
    $dock.Top = [Math]::Max($screen.Top, [Math]::Min($screen.Bottom - $dock.Height, $b[3] - $dock.Height + 2))
    $composer.Left = [Math]::Max($screen.Left, [Math]::Min($screen.Right - $composer.Width, $dock.Left + $dock.Width - $composer.Width))
    $composer.Top = [Math]::Max($screen.Top, [Math]::Min($screen.Bottom - $composer.Height, $dock.Top - $composer.Height - 5))
    if (-not $dock.IsVisible) { $dock.Show() }
}

$script:mode = ''
$script:petHandle = 0L
$script:clock = [Diagnostics.Stopwatch]::new()
$script:wasLeftDown = [KittyDesktop]::LeftDown()

function Restore-Kitty {
    if ($script:petHandle) {
        [KittyDesktop]::Reveal($script:petHandle)
        $script:petHandle = 0L
    }
    $effect.Hide()
    $script:mode = ''
}

function Begin-Treat {
    $script:mode = 'treat'
    $catFrame.Source = $sitFrame
    $catRotate.Angle = 0
    $catScale.ScaleX = 1
    $catScale.ScaleY = 1
    $catMove.X = 0
    $catMove.Y = 0
    $biscuit.Visibility = [Windows.Visibility]::Visible
    $script:clock.Restart()
}

function Begin-TrickForTreat {
    if ($script:mode) { return }
    $bounds = Get-KittyBounds
    if (-not $bounds) { return }
    $script:petHandle = [long]$bounds[4]
    $width = [int]($bounds[2] - $bounds[0])
    $height = [int]($bounds[3] - $bounds[1])
    $effect.Width = $width
    $effect.Height = $height
    $effect.Left = [double]$bounds[0]
    $effect.Top = [double]$bounds[1]
    $catFrame.Width = $width
    $catFrame.Height = $height
    $catFrame.Source = $sitFrame
    $catRotate.Angle = 0
    $catScale.ScaleX = 1
    $catScale.ScaleY = 1
    $catMove.X = 0
    $catMove.Y = 0
    $biscuit.Visibility = [Windows.Visibility]::Collapsed
    $effect.Show()
    [KittyDesktop]::Hide($script:petHandle)
    $script:mode = 'trick'
    $script:clock.Restart()
}

$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(16)
$timer.Add_Tick({
    try {
        if (([DateTime]::UtcNow - $script:lastDockUpdate).TotalMilliseconds -ge 180) {
            $script:lastDockUpdate = [DateTime]::UtcNow
            Update-KittyDock
            if ($script:chatBusy -and (Test-Path -LiteralPath $script:chatResult)) {
                $reply = Get-Content -LiteralPath $script:chatResult -Raw | ConvertFrom-Json
                $script:chatBusy = $false
                $sendButton.IsEnabled = $true
                $providerButton.IsEnabled = $true
                if ($reply.ok) {
                    $chatAnswerView.Text = [string]$reply.answer
                    $chatText.Clear()
                    $name = if ($reply.provider -eq 'claude') { 'Claude' } else { 'Codex' }
                    $chatStatus.Text = "$name replied - type another message"
                } else {
                    $chatAnswerView.Text = [string]$reply.error
                    $chatStatus.Text = 'Message failed - try again'
                }
            }
        }
        $leftDown = [KittyDesktop]::LeftDown()
        if ($leftDown -and -not $script:wasLeftDown -and -not $script:mode -and [KittyDesktop]::ModifierDown()) {
            $bounds = Get-KittyBounds
            if ($bounds) {
                $point = [KittyDesktop]::Cursor()
                if ($point[0] -ge $bounds[0] -and $point[0] -lt $bounds[2] -and
                    $point[1] -ge $bounds[1] -and $point[1] -lt $bounds[3]) {
                    Begin-TrickForTreat
                }
            }
        }
        $script:wasLeftDown = $leftDown
        if (-not $script:mode) { return }
        $elapsed = $script:clock.Elapsed.TotalMilliseconds
        if ($script:mode -eq 'trick') {
            if ($elapsed -lt 220) {
                $catScale.ScaleY = 1 - 0.12 * ($elapsed / 220)
                $catMove.Y = 7 * ($elapsed / 220)
            } elseif ($elapsed -lt 1450) {
                $p = ($elapsed - 220) / 1230.0
                $catScale.ScaleY = 1
                $catRotate.Angle = 360 * $p
                $catMove.Y = -26 * [Math]::Sin([Math]::PI * $p)
                $catMove.X = 11 * [Math]::Sin(2 * [Math]::PI * $p)
            } else {
                $catFrame.Source = $curlFrame
                $catRotate.Angle = 0
                $catMove.X = 0
                $catMove.Y = 0
                $catScale.ScaleY = 1
            }
            if ($elapsed -ge 2180) { Begin-Treat }
        } else {
            if ($elapsed -lt 740) {
                $p = $elapsed / 740.0
                $x = ($effect.Width * 0.88) - ($effect.Width * 0.37 * $p)
                $y = ($effect.Height * 0.76) - ($effect.Height * 0.42 * $p) - (24 * [Math]::Sin([Math]::PI * $p))
                [Windows.Controls.Canvas]::SetLeft($biscuit, $x)
                [Windows.Controls.Canvas]::SetTop($biscuit, $y)
                $catRotate.Angle = -5 * $p
            } else {
                $biscuit.Visibility = [Windows.Visibility]::Collapsed
                $p = [Math]::Min(1, ($elapsed - 740) / 730.0)
                $catRotate.Angle = -5 + 4 * [Math]::Sin($p * 5 * [Math]::PI)
                $catScale.ScaleY = 1 - 0.045 * [Math]::Sin($p * 6 * [Math]::PI)
                $catFrame.Source = if ($elapsed -lt 1160) { $curlFrame } else { $sitFrame }
            }
            if ($elapsed -ge 1500) { Restore-Kitty }
        }
    } catch {
        Restore-Kitty
    }
})

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$exitItem = $trayMenu.Items.Add('Exit Kitty gestures')
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = 'Mr. Kitty: Alt-click or Ctrl-click for a trick and treat'
$tray.ContextMenuStrip = $trayMenu
$tray.Visible = $true
$dispatcher = [Windows.Threading.Dispatcher]::CurrentDispatcher
$exitItem.Add_Click({ $dispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Normal) })

try {
    $timer.Start()
    if ($Demo) {
        $demoTimer = [Windows.Threading.DispatcherTimer]::new()
        $demoTimer.Interval = [TimeSpan]::FromMilliseconds(800)
        $demoTimer.Add_Tick({ $demoTimer.Stop(); Begin-TrickForTreat })
        $demoTimer.Start()
    }
    [Windows.Threading.Dispatcher]::Run()
} finally {
    $timer.Stop()
    if ($demoTimer) { $demoTimer.Stop() }
    Restore-Kitty
    $dock.Close()
    $composer.Close()
    $tray.Visible = $false
    $tray.Dispose()
    $trayMenu.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
