"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def ident(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()


def obj(label, isa, **fields):
    key = ident(label)
    objects[key] = {"isa": isa, **fields}
    return key


def serialize(value):
    if isinstance(value, dict):
        return "{ " + " ".join(f"{k} = {serialize(v)};" for k, v in value.items()) + " }"
    if isinstance(value, list):
        return "(" + ", ".join(serialize(v) for v in value) + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


def group_tree(path, sources, resources):
    children = []
    for child in sorted(path.iterdir()):
        if child.name.startswith("."):
            continue
        label = str(child.relative_to(ROOT)).replace("\\", "/")
        if child.is_dir() and child.suffix != ".xcassets":
            children.append(group_tree(child, sources, resources))
            continue
        file_type = {".swift": "sourcecode.swift", ".plist": "text.plist.xml", ".xcprivacy": "text.xml", ".xcassets": "folder.assetcatalog"}.get(child.suffix)
        if not file_type:
            continue
        ref = obj(label, "PBXFileReference", lastKnownFileType=file_type, path=child.name, sourceTree="<group>")
        children.append(ref)
        if child.suffix == ".swift":
            sources.append(obj(label + "-build", "PBXBuildFile", fileRef=ref))
        elif child.suffix in (".xcprivacy", ".xcassets"):
            resources.append(obj(label + "-build", "PBXBuildFile", fileRef=ref))
    return obj(str(path.relative_to(ROOT)) + "-group", "PBXGroup", children=children, path=path.name, sourceTree="<group>")


def configurations(label, common, debug=None, release=None):
    configs = []
    for name, extra in (("Debug", debug or {}), ("Release", release or {})):
        configs.append(obj(label + name, "XCBuildConfiguration", name=name, buildSettings=common | extra))
    return obj(label + "-configs", "XCConfigurationList", buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def generate():
    resources = ROOT / "MyNews/Resources"
    assets = resources / "Assets.xcassets"
    assets.mkdir(parents=True, exist_ok=True)
    (assets / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    info = {
        "CFBundleDevelopmentRegion": "es", "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)", "CFBundleDisplayName": "MyNews", "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1", "LSRequiresIPhoneOS": True,
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
        "UILaunchScreen": {}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "NewsBackendURL": "",  # Set a public HTTPS backend URL here. No provider secrets.
    }
    info_path = resources / "Info.plist"
    if not info_path.exists():
        info_path.write_bytes(plistlib.dumps(info))
    privacy = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults", "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]},
            {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp", "NSPrivacyAccessedAPITypeReasons": ["C617.1"]},
        ],
    }
    (resources / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(privacy))
    app_sources, app_resources, test_sources = [], [], []
    app_group = group_tree(ROOT / "MyNews", app_sources, app_resources)
    test_group = group_tree(ROOT / "MyNewsTests", test_sources, [])
    product = obj("app-product", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0, path="MyNews.app", sourceTree="BUILT_PRODUCTS_DIR")
    test_product = obj("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", includeInIndex=0, path="MyNewsTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    products = obj("products", "PBXGroup", children=[product, test_product], name="Products", sourceTree="<group>")
    main = obj("main", "PBXGroup", children=[app_group, test_group, products], sourceTree="<group>")
    common = {"CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SDKROOT": "iphoneos",
              "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "complete"}
    project_configs = configurations("project", common,
        {"SWIFT_OPTIMIZATION_LEVEL": "-Onone", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "ENABLE_TESTABILITY": "YES", "DEBUG_INFORMATION_FORMAT": "dwarf"},
        {"SWIFT_OPTIMIZATION_LEVEL": "-O", "SWIFT_COMPILATION_MODE": "wholemodule", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"})
    target_common = {"CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "", "TARGETED_DEVICE_FAMILY": "1",
                     "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
                     "PRODUCT_NAME": "$(TARGET_NAME)", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]}
    app_configs = configurations("app", target_common | {"GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "MyNews/Resources/Info.plist", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.mynews", "ENABLE_PREVIEWS": "YES"})
    test_configs = configurations("tests", target_common | {"GENERATE_INFOPLIST_FILE": "YES", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.mynews.tests",
            "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/MyNews.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MyNews", "BUNDLE_LOADER": "$(TEST_HOST)"})
    def phases(label, sources, resources):
        return [obj(label + "-sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0),
                obj(label + "-frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0),
                obj(label + "-resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0)]
    app = obj("app-target", "PBXNativeTarget", buildConfigurationList=app_configs, buildPhases=phases("app", app_sources, app_resources), buildRules=[], dependencies=[], name="MyNews", productName="MyNews", productReference=product, productType="com.apple.product-type.application")
    proxy = obj("test-proxy", "PBXContainerItemProxy", containerPortal=ident("project"), proxyType=1, remoteGlobalIDString=app, remoteInfo="MyNews")
    dep = obj("test-dependency", "PBXTargetDependency", target=app, targetProxy=proxy)
    tests = obj("test-target", "PBXNativeTarget", buildConfigurationList=test_configs, buildPhases=phases("test", test_sources, []), buildRules=[], dependencies=[dep], name="MyNewsTests", productName="MyNewsTests", productReference=test_product, productType="com.apple.product-type.bundle.unit-test")
    project = obj("project", "PBXProject", attributes={"LastUpgradeCheck": "1600", "BuildIndependentTargetsInParallel": "YES"}, buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="es", knownRegions=["es", "en", "Base"], mainGroup=main, productRefGroup=products, projectDirPath="", projectRoot="", targets=[app, tests])
    project_dir = ROOT / "MyNews.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    content = "// !$*UTF8*$!\n" + serialize({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project})
    (project_dir / "project.pbxproj").write_text(content, encoding="utf-8")
    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    def reference(parent, target_id, name, buildable):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target_id, BuildableName=buildable, BlueprintName=name, ReferencedContainer="container:MyNews.xcodeproj")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    reference(entry, app, "MyNews", "MyNews.app")
    test_action = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    reference(ET.SubElement(ET.SubElement(test_action, "Testables"), "TestableReference", skipped="NO"), tests, "MyNewsTests", "MyNewsTests.xctest")
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
    reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), app, "MyNews", "MyNews.app")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), app, "MyNews", "MyNews.app")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    scheme_dir = project_dir / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(scheme_dir / "MyNews.xcscheme", encoding="utf-8", xml_declaration=True)
    print(f"Generated project: {len(app_sources)} Swift sources, {len(test_sources)} test files, {len(app_resources)} resources.")


if __name__ == "__main__":
    generate()
