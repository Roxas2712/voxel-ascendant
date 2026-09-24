"""Validate all dumped production Voxel3D shader variants with Khronos glslang."""
import argparse
from pathlib import Path
import subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('directory',type=Path)
p.add_argument('--compiler',default='glslang')
a=p.parse_args()
files=sorted([*a.directory.glob('*.vert'),*a.directory.glob('*.frag')])
assert len(files)==60, f'Expected 60 shader stages, found {len(files)}'
failed=[]
for shader in files:
 result=subprocess.run([a.compiler,str(shader)],capture_output=True,text=True)
 if result.returncode:
  failed.append(shader.name)
  print(result.stdout+result.stderr)
# Stage compilation alone misses GLES uniform-interface precision mismatches.
pairs=sorted(a.directory.glob('*.vert'))
for vertex in pairs:
 fragment=vertex.with_suffix('.frag')
 assert fragment.exists(), f'Missing fragment stage for {vertex.name}'
 result=subprocess.run([a.compiler,'-l',str(vertex),str(fragment)],capture_output=True,text=True)
 if result.returncode:
  failed.append(vertex.stem+' (link)')
  print(result.stdout+result.stderr)
print(f'Validated {len(files)} stages and {len(pairs)} linked programs; failures: {len(failed)}')
raise SystemExit(bool(failed))
