"""Package source without private configuration or credentials."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
destination = root.parent / 'MyNews-iOS.zip'


def included(path):
    if any(part in {'__pycache__', '.git', 'DerivedData', 'build', 'xcuserdata'} for part in path.parts):
        return False
    if path.name.startswith('.env') and path.name != '.env.example':
        return False
    return path.suffix not in {'.pyc', '.p8', '.p12'} and path.name != 'Secrets.xcconfig'


if __name__ == '__main__':
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob('*')):
            if path.is_file() and included(path.relative_to(root)):
                archive.write(path, Path(root.name) / path.relative_to(root))
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert all(included(Path(name)) for name in archive.namelist())
        print('ZIP verificado, sin archivos de credenciales:', len(archive.namelist()), 'archivos')
