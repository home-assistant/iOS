#!/usr/bin/env python3
"""Add the Shared-macOS framework target to HomeAssistant.xcodeproj.

Additive-only pbxproj surgery. Clones Shared-iOS's exact source/resource/header
file lists (same PBXFileReferences, new PBXBuildFiles) so the macOS framework
compiles the identical file set, swaps the CocoaPods dependency graph for SPM
package products (verified macOS-capable), and adds SiriKit intent codegen.

Idempotent: refuses to run if the target already exists.
"""
import re
import sys

PBX = "HomeAssistant.xcodeproj/project.pbxproj"
SHARED_IOS_SOURCES = "D03D891220E0A85200D4F28D"
SHARED_IOS_RESOURCES = "D03D891520E0A85200D4F28D"
INTENTS_FILEREF = "B63CCDCF2164714900123C50"
SHARED_H_FILEREF_COMMENT = "Shared.h"
EXISTING_PKG_SHAREDPUSH = "42E00D0F2E1E7487006D140D"
EXISTING_PKG_ZIPFOUNDATION = "4237E6372E5333370023B673"

with open(PBX) as f:
    text = f.read()

if "Shared-macOS" in text:
    print("Shared-macOS already present; aborting")
    sys.exit(1)
for prefix in ("FAB2", "FAB3"):
    assert not re.search(rf"\b{prefix}[0-9A-F]{{20}}\b", text), f"prefix in use: {prefix}"

counter = 0


def uuid() -> str:
    global counter
    counter += 1
    return f"FAB2{counter:020X}"


def phase_files(phase_uuid: str) -> list[tuple[str, str]]:
    """Return [(buildfile_uuid, name)] for a build phase's files list."""
    m = re.search(
        rf"\t\t{phase_uuid} /\* [^*]+ \*/ = \{{.*?files = \((.*?)\);",
        text,
        re.S,
    )
    assert m, f"phase not found: {phase_uuid}"
    entries = re.findall(r"([A-F0-9]{24}) /\* (.+?) \*/", m.group(1))
    return entries


def fileref_for_buildfile(bf_uuid: str) -> tuple[str, str]:
    """Return (fileref_uuid, comment) for a PBXBuildFile."""
    m = re.search(
        rf"\t\t{bf_uuid} /\* .*? \*/ = \{{isa = PBXBuildFile; fileRef = ([A-F0-9]{{24}}) /\* (.+?) \*/",
        text,
    )
    assert m, f"buildfile not found: {bf_uuid}"
    return m.group(1), m.group(2)


# ---- collect Shared-iOS file lists -----------------------------------------
src_entries = phase_files(SHARED_IOS_SOURCES)
res_entries = phase_files(SHARED_IOS_RESOURCES)
src_refs = []
seen = set()
for bf, _name in src_entries:
    ref, comment = fileref_for_buildfile(bf)
    if ref not in seen:  # dedupe (defensive)
        seen.add(ref)
        src_refs.append((ref, comment))
res_refs = []
seen_r = set()
for bf, _name in res_entries:
    ref, comment = fileref_for_buildfile(bf)
    if ref not in seen_r:
        seen_r.add(ref)
        res_refs.append((ref, comment))
print(f"Shared-iOS: {len(src_refs)} sources, {len(res_refs)} resources")

# Shared.h fileref
m = re.search(r"([A-F0-9]{24}) /\* Shared\.h \*/ = \{isa = PBXFileReference", text)
assert m, "Shared.h fileref not found"
shared_h_ref = m.group(1)

# ---- new build files ---------------------------------------------------------
new_buildfiles = []  # lines
src_bf_lines = []  # (bf_uuid, comment) for sources phase listing
for ref, comment in src_refs:
    bf = uuid()
    new_buildfiles.append(
        f"\t\t{bf} /* {comment} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {comment} */; }};\n"
    )
    src_bf_lines.append((bf, comment))

# intent definition with public codegen
bf_intents = uuid()
new_buildfiles.append(
    f"\t\t{bf_intents} /* Intents.intentdefinition in Sources */ = {{isa = PBXBuildFile; fileRef = {INTENTS_FILEREF} /* Intents.intentdefinition */; settings = {{ATTRIBUTES = (codegen, ); }}; }};\n"
)
src_bf_lines.append((bf_intents, "Intents.intentdefinition"))

# CrossPlatformUI shim (mac-only file; new fileref anchored at SOURCE_ROOT)
ref_shim = uuid()
bf_shim = uuid()
new_buildfiles.append(
    f"\t\t{bf_shim} /* CrossPlatformUI.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_shim} /* CrossPlatformUI.swift */; }};\n"
)
src_bf_lines.append((bf_shim, "CrossPlatformUI.swift"))

res_bf_lines = []
for ref, comment in res_refs:
    bf = uuid()
    new_buildfiles.append(
        f"\t\t{bf} /* {comment} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {comment} */; }};\n"
    )
    res_bf_lines.append((bf, comment))

bf_header = uuid()
new_buildfiles.append(
    f"\t\t{bf_header} /* Shared.h in Headers */ = {{isa = PBXBuildFile; fileRef = {shared_h_ref} /* Shared.h */; settings = {{ATTRIBUTES = (Public, ); }}; }};\n"
)

# ---- SPM packages ------------------------------------------------------------
PKGS = [
    # key, repo, requirement-body, product
    ("Alamofire", "https://github.com/Alamofire/Alamofire.git",
     "kind = exactVersion;\n\t\t\t\tversion = 5.8.1;", "Alamofire"),
    ("GRDB.swift", "https://github.com/groue/GRDB.swift.git",
     "kind = exactVersion;\n\t\t\t\tversion = 7.8.0;", "GRDB"),
    ("HAKit", "https://github.com/home-assistant/HAKit.git",
     "kind = exactVersion;\n\t\t\t\tversion = 0.4.14;", "HAKit"),
    ("Starscream", "https://github.com/bgoncal/Starscream",
     "kind = revision;\n\t\t\t\trevision = aaaf609d07eb487b2fccbe77f6267cf0843e2b19;", "Starscream"),
    ("KeychainAccess", "https://github.com/kishikawakatsumi/KeychainAccess.git",
     "kind = exactVersion;\n\t\t\t\tversion = 4.2.2;", "KeychainAccess"),
    ("ObjectMapper", "https://github.com/tristanhimmelman/ObjectMapper.git",
     "branch = master;\n\t\t\t\tkind = branch;", "ObjectMapper"),
    ("PromiseKit", "https://github.com/mxcl/PromiseKit.git",
     "kind = exactVersion;\n\t\t\t\tversion = 8.1.2;", "PromiseKit"),
    ("realm-swift", "https://github.com/realm/realm-swift.git",
     "kind = exactVersion;\n\t\t\t\tversion = 10.35.0;", "RealmSwift"),
    ("Reachability.swift", "https://github.com/ashleymills/Reachability.swift.git",
     "kind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 5.0.0;", "Reachability"),
    ("SFSafeSymbols", "https://github.com/SFSafeSymbols/SFSafeSymbols.git",
     "kind = exactVersion;\n\t\t\t\tversion = 5.3.0;", "SFSafeSymbols"),
    ("swift-sodium", "https://github.com/zacwest/swift-sodium.git",
     "branch = \"xcode-14.0.1\";\n\t\t\t\tkind = branch;", "Sodium"),
    ("UIColor-Hex-Swift", "https://github.com/yeahdongcn/UIColor-Hex-Swift.git",
     "kind = exactVersion;\n\t\t\t\tversion = 5.1.9;", "UIColorHexSwift"),
    ("Version", "https://github.com/mrackwitz/Version.git",
     "kind = exactVersion;\n\t\t\t\tversion = 0.8.0;", "Version"),
    ("XCGLogger", "https://github.com/DaveWoodCom/XCGLogger.git",
     "kind = exactVersion;\n\t\t\t\tversion = 7.0.1;", "XCGLogger"),
]

pkg_ref_section = ""
pkg_ref_list_lines = ""
prod_dep_section = ""
fw_buildfile_lines = ""
prod_dep_list_lines = ""

for key, repo, req, product in PKGS:
    pref = uuid()
    pdep = uuid()
    pbf = uuid()
    pkg_ref_section += (
        f"\t\t{pref} /* XCRemoteSwiftPackageReference \"{key}\" */ = {{\n"
        f"\t\t\tisa = XCRemoteSwiftPackageReference;\n"
        f"\t\t\trepositoryURL = \"{repo}\";\n"
        f"\t\t\trequirement = {{\n"
        f"\t\t\t\t{req}\n"
        f"\t\t\t}};\n"
        f"\t\t}};\n"
    )
    pkg_ref_list_lines += f"\t\t\t\t{pref} /* XCRemoteSwiftPackageReference \"{key}\" */,\n"
    prod_dep_section += (
        f"\t\t{pdep} /* {product} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {pref} /* XCRemoteSwiftPackageReference \"{key}\" */;\n"
        f"\t\t\tproductName = {product};\n"
        f"\t\t}};\n"
    )
    fw_bf = uuid()
    fw_buildfile_lines += (
        f"\t\t{fw_bf} /* {product} in Frameworks */ = {{isa = PBXBuildFile; productRef = {pdep} /* {product} */; }};\n"
    )
    prod_dep_list_lines += f"\t\t\t\t{pdep} /* {product} */,\n"
    new_buildfiles.append("")  # placeholder no-op to keep structure obvious

# existing packages: SharedPush (local) + ZIPFoundation — new product deps for this target
for pkg_uuid, pkg_comment, product in (
    (EXISTING_PKG_SHAREDPUSH, 'XCLocalSwiftPackageReference "SharedPush"', "SharedPush"),
    (EXISTING_PKG_ZIPFOUNDATION, 'XCRemoteSwiftPackageReference "ZIPFoundation"', "ZIPFoundation"),
):
    pdep = uuid()
    prod_dep_section += (
        f"\t\t{pdep} /* {product} */ = {{\n"
        f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {pkg_uuid} /* {pkg_comment} */;\n"
        f"\t\t\tproductName = {product};\n"
        f"\t\t}};\n"
    )
    fw_bf = uuid()
    fw_buildfile_lines += (
        f"\t\t{fw_bf} /* {product} in Frameworks */ = {{isa = PBXBuildFile; productRef = {pdep} /* {product} */; }};\n"
    )
    prod_dep_list_lines += f"\t\t\t\t{pdep} /* {product} */,\n"

# ---- phases, target, configs -------------------------------------------------
ph_sources = uuid()
ph_frameworks = uuid()
ph_headers = uuid()
ph_resources = uuid()
target = uuid()
cfg_list = uuid()
cfg_debug = uuid()
cfg_release = uuid()
cfg_beta = uuid()
ref_product = uuid()


def insert_before(marker: str, payload: str) -> None:
    global text
    assert marker in text, f"marker not found: {marker}"
    text = text.replace(marker, payload + marker, 1)


# build files
insert_before("/* End PBXBuildFile section */", "".join(new_buildfiles) + fw_buildfile_lines)

# file references (shim + product)
insert_before(
    "/* End PBXFileReference section */",
    f"\t\t{ref_shim} /* CrossPlatformUI.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = CrossPlatformUI.swift; path = Sources/Shared/Common/CrossPlatform/CrossPlatformUI.swift; sourceTree = SOURCE_ROOT; }};\n"
    f"\t\t{ref_product} /* Shared.framework */ = {{isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Shared.framework; sourceTree = BUILT_PRODUCTS_DIR; }};\n",
)

# attach shim fileref to the Shared group for navigator visibility
m = re.search(r"([A-F0-9]{24}) /\* Shared \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n", text)
assert m, "Shared group not found"
text = text.replace(m.group(0), m.group(0) + f"\t\t\t\t{ref_shim} /* CrossPlatformUI.swift */,\n", 1)

# products group
products_anchor = "\t\tB657A8E71CA646EB00121384 /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
text = text.replace(products_anchor, products_anchor + f"\t\t\t\t{ref_product} /* Shared.framework */,\n", 1)

# phases
src_lines = "".join(f"\t\t\t\t{bf} /* {c} in Sources */,\n" for bf, c in src_bf_lines)
res_lines = "".join(f"\t\t\t\t{bf} /* {c} in Resources */,\n" for bf, c in res_bf_lines)
fw_lines = ""
for line in fw_buildfile_lines.strip().split("\n"):
    bf = line.strip().split(" ")[0]
    cm = re.search(r"/\* (.+?) in Frameworks \*/", line).group(1)
    fw_lines += f"\t\t\t\t{bf} /* {cm} in Frameworks */,\n"

insert_before(
    "/* End PBXSourcesBuildPhase section */",
    f"\t\t{ph_sources} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{src_lines}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)
insert_before(
    "/* End PBXFrameworksBuildPhase section */",
    f"\t\t{ph_frameworks} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{fw_lines}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)
insert_before(
    "/* End PBXHeadersBuildPhase section */",
    f"\t\t{ph_headers} /* Headers */ = {{\n\t\t\tisa = PBXHeadersBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{bf_header} /* Shared.h in Headers */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)
insert_before(
    "/* End PBXResourcesBuildPhase section */",
    f"\t\t{ph_resources} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{res_lines}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)

# target
insert_before(
    "/* End PBXNativeTarget section */",
    f"\t\t{target} /* Shared-macOS */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget \"Shared-macOS\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{ph_sources} /* Sources */,\n"
    f"\t\t\t\t{ph_frameworks} /* Frameworks */,\n"
    f"\t\t\t\t{ph_headers} /* Headers */,\n"
    f"\t\t\t\t{ph_resources} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t);\n"
    f"\t\t\tname = \"Shared-macOS\";\n"
    f"\t\t\tpackageProductDependencies = (\n{prod_dep_list_lines}\t\t\t);\n"
    f"\t\t\tproductName = Shared;\n"
    f"\t\t\tproductReference = {ref_product} /* Shared.framework */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.framework\";\n"
    f"\t\t}};\n",
)

# configs
SETTINGS = (
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
configs = ""
for cu, name in ((cfg_debug, "Debug"), (cfg_release, "Release"), (cfg_beta, "Beta")):
    configs += (
        f"\t\t{cu} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n{SETTINGS}\t\t\tname = {name};\n\t\t}};\n"
    )
insert_before("/* End XCBuildConfiguration section */", configs)
insert_before(
    "/* End XCConfigurationList section */",
    f"\t\t{cfg_list} /* Build configuration list for PBXNativeTarget \"Shared-macOS\" */ = {{\n"
    f"\t\t\tisa = XCConfigurationList;\n"
    f"\t\t\tbuildConfigurations = (\n"
    f"\t\t\t\t{cfg_debug} /* Debug */,\n"
    f"\t\t\t\t{cfg_release} /* Release */,\n"
    f"\t\t\t\t{cfg_beta} /* Beta */,\n"
    f"\t\t\t);\n"
    f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
    f"\t\t\tdefaultConfigurationName = Release;\n"
    f"\t\t}};\n",
)

# package reference + product dependency sections
insert_before("/* End XCRemoteSwiftPackageReference section */", pkg_ref_section)
insert_before("/* End XCSwiftPackageProductDependency section */", prod_dep_section)

# project packageReferences list (append after firebase entry which is unique)
fw_anchor = "\t\t\t\t42F384032FB49C9500390AFC /* XCRemoteSwiftPackageReference \"DebugSwift\" */,\n"
assert fw_anchor in text
text = text.replace(fw_anchor, fw_anchor + pkg_ref_list_lines, 1)

# project targets list (after App-macOS)
targets_anchor = "\t\t\t\tFAB00000000000000000000D /* App-macOS */,\n"
assert targets_anchor in text
text = text.replace(targets_anchor, targets_anchor + f"\t\t\t\t{target} /* Shared-macOS */,\n", 1)

with open(PBX, "w") as f:
    f.write(text)
print(f"Shared-macOS target added: {len(src_bf_lines)} sources, {len(res_bf_lines)} resources, {len(PKGS) + 2} package products")
print(f"target uuid: {target}")
