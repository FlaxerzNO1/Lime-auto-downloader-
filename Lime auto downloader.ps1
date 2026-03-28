Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@

function Build-RoundedPath([int]$w, [int]$h, [int]$radius) {
    if ($w -le 0 -or $h -le 0) { return $null }
    $cr = [Math]::Min($radius, [Math]::Min($w, $h) / 2)
    $segments = 8
    $angleStep = ([Math]::PI / 2) / $segments
    $corners = @(
        @{ cx = $w - $cr; cy = $cr;      startAngle = -[Math]::PI / 2 },
        @{ cx = $w - $cr; cy = $h - $cr; startAngle = 0 },
        @{ cx = $cr;      cy = $h - $cr; startAngle = [Math]::PI / 2 },
        @{ cx = $cr;      cy = $cr;      startAngle = [Math]::PI }
    )
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($corner in $corners) {
        for ($i = 0; $i -le $segments; $i++) {
            $angle = $corner.startAngle + $i * $angleStep
            $pts.Add([System.Drawing.PointF]::new(
                [float]($corner.cx + $cr * [Math]::Cos($angle)),
                [float]($corner.cy + $cr * [Math]::Sin($angle))
            ))
        }
    }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.StartFigure()
    $path.AddLines($pts.ToArray())
    $path.CloseFigure()
    return $path
}

function Set-Rounded {
    param(
        [System.Windows.Forms.Control]$Control,
        [int]$Radius,
        [System.Drawing.Color]$BorderColor = [System.Drawing.Color]::Empty,
        [float]$BorderWidth = 1.5
    )
    if ($null -eq $Control) { return }

    $safeBorderColor = if ($null -eq $BorderColor -or $BorderColor.IsEmpty) {
        [System.Drawing.Color]::Empty
    } else {
        $BorderColor
    }

    # Closure için değerleri yerel değişkenlere ata
    $localRadius = $Radius
    $localBorderColor = $safeBorderColor
    $localBorderWidth = $BorderWidth
    $buildPath = ${function:Build-RoundedPath}

    $path = Build-RoundedPath $Control.Width $Control.Height $Radius
    if ($null -ne $path) {
        $Control.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    }

    $Control.Add_SizeChanged({
        $path = & $buildPath $this.Width $this.Height $localRadius
        if ($null -eq $path) { return }
        $old = $this.Region
        $this.Region = New-Object System.Drawing.Region($path)
        if ($null -ne $old) { $old.Dispose() }
        $path.Dispose()
    }.GetNewClosure())

    if (-not $safeBorderColor.IsEmpty) {
        $Control.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            
            # BorderColor boş ise çizim yapma
            if ($null -eq $localBorderColor -or $localBorderColor.IsEmpty) { return }
            
            $path = & $buildPath $s.Width $s.Height $localRadius
            if ($null -eq $path) { return }
            $pen = $null
            try {
                $pen = New-Object System.Drawing.Pen($localBorderColor, $localBorderWidth)
                $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
                $g.DrawPath($pen, $path)
            } finally {
                if ($null -ne $pen)  { $pen.Dispose() }
                if ($null -ne $path) { $path.Dispose() }
            }
        }.GetNewClosure())
    }

    $Control.Add_Disposed({
        if ($null -ne $this.Region) { $this.Region.Dispose() }
    })
}

$clr = @{
    BgDark     = [System.Drawing.Color]::FromArgb(26,  26,  10)
    BgPanel    = [System.Drawing.Color]::FromArgb(37,  37,  16)
    BgHeader   = [System.Drawing.Color]::FromArgb(42,  42,  15)
    BgCard     = [System.Drawing.Color]::FromArgb(37,  37,  16)
    Mango      = [System.Drawing.Color]::FromArgb(255, 247, 31)
    MangoLite  = [System.Drawing.Color]::FromArgb(255, 204, 0)
    MangoDark  = [System.Drawing.Color]::FromArgb(220, 176, 0)
    MangoGlow  = [System.Drawing.Color]::FromArgb(60,  255, 247, 31)
    LeafGreen  = [System.Drawing.Color]::FromArgb(153, 204, 51)
    LeafDark   = [System.Drawing.Color]::FromArgb(116, 155, 40)
    LeafGlow   = [System.Drawing.Color]::FromArgb(50,  116, 155, 40)
    TextMain   = [System.Drawing.Color]::FromArgb(255, 255, 255)
    TextDim    = [System.Drawing.Color]::FromArgb(116, 155, 40)
    Border     = [System.Drawing.Color]::FromArgb(255, 247, 31)
    BorderDim  = [System.Drawing.Color]::FromArgb(80,  116, 155, 40)
    RunGreen   = [System.Drawing.Color]::FromArgb(31,  58,  5)
    Dark       = [System.Drawing.Color]::FromArgb(51,  51,  51)
}

$tr = @{
    Iptal        = ([char]0x0130) + "ptal"
    IptalEdildi  = ([char]0x0130) + "ptal edildi."
    Baslatiliyor = "Ba" + ([char]0x015F) + "lat" + ([char]0x0131) + "l" + ([char]0x0131) + "yor..."
    Tamamlandi   = "Tamamland" + ([char]0x0131) + "!"
    Hata         = "Hata"
    Indiriliyor  = ([char]0x0130) + "ndiriliyor"
}

function Invoke-ScriptInWindow {
    param([string]$Url)
    $cmd = "`$host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(95,25); " +
           "`$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(95,200); " +
           "iex (irm '$Url')"
    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $cmd -Verb RunAs
}

function Show-ScriptSelector {
    param([array]$Scripts)

    $sForm = New-Object System.Windows.Forms.Form
    $sForm.Size = New-Object System.Drawing.Size(500, 474)
    $sForm.StartPosition = "CenterScreen"
    $sForm.FormBorderStyle = "None"
    $sForm.BackColor = $clr.BgDark
    $sForm.TopMost = $false

    $sHeader = New-Object System.Windows.Forms.Panel
    $sHeader.Dock = "Top"
    $sHeader.Height = 44
    $sHeader.BackColor = $clr.BgHeader
    $sForm.Controls.Add($sHeader)

    $dragHandler = {
        [Win32]::ReleaseCapture() | Out-Null
        [Win32]::SendMessage($sForm.Handle, 0xA1, 0x2, 0)
    }
    $sHeader.Add_MouseDown($dragHandler)

    $sTitle = New-Object System.Windows.Forms.Label
    $sTitle.Text = "Script Se" + ([char]0x00E7) + "im"
    $sTitle.Location = New-Object System.Drawing.Point(16, 0)
    $sTitle.Size = New-Object System.Drawing.Size(300, 44)
    $sTitle.Font = New-Object System.Drawing.Font("Segoe UI Black", 12)
    $sTitle.ForeColor = $clr.Mango
    $sTitle.TextAlign = "MiddleLeft"
    $sTitle.BackColor = [System.Drawing.Color]::Transparent
    $sTitle.Add_MouseDown($dragHandler)
    $sHeader.Controls.Add($sTitle)

    $sCloseBtn = New-Object System.Windows.Forms.Panel
    $sCloseBtn.Size = New-Object System.Drawing.Size(44, 30)
    $sCloseBtn.Cursor = "Hand"
    $sCloseBtn.BackColor = $clr.BgPanel
    $sCloseBtn.Tag = $false

    $sCloseLbl = New-Object System.Windows.Forms.Label
    $sCloseLbl.Text = "x"
    $sCloseLbl.Dock = "Fill"
    $sCloseLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 12)
    $sCloseLbl.ForeColor = $clr.Mango
    $sCloseLbl.TextAlign = "MiddleCenter"
    $sCloseLbl.BackColor = [System.Drawing.Color]::Transparent
    $sCloseBtn.Controls.Add($sCloseLbl)

    $sCloseBtn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.SolidBrush($clr.MangoLite)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $overlayBrush = New-Object System.Drawing.SolidBrush($clr.MangoGlow)
            $g.FillRectangle($overlayBrush, $s.ClientRectangle)
            $overlayBrush.Dispose()
            $pen = New-Object System.Drawing.Pen($clr.Border, 2)
            $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush($clr.BgPanel)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })
    $sCloseBtn.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate(); foreach($c in $this.Controls){ $c.ForeColor = $clr.Dark; $c.BackColor = [System.Drawing.Color]::Transparent } })
    $sCloseBtn.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate(); foreach($c in $this.Controls){ $c.ForeColor = $clr.Mango; $c.BackColor = [System.Drawing.Color]::Transparent } })
    $sCloseLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.ForeColor = $clr.Dark; $this.BackColor = [System.Drawing.Color]::Transparent })
    $sCloseLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.ForeColor = $clr.Mango; $this.BackColor = [System.Drawing.Color]::Transparent })
    $sCloseBtn.Add_Click({ $sForm.Close() })
    $sCloseLbl.Add_Click({ $sForm.Close() })
    $sHeader.Controls.Add($sCloseBtn)

    $yazarlar = @()
    foreach ($scr in $Scripts) {
        $y = if ($scr.Yazar) { $scr.Yazar } else { "Anonim" }
        if ($yazarlar -notcontains $y) { $yazarlar += $y }
    }
    $script:activeTabYazar = if ($yazarlar.Count -gt 0) { $yazarlar[0] } else { "Anonim" }

    $tabBarContainer = New-Object System.Windows.Forms.Panel
    $tabBarContainer.Location = New-Object System.Drawing.Point(16, 44)
    $tabBarContainer.Size = New-Object System.Drawing.Size(468, 44)
    $tabBarContainer.BackColor = $clr.BgDark
    $sForm.Controls.Add($tabBarContainer)

    $tabBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $tabBar.Dock = "Fill"
    $tabBar.BackColor = $clr.BgDark
    $tabBar.WrapContents = $false
    $tabBar.AutoScroll = $true
    $tabBarContainer.Controls.Add($tabBar)
    
    $tabBarContainer.Add_MouseDown($dragHandler)
    $tabBar.Add_MouseDown($dragHandler)

    $tabButtons = @()
    $sGraphics = $sForm.CreateGraphics()
    foreach ($yazar in $yazarlar) {
        $tBtn = New-Object System.Windows.Forms.Panel
        $tBtn.Height = 44
        $tBtn.Cursor = "Hand"
        $tBtn.Tag = @{ Yazar = $yazar; Hovered = $false }
        
        $tLbl = New-Object System.Windows.Forms.Label
        $tLbl.Text = $yazar
        $tLbl.AutoSize = $true
        $tLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 10)
        $tLbl.ForeColor = $clr.Dark
        $tLbl.BackColor = [System.Drawing.Color]::Transparent
        $tBtn.Controls.Add($tLbl)
        
        $sz = $sGraphics.MeasureString($yazar, $tLbl.Font)
        $tBtn.Width = [int]$sz.Width + 30
        $tBtn.Height = 36
        $tLbl.Location = New-Object System.Drawing.Point(15, ([int](36 - $sz.Height)/2))
        $tBtn.Margin = New-Object System.Windows.Forms.Padding(0, 4, 8, 4)
        
        $tBtn.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $isAktif = ($script:activeTabYazar -eq $s.Tag.Yazar)
            
            $clrFill = if ($s.Tag.Hovered -or $isAktif) { $clr.MangoLite } else { $clr.Mango }
            $brush = New-Object System.Drawing.SolidBrush($clrFill)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            
            if ($s.Tag.Hovered -or $isAktif) {
                $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
                $g.FillRectangle($overlayBrush, $s.ClientRectangle)
                $overlayBrush.Dispose()
            }
            
            $pen = New-Object System.Drawing.Pen($clr.Border, 2)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
            
            if ($isAktif) {
                $lineBrush = New-Object System.Drawing.SolidBrush($clr.Mango)
                $g.FillRectangle($lineBrush, 0, $s.Height - 3, $s.Width, 3)
                $lineBrush.Dispose()
                $s.Controls[0].ForeColor = $clr.Dark
            } else {
                $s.Controls[0].ForeColor = if ($s.Tag.Hovered) { $clr.Dark } else { $clr.Dark }
            }
        })
        
        $tBtn.Add_MouseEnter({ $this.Tag.Hovered = $true; $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })
        $tBtn.Add_MouseLeave({ $this.Tag.Hovered = $false; $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })
        $tLbl.Add_MouseEnter({ $this.Parent.Tag.Hovered = $true; $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
        $tLbl.Add_MouseLeave({ $this.Parent.Tag.Hovered = $false; $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
        
        $tabClick = {
            $p = if ($this -is [System.Windows.Forms.Panel]) { $this } else { $this.Parent }
            if ($script:activeTabYazar -ne $p.Tag.Yazar) {
                $script:activeTabYazar = $p.Tag.Yazar
                foreach ($tb in $tabButtons) { $tb.Invalidate() }
                & $loadScriptsForTab
            }
        }
        $tBtn.Add_Click($tabClick)
        $tLbl.Add_Click($tabClick)
        
        $tabBar.Controls.Add($tBtn)
        Set-Rounded $tBtn 6
        $tabButtons += $tBtn
    }
    $sGraphics.Dispose()

    $tabSeparator = New-Object System.Windows.Forms.Panel
    $tabSeparator.Location = New-Object System.Drawing.Point(16, 88)
    $tabSeparator.Size = New-Object System.Drawing.Size(468, 1)
    $tabSeparator.BackColor = $clr.Border
    $sForm.Controls.Add($tabSeparator)

    $contentArea = New-Object System.Windows.Forms.Panel
    $contentArea.Location = New-Object System.Drawing.Point(0, 89)
    $contentArea.Size = New-Object System.Drawing.Size(500, 289)
    $contentArea.BackColor = $clr.BgDark
    $sForm.Controls.Add($contentArea)

    $scrollTrack = New-Object System.Windows.Forms.Panel
    $scrollTrack.Size = New-Object System.Drawing.Size(6, 270)
    $scrollTrack.Location = New-Object System.Drawing.Point(482, 10)
    $scrollTrack.BackColor = $clr.BgPanel
    $contentArea.Controls.Add($scrollTrack)

    $scrollThumb = New-Object System.Windows.Forms.Panel
    $scrollThumb.Size = New-Object System.Drawing.Size(6, 60)
    $scrollThumb.Location = New-Object System.Drawing.Point(0, 0)
    $scrollThumb.BackColor = $clr.Mango
    $scrollThumb.Cursor = "Hand"
    $scrollTrack.Controls.Add($scrollThumb)

    $scrollThumb.Add_Paint({
        param($s, $e)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $s.ClientRectangle,
            $clr.Mango,
            $clr.MangoLite,
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
        )
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.FillRectangle($brush, $s.ClientRectangle)
        $brush.Dispose()
    })

    Set-Rounded $scrollTrack 3
    Set-Rounded $scrollThumb 3

    $itemsPanel = New-Object System.Windows.Forms.Panel
    $itemsPanel.Location = New-Object System.Drawing.Point(16, 8)
    $itemsPanel.Size = New-Object System.Drawing.Size(456, 274)
    $itemsPanel.BackColor = $clr.BgDark
    $contentArea.Controls.Add($itemsPanel)

    $script:checkboxes = @()
    $itemHeight = 44
    $script:totalHeight = 0
    $script:scrollOffset = 0
    $visibleHeight = 274

    $updateScroll = {
        $maxScroll = [Math]::Max(0, $script:totalHeight - $visibleHeight)
        if ($maxScroll -eq 0) {
            $scrollThumb.Visible = $false
            foreach ($cb in $script:checkboxes) {
                $cb.Top = $cb.Tag.OriginalY
                $cb.Visible = $true
            }
            return
        }
        $scrollThumb.Visible = $true
        $thumbRatio = $visibleHeight / $script:totalHeight
        $thumbH = [Math]::Max(20, [int]($scrollTrack.Height * $thumbRatio))
        $scrollThumb.Height = $thumbH
        $thumbY = [int](($script:scrollOffset / $maxScroll) * ($scrollTrack.Height - $thumbH))
        $scrollThumb.Top = [Math]::Max(0, [Math]::Min($thumbY, $scrollTrack.Height - $thumbH))
        $scrollThumb.Invalidate()

        foreach ($cb in $script:checkboxes) {
            $cb.Top = $cb.Tag.OriginalY - $script:scrollOffset
            $visible = ($cb.Top + $cb.Height -gt 0) -and ($cb.Top -lt $visibleHeight)
            $cb.Visible = $visible
        }
    }

    $wheelHandler = {
        param($sender, $e)
        $maxS = [Math]::Max(0, $script:totalHeight - $visibleHeight)
        if ($maxS -eq 0) { return }
        $delta = if ($e.Delta -gt 0) { -40 } else { 40 }
        $script:scrollOffset = [Math]::Max(0, [Math]::Min($script:scrollOffset + $delta, $maxS))
        & $updateScroll
    }

    $contentArea.Add_MouseWheel($wheelHandler)
    $itemsPanel.Add_MouseWheel($wheelHandler)

    $loadScriptsForTab = {
        $itemsPanel.SuspendLayout()
        foreach ($cb in $script:checkboxes) {
            $cb.Dispose()
        }
        $itemsPanel.Controls.Clear()
        $script:checkboxes = @()
        $script:scrollOffset = 0

        $filteredScripts = @()
        foreach ($scr in $Scripts) {
            $y = if ($scr.Yazar) { $scr.Yazar } else { "Anonim" }
            if ($y -eq $script:activeTabYazar) {
                $filteredScripts += $scr
            }
        }

        $script:totalHeight = $filteredScripts.Count * $itemHeight

        $yPos = 0
        foreach ($scr in $filteredScripts) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Size = New-Object System.Drawing.Size(446, 36)
        $row.Location = New-Object System.Drawing.Point(0, $yPos)
        $row.BackColor = $clr.Mango
        $row.Tag = @{ Checked = $true; Script = $scr; OriginalY = $yPos }
        $row.Cursor = "Hand"

        $row.Add_MouseWheel($wheelHandler)

        $row.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            if ($s.Tag.Checked) {
                $brush = New-Object System.Drawing.SolidBrush($clr.MangoLite)
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
                $pen = New-Object System.Drawing.Pen($clr.Border, 2)
                $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
                $pen.Dispose()
            } else {
                $brush = New-Object System.Drawing.SolidBrush($clr.Mango)
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
                $pen = New-Object System.Drawing.Pen($clr.BorderDim, 1.5)
                $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
                $pen.Dispose()
            }
            $cbX = 12; $cbY = 10; $cbSize = 16
            $cbRect = [System.Drawing.Rectangle]::new($cbX, $cbY, $cbSize, $cbSize)
            if ($s.Tag.Checked) {
                $cbBrush = New-Object System.Drawing.SolidBrush($clr.BgDark)
                $g.FillRectangle($cbBrush, $cbRect)
                $cbBrush.Dispose()
                $cbPen = New-Object System.Drawing.Pen($clr.Border, 2)
                $g.DrawRectangle($cbPen, $cbRect)
                $cbPen.Dispose()
                $tickPen = New-Object System.Drawing.Pen($clr.Mango, 2)
                $tickPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                $tickPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
                $g.DrawLine($tickPen, $cbX+3, $cbY+8, $cbX+6, $cbY+11)
                $g.DrawLine($tickPen, $cbX+6, $cbY+11, $cbX+13, $cbY+4)
                $tickPen.Dispose()
            } else {
                $cbPen = New-Object System.Drawing.Pen($clr.BorderDim, 1.5)
                $g.DrawRectangle($cbPen, $cbRect)
                $cbPen.Dispose()
            }
        })

        $nameLbl = New-Object System.Windows.Forms.Label
        $nameLbl.Text = $scr.Ad
        $nameLbl.Location = New-Object System.Drawing.Point(38, 0)
        $nameLbl.Size = New-Object System.Drawing.Size(310, 36)
        $nameLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
        $nameLbl.ForeColor = $clr.Dark
        $nameLbl.TextAlign = "MiddleLeft"
        $nameLbl.BackColor = [System.Drawing.Color]::Transparent
        $nameLbl.Add_MouseWheel($wheelHandler)
        $row.Controls.Add($nameLbl)

        $runBtn = New-Object System.Windows.Forms.Panel
        $runBtn.Size = New-Object System.Drawing.Size(80, 22)
        $runBtn.Location = New-Object System.Drawing.Point(358, 7)
        $runBtn.Cursor = "Hand"
        $runBtn.BackColor = $clr.RunGreen
        $runBtn.Tag = @{ Hovered = $false; Url = $scr.Url }

        $runLbl = New-Object System.Windows.Forms.Label
        $runLbl.Text = "Calistir"
        $runLbl.Dock = "Fill"
        $runLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 7.5)
        $runLbl.ForeColor = $clr.LeafGreen
        $runLbl.TextAlign = "MiddleCenter"
        $runLbl.BackColor = [System.Drawing.Color]::Transparent
        $runBtn.Controls.Add($runLbl)

        $runBtn.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            if ($s.Tag.Hovered) {
                $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                    $s.ClientRectangle,
                    $clr.LeafGreen,
                    $clr.LeafDark,
                    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
                )
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
                $overlayBrush = New-Object System.Drawing.SolidBrush($clr.LeafGlow)
                $g.FillRectangle($overlayBrush, $s.ClientRectangle)
                $overlayBrush.Dispose()
            } else {
                $brush = New-Object System.Drawing.SolidBrush($clr.RunGreen)
                $g.FillRectangle($brush, $s.ClientRectangle)
                $brush.Dispose()
            }
            $pen = New-Object System.Drawing.Pen($clr.BorderDim, 1.5)
            $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
            $pen.Dispose()
        })

        $runBtn.Add_MouseEnter({ $this.Tag.Hovered = $true;  $this.Invalidate() })
        $runBtn.Add_MouseLeave({ $this.Tag.Hovered = $false; $this.Invalidate() })
        $runLbl.Add_MouseEnter({ $this.Parent.Tag.Hovered = $true;  $this.Parent.Invalidate() })
        $runLbl.Add_MouseLeave({ $this.Parent.Tag.Hovered = $false; $this.Parent.Invalidate() })

        $runBtn.Add_Click({ Invoke-ScriptInWindow -Url $this.Tag.Url })
        $runLbl.Add_Click({ Invoke-ScriptInWindow -Url $this.Parent.Tag.Url })

        Set-Rounded $runBtn 6
        $row.Controls.Add($runBtn)

        $toggleAction = {
            $r = if ($this -is [System.Windows.Forms.Panel]) { $this } else { $this.Parent }
            $r.Tag.Checked = -not $r.Tag.Checked
            $r.Invalidate()
            $lbl = $r.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = if ($r.Tag.Checked) { $clr.Dark } else { $clr.TextDim }
        }
        $row.Add_Click($toggleAction)
        $nameLbl.Add_Click($toggleAction)

        Set-Rounded $row 8
        $itemsPanel.Controls.Add($row)
        $script:checkboxes += $row
        $yPos += $itemHeight
    }
        $itemsPanel.ResumeLayout()
        & $updateScroll
    }

    & $loadScriptsForTab

    $btnSelectAll = New-Object System.Windows.Forms.Panel
    $btnSelectAll.Size = New-Object System.Drawing.Size(130, 36)
    $btnSelectAll.Location = New-Object System.Drawing.Point(16, 390)
    $btnSelectAll.Cursor = "Hand"
    $btnSelectAll.BackColor = $clr.Mango
    $btnSelectAll.Tag = $false

    $btnSelectAllLbl = New-Object System.Windows.Forms.Label
    $btnSelectAllLbl.Text = "T" + ([char]0x00FC) + "m" + ([char]0x00FC) + "n" + ([char]0x00FC) + " Se" + ([char]0x00E7)
    $btnSelectAllLbl.Dock = "Fill"
    $btnSelectAllLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 9)
    $btnSelectAllLbl.ForeColor = $clr.Dark
    $btnSelectAllLbl.TextAlign = "MiddleCenter"
    $btnSelectAllLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnSelectAll.Controls.Add($btnSelectAllLbl)

    $btnClearAll = New-Object System.Windows.Forms.Panel
    $btnClearAll.Size = New-Object System.Drawing.Size(130, 36)
    $btnClearAll.Location = New-Object System.Drawing.Point(156, 390)
    $btnClearAll.Cursor = "Hand"
    $btnClearAll.BackColor = $clr.Mango
    $btnClearAll.Tag = $false

    $btnClearAllLbl = New-Object System.Windows.Forms.Label
    $btnClearAllLbl.Text = "T" + ([char]0x00FC) + "m" + ([char]0x00FC) + "n" + ([char]0x00FC) + " Kald" + ([char]0x0131) + "r"
    $btnClearAllLbl.Dock = "Fill"
    $btnClearAllLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 9)
    $btnClearAllLbl.ForeColor = $clr.Dark
    $btnClearAllLbl.TextAlign = "MiddleCenter"
    $btnClearAllLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnClearAll.Controls.Add($btnClearAllLbl)

    $btnRun = New-Object System.Windows.Forms.Panel
    $btnRun.Size = New-Object System.Drawing.Size(150, 36)
    $btnRun.Location = New-Object System.Drawing.Point(332, 390)
    $btnRun.Cursor = "Hand"
    $btnRun.BackColor = $clr.MangoLite
    $btnRun.Tag = $false

    $btnRunLbl = New-Object System.Windows.Forms.Label
    $btnRunLbl.Text = ([char]0x0130) + "ndir"
    $btnRunLbl.Dock = "Fill"
    $btnRunLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 9)
    $btnRunLbl.ForeColor = $clr.Dark
    $btnRunLbl.TextAlign = "MiddleCenter"
    $btnRunLbl.BackColor = [System.Drawing.Color]::Transparent
    $btnRun.Controls.Add($btnRunLbl)

    foreach ($sb in @($btnSelectAll, $btnClearAll)) {
        $sb.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $clrFill = if ($s.Tag) { $clr.MangoLite } else { $clr.Mango }
            $brush = New-Object System.Drawing.SolidBrush($clrFill)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            if ($s.Tag) {
                $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
                $g.FillRectangle($overlayBrush, $s.ClientRectangle)
                $overlayBrush.Dispose()
            }
            $pen = New-Object System.Drawing.Pen($clr.BorderDim, 1.5)
            $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
            $pen.Dispose()
        })
        $sb.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })
        $sb.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })
    }

    $btnRun.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $s.ClientRectangle,
                [System.Drawing.Color]::FromArgb(231, 186, 5),
                [System.Drawing.Color]::FromArgb(211, 162, 27),
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 255, 255, 255))
            $g.FillRectangle($overlayBrush, $s.ClientRectangle)
            $overlayBrush.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(196, 158, 11))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 231, 186, 5), 1.5)
        $g.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1)
        $pen.Dispose()
    })
    $btnRun.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })
    $btnRun.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate(); foreach($c in $this.Controls){ $c.BackColor = [System.Drawing.Color]::Transparent; $c.Invalidate() } })

    $selectAllAction = {
        foreach ($cb in $script:checkboxes) {
            $cb.Tag.Checked = $true
            $cb.Invalidate()
            $lbl = $cb.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = $clr.Dark
        }
    }
    $clearAllAction = {
        foreach ($cb in $script:checkboxes) {
            $cb.Tag.Checked = $false
            $cb.Invalidate()
            $lbl = $cb.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
            $lbl.ForeColor = $clr.TextDim
        }
    }
    $runAction = {
        $secilenler = @()
        foreach ($cb in $script:checkboxes) {
            if ($cb.Tag.Checked) { $secilenler += $cb.Tag.Script }
        }
        if ($secilenler.Count -eq 0) { return }
        $sForm.Close()
        $target = Join-Path $downloadsPath "ScreenShareTools\PSScripts"
        Invoke-TaskWithProgress -Title "PowerShell Scripts" -Items $secilenler -TargetPath $target -RunAfterDownload $false
    }

    $btnSelectAllLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
    $btnSelectAllLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
    $btnClearAllLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
    $btnClearAllLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
    $btnRunLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })
    $btnRunLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.BackColor = [System.Drawing.Color]::Transparent; $this.Invalidate() })

    $btnSelectAll.Add_Click($selectAllAction)
    $btnSelectAllLbl.Add_Click($selectAllAction)
    $btnClearAll.Add_Click($clearAllAction)
    $btnClearAllLbl.Add_Click($clearAllAction)
    $btnRun.Add_Click($runAction)
    $btnRunLbl.Add_Click($runAction)

    $sForm.Controls.Add($btnSelectAll)
    $sForm.Controls.Add($btnClearAll)
    $sForm.Controls.Add($btnRun)

    $sForm.Add_Shown({
        $sCloseBtn.Location = New-Object System.Drawing.Point(($sForm.ClientSize.Width - 52), 7)
        Set-Rounded $sForm 16 $clr.Border 2.5
        Set-Rounded $btnSelectAll 8
        Set-Rounded $btnClearAll 8
        Set-Rounded $btnRun 8
        Set-Rounded $sCloseBtn 10
    })

    $sForm.ShowDialog() | Out-Null
}

function Invoke-TaskWithProgress {
    param(
        [string]$Title,
        [array]$Items,
        [string]$TargetPath,
        [bool]$RunAfterDownload = $false
    )

    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null

    $syncHash = [hashtable]::Synchronized(@{
        Cancel      = $false
        Current     = $tr.Baslatiliyor
        Index       = 0
        Total       = $Items.Count
        Done        = $false
        Error       = ""
        TargetPath  = $TargetPath
    })

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions  = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $runspace.SessionStateProxy.SetVariable("Items", $Items)
    $runspace.SessionStateProxy.SetVariable("TargetPath", $TargetPath)
    $runspace.SessionStateProxy.SetVariable("RunAfterDownload", $RunAfterDownload)
    $runspace.SessionStateProxy.SetVariable("tr", $tr)

    $psCmd = [powershell]::Create()
    $psCmd.Runspace = $runspace
    $psCmd.AddScript({
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($syncHash.Cancel) { break }

            $item = $Items[$i]
            $syncHash.Current = $item.Ad
            $syncHash.Index   = $i
            $itemFolder = if ($item.Klasor) { Join-Path $TargetPath $item.Klasor } else { $TargetPath }
            New-Item -ItemType Directory -Path $itemFolder -Force | Out-Null
            $dest = Join-Path $itemFolder $item.Ad

            try {
                $client.DownloadFile($item.Url, $dest)

                if ($RunAfterDownload -and (-not $syncHash.Cancel)) {
                    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$dest`""
                }
            } catch {
                if (Test-Path $dest) {
                    try { Remove-Item $dest -Force -ErrorAction SilentlyContinue } catch {}
                }
                if (-not $syncHash.Cancel) {
                    $syncHash.Error = "$($item.Ad)"
                }
            }
        }

        try { $client.Dispose() } catch {}
        $syncHash.Done = $true
    }) | Out-Null

    $asyncResult = $psCmd.BeginInvoke()

    $pForm = New-Object System.Windows.Forms.Form
    $pForm.Size = New-Object System.Drawing.Size(560, 240)
    $pForm.StartPosition = "CenterScreen"
    $pForm.FormBorderStyle = "None"
    $pForm.BackColor = $clr.BgDark
    $pForm.TopMost = $false 

    $pForm.Add_MouseDown({
        [Win32]::ReleaseCapture() | Out-Null
        [Win32]::SendMessage($this.Handle, 0xA1, 0x2, 0)
    })

    $titleLbl = New-Object System.Windows.Forms.Label
    $titleLbl.Text = $Title
    $titleLbl.Location = New-Object System.Drawing.Point(24, 22)
    $titleLbl.Size = New-Object System.Drawing.Size(510, 32)
    $titleLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 13)
    $titleLbl.ForeColor = $clr.MangoDark
    $titleLbl.BackColor = [System.Drawing.Color]::Transparent
    $pForm.Controls.Add($titleLbl)

    $currentLbl = New-Object System.Windows.Forms.Label
    $currentLbl.Text = $tr.Baslatiliyor
    $currentLbl.Location = New-Object System.Drawing.Point(24, 68)
    $currentLbl.Size = New-Object System.Drawing.Size(510, 24)
    $currentLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $currentLbl.ForeColor = $clr.MangoDark
    $currentLbl.BackColor = [System.Drawing.Color]::Transparent
    $pForm.Controls.Add($currentLbl)

    $trackPanel = New-Object System.Windows.Forms.Panel
    $trackPanel.Location = New-Object System.Drawing.Point(24, 104)
    $trackPanel.Size = New-Object System.Drawing.Size(510, 14)
    $trackPanel.BackColor = $clr.BgPanel
    $pForm.Controls.Add($trackPanel)

    $fillPanel = New-Object System.Windows.Forms.Panel
    $fillPanel.Location = New-Object System.Drawing.Point(0, 0)
    $fillPanel.Size = New-Object System.Drawing.Size(2, 14)
    $trackPanel.Controls.Add($fillPanel)

    $fillPanel.Add_Paint({
        param($s, $e)
        if ($s.Width -lt 4) { return }
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $s.ClientRectangle,
            $clr.MangoDark,
            $clr.Mango,
            [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
        )
        $g.FillRectangle($brush, $s.ClientRectangle)
        $brush.Dispose()
        
        # Sarı border çiz
        $pen = New-Object System.Drawing.Pen($clr.Border, 2)
        $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
        $pen.Dispose()
    })

    $countLbl = New-Object System.Windows.Forms.Label
    $countLbl.Text = "0 / $($Items.Count)"
    $countLbl.Location = New-Object System.Drawing.Point(24, 126)
    $countLbl.Size = New-Object System.Drawing.Size(510, 20)
    $countLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $countLbl.ForeColor = $clr.TextDim
    $countLbl.BackColor = [System.Drawing.Color]::Transparent
    $countLbl.TextAlign = "MiddleRight"
    $pForm.Controls.Add($countLbl)

    $cancelBtn = New-Object System.Windows.Forms.Panel
    $cancelBtn.Size = New-Object System.Drawing.Size(120, 36)
    $cancelBtn.Location = New-Object System.Drawing.Point(220, 170)
    $cancelBtn.Cursor = "Hand"
    $cancelBtn.Tag = $false

    $cancelLbl = New-Object System.Windows.Forms.Label
    $cancelLbl.Text = $tr.Iptal
    $cancelLbl.Dock = "Fill"
    $cancelLbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 10)
    $cancelLbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 100, 80)
    $cancelLbl.TextAlign = "MiddleCenter"
    $cancelLbl.BackColor = [System.Drawing.Color]::Transparent
    $cancelBtn.Controls.Add($cancelLbl)

    $cancelBtn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        if ($s.Tag) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 50, 40))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 220, 100, 80), 2)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush($clr.BgPanel)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $pen = New-Object System.Drawing.Pen($clr.BorderDim, 1.5)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        }
    })

    $cancelBtn.Add_MouseEnter({ $this.Tag = $true;  $this.Invalidate() })
    $cancelBtn.Add_MouseLeave({ $this.Tag = $false; $this.Invalidate() })
    $cancelLbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate() })
    $cancelLbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate() })

    $cancelBtn.Add_Click({ $syncHash.Cancel = $true })
    $cancelLbl.Add_Click({ $syncHash.Cancel = $true })

    $pForm.Controls.Add($cancelBtn)

    Set-Rounded $pForm 16 $clr.Border 2.5
    Set-Rounded $trackPanel 7
    Set-Rounded $fillPanel 7
    Set-Rounded $cancelBtn 10

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 80

    $script:closeCountdown = 0

    $timer.Add_Tick({
        if ($pForm.IsDisposed) { $timer.Stop(); return }

        $idx    = $syncHash.Index
        $total  = $syncHash.Total
        $done   = $syncHash.Done
        $cancel = $syncHash.Cancel

        $currentLbl.Text = $syncHash.Current
        $countLbl.Text   = "$($idx + 1) / $total"

        $pct  = if ($total -gt 0) { $idx / $total } else { 0 }
        $newW = [Math]::Max(2, [int]($trackPanel.Width * $pct))
        if ($fillPanel.Width -ne $newW) {
            $fillPanel.Width = $newW
            $fillPanel.Invalidate()
        }

        if ($cancel -and -not $done) { return }

        if ($cancel -and $done) {
            $currentLbl.Text = $tr.IptalEdildi
            $script:closeCountdown++
            if ($script:closeCountdown -ge 8) {
                $timer.Stop()
                if (-not $pForm.IsDisposed) { $pForm.Close() }
            }
            return
        }

        if ($done) {
            $fillPanel.Width = $trackPanel.Width
            $fillPanel.Invalidate()
            $currentLbl.Text = $tr.Tamamlandi
            $countLbl.Text   = "$total / $total"
            $script:closeCountdown++
            if ($script:closeCountdown -ge 11) {
                $timer.Stop()
                if (-not $pForm.IsDisposed) { $pForm.Close() }
                Start-Process explorer.exe $TargetPath
            }
        }
    })

    $timer.Start()
    $pForm.ShowDialog() | Out-Null

    $timer.Stop()
    $timer.Dispose()
    $syncHash.Cancel = $true

    try { $psCmd.EndInvoke($asyncResult) } catch {}
    $psCmd.Dispose()
    $runspace.Close()
    $runspace.Dispose()
}


$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(760, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $clr.BgDark
$form.ShowInTaskbar = $true

$form.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object System.Drawing.Pen($clr.Border, 2.5)
    $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
    $pen.Dispose()
})

$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Top"
$header.Height = 48
$header.BackColor = $clr.BgHeader
$form.Controls.Add($header)

$header.Add_MouseDown({
    [Win32]::ReleaseCapture() | Out-Null
    [Win32]::SendMessage($form.Handle, 0xA1, 0x2, 0)
})

# titlenin glowunun başlangıcı
# 2 yorum satırı attık hemen yapay zeka demeyin 
# yapay zeka diyenlerin 
$script:glowStep = 0
$script:glowDir  = 1

$title = New-Object System.Windows.Forms.Label
$title.Text = "Lime AAC Auto Downloader"
$title.Location = New-Object System.Drawing.Point(20, 0)
$title.Size = New-Object System.Drawing.Size(400, 48)
$title.Font = New-Object System.Drawing.Font("Segoe UI Black", 16)
$title.TextAlign = "MiddleLeft"
$title.BackColor = $clr.BgHeader

$title.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $bg = New-Object System.Drawing.SolidBrush($clr.BgHeader)
    $g.FillRectangle($bg, 0, 0, $s.Width, $s.Height)
    $bg.Dispose()

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Near
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $alpha = [int](8 + ($script:glowStep / 20.0) * 55)

    foreach ($ox in @(-2, -1, 1, 2)) {
        foreach ($oy in @(-2, -1, 1, 2)) {
            $dist = [Math]::Sqrt($ox * $ox + $oy * $oy)
            $layerAlpha = [int]($alpha / $dist)
            if ($layerAlpha -lt 3) { continue }
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($layerAlpha, 255, 247, 31))
            $g.DrawString("Lime AAC Auto Downloader", $s.Font, $glowBrush, [System.Drawing.RectangleF]::new($ox, $oy, $s.Width, $s.Height), $sf)
            $glowBrush.Dispose()
        }
    }

    $innerAlpha = [int]($alpha * 0.75)
    foreach ($ox in @(-1, 1)) {
        foreach ($oy in @(-1, 1)) {
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($innerAlpha, 255, 204, 0))
            $g.DrawString("Lime AAC Auto Downloader", $s.Font, $glowBrush, [System.Drawing.RectangleF]::new($ox, $oy, $s.Width, $s.Height), $sf)
            $glowBrush.Dispose()
        }
    }

    $mainBrush = New-Object System.Drawing.SolidBrush($clr.Mango)
    $g.DrawString("Lime AAC Auto Downloader", $s.Font, $mainBrush, [System.Drawing.RectangleF]::new(0, 0, $s.Width, $s.Height), $sf)
    $mainBrush.Dispose()

    $sf.Dispose()
})

$glowTimer = New-Object System.Windows.Forms.Timer
$glowTimer.Interval = 40
$glowTimer.Add_Tick({
    $script:glowStep += $script:glowDir
    if ($script:glowStep -ge 20) { $script:glowDir = -1 }
    if ($script:glowStep -le 0)  { $script:glowDir =  1 }
    if ($null -ne $script:titleRef -and -not $script:titleRef.IsDisposed) {
        $script:titleRef.Invalidate()
    }
})

$script:titleRef = $title
$header.Controls.Add($title)

$form.Add_Shown({ $glowTimer.Start() })
$form.Add_FormClosing({ $glowTimer.Stop(); $glowTimer.Dispose() })
# glow bitiştir
function New-WindowButton($iconChar, $hoverColor, $action) {
    $btn = New-Object System.Windows.Forms.Panel
    $btn.Size = New-Object System.Drawing.Size(50, 34)
    $btn.Cursor = "Hand"
    $btn.BackColor = $clr.BgPanel
    $btn.Tag = @{ Hovered = $false; HoverColor = $hoverColor }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $iconChar
    $lbl.Dock = "Fill"
    $lbl.ForeColor = $clr.Mango
    $lbl.TextAlign = "MiddleCenter"
    $lbl.BackColor = $clr.BgPanel
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 13)

    $btn.Controls.Add($lbl)

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $hc = $s.Tag.HoverColor
        if ($s.Tag.Hovered) {
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, $hc.R, $hc.G, $hc.B))
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
            $overlayBrush = New-Object System.Drawing.SolidBrush($clr.MangoGlow)
            $g.FillRectangle($overlayBrush, $s.ClientRectangle)
            $overlayBrush.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, $hc.R, $hc.G, $hc.B), 2)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush($clr.BgPanel)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })

    $btn.Add_MouseEnter({
        $this.Tag.Hovered = $true
        $hc = $this.Tag.HoverColor
        foreach ($c in $this.Controls) {
            $c.ForeColor = $clr.Mango
            $c.BackColor = [System.Drawing.Color]::Transparent
        }
        $this.Invalidate()
    })
    $btn.Add_MouseLeave({
        $this.Tag.Hovered = $false
        foreach ($c in $this.Controls) {
            $c.ForeColor = $clr.Mango
            $c.BackColor = $clr.BgPanel
        }
        $this.Invalidate()
    })
    $lbl.Add_MouseEnter({
        $p = $this.Parent
        $p.Tag.Hovered = $true
        $hc = $p.Tag.HoverColor
        $this.ForeColor = $clr.Mango
        $this.BackColor = [System.Drawing.Color]::Transparent
        $p.Invalidate()
    })
    $lbl.Add_MouseLeave({
        $p = $this.Parent
        $p.Tag.Hovered = $false
        $this.ForeColor = $clr.Mango
        $this.BackColor = $clr.BgPanel
        $p.Invalidate()
    })

    $btn.Add_Click($action)
    $lbl.Add_Click($action)

    $header.Controls.Add($btn)
    return $btn
}

$btnClose = New-WindowButton "x" ([System.Drawing.Color]::FromArgb(220, 80, 60))  { $form.Close() }
$btnMin   = New-WindowButton "_" $clr.MangoDark { $form.WindowState = "Minimized" }

$buttons = @()
function New-PurpleButton($text, $top, $action) {
    $btn = New-Object System.Windows.Forms.Panel
    $btn.Size = New-Object System.Drawing.Size(360, 48)
    $btn.Location = New-Object System.Drawing.Point(200, $top)
    $btn.Cursor = "Hand"
    $btn.BackColor = $clr.Mango
    $btn.Tag = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Dock = "Fill"
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Black", 11)
    $lbl.ForeColor = $clr.Dark
    $lbl.TextAlign = "MiddleCenter"
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $btn.Controls.Add($lbl)

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        if ($s.Tag -eq $true) {
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $s.ClientRectangle,
                $clr.MangoLite,
                $clr.MangoDark,
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()

            $pen = New-Object System.Drawing.Pen($clr.Border, 2.5)
            $g.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        } else {
            $brush = New-Object System.Drawing.SolidBrush($clr.Mango)
            $g.FillRectangle($brush, $s.ClientRectangle)
            $brush.Dispose()
        }
    })

    $btn.Add_MouseEnter({
        $this.Tag = $true
        $this.Invalidate()
        foreach ($child in $this.Controls) { $child.Invalidate() }
    })
    $btn.Add_MouseLeave({
        $this.Tag = $false
        $this.Invalidate()
        foreach ($child in $this.Controls) { $child.Invalidate() }
    })

    $lbl.Add_MouseEnter({ $this.Parent.Tag = $true;  $this.Parent.Invalidate(); $this.Invalidate() })
    $lbl.Add_MouseLeave({ $this.Parent.Tag = $false; $this.Parent.Invalidate(); $this.Invalidate() })

    if ($action) {
        $btn.Add_Click($action)
        $lbl.Add_Click($action)
    }

    $form.Controls.Add($btn)
    $script:buttons += $btn
    return $btn
}

$downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

New-PurpleButton "SS Tools" 120 {
$dosyalar = @(
        @{ Url = "https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; Ad = "Everything-Setup.exe" }
        @{ Url = "https://www.nirsoft.net/utils/winprefetchview-x64.zip"; Ad = "WinPrefetchView_x64.zip" }
        @{ Url = "https://sourceforge.net/projects/processhacker/files/processhacker2/processhacker-2.39-setup.exe/download"; Ad = "ProcessHacker-2.39-setup.exe" }
        @{ Url = "https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"; Ad = "JournalTrace.exe" }
        @{ Url = "https://github.com/ponei/CachedProgramsList/releases/download/1.1/CachedProgramsList.exe"; Ad = "CachedProgramsList.exe" }
        @{ Url = "https://privazer.com/en/shellbag_analyzer_cleaner.exe"; Ad = "ShellBagAnalyzerCleaner.exe" }
        @{ Url = "https://www.nirsoft.net/utils/browsinghistoryview.zip"; Ad = "BrowsingHistoryView.zip" }
        @{ Url = "https://www.nirsoft.net/utils/browserdownloadsview-x64.zip"; Ad = "WebBrowserDownloadsView.zip" }
        @{ Url = "https://www.nirsoft.net/utils/jumplistsview.zip"; Ad = "JumpListsView.zip" }
        @{ Url = "https://www.nirsoft.net/utils/computeractivityview.zip"; Ad = "ComputerActivityView.zip" }
        @{ Url = "https://www.nirsoft.net/utils/usbdrivelog.zip"; Ad = "USBDriveLog.zip" }
        @{ Url = "https://www.nirsoft.net/utils/lastactivityview.zip"; Ad = "lastactivityview.zip" } 
    )

    $target = Join-Path $downloadsPath "ScreenShareTools"
    Invoke-TaskWithProgress -Title "Tools indiriliyor..." -Items $dosyalar -TargetPath $target -RunAfterDownload $false
}

New-PurpleButton "PowerShell Scripts" 175 {
    $psScripts = @(
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Drive-Executions.ps1"; Ad = "Drive-Executions.ps1"; Yazar = "Lily" }
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1"; Ad = "Services.ps1"; Yazar = "Lily" }
        @{ Url = "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/DoomsdayFinder.ps1"; Ad = "DoomsdayFinder.ps1"; Yazar = "Lily" }
        @{ Url= "https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1"; Ad = "Domdomfinderv2.ps1"; Yazar = "Lily"}

        @{ Url = "https://raw.githubusercontent.com/spokwn/powershells/refs/heads/main/Streams.ps1"; Ad = "Streams.ps1"; Yazar = "spokwn" }
        @{ Url= "https://raw.githubusercontent.com/spokwn/powershells/refs/heads/main/bamparser.ps1"; Ad = "BamDeletedKeys.ps1"; Yazar = "spokwn"}

        @{ Url = "https://raw.githubusercontent.com/bacanoicua/Screenshare/main/RedLotusPrefetchIntegrityAnalyzer.ps1"; Ad = "RedLotusPrefetchIntegrityAnalyzer.ps1"; Yazar = "RedLotus" }
        @{ Url= "https://raw.githubusercontent.com/ObsessiveBf/Task-Scheduler-Parser/main/script.ps1"; Ad = "TaskSchedulerParser.ps1"; Yazar = "RedLotus" }
        @{ Url= "https://raw.githubusercontent.com/HadronCollision/PowershellScripts/refs/heads/main/HabibiModAnalyzer.ps1"; Ad = "HabibiModAnalyzer.ps1"; Yazar = "RedLotus" }
        @{ Url ="https://raw.githubusercontent.com/nolww/project-mohr/refs/heads/main/SuspiciousScheduler.ps1"; Ad = "SuspiciousScheduler.ps1"; Yazar = "RedLotus"}
        @{ Url = "https://raw.githubusercontent.com/nolww/project-mohr/refs/heads/main/ManualTasks.ps1"; Ad = "ManualSchduledTasks.ps1"; Yazar = "RedLotus"}
        @{ Url = "https://raw.githubusercontent.com/PureIntent/ScreenShare/main/RedLotusBam.ps1"; Ad = "RedLotusBam.ps1"; Yazar = "RedLotus"}

        @{ Url = "https://raw.githubusercontent.com/trSScommunity/BaglantiAnalizi/refs/heads/main/BaglantiAnalizi.ps1"; Ad = "BaglantiAnalizi.ps1"; Yazar = "TRSScommunity" }
    )
    Show-ScriptSelector -Scripts $psScripts
}

New-PurpleButton "Soon..." 230 $null
New-PurpleButton "Soon..." 285 $null
New-PurpleButton "Soon..." 340 $null

$creditLabel = New-Object System.Windows.Forms.Label
$creditLabel.Text = "-By FlaxerzNO1"
$creditLabel.Location = New-Object System.Drawing.Point(20, 440)
$creditLabel.Size = New-Object System.Drawing.Size(200, 20)
$creditLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$creditLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$creditLabel.BackColor = [System.Drawing.Color]::Transparent
$creditLabel.TextAlign = "MiddleLeft"

$creditLabel.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Near
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    
    foreach ($ox in @(-1, 0, 1)) {
        foreach ($oy in @(-1, 0, 1)) {
            if ($ox -eq 0 -and $oy -eq 0) { continue }
            $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(15, 116, 155, 40))
            $g.DrawString("-By FlaxerzNO1", $s.Font, $glowBrush, [System.Drawing.RectangleF]::new($ox, $oy, $s.Width, $s.Height), $sf)
            $glowBrush.Dispose()
        }
    }
    
    $mainBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 80, 80))
    $g.DrawString("-By FlaxerzNO1", $s.Font, $mainBrush, [System.Drawing.RectangleF]::new(0, 0, $s.Width, $s.Height), $sf)
    $mainBrush.Dispose()
    
    $sf.Dispose()
})

$form.Controls.Add($creditLabel)

$form.Add_Shown({
    $btnClose.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 58), 7)
    $btnMin.Location   = New-Object System.Drawing.Point(($form.ClientSize.Width - 114), 7)
    Set-Rounded $form 18 $clr.Border 2.5
    Set-Rounded $btnClose 10
    Set-Rounded $btnMin   10
    foreach ($b in $buttons) { Set-Rounded $b 14 }
})

[void]$form.ShowDialog()
