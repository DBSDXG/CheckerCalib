param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.Windows.Forms.Application]::EnableVisualStyles()

$template = Join-Path $PSScriptRoot 'checkerboard.scad'
$engine = Join-Path $PSScriptRoot 'tools\openscad-2021.01\openscad.com'
if (-not (Test-Path -LiteralPath $engine)) {
    $engine = Join-Path ${env:ProgramFiles} 'OpenSCAD\openscad.com'
}
if (-not (Test-Path -LiteralPath $engine)) {
    [System.Windows.Forms.MessageBox]::Show('未找到 OpenSCAD。请完整解压模板包，保留 tools 文件夹，或安装 OpenSCAD。','无法启动') | Out-Null
    exit 1
}

# ---------- 配色与字体 ----------
$bgForm         = [System.Drawing.Color]::FromArgb(243,245,248)
$colCard        = [System.Drawing.Color]::White
$colBorder      = [System.Drawing.Color]::FromArgb(226,232,240)
$colAccent      = [System.Drawing.Color]::FromArgb(46,107,230)
$colTitle       = [System.Drawing.Color]::FromArgb(15,23,42)
$colSub         = [System.Drawing.Color]::FromArgb(100,116,139)
$colKey         = [System.Drawing.Color]::FromArgb(100,116,139)
$colValue       = [System.Drawing.Color]::FromArgb(15,23,42)
$colPreviewBg     = [System.Drawing.Color]::FromArgb(237,242,247)
$colPreviewBorder = [System.Drawing.Color]::FromArgb(217,225,234)
$colDim         = [System.Drawing.Color]::FromArgb(71,85,105)
$colDimLine     = [System.Drawing.Color]::FromArgb(148,163,184)
$colStatusBg    = [System.Drawing.Color]::FromArgb(231,237,243)
$colStatus      = [System.Drawing.Color]::FromArgb(71,85,105)
$colErr         = [System.Drawing.Color]::FromArgb(220,38,38)
$colOk          = [System.Drawing.Color]::FromArgb(21,128,61)

$fontTitle    = New-Object System.Drawing.Font('Microsoft YaHei UI',17,[System.Drawing.FontStyle]::Bold)
$fontSub      = New-Object System.Drawing.Font('Microsoft YaHei UI',9.25)
$fontSection  = New-Object System.Drawing.Font('Microsoft YaHei UI',10.5,[System.Drawing.FontStyle]::Bold)
$fontCaption  = New-Object System.Drawing.Font('Microsoft YaHei UI',8.5)
$fontInput    = New-Object System.Drawing.Font('Microsoft YaHei UI',10)
$fontKey      = New-Object System.Drawing.Font('Microsoft YaHei UI',8.5)
$fontValue    = New-Object System.Drawing.Font('Microsoft YaHei UI',10.5,[System.Drawing.FontStyle]::Bold)
$fontDim      = New-Object System.Drawing.Font('Microsoft YaHei UI',8.25)
$fontNote     = New-Object System.Drawing.Font('Microsoft YaHei UI',8.75)
$fontBtnP     = New-Object System.Drawing.Font('Microsoft YaHei UI',10.5,[System.Drawing.FontStyle]::Bold)
$fontBtnS     = New-Object System.Drawing.Font('Microsoft YaHei UI',10)
$fontStatus   = New-Object System.Drawing.Font('Microsoft YaHei UI',9)
$fontCheck    = New-Object System.Drawing.Font('Microsoft YaHei UI',9.75)

# ---------- 主窗体 ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = '棋盘标定板 · 参数化 STL 生成器'
$form.ClientSize = New-Object System.Drawing.Size(1120,832)
$form.MinimumSize = $form.Size
$form.MaximumSize = $form.Size
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI',9.75)
$form.BackColor = $bgForm

# ---------- 绘图与控件辅助 ----------
function RoundPath([single]$w,[single]$h,[single]$r) {
    if ($r -gt $w/2) { $r = $w/2 }
    if ($r -gt $h/2) { $r = $h/2 }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0,0,$r,$r,180,90)
    $path.AddArc($w-2*$r,0,$r,$r,270,90)
    $path.AddArc($w-2*$r,$h-2*$r,$r,$r,0,90)
    $path.AddArc(0,$h-2*$r,$r,$r,90,90)
    $path.CloseFigure()
    return $path
}
function New-Card([int]$x,[int]$y,[int]$w,[int]$h) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($x,$y)
    $p.Size = New-Object System.Drawing.Size($w,$h)
    $p.BackColor = $bgForm
    $p.Add_Paint({
        param($sender,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $path = RoundPath $sender.Width $sender.Height 10
        $brush = New-Object System.Drawing.SolidBrush($colCard)
        $e.Graphics.FillPath($brush,$path)
        $pen = New-Object System.Drawing.Pen($colBorder)
        $e.Graphics.DrawPath($pen,$path)
        $path.Dispose(); $pen.Dispose(); $brush.Dispose()
    })
    $form.Controls.Add($p)
    return $p
}
function Add-Section($parent,[string]$text,[int]$x,[int]$y,[int]$w) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($x,$y)
    $p.Size = New-Object System.Drawing.Size($w,20)
    $p.BackColor = $colCard
    $p.Tag = $text
    $p.Add_Paint({
        param($sender,$e)
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $text = [string]$sender.Tag
        $bar = New-Object System.Drawing.SolidBrush($colAccent)
        $e.Graphics.FillRectangle($bar,0,2,4,16)
        $tb = New-Object System.Drawing.SolidBrush($colTitle)
        $e.Graphics.DrawString($text,$fontSection,$tb,12,0)
        $tw = $e.Graphics.MeasureString($text,$fontSection).Width
        $pen = New-Object System.Drawing.Pen($colBorder)
        $e.Graphics.DrawLine($pen,[single](12+$tw+10),[single]11,[single]$sender.Width,[single]11)
        $bar.Dispose(); $tb.Dispose(); $pen.Dispose()
    })
    $parent.Controls.Add($p)
    return $p
}
function Add-Caption($parent,[string]$text,[int]$x,[int]$y,[int]$w) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x,$y)
    $l.Size = New-Object System.Drawing.Size($w,17)
    $l.BackColor = $colCard
    $l.ForeColor = $colSub
    $l.Font = $fontCaption
    $parent.Controls.Add($l)
    return $l
}
function Add-Combo($parent,[object[]]$items,[int]$x,[int]$y,[int]$w) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'
    $c.FlatStyle = 'Flat'
    $c.BackColor = $colCard
    $c.Font = $fontInput
    $c.Items.AddRange($items)
    $c.SelectedIndex = 0
    $c.Location = New-Object System.Drawing.Point($x,$y)
    $c.Size = New-Object System.Drawing.Size($w,30)
    $parent.Controls.Add($c)
    return $c
}
function Add-Number($parent,[decimal]$value,[decimal]$min,[decimal]$max,[int]$decimals,[int]$x,[int]$y,[int]$w) {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Minimum = $min
    $n.Maximum = $max
    $n.DecimalPlaces = $decimals
    $n.Increment = [decimal]([math]::Pow(10,-$decimals))
    $n.Value = $value
    $n.BorderStyle = 'FixedSingle'
    $n.BackColor = $colCard
    $n.TextAlign = 'Center'
    $n.Font = $fontInput
    $n.Location = New-Object System.Drawing.Point($x,$y)
    $n.Size = New-Object System.Drawing.Size($w,30)
    $parent.Controls.Add($n)
    return $n
}
function New-AppButton([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[bool]$primary) {
    $b = New-Object System.Windows.Forms.Button
    $b.Location = New-Object System.Drawing.Point($x,$y)
    $b.Size = New-Object System.Drawing.Size($w,$h)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $bgForm
    $b.FlatAppearance.MouseDownBackColor = $bgForm
    $b.BackColor = $bgForm
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Tag = @{ text = $text; primary = $primary; hover = $false }
    $b.Add_MouseEnter({ param($sender,$e) $sender.Tag.hover = $true; $sender.Invalidate() })
    $b.Add_MouseLeave({ param($sender,$e) $sender.Tag.hover = $false; $sender.Invalidate() })
    $b.Add_EnabledChanged({ param($sender,$e) $sender.Invalidate() })
    $b.Add_Paint({
        param($sender,$e)
        $t = $sender.Tag
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $path = RoundPath $sender.Width $sender.Height 9
        $rect = New-Object System.Drawing.RectangleF(0,0,$sender.Width,$sender.Height)
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Alignment = [System.Drawing.StringAlignment]::Center
        $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
        if ($t.primary) {
            $bg = [System.Drawing.Color]::FromArgb(46,107,230)
            if (-not $sender.Enabled) { $bg = [System.Drawing.Color]::FromArgb(184,199,229) }
            elseif ($t.hover) { $bg = [System.Drawing.Color]::FromArgb(36,88,200) }
            $brush = New-Object System.Drawing.SolidBrush($bg)
            $e.Graphics.FillPath($brush,$path)
            $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $e.Graphics.DrawString($t.text,$fontBtnP,$tb,$rect,$fmt)
            $tb.Dispose(); $brush.Dispose()
        } else {
            $fill = [System.Drawing.Color]::White
            if (-not $sender.Enabled) { $fill = [System.Drawing.Color]::FromArgb(244,247,250) }
            elseif ($t.hover) { $fill = [System.Drawing.Color]::FromArgb(240,245,250) }
            $brush = New-Object System.Drawing.SolidBrush($fill)
            $e.Graphics.FillPath($brush,$path)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(203,213,225))
            $e.Graphics.DrawPath($pen,$path)
            $tcol = [System.Drawing.Color]::FromArgb(51,65,85)
            if (-not $sender.Enabled) { $tcol = [System.Drawing.Color]::FromArgb(148,163,184) }
            $tb = New-Object System.Drawing.SolidBrush($tcol)
            $e.Graphics.DrawString($t.text,$fontBtnS,$tb,$rect,$fmt)
            $tb.Dispose(); $pen.Dispose(); $brush.Dispose()
        }
        $fmt.Dispose(); $path.Dispose()
    })
    $form.Controls.Add($b)
    return $b
}
function SetStatus([string]$text,[string]$kind) {
    $status.Text = $text
    if ($kind -eq 'err') { $status.ForeColor = $colErr }
    elseif ($kind -eq 'ok') { $status.ForeColor = $colOk }
    else { $status.ForeColor = $colStatus }
}

# ---------- 顶部标题区 ----------
$accentBar = New-Object System.Windows.Forms.Panel
$accentBar.Location = New-Object System.Drawing.Point(32,25)
$accentBar.Size = New-Object System.Drawing.Size(5,27)
$accentBar.BackColor = $colAccent
$form.Controls.Add($accentBar)
$title = New-Object System.Windows.Forms.Label
$title.Text = '棋盘标定板生成器'
$title.Location = New-Object System.Drawing.Point(46,18)
$title.Size = New-Object System.Drawing.Size(620,34)
$title.BackColor = $bgForm
$title.ForeColor = $colTitle
$title.Font = $fontTitle
$form.Controls.Add($title)
$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = '调整规格 → 查看实际尺寸 → 导出黑白两部分 STL'
$subtitle.Location = New-Object System.Drawing.Point(46,58)
$subtitle.Size = New-Object System.Drawing.Size(700,22)
$subtitle.BackColor = $bgForm
$subtitle.ForeColor = $colSub
$subtitle.Font = $fontSub
$form.Controls.Add($subtitle)
$chip = New-Object System.Windows.Forms.Label
$chip.Text = '参数化模板 v1.3 · 单位：毫米'
$chip.Location = New-Object System.Drawing.Point(828,30)
$chip.Size = New-Object System.Drawing.Size(260,20)
$chip.BackColor = $bgForm
$chip.ForeColor = $colDimLine
$chip.Font = $fontKey
$chip.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$form.Controls.Add($chip)

# ---------- 左栏：参数卡片 ----------
$cardL = New-Card 32 104 384 592
$ix = 24; $iw = 336; $hx = 198; $hw = 162
$y = 18
$null = Add-Section $cardL '棋盘规格' $ix $y $iw; $y += 32
$null = Add-Caption $cardL '数量填写方式' $ix $y $iw; $y += 19
$count = Add-Combo $cardL @('格子数','内角点数') $ix $y $iw; $y += 42
$null = Add-Caption $cardL '横向数量' $ix $y $hw
$null = Add-Caption $cardL '纵向数量' $hx $y $hw; $y += 19
$cols = Add-Number $cardL 10 2 60 0 $ix $y $hw
$rows = Add-Number $cardL 7 2 60 0 $hx $y $hw; $y += 42
$null = Add-Caption $cardL '尺寸设置方式' $ix $y $iw; $y += 19
$sizeMode = Add-Combo $cardL @('按单格边长','按整板宽高') $ix $y $iw; $y += 42
$null = Add-Caption $cardL '单格边长 / mm' $ix $y $hw
$null = Add-Caption $cardL '最小白边 / mm' $hx $y $hw; $y += 19
$square = Add-Number $cardL 20 2 100 2 $ix $y $hw
$border = Add-Number $cardL 20 0.1 100 2 $hx $y $hw; $y += 42
$null = Add-Caption $cardL '整板宽度 / mm' $ix $y $hw
$null = Add-Caption $cardL '整板高度 / mm' $hx $y $hw; $y += 19
$width = Add-Number $cardL 240 10 1000 2 $ix $y $hw
$height = Add-Number $cardL 180 10 1000 2 $hx $y $hw; $y += 46
$null = Add-Section $cardL '厚度与工艺' $ix $y $iw; $y += 32
$null = Add-Caption $cardL '底板厚度 / mm' $ix $y $hw
$null = Add-Caption $cardL '黑格嵌入深度 / mm' $hx $y $hw; $y += 19
$base = Add-Number $cardL 2 0.4 20 2 $ix $y $hw
$depth = Add-Number $cardL 0.6 0.2 5 2 $hx $y $hw; $y += 42
$null = Add-Caption $cardL '角点微切角 / mm' $ix $y $hw
$null = Add-Caption $cardL '底部收缩量 / mm' $hx $y $hw; $y += 19
$relief = Add-Number $cardL 0.02 0 0.2 2 $ix $y $hw
$taper = Add-Number $cardL 0.05 0.01 0.5 2 $hx $y $hw; $y += 46
$null = Add-Section $cardL '图案' $ix $y $iw; $y += 32
$blackOrigin = New-Object System.Windows.Forms.CheckBox
$blackOrigin.Text = '左下角为黑格（XY 坐标）'
$blackOrigin.Checked = $true
$blackOrigin.Location = New-Object System.Drawing.Point($ix,$y)
$blackOrigin.Size = New-Object System.Drawing.Size($iw,30)
$blackOrigin.BackColor = $colCard
$blackOrigin.ForeColor = $colTitle
$blackOrigin.Font = $fontCheck
$cardL.Controls.Add($blackOrigin)

# ---------- 右栏：预览卡片 ----------
$cardP = New-Card 440 104 648 388
$preview = New-Object System.Windows.Forms.Panel
$preview.Location = New-Object System.Drawing.Point(16,16)
$preview.Size = New-Object System.Drawing.Size(616,356)
$preview.BackColor = $colCard
$cardP.Controls.Add($preview)

# ---------- 右栏：数据概览卡片 ----------
$cardI = New-Card 440 506 648 112
$cardI.Add_Paint({
    param($sender,$e)
    $g2 = CurrentGeometry
    $slots = @(
        @('实际格子', ('{0} × {1}' -f $g2.nx,$g2.ny)),
        @('内角点', ('{0} × {1}' -f ($g2.nx-1),($g2.ny-1))),
        @('单格边长', ('{0:0.####} mm' -f $g2.s)),
        @('整板尺寸', ('{0:0.##} × {1:0.##} × {2:0.##} mm' -f $g2.w,$g2.h,$g2.z)),
        @('左右白边', ('{0:0.##} mm' -f $g2.mx)),
        @('上下白边', ('{0:0.##} mm' -f $g2.my))
    )
    $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $kb = New-Object System.Drawing.SolidBrush($colKey)
    $vb = New-Object System.Drawing.SolidBrush($colValue)
    for ($i = 0; $i -lt 6; $i++) {
        $sx = 24 + ($i%3)*204
        $sy = 16 + [math]::Floor($i/3)*48
        $e.Graphics.DrawString($slots[$i][0],$fontKey,$kb,[single]$sx,[single]$sy)
        $e.Graphics.DrawString($slots[$i][1],$fontValue,$vb,[single]$sx,[single]($sy+20))
    }
    $kb.Dispose(); $vb.Dispose()
})

# ---------- 右栏：说明文字 ----------
$note = New-Object System.Windows.Forms.Label
$note.Text = "预览为正面示意：黑白格表面齐平，底部连续支撑。`r`n角点微切角默认 0.02 mm；设为 0 可保留理想尖角，但 STL 导出可能出现接触角点警告。"
$note.Location = New-Object System.Drawing.Point(440,630)
$note.Size = New-Object System.Drawing.Size(648,52)
$note.BackColor = $bgForm
$note.ForeColor = $colSub
$note.Font = $fontNote
$form.Controls.Add($note)

# ---------- 底部操作按钮 ----------
$loadButton = New-AppButton '载入已保存的参数' 32 716 210 50 $false
$button = New-AppButton '选择保存位置并生成 3MF + STL' 728 716 360 50 $true

# ---------- 底部状态条 ----------
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(0,782)
$statusPanel.Size = New-Object System.Drawing.Size(1120,36)
$statusPanel.BackColor = $colStatusBg
$form.Controls.Add($statusPanel)
$status = New-Object System.Windows.Forms.Label
$status.Text = ''
$status.Location = New-Object System.Drawing.Point(32,7)
$status.Size = New-Object System.Drawing.Size(1040,22)
$status.BackColor = $colStatusBg
$status.ForeColor = $colStatus
$status.Font = $fontStatus
$status.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$statusPanel.Controls.Add($status)

# ---------- 几何计算 ----------
function CurrentGeometry {
    $nx = [int]$cols.Value + [int]$count.SelectedIndex
    $ny = [int]$rows.Value + [int]$count.SelectedIndex
    $b = [double]$border.Value
    $s = [double]$square.Value
    $w = $nx*$s + 2*$b
    $h = $ny*$s + 2*$b
    if ($sizeMode.SelectedIndex -eq 1) {
        $w = [double]$width.Value
        $h = [double]$height.Value
        $s = [math]::Min(($w-2*$b)/$nx,($h-2*$b)/$ny)
    }
    return @{ nx=$nx; ny=$ny; s=$s; w=$w; h=$h; mx=($w-$nx*$s)/2; my=($h-$ny*$s)/2; z=([double]$base.Value+[double]$depth.Value) }
}
function UpdatePreview {
    $g = CurrentGeometry
    $square.Enabled = $sizeMode.SelectedIndex -eq 0
    $width.Enabled = $sizeMode.SelectedIndex -eq 1
    $height.Enabled = $sizeMode.SelectedIndex -eq 1
    $button.Enabled = $g.s -gt (2*[double]$taper.Value) -and $g.s -gt (4*[double]$relief.Value)
    if (-not $button.Enabled) { SetStatus '尺寸不成立：请增大整板尺寸，或减小白边/格子数量。' 'err' }
    else { SetStatus '单位：毫米。请确认整板尺寸能放入打印平台。' '' }
    $cardI.Invalidate()
    $preview.Invalidate()
}

# ---------- 预览绘制 ----------
$preview.Add_Paint({
    param($sender,$e)
    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $fmtC = New-Object System.Drawing.StringFormat
    $fmtC.Alignment = [System.Drawing.StringAlignment]::Center
    $fmtC.LineAlignment = [System.Drawing.StringAlignment]::Center
    $bgBrush = New-Object System.Drawing.SolidBrush($colPreviewBg)
    $bgPen = New-Object System.Drawing.Pen($colPreviewBorder)
    $path = RoundPath $sender.Width $sender.Height 10
    $e.Graphics.FillPath($bgBrush,$path)
    $e.Graphics.DrawPath($bgPen,$path)
    $path.Dispose()
    $g2 = CurrentGeometry
    if ($g2.s -le 0) {
        $hintBrush = New-Object System.Drawing.SolidBrush($colDimLine)
        $rect = New-Object System.Drawing.RectangleF(0,0,$sender.Width,$sender.Height)
        $e.Graphics.DrawString('当前规格不成立，请调整左侧参数',$fontInput,$hintBrush,$rect,$fmtC)
        $hintBrush.Dispose(); $fmtC.Dispose(); $bgBrush.Dispose(); $bgPen.Dispose()
        return
    }
    $padL = 46; $padR = 46; $padT = 40; $padB = 46
    $scale = [math]::Min(($sender.Width-$padL-$padR)/$g2.w,($sender.Height-$padT-$padB)/$g2.h)
    $bw = $g2.w*$scale
    $bh = $g2.h*$scale
    $x = ($sender.Width-$bw)/2
    $y = $padT + ($sender.Height-$padT-$padB-$bh)/2
    $e.Graphics.FillRectangle([System.Drawing.Brushes]::White,[single]$x,[single]$y,[single]$bw,[single]$bh)
    for ($r=0; $r -lt $g2.ny; $r++) {
        for ($c=0; $c -lt $g2.nx; $c++) {
            if ((($r+$c)%2 -eq 0) -eq $blackOrigin.Checked) {
                $e.Graphics.FillRectangle([System.Drawing.Brushes]::Black,[single]($x+($g2.mx+$c*$g2.s)*$scale),[single]($y+($g2.my+($g2.ny-1-$r)*$g2.s)*$scale),[single]($g2.s*$scale),[single]($g2.s*$scale))
            }
        }
    }
    $boardPen = New-Object System.Drawing.Pen($colDim)
    $e.Graphics.DrawRectangle($boardPen,[single]$x,[single]$y,[single]$bw,[single]$bh)
    # 宽度标注（板下方）
    $dimPen = New-Object System.Drawing.Pen($colDimLine)
    $dimBrush = New-Object System.Drawing.SolidBrush($colDim)
    $dy = $y+$bh+14
    $e.Graphics.DrawLine($dimPen,[single]$x,[single]$dy,[single]($x+$bw),[single]$dy)
    $e.Graphics.DrawLine($dimPen,[single]$x,[single]($dy-4),[single]$x,[single]($dy+4))
    $e.Graphics.DrawLine($dimPen,[single]($x+$bw),[single]($dy-4),[single]($x+$bw),[single]($dy+4))
    $wt = '{0:0.##} mm' -f $g2.w
    $wsz = $e.Graphics.MeasureString($wt,$fontDim)
    $wcx = $x+$bw/2
    $e.Graphics.FillRectangle($bgBrush,[single]($wcx-$wsz.Width/2-4),[single]($dy-$wsz.Height/2),[single]($wsz.Width+8),[single]$wsz.Height)
    $e.Graphics.DrawString($wt,$fontDim,$dimBrush,[single]$wcx,[single]$dy,$fmtC)
    # 高度标注（板左侧）
    $dx = $x-14
    $e.Graphics.DrawLine($dimPen,[single]$dx,[single]$y,[single]$dx,[single]($y+$bh))
    $e.Graphics.DrawLine($dimPen,[single]($dx-4),[single]$y,[single]($dx+4),[single]$y)
    $e.Graphics.DrawLine($dimPen,[single]($dx-4),[single]($y+$bh),[single]($dx+4),[single]($y+$bh))
    $ht = '{0:0.##} mm' -f $g2.h
    $hsz = $e.Graphics.MeasureString($ht,$fontDim)
    $hcy = $y+$bh/2
    $e.Graphics.TranslateTransform([single]$dx,[single]$hcy)
    $e.Graphics.RotateTransform(-90)
    $e.Graphics.FillRectangle($bgBrush,[single](-$hsz.Width/2-4),[single](-$hsz.Height/2),[single]($hsz.Width+8),[single]$hsz.Height)
    $e.Graphics.DrawString($ht,$fontDim,$dimBrush,0,0,$fmtC)
    $e.Graphics.ResetTransform()
    # 左下角颜色说明
    $cap = if ($blackOrigin.Checked) { '左下角 = 黑格' } else { '左下角 = 白格' }
    $capBrush = New-Object System.Drawing.SolidBrush($colDimLine)
    $e.Graphics.DrawString($cap,$fontDim,$capBrush,16,[single]($sender.Height-24))
    $capBrush.Dispose(); $dimBrush.Dispose(); $dimPen.Dispose(); $boardPen.Dispose()
    $fmtC.Dispose(); $bgBrush.Dispose(); $bgPen.Dispose()
})

# ---------- 事件绑定 ----------
foreach ($n in @($cols,$rows,$square,$border,$width,$height,$base,$depth,$relief,$taper)) { $n.Add_ValueChanged({ UpdatePreview }) }
foreach ($c in @($count,$sizeMode)) { $c.Add_SelectedIndexChanged({ UpdatePreview }) }
$blackOrigin.Add_CheckedChanged({ UpdatePreview })

# ---------- 参数序列化 ----------
function ScadNumber($v) { return ([double]$v).ToString('0.########',[System.Globalization.CultureInfo]::InvariantCulture) }
function SavePreset($path,$values) {
    $serialized = @{fileFormatVersion='1';parameterSets=@{saved=$values}} | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($path,$serialized,(New-Object System.Text.UTF8Encoding($false)))
}

# ---------- 3MF 构建（Bambu Studio 原生结构，单零件 · 双色 part） ----------
# 格式依据：BambuStudio 源码 src/libslic3r/Format/bbs_3mf.cpp 读取器，
# 并经 Bambu Studio 02.08.02 真机 CLI 往返验证（部件与挤出机映射完整保留）：
# 网格放在 3D/Objects/object_N.model，主模型用 p:path 组件引用；
# Metadata/model_settings.config 的 <part id=组件objectid subtype="normal_part">
# 里 metadata key="extruder" 指定部件挤出机。
# Bambu only loads embedded project configuration for its recognized Application
# signature. Supply the COMPLETE defaults template; an incomplete one can crash
# Bambu's project loader, while a custom signature silently discards the colours.
function Read-StlTriangles([string]$stlPath) {
    $verts = New-Object 'System.Collections.Generic.List[double[]]'
    $reader = New-Object System.IO.StreamReader($stlPath,[System.Text.Encoding]::ASCII,$false)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            $t = $line.Trim()
            if ($t.StartsWith('vertex')) {
                $p = $t.Substring(6).Trim() -split '\s+'
                $verts.Add(@([double]::Parse($p[0],[System.Globalization.CultureInfo]::InvariantCulture),
                              [double]::Parse($p[1],[System.Globalization.CultureInfo]::InvariantCulture),
                              [double]::Parse($p[2],[System.Globalization.CultureInfo]::InvariantCulture)))
            }
        }
    } finally { $reader.Dispose() }
    if ($verts.Count -eq 0 -or $verts.Count % 3 -ne 0) { throw ('STL 没有有效的完整三角面：'+$stlPath) }
    return $verts
}
function ConvertTo-3mfNumber([double]$d) {
    if ($d -eq 0) { return '0' }
    return $d.ToString('R',[System.Globalization.CultureInfo]::InvariantCulture)
}
function ConvertTo-3mfXmlEscape([string]$s) {
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}
function New-ThreeMf([string]$path,[string]$objectName,$whiteVerts,$blackVerts) {
    $settingsPath = Join-Path $PSScriptRoot 'bambu_project_settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) { throw '缺少双色工程配置 bambu_project_settings.json，请使用完整程序包。' }
    $projectSettings = [System.IO.File]::ReadAllText($settingsPath,[System.Text.Encoding]::UTF8)
    $projectCheck = $projectSettings | ConvertFrom-Json
    if ($projectCheck.filament_colour.Count -lt 2 -or $projectCheck.filament_colour[0] -ne '#FFFFFF' -or $projectCheck.filament_colour[1] -ne '#000000' -or $projectCheck.filament_settings_id.Count -lt 2) {
        throw '双色工程配置损坏：必须包含白色与黑色两个耗材槽位。'
    }
    $wTri = $whiteVerts.Count / 3
    $bTri = $blackVerts.Count / 3
    $totalTri = $wTri + $bTri
    $date = (Get-Date).ToString('yyyy-MM-dd')
    $nameEsc = ConvertTo-3mfXmlEscape $objectName

    function MeshSection($verts) {
        # STL repeats coordinates for every triangle. 3MF needs shared vertex
        # indices, otherwise Bambu reports every triangle edge as an open edge.
        $map = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([System.StringComparer]::Ordinal)
        $unique = New-Object 'System.Collections.Generic.List[double[]]'
        $indices = New-Object 'System.Collections.Generic.List[int]'
        foreach ($v in $verts) {
            $key = (ConvertTo-3mfNumber $v[0]) + ',' + (ConvertTo-3mfNumber $v[1]) + ',' + (ConvertTo-3mfNumber $v[2])
            if (-not $map.ContainsKey($key)) {
                $map.Add($key,$unique.Count)
                $unique.Add($v)
            }
            $indices.Add($map[$key])
        }
        $local = New-Object System.Text.StringBuilder
        [void]$local.Append('   <mesh>' + "`n")
        [void]$local.Append('    <vertices>' + "`n")
        foreach ($v in $unique) {
            [void]$local.Append('     <vertex x="' + (ConvertTo-3mfNumber $v[0]) + '" y="' + (ConvertTo-3mfNumber $v[1]) + '" z="' + (ConvertTo-3mfNumber $v[2]) + '"/>' + "`n")
        }
        [void]$local.Append('    </vertices>' + "`n")
        [void]$local.Append('    <triangles>' + "`n")
        for ($j = 0; $j -lt ($verts.Count / 3); $j++) {
            $b3 = 3*$j
            [void]$local.Append('     <triangle v1="' + $indices[$b3] + '" v2="' + $indices[$b3+1] + '" v3="' + $indices[$b3+2] + '"/>' + "`n")
        }
        [void]$local.Append('    </triangles>' + "`n")
        [void]$local.Append('   </mesh>' + "`n")
        return $local.ToString()
    }
    function ObjectModelFile([int]$objId,$uuid,$verts) {
        $local = New-Object System.Text.StringBuilder
        [void]$local.Append('<?xml version="1.0" encoding="UTF-8"?>' + "`n")
        [void]$local.Append('<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" requiredextensions="p">' + "`n")
        [void]$local.Append(' <metadata name="BambuStudio:3mfVersion">1</metadata>' + "`n")
        [void]$local.Append(' <resources>' + "`n")
        [void]$local.Append('  <basematerials id="10"><base name="White" displaycolor="#FFFFFFFF"/><base name="Black" displaycolor="#000000FF"/></basematerials>' + "`n")
        [void]$local.Append('  <object id="' + $objId + '" p:UUID="' + $uuid + '" type="model" pid="10" pindex="' + ($objId-1) + '">' + "`n")
        [void]$local.Append((MeshSection $verts))
        [void]$local.Append('  </object>' + "`n")
        [void]$local.Append(' </resources>' + "`n")
        [void]$local.Append(' <build/>' + "`n")
        [void]$local.Append('</model>' + "`n")
        return $local.ToString()
    }

    $u1 = [guid]::NewGuid().ToString()
    $u2 = [guid]::NewGuid().ToString()
    $u3 = [guid]::NewGuid().ToString()
    $uc1 = [guid]::NewGuid().ToString()
    $uc2 = [guid]::NewGuid().ToString()
    $ub = [guid]::NewGuid().ToString()
    $ui = [guid]::NewGuid().ToString()

    $mainModel = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" +
'<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" requiredextensions="p">' + "`n" +
' <metadata name="Application">BambuStudio-02.08.02.61</metadata>' + "`n" +
' <metadata name="Generator">CalibrationBoardGenerator-1.3</metadata>' + "`n" +
' <metadata name="BambuStudio:3mfVersion">1</metadata>' + "`n" +
' <metadata name="slic3rpe:Version3mf">1</metadata>' + "`n" +
' <metadata name="Title">' + $nameEsc + '</metadata>' + "`n" +
' <metadata name="Designer"></metadata>' + "`n" +
' <metadata name="Description">' + $nameEsc + '</metadata>' + "`n" +
' <metadata name="CreationDate">' + $date + '</metadata>' + "`n" +
' <metadata name="ModificationDate">' + $date + '</metadata>' + "`n" +
' <resources>' + "`n" +
'  <object id="3" p:UUID="' + $u3 + '" type="model">' + "`n" +
'   <components>' + "`n" +
'    <component p:path="/3D/Objects/object_1.model" objectid="1" p:UUID="' + $uc1 + '" transform="1 0 0 0 1 0 0 0 1 0 0 0"/>' + "`n" +
'    <component p:path="/3D/Objects/object_2.model" objectid="2" p:UUID="' + $uc2 + '" transform="1 0 0 0 1 0 0 0 1 0 0 0"/>' + "`n" +
'   </components>' + "`n" +
'  </object>' + "`n" +
' </resources>' + "`n" +
' <build p:UUID="' + $ub + '">' + "`n" +
'  <item objectid="3" p:UUID="' + $ui + '" transform="1 0 0 0 1 0 0 0 1 0 0 0" printable="1"/>' + "`n" +
' </build>' + "`n" +
'</model>'

    $objFile1 = ObjectModelFile 1 $u1 $whiteVerts
    $objFile2 = ObjectModelFile 2 $u2 $blackVerts

    $objRels = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" +
'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + "`n" +
' <Relationship Target="/3D/Objects/object_1.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>' + "`n" +
' <Relationship Target="/3D/Objects/object_2.model" Id="rel-2" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>' + "`n" +
'</Relationships>'

    $cfgXml = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" +
'<config>' + "`n" +
' <object id="3">' + "`n" +
'  <metadata key="name" value="' + $nameEsc + '"/>' + "`n" +
'  <part id="1" subtype="normal_part">' + "`n" +
'   <metadata key="name" value="白色底板"/>' + "`n" +
'   <metadata key="extruder" value="1"/>' + "`n" +
'   <mesh_stat edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0"/>' + "`n" +
'  </part>' + "`n" +
'  <part id="2" subtype="normal_part">' + "`n" +
'   <metadata key="name" value="黑色格片"/>' + "`n" +
'   <metadata key="extruder" value="2"/>' + "`n" +
'   <mesh_stat edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0"/>' + "`n" +
'  </part>' + "`n" +
' </object>' + "`n" +
'</config>'

    $contentTypes = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" +
'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' + "`n" +
' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' + "`n" +
' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>' + "`n" +
' <Default Extension="config" ContentType="application/octet-stream"/>' + "`n" +
' <Default Extension="png" ContentType="image/png"/>' + "`n" +
'</Types>'
    $rootRels = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" +
'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + "`n" +
' <Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>' + "`n" +
'</Relationships>'

    $fs = [System.IO.File]::Open($path,[System.IO.FileMode]::Create)
    $zip = New-Object System.IO.Compression.ZipArchive($fs,[System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($pair in @(
            @('[Content_Types].xml',$contentTypes),
            @('_rels/.rels',$rootRels),
            @('3D/3dmodel.model',$mainModel),
            @('3D/_rels/3dmodel.model.rels',$objRels),
            @('3D/Objects/object_1.model',$objFile1),
            @('3D/Objects/object_2.model',$objFile2),
            @('Metadata/model_settings.config',$cfgXml),
            @('Metadata/project_settings.config',$projectSettings)
        )) {
            $entry = $zip.CreateEntry($pair[0],[System.IO.Compression.CompressionLevel]::Optimal)
            $sw = New-Object System.IO.StreamWriter($entry.Open(),(New-Object System.Text.UTF8Encoding($false)))
            try { $sw.Write($pair[1]) } finally { $sw.Dispose() }
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
    return $totalTri
}

# ---------- 载入参数 ----------
$loadButton.Add_Click({
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = '参数预设 (*.json)|*.json'
    $fileDialog.InitialDirectory = $PSScriptRoot
    if ($fileDialog.ShowDialog() -ne 'OK') { return }
    try {
        $data = Get-Content -LiteralPath $fileDialog.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        $sets = @($data.parameterSets.PSObject.Properties)
        if ($sets.Count -eq 0) { throw '没有找到参数预设。请选择生成器保存的 checkerboard.json。' }
        $selected = 0
        if ($sets.Count -gt 1) {
            $picker = New-Object System.Windows.Forms.Form
            $picker.Text = '选择规格预设'
            $picker.ClientSize = New-Object System.Drawing.Size(420,112)
            $picker.StartPosition = 'CenterParent'
            $picker.Font = $form.Font
            $picker.FormBorderStyle = 'FixedDialog'
            $picker.MaximizeBox = $false
            $list = New-Object System.Windows.Forms.ComboBox
            $list.DropDownStyle = 'DropDownList'
            $list.FlatStyle = 'Flat'
            $list.Location = New-Object System.Drawing.Point(16,16)
            $list.Size = New-Object System.Drawing.Size(385,30)
            $list.Items.AddRange([object[]]@($sets | ForEach-Object { $_.Name }))
            $list.SelectedIndex = 0
            $picker.Controls.Add($list)
            $ok = New-Object System.Windows.Forms.Button
            $ok.Text = '载入'
            $ok.Location = New-Object System.Drawing.Point(290,62)
            $ok.Size = New-Object System.Drawing.Size(110,32)
            $ok.DialogResult = 'OK'
            $picker.Controls.Add($ok)
            $picker.AcceptButton = $ok
            if ($picker.ShowDialog($form) -ne 'OK') { $picker.Dispose(); return }
            $selected = $list.SelectedIndex
            $picker.Dispose()
        }
        $p = $sets[$selected].Value
        $mapping = @{
            columns=$cols;rows=$rows;square_size=$square;border=$border;outer_width=$width;outer_height=$height
            base_thickness=$base;pattern_thickness=$depth;inlay_taper=$taper;corner_relief=$relief
        }
        foreach ($key in $mapping.Keys) {
            if ($null -ne $p.$key) {
                $v = [decimal]::Parse([string]$p.$key,[System.Globalization.CultureInfo]::InvariantCulture)
                if ($v -lt $mapping[$key].Minimum -or $v -gt $mapping[$key].Maximum) { throw ('参数超出范围：'+$key) }
            }
        }
        if ([string]$p.count_mode -notin @('squares','inner_corners') -or [string]$p.size_mode -notin @('square','outer')) { throw '无法识别参数的数量或尺寸模式。' }
        foreach ($key in $mapping.Keys) {
            if ($null -ne $p.$key) { $mapping[$key].Value = [decimal]::Parse([string]$p.$key,[System.Globalization.CultureInfo]::InvariantCulture) }
        }
        $count.SelectedIndex = [int]($p.count_mode -eq 'inner_corners')
        $sizeMode.SelectedIndex = [int]($p.size_mode -eq 'outer')
        if ($null -ne $p.black_at_origin) { $blackOrigin.Checked = [bool]::Parse([string]$p.black_at_origin) }
        UpdatePreview
        SetStatus ('已载入：'+$sets[$selected].Name) 'ok'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'载入失败') | Out-Null
    } finally { $fileDialog.Dispose() }
})

# ---------- 生成导出 ----------
$button.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择输出文件夹。每次生成会创建一个新的规格子文件夹。'
    $dialog.SelectedPath = $PSScriptRoot
    if ($CheckOnly) {
        $dialog.SelectedPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.calibration-tools\gui-smoke'
        New-Item -ItemType Directory -Path $dialog.SelectedPath -Force | Out-Null
    } elseif ($dialog.ShowDialog() -ne 'OK') { return }
    $g = CurrentGeometry
    $stem = '棋盘_{0}x{1}_单格{2}mm_{3}' -f $g.nx,$g.ny,(ScadNumber $g.s),(Get-Date -Format 'yyyyMMdd_HHmmss_fff')
    $out = Join-Path $dialog.SelectedPath $stem
    $button.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        New-Item -ItemType Directory -Path $out | Out-Null
        $values = [ordered]@{
            count_mode=@('squares','inner_corners')[$count.SelectedIndex]; columns=(ScadNumber $cols.Value); rows=(ScadNumber $rows.Value)
            size_mode=@('square','outer')[$sizeMode.SelectedIndex]; square_size=(ScadNumber $square.Value); border=(ScadNumber $border.Value)
            outer_width=(ScadNumber $width.Value); outer_height=(ScadNumber $height.Value)
            base_thickness=(ScadNumber $base.Value); pattern_thickness=(ScadNumber $depth.Value)
            inlay_taper=(ScadNumber $taper.Value); corner_relief=(ScadNumber $relief.Value)
            black_at_origin=$blackOrigin.Checked.ToString().ToLowerInvariant(); export_part='preview'
        }
        $presetFile = Join-Path $out 'checkerboard.json'
        SavePreset $presetFile $values
        Copy-Item -LiteralPath $template -Destination (Join-Path $out 'checkerboard.scad')
        $logPath = Join-Path $out '导出日志.txt'
        foreach ($part in @('white','black')) {
            SetStatus ('正在生成 ' + @{'white'='白色底板';'black'='黑色格子'}[$part] + '，请稍候…') ''
            [System.Windows.Forms.Application]::DoEvents()
            $stl = Join-Path $out ($part+'.stl')
            $values.export_part = $part
            SavePreset $presetFile $values
            $argsList = @('-o',$stl,'-p',$presetFile,'-P','saved',$template)
            $oldPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $log = & $engine @argsList 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = $oldPreference
            $logText = $log | Out-String
            $logText | Add-Content -LiteralPath $logPath -Encoding UTF8
            if ($code -ne 0 -or $logText -match 'ERROR:' -or -not (Test-Path -LiteralPath $stl)) { throw ('生成 '+$part+' 失败，请查看导出日志。') }
        }
        $values.export_part = 'preview'
        SavePreset $presetFile $values
        SetStatus '正在打包 3MF（封闭网格 · 黑白双色工程）…' ''
        [System.Windows.Forms.Application]::DoEvents()
        $whiteVerts = Read-StlTriangles (Join-Path $out 'white.stl')
        $blackVerts = Read-StlTriangles (Join-Path $out 'black.stl')
        $threeMfName = '棋盘_{0}x{1}_单格{2}mm.3mf' -f $g.nx,$g.ny,(ScadNumber $g.s)
        $threeMfPath = Join-Path $out $threeMfName
        $triCount = New-ThreeMf $threeMfPath $threeMfName $whiteVerts $blackVerts
        if (-not (Test-Path -LiteralPath $threeMfPath)) { throw '生成 3MF 失败。' }
        ('3MF: ' + $threeMfName + ' volumes=2 (extruder 1=白, 2=黑), triangles=' + $triCount) | Add-Content -LiteralPath $logPath -Encoding UTF8
        @"
棋盘标定板规格（单位 mm）
横向格子数：$($g.nx)
纵向格子数：$($g.ny)
内角点（列，行）：$($g.nx-1), $($g.ny-1)
单格边长（理论格距）：$(ScadNumber $g.s)
整板：$(ScadNumber $g.w) x $(ScadNumber $g.h) x $(ScadNumber $g.z)
左右白边：$(ScadNumber $g.mx)
上下白边：$(ScadNumber $g.my)
角点微切角：$(ScadNumber $relief.Value)

【拓竹 Bambu Studio（推荐）】直接打开 $($threeMfName)：
已包含白色与黑色两个 Generic PLA 耗材槽位：白色=1，黑色=2。
网格使用共享顶点，黑白部件保持齐平与原始相对位置。
切片前按实际设备选择打印机、喷嘴和耗材类型，并核对 AMS 槽位。

【其他切片软件】同时选中 white.stl 与 black.stl 导入，作为一个多零件对象载入，
white 分配白色耗材，black 分配黑色耗材。不要单独居中或自动摆盘。
黑白表面位于同一平面。标定前实测格距并检查平整度。
checkerboard.json 可以与本文件夹的 checkerboard.scad 配合复用。
"@ | Set-Content -LiteralPath (Join-Path $out '规格说明.txt') -Encoding UTF8
        SetStatus ('生成完成：' + $out) 'ok'
        if ($CheckOnly) { Write-Output ('GUI export OK: '+$out) }
        else {
            [System.Windows.Forms.MessageBox]::Show("已生成 $($threeMfName) 与 white.stl、black.stl。`r`n拓竹 Bambu Studio 可直接打开 3MF：单零件、黑白双色已分配（1=白，2=黑)。",'生成完成') | Out-Null
            Start-Process explorer.exe -ArgumentList ('"'+$out+'"')
        }
    } catch {
        SetStatus ('生成失败：' + $_.Exception.Message) 'err'
        if ($CheckOnly) { throw }
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'生成失败') | Out-Null
    } finally {
        $form.UseWaitCursor = $false
        $button.Enabled = $true
        $dialog.Dispose()
    }
})

UpdatePreview
if ($CheckOnly) {
    $g = CurrentGeometry
    if ($g.nx -ne 10 -or $g.ny -ne 7 -or $g.s -ne 20 -or $g.w -ne 240 -or $g.h -ne 180) { throw 'Default geometry mismatch' }
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point(-10000,-10000)
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    $bitmap = New-Object System.Drawing.Bitmap($form.Width,$form.Height)
    $rect = New-Object System.Drawing.Rectangle(0,0,$form.Width,$form.Height)
    $form.DrawToBitmap($bitmap,$rect)
    $bitmap.Save((Join-Path $PSScriptRoot '生成器预览.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $count.SelectedIndex = 1
    $cols.Value = 9
    $rows.Value = 6
    $g = CurrentGeometry
    if ($g.nx -ne 10 -or $g.ny -ne 7) { throw 'Inner-corner geometry mismatch' }
    $count.SelectedIndex = 0
    $cols.Value = 10
    $rows.Value = 7
    $sizeMode.SelectedIndex = 1
    $border.Value = 15
    $width.Value = 220
    $height.Value = 180
    $g = CurrentGeometry
    if ($g.s -ne 19 -or $g.mx -ne 15 -or $g.my -ne 23.5) { throw 'Outer-size geometry mismatch' }
    $width.Value = 20
    if ($button.Enabled) { throw 'Invalid dimensions were not blocked' }
    $width.Value = 240
    $border.Value = 20
    $sizeMode.SelectedIndex = 0
    $button.PerformClick()
    # ---- 校验刚生成的 3MF 结构（zip 条目、XML、volume/extruder 映射）----
    $smoke = Join-Path (Split-Path $PSScriptRoot -Parent) '.calibration-tools\gui-smoke'
    $latest = Get-ChildItem -LiteralPath $smoke -Directory | Sort-Object LastWriteTime | Select-Object -Last 1
    $mf3 = Get-ChildItem -LiteralPath $latest.FullName -Filter '*.3mf' | Select-Object -First 1
    if ($null -eq $mf3) { throw '3MF not produced' }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($mf3.FullName)
    try {
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
        foreach ($need in @('[Content_Types].xml','_rels/.rels','3D/3dmodel.model','3D/_rels/3dmodel.model.rels','3D/Objects/object_1.model','3D/Objects/object_2.model','Metadata/model_settings.config','Metadata/project_settings.config')) {
            if ($names -notcontains $need) { throw ('3MF missing entry: '+$need) }
        }
        $modelDoc = New-Object System.Xml.XmlDocument
        $mr = New-Object System.IO.StreamReader($zip.GetEntry('3D/3dmodel.model').Open())
        try { $modelDoc.LoadXml($mr.ReadToEnd()) } finally { $mr.Dispose() }
        $obj1Doc = New-Object System.Xml.XmlDocument
        $r1 = New-Object System.IO.StreamReader($zip.GetEntry('3D/Objects/object_1.model').Open())
        try { $obj1Doc.LoadXml($r1.ReadToEnd()) } finally { $r1.Dispose() }
        $obj2Doc = New-Object System.Xml.XmlDocument
        $r2 = New-Object System.IO.StreamReader($zip.GetEntry('3D/Objects/object_2.model').Open())
        try { $obj2Doc.LoadXml($r2.ReadToEnd()) } finally { $r2.Dispose() }
        $cfgDoc = New-Object System.Xml.XmlDocument
        $cr = New-Object System.IO.StreamReader($zip.GetEntry('Metadata/model_settings.config').Open())
        try { $cfgDoc.LoadXml($cr.ReadToEnd()) } finally { $cr.Dispose() }
        $pr = New-Object System.IO.StreamReader($zip.GetEntry('Metadata/project_settings.config').Open())
        try { $colourConfig = $pr.ReadToEnd() | ConvertFrom-Json } finally { $pr.Dispose() }
    } finally { $zip.Dispose() }
    $nsm = New-Object System.Xml.XmlNamespaceManager($modelDoc.NameTable)
    $null = $nsm.AddNamespace('m','http://schemas.microsoft.com/3dmanufacturing/core/2015/02')
    if ($modelDoc.SelectNodes('//m:object',$nsm).Count -ne 1) { throw '3MF main object count mismatch' }
    $compNodes = $modelDoc.SelectNodes('//m:component',$nsm)
    if ($compNodes.Count -ne 2) { throw '3MF component count mismatch' }
    if ($compNodes[0].GetAttribute('objectid') -ne '1' -or $compNodes[1].GetAttribute('objectid') -ne '2') { throw '3MF component objectid mismatch' }
    $itemNode = $modelDoc.SelectNodes('//m:item',$nsm)
    if ($itemNode.Count -ne 1 -or $itemNode[0].GetAttribute('objectid') -ne '3' -or $itemNode[0].GetAttribute('printable') -ne '1') { throw '3MF build item mismatch' }
    $n1 = New-Object System.Xml.XmlNamespaceManager($obj1Doc.NameTable)
    $null = $n1.AddNamespace('m','http://schemas.microsoft.com/3dmanufacturing/core/2015/02')
    if ($obj1Doc.SelectNodes('//m:vertex',$n1).Count -ne 568) { throw '3MF white shared vertex count mismatch' }
    if ($obj1Doc.SelectNodes('//m:triangle',$n1).Count -ne 1132) { throw '3MF white triangle count mismatch' }
    $n2 = New-Object System.Xml.XmlNamespaceManager($obj2Doc.NameTable)
    $null = $n2.AddNamespace('m','http://schemas.microsoft.com/3dmanufacturing/core/2015/02')
    if ($obj2Doc.SelectNodes('//m:vertex',$n2).Count -ne 560) { throw '3MF black shared vertex count mismatch' }
    if ($obj2Doc.SelectNodes('//m:triangle',$n2).Count -ne 980) { throw '3MF black triangle count mismatch' }
    if ($cfgDoc.GetElementsByTagName('object').Count -ne 1) { throw '3MF config object count mismatch' }
    $objNode = $cfgDoc.GetElementsByTagName('object')[0]
    if ($objNode.GetAttribute('id') -ne '3') { throw '3MF config object id mismatch' }
    $parts = $objNode.SelectNodes('part')
    if ($parts.Count -ne 2) { throw '3MF part count mismatch' }
    if ($parts[0].GetAttribute('id') -ne '1' -or $parts[1].GetAttribute('id') -ne '2') { throw '3MF part id mismatch' }
    $p1e = $parts[0].SelectSingleNode("metadata[@key='extruder']").GetAttribute('value')
    $p2e = $parts[1].SelectSingleNode("metadata[@key='extruder']").GetAttribute('value')
    if ($p1e -ne '1' -or $p2e -ne '2') { throw '3MF extruder mapping mismatch' }
    if ($colourConfig.filament_colour[0] -ne '#FFFFFF' -or $colourConfig.filament_colour[1] -ne '#000000' -or $colourConfig.filament_settings_id.Count -lt 2) { throw '3MF actual filament palette mismatch' }
    $form.Dispose()
    Write-Output ('3MF verified: 2 object files (1132/980 tris), parts=2 extruders 1/2. File: ' + $mf3.Name)
    Write-Output 'GUI initialization, sizing modes, invalid-input blocking and actual export OK.'
    exit 0
}
[void]$form.ShowDialog()
$form.Dispose()
