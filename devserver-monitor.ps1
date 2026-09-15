# Dev Server 监视器 (Windows 版)
# 双击 "启动监视器.bat" 运行, 或用:
#   powershell -ExecutionPolicy Bypass -File devserver-monitor.ps1
# 需要 Windows 8 / PowerShell 5 及以上 (Win10/Win11 自带)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:matchNames = @('node', 'bun', 'deno', 'python', 'ruby', 'php', 'serve', 'http-server')

function Get-DevServers {
    $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
    $seen = @{}
    $list = @()
    foreach ($c in $conns) {
        $procId = $c.OwningProcess
        $port = $c.LocalPort
        $key = "$procId`:$port"
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        $pname = $p.ProcessName.ToLower()
        $matched = $false
        foreach ($n in $script:matchNames) {
            if ($pname.StartsWith($n)) { $matched = $true; break }
        }
        if (-not $matched) { continue }

        # 从命令行里推测项目名: 取 node_modules 上一级目录名
        $project = $pname
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction Stop).CommandLine
            if ($cmd -match '([A-Za-z]:\\[^"'']+?)\\node_modules\\') {
                $project = Split-Path $Matches[1] -Leaf
            }
        } catch {}
        $list += [pscustomobject]@{ Port = $port; PID = $procId; Project = $project }
    }
    $list | Sort-Object Port
}

$bg      = [System.Drawing.Color]::FromArgb(30, 31, 36)
$fg      = [System.Drawing.Color]::FromArgb(230, 230, 230)
$dim     = [System.Drawing.Color]::FromArgb(154, 154, 154)
$orange  = [System.Drawing.Color]::FromArgb(240, 198, 116)
$red     = [System.Drawing.Color]::FromArgb(194, 69, 45)
$gray    = [System.Drawing.Color]::FromArgb(58, 59, 65)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Dev Server 监视器'
$form.TopMost = $true
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(360, 260)
$form.MinimumSize = New-Object System.Drawing.Size(300, 150)
$form.BackColor = $bg
$form.ForeColor = $fg
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 36
$header.BackColor = $bg

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Dev Server'
$titleLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $fg
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(10, 9)

$countLabel = New-Object System.Windows.Forms.Label
$countLabel.Text = ''
$countLabel.ForeColor = $dim
$countLabel.AutoSize = $true
$countLabel.Location = New-Object System.Drawing.Point(100, 11)

function New-FlatButton($text, $color, $x) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.FlatStyle = 'Flat'
    $b.BackColor = $color
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderSize = 0
    $b.Size = New-Object System.Drawing.Size(58, 22)
    $b.Location = New-Object System.Drawing.Point($x, 7)
    $b.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
    return $b
}

$refreshBtn = New-FlatButton '刷新' $gray 220
$killAllBtn = New-FlatButton '全部关闭' $red 284
$header.Controls.AddRange(@($titleLabel, $countLabel, $refreshBtn, $killAllBtn))
$header.Add_Resize({
    $refreshBtn.Left = $header.Width - 140
    $killAllBtn.Left = $header.Width - 76
})

$listPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$listPanel.Dock = 'Fill'
$listPanel.FlowDirection = 'TopDown'
$listPanel.WrapContents = $false
$listPanel.AutoScroll = $true
$listPanel.BackColor = $bg
$listPanel.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 6)

function Refresh-List {
    $listPanel.Controls.Clear()
    $servers = @(Get-DevServers)
    $countLabel.Text = "$($servers.Count) 个运行中"
    if ($servers.Count -eq 0) {
        $empty = New-Object System.Windows.Forms.Label
        $empty.Text = '没有正在运行的 dev server'
        $empty.ForeColor = $dim
        $empty.AutoSize = $true
        $empty.Margin = New-Object System.Windows.Forms.Padding(8, 10, 0, 0)
        $listPanel.Controls.Add($empty)
        return
    }
    foreach ($s in $servers) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Width = $listPanel.ClientSize.Width - 28
        $row.Height = 26
        $row.BackColor = $bg
        $row.Margin = New-Object System.Windows.Forms.Padding(2, 3, 2, 3)

        $portLabel = New-Object System.Windows.Forms.Label
        $portLabel.Text = ":$($s.Port)"
        $portLabel.ForeColor = $orange
        $portLabel.Font = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Bold)
        $portLabel.AutoSize = $true
        $portLabel.Location = New-Object System.Drawing.Point(4, 5)

        $projLabel = New-Object System.Windows.Forms.Label
        $projLabel.Text = $s.Project
        $projLabel.ForeColor = $fg
        $projLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
        $projLabel.AutoEllipsis = $true
        $projLabel.Location = New-Object System.Drawing.Point(70, 5)
        $projLabel.Size = New-Object System.Drawing.Size(170, 18)

        $closeBtn = New-Object System.Windows.Forms.Button
        $closeBtn.Text = '关闭'
        $closeBtn.FlatStyle = 'Flat'
        $closeBtn.BackColor = $red
        $closeBtn.ForeColor = [System.Drawing.Color]::White
        $closeBtn.FlatAppearance.BorderSize = 0
        $closeBtn.Size = New-Object System.Drawing.Size(46, 20)
        $closeBtn.Location = New-Object System.Drawing.Point(($row.Width - 52), 3)
        $closeBtn.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
        $closeBtn.Anchor = 'Top, Right'
        $closeBtn.Tag = $s.PID
        $closeBtn.Add_Click({
            Stop-Process -Id $this.Tag -Force -ErrorAction SilentlyContinue
            Refresh-List
        })

        $row.Controls.AddRange(@($portLabel, $projLabel, $closeBtn))
        $listPanel.Controls.Add($row)
    }
}

$refreshBtn.Add_Click({ Refresh-List })
$killAllBtn.Add_Click({
    foreach ($s in @(Get-DevServers)) {
        Stop-Process -Id $s.PID -Force -ErrorAction SilentlyContinue
    }
    Refresh-List
})

$split = New-Object System.Windows.Forms.Panel
$split.Dock = 'Top'
$split.Height = 1
$split.BackColor = [System.Drawing.Color]::FromArgb(60, 61, 67)

$form.Controls.Add($listPanel)
$form.Controls.Add($split)
$form.Controls.Add($header)

Refresh-List
[void]$form.ShowDialog()
