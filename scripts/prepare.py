from pathlib import Path
import plistlib
root = Path(__file__).resolve().parent.parent
info = {
 'CFBundleDevelopmentRegion':'zh_CN','CFBundleDisplayName':'绘序',
 'CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
 'CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)',
 'CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'2',
 'LSRequiresIPhoneOS':True,'UILaunchScreen':{},
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],
 'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},
}
(root/'Huixu'/'Info.plist').write_bytes(plistlib.dumps(info))
pbx = '''// !$*UTF8*$!
{
 archiveVersion = 1; classes = {}; objectVersion = 56;
 objects = {
 A00000000000000000000001 = {isa = PBXProject; attributes = {LastUpgradeCheck = 1600;}; buildConfigurationList = A00000000000000000000002; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN, en, Base); mainGroup = A00000000000000000000003; productRefGroup = A00000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A00000000000000000000005);};
 A00000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000010, A00000000000000000000011); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
 A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000006, A0000000000000000000000D, A00000000000000000000004); sourceTree = "<group>";};
 A00000000000000000000004 = {isa = PBXGroup; children = (A00000000000000000000007); name = Products; sourceTree = "<group>";};
 A00000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000008; buildPhases = (A00000000000000000000009, A0000000000000000000000A, A0000000000000000000000B); buildRules = (); dependencies = (); name = Huixu; productName = Huixu; productReference = A00000000000000000000007; productType = "com.apple.product-type.application";};
 A00000000000000000000006 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Huixu/HuixuApp.swift; sourceTree = "<group>";};
 A00000000000000000000007 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Huixu.app; sourceTree = BUILT_PRODUCTS_DIR;};
 A00000000000000000000008 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000012, A00000000000000000000013); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
 A00000000000000000000009 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A0000000000000000000000C); runOnlyForDeploymentPostprocessing = 0;};
 A0000000000000000000000A = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;};
 A0000000000000000000000B = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (A0000000000000000000000E); runOnlyForDeploymentPostprocessing = 0;};
 A0000000000000000000000C = {isa = PBXBuildFile; fileRef = A00000000000000000000006;};
 A0000000000000000000000D = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Huixu/Assets.xcassets; sourceTree = "<group>";};
 A0000000000000000000000E = {isa = PBXBuildFile; fileRef = A0000000000000000000000D;};
 A00000000000000000000010 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 18.0; CLANG_ENABLE_MODULES = YES; SWIFT_OPTIMIZATION_LEVEL = "-Onone";}; name = Debug;};
 A00000000000000000000011 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 18.0; CLANG_ENABLE_MODULES = YES; SWIFT_OPTIMIZATION_LEVEL = "-O";}; name = Release;};
 A00000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.manyu2006131.huixu; PRODUCT_NAME = "$(TARGET_NAME)"; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; INFOPLIST_FILE = Huixu/Info.plist; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO;}; name = Debug;};
 A00000000000000000000013 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.manyu2006131.huixu; PRODUCT_NAME = "$(TARGET_NAME)"; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; INFOPLIST_FILE = Huixu/Info.plist; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO;}; name = Release;};
 }; rootObject = A00000000000000000000001;
}
'''
(root/'Huixu.xcodeproj').mkdir(exist_ok=True)
(root/'Huixu.xcodeproj'/'project.pbxproj').write_text(pbx)
scheme_dir = root/'Huixu.xcodeproj'/'xcshareddata'/'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme_dir.joinpath('Huixu.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="Huixu.app" BlueprintName="Huixu" ReferencedContainer="container:Huixu.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="Huixu.app" BlueprintName="Huixu" ReferencedContainer="container:Huixu.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Project generated')
# A simulator UI-test target exercises the actual app rather than duplicating its logic.
project = root/'Huixu.xcodeproj/project.pbxproj'
s = project.read_text()
s = s.replace('targets = (A00000000000000000000005);', 'targets = (A00000000000000000000005, B00000000000000000000001);')
s = s.replace('A0000000000000000000000D, A00000000000000000000004', 'A0000000000000000000000D, B00000000000000000000002, A00000000000000000000004')
s = s.replace('children = (A00000000000000000000007);', 'children = (A00000000000000000000007, B00000000000000000000003);')
objects = '''
 B00000000000000000000001 = {isa = PBXNativeTarget; buildConfigurationList = B00000000000000000000004; buildPhases = (B00000000000000000000005); buildRules = (); dependencies = (B00000000000000000000009); name = HuixuUITests; productName = HuixuUITests; productReference = B00000000000000000000003; productType = "com.apple.product-type.bundle.ui-testing";};
 B00000000000000000000002 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = tests/HuixuUITests.swift; sourceTree = "<group>";};
 B00000000000000000000003 = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = HuixuUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;};
 B00000000000000000000004 = {isa = XCConfigurationList; buildConfigurations = (B00000000000000000000007, B00000000000000000000008); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
 B00000000000000000000005 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (B00000000000000000000006); runOnlyForDeploymentPostprocessing = 0;};
 B00000000000000000000006 = {isa = PBXBuildFile; fileRef = B00000000000000000000002;};
 B00000000000000000000007 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.manyu2006131.huixu.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Automatic; TEST_TARGET_NAME = Huixu;}; name = Debug;};
 B00000000000000000000008 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.manyu2006131.huixu.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Automatic; TEST_TARGET_NAME = Huixu;}; name = Release;};
 B00000000000000000000009 = {isa = PBXTargetDependency; target = A00000000000000000000005; targetProxy = B0000000000000000000000A;};
 B0000000000000000000000A = {isa = PBXContainerItemProxy; containerPortal = A00000000000000000000001; proxyType = 1; remoteGlobalIDString = A00000000000000000000005; remoteInfo = Huixu;};
'''
s=s.replace(' }; rootObject =',objects+' }; rootObject =')
project.write_text(s)
scheme=scheme_dir/'Huixu.xcscheme'
s=scheme.read_text().replace('<LaunchAction', '''<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="B00000000000000000000001" BuildableName="HuixuUITests.xctest" BlueprintName="HuixuUITests" ReferencedContainer="container:Huixu.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction''')
scheme.write_text(s)
