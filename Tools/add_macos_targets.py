#!/usr/bin/env python3
"""Add the native macOS targets (App-macOS, Shared-macOS) to HomeAssistant.xcodeproj.

Additive-only pbxproj surgery: no existing entry is modified beyond appending to
lists, so every iOS / watchOS / Catalyst target is untouched.

Shared-macOS mirrors Shared-iOS: the same file-system-synchronized groups, the
same per-group membership exceptions (cloned for the new target), the same
explicit top-level sources, the same Swift package products (each target needs
its own XCSwiftPackageProductDependency object), minus the iOS-only system
frameworks and the MacBridge plugin. App-macOS owns Sources/App/macOS and
depends on, links and embeds Shared-macOS.

Idempotent: refuses to run if either target already exists.
"""
import re
import sys

PBX = "HomeAssistant.xcodeproj/project.pbxproj"

SHARED_IOS_TARGET = "D03D891620E0A85200D4F28D"
SHARED_IOS_SOURCES = "D03D891220E0A85200D4F28D"
SHARED_IOS_FRAMEWORKS = "D03D891320E0A85200D4F28D"
SHARED_H_FILEREF = "D03D891920E0A85300D4F28D"
CODEGEN_TARGET = "111711E425B29ACB003C149E"
PROJECT_OBJECT = "B657A8DE1CA646EB00121384"
PROJECT_CONFIG_LIST = "B657A8E11CA646EB00121384"
PRODUCTS_GROUP = "B657A8E71CA646EB00121384"
LAUNCHER_TARGET = "11DE9D8225B6103C0081C0ED"
APP_GROUP_ANCHOR = "\t\t\t\t42EDE940300315A50051FC9B /* AppDelegate.swift */,\n"
IOS_ONLY_FRAMEWORKS = {"MatterSupport.framework", "CoreMediaIO.framework", "MacBridge.bundle"}

APP = {
    "group": "FAB000000000000000000006",
    "exceptions": "FAB000000000000000000012",
    "product": "FAB000000000000000000005",
    "ph_sources": "FAB00000000000000000000A",
    "ph_frameworks": "FAB00000000000000000000B",
    "ph_resources": "FAB00000000000000000000C",
    "ph_embed": "FAB500000000000000000005",
    "bf_link": "FAB500000000000000000001",
    "bf_embed": "FAB500000000000000000002",
    "proxy": "FAB500000000000000000003",
    "dep": "FAB500000000000000000004",
    "target": "FAB00000000000000000000D",
    "cfg_list": "FAB00000000000000000000E",
}
SHARED = {
    "target": "FAB20000000000000000017E",
    "cfg_list": "FAB20000000000000000017F",
    "product": "FAB200000000000000000183",
    "ph_sources": "FAB20000000000000000017A",
    "ph_frameworks": "FAB20000000000000000017B",
    "ph_headers": "FAB20000000000000000017C",
    "ph_resources": "FAB20000000000000000017D",
    "proxy": "FAB200000000000000000184",
    "dep": "FAB200000000000000000185",
}

with open(PBX) as f:
    text = f.read()

if "App-macOS" in text or "Shared-macOS" in text:
    print("macOS targets already present; aborting")
    sys.exit(1)
assert not re.search(r"\bFAB[0-9A-F]{21}\b", text), "FAB UUID prefix already in use"

counter = 0


def uuid() -> str:
    global counter
    counter += 1
    return f"FAB3{counter:020X}"


def insert_before(marker: str, payload: str) -> None:
    global text
    assert text.count(marker) == 1, f"marker not unique: {marker}"
    text = text.replace(marker, payload + marker, 1)


def insert_after(marker: str, payload: str) -> None:
    global text
    assert text.count(marker) == 1, f"marker not unique: {marker}"
    text = text.replace(marker, marker + payload, 1)


def block(uuid_: str) -> str:
    m = re.search(rf"^\t\t{uuid_} /\* [^\n]*? \*/ = \{{\n.*?^\t\t\}};\n", text, re.S | re.M)
    assert m, f"object not found: {uuid_}"
    return m.group(0)


def list_entries(body: str, key: str) -> list[tuple[str, str]]:
    m = re.search(rf"{key} = \((.*?)\);", body, re.S)
    assert m, f"list not found: {key}"
    return re.findall(r"([A-F0-9]{24}) /\* (.+?) \*/", m.group(1))


def config_names() -> list[str]:
    return [name for _, name in list_entries(block(PROJECT_CONFIG_LIST), "buildConfigurations")]


ios_target = block(SHARED_IOS_TARGET)
synced_groups = list_entries(ios_target, "fileSystemSynchronizedGroups")
product_deps = list_entries(ios_target, "packageProductDependencies")

# ---- Shared-macOS: build files ---------------------------------------------
buildfiles = []
sources = []
for bf, name in list_entries(block(SHARED_IOS_SOURCES), "files"):
    m = re.search(rf"^\t\t{bf} /\* .*? \*/ = \{{isa = PBXBuildFile; fileRef = ([A-F0-9]{{24}}) /\* (.+?) \*/", text, re.M)
    assert m, f"build file not found: {bf}"
    new = uuid()
    buildfiles.append(f"\t\t{new} /* {m.group(2)} in Sources */ = {{isa = PBXBuildFile; fileRef = {m.group(1)} /* {m.group(2)} */; }};\n")
    sources.append(f"\t\t\t\t{new} /* {m.group(2)} in Sources */,\n")

bf_header = uuid()
buildfiles.append(f"\t\t{bf_header} /* Shared.h in Headers */ = {{isa = PBXBuildFile; fileRef = {SHARED_H_FILEREF} /* Shared.h */; settings = {{ATTRIBUTES = (Public, ); }}; }};\n")

new_product_deps = []
product_dep_objects = []
frameworks = []
for dep, name in product_deps:
    body = block(dep)
    pkg = re.search(r"package = ([A-F0-9]{24} /\* [^\n]*? \*/);", body)
    new_dep = uuid()
    new_bf = uuid()
    product_dep_objects.append(
        f"\t\t{new_dep} /* {name} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        + (f"\t\t\tpackage = {pkg.group(1)};\n" if pkg else "")
        + f"\t\t\tproductName = {name};\n"
        f"\t\t}};\n"
    )
    buildfiles.append(f"\t\t{new_bf} /* {name} in Frameworks */ = {{isa = PBXBuildFile; productRef = {new_dep} /* {name} */; }};\n")
    frameworks.append(f"\t\t\t\t{new_bf} /* {name} in Frameworks */,\n")
    new_product_deps.append(f"\t\t\t\t{new_dep} /* {name} */,\n")

for bf, name in list_entries(block(SHARED_IOS_FRAMEWORKS), "files"):
    m = re.search(rf"^\t\t{bf} /\* .*? \*/ = \{{isa = PBXBuildFile; fileRef = ([A-F0-9]{{24}}) /\* (.+?) \*/", text, re.M)
    if not m or m.group(2) in IOS_ONLY_FRAMEWORKS:
        continue
    new = uuid()
    buildfiles.append(f"\t\t{new} /* {m.group(2)} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {m.group(1)} /* {m.group(2)} */; }};\n")
    frameworks.append(f"\t\t\t\t{new} /* {m.group(2)} in Frameworks */,\n")

buildfiles.append(
    f"\t\t{APP['bf_link']} /* Shared.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {SHARED['product']} /* Shared.framework */; }};\n"
    f"\t\t{APP['bf_embed']} /* Shared.framework in Embed Frameworks */ = {{isa = PBXBuildFile; fileRef = {SHARED['product']} /* Shared.framework */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n"
)
insert_before("/* End PBXBuildFile section */", "".join(buildfiles))

# ---- Shared-macOS: clone every membership exception set of Shared-iOS --------
exception_sets = []
for m in re.finditer(
    r"^\t\t([A-F0-9]{24}) /\* PBXFileSystemSynchronizedBuildFileExceptionSet \*/ = \{\n(.*?)^\t\t\};\n",
    text,
    re.S | re.M,
):
    old, body = m.group(1), m.group(2)
    if f"target = {SHARED_IOS_TARGET} " not in body:
        continue
    new = uuid()
    new_body = body.replace(
        f"target = {SHARED_IOS_TARGET} /* Shared-iOS */;",
        f"target = {SHARED['target']} /* Shared-macOS */;",
    )
    assert new_body != body
    exception_sets.append(f"\t\t{new} /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {{\n{new_body}\t\t}};\n")
    old_ref = f"{old} /* PBXFileSystemSynchronizedBuildFileExceptionSet */, "
    assert text.count(old_ref) == 1, f"exception set not referenced exactly once: {old}"
    text = text.replace(old_ref, old_ref + f"{new} /* PBXFileSystemSynchronizedBuildFileExceptionSet */, ", 1)

exception_sets.append(
    f"\t\t{APP['exceptions']} /* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {{\n"
    f"\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n"
    f"\t\t\tmembershipExceptions = (\n"
    f"\t\t\t\tInfo.plist,\n"
    f"\t\t\t);\n"
    f"\t\t\ttarget = {APP['target']} /* App-macOS */;\n"
    f"\t\t}};\n"
)
insert_before("/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */", "".join(exception_sets))

# ---- App-macOS: synchronized group for Sources/App/macOS ----------------------
insert_before(
    "/* End PBXFileSystemSynchronizedRootGroup section */",
    f"\t\t{APP['group']} /* macOS */ = {{isa = PBXFileSystemSynchronizedRootGroup; exceptions = ({APP['exceptions']} /* PBXFileSystemSynchronizedBuildFileExceptionSet */, ); explicitFileTypes = {{}}; explicitFolders = (); path = macOS; sourceTree = \"<group>\"; }};\n",
)
insert_after(APP_GROUP_ANCHOR, f"\t\t\t\t{APP['group']} /* macOS */,\n")

# ---- products ---------------------------------------------------------------
insert_before(
    "/* End PBXFileReference section */",
    f"\t\t{APP['product']} /* Home Assistant.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"Home Assistant.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    f"\t\t{SHARED['product']} /* Shared.framework */ = {{isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Shared.framework; sourceTree = BUILT_PRODUCTS_DIR; }};\n",
)
insert_after(
    f"\t\t{PRODUCTS_GROUP} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n",
    f"\t\t\t\t{APP['product']} /* Home Assistant.app */,\n\t\t\t\t{SHARED['product']} /* Shared.framework */,\n",
)

# ---- build phases -----------------------------------------------------------
def phase(uuid_: str, isa: str, name: str, files: list[str], extra: str = "") -> str:
    return (
        f"\t\t{uuid_} /* {name} */ = {{\n"
        f"\t\t\tisa = {isa};\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"{extra}"
        f"\t\t\tfiles = (\n" + "".join(files) + "\t\t\t);\n"
        + (f"\t\t\tname = \"{name}\";\n" if " " in name else "")
        + "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )


insert_before(
    "/* End PBXSourcesBuildPhase section */",
    phase(SHARED["ph_sources"], "PBXSourcesBuildPhase", "Sources", sources)
    + phase(APP["ph_sources"], "PBXSourcesBuildPhase", "Sources", []),
)
insert_before(
    "/* End PBXFrameworksBuildPhase section */",
    phase(SHARED["ph_frameworks"], "PBXFrameworksBuildPhase", "Frameworks", frameworks)
    + phase(APP["ph_frameworks"], "PBXFrameworksBuildPhase", "Frameworks", [f"\t\t\t\t{APP['bf_link']} /* Shared.framework in Frameworks */,\n"]),
)
insert_before(
    "/* End PBXHeadersBuildPhase section */",
    phase(SHARED["ph_headers"], "PBXHeadersBuildPhase", "Headers", [f"\t\t\t\t{bf_header} /* Shared.h in Headers */,\n"]),
)
insert_before(
    "/* End PBXResourcesBuildPhase section */",
    phase(SHARED["ph_resources"], "PBXResourcesBuildPhase", "Resources", [])
    + phase(APP["ph_resources"], "PBXResourcesBuildPhase", "Resources", []),
)
insert_before(
    "/* End PBXCopyFilesBuildPhase section */",
    phase(
        APP["ph_embed"],
        "PBXCopyFilesBuildPhase",
        "Embed Frameworks",
        [f"\t\t\t\t{APP['bf_embed']} /* Shared.framework in Embed Frameworks */,\n"],
        extra="\t\t\tdstPath = \"\";\n\t\t\tdstSubfolderSpec = 10;\n",
    ),
)

# ---- target dependencies ----------------------------------------------------
def proxy(uuid_: str, remote: str, info: str) -> str:
    return (
        f"\t\t{uuid_} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {PROJECT_OBJECT} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {remote};\n"
        f"\t\t\tremoteInfo = {info};\n"
        f"\t\t}};\n"
    )


def dependency(uuid_: str, target: str, name: str, proxy_: str) -> str:
    return (
        f"\t\t{uuid_} /* PBXTargetDependency */ = {{\n"
        f"\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {target} /* {name} */;\n"
        f"\t\t\ttargetProxy = {proxy_} /* PBXContainerItemProxy */;\n"
        f"\t\t}};\n"
    )


insert_before(
    "/* End PBXContainerItemProxy section */",
    proxy(SHARED["proxy"], CODEGEN_TARGET, "Codegen") + proxy(APP["proxy"], SHARED["target"], "\"Shared-macOS\""),
)
insert_before(
    "/* End PBXTargetDependency section */",
    dependency(SHARED["dep"], CODEGEN_TARGET, "Codegen", SHARED["proxy"])
    + dependency(APP["dep"], SHARED["target"], "Shared-macOS", APP["proxy"]),
)

# ---- native targets ---------------------------------------------------------
insert_before(
    "/* End PBXNativeTarget section */",
    f"\t\t{SHARED['target']} /* Shared-macOS */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {SHARED['cfg_list']} /* Build configuration list for PBXNativeTarget \"Shared-macOS\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{SHARED['ph_sources']} /* Sources */,\n"
    f"\t\t\t\t{SHARED['ph_frameworks']} /* Frameworks */,\n"
    f"\t\t\t\t{SHARED['ph_headers']} /* Headers */,\n"
    f"\t\t\t\t{SHARED['ph_resources']} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t\t{SHARED['dep']} /* PBXTargetDependency */,\n"
    f"\t\t\t);\n"
    f"\t\t\tfileSystemSynchronizedGroups = (\n"
    + "".join(f"\t\t\t\t{u} /* {n} */,\n" for u, n in synced_groups)
    + f"\t\t\t);\n"
    f"\t\t\tname = \"Shared-macOS\";\n"
    f"\t\t\tpackageProductDependencies = (\n"
    + "".join(new_product_deps)
    + f"\t\t\t);\n"
    f"\t\t\tproductName = Shared;\n"
    f"\t\t\tproductReference = {SHARED['product']} /* Shared.framework */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.framework\";\n"
    f"\t\t}};\n"
    f"\t\t{APP['target']} /* App-macOS */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {APP['cfg_list']} /* Build configuration list for PBXNativeTarget \"App-macOS\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{APP['ph_sources']} /* Sources */,\n"
    f"\t\t\t\t{APP['ph_frameworks']} /* Frameworks */,\n"
    f"\t\t\t\t{APP['ph_resources']} /* Resources */,\n"
    f"\t\t\t\t{APP['ph_embed']} /* Embed Frameworks */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t\t{APP['dep']} /* PBXTargetDependency */,\n"
    f"\t\t\t);\n"
    f"\t\t\tfileSystemSynchronizedGroups = (\n"
    f"\t\t\t\t{APP['group']} /* macOS */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"App-macOS\";\n"
    f"\t\t\tproductName = \"App-macOS\";\n"
    f"\t\t\tproductReference = {APP['product']} /* Home Assistant.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};\n",
)

# ---- build configurations ---------------------------------------------------
SHARED_SETTINGS = (
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = NO;\n"
    "\t\t\t\tDEFINES_MODULE = YES;\n"
    "\t\t\t\tDYLIB_COMPATIBILITY_VERSION = 1;\n"
    "\t\t\t\tDYLIB_CURRENT_VERSION = 2;\n"
    "\t\t\t\tDYLIB_INSTALL_NAME_BASE = \"@rpath\";\n"
    "\t\t\t\tINFOPLIST_FILE = Sources/Shared/Resources/Info.plist;\n"
    "\t\t\t\tINSTALL_PATH = \"$(LOCAL_LIBRARY_DIR)/Frameworks\";\n"
    "\t\t\t\tINTENTS_CODEGEN_LANGUAGE = Swift;\n"
    "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
    "\t\t\t\t\t\"$(inherited)\",\n"
    "\t\t\t\t\t\"@executable_path/../Frameworks\",\n"
    "\t\t\t\t\t\"@loader_path/Frameworks\",\n"
    "\t\t\t\t);\n"
    "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;\n"
    "\t\t\t\tPRODUCT_MODULE_NAME = Shared;\n"
    "\t\t\t\tPRODUCT_NAME = Shared;\n"
    "\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = \"\";\n"
    "\t\t\t\tPROVISIONING_SUFFIX = .Shared;\n"
    "\t\t\t\tSDKROOT = macosx;\n"
    "\t\t\t\tSKIP_INSTALL = YES;\n"
    "\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n"
    "\t\t\t};\n"
)
APP_SETTINGS = (
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tCODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;\n"
    "\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;\n"
    "\t\t\t\tENABLE_HARDENED_RUNTIME = YES;\n"
    "\t\t\t\tINFOPLIST_FILE = Sources/App/macOS/Info.plist;\n"
    "\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
    "\t\t\t\t\t\"$(inherited)\",\n"
    "\t\t\t\t\t\"@executable_path/../Frameworks\",\n"
    "\t\t\t\t);\n"
    "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;\n"
    "\t\t\t\tPRODUCT_NAME = \"Home Assistant\";\n"
    "\t\t\t\tPROVISIONING_SUFFIX = .Mac;\n"
    "\t\t\t\tSDKROOT = macosx;\n"
    "\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n"
    "\t\t\t};\n"
)
configs = ""
lists = ""
for prefix, settings, name in ((SHARED, SHARED_SETTINGS, "Shared-macOS"), (APP, APP_SETTINGS, "App-macOS")):
    entries = ""
    for cfg in config_names():
        u = uuid()
        configs += f"\t\t{u} /* {cfg} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n{settings}\t\t\tname = {cfg};\n\t\t}};\n"
        entries += f"\t\t\t\t{u} /* {cfg} */,\n"
    lists += (
        f"\t\t{prefix['cfg_list']} /* Build configuration list for PBXNativeTarget \"{name}\" */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n{entries}\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )
insert_before("/* End XCBuildConfiguration section */", configs)
insert_before("/* End XCConfigurationList section */", lists)
insert_before("/* End XCSwiftPackageProductDependency section */", "".join(product_dep_objects))

# ---- register targets -------------------------------------------------------
insert_after(
    f"\t\t\t\t{LAUNCHER_TARGET} /* Launcher */,\n",
    f"\t\t\t\t{SHARED['target']} /* Shared-macOS */,\n\t\t\t\t{APP['target']} /* App-macOS */,\n",
)

with open(PBX, "w") as f:
    f.write(text)
print(f"added Shared-macOS ({len(sources)} explicit sources, {len(synced_groups)} synced groups, "
      f"{len(new_product_deps)} package products, {len(exception_sets) - 1} cloned exception sets) and App-macOS")
