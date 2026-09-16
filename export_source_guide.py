from pathlib import Path

root = Path(__file__).resolve().parents[1]
sections = ["# Código Swift completo\n\nCada encabezado indica la ruta exacta desde la raíz del proyecto. Los archivos ya están creados y agregados al target de Xcode. Consulta FASES.md para explicación y pruebas.\n"]
for folder in (root / "MyNews", root / "MyNewsTests"):
    for path in sorted(folder.rglob("*.swift")):
        sections.append(f"\n## {path.relative_to(root).as_posix()}\n\n```swift\n{path.read_text(encoding='utf-8').rstrip()}\n```\n")
(root / "CODIGO-SWIFT.md").write_text("".join(sections), encoding="utf-8")
print("Exported complete Swift source guide.")
