"""Find source files that are not valid UTF-8, and optionally repair them.

    python -I tool/utf8_scan.py          # report only
    python -I tool/utf8_scan.py --fix    # replace bad bytes with "-" and rewrite as UTF-8

Why: a Python or shell edit that reads and writes a file with the Windows
default encoding turns characters such as the em dash into a single legacy
byte. Dart's compiler and the test runner tolerate that, but `flutter analyze`
then reports the file as not existing ("Target of URI doesn't exist") and
every file importing it shows errors. Run this after scripted edits, and
always open files in Python with encoding='utf-8'.

Scans lib/, test/, tool/, docs/ and supabase/ for .dart, .md, .py, .sql, .yaml
and .json files, relative to the project root (the parent of this folder).
Exits with status 1 when invalid files are found and --fix was not given, so it
can be used in a check script or CI.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = ('lib', 'test', 'tool', 'docs', 'supabase')
SUFFIXES = ('.dart', '.md', '.py', '.sql', '.yaml', '.json')


def main(fix):
    bad = []
    for folder in FOLDERS:
        for directory, _, files in os.walk(os.path.join(ROOT, folder)):
            for name in files:
                if not name.endswith(SUFFIXES):
                    continue
                path = os.path.join(directory, name)
                data = open(path, 'rb').read()
                try:
                    data.decode('utf-8')
                except UnicodeDecodeError:
                    bad.append(path)
                    if fix:
                        text = data.decode('utf-8', errors='replace')
                        text = text.replace('�', '-')
                        open(path, 'wb').write(text.encode('utf-8'))
    verb = 'repaired' if fix else 'found'
    print(f'{len(bad)} file(s) with invalid UTF-8 {verb}')
    for path in bad:
        print('  ', os.path.relpath(path, ROOT))
    return 1 if bad and not fix else 0


if __name__ == '__main__':
    sys.exit(main('--fix' in sys.argv))
