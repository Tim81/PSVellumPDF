# Shared helpers for the Pester tests. Dot-source from BeforeAll:
#   . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

# The whole PDF as a Latin-1 string (every byte maps to one char).
function Get-PdfText {
    param([string]$Path)
    [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::Latin1)
}

# Inflates every FlateDecode stream so tests can read page content operators.
function Get-PdfContentText {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::Latin1.GetString($bytes)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($m in [regex]::Matches($text, '(?<!end)stream\r?\n')) {
        $start = $m.Index + $m.Length
        $end = $text.IndexOf('endstream', $start)
        $slice = [byte[]]$bytes[($start + 2)..($end - 1)]   # skip the 2-byte zlib header
        try {
            $ds = [System.IO.Compression.DeflateStream]::new(
                [System.IO.MemoryStream]::new($slice), [System.IO.Compression.CompressionMode]::Decompress)
            $reader = [System.IO.StreamReader]::new($ds, [System.Text.Encoding]::Latin1)
            [void]$sb.AppendLine($reader.ReadToEnd())
        }
        catch { Write-Verbose "not a flate stream: $_" }
    }
    $sb.ToString()
}

# Regex source matching a PDF text string stored as UTF-16BE with a byte-order mark.
function Get-Utf16Pattern {
    param([string]$Text)
    '\xFE\xFF' + (($Text.ToCharArray() | ForEach-Object { '\x00' + [regex]::Escape([string]$_) }) -join '')
}

# The structure tree of a tagged PDF as nested objects (Type, Mcid, Scope, RowSpan, ColSpan, Lang, Alt, Children),
# read from qpdf's uncompressed form of the file. Returns the children of the root /Document element.
function Get-PdfStructureTree {
    param([string]$Path)
    $plain = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N') + '.pdf')
    try {
        & qpdf --qdf --object-streams=disable $Path $plain 2>&1 | Out-Null
        $text = [System.IO.File]::ReadAllText($plain, [System.Text.Encoding]::Latin1)
    }
    finally { Remove-Item $plain -ErrorAction SilentlyContinue }
    $objects = @{}
    foreach ($m in [regex]::Matches($text, '(?s)\n(\d+) 0 obj\n(.*?)\nendobj')) { $objects[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
    $build = $null
    $build = {
        param([int]$Number)
        $body = $objects[$Number]
        $node = [pscustomobject]@{
            Type = [regex]::Match($body, '/S /(\w+)').Groups[1].Value
            Mcid = $null; Scope = $null; RowSpan = 1; ColSpan = 1; Lang = $null; Alt = $null
            Children = [System.Collections.Generic.List[object]]::new()
        }
        $scope = [regex]::Match($body, '/Scope /(\w+)'); if ($scope.Success) { $node.Scope = $scope.Groups[1].Value }
        $rowSpan = [regex]::Match($body, '/RowSpan (\d+)'); if ($rowSpan.Success) { $node.RowSpan = [int]$rowSpan.Groups[1].Value }
        $colSpan = [regex]::Match($body, '/ColSpan (\d+)'); if ($colSpan.Success) { $node.ColSpan = [int]$colSpan.Groups[1].Value }
        $alt = [regex]::Match($body, '/Alt <([0-9a-f]+)>'); if ($alt.Success) { $node.Alt = [System.Text.Encoding]::BigEndianUnicode.GetString([Convert]::FromHexString($alt.Groups[1].Value)).TrimStart([char]0xFEFF) }
        $lang = [regex]::Match($body, '/Lang <([0-9a-f]+)>'); if ($lang.Success) { $node.Lang = [System.Text.Encoding]::BigEndianUnicode.GetString([Convert]::FromHexString($lang.Groups[1].Value)).TrimStart([char]0xFEFF) }
        $array = [regex]::Match($body, '/K \[([^\]]*)\]')
        $single = [regex]::Match($body, '/K (\d+) 0 R')
        $mcid = [regex]::Match($body, '/K (\d+)(?! 0 R)(?=\s|$)')
        if ($array.Success) { foreach ($r in [regex]::Matches($array.Groups[1].Value, '(\d+) 0 R')) { $node.Children.Add((& $build ([int]$r.Groups[1].Value))) } }
        elseif ($single.Success) { $node.Children.Add((& $build ([int]$single.Groups[1].Value))) }
        elseif ($mcid.Success) { $node.Mcid = [int]$mcid.Groups[1].Value }
        $node
    }
    $root = [regex]::Match($text, '/StructTreeRoot (\d+) 0 R')
    if (-not $root.Success) { return @() }
    $rootNode = & $build ([int]$root.Groups[1].Value)
    # StructTreeRoot has no /S; its single /K child is the Document element.
    $document = $rootNode.Children[0]
    , @($document.Children)
}

# The content stream of one page of an unsaved page document, as Latin-1 text: finishes the page canvases the way a
# save would (bands, balance check) without writing a file. The document cannot be drawn on afterwards.
function Get-PageContent {
    param($Document, [int]$Page = 1)
    & (Get-Module PSVellumPDF) { param($d) Complete-VellumPdfPageDocument -Document $d } $Document
    $bytes = $Document.Pages[$Page - 1].ContentBytes
    if ($null -eq $bytes) { return '' }
    [System.Text.Encoding]::Latin1.GetString($bytes)
}

# Lines of page content that start a text object outside any marked-content sequence (BMC/BDC ... EMC).
function Get-UnmarkedTextStart {
    param([string]$Content)
    $depth = 0
    foreach ($line in ($Content -split "\r?\n")) {
        if ($line -match ' (BMC|BDC)$') { $depth++ }
        elseif ($line -eq 'EMC') { $depth-- }
        elseif ($line -eq 'BT' -and $depth -le 0) { $line }
    }
}
