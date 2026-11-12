"""Print the sheets and first rows of an .xlsx file, using only the standard
library (no openpyxl needed).

Used to look at a spreadsheet before writing an inventory import for it, for
example assets/Shop Steward Procurement Tracker.xlsx.

    python -I tool/inspect_xlsx.py "assets/Shop Steward Procurement Tracker.xlsx" [rows]

Prints, per sheet: its name, whether it is hidden, its row count, then the
first [rows] rows (default 15) as `CELL=value` pairs. Empty cells are skipped
and values are cut at 60 characters.
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {
    'm': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
}


def main(path, limit):
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in root.findall('m:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))

    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    relmap = {r.get('Id'): r.get('Target') for r in rels}

    for s in wb.find('m:sheets', NS):
        target = relmap[s.get('{%s}id' % NS['r'])].lstrip('/')
        sheet_path = target if target.startswith('xl/') else 'xl/' + target
        rows = ET.fromstring(z.read(sheet_path)).findall('.//m:row', NS)
        print('##', s.get('name'), 'state=', s.get('state'), 'rows=', len(rows))
        for row in rows[:limit]:
            out = []
            for c in row.findall('m:c', NS):
                v = c.find('m:v', NS)
                t = c.get('t')
                if t == 's' and v is not None:
                    val = shared[int(v.text)]
                elif t == 'inlineStr':
                    val = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['m']))
                else:
                    val = v.text if v is not None else ''
                if val != '':
                    out.append('%s=%s' % (c.get('r'), val[:60]))
            print(' | '.join(out))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 15)
