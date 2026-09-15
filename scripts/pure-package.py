#!/usr/bin/env python3
"""Package the installable APK and corresponding working-tree source."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import zipfile


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    apk = root / 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
    if not apk.is_file():
        raise SystemExit('Build the APK with bash scripts/pure-build.sh first.')
    output = root / 'dist'
    output.mkdir(exist_ok=True)
    target = output / 'jiankan-0.1.0-arm64-v8a.apk'
    shutil.copy2(apk, target)
    source = output / 'jiankan-0.1.0-source.zip'
    paths = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=root,
    ).decode().split('\0')
    excluded = {'AGENTS.md', 'android/local.properties', 'android/key.properties', 'pili_release.json'}
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for name in sorted(set(paths)):
            if not name or name in excluded or name.startswith(('.toolchain/', 'dist/', '.git/')):
                continue
            path = root / name
            if path.is_file() and not path.is_symlink() and path.suffix not in {'.jks', '.keystore', '.log'}:
                bundle.write(path, 'jiankan/' + name)
    with zipfile.ZipFile(source) as bundle:
        if bundle.testzip() is not None:
            raise SystemExit('Source archive verification failed.')
    outputs = [target, source]
    (output / 'SHA256SUMS').write_text(''.join(
        f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n'
        for path in outputs
    ))
    for path in outputs:
        print(f'{path.name}: {path.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
