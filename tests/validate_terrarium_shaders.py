"""Compile and link the installed Terrarium's auxiliary GL/GLES shader pairs."""
import argparse
from pathlib import Path
import subprocess
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=Path)
parser.add_argument('--compiler', default='glslang')
args = parser.parse_args()
failures = []
for name in ('Dome', 'Background', 'GymAtmosphere'):
    for version in ('1', '3'):
        for backend in ('gl', 'es'):
            stem = f'{name}-{version}-{backend}'
            vertex = args.directory / f'{stem}.vert'
            fragment = args.directory / f'{stem}.frag'
            assert vertex.exists() and fragment.exists(), stem
            result = subprocess.run([args.compiler, '-l', str(vertex), str(fragment)], capture_output=True, text=True)
            if result.returncode:
                failures.append(stem)
                print(result.stdout + result.stderr)
print(f'Terrarium: 24 stages / 12 linked programs; failures: {len(failures)}')
raise SystemExit(bool(failures))
