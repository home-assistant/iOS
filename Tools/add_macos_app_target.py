#!/usr/bin/env python3
"""Add the native macOS app target (App-macOS) to HomeAssistant.xcodeproj.

Additive-only pbxproj surgery: no existing entry is modified, so every iOS /
watchOS / catalyst target is untouched. Mirrors the conventions of the existing
native-macOS `Launcher` target (minimal per-target settings inheriting the
project xcconfigs, PROVISIONING_SUFFIX-based bundle id).

Idempotent: refuses to run if the target already exists.
"""
import re
import sys

PBX = "HomeAssistant.xcodeproj/project.pbxproj"

U = {
    "ref_entry": "FAB000000000000000000001",
    "ref_host": "FAB000000000000000000002",
    "ref_root": "FAB000000000000000000003",
    "ref_plist": "FAB000000000000000000004",
    "ref_product": "FAB000000000000000000005",
    "grp_macos": "FAB000000000000000000006",
    "bf_entry": "FAB000000000000000000007",
    "bf_host": "FAB000000000000000000008",
    "bf_root": "FAB000000000000000000009",
    "ph_sources": "FAB00000000000000000000A",
    "ph_frameworks": "FAB00000000000000000000B",
    "ph_resources": "FAB00000000000000000000C",
    "target": "FAB00000000000000000000D",
    "cfg_list": "FAB00000000000000000000E",
    "cfg_debug": "FAB00000000000000000000F",
    "cfg_release": "FAB000000000000000000010",
    "cfg_beta": "FAB000000000000000000011",
}

with open(PBX) as f:
    text = f.read()

if "App-macOS" in text:
    print("App-macOS already present; aborting")
    sys.exit(1)
for uuid in U.values():
    assert uuid not in text, f"UUID collision: {uuid}"


def insert_before(marker: str, payload: str) -> None:
    global text
    assert marker in text, f"marker not found: {marker}"
    text = text.replace(marker, payload + marker, 1)


# 1. PBXBuildFile entries
insert_before(
    "/* End PBXBuildFile section */",
    f"\t\t{U['bf_entry']} /* MacAppEntry.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {U['ref_entry']} /* MacAppEntry.swift */; }};\n"
    f"\t\t{U['bf_host']} /* MacWebViewHost.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {U['ref_host']} /* MacWebViewHost.swift */; }};\n"
    f"\t\t{U['bf_root']} /* MacRootView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {U['ref_root']} /* MacRootView.swift */; }};\n",
)

# 2. PBXFileReference entries
insert_before(
    "/* End PBXFileReference section */",
    f"\t\t{U['ref_entry']} /* MacAppEntry.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MacAppEntry.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{U['ref_host']} /* MacWebViewHost.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MacWebViewHost.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{U['ref_root']} /* MacRootView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MacRootView.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{U['ref_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
    f"\t\t{U['ref_product']} /* Home Assistant.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"Home Assistant.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};\n",
)

# 3. macOS group + attach under the App group (Sources/App)
insert_before(
    "/* End PBXGroup section */",
    f"\t\t{U['grp_macos']} /* macOS */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
    f"\t\t\t\t{U['ref_entry']} /* MacAppEntry.swift */,\n"
    f"\t\t\t\t{U['ref_host']} /* MacWebViewHost.swift */,\n"
    f"\t\t\t\t{U['ref_root']} /* MacRootView.swift */,\n"
    f"\t\t\t\t{U['ref_plist']} /* Info.plist */,\n"
    f"\t\t\t);\n"
    f"\t\t\tpath = macOS;\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};\n",
)
# attach: the App group's children include the unique Resources child line
app_group_anchor = "\t\t\t\tB69933961E232AF50054453D /* Resources */,\n"
assert text.count(app_group_anchor) == 1, "App group anchor not unique"
text = text.replace(
    app_group_anchor,
    app_group_anchor + f"\t\t\t\t{U['grp_macos']} /* macOS */,\n",
    1,
)

# 4. Products group: add product reference
products_anchor = "\t\tB657A8E71CA646EB00121384 /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
assert products_anchor in text, "Products group anchor not found"
text = text.replace(
    products_anchor,
    products_anchor + f"\t\t\t\t{U['ref_product']} /* Home Assistant.app */,\n",
    1,
)

# 5. Build phases
insert_before(
    "/* End PBXSourcesBuildPhase section */",
    f"\t\t{U['ph_sources']} /* Sources */ = {{\n"
    f"\t\t\tisa = PBXSourcesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{U['bf_entry']} /* MacAppEntry.swift in Sources */,\n"
    f"\t\t\t\t{U['bf_host']} /* MacWebViewHost.swift in Sources */,\n"
    f"\t\t\t\t{U['bf_root']} /* MacRootView.swift in Sources */,\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)
insert_before(
    "/* End PBXFrameworksBuildPhase section */",
    f"\t\t{U['ph_frameworks']} /* Frameworks */ = {{\n"
    f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)
insert_before(
    "/* End PBXResourcesBuildPhase section */",
    f"\t\t{U['ph_resources']} /* Resources */ = {{\n"
    f"\t\t\tisa = PBXResourcesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# 6. Native target
insert_before(
    "/* End PBXNativeTarget section */",
    f"\t\t{U['target']} /* App-macOS */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {U['cfg_list']} /* Build configuration list for PBXNativeTarget \"App-macOS\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{U['ph_sources']} /* Sources */,\n"
    f"\t\t\t\t{U['ph_frameworks']} /* Frameworks */,\n"
    f"\t\t\t\t{U['ph_resources']} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"App-macOS\";\n"
    f"\t\t\tproductName = \"App-macOS\";\n"
    f"\t\t\tproductReference = {U['ref_product']} /* Home Assistant.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};\n",
)

# 7. Build configurations + list
SETTINGS = (
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
for key, name in (("cfg_debug", "Debug"), ("cfg_release", "Release"), ("cfg_beta", "Beta")):
    configs += (
        f"\t\t{U[key]} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"{SETTINGS}"
        f"\t\t\tname = {name};\n"
        f"\t\t}};\n"
    )
insert_before("/* End XCBuildConfiguration section */", configs)

insert_before(
    "/* End XCConfigurationList section */",
    f"\t\t{U['cfg_list']} /* Build configuration list for PBXNativeTarget \"App-macOS\" */ = {{\n"
    f"\t\t\tisa = XCConfigurationList;\n"
    f"\t\t\tbuildConfigurations = (\n"
    f"\t\t\t\t{U['cfg_debug']} /* Debug */,\n"
    f"\t\t\t\t{U['cfg_release']} /* Release */,\n"
    f"\t\t\t\t{U['cfg_beta']} /* Beta */,\n"
    f"\t\t\t);\n"
    f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
    f"\t\t\tdefaultConfigurationName = Release;\n"
    f"\t\t}};\n",
)

# 8. Register in PBXProject targets (after Launcher)
targets_anchor = "\t\t\t\t11DE9D8225B6103C0081C0ED /* Launcher */,\n"
assert text.count(targets_anchor) >= 1
text = text.replace(
    targets_anchor,
    targets_anchor + f"\t\t\t\t{U['target']} /* App-macOS */,\n",
    1,
)

with open(PBX, "w") as f:
    f.write(text)
print("App-macOS target added")
