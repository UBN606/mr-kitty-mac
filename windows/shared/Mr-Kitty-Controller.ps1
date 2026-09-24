param([switch]$SmokeTest, [switch]$UiSmokeTest, [switch]$RuntimeSmokeTest, [switch]$Demo)

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
    public static bool LeftDown() { return (GetAsyncKeyState(0x01) & 0x8000) != 0; }
    public static bool ModifierDown() {
        return (GetAsyncKeyState(0x11) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x12) & 0x8000) != 0;
    }
    public static int[] Cursor() { Point p; GetCursorPos(out p); return new int[] {p.X, p.Y}; }
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
if (-not $UiSmokeTest -and -not $RuntimeSmokeTest) {
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
        Width="146" Height="30" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Topmost="True" ResizeMode="NoResize" Title="Mr. Kitty chat controls">
  <Border CornerRadius="15" Background="#D827303D" BorderBrush="#88FFFFFF"
          BorderThickness="1" Padding="2">
    <Border.Effect>
      <DropShadowEffect Color="#77000000" BlurRadius="9" ShadowDepth="2" Opacity="0.6"/>
    </Border.Effect>
    <StackPanel x:Name="DockStack" Orientation="Horizontal" VerticalAlignment="Center">
      <StackPanel.Clip>
        <RectangleGeometry Rect="0,0,140,24" RadiusX="12" RadiusY="12"/>
      </StackPanel.Clip>
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
              ToolTip="Speak directly into Kitty chat; click again to stop" Cursor="Hand">
        <Canvas Width="18" Height="18">
          <Border Width="6" Height="10" CornerRadius="3" BorderBrush="#FFF3F8FA"
                  BorderThickness="1.6" Canvas.Left="6" Canvas.Top="1"/>
          <Path Data="M 3,9 C 3,15 15,15 15,9 M 9,14 L 9,18 M 6,18 L 12,18"
                Stroke="#FFF3F8FA" StrokeThickness="1.6" StrokeStartLineCap="Round"
                StrokeEndLineCap="Round"/>
        </Canvas>
      </Button>
      <StackPanel x:Name="ProviderChoices" Orientation="Horizontal">
        <Button x:Name="CodexButton" Width="40" Height="24" FontSize="9" Content="Codex"
                Foreground="White" Background="#FF287BA7" BorderThickness="0"
                ToolTip="Send Kitty messages to Codex" Cursor="Hand"/>
        <Button x:Name="ClaudeButton" Width="40" Height="24" FontSize="9" Content="Claude"
                Foreground="White" Background="#554D5968" BorderThickness="0"
                ToolTip="Send Kitty messages to Claude" Cursor="Hand"/>
      </StackPanel>
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
      <Button x:Name="DesktopButton" Grid.Row="0" Content="Desktop" Width="52" Height="21"
              HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,0,68,0" FontSize="10"
              Foreground="White" Background="#554B5665" BorderThickness="0"
              ToolTip="Choose a recent Codex Desktop or Claude Code reply" Cursor="Hand"/>
      <Button x:Name="HearButton" Grid.Row="0" Content="Hear" Width="36" Height="21"
              HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,0,27,0" FontSize="10"
              Foreground="White" Background="#554B5665" BorderThickness="0"
              ToolTip="Read Kitty's reply aloud; click again to stop" Cursor="Hand"/>
      <Button x:Name="CloseButton" Grid.Row="0" Content="X" Width="22" Height="21"
              HorizontalAlignment="Right" VerticalAlignment="Top" FontSize="11"
              Foreground="White" Background="#554B5665" BorderThickness="0"
              ToolTip="Close Kitty chat (Esc)" Cursor="Hand"/>
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
$codexButton = $dock.FindName('CodexButton')
$claudeButton = $dock.FindName('ClaudeButton')
$providerChoices = $dock.FindName('ProviderChoices')
$dockStack = $dock.FindName('DockStack')
$chatText = $composer.FindName('ChatText')
$chatHeader = $composer.FindName('ChatHeader')
$chatStatus = $composer.FindName('ChatStatus')
$chatAnswerView = $composer.FindName('ChatAnswer')
$sendButton = $composer.FindName('SendButton')
$desktopButton = $composer.FindName('DesktopButton')
$hearButton = $composer.FindName('HearButton')
$closeButton = $composer.FindName('CloseButton')
function Get-KittyPlacement([long[]]$bounds, [System.Drawing.Rectangle]$area) {
    $gap = 4
    $petCenter = ($bounds[0] + $bounds[2]) / 2.0
    $horizontalLeft = [Math]::Max($area.Left, [Math]::Min($area.Right - 146,
        ($petCenter - 73)))
    $narrow = [Math]::Abs($horizontalLeft - ($petCenter - 73)) -gt 20
    $dock.Width = if ($narrow) { 36 } else { 146 }
    $dock.Height = if ($narrow) { 104 } else { 30 }
    $dockStack.Orientation = if ($narrow) {
        [Windows.Controls.Orientation]::Vertical
    } else {
        [Windows.Controls.Orientation]::Horizontal
    }
    $providerChoices.Orientation = if ($narrow) {
        [Windows.Controls.Orientation]::Vertical
    } else {
        [Windows.Controls.Orientation]::Horizontal
    }
    $codexButton.Width = if ($narrow) { 30 } else { 40 }
    $claudeButton.Width = if ($narrow) { 30 } else { 40 }
    $codexButton.Content = if ($narrow) { 'Cx' } else { 'Codex' }
    $claudeButton.Content = if ($narrow) { 'Cl' } else { 'Claude' }
    $clipWidth = if ($narrow) { 30 } else { 140 }
    $clipHeight = if ($narrow) { 96 } else { 24 }
    $dockStack.Clip = [Windows.Media.RectangleGeometry]::new(
        [Windows.Rect]::new(0, 0, $clipWidth, $clipHeight), 12, 12
    )
    $dockLeft = [Math]::Max($area.Left, [Math]::Min($area.Right - $dock.Width,
        ($petCenter - $dock.Width / 2)))
    # Keep every dock button outside CoPet's window and its drag hit area.
    $belowPet = [double]$bounds[3]
    $abovePet = [double]$bounds[1] - $dock.Height - $gap
    if ($belowPet + $dock.Height -le $area.Bottom) {
        $dockTop = $belowPet
    } elseif ($abovePet -ge $area.Top) {
        $dockTop = $abovePet
    } else {
        $dockTop = [Math]::Max($area.Top, [Math]::Min($area.Bottom - $dock.Height, $belowPet))
    }
    $rightOfPet = [double]$bounds[2] + 8
    $leftOfPet = [double]$bounds[0] - $composer.Width - 8
    if ($rightOfPet + $composer.Width -le $area.Right) {
        $composerLeft = $rightOfPet
    } elseif ($leftOfPet -ge $area.Left) {
        $composerLeft = $leftOfPet
    } else {
        $composerLeft = [Math]::Max($area.Left, [Math]::Min($area.Right - $composer.Width, $rightOfPet))
    }
    $aboveDock = $dockTop - $composer.Height - 8
    $belowDock = $dockTop + $dock.Height + 8
    if ($aboveDock -ge $area.Top) {
        $composerTop = $aboveDock
    } elseif ($belowDock + $composer.Height -le $area.Bottom) {
        $composerTop = $belowDock
    } else {
        $composerTop = [Math]::Max($area.Top,
            [Math]::Min($area.Bottom - $composer.Height, [double]$bounds[1]))
    }
    return @{
        DockLeft = $dockLeft; DockTop = $dockTop
        ComposerLeft = $composerLeft; ComposerTop = $composerTop
    }
}
if ($UiSmokeTest) {
    if (-not $writeButton -or -not $voiceButton -or -not $codexButton -or
        -not $claudeButton -or
        -not $chatHeader -or -not $chatText -or -not $sendButton -or
        -not $closeButton -or -not $hearButton -or -not $desktopButton -or
        -not $chatAnswerView) {
        throw 'Kitty chat controls did not load.'
    }
    if ($dock.Width -gt 150 -or $dock.Height -gt 32 -or
        $writeButton.Content -isnot [Windows.Controls.Canvas] -or
        $voiceButton.Content -isnot [Windows.Controls.Canvas]) {
        throw 'Kitty dock is oversized or its drawn icons did not load.'
    }
    $testArea = [System.Drawing.Rectangle]::new(0, 0, 1920, 1080)
    $middle = Get-KittyPlacement ([long[]]@(200, 200, 400, 400, 0)) $testArea
    $edge = Get-KittyPlacement ([long[]]@(1700, 900, 1880, 1070, 0)) $testArea
    if ($middle.DockTop -lt 388 -or
        $middle.DockTop + 15 -le 400 -or
        $middle.ComposerLeft -lt 408 -or
        $edge.DockTop + $dock.Height -gt 896 -or
        $edge.ComposerLeft + $composer.Width -gt 1692 -or
        $middle.ComposerTop -le $middle.DockTop -and
        $middle.ComposerTop + $composer.Height -gt $middle.DockTop -or
        $edge.ComposerTop -le $edge.DockTop -and
        $edge.ComposerTop + $composer.Height -gt $edge.DockTop) {
        throw 'Kitty controls overlap the pet hit area.'
    }
    $taskbarEdge = Get-KittyPlacement ([long[]]@(1240, 20, 1380, 180, 0)) ([System.Drawing.Rectangle]::new(0, 0, 1312, 768))
    if ($dock.Width -ne 36 -or
        [Math]::Abs(($taskbarEdge.DockLeft + $dock.Width / 2) - 1310) -gt 20 -or
        $taskbarEdge.ComposerTop -lt $taskbarEdge.DockTop + $dock.Height + 8) {
        throw 'Kitty edge layout is not centered or the composer covers the dock.'
    }
    Write-Output 'Kitty text, voice, provider, send, and reply controls loaded.'
    exit 0
}
$runtime = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$script:speechInbox = Join-Path $runtime 'speech-inbox'
$script:desktopReplies = @{}
New-Item -ItemType Directory -Force -Path $script:speechInbox | Out-Null
Get-ChildItem -LiteralPath $script:speechInbox -Filter '*.json' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
$script:captureEnabledFlag = Join-Path $runtime 'desktop-reply-capture.flag'
# The watcher only captures replies. Playback requires a deliberate Hear click.
[IO.File]::WriteAllText($script:captureEnabledFlag, 'capture-only', [Text.UTF8Encoding]::new($false))
$script:chatRequest = Join-Path $runtime 'kitty-chat-request.json'
$script:chatResult = Join-Path $runtime 'kitty-chat-result.json'
$script:chatState = Join-Path $runtime 'kitty-chat-state.json'
$script:chatAnswer = ''
$script:hasSpeakableReply = $false
$script:chatBusy = $false
$script:chatProvider = 'codex'
$script:lastBounds = $null
$script:lastDockUpdate = [DateTime]::MinValue
$script:codexBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF287BA7')
$script:claudeBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFC46B4B')
$script:inactiveBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#554D5968')
$script:listeningBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFD14C5A')
$script:speechState = 'idle'
$script:speechEngine = $null
$script:sendAfterSpeech = $false
$script:voiceTurn = $false
$script:isSpeaking = $false
$script:voiceProcess = $null
$script:voicePlayer = $null
$script:voiceEndsAt = [DateTime]::MinValue
$script:voiceRequest = Join-Path $runtime 'kitty-voice-request.json'
$script:voiceOutput = Join-Path $runtime 'kitty-voice-output.wav'
$script:voiceResult = Join-Path $runtime 'kitty-voice-result.json'
$script:voiceRenderer = Join-Path $PSScriptRoot 'Mr-Kitty-Voice.py'
$script:voicePython = if ($env:MR_KITTY_VOICE_PYTHON) { $env:MR_KITTY_VOICE_PYTHON } else {
    Join-Path $PSScriptRoot 'voice/venv/Scripts/python.exe'
}
$script:voiceModel = if ($env:MR_KITTY_VOICE_MODEL_DIR) { $env:MR_KITTY_VOICE_MODEL_DIR } else {
    Join-Path $PSScriptRoot 'voice/model'
}
$script:speechRecognizedId = 'MrKittySpeechRecognized'
$script:speechCompletedId = 'MrKittySpeechCompleted'

function Set-KittyProvider([string]$provider) {
    if ($script:chatBusy -or $provider -notin @('codex', 'claude')) { return }
    Stop-KittySpeaking
    $script:chatProvider = $provider
    $codexButton.Background = if ($provider -eq 'codex') {
        $script:codexBrush
    } else { $script:inactiveBrush }
    $claudeButton.Background = if ($provider -eq 'claude') {
        $script:claudeBrush
    } else { $script:inactiveBrush }
    $name = if ($provider -eq 'codex') { 'Codex' } else { 'Claude' }
    $chatHeader.Text = "Message Kitty - $name"
    $chatAnswerView.Text = "Kitty will reply from $name."
    $script:hasSpeakableReply = $false
    $chatStatus.Text = "$name selected - type or speak to Kitty"
}

function Show-KittyComposer {
    Update-KittyDock
    if (-not $composer.IsVisible) { $composer.Show() }
    $composer.Activate() | Out-Null
    $chatText.Focus() | Out-Null
}
function Clear-KittySpeech {
    foreach ($id in @($script:speechRecognizedId, $script:speechCompletedId)) {
        Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue
        Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue |
            Remove-Event -ErrorAction SilentlyContinue
    }
    if ($script:speechEngine) {
        try { $script:speechEngine.Dispose() } catch {}
        $script:speechEngine = $null
    }
    $script:speechState = 'idle'
    $voiceButton.Background = [Windows.Media.Brushes]::Transparent
}
function Stop-KittyListening {
    if ($script:speechState -ne 'listening') { return }
    $script:speechState = 'stopping'
    $chatStatus.Text = 'Finishing voice input...'
    try { $script:speechEngine.RecognizeAsyncStop() }
    catch { Clear-KittySpeech; $chatStatus.Text = 'Voice input stopped.' }
}
function Stop-KittySpeaking {
    if ($script:voiceProcess -and -not $script:voiceProcess.HasExited) {
        try { Stop-Process -Id $script:voiceProcess.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    $script:voiceProcess = $null
    if ($script:voicePlayer) {
        try { $script:voicePlayer.Stop(); $script:voicePlayer.Dispose() } catch {}
        $script:voicePlayer = $null
    }
    $script:isSpeaking = $false
    $script:voiceEndsAt = [DateTime]::MinValue
    $hearButton.Content = 'Hear'
}
function Speak-KittyAnswer([string]$words) {
    if (-not $words.Trim()) { return }
    try {
        Stop-KittySpeaking
        if (-not (Test-Path -LiteralPath $script:voicePython) -or
            -not (Test-Path -LiteralPath $script:voiceRenderer) -or
            -not (Test-Path -LiteralPath (Join-Path $script:voiceModel 'kokoro-v1.0.int8.onnx')) -or
            -not (Test-Path -LiteralPath (Join-Path $script:voiceModel 'voices-v1.0.bin'))) {
            $chatStatus.Text = 'Kitty voice needs Setup-Mr-Kitty-Voice.cmd once.'
            return
        }
        Remove-Item -LiteralPath $script:voiceOutput, $script:voiceResult -Force -ErrorAction SilentlyContinue
        $requestJson = @{text=$words;voice='am_puck'} | ConvertTo-Json -Compress
        [IO.File]::WriteAllText($script:voiceRequest, $requestJson, [Text.UTF8Encoding]::new($false))
        $voiceArgs = @('"' + $script:voiceRenderer + '"',
            '"' + $script:voiceRequest + '"', '"' + $script:voiceOutput + '"',
            '"' + $script:voiceResult + '"', '"' + $script:voiceModel + '"')
        $script:voiceProcess = Start-Process -FilePath $script:voicePython -ArgumentList $voiceArgs -WindowStyle Hidden -PassThru
        $script:isSpeaking = $true
        $hearButton.Content = 'Stop'
        $chatStatus.Text = 'Kitty is finding his voice...'
    } catch {
        $chatStatus.Text = "Kitty cannot speak: $($_.Exception.Message)"
        Stop-KittySpeaking
    }
}
function Update-KittySpeaking {
    if (-not $script:isSpeaking) { return }
    if ($script:voiceProcess) {
        if (-not $script:voiceProcess.HasExited) { return }
        $script:voiceProcess = $null
        if (-not (Test-Path -LiteralPath $script:voiceResult)) {
            $chatStatus.Text = 'Kitty voice did not finish.'
            Stop-KittySpeaking
            return
        }
        $result = Get-Content -LiteralPath $script:voiceResult -Raw | ConvertFrom-Json
        if (-not $result.ok -or -not (Test-Path -LiteralPath $script:voiceOutput) -or
            (Get-Item -LiteralPath $script:voiceOutput).Length -lt 1000) {
            $chatStatus.Text = "Kitty voice failed: $($result.error)"
            Stop-KittySpeaking
            return
        }
        try {
            $script:voicePlayer = [System.Media.SoundPlayer]::new($script:voiceOutput)
            $script:voicePlayer.Load()
            $script:voicePlayer.Play()
            $script:voiceEndsAt = [DateTime]::UtcNow.AddSeconds([double]$result.seconds + 0.3)
            $chatStatus.Text = 'Kitty is speaking - press Stop to silence him.'
        } catch {
            $chatStatus.Text = "Kitty cannot play audio: $($_.Exception.Message)"
            Stop-KittySpeaking
        }
        return
    }
    if ([DateTime]::UtcNow -ge $script:voiceEndsAt) { Stop-KittySpeaking }
}
function Read-KittyInbox {
    foreach ($file in @(Get-ChildItem -LiteralPath $script:speechInbox -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object Name | Select-Object -First 20)) {
        try {
            $speechRecord = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            Remove-Item -LiteralPath $file.FullName -Force
            if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [double]$speechRecord.at -gt 120) { continue }
            if ($speechRecord.source -notin @('codex', 'claude')) { continue }
            $words = [string]$speechRecord.text
            if ($words.Trim()) { $script:desktopReplies[$speechRecord.source] = $words }
        } catch {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
function Start-KittyListening {
    if ($script:speechState -eq 'listening') { Stop-KittyListening; return }
    if ($script:speechState -eq 'stopping') { return }
    Stop-KittySpeaking
    Show-KittyComposer
    try {
        Add-Type -AssemblyName System.Speech
        if ([System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers().Count -eq 0) {
            $chatStatus.Text = 'No Windows speech recognizer is installed.'
            return
        }
        $script:speechEngine = [System.Speech.Recognition.SpeechRecognitionEngine]::new()
        $script:speechEngine.LoadGrammar([System.Speech.Recognition.DictationGrammar]::new())
        $script:speechEngine.SetInputToDefaultAudioDevice()
        Register-ObjectEvent -InputObject $script:speechEngine -EventName SpeechRecognized -SourceIdentifier $script:speechRecognizedId | Out-Null
        Register-ObjectEvent -InputObject $script:speechEngine -EventName RecognizeCompleted -SourceIdentifier $script:speechCompletedId | Out-Null
        $script:speechEngine.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
        $script:speechState = 'listening'
        $script:voiceTurn = $true
        $voiceButton.Background = $script:listeningBrush
        $chatStatus.Text = 'Listening... speak now'
    } catch {
        $reason = $_.Exception.Message
        $script:voiceTurn = $false
        Clear-KittySpeech
        $chatStatus.Text = "Kitty microphone unavailable: $reason"
    }
}
function Read-KittySpeech {
    foreach ($eventRecord in @(Get-Event -SourceIdentifier $script:speechRecognizedId -ErrorAction SilentlyContinue)) {
        $words = [string]$eventRecord.SourceEventArgs.Result.Text
        if ($words) {
            $prefix = if ($chatText.Text.Trim()) { ' ' } else { '' }
            $chatText.AppendText($prefix + $words)
            $chatText.CaretIndex = $chatText.Text.Length
            $chatText.ScrollToEnd()
            $chatStatus.Text = 'Sending what you said...'
            if ($script:voiceTurn -and $script:speechState -eq 'listening') {
                $script:sendAfterSpeech = $true
                Stop-KittyListening
            }
        }
        Remove-Event -EventIdentifier $eventRecord.EventIdentifier
    }
    foreach ($eventRecord in @(Get-Event -SourceIdentifier $script:speechCompletedId -ErrorAction SilentlyContinue)) {
        $errorMessage = if ($eventRecord.SourceEventArgs.Error) {
            $eventRecord.SourceEventArgs.Error.Message
        } else { '' }
        Remove-Event -EventIdentifier $eventRecord.EventIdentifier
        $sendAfter = $script:sendAfterSpeech
        $script:sendAfterSpeech = $false
        Clear-KittySpeech
        $chatStatus.Text = if ($errorMessage) {
            "Voice stopped: $errorMessage"
        } else { 'Voice stopped - review text, then Send' }
        if ($sendAfter -and -not $errorMessage) { Send-KittyMessage }
    }
}
function Send-KittyMessage {
    if ($script:chatBusy) { return }
    if ($script:speechState -ne 'idle') {
        $script:sendAfterSpeech = $true
        Stop-KittyListening
        return
    }
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
    $script:voiceTurn = $false
    $sendButton.IsEnabled = $false
    $codexButton.IsEnabled = $false
    $claudeButton.IsEnabled = $false
    $chatAnswerView.Text = ''
    $script:hasSpeakableReply = $false
    $chatStatus.Text = 'Kitty is thinking...'
}
$writeButton.Add_Click({
    if ($composer.IsVisible) {
        $script:voiceTurn = $false
        Stop-KittyListening
        $composer.Hide()
    }
    else { Show-KittyComposer }
})
$voiceButton.Add_Click({
    if ($script:speechState -eq 'listening') {
        $script:voiceTurn = $false
        Stop-KittyListening
    } else { Start-KittyListening }
})
$codexButton.Add_Click({ Set-KittyProvider 'codex' })
$claudeButton.Add_Click({ Set-KittyProvider 'claude' })
$sendButton.Add_Click({ Send-KittyMessage })
$hearButton.Add_Click({
    if ($script:isSpeaking) { Stop-KittySpeaking }
    elseif ($script:hasSpeakableReply) { Speak-KittyAnswer $chatAnswerView.Text }
    else { $chatStatus.Text = 'Choose a reply before pressing Hear.' }
})
$desktopButton.Add_Click({
    $menu = [Windows.Controls.ContextMenu]::new()
    foreach ($source in @('codex', 'claude')) {
        $item = [Windows.Controls.MenuItem]::new()
        $item.Header = if ($source -eq 'codex') { 'Latest Codex Desktop reply' } else { 'Latest Claude Code reply' }
        $item.Tag = $source
        $item.IsEnabled = $script:desktopReplies.ContainsKey($source)
        $item.Add_Click({
            param($sender, $event)
            Stop-KittySpeaking
            $key = [string]$sender.Tag
            $chatAnswerView.Text = [string]$script:desktopReplies[$key]
            $script:hasSpeakableReply = $true
            $chatStatus.Text = 'Desktop reply selected - press Hear to play it.'
        })
        $null = $menu.Items.Add($item)
    }
    $desktopButton.ContextMenu = $menu
    $menu.PlacementTarget = $desktopButton
    $menu.IsOpen = $true
})
$closeButton.Add_Click({
    $script:voiceTurn = $false
    Stop-KittyListening
    Stop-KittySpeaking
    $composer.Hide()
})
$composer.Add_PreviewKeyDown({
    param($sender, $event)
    if ($event.Key -eq [Windows.Input.Key]::Escape) {
        $event.Handled = $true
        $script:voiceTurn = $false
        Stop-KittyListening
        Stop-KittySpeaking
        $composer.Hide()
    }
})
$chatText.Add_PreviewKeyDown({
    param($sender, $event)
    if ($event.Key -eq [Windows.Input.Key]::Enter -and
        -not ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift)) {
        $event.Handled = $true
        Send-KittyMessage
    }
})
$composer.Add_Closing({
    param($sender, $event)
    $event.Cancel = $true
    $script:voiceTurn = $false
    Stop-KittyListening
    Stop-KittySpeaking
    $composer.Hide()
})
Set-KittyProvider 'codex'

function Update-KittyDock {
    $bounds = Get-KittyBounds
    if ($bounds) { $script:lastBounds = $bounds }
    if (-not $bounds -and -not $script:mode) {
        $dock.Hide()
        $script:voiceTurn = $false
        Stop-KittyListening
        Stop-KittySpeaking
        $composer.Hide()
        return
    }
    if (-not $script:lastBounds) { return }
    $b = $script:lastBounds
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new([int]$b[0], [int]$b[1])).WorkingArea
    $placement = Get-KittyPlacement $b $screen
    $dock.Left = $placement.DockLeft
    $dock.Top = $placement.DockTop
    $composer.Left = $placement.ComposerLeft
    $composer.Top = $placement.ComposerTop
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
            Read-KittySpeech
            Read-KittyInbox
            Update-KittySpeaking
            if ($script:chatBusy -and (Test-Path -LiteralPath $script:chatResult)) {
                $reply = Get-Content -LiteralPath $script:chatResult -Raw | ConvertFrom-Json
                $script:chatBusy = $false
                $sendButton.IsEnabled = $true
                $codexButton.IsEnabled = $true
                $claudeButton.IsEnabled = $true
                if ($reply.ok) {
                    $chatAnswerView.Text = [string]$reply.answer
                    $script:hasSpeakableReply = $true
                    $chatText.Clear()
                    $name = if ($reply.provider -eq 'claude') { 'Claude' } else { 'Codex' }
                    $chatStatus.Text = "$name replied - type another message"
                } else {
                    $chatAnswerView.Text = [string]$reply.error
                    $script:hasSpeakableReply = $false
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
$manualSpeechItem = $trayMenu.Items.Add('Speech: Hear button only')
$manualSpeechItem.Enabled = $false
$null = $trayMenu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
$exitItem = $trayMenu.Items.Add('Exit Kitty gestures')
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = 'Mr. Kitty: Alt-click or Ctrl-click for a trick and treat'
$tray.ContextMenuStrip = $trayMenu
$tray.Visible = $true
$dispatcher = [Windows.Threading.Dispatcher]::CurrentDispatcher
$exitItem.Add_Click({ $dispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Normal) })
$script:desktopSpeechProcess = $null
$desktopSpeechWatcher = Join-Path $PSScriptRoot 'Mr-Kitty-Desktop-Speech-Watcher.py'
$desktopSpeechPython = $env:MR_KITTY_PYTHONW
if (-not $desktopSpeechPython) {
    $pythonwCommand = Get-Command 'pythonw.exe' -ErrorAction SilentlyContinue
    if ($pythonwCommand) { $desktopSpeechPython = $pythonwCommand.Source }
}
if (-not $desktopSpeechPython) { $desktopSpeechPython = $env:MR_KITTY_PYTHON }
if (-not $RuntimeSmokeTest -and $desktopSpeechPython -and
    (Test-Path -LiteralPath $desktopSpeechPython) -and
    (Test-Path -LiteralPath $desktopSpeechWatcher)) {
    try {
        $script:desktopSpeechProcess = Start-Process -FilePath $desktopSpeechPython -ArgumentList @(
            '"' + $desktopSpeechWatcher + '"', [string]$PID
        ) -WindowStyle Hidden -PassThru
    } catch {
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $runtime 'speech-watcher-start-error.txt')
    }
}

try {
    $timer.Start()
    if ($RuntimeSmokeTest) {
        $runtimeTestTimer = [Windows.Threading.DispatcherTimer]::new()
        $runtimeTestTimer.Interval = [TimeSpan]::FromMilliseconds(500)
        $runtimeTestTimer.Add_Tick({
            $runtimeTestTimer.Stop()
            $dispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Normal)
        })
        $runtimeTestTimer.Start()
    }
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
    if ($script:speechState -eq 'listening') { Stop-KittyListening }
    Clear-KittySpeech
    Stop-KittySpeaking
    Remove-Item -LiteralPath $script:captureEnabledFlag -Force -ErrorAction SilentlyContinue
    if ($script:desktopSpeechProcess -and -not $script:desktopSpeechProcess.HasExited) {
        Stop-Process -Id $script:desktopSpeechProcess.Id -ErrorAction SilentlyContinue
    }
    Restore-Kitty
    $dock.Close()
    $composer.Close()
    $tray.Visible = $false
    $tray.Dispose()
    $trayMenu.Dispose()
    if ($mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}
