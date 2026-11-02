#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Runs the examples that must keep working end to end and checks their output.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:examples = Join-Path (Split-Path $PSScriptRoot -Parent) 'examples'
}

Describe 'examples/09-kms-signing.ps1' {
    It 'signs through the compiled external signer and produces a verifiable detached CMS signature' {
        $out = Join-Path $TestDrive 'kms.pdf'
        # A child process: the example compiles a type with Add-Type, which cannot be reloaded in this session.
        $result = & (Get-Command pwsh).Source -NoProfile -File (Join-Path $script:examples '09-kms-signing.ps1') -OutputPath $out 2>&1
        ($result | Out-String) | Should -Match 'signer called 1 time'

        $bytes = [System.IO.File]::ReadAllBytes($out)
        $text = [System.Text.Encoding]::Latin1.GetString($bytes)
        $text | Should -Match '/SubFilter\s*/ETSI\.CAdES\.detached'
        $br = [regex]::Match($text, '/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]')
        $br.Success | Should -BeTrue
        $a, $b, $c, $d = 1..4 | ForEach-Object { [int64]$br.Groups[$_].Value }
        $signed = [byte[]]::new($b + $d)
        [Array]::Copy($bytes, $a, $signed, 0, $b)
        [Array]::Copy($bytes, $c, $signed, $b, $d)
        # The hex /Contents sits in the gap between the two signed ranges, zero-padded. Read the CMS length from its
        # DER header instead of trimming zeros (the signature can end in 00 bytes itself).
        $padded = [Convert]::FromHexString([System.Text.Encoding]::ASCII.GetString($bytes, $b + 1, $c - $b - 2))
        $padded[0] | Should -Be 0x30
        $length = if ($padded[1] -band 0x80) {
            $count = $padded[1] -band 0x7F
            $value = 0
            foreach ($i in 1..$count) { $value = ($value -shl 8) -bor $padded[1 + $i] }
            2 + $count + $value
        }
        else { 2 + $padded[1] }
        $cmsBytes = [byte[]]$padded[0..($length - 1)]

        $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new([System.Security.Cryptography.Pkcs.ContentInfo]::new($signed), $true)
        $cms.Decode($cmsBytes)
        $cms.SignerInfos.Count | Should -Be 1
        { $cms.CheckSignature($true) } | Should -Not -Throw
    }

    It 'is robust whatever the last signature bytes are (DER length, not zero trimming)' {
        # The old test trimmed trailing '0' characters; make sure the length logic itself handles long form lengths.
        $der = [byte[]](0x30, 0x82, 0x01, 0x00) + [byte[]]::new(256)
        $count = $der[1] -band 0x7F
        $value = 0
        foreach ($i in 1..$count) { $value = ($value -shl 8) -bor $der[1 + $i] }
        (2 + $count + $value) | Should -Be 260
    }
}

Describe 'examples/10-paths-clipping-and-text-boxes.ps1' {
    It 'runs under en-US and de-DE and writes a PDF that qpdf accepts' -ForEach @('en-US', 'de-DE') {
        $out = Join-Path $TestDrive "paths-$_.pdf"
        # A child process, so that the culture change cannot leak into this session.
        $script = "[cultureinfo]::CurrentCulture = '$_'; & '$(Join-Path $script:examples '10-paths-clipping-and-text-boxes.ps1')'"
        $written = Join-Path $script:examples 'paths-and-text-boxes.pdf'
        Remove-Item $written -ErrorAction SilentlyContinue   # a leftover file from an earlier run must not pass for this one
        $output = & (Get-Command pwsh).Source -NoProfile -Command $script 2>&1
        $LASTEXITCODE | Should -Be 0 -Because (($output | Out-String))
        Test-Path $written | Should -BeTrue
        Copy-Item $written $out
        if (Get-Command qpdf -ErrorAction SilentlyContinue) { & qpdf --check $out 2>&1 | Out-String | Should -Match 'No syntax or stream encoding errors' }
        else { Set-ItResult -Skipped -Because 'qpdf is not installed' }   # the qpdf check did not run; do not report it as passed
    }
}
