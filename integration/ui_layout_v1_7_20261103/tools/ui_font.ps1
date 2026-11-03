$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$outDir = Join-Path $PSScriptRoot '../ui_evidence'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$characters = ' 安路科技运行时间未校图片轮播开启关闭当前操作缩放双线性最近邻原尺寸等比例留边铺满裁剪转场直接切换淡出入水平滑动风车旋垂擦除百叶窗圆形光圈方块溶解亮度对比文字滚速方向时长字幕音频无设置慢中快左右短关英中文语0123456789:/.-ANLOGICFPGA'
$chars = [System.Collections.Generic.List[char]]::new()
foreach ($c in $characters.ToCharArray()) { if (-not $chars.Contains($c)) { $chars.Add($c) } }
$font = [System.Drawing.Font]::new('SimHei',16,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$bmp = [System.Drawing.Bitmap]::new(16,16)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
$fmt = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
$rows = [System.Collections.Generic.List[string]]::new()
foreach ($c in $chars) {
    $g.Clear([System.Drawing.Color]::Black)
    $g.DrawString([string]$c,$font,[System.Drawing.Brushes]::White,[System.Drawing.PointF]::new(0,-1),$fmt)
    for ($y=0;$y -lt 16;$y++) {
        $bits = 0
        for ($x=0;$x -lt 16;$x++) { if ($bmp.GetPixel($x,$y).R -gt 100) { $bits = $bits -bor (1 -shl (15-$x)) } }
        $rows.Add(('{0:x4}' -f $bits))
    }
}
while ($rows.Count -lt 2048) { $rows.Add('0000') }
if ($chars.Count -gt 128) { throw 'Font exceeds 128 glyphs' }
[IO.File]::WriteAllLines((Join-Path $outDir 'sidebar_font.hex'),$rows)
[IO.File]::WriteAllText((Join-Path $outDir 'sidebar_chars.txt'),(-join $chars),[Text.UTF8Encoding]::new($false))
$g.Dispose(); $bmp.Dispose(); $font.Dispose(); $fmt.Dispose()
Write-Output "Generated $($chars.Count) sidebar glyphs"
