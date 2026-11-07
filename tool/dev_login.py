"""Type a dev account's email and password into the app's sign-in screen on the
test tablet, choose the matching "Preferred view", and press Sign in.

    python -I tool/dev_login.py [admin|supervisor|dispatcher|tech]    (default: admin)

Reads VOLTCORE_DEV_EMAIL_<ROLE> / VOLTCORE_DEV_PASSWORD_<ROLE> from
dev_credentials.local.json (git-ignored). Nothing is printed. Stops with a
message if those entries are empty.

Tap positions are for the Samsung test tablet (1320x2112) with the sign-in
screen showing and no keyboard open; adjust them for another device.
"""
import json
import os
import subprocess
import sys
import time

SERIAL = os.environ.get('VOLTCORE_DEVICE', 'R52Y80JVX9M')
ADB = os.path.expandvars(r'%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe')
CREDS = 'dev_credentials.local.json'

EMAIL_FIELD = (660, 693)
PASSWORD_FIELD = (600, 809)
SIGN_IN = (660, 1552)
VIEWS = {'tech': 1022, 'supervisor': 1146, 'dispatcher': 1269, 'admin': 1392}

SPECIAL = set('&|;<>()$`\\"\' *?[]{}~#!^%')


def shell(*args):
    subprocess.run([ADB, '-s', SERIAL, 'shell', *args], check=True)


def tap(x, y):
    shell('input', 'tap', str(x), str(y))


def type_text(s):
    esc = ''.join(('\\' + c) if c in SPECIAL else c for c in s).replace('\\ ', '%s')
    shell('input', 'text', esc)


def main(role):
    role = role.lower()
    if role not in VIEWS:
        sys.exit(__doc__)
    creds = json.load(open(CREDS))
    email = creds.get('VOLTCORE_DEV_EMAIL_' + role.upper(), '')
    password = creds.get('VOLTCORE_DEV_PASSWORD_' + role.upper(), '')
    if not email or not password:
        sys.exit(f'No {role} credentials in {CREDS}.')
    tap(*EMAIL_FIELD); time.sleep(.5); type_text(email)
    tap(*PASSWORD_FIELD); time.sleep(.5); type_text(password)
    shell('input', 'keyevent', '4')  # close the keyboard
    time.sleep(1)
    tap(660, VIEWS[role]); time.sleep(.5)
    tap(*SIGN_IN)
    print('submitted')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'admin')
