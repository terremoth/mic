# Media Info Comparison by Terremoth: https://github.com/terremoth

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

$iconPath = Join-Path $scriptDir "mediainfo.ico"
if (Test-Path $iconPath) {
    try {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
    } catch {
        # Dies silently without icon
    }
}

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
    $tmp_meta   = Join-Path $env:TEMP "ffprobe_meta.tmp"

    & $global:ffprobePath -v error -select_streams v:0 `
        -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,color_space,color_transfer,color_primaries,chroma_location,bits_per_raw_sample,gop_size `
        -of default=noprint_wrappers=1:nokey=0 "$filepath" > $tmp_stream

    & $global:ffprobePath -v error `
        -show_entries format=duration,bit_rate,format_long_name,major_brand `
        -of default=noprint_wrappers=1:nokey=0 "$filepath" > $tmp_format

    $info = @{
        "Profile" = $null; "Level" = $null; "ColorSpace" = $null; "ColorTransfer" = $null
        "ColorPrimaries" = $null; "ChromaLocation" = $null; "BitsPerRawSample" = $null;
    }

    $codec = $width = $height = $fps = $duration = $bitrate = $formatName = $null

    Get-Content $tmp_stream | ForEach-Object {
        if ($_ -match '^codec_name=(.+)$') { $codec = $Matches[1] }
        elseif ($_ -match '^profile=(.+)$') { $info["Profile"] = $Matches[1] }
        elseif ($_ -match '^level=(.+)$') { $info["Level"] = $Matches[1] }
        elseif ($_ -match '^width=(\d+)$') { $width = [int]$Matches[1] }
        elseif ($_ -match '^height=(\d+)$') { $height = [int]$Matches[1] }
        elseif ($_ -match '^r_frame_rate=(.+)$') {
            $fps_raw = $Matches[1]
            if ($fps_raw -match '^(\d+)/(\d+)$') {
                $fps = [math]::Round([double]$Matches[1] / [double]$Matches[2], 2)
            } else { $fps = $fps_raw }
        }
        elseif ($_ -match '^color_space=(.+)$') { $info["ColorSpace"] = $Matches[1] }
        elseif ($_ -match '^color_transfer=(.+)$') { $info["ColorTransfer"] = $Matches[1] }
        elseif ($_ -match '^color_primaries=(.+)$') { $info["ColorPrimaries"] = $Matches[1] }
        elseif ($_ -match '^chroma_location=(.+)$') { $info["ChromaLocation"] = $Matches[1] }
        elseif ($_ -match '^bits_per_raw_sample=(.+)$') { $info["BitsPerRawSample"] = $Matches[1] }
    }

    Get-Content $tmp_format | ForEach-Object {
        if ($_ -match '^duration=(.+)$') { $duration = [double]$Matches[1] }
        elseif ($_ -match '^bit_rate=(.+)$') { $bitrate = $Matches[1] }
        elseif ($_ -match '^format_long_name=(.+)$') { $formatName = $Matches[1] }
        elseif ($_ -match '^major_brand=(.+)$') { $info["MajorBrand"] = $Matches[1] }
    }

    $fileInfo = Get-Item -LiteralPath $filepath
    $size_bytes = $fileInfo.Length
    $size_mb = [math]::Round($size_bytes / 1MB, 2)

    $duration_fmt = ""
    if ($duration) {
        $total_secs = [int][math]::Floor($duration)
        $hours = [int]($total_secs / 3600)
        $mins = [int](($total_secs % 3600) / 60)
        $secs = $total_secs % 60
        if ($hours -gt 0) { $duration_fmt += "${hours}h" }
        if ($mins -gt 0) { $duration_fmt += "${mins}m" }
        $duration_fmt += "${secs}s"
    }

    $culture = Get-Culture
    $dateFormat = $culture.DateTimeFormat.ShortDatePattern + " " + $culture.DateTimeFormat.LongTimePattern

    Remove-Item $tmp_stream, $tmp_format, $tmp_meta -ErrorAction SilentlyContinue

    return @{
        "File"          = $fileInfo.Name
        "Format"        = [System.IO.Path]::GetExtension($fileInfo.Name).TrimStart('.')
        "Codec"         = $codec
        "Width"         = $width
        "Height"        = $height
        "FPS"           = $fps
        "Duration"      = $duration
        "DurationFmt"   = $duration_fmt
        "Bitrate"       = [double]$bitrate
        "Size"          = $size_bytes
        "TotalSize"     = "$size_bytes bytes (~$size_mb MB)"
        "Created"       = $fileInfo.CreationTime.ToString($dateFormat)
        "Modified"      = $fileInfo.LastWriteTime.ToString($dateFormat)
        "CreatedRaw"    = $fileInfo.CreationTime
        "ModifiedRaw"   = $fileInfo.LastWriteTime
    } + $info
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

    $properties = @(
        "Codec","Format","Profile","Level","Width","Height","FPS",
        "Duration","Bitrate","TotalSize","ColorSpace","ColorTransfer",
        "ColorPrimaries","ChromaLocation","BitsPerRawSample",
        "Created","Modified"
    )

    foreach ($prop in $properties) {
        $row = New-Object System.Windows.Forms.ListViewItem($prop)
        foreach ($info in $infos) {
            switch ($prop) {
                "Duration" { 
                    $row.SubItems.Add("$($info[$prop]) sec ($($info["DurationFmt"]))") | Out-Null 
                }
                default { 
                    $row.SubItems.Add($info[$prop].ToString()) | Out-Null 
                }
            }
        }
        $listView.Items.Add($row) | Out-Null
    }

    $compareProps = @("Width","Height","FPS","Duration","Bitrate","Size","Created","Modified")
    $culture = Get-Culture
    $dateFormat = $culture.DateTimeFormat.ShortDatePattern + " " + $culture.DateTimeFormat.LongTimePattern

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
        $worstIndex = @()
        $bestValue = $null
        $worstValue = $null
        $isDate = ($prop -eq "Created" -or $prop -eq "Modified")

        for ($j=0; $j -lt $infos.Count; $j++) {
            $value = $infos[$j][$prop]

            if ($isDate) {
                try {
                    $dt = [DateTime]::ParseExact($value, $dateFormat, $culture)
                    $seconds = [int]($dt - [DateTime]'1970-01-01').TotalSeconds
                } catch {
                    $seconds = 0
                }

                # Best = mais antigo (menor timestamp)
                if ($bestValue -eq $null -or $seconds -lt $bestValue) {
                    $bestValue = $seconds
                    $bestIndex = @($j)
                } elseif ($seconds -eq $bestValue) {
                    $bestIndex += $j
                }

                # Worst = mais recente (maior timestamp)
                if ($worstValue -eq $null -or $seconds -gt $worstValue) {
                    $worstValue = $seconds
                    $worstIndex = @($j)
                } elseif ($seconds -eq $worstValue) {
                    $worstIndex += $j
                }

            } else {
                # Best = maior valor
                if ($bestValue -eq $null -or $value -gt $bestValue) {
                    $bestValue = $value
                    $bestIndex = @($j)
                } elseif ($value -eq $bestValue) {
                    $bestIndex += $j
                }

                # Worst = menor valor
                if ($worstValue -eq $null -or $value -lt $worstValue) {
                    $worstValue = $value
                    $worstIndex = @($j)
                } elseif ($value -eq $worstValue) {
                    $worstIndex += $j
                }
            }
        }

        # Se todos são iguais, só pinta de verde (já está OK)
        $allEqual = ($bestValue -eq $worstValue)

        if (-not $allEqual) {
            # Destaca melhores em verde
            foreach ($idx in $bestIndex) {
                $cell = $listView.Items[$rowIndex].SubItems[$idx + 1]
                $cell.BackColor = [System.Drawing.Color]::DarkGreen
                $cell.ForeColor = [System.Drawing.Color]::White
            }
            # Destaca piores em vermelho
            foreach ($idx in $worstIndex) {
                $cell = $listView.Items[$rowIndex].SubItems[$idx + 1]
                $cell.BackColor = [System.Drawing.Color]::DarkRed
                $cell.ForeColor = [System.Drawing.Color]::White
            }
        } else {
            # Todos iguais: pinta só de verde (melhores)
            foreach ($idx in $bestIndex) {
                $cell = $listView.Items[$rowIndex].SubItems[$idx + 1]
                $cell.BackColor = [System.Drawing.Color]::DarkGreen
                $cell.ForeColor = [System.Drawing.Color]::White
            }
        }
    }
}


$btnSelect.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Video Files|*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.flv;*.webm;*.3gp;*.ts;*.m2ts;*.vob;*.mpg;*.mpeg;*.divx;*.ogv;*.f4v;*.rm;*.rmvb|All Files|*.*"
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
