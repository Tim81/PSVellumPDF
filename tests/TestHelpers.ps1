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
