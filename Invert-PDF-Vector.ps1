# Invert PDF drawing colors without rasterizing text / shapes / notation.
# Requires PyMuPDF
# to install PyMuPDF, powershell line: py -3 -m pip install pymupdf
#

param(
    [string]$Path = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$python = @'
import fitz, re, pathlib, sys
root = pathlib.Path(sys.argv[1])
files = [root] if root.is_file() else sorted(p for p in root.glob('*.pdf') if not p.stem.lower().endswith('_dark'))
# PDF content stream RGB, grayscale, and CMYK color-setting operators.
pat = re.compile(rb'(?m)(?<!\S)((?:[+]?(?:\d*\.\d+|\d+\.?\d*)\s+){1,4})(rg|RG|g|G|k|K)(?=\s|$)')
def invert(m):
    op = m.group(2)
    vals = list(map(float, m.group(1).split()))
    count = 3 if op in (b'rg', b'RG') else 1 if op in (b'g', b'G') else 4
    if len(vals) != count: return m.group(0)
    # CMYK: convert to RGB, invert, emit RGB operator for a predictable result.
    if count == 4:
        c, mag, y, k = vals
        rgb = [(1-c)*(1-k), (1-mag)*(1-k), (1-y)*(1-k)]
        op = b'rg' if op == b'k' else b'RG'
        return b' '.join(f'{1-v:.6f}'.encode() for v in rgb) + b' ' + op
    return b' '.join(f'{1-v:.6f}'.encode() for v in vals) + b' ' + op
for src in files:
    dst = src.with_name(src.stem + '_Dark.pdf')
    try:
        doc = fitz.open(str(src))
        if doc.needs_pass:
            print(f'SKIP password protected: {src.name}'); doc.close(); continue
        changed = 0
        seen = set()
        for page in doc:
            for xref in page.get_contents():
                if xref in seen: continue
                seen.add(xref)
                data = doc.xref_stream(xref)
                new, n = pat.subn(invert, data)
                if n:
                    doc.update_stream(xref, new)
                    changed += n
        # Add full-page black underlay, covering formerly transparent / viewer-white margins.
        for page in doc:
            page.draw_rect(page.rect, color=None, fill=(0, 0, 0), overlay=False)
        doc.save(str(dst), garbage=4, deflate=True)
        doc.close()
        print(f'{src.name} -> {dst.name} ({changed} color commands changed)')
    except Exception as e:
        print(f'ERROR {src.name}: {e}', file=sys.stderr)
'@
$temp = Join-Path $env:TEMP ("pdf_invert_" + [guid]::NewGuid().ToString('N') + '.py')
try {
    [System.IO.File]::WriteAllText($temp, $python, [System.Text.UTF8Encoding]::new($false))
    & py -3 $temp $Path
    if ($LASTEXITCODE -ne 0) { throw 'Conversion failed. Install PyMuPDF: py -3 -m pip install pymupdf' }
} finally {
    Remove-Item $temp -ErrorAction SilentlyContinue
}
