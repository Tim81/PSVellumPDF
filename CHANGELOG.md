# Changelog

All notable changes to PSVellumPDF are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-11-02

Built on **VellumPdf 2.3.3** (was 1.5.4). A major release: the engine changed how
a few things render and validate, and several long-standing wrapper bugs are fixed
in ways that change output. Upgrade notes are in the README.

### Breaking
- **Heading levels**: `Add-VellumPdfHeading -Level 1` is now tagged `H1` and is a
  top-level outline entry. The engine counts levels from zero and the module passed
  1..6 straight through, so level 1 was tagged `H2` (and so on).
- **`-MarginBottom`** now adds space before the next element on paragraphs, headings,
  lists and tables. VellumPdf's bottom margin only limits the element's own box, so
  the parameter had no visible effect. The space is carried to the next element's
  top margin and consumed once.
- **Lists** nested deeper than one child level are refused (`Add-VellumPdfList`).
  The engine renders one level and silently dropped the text of deeper items; the
  module previously accepted 64 levels.
- **A document can be saved once.** Layout runs inside the save, a second save is
  refused by the engine, and a save that failed can leave state that makes a retry
  write a different file. `Save-VellumPdfDocument` now says so plainly for a second
  save (with `-KeepOpen`) and after a failure.
- **Encoding warnings** follow Windows-1252. The base-14 fonts now encode
  `€ ‚ ƒ „ … † ‡ ˆ ‰ Š ‹ Œ Ž ‘ ’ “ ” • – — ˜ ™ š › œ ž Ÿ`, which no longer warn; text
  widths changed with the new encoding, so lines can wrap differently.
- **Encryption** (`Protect-VellumPdfDocument`): an empty `-OwnerPassword` beside a
  user password is refused (such a file opened with full owner access and no
  password), as is encryption with `-UseObjectStreams`. Encrypted files differ at
  the byte level: the `/P` permission value always sets the reserved bits, and
  `-EncryptMetadata:$false` now really leaves the XMP metadata unencrypted.
- **Signing**: PAdES signatures no longer carry a CMS `signing-time` attribute (the
  claimed time stays in the signature dictionary's `/M`), and only the two defined
  sub-filters are accepted.
- **Engine rendering changes** visible in existing documents: table margins are no
  longer applied twice (tables with a left/top margin move), the column count comes
  from the widest row, header/footer text wider than the page is cut at a word
  boundary and honours its colour, and links are written with the Print flag.
- **Errors always stop the cmdlet.** Every public cmdlet raises its errors as terminating errors, so
  `-ErrorAction SilentlyContinue`/`Ignore` can no longer let a cmdlet carry on after a failed check
  (previously `Save-VellumPdfDocument -Validate` was skipped, conflicting colours were both written, and
  an unknown path command looped for ever). Wrap the call in `try`/`catch` to handle an error.
- **The document default font reaches every element.** With `New-VellumPdfDocument -DefaultFont/-DefaultFontSize`,
  list items, table cells, header and footer bands and `New-VellumPdfTextRun` runs used Helvetica 12; they now
  use the default (11 pt Helvetica when none is set), so existing documents change size.
- **Piped file objects bind to `-LiteralPath`** in `Get-VellumPdfInfo`, `Get-VellumPdfText`,
  `Test-VellumPdfConformance`, `Export-VellumPdfImage` and `Unprotect-VellumPdfDocument`; `-Path` no longer binds
  by property name (so `report[1].pdf` from `Get-ChildItem` works). Strings piped in still bind to `-Path`.
- **Stricter input**: page coordinates and sizes must be finite and within +-14,400 pt (the largest page); language
  tags must be BCP 47; alternate text must not be empty or whitespace; `Set-VellumPdfOutputIntent` reads the colour
  space from the ICC profile and refuses a mismatching `-ComponentCount`; barcode captions are off by default in
  PDF/UA as well as PDF/A (a non-embedded font fails PDF/UA).
- **`Export-VellumPdfImage`** writes CCITT as TIFF and JBIG2 as a standalone file (see Fixed), and skips images that
  have no file format (for example raw CMYK) with a warning instead of writing headerless `.bin` files.
- **Installation**: the module loads `VellumPdf.Kernel/Layout/Reader/Signing/
  Barcodes/Conformance/Fonts.Standard14` and `PSVellumPDF.Interop`. The loader
  checks their identity (version 2.0.0.0, strong-name token `b2757187a6d18ae5`),
  so a stale 1.x `lib/` fails at import with the fix instead of a type-load error.

- **Reader cmdlets report a bad file and go on** (`Get-VellumPdfInfo`, `Get-VellumPdfText`,
  `Test-VellumPdfConformance`, `Export-VellumPdfImage`, `Unprotect-VellumPdfDocument`): a file that is missing,
  unreadable, malformed or locked is a non-terminating error with the file as `TargetObject`, and the remaining files
  are still processed. Scripts that relied on `try`/`catch` must add `-ErrorAction Stop`. Files are read one at a
  time instead of all up front. `Test-VellumPdfConformance -Quiet` returns `$false` for a file it could not check.
- **Plain hashtable table rows are refused** by `Add-VellumPdfTable` when they have more than one key: a plain
  `@{}` has no defined key order, so the columns came out shuffled. Use `[ordered]@{...}` or `[pscustomobject]`.
- **`Add-VellumPdfTextBox` throws** when its text would run below the bottom of the page (it drew off the page
  silently); `-MaxHeight` still cuts the text off.
- **Conformant flow documents embed their fonts**: with `-Conformance` PDF/A or PDF/UA-1, base-14 font names are
  replaced by the embedded, metric-compatible Liberation fonts (as page documents already did), so these files now
  pass the font-embedding checks without `-FontHandle`. Layout is unchanged. Text in embedded fonts is not
  extracted by `Get-VellumPdfText`. Symbol and ZapfDingbats have no substitute and need `-FontHandle`.
- **Right- and centre-aligned text with `-CharSpacing`** aligns on its visible glyphs: the spacing after the last
  character is no longer counted, so right-aligned text ends exactly at `-X`.

- **Numbers in table cells and list items**: a string that is only a number (`1.444,50`, `1,976.08`, `66443,85`)
  is read as a decimal and drawn with the cell's format and culture; with the invariant default and no format,
  `1.444,50` is drawn as `1444.50`. Both separator conventions are detected; an ambiguous value such as `1,234` is
  resolved from the other values in the column or list, then from `-InputCulture`, and otherwise left as typed with
  one warning. `-NoNumberParsing` (or a cell's `Parse = $false`) draws strings exactly as given; header cells are
  never parsed.
- **Pie-chart legend percentages** use the invariant culture (`33.3 %`) instead of the machine's culture; pass
  `-Culture` to choose one.
- **Error ids**: the reader cmdlets' per-file ids `PdfFileNotFound`, `PdfFileReadError` and `PdfInputError` (new in
  this release's development) are `PSVellumPDF.FileNotFound`, `PSVellumPDF.FileReadError`, `PSVellumPDF.InvalidPdf`,
  `PSVellumPDF.PasswordRequired` and `PSVellumPDF.InputError`; `Export-VellumPdfImage`'s `ImageFileExists` is
  `PSVellumPDF.FileExists`.

### Added
- **New flow-document cmdlets**: `Add-VellumPdfPieChart` (slices or pipeline data,
  colour-blind-safe palette, legend, alternate text), `Add-VellumPdfBarcode`
  (QR, Micro QR, Data Matrix, Aztec, PDF417, Code 128, Code 39, EAN-13/8, UPC-A/E,
  ITF-14; GS1; Structured Append and Macro PDF417 via `-SplitInto`),
  `Add-VellumPdfDrawing` (a script block receives the VellumPdf canvas) and
  `Add-VellumPdfElement` (any `IRenderer`).
- **Page-based documents**: `New-VellumPdfPageDocument`, `Add-VellumPdfPage`,
  `Add-VellumPdfShape`, `Add-VellumPdfText`, `Add-VellumPdfGradient`,
  `Add-VellumPdfPageImage`, `Add-VellumPdfPageBarcode`, `Invoke-VellumPdfCanvas`,
  `Add-VellumPdfFormField`, `Add-VellumPdfLink`, `Add-VellumPdfOutlineEntry`,
  `Add-VellumPdfPath` (lines and curves from path data or points, nonzero or even-odd
  fill), `Use-VellumPdfClip` (clip any drawing to a rectangle, ellipse or path),
  `Add-VellumPdfTextBox` (wrapped, centred, right-aligned or justified text in a
  column) and `Set-VellumPdfPageBand` (repeated header/footer, `Page {page} of
  {pages}`). Includes AcroForm fields, links to other pages, collapsible bookmarks, page
  rotation, linearized ("fast web view") output and byte-for-byte reproducible
  files (`-DocumentId`, `-Timestamp`). `Set-VellumPdfDocumentInfo`,
  `Set-VellumPdfOutputIntent`, `Register-VellumPdfFont`, `Protect-VellumPdfDocument`,
  `Set-VellumPdfSignature` and `Save-VellumPdfDocument` work on both kinds.
- **Conformance**: `Test-VellumPdfConformance` validates any PDF against PDF/A-2b/2u/2a
  or PDF/UA-1 in-process, and `Save-VellumPdfDocument -Validate` refuses to write a
  non-compliant file. New-VellumPdfDocument gains `-Conformance PdfUA1`.
- **Signing**: `Set-VellumPdfSignature -Level B-B|B-T|B-LT|B-LTA`, `-TimestampClient`,
  `-RevocationClient`/`-RevocationTimeout`, `-SignaturePage`, `-SubFilter`,
  `-EstimatedSignatureSize`, `-ExternalPrivateKey` and `-ExternalSigner` (cloud
  KMS / HSM); `examples/09-kms-signing.ps1` shows a compiled signer with ECDSA
  signature conversion. Script-block signers are not offered: the engine calls the
  signer on thread-pool threads, where a script block cannot run.
- **Experimental readers** (VellumPdf.Reader is a preview package): `Get-VellumPdfInfo`,
  `Get-VellumPdfText`, `Export-VellumPdfImage`, `Unprotect-VellumPdfDocument`.
- **Embedded fonts everywhere**: `-FontHandle` on `Add-VellumPdfTable`,
  `Add-VellumPdfList`, `Set-VellumPdfHeader`/`Footer`, so tables, lists and bands
  can be Unicode and PDF/A. Table cells also take `FontHandle`, `Leading`,
  `Padding` and `Language`; `-Header` accepts rich cells; `-CellPadding`.
- **Text options**: `Add-VellumPdfHeading -Color -Leading -Language`,
  `Add-VellumPdfParagraph -Language`, `Add-VellumPdfList -Color -Leading -Language`
  and per-item style keys, `Set-VellumPdfHeader`/`Footer -Color -Height`.
- **Document**: custom page sizes (`-PageWidthMm`/`-PageHeightMm`, up to 5080 mm).
- **Save**: `Save-VellumPdfDocument -Stream`, `-AsByteArray`, `-PassThru`, `-Force`,
  `-Validate`. After a save the engine's own diagnostics are reported (characters
  replaced by `?`, truncated header/footer text) and attached to the returned file
  as `TextEncodingWarnings` and `BandTruncations`.
- **Images**: `Add-VellumPdfImage -Format Ccitt` (raw fax data with `-Columns`/`-Rows`
  and options), `-ReduceToEightBit`, `-DecodeToRaster`, `-MarginLeft`/`-MarginRight`.
- **Tagged page documents**: `New-VellumPdfPageDocument -Tagged`, `-Conformance PdfA2a` and
  `PdfUA1`. Text carries a structure role (`Add-VellumPdfText -Role P|H1-H6|Span|Caption`,
  `-Language`), shapes and gradients are artifacts (or Figures with `-AltText`), images
  and barcodes need `-AltText` or `-Decorative`, and `Invoke-VellumPdfCanvas` drawing is an
  artifact (`-NoMarkedContent` to take over). Links and form fields cannot be tagged by
  VellumPdf; the cmdlets warn once. A PDF/UA-1 page document without them passes the
  preflight.
- `Add-VellumPdfText`: `-CharSpacing`, `-WordSpacing`, `-Rise`, `-HorizontalScale`
  (alignment accounts for them). `Add-VellumPdfShape`: `-LineCap`, `-LineJoin`, `-MiterLimit`.
- `Add-VellumPdfTable -Header` accepts several rows (an array per row); the leading header
  rows repeat on every page.
- Reader: resource limits (`-MaxDecodedStreamBytes`, `-MaxDiagnostics`, `-MaxFormXObjectDepth`,
  `-ReconstructionBudgetMultiplier`) on the reading cmdlets, object numbers on diagnostics,
  and `Get-VellumPdfInfo` reports catalog features (`Catalog.IsTagged`, `HasForm`, ...).
- Barcodes: PDF417 `-RowHeight`/`-PreferredAspectRatio`, Macro PDF417 metadata
  (`-MacroFileName/-Sender/-Addressee/-Timestamp/-FileSize/-Checksum`), and
  `Get-VellumPdfBarcodeMatrix` returns a 2-D symbol's module grid as data.
- `Get-VellumPdfConformanceCoverage` lists which checks the in-process preflight performs.
- `Add-VellumPdfShape`: an `Arc` shape and ICC-based colour (`-IccProfilePath` with
  `-FillIcc`/`-StrokeIcc`; the profile is embedded once per page and its component
  count is read from the file).
- About 35 more CSS colour names; `-ColumnWidth 0` means auto.
- `PSVellumPDF.Interop`: a small C# shim for what PowerShell cannot call directly
  (span-taking canvas operators) and the renderer behind `Add-VellumPdfDrawing`.
  Display formats for preflight results and PDF info.
- Image loading and the Windows-1252 table now live in one private helper each. CI uses
  PowerShell 7.6.9. Examples 05-08, new validation samples (charts, page documents, PDF/UA,
  linearized, forms), veraPDF PDF/UA-1 and qpdf linearization checks in CI, and an
  engine-surface test that fails by name when a VellumPdf upgrade removes anything
  the module uses. `tools/Get-VellumPdfApiSurface.py` diffs two engine releases.

### Added (review follow-up)
- **Page documents**: `Add-VellumPdfPath` (path data or points, nonzero/even-odd fill), `Use-VellumPdfClip`,
  `Use-VellumPdfTransform` (rotate, scale, move a drawing), `Add-VellumPdfTextBox` (wrapped, justified text),
  `Set-VellumPdfPageBand` (repeated header/footer, page numbers), `Add-VellumPdfPageTable` and
  `Add-VellumPdfPageList` (tables and lists tagged as real Table/TR/TH/TD and L/LI/Lbl/LBody), and
  `Use-VellumPdfStructure` (group tagged content under Sect, Div, Art ...). `-Rotation` on `Add-VellumPdfText` and
  `Add-VellumPdfPageImage`; `-FillGray`/`-StrokeGray` on shapes and paths.
- `Measure-VellumPdfText`: text width in a base-14 or embedded font, with missing and unencodable characters.
- `Get-VellumPdfInfo -IncludeSignatureContents` returns the CMS bytes of each signature, so a script can verify it.
- `Export-VellumPdfImage` file objects carry Page, Encoding, Width, Height, BitsPerComponent, ColorSpace,
  ComponentCount, IsInline, IsStencilMask and HasSoftMask.
- Warnings for characters an embedded font has no glyph for (they draw as empty boxes and fail PDF/A).
- `examples/09-kms-signing.ps1` (a KMS/HSM signer) and `examples/10-paths-clipping-and-text-boxes.ps1`.

### Fixed
- **Embedded fonts and word spacing**: `Add-VellumPdfText -WordSpacing` had no effect with an embedded font (and
  therefore in PDF/A and PDF/UA documents), so aligned text ended in the wrong place; the words are now placed
  individually.
- **Tables** align cells by grid column when they use `ColSpan`/`RowSpan` (`-ColumnAlignment`, `-ColumnWidth` count).
- **Export-VellumPdfImage**: CCITT fax data is wrapped in a TIFF (pixel-identical to the PDF's rendering), and JBIG2
  segments are joined with their shared segments into a standard sequential file. Limitation: VellumPdf's own
  JBIG2 loader reads only the 8-byte ID string, so these standard files cannot be embedded again with
  `Add-VellumPdfPageImage`.
- `Invoke-VellumPdfCanvas` refuses to save a document whose script block saved more graphics states than it restored.
- A clip scope's `-Page` is the page its drawing goes to; a text box no longer splits on no-break spaces and honours
  `-MaxHeight` exactly; page bands warn when they run off the page; `-LineCap`/`-LineJoin` accept any letter case;
  table and pie data tolerate missing properties; `Save-VellumPdfDocument` leaked a task object with `-ExternalSigner`.
- **Failures keep the structure tree consistent**: content tagged before a `Use-VellumPdfStructure` block, a table or
  a list failed no longer ends up with MCIDs that no structure element owns (a corrupt ParentTree that
  `-Validate` did not notice); table cell colours are checked before anything is drawn.
- **`Add-VellumPdfParagraph -Run`** no longer swaps an embedded font for Helvetica when the run sets `-FontHandle`
  but no `-FontSize`; unpaired UTF-16 surrogates and the Symbol/ZapfDingbats fonts (no width table in VellumPdf) are
  refused with a cmdlet-named error where text is measured; `-Page` beyond the page count is named for tables and
  lists; `Use-VellumPdfTransform -Scale` is limited to 0.000001 ... 1,000,000; Group 3 CCITT without end-of-line
  codes is exported as TIFF compression 2 (one-dimensional byte-aligned data) or skipped, never as an undecodable
  file; a hostile JBIG2 header can no longer abort the export; `-RowHeader` marks only grid column 0;
  page tables and lists write no colour operator unless a colour was given (DeviceRGB fails PDF/A with a CMYK
  intent) and the table is no longer quadratic in rows; numbered lists widen the marker column and label more
  than 26 children aa, ab ...; values no longer leak between documents piped to one call.
- Pie chart `-StrokeColor` and `-MarginTop`/`-MarginBottom` had no effect (the cmdlet's
  bound parameters were read from inside a script block, where they are empty).
- `Add-VellumPdfElement` now honours the space a previous `-MarginBottom` left (an
  invisible spacer is inserted before the element).
- `Get-VellumPdfText` on a PDF with no pages returned an error instead of nothing;
  `-DestTop` of `Add-VellumPdfLink`/`Add-VellumPdfOutlineEntry` must be finite.
- Options that were silently ignored are now applied or refused: stroke options beside
  a fill in `Add-VellumPdfShape`, `-X/-Y/-Width/-Height/-Page` with a Radio field, the
  CCITT-only image switches on other formats, and a wildcard `-Path` that matches
  several files in `Unprotect-VellumPdfDocument`.
- B-LT/B-LTA revocation lookups use a per-signature HTTP client that follows at most
  three redirects, instead of the engine's process-wide shared client.
- Table without `-Header`: the column-count check no longer counts a phantom header.

### Added (second review)
- **Culture and formats**: `-Culture` (a name such as `de-DE` or a `[cultureinfo]`) on `New-VellumPdfDocument` and
  `New-VellumPdfPageDocument` sets how numbers and dates are written; the same parameter on `Add-VellumPdfTable`,
  `Add-VellumPdfPageTable`, `Add-VellumPdfList`, `Add-VellumPdfPageList` and `Add-VellumPdfPieChart` overrides it for
  one call. The default is the invariant culture, so output does not depend on the machine.
- .NET format strings: `-ColumnFormat` (tables, one per column, beside `-ColumnAlignment`), `-Format` (lists) and
  `-LabelFormat` (pie charts, default `P1`); a table cell or list item may carry its own `Format`. The format
  decides the layout and the culture the separators: `-ColumnFormat 'N2' -Culture de-DE` writes `1.234,50`.
- `-InputCulture` (documents and the table/list cmdlets) reads number strings strictly in that culture instead of
  detecting the convention.
- **Stable error ids**: errors carry an id in `FullyQualifiedErrorId`, a typed exception and a category
  (`PSVellumPDF.FileNotFound`, `.InvalidArgument`, `.PasswordRequired`, `.InvalidPdf`, `.NotConformant`,
  `.FileReadError`, `.InputError`, `.FileExists`, and `PSVellumPDF.<Cmdlet>` for anything else); message texts are
  unchanged. See "Errors" in the README.

### Fixed (second review)
- `Add-VellumPdfList` with `-FontHandle` and a list item that contains itself crashed the PowerShell process
  (stack overflow); it now reports the nesting-depth error.
- `Add-VellumPdfPageList` added an empty sub-item under every hashtable item without `Children`; items may now be
  objects with `Text`/`Children`, and an item without text is an error. A large `-FontSize` no longer fails on the
  `-Indent` range.
- `Add-VellumPdfPageTable` failed on a row fully covered by RowSpans (`@()`) and left half a table behind; such a
  row is drawn and keeps an empty `TR`. `-Row` may be empty or omitted when `-Header` is given (also for
  `Add-VellumPdfTable`). A non-numeric `ColSpan`/`RowSpan` gives a clear error.
- Lower-case `Use-VellumPdfStructure -Type sect` and `-Role h1` passed validation but broke the save; they are
  written with the standard spelling.
- `Set-VellumPdfSignature -Level b-t` (lower case) failed with a .NET error.
- A tab in page text (`Add-VellumPdfText`, `Add-VellumPdfTextBox`, page-band templates, `Measure-VellumPdfText`)
  drew glyph 0, which PDF/A forbids, or vanished; it is drawn as four spaces.
- NaN and infinity are refused in colours and in table/list `FontSize`/`Leading` (they wrote `NaN` into the PDF).
- `Add-VellumPdfDrawing` script blocks use the variable values from when they were added (a loop variable no longer
  reads its last value; a function's locals are still there at save time), and a block that saves and restores the
  graphics state unevenly fails the save. `Invoke-VellumPdfCanvas` also detects unbalanced `BT`/`ET` and marked
  content (`BMC`/`BDC`/`EMC`).
- `Add-VellumPdfFormField -Selected` matched without regard to case but wrote the caller's spelling, so no option
  showed as selected; it writes the option's own spelling (case-only duplicates are ambiguous and refused).
- A text run without font or size wrote an empty link annotation (and failed PDF/UA).
- Drawing on a page document after `Save-VellumPdfDocument -KeepOpen` is refused (it could never be saved); the
  messages no longer call a page document a layout document. `Add-VellumPdfPage -Count N -PassThru` returns all
  new pages.
- RGB colour or an RGB image in a PDF/A document whose output intent is CMYK warns once (the file fails
  6.2.4.3); replacing a CMYK intent with an RGB one clears the CMYK state; output-intent profiles with a device
  class other than printer/monitor/scanner/colour space, or ICC version 5, are refused (PDF/A 6.2.3).
- `Export-VellumPdfImage` gives unique file names across all inputs of one call (`report-p1-i1-2.png`), so
  same-named PDFs no longer overwrite each other's images.
- `Export-VellumPdfImage` and `Unprotect-VellumPdfDocument` have `-AllowReconstruction` (their error message
  suggested it, and `-ReconstructionBudgetMultiplier` did nothing without it).
- Reader cmdlets bind piped objects with a `Path` property to `-Path` and objects with `FullName` (for example
  `Select-Object FullName`) to `-LiteralPath`.
- Tests and CI: the whole suite runs under de-DE as well (two tests were culture-dependent); checks that need qpdf,
  pdftoppm or ImageMagick report as skipped instead of passing without checking; the veraPDF PDF/UA-1 run on tagged
  page documents now fails the build, and new PDF/A-2u and PDF/A-2a samples are validated with veraPDF.

### Security
- VellumPdf 2.2 fixed `OwnerPassword = ""` with a user password producing a file that
  opens without any password; the module now refuses the combination up front and
  you should re-encrypt such files made with 1.x.
- NuGet flagged `System.Security.Cryptography.Pkcs` 10.0.12 (required by VellumPdf.Signing
  2.3.3) with two advisories. The dependency project now references Pkcs as `10.0.*`, so
  every restore takes the newest 10.0.x (10.0.14 today), and the warnings are gone. The
  module never ships that assembly: at run time signing uses the copy bundled with
  PowerShell, which a module cannot override.

### Notes
- `dependencies/packages.lock.json` and locked-mode restore were removed so Pkcs can float;
  restores are no longer bit-for-bit reproducible (the VellumPdf versions stay exact).
- VellumPdf.Layout draws no labels on pie charts and does not tag hyperlinks:
  `-Legend` adds a table, and a PDF/UA document containing `-LinkUri` is not fully
  conformant (the module warns once).
- Links and form fields in a tagged page document are untagged (VellumPdf cannot tag
  annotations), so such a document is not fully PDF/UA-conformant.
- The in-process preflight does not look at fonts used only by form fields.
- `docs/PSVellumPDF/` is generated by `./build.ps1 Docs` (PlatyPS, from the
  PowerShell Gallery) and should be regenerated before publishing.

## [1.3.1] - 2026-06-14

Hardening of the 1.3.0 features. No new parameters.

### Fixed
- `Add-VellumPdfTable` rich cells now validate their `Font` (must be a base-14
  name), `FontSize` (1..1000), and `ColSpan`/`RowSpan` (positive integers).
  Previously a bad value failed with a cryptic library error or, for a negative
  `FontSize`, succeeded silently.
- A rich cell that sets only `Color` (no `Font`/`FontSize`) now keeps the table's
  effective font instead of falling back to the library-global Helvetica.
- `Add-VellumPdfTable` fails fast when `-Row` mixes record (PSCustomObject/
  hashtable) and cell-array shapes, instead of rendering a silently-wrong table.
- Colour parameters now require a leading `#` for hex (`#3366cc`/`#36c`). A bare
  number such as `255` is no longer misread as hex (it would have become a dark
  teal); it is rejected as an unrecognised colour.
- `-LinkUri` is stored with embedded whitespace/control/format characters removed
  (the scheme was already validated against the stripped value), so no malformed
  URI reaches the `/URI` action.
- `Add-VellumPdfList` caps nesting depth (64) so a cyclic/self-referential
  hashtable raises a clear error instead of an uncatchable stack overflow.

## [1.3.0] - 2026-06-13

Usability features. No breaking changes (existing call shapes still work).

### Added
- `Add-VellumPdfTable` accepts `PSCustomObject` rows straight from `Import-Csv` or
  `Select-Object`; columns and a header are derived from the property names when
  `-Header` is omitted. (Previously such rows were rejected with a hint.)
- `Add-VellumPdfTable` rich per-cell hashtables: a cell can be
  `@{ Text=...; ColSpan=...; RowSpan=...; Background=...; Alignment=...; Font=...;
  FontSize=...; Color=... }`, enabling merged and individually styled cells.
- `Add-VellumPdfTable -AlternateRowBackground` (zebra striping on every second
  data row) and `-ColumnAlignment` (per-column alignment by index).
- Every colour parameter (`-Color`, `-BorderColor`, `-HeaderBackground`, the new
  `-AlternateRowBackground`, and a cell's `Background`/`Color`) now also accepts a
  hex string (`#3366cc` or `#36c`) or a colour name (e.g. `navy`, `orange`),
  alongside the existing R,G,B triple in 0..1.
- `Add-VellumPdfList` builds nested lists: an item may be a hashtable
  `@{ Text=...; Children=@(...) }`, nesting to any depth.
- `Add-VellumPdfImage -ImageBytes <byte[]> -Format <fmt>` embeds an in-memory
  image (chart, QR, downloaded bytes) without a temp file, mirroring
  `Register-VellumPdfFont -FontBytes`.

## [1.2.3] - 2026-06-13

Security hardening. No new cmdlets or parameters.

### Security
- `-LinkUri` (on `Add-VellumPdfParagraph` and `New-VellumPdfTextRun`) now uses a
  scheme allowlist: only `http`, `https`, and `mailto` URLs are accepted. Any
  other scheme, and relative or scheme-relative (`//host`) URIs, are rejected,
  so a generated document cannot carry an unanticipated protocol-handler link.
  Previously only `javascript`/`vbscript`/`data`/`file` were blocked. The
  whitespace/control-character normalisation that defeats `java<TAB>script:`
  smuggling is kept.
- The RFC-3161 timestamp HTTP client built for `Set-VellumPdfSignature
  -TimestampUrl` no longer follows redirects and applies `-TimestampTimeout` to
  the client itself, reducing the SSRF/stall surface of the user-supplied,
  save-time TSA request.
- `Protect-VellumPdfDocument` now warns when an owner password is set with no
  user password and the default `-Permission All` - that combination opens the
  document with no password and every permission, so nothing is restricted. The
  help also notes that PDF permission flags are advisory.

### Changed
- Gallery `Description` rewritten for readability (same facts, less dense).

## [1.2.2] - 2026-06-13

Built on VellumPdf 1.5.4 (was 1.5.3). No wrapper API change.

### Fixed
- JPEG 2000 and JBIG2 images now compose with PDF/A-2. VellumPdf 1.5.4 embeds the
  JP2 box metadata (`ihdr`/`colr`) that veraPDF reads for PDF/A-2 clause 6.2.8.3
  and only emits `/BitsPerComponent` when PDF/A permits the value, so a PDF/A-2b
  document with an embedded JPEG 2000 image is now veraPDF-conformant
  ([VellumPDF#91](https://github.com/Tim81/VellumPDF/issues/91)). Before this,
  the image was embedded as a bare codestream and veraPDF saw 0 channels / 0 bit
  depth and failed.

### Tests
- CI now veraPDF-validates two new PDF/A-2b samples - one with an embedded JPEG
  2000 image, one with a JBIG2 image - so the conformance fix cannot regress.
- Vendored `tests/assets/sample.jp2` (a real 16x16 RGB JPEG 2000) and
  `sample.jb2` (minimal JBIG2), with SHA-256 integrity checks, plus Pester
  tests embedding each in a PDF/A-2b document.

### Changed
- `Add-VellumPdfImage` help now states JPEG 2000/JBIG2 compose with PDF/A-2
  (on the bundled engine), noting JPEG 2000's channel/bit-depth requirement,
  replacing the earlier "may not conform" caveat.

## [1.2.1] - 2026-06-13

Adversarial-review follow-ups to 1.2.0. No new features; behaviour, tests, and
docs only.

### Fixed
- The `HttpClient` backing a `-TimestampUrl` timestamp is now disposed when the
  document is (and replaced cleanly when a signature is re-staged), instead of
  being orphaned - removes a connection-pool leak in long-lived sessions that
  generate many signed documents.
- A timestamp-authority failure during `Save-VellumPdfDocument` now ends with a
  hint pointing at the TSA/network (`-TimestampUrl` reachable?) instead of the
  signing certificate. The atomic write still leaves no file behind on failure.

### Changed
- `Add-VellumPdfImage` help now notes that JPEG 2000 and JBIG2 images embed in
  any document, but PDF/A-2 imposes extra ISO constraints on them (for JPEG
  2000: 1, 3, or 4 colour channels sharing one bit depth in 1-38), so PDF/A
  conformance with such an image depends on the source meeting those rules.

### Tests
- The JBIG2/JPEG 2000 routing tests now assert the format-specific loader
  message, so a misroute to a different loader is caught (the previous
  `*failed to load*` assertion passed for any loader).
- Added end-to-end tests that embed minimal valid JBIG2 and JPEG 2000 streams
  and assert the saved PDF uses `/JBIG2Decode` / `/JPXDecode`; added
  HttpClient-lifecycle and TSA-failure tests for signing.

## [1.2.0] - 2026-06-13

Built on VellumPdf 1.5.3 (was 1.2.0).

### Added
- `Set-VellumPdfSignature` RFC-3161 timestamps: `-TimestampUrl` contacts a
  Time-Stamping Authority while `Save-VellumPdfDocument` signs, upgrading the
  signature from PAdES B-B to B-T so the signing time is attested by the TSA
  rather than the signer's clock. `-TimestampTimeout` (a TimeSpan) and
  `-TimestampRequestCertificate` (default `$true`, embeds the TSA certificate
  for offline verification) tune the request. Saving a timestamped signature
  needs network access to the TSA.
- `Add-VellumPdfImage` accepts JBIG2 (`.jbig2`, `.jb2`) and JPEG 2000 (`.jp2`,
  `.jpx`, `.j2k`, `.jpf`) images, using the VellumPdf 1.4.0 codecs.

### Changed
- VellumPdf 1.3.0-1.5.3 widen image support (interlaced and 16-bit PNG; TIFF
  LZW/JPEG/Group-3/Group-4; JBIG2; JPEG 2000) and harden the image, font, and
  signing code. Existing pipelines pick these up without changes.
- 1.5.3 drops the proprietary `%VELLUM_SIG_CONTENTS` comment from the signature
  `/Contents`, so PAdES-signed PDF/A-2b output passes veraPDF 1.30+ clause
  6.4.3-1 again (the signature bytes and `/ByteRange` are unchanged).

### Notes
- AcroForm interactive form fields and outline expand/collapse state
  (`PdfOutlineEntry.IsExpanded`) ship in VellumPdf but stay unwrapped: both need
  kernel `PdfPage` references that the layout `Document` this module drives does
  not expose, the same limit that keeps internal go-to links and standalone
  outline entries out of scope. See CLAUDE.md.

## [1.1.1] - 2026-06-11

### Fixed
- `Save-VellumPdfDocument` now renders (and signs) to a temporary file and moves
  it into place only on success, so a render or signing failure no longer
  truncates an existing good file at `-Path`, and a failed save leaves no
  0-byte artifact behind.
- `Save-VellumPdfDocument -WhatIf` to a nonexistent directory no longer throws
  or disposes the document - a dry run now leaves the document open as
  documented. A real (non-`-WhatIf`) save to a missing directory still fails
  fast and disposes the document.
- Signing and file-write failures from `Save-VellumPdfDocument` now carry
  operation-specific guidance (certificate/signing or path-writability) instead
  of the layout/render hint.
- `-LinkUri` scheme blocklist now normalises out embedded whitespace and control
  characters before matching, closing a bypass where `java<TAB>script:`, a
  mid-keyword no-break space, or a leading control byte could smuggle a blocked
  scheme past the check (lenient PDF readers strip such noise before dispatching
  the scheme).

## [1.1.0] - 2026-06-11

Built on VellumPdf 1.2.0 (was 1.1.0).

### Added
- `Set-VellumPdfSignature`: PAdES digital signing (SubFilter
  `ETSI.CAdES.detached`) via the new `VellumPdf.Signing` package. Stage a
  signature anywhere in the pipeline with an `[X509Certificate2]` (from
  `Get-PfxCertificate` or the `cert:` drive) plus optional `-Reason`,
  `-Location`, `-ContactInfo`, `-SignerName` and `-SigningTime`;
  `Save-VellumPdfDocument` signs the document while writing it. Composes with
  PDF/A conformance. Signing and encryption cannot be combined (library
  constraint) - both `Set-VellumPdfSignature` and `Protect-VellumPdfDocument`
  fail fast on the conflict.
- `Set-VellumPdfOutputIntent`: replace the default sRGB PDF/A output intent
  with a custom ICC profile (`-IccProfilePath`/`-ComponentCount`) or the
  library's built-in generic CMYK profile (`-Cmyk`).

### Changed
- VellumPdf 1.2.0 brings CFF (OpenType-CFF) font subsetting, cmap subtable
  formats 0 and 6, ICC-based colour management, and hardened font parsers.
  Existing pipelines benefit transparently (smaller embedded-font output).

## [1.0.0] - 2026-06-11

First stable release, built on VellumPdf 1.1.0. PDF/A-2b output is now
validated with veraPDF (and structure with qpdf) in CI on every push.

### Added
- `Add-VellumPdfLineSeparator` for horizontal rules.
- `-Leading` (line spacing) on `New-VellumPdfTextRun` and `Add-VellumPdfParagraph`.
- `-MarginTop`/`-MarginBottom` spacing on all content cmdlets.
- `Register-VellumPdfFont -FontBytes` to embed a font from memory.
- `New-VellumPdfDocument -UseObjectStreams` (compressed object streams) and
  `-Language` (PDF `/Lang` entry for accessibility).
- Warning when text contains characters the base-14 fonts cannot encode -
  VellumPdf otherwise renders them silently mangled; use
  `Register-VellumPdfFont`/`-FontHandle` for full Unicode.
- Complete parameter help on every cmdlet (`Get-Help -Full` and docs/).
- Stress test generating a 200+ page mixed-content document.

### Fixed
- Cross-document font handles silently produced PDFs whose text cannot render;
  content cmdlets now reject handles registered on a different document.
- Dangerous `-LinkUri` schemes (`javascript:`, `vbscript:`, `data:`, `file:`)
  were written verbatim into `/URI` actions; now rejected. Whitespace-only
  URIs no longer produce a broken annotation.
- Cmdlets fail fast with a clear error when given a document that
  `Save-VellumPdfDocument` already disposed (VellumPdf silently accepts it).
- Calling `Protect-VellumPdfDocument` twice left an orphaned `/Encrypt`
  object; the second call now throws.
- `-ColumnWidth` accepts only positive widths (negative values produced
  malformed layout) and warns when the count does not match the columns.
- `Add-VellumPdfTable` rejects PSCustomObject rows (e.g. from `Import-Csv`)
  with a conversion hint instead of mangling all columns into one cell.
- Image load failures now include the file path; render failures from `Save`
  carry a remediation hint; emoji in encoding warnings report the real
  codepoint instead of a UTF-16 surrogate half.
- `Add-VellumPdfList -Item` accepts empty strings (blank entries).

## [0.1.0] - 2026-06-10

First public release, built on VellumPdf 1.1.0 (.NET 10).

### Added
- Fluent pipeline API: `New-VellumPdfDocument | Add-VellumPdf* | Save-VellumPdfDocument`.
- Documents: page size, margins, PDF/A-2b/2u/2a conformance, tagged PDF,
  `/Lang` language entry, document metadata (`Set-VellumPdfDocumentInfo`).
- Content: headings with outline bookmarks, paragraphs with mixed-style runs,
  colour and hyperlinks (`New-VellumPdfTextRun`), tables, ordered/unordered
  lists, images (JPEG/PNG/BMP/GIF/TIFF).
- Embedded TrueType fonts (`Register-VellumPdfFont` + `-FontHandle`) enabling
  Unicode text and PDF/A font embedding.
- Running headers/footers with `{page}`/`{pages}` tokens.
- Encryption with permissions (`Protect-VellumPdfDocument`, SecureString).
- Quality gates: PSScriptAnalyzer, Pester (94% coverage), 3-OS CI, locked
  NuGet restore, SHA-pinned actions, PSGallery release pipeline.

[Unreleased]: https://github.com/Tim81/PSVellumPDF/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/Tim81/PSVellumPDF/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/Tim81/PSVellumPDF/compare/v1.2.3...v1.3.0
[1.2.3]: https://github.com/Tim81/PSVellumPDF/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/Tim81/PSVellumPDF/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/Tim81/PSVellumPDF/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Tim81/PSVellumPDF/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/Tim81/PSVellumPDF/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/Tim81/PSVellumPDF/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Tim81/PSVellumPDF/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/Tim81/PSVellumPDF/releases/tag/v0.1.0
