# Non-raster PDF negative using a white /Difference blend overlay.
# Requires: py -3 -m pip install pymupdf
param([string]$Path = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$code = @'
import fitz, pathlib, sys
source = pathlib.Path(sys.argv[1]).resolve()
if source.is_dir():
    inputs = sorted(p for p in source.glob('*.pdf') if not p.stem.lower().endswith('_dark'))
elif source.is_file():
    inputs = [source]
else:
    raise SystemExit(f'Path not found: {source}')
if not inputs:
    print('No input PDFs found.')

def install_blend_resource(doc, page, name):
    kind, value = doc.xref_get_key(page.xref, 'Resources')
    if kind != 'xref':
        raise ValueError('Unsupported page resource dictionary')
    resources_xref = int(value.split()[0])
    blend = '<</Type /ExtGState /BM /Difference /ca 1 /CA 1>>'
    ext_type, ext_value = doc.xref_get_key(resources_xref, 'ExtGState')
    if ext_type == 'xref':
        doc.xref_set_key(int(ext_value.split()[0]), name, blend)
    else:
        doc.xref_set_key(resources_xref, 'ExtGState/' + name, blend)

for src in inputs:
    dst = src.with_name(src.stem + '_Dark.pdf')
    try:
        doc = fitz.open(src)
        if doc.needs_pass:
            print(f'SKIPPED (password protected): {src.name}')
            doc.close()
            continue
        for page in doc:
            # Add an opaque white base even if original PDF relies on transparent paper.
            page.draw_rect(page.rect, fill=(1, 1, 1), color=None, overlay=False)
            # Add a white layer on top. Difference blending: abs(backdrop - 1) = inverse.
            page.draw_rect(page.rect, fill=(1, 1, 1), color=None, overlay=True)
            last_xref = page.get_contents()[-1]
            raw = doc.xref_stream(last_xref)
            replacement = raw.replace(b'1 1 1 rg f', b'/PDF_NEGATIVE gs 1 1 1 rg f')
            if replacement == raw:
                raise ValueError('Unexpected PyMuPDF drawing output; overlay not patched')
            doc.update_stream(last_xref, replacement)
            install_blend_resource(doc, page, 'PDF_NEGATIVE')
        doc.save(dst, garbage=4, deflate=True)
        doc.close()
        print(f'OK: {src.name} -> {dst.name}')
    except Exception as exc:
        print(f'ERROR: {src.name}: {exc}', file=sys.stderr)
'@
$temp = Join-Path $env:TEMP ("invert_pdf_" + [guid]::NewGuid().ToString('N') + '.py')
try {
    [IO.File]::WriteAllText($temp, $code, [Text.UTF8Encoding]::new($false))
    & py -3 $temp $Path
    if ($LASTEXITCODE -ne 0) { throw 'Python conversion failed. Install: py -3 -m pip install pymupdf' }
}
finally {
    Remove-Item $temp -ErrorAction SilentlyContinue
}
