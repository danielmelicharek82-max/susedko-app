path = "ios/Runner.xcodeproj/project.pbxproj"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if "sk," not in content:
    content = content.replace(
        "knownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,",
        "knownRegions = (\n\t\t\t\ten,\n\t\t\t\tsk,\n\t\t\t\tBase,"
    )
    print("knownRegions: sk pridane")
else:
    print("knownRegions: ok")

file_ref_sk = '\t\tAA000001000000000000001 /* sk */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = sk; path = sk.lproj/InfoPlist.strings; sourceTree = "<group>"; };\n'
file_ref_en = '\t\tAA000002000000000000002 /* en */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/InfoPlist.strings; sourceTree = "<group>"; };\n'
end_ref = "/* End PBXFileReference section */"
if "AA000001000000000000001" not in content:
    content = content.replace(end_ref, file_ref_sk + file_ref_en + "\t\t" + end_ref)
    print("PBXFileReference: pridane")
else:
    print("PBXFileReference: ok")

variant_group = "\t\tAA000003000000000000003 /* InfoPlist.strings */ = {\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = (\n\t\t\t\tAA000002000000000000002 /* en */,\n\t\t\t\tAA000001000000000000001 /* sk */,\n\t\t\t);\n\t\t\tname = InfoPlist.strings;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
end_variant = "/* End PBXVariantGroup section */"
if "AA000003000000000000003" not in content:
    content = content.replace(end_variant, variant_group + "\t\t" + end_variant)
    print("PBXVariantGroup: pridany")
else:
    print("PBXVariantGroup: ok")

build_file = '\t\tAA000004000000000000004 /* InfoPlist.strings in Resources */ = {isa = PBXBuildFile; fileRef = AA000003000000000000003 /* InfoPlist.strings */; };\n'
end_build = "/* End PBXBuildFile section */"
if "AA000004000000000000004" not in content:
    content = content.replace(end_build, build_file + "\t\t" + end_build)
    print("PBXBuildFile: pridany")
else:
    print("PBXBuildFile: ok")

assets = "\t\t\t\t97C146FD1CF9000F007C117D /* Assets.xcassets */,"
infoplist_res = "\t\t\t\tAA000004000000000000004 /* InfoPlist.strings in Resources */,"
if "AA000004000000000000004 /* InfoPlist.strings in Resources */" not in content:
    content = content.replace(assets, infoplist_res + "\n" + assets)
    print("Resources: pridany")
else:
    print("Resources: ok")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Patch hotovy")
