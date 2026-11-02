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
        # The hex /Contents sits in the gap between the two signed ranges.
        $hex = [System.Text.Encoding]::ASCII.GetString($bytes, $b + 1, $c - $b - 2).TrimEnd('0')
        if ($hex.Length % 2) { $hex += '0' }
        $cmsBytes = [Convert]::FromHexString($hex)

        $cms = [System.Security.Cryptography.Pkcs.SignedCms]::new([System.Security.Cryptography.Pkcs.ContentInfo]::new($signed), $true)
        $cms.Decode($cmsBytes)
        $cms.SignerInfos.Count | Should -Be 1
        { $cms.CheckSignature($true) } | Should -Not -Throw
    }
}
