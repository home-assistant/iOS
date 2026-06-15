#!/usr/bin/env python3
"""Link Shared-macOS into App-macOS: target dependency + link + embed.

Additive-only pbxproj surgery. Run once Shared-macOS compiles.
"""
import sys

PBX = "HomeAssistant.xcodeproj/project.pbxproj"
APP_TARGET = "FAB00000000000000000000D"
APP_FRAMEWORKS_PHASE = "FAB00000000000000000000B"
SHARED_TARGET = "FAB20000000000000000017E"
SHARED_PRODUCT_REF = "FAB200000000000000000183"
PROJECT_OBJECT = "B657A8DE1CA646EB00121384"

U = {
    "bf_link": "FAB500000000000000000001",
    "bf_embed": "FAB500000000000000000002",
    "proxy": "FAB500000000000000000003",
    "dep": "FAB500000000000000000004",
    "ph_embed": "FAB500000000000000000005",
}

with open(PBX) as f:
    text = f.read()

if U["bf_link"] in text:
    print("already linked; aborting")
    sys.exit(1)


def insert_before(marker: str, payload: str) -> None:
    global text
    assert marker in text, f"marker not found: {marker}"
    text = text.replace(marker, payload + marker, 1)


insert_before(
    "/* End PBXBuildFile section */",
    f"\t\t{U['bf_link']} /* Shared.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {SHARED_PRODUCT_REF} /* Shared.framework */; }};\n"
    f"\t\t{U['bf_embed']} /* Shared.framework in Embed Frameworks */ = {{isa = PBXBuildFile; fileRef = {SHARED_PRODUCT_REF} /* Shared.framework */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n",
)

insert_before(
    "/* End PBXContainerItemProxy section */",
    f"\t\t{U['proxy']} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {PROJECT_OBJECT} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {SHARED_TARGET};\n"
    f"\t\t\tremoteInfo = \"Shared-macOS\";\n"
    f"\t\t}};\n",
)

insert_before(
    "/* End PBXTargetDependency section */",
    f"\t\t{U['dep']} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {SHARED_TARGET} /* Shared-macOS */;\n"
    f"\t\t\ttargetProxy = {U['proxy']} /* PBXContainerItemProxy */;\n"
    f"\t\t}};\n",
)

# embed phase
insert_before(
    "/* End PBXCopyFilesBuildPhase section */",
    f"\t\t{U['ph_embed']} /* Embed Frameworks */ = {{\n"
    f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tdstPath = \"\";\n"
    f"\t\t\tdstSubfolderSpec = 10;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{U['bf_embed']} /* Shared.framework in Embed Frameworks */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"Embed Frameworks\";\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# wire into App-macOS target: link buildfile into frameworks phase
fw_anchor = (
    f"\t\t{APP_FRAMEWORKS_PHASE} /* Frameworks */ = {{\n"
    f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
)
assert fw_anchor in text, "App-macOS frameworks phase not found"
text = text.replace(fw_anchor, fw_anchor + f"\t\t\t\t{U['bf_link']} /* Shared.framework in Frameworks */,\n", 1)

# add embed phase + dependency to target
tgt_phases_anchor = (
    f"\t\t{APP_TARGET} /* App-macOS */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = FAB00000000000000000000E /* Build configuration list for PBXNativeTarget \"App-macOS\" */;\n"
    f"\t\t\tbuildPhases = (\n"
)
assert tgt_phases_anchor in text, "App-macOS target anchor not found"
text = text.replace(
    tgt_phases_anchor + "\t\t\t\tFAB00000000000000000000A /* Sources */,\n",
    tgt_phases_anchor + "\t\t\t\tFAB00000000000000000000A /* Sources */,\n"
    + f"\t\t\t\t{U['ph_embed']} /* Embed Frameworks */,\n",
    1,
)
deps_anchor = "\t\t\tname = \"App-macOS\";"
text = text.replace(
    "\t\t\tdependencies = (\n\t\t\t);\n" + deps_anchor,
    f"\t\t\tdependencies = (\n\t\t\t\t{U['dep']} /* PBXTargetDependency */,\n\t\t\t);\n" + deps_anchor,
    1,
)

with open(PBX, "w") as f:
    f.write(text)
print("App-macOS now depends on, links, and embeds Shared-macOS")
