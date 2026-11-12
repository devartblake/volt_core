"""Show or change the app version in pubspec.yaml, and keep CHANGELOG.md in step.

    python -I tool/bump_version.py show
    python -I tool/bump_version.py patch            # 0.9.0+3  ->  0.9.1+4
    python -I tool/bump_version.py minor            # 0.9.1+4  ->  0.10.0+5
    python -I tool/bump_version.py major            # 0.10.0+5 ->  1.0.0+6
    python -I tool/bump_version.py build            # 1.0.0+6  ->  1.0.0+7  (same release, new upload)
    python -I tool/bump_version.py set 1.0.0        # exact version, build number +1
    python -I tool/bump_version.py set 1.0.0+20     # exact version and build number

Options (with patch / minor / major / set):
    --tag        also create the git tag v<version> on the current commit (not pushed)
    --dry-run    print what would change and touch nothing

The version has the form  MAJOR.MINOR.PATCH+BUILD:
  * MAJOR.MINOR.PATCH is what people see (Settings > About).
  * BUILD must go up on every build you upload anywhere (Android's versionCode).
    It never resets, even when the version changes.

When the version changes, the entries under "## [Unreleased]" in CHANGELOG.md
move under a new "## [<version>] - <date>" heading, and Unreleased is left empty.
See docs/release_versioning.md for the policy.
"""
import datetime
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')
CHANGELOG = os.path.join(ROOT, 'CHANGELOG.md')

VERSION_LINE = re.compile(r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$', re.M)


def read(path):
    with open(path, encoding='utf-8', newline='') as f:
        return f.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


def current():
    m = VERSION_LINE.search(read(PUBSPEC))
    if not m:
        sys.exit('pubspec.yaml has no "version: X.Y.Z+N" line.')
    major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))
    build = int(m.group(4)) if m.group(4) else 0
    return major, minor, patch, build


def fmt(major, minor, patch, build):
    return f'{major}.{minor}.{patch}+{build}'


def parse_target(text, build):
    m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', text.strip())
    if not m:
        sys.exit(f'"{text}" is not a version like 1.2.3 or 1.2.3+45.')
    b = int(m.group(4)) if m.group(4) else build + 1
    return int(m.group(1)), int(m.group(2)), int(m.group(3)), b


def update_changelog(version_name, dry):
    if not os.path.exists(CHANGELOG):
        return 'CHANGELOG.md not found (skipped)'
    text = read(CHANGELOG)
    nl = '\r\n' if '\r\n' in text else '\n'
    text = text.replace('\r\n', '\n')
    m = re.search(r'^## \[Unreleased\]\s*\n', text, re.M)
    if not m:
        return 'CHANGELOG.md has no "## [Unreleased]" heading (skipped)'
    start = m.end()
    nxt = re.search(r'^## \[', text[start:], re.M)
    end = start + nxt.start() if nxt else len(text)
    body = text[start:end].strip('\n')
    today = datetime.date.today().isoformat()
    released = f'## [{version_name}] - {today}\n\n' + (body + '\n\n' if body.strip() else '_No notes._\n\n')
    new_text = text[:m.start()] + '## [Unreleased]\n\n' + released + text[end:]
    if not dry:
        write(CHANGELOG, new_text.replace('\n', nl))
    return f'CHANGELOG.md: Unreleased entries moved under [{version_name}]'


def main(argv):
    if not argv or argv[0] in ('-h', '--help', 'help'):
        sys.exit(__doc__)
    dry = '--dry-run' in argv
    tag = '--tag' in argv
    args = [a for a in argv if not a.startswith('--')]
    cmd = args[0]
    major, minor, patch, build = current()
    if cmd == 'show':
        print(fmt(major, minor, patch, build))
        return
    if cmd == 'patch':
        new = (major, minor, patch + 1, build + 1)
    elif cmd == 'minor':
        new = (major, minor + 1, 0, build + 1)
    elif cmd == 'major':
        new = (major + 1, 0, 0, build + 1)
    elif cmd == 'build':
        new = (major, minor, patch, build + 1)
    elif cmd == 'set' and len(args) > 1:
        new = parse_target(args[1], build)
    else:
        sys.exit(__doc__)

    old_s, new_s = fmt(major, minor, patch, build), fmt(*new)
    print(f'{old_s}  ->  {new_s}')
    name_changed = new[:3] != (major, minor, patch)
    if dry:
        print('(dry run: nothing changed)')
    else:
        text = read(PUBSPEC)
        write(PUBSPEC, VERSION_LINE.sub(f'version: {new_s}', text, count=1))
        print('pubspec.yaml updated')
    if name_changed:
        print(update_changelog('.'.join(map(str, new[:3])), dry))
    if tag and not dry:
        name = 'v' + '.'.join(map(str, new[:3]))
        subprocess.run(['git', 'tag', name], cwd=ROOT, check=True)
        print(f'created git tag {name} (not pushed)')


if __name__ == '__main__':
    main(sys.argv[1:])
