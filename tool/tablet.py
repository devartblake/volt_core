"""Drive the test tablet over adb: install the debug build, push files, take
screenshots, tap, relaunch.

    python -I tool/tablet.py build            # flutter debug build with dev credentials
    python -I tool/tablet.py install          # install build/app/outputs/flutter-apk/app-debug.apk (-r keeps data)
    python -I tool/tablet.py push FILE [NAME] # copy FILE to /sdcard/Download/NAME
    python -I tool/tablet.py shot [OUT.png]   # screenshot (default: tablet.png)
    python -I tool/tablet.py tap X Y          # tap at pixel coordinates
    python -I tool/tablet.py swipe X1 Y1 X2 Y2
    python -I tool/tablet.py relaunch         # force-stop and start the app

The device serial defaults to the Samsung test tablet; override with the
VOLTCORE_DEVICE environment variable. adb is found under %LOCALAPPDATA%.
After a large import, `relaunch` also nudges the offline sync queue, which
drains about 100 changes per run.
"""
import os
import subprocess
import sys

APP_ID = 'com.theoreticalmindstech.voltcore'
SERIAL = os.environ.get('VOLTCORE_DEVICE', 'R52Y80JVX9M')
ADB = os.path.expandvars(r'%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe')
FLUTTER = os.path.expandvars(r'%LOCALAPPDATA%\flutter\bin\flutter.bat')
APK = os.path.join('build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk')


def adb(*args, **kw):
    return subprocess.run([ADB, '-s', SERIAL, *args], check=True, **kw)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, rest = argv[0], argv[1:]
    if cmd == 'build':
        creds = 'dev_credentials.local.json'
        extra = [f'--dart-define-from-file={creds}'] if os.path.exists(creds) else []
        subprocess.run([FLUTTER, 'build', 'apk', '--debug', *extra], check=True)
    elif cmd == 'install':
        adb('install', '-r', APK)
    elif cmd == 'push':
        name = rest[1] if len(rest) > 1 else os.path.basename(rest[0])
        adb('push', rest[0], '/sdcard/Download/' + name)
    elif cmd == 'shot':
        out = rest[0] if rest else 'tablet.png'
        with open(out, 'wb') as f:
            adb('exec-out', 'screencap', '-p', stdout=f)
        print(out)
    elif cmd == 'tap':
        adb('shell', 'input', 'tap', rest[0], rest[1])
    elif cmd == 'swipe':
        adb('shell', 'input', 'swipe', *rest[:4], '300')
    elif cmd == 'relaunch':
        adb('shell', 'am', 'force-stop', APP_ID)
        adb('shell', 'monkey', '-p', APP_ID, '1', stdout=subprocess.DEVNULL)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv[1:])
