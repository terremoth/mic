Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$iniFile = Join-Path $scriptDir "mediainfo.ini"

$global:ffmpegPath = ""
$global:ffprobePath = ""

function Save-INI {
    @"
[Paths]
ffmpeg=$global:ffmpegPath
ffprobe=$global:ffprobePath
"@ | Set-Content -Path $iniFile -Encoding UTF8
}

function Load-INI {
    if (Test-Path $iniFile) {
        $content = Get-Content $iniFile
        foreach ($line in $content) {
            if ($line -match '^ffmpeg=(.+)$') { $global:ffmpegPath = $Matches[1] }
            elseif ($line -match '^ffprobe=(.+)$') { $global:ffprobePath = $Matches[1] }
        }
    }
}

function Validate-Executables {

    if ([string]::IsNullOrEmpty($global:ffmpegPath) -or [string]::IsNullOrEmpty($global:ffprobePath)) {
        return $false
    }
    if (-not (Test-Path $global:ffmpegPath)) { return $false }
    if (-not (Test-Path $global:ffprobePath)) { return $false }
    return $true
}

# Detect executables in same folder
if (Test-Path (Join-Path $scriptDir "ffmpeg.exe")) { $global:ffmpegPath = Join-Path $scriptDir "ffmpeg.exe" }
if (Test-Path (Join-Path $scriptDir "ffprobe.exe")) { $global:ffprobePath = Join-Path $scriptDir "ffprobe.exe" }

Load-INI

# --- UI ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Media Info Comparison"
$form.WindowState = "Maximized"
$form.StartPosition = "CenterScreen"
$form.AllowDrop = $true
$form.MinimumSize = New-Object System.Drawing.Size(800,600)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Media Info Comparison"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($lblTitle)

$linkAuthor = New-Object System.Windows.Forms.LinkLabel
$linkAuthor.Text = "by Terremoth (https://github.com/terremoth/mic)"
$linkAuthor.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
$linkAuthor.AutoSize = $true
$linkAuthor.Location = New-Object System.Drawing.Point(30, 60)
[void]$linkAuthor.Links.Add(3, 44, "https://github.com/terremoth/mic")
$form.Controls.Add($linkAuthor)

# Evento para abrir o link no navegador padrão
$linkAuthor.Add_LinkClicked({
    param($sender, $e)
    Start-Process $e.Link.LinkData
})

$lblFFMPEG = New-Object System.Windows.Forms.Label
$lblFFMPEG.Text = "FFMPEG location:"
$lblFFMPEG.Location = New-Object System.Drawing.Point(10, 100)
$lblFFMPEG.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblFFMPEG)

$txtFFMPEG = New-Object System.Windows.Forms.TextBox
$txtFFMPEG.Location = New-Object System.Drawing.Point(160, 100)
$txtFFMPEG.Width = 400
$txtFFMPEG.ReadOnly = $true
$form.Controls.Add($txtFFMPEG)

$btnLoadFFMPEG = New-Object System.Windows.Forms.Button
$btnLoadFFMPEG.Text = "Load"
$btnLoadFFMPEG.Location = New-Object System.Drawing.Point(570, 100)
$btnLoadFFMPEG.Size = New-Object System.Drawing.Size(60, 22)
$form.Controls.Add($btnLoadFFMPEG)

# FFPROBE label + textbox + load
$lblFFPROBE = New-Object System.Windows.Forms.Label
$lblFFPROBE.Text = "FFPROBE location:"
$lblFFPROBE.Location = New-Object System.Drawing.Point(10, 130)
$lblFFPROBE.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblFFPROBE)

$txtFFPROBE = New-Object System.Windows.Forms.TextBox
$txtFFPROBE.Location = New-Object System.Drawing.Point(160, 130)
$txtFFPROBE.Width = 400
$txtFFPROBE.ReadOnly = $true
$form.Controls.Add($txtFFPROBE)

$btnLoadFFPROBE = New-Object System.Windows.Forms.Button
$btnLoadFFPROBE.Text = "Load"
$btnLoadFFPROBE.Location = New-Object System.Drawing.Point(570, 130)
$btnLoadFFPROBE.Size = New-Object System.Drawing.Size(60, 22)
$form.Controls.Add($btnLoadFFPROBE)

# Botão Select
$btnSelect = New-Object System.Windows.Forms.Button
$btnSelect.Text = "Select Video Files"
$btnSelect.Size = New-Object System.Drawing.Size(200, 40)
$btnSelect.Location = New-Object System.Drawing.Point(10, 160)
$form.Controls.Add($btnSelect)

# ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$listView.OwnerDraw = $true
$listView.AllowColumnReorder = $true

function Resize-ListView {
    $lvTop = $btnSelect.Bottom + 10
    $lvWidth = $form.ClientSize.Width - 20
    $lvHeight = $form.ClientSize.Height - $lvTop - 10

    $listView.Location = New-Object System.Drawing.Point(10, $lvTop)
    $listView.Size = New-Object System.Drawing.Size($lvWidth, $lvHeight)
}
Resize-ListView
$form.Controls.Add($listView)
$form.Add_Resize({ Resize-ListView })

$listView.Add_DrawColumnHeader({ $_.DrawDefault = $true })
$listView.Add_DrawSubItem({ $_.DrawBackground(); $_.DrawText() })

$txtFFMPEG.Text = $global:ffmpegPath
$txtFFPROBE.Text = $global:ffprobePath

function Update-ButtonState {
    $btnSelect.Enabled = Validate-Executables
}
Update-ButtonState

$btnLoadFFMPEG.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "FFMPEG|ffmpeg.exe"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:ffmpegPath = $ofd.FileName
        $txtFFMPEG.Text = $global:ffmpegPath
        
        # Se ffprobe estiver na mesma pasta
        $possibleFFPROBE = Join-Path (Split-Path $global:ffmpegPath) "ffprobe.exe"
        if (Test-Path $possibleFFPROBE) {
            $global:ffprobePath = $possibleFFPROBE
            $txtFFPROBE.Text = $global:ffprobePath
        }
        Save-INI
        Update-ButtonState
    }
})

$btnLoadFFPROBE.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "FFPROBE|ffprobe.exe"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:ffprobePath = $ofd.FileName
        $txtFFPROBE.Text = $global:ffprobePath
        Save-INI
        Update-ButtonState
    }
})

function Get-MediaInfo($filepath) {
    $tmp_stream = Join-Path $env:TEMP "ffprobe_stream.tmp"
    $tmp_format = Join-Path $env:TEMP "ffprobe_format.tmp"

    & $global:ffprobePath -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1:nokey=0 "$filepath" > $tmp_stream
    & $global:ffprobePath -v error -show_entries format=duration,bit_rate -of default=noprint_wrappers=1:nokey=0 "$filepath" > $tmp_format

    $codec = $width = $height = $fps = $duration = $bitrate = $null

    Get-Content $tmp_stream | ForEach-Object {
        if ($_ -match '^codec_name=(.+)$') { $codec = $Matches[1] }
        elseif ($_ -match '^width=(\d+)$') { $width = [int]$Matches[1] }
        elseif ($_ -match '^height=(\d+)$') { $height = [int]$Matches[1] }
        elseif ($_ -match '^r_frame_rate=(.+)$') {
            $fps_raw = $Matches[1]
            if ($fps_raw -match '^(\d+)/(\d+)$') {
                $fps = [math]::Round([double]$Matches[1] / [double]$Matches[2], 2)
            } else { $fps = $fps_raw }
        }
    }

    Get-Content $tmp_format | ForEach-Object {
        if ($_ -match '^duration=(.+)$') { $duration = [double]$Matches[1] }
        elseif ($_ -match '^bit_rate=(.+)$') { $bitrate = $Matches[1] }
    }

    $resolvedPath = $filepath
    if (Test-Path $filepath) {
        try { $resolvedPath = (Resolve-Path $filepath -ErrorAction Stop).Path } catch {}
    }

    $fileInfo = Get-Item -LiteralPath $resolvedPath
    $fileName = $fileInfo.Name
    $size_bytes = $fileInfo.Length
    $size_mb = [math]::Round($size_bytes / 1MB, 2)
    $created = $fileInfo.CreationTime
    $modified = $fileInfo.LastWriteTime

    $duration_formatted = ""
    if ($duration) {
        $total_secs = [int][math]::Floor($duration)
        $hours = [int]($total_secs / 3600)
        $mins = [int](($total_secs % 3600) / 60)
        $secs = $total_secs % 60
        if ($hours -gt 0) { $duration_formatted += "${hours}h" }
        if ($mins -gt 0) { $duration_formatted += "${mins}m" }
        $duration_formatted += "${secs}s"
    }

    Remove-Item $tmp_stream, $tmp_format -ErrorAction SilentlyContinue

    return @{
        "File"        = $fileName
        "Format"      = [System.IO.Path]::GetExtension($fileInfo.Name).TrimStart('.')
        "Codec"       = $codec
        "Width"       = $width
        "Height"      = $height
        "FPS"         = $fps
        "Duration"    = $duration
        "DurationFmt" = $duration_formatted
        "Bitrate"     = [double]$bitrate
        "Size"        = $size_bytes
        "TotalSize"   = "$size_bytes bytes (~$size_mb MB)"
        "Created"     = $created
        "Modified"    = $modified
    }
}

function Compare-And-Highlight($infos) {
    $listView.Clear()

    $totalCols = $infos.Count + 1
    $colWidth = [int](($listView.ClientSize.Width - 20) / $totalCols)
    if ($colWidth -lt 100) { $colWidth = 100 }

    $listView.Columns.Add("Property", $colWidth) | Out-Null
    foreach ($info in $infos) {
        $listView.Columns.Add($info["File"], $colWidth) | Out-Null
    }

    $properties = @("Codec","Format","Width","Height","FPS","Duration","Bitrate","TotalSize","Created","Modified")
    foreach ($prop in $properties) {
        $row = New-Object System.Windows.Forms.ListViewItem($prop)
        foreach ($info in $infos) {
            switch ($prop) {
                "Duration" { $row.SubItems.Add("$($info[$prop]) sec ($($info["DurationFmt"]))") | Out-Null }
                default    { $row.SubItems.Add($info[$prop].ToString()) | Out-Null }
            }
        }
        $listView.Items.Add($row) | Out-Null
    }

    $compareProps = @("Width","Height","FPS","Duration","Bitrate","Size","Created","Modified")
    for ($i=0; $i -lt $compareProps.Count; $i++) {
        $prop = $compareProps[$i]
        if ($prop -eq "Size") {
            $rowIndex = $properties.IndexOf("TotalSize")
        } elseif ($properties.IndexOf($prop) -ne -1) {
            $rowIndex = $properties.IndexOf($prop)
        } else {
            $rowIndex = $properties.IndexOf("TotalSize")
        }

        $bestIndex = @()
        $bestValue = $null

        for ($j=0; $j -lt $infos.Count; $j++) {
            $value = $infos[$j][$prop]
            if ($value -is [datetime]) {
                if ($bestValue -eq $null -or $value -gt $bestValue) {
                    $bestValue = $value
                    $bestIndex = @($j)
                } elseif ($value -eq $bestValue) { $bestIndex += $j }
            } else {
                if ($bestValue -eq $null -or $value -gt $bestValue) {
                    $bestValue = $value
                    $bestIndex = @($j)
                } elseif ($value -eq $bestValue) { $bestIndex += $j }
            }
        }

        foreach ($idx in $bestIndex) {
            $cell = $listView.Items[$rowIndex].SubItems[$idx+1]
            $cell.BackColor = [System.Drawing.Color]::DarkGreen
            $cell.ForeColor = [System.Drawing.Color]::White
        }
    }
}

$btnSelect.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Video Files|*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.flv|All Files|*.*"
    $ofd.Multiselect = $true
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $infos = @()
        foreach ($file in $ofd.FileNames) {
            $infos += (Get-MediaInfo $file)
        }
        Compare-And-Highlight $infos
    }
})

[void]$form.ShowDialog()
