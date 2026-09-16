"""Validate delivered project references and resource syntax, without claiming a Swift build."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def parse_project(text):
    text = text.split("\n", 1)[1]
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', text)
    index = 0
    def take(expected=None):
        nonlocal index
        token = tokens[index]
        index += 1
        if expected is not None:
            assert token == expected, (token, expected)
        return token
    def value():
        token = take()
        if token == "{":
            result = {}
            while tokens[index] != "}":
                key = take()
                key = json.loads(key) if key.startswith('"') else key
                take("=")
                assert key not in result, f"Duplicate project key {key}"
                result[key] = value()
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while tokens[index] != ")":
                result.append(value())
                if tokens[index] == ",":
                    take(",")
            take(")")
            return result
        return json.loads(token) if token.startswith('"') else token
    result = value()
    assert index == len(tokens)
    return result


def main():
    project = parse_project((ROOT / "MyNews.xcodeproj/project.pbxproj").read_text(encoding="utf-8"))
    objects = project["objects"]
    project_object = objects[project["rootObject"]]
    paths = {}
    def visit(group_id, parent):
        group = objects[group_id]
        base = parent / group.get("path", "")
        for child_id in group.get("children", []):
            child = objects[child_id]
            if child["isa"] == "PBXGroup":
                visit(child_id, base)
            elif child.get("sourceTree") != "BUILT_PRODUCTS_DIR":
                path = base / child["path"]
                assert path.exists(), f"Missing referenced file: {path}"
                paths[child_id] = path
    visit(project_object["mainGroup"], ROOT)
    targets = {objects[i]["name"]: objects[i] for i in project_object["targets"]}
    for name, source_root in (("MyNews", "MyNews"), ("MyNewsTests", "MyNewsTests")):
        target = targets[name]
        actual = set()
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            if phase["isa"] == "PBXSourcesBuildPhase":
                for build_id in phase["files"]:
                    path = paths[objects[build_id]["fileRef"]]
                    assert path not in actual, f"Duplicate compilation: {path}"
                    actual.add(path)
        expected = set((ROOT / source_root).rglob("*.swift"))
        assert actual == expected, f"Target membership mismatch: {name}, {expected ^ actual}"
        print(f"OK {name}: {len(actual)} Swift files referenced exactly once")
    sources = list((ROOT / "MyNews").rglob("*.swift"))
    assert sum(p.read_text(encoding="utf-8").count("@main") for p in sources) == 1
    for path in (ROOT / "MyNews/Resources").rglob("*"):
        if path.suffix in (".plist", ".xcprivacy"):
            plistlib.loads(path.read_bytes())
        if path.suffix == ".json":
            json.loads(path.read_text())
    scheme = ET.parse(ROOT / "MyNews.xcodeproj/xcshareddata/xcschemes/MyNews.xcscheme")
    for ref in scheme.findall(".//BuildableReference"):
        assert objects[ref.attrib["BlueprintIdentifier"]]["name"] == ref.attrib["BlueprintName"]
    fixture = json.loads((ROOT / "Backend/sample.apns").read_text())
    assert fixture["aps"]["alert"]["title"]
    print("OK project syntax, file paths, entry point, scheme, plists, assets and push payload")
    print("Swift compilation and simulator execution still require Xcode on macOS.")


if __name__ == "__main__":
    main()
