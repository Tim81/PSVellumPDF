#requires -Version 7.6
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeAll {
    $manifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'PSVellumPDF.psd1'
    Import-Module $manifest -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:gray16 = Join-Path $PSScriptRoot 'assets' 'gray16.png'
    $script:fontPath = Join-Path $PSScriptRoot 'assets' 'DejaVuSans.ttf'

    # A two-page document with text, an image and a heading.
    $script:sample = Join-Path $TestDrive 'sample.pdf'
    $doc = New-VellumPdfDocument | Add-VellumPdfHeading -Text 'Quarterly report' |
        Add-VellumPdfParagraph -Text 'First page body.' |
        Add-VellumPdfImage -Path $script:gray16 -Width 30
    1..70 | ForEach-Object { $doc = $doc | Add-VellumPdfParagraph -Text "Filler line $_" }
    $doc | Add-VellumPdfParagraph -Text 'Last words.' | Save-VellumPdfDocument -Path $script:sample | Out-Null

    $script:pw = ConvertTo-SecureString 'sekret' -AsPlainText -Force
    $script:locked = Join-Path $TestDrive 'locked.pdf'
    New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Secret text' |
        Protect-VellumPdfDocument -UserPassword $script:pw -OwnerPassword (ConvertTo-SecureString 'owner' -AsPlainText -Force) |
        Save-VellumPdfDocument -Path $script:locked | Out-Null
}

AfterAll {
    Remove-Module PSVellumPDF -Force -ErrorAction SilentlyContinue
}

Describe 'Get-VellumPdfInfo' {
    It 'reports pages, boxes and a clean bill for an ordinary file' {
        $i = Get-VellumPdfInfo -Path $script:sample
        $i.PSObject.TypeNames | Should -Contain 'PSVellumPDF.PdfInfo'
        $i.PageCount | Should -BeGreaterOrEqual 2
        $i.Pages[0].Page | Should -Be 1
        [math]::Round($i.Pages[0].Width, 2) | Should -Be 595.28
        [math]::Round($i.Pages[0].Height, 2) | Should -Be 841.89
        $i.IsEncrypted | Should -BeFalse
        $i.Encryption | Should -BeNullOrEmpty
        $i.Signatures.Count | Should -Be 0
        $i.WasReconstructed | Should -BeFalse
    }

    It 'accepts pipeline input from Save-VellumPdfDocument, a literal path and bytes' {
        $file = New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'x' | Save-VellumPdfDocument -Path (Join-Path $TestDrive 'pipe.pdf')
        ($file | Get-VellumPdfInfo).PageCount | Should -Be 1
        (Get-VellumPdfInfo -LiteralPath $file.FullName).Path | Should -Be $file.FullName
        (Get-VellumPdfInfo -Bytes ([System.IO.File]::ReadAllBytes($file.FullName))).Path | Should -Be '<bytes>'
    }

    It 'describes encryption and needs the password' {
        { Get-VellumPdfInfo -Path $script:locked } | Should -Throw '*needs a password*'
        $i = Get-VellumPdfInfo -Path $script:locked -Password $script:pw
        $i.IsEncrypted | Should -BeTrue
        $i.Encryption.KeyLengthBits | Should -Be 256
        $i.Encryption.StreamCipher | Should -Be 'Aes256'
        $i.Encryption.IsOwnerAccess | Should -BeFalse
    }

    It 'lists signatures with their sub-filter and byte range' {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Reader', $rsa, 'SHA256', [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))
        try {
            $path = Join-Path $TestDrive 'signed.pdf'
            New-VellumPdfDocument | Add-VellumPdfParagraph -Text 'Signed' | Set-VellumPdfSignature -Certificate $cert |
                Save-VellumPdfDocument -Path $path | Out-Null
            $sig = (Get-VellumPdfInfo -Path $path).Signatures
            $sig.Count | Should -Be 1
            $sig[0].SubFilter | Should -Be 'ETSI.CAdES.detached'
            $sig[0].ByteRange.Count | Should -Be 4
            $sig[0].ContentsLength | Should -BeGreaterThan 100
        }
        finally { $cert.Dispose(); $rsa.Dispose() }
    }

    It 'reports the PDF/A claim and recovers a truncated file only with -AllowReconstruction' {
        $doc = New-VellumPdfDocument -Conformance PdfA2b -Language en
        $h = Register-VellumPdfFont -Document $doc -Path $script:fontPath
        $path = Join-Path $TestDrive 'pdfa.pdf'
        $doc | Add-VellumPdfParagraph -Text 'Archive' -FontHandle $h | Save-VellumPdfDocument -Path $path | Out-Null
        (Get-VellumPdfInfo -Path $path).ClaimedProfiles | Should -Contain 'PdfA2b'

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $broken = $bytes[0..($bytes.Length - 120)]   # cut off the xref table and trailer
        { Get-VellumPdfInfo -Bytes $broken } | Should -Throw '*Try -AllowReconstruction*'
        $recovered = Get-VellumPdfInfo -Bytes $broken -AllowReconstruction
        $recovered.WasReconstructed | Should -BeTrue
        $recovered.PageCount | Should -Be 1
    }

    It 'gives clear errors for missing, malformed and unmatched input' {
        { Get-VellumPdfInfo -LiteralPath (Join-Path $TestDrive 'nope.pdf') } | Should -Throw '*file not found*'
        { Get-VellumPdfInfo -Path (Join-Path $TestDrive 'nomatch*.pdf') } | Should -Throw '*no file matches*'
        { Get-VellumPdfInfo -Bytes ([byte[]](1, 2, 3)) } | Should -Throw '*not a well-formed PDF*'
    }
}

Describe 'Reader limits and catalog details' {
    It 'reports which catalog features a document has' {
        $doc = New-VellumPdfPageDocument -Tagged -Language en | Add-VellumPdfPage -Count 2
        $path = Join-Path $TestDrive 'features.pdf'
        $doc | Set-VellumPdfDocumentInfo -Title 'f' | Add-VellumPdfText 'x' -X 72 -Y 700 |
            Add-VellumPdfOutlineEntry 'One' -TargetPage 1 |
            Add-VellumPdfFormField Text -Name t -X 72 -Y 600 -Width 100 -Height 20 -WarningAction SilentlyContinue |
            Save-VellumPdfDocument -Path $path | Out-Null
        $c = (Get-VellumPdfInfo -Path $path).Catalog
        $c.IsTagged | Should -BeTrue
        $c.HasLanguage | Should -BeTrue
        $c.HasOutline | Should -BeTrue
        $c.HasForm | Should -BeTrue
        $c.HasMetadata | Should -BeTrue
        $plain = (Get-VellumPdfInfo -Path $script:sample).Catalog
        $plain.IsTagged | Should -BeFalse
        $plain.HasForm | Should -BeFalse
    }

    It 'accepts tightened limits and rejects values above the engine ceilings' {
        $i = Get-VellumPdfInfo -Path $script:sample -MaxDecodedStreamBytes 2MB -MaxDiagnostics 5 -MaxFormXObjectDepth 4 -ReconstructionBudgetMultiplier 2
        $i.PageCount | Should -BeGreaterOrEqual 2
        { Get-VellumPdfInfo -Path $script:sample -MaxDecodedStreamBytes 1GB } | Should -Throw
        { Get-VellumPdfText -Path $script:sample -MaxFormXObjectDepth 99 } | Should -Throw
        { Get-VellumPdfText -Path $script:sample -MaxDiagnostics 0 } | Should -Throw
    }

    It 'a tight decoded-size limit makes the reader skip oversized content and say so' {
        # About 2 MiB of drawing operators once inflated, 300 KB on disk.
        $big = Join-Path $TestDrive 'big.pdf'
        New-VellumPdfPageDocument | Add-VellumPdfPage |
            Invoke-VellumPdfCanvas -ScriptBlock { param($c) foreach ($i in 1..130000) { [void]$c.Rectangle($i % 500, $i % 700, 3, 3).Fill() } } |
            Save-VellumPdfDocument -Path $big | Out-Null
        Get-VellumPdfText -Path $big -WarningVariable fine -WarningAction SilentlyContinue | Out-Null
        @($fine).Count | Should -Be 0
        Get-VellumPdfText -Path $big -MaxDecodedStreamBytes 1MB -WarningVariable tight -WarningAction SilentlyContinue | Out-Null
        @($tight | Where-Object Message -Like '*failed to decode; it was skipped*').Count | Should -Be 1
    }

    It 'diagnostics carry object numbers' {
        $bytes = [System.IO.File]::ReadAllBytes($script:sample)
        $broken = $bytes[0..($bytes.Length - 120)]
        $i = Get-VellumPdfInfo -Bytes $broken -AllowReconstruction
        $i.Diagnostics.Count | Should -BeGreaterThan 0
        $i.Diagnostics[0].PSObject.Properties.Name | Should -Contain 'ObjectNumber'
        $i.Diagnostics[0].PSObject.Properties.Name | Should -Contain 'Generation'
    }
}

Describe 'Get-VellumPdfText' {
    It 'extracts the text of the whole document, one page, or per page' {
        $all = Get-VellumPdfText -Path $script:sample
        $all | Should -BeOfType ([string])
        $all | Should -Match 'Quarterly report'
        $all | Should -Match 'Last words'

        $first = Get-VellumPdfText -Path $script:sample -Page 1
        $first | Should -Match 'First page body'
        $first | Should -Not -Match 'Last words'

        $pages = @(Get-VellumPdfText -Path $script:sample -PerPage)
        $pages.Count | Should -BeGreaterOrEqual 2
        $pages[0].Page | Should -Be 1
        $pages[-1].Text | Should -Match 'Last words'
    }

    It 'returns nothing for a document without pages instead of asking for page 0' {
        # A reconstructed file whose page tree is empty: drop the single page from a valid file.
        $bytes = [System.IO.File]::ReadAllBytes($script:sample)
        $text = [System.Text.Encoding]::Latin1.GetString($bytes) -replace '/Count \d+', '/Count 0' -replace '/Kids \[[^\]]*\]', '/Kids []'
        $none = [System.Text.Encoding]::Latin1.GetBytes($text)
        $info = Get-VellumPdfInfo -Bytes $none -AllowReconstruction
        $info.PageCount | Should -Be 0
        Get-VellumPdfText -Bytes $none -AllowReconstruction | Should -BeNullOrEmpty
    }

    It 'reads an encrypted file with its password and rejects a page that does not exist' {
        Get-VellumPdfText -Path $script:locked -Password $script:pw | Should -Match 'Secret text'
        { Get-VellumPdfText -Path $script:sample -Page 99 } | Should -Throw '*page 99 does not exist*'
    }
}

Describe 'Export-VellumPdfImage' {
    It 'writes embedded images and refuses to overwrite without -Force' {
        $dir = Join-Path $TestDrive 'imgs'
        $files = @(Export-VellumPdfImage -Path $script:sample -DestinationPath $dir)
        $files.Count | Should -Be 1
        $files[0].Name | Should -Be 'sample-p1-i1.png'
        [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($files[0].FullName)[1..3]) | Should -Be 'PNG'

        { Export-VellumPdfImage -Path $script:sample -DestinationPath $dir -ErrorAction Stop } | Should -Throw '*use -Force*'
        @(Export-VellumPdfImage -Path $script:sample -DestinationPath $dir -Force).Count | Should -Be 1
    }

    It 'honours -BaseName, -Page and -WhatIf' {
        $dir = Join-Path $TestDrive 'imgs2'
        Export-VellumPdfImage -Path $script:sample -DestinationPath $dir -WhatIf | Should -BeNullOrEmpty
        Test-Path $dir | Should -BeFalse
        @(Export-VellumPdfImage -Path $script:sample -DestinationPath $dir -Page 2).Count | Should -Be 0
        (Export-VellumPdfImage -Path $script:sample -DestinationPath $dir -BaseName logo).Name | Should -Be 'logo-p1-i1.png'
    }
}

Describe 'Unprotect-VellumPdfDocument' {
    It 'writes a decrypted copy that opens without a password, and leaves the original encrypted' {
        $out = Join-Path $TestDrive 'open.pdf'
        $result = Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath $out -Password $script:pw
        $result.FullName | Should -Be $out
        (Get-VellumPdfInfo -Path $out).IsEncrypted | Should -BeFalse
        Get-VellumPdfText -Path $out | Should -Match 'Secret text'
        (Get-VellumPdfInfo -Path $script:locked -Password $script:pw).IsEncrypted | Should -BeTrue
    }

    It 'refuses the same file, an existing destination without -Force, and unencrypted input' {
        { Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath $script:locked -Password $script:pw } | Should -Throw '*different file*'
        $existing = Join-Path $TestDrive 'exists.pdf'
        Set-Content -LiteralPath $existing -Value 'x'
        { Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath $existing -Password $script:pw } | Should -Throw '*use -Force*'
        { Unprotect-VellumPdfDocument -Path $script:sample -DestinationPath (Join-Path $TestDrive 'x.pdf') } | Should -Throw '*is not encrypted*'
        { Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath (Join-Path $TestDrive 'y.pdf') } | Should -Throw '*needs a password*'
        Test-Path (Join-Path $TestDrive 'y.pdf') | Should -BeFalse
    }

    It 'refuses a wildcard that matches several files' {
        Copy-Item $script:locked (Join-Path $TestDrive 'multi-a.pdf')
        Copy-Item $script:locked (Join-Path $TestDrive 'multi-b.pdf')
        { Unprotect-VellumPdfDocument -Path (Join-Path $TestDrive 'multi-*.pdf') -DestinationPath (Join-Path $TestDrive 'm.pdf') -Password $script:pw } |
            Should -Throw '*matches 2 files*'
    }

    It 'does nothing under -WhatIf' {
        $out = Join-Path $TestDrive 'whatif.pdf'
        Unprotect-VellumPdfDocument -Path $script:locked -DestinationPath $out -Password $script:pw -WhatIf | Should -BeNullOrEmpty
        Test-Path $out | Should -BeFalse
    }
}
