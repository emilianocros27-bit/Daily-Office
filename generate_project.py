from pathlib import Path
import hashlib
root=Path(__file__).parent
uid=lambda s:hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def add(name,body): objects.append(f'{uid(name)} = {{ {body} }};'); return uid(name)
files=[]; builds=[]
for p in sorted((root/'DailyOffice').glob('*.swift')):
 f=add(str(p.name),f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{p.name}"; sourceTree = "<group>";')
 files.append(f)
 builds.append(add('build'+p.name,f'isa = PBXBuildFile; fileRef = {f};'))
resource=add('skills-json','isa = PBXFileReference; lastKnownFileType = text.json; path = DefaultSkills.json; sourceTree = "<group>";')
files.append(resource)
resourcebuild=add('skills-build',f'isa = PBXBuildFile; fileRef = {resource};')
skillsfolder=add('skills-folder','isa = PBXFileReference; lastKnownFileType = folder; path = Skills; sourceTree = SOURCE_ROOT;')
files.append(skillsfolder)
folderbuild=add('skills-folder-build',f'isa = PBXBuildFile; fileRef = {skillsfolder};')
resources=add('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resourcebuild},{folderbuild},); runOnlyForDeploymentPostprocessing = 0;')
app=add('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = "Daily Office.app"; sourceTree = BUILT_PRODUCTS_DIR;')
sources=add('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
framework=add('framework','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
group=add('code',f'isa = PBXGroup; children = ({",".join(files)},); path = DailyOffice; sourceTree = "<group>";')
products=add('products',f'isa = PBXGroup; children = ({app},); name = Products; sourceTree = "<group>";')
main=add('main',f'isa = PBXGroup; children = ({group},{products},); sourceTree = "<group>";')
base='MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'
settings=base+' PRODUCT_NAME = "Daily Office"; PRODUCT_BUNDLE_IDENTIFIER = app.dailyoffice.mac; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_LSUIElement = YES; INFOPLIST_KEY_NSScreenCaptureUsageDescription = "Daily Office captura la región que eliges para enviarla al agente seleccionado."; INFOPLIST_KEY_NSAppleEventsUsageDescription = "Daily Office abre Terminal para ejecutar el comando de tu proyecto."; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_APP_SANDBOX = NO; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0; SWIFT_EMIT_LOC_STRINGS = YES;'
for name in ['Debug','Release']:
 add('project'+name,f'isa = XCBuildConfiguration; buildSettings = {{{base}}}; name = {name};')
 add('target'+name,f'isa = XCBuildConfiguration; buildSettings = {{{settings} SWIFT_OPTIMIZATION_LEVEL = "'+('-Onone' if name=='Debug' else '-O')+f'";}}; name = {name};')
for kind in ['project','target']:
 add(kind+'list',f'isa = XCConfigurationList; buildConfigurations = ({uid(kind+"Debug")},{uid(kind+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=add('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetlist")}; buildPhases = ({sources},{framework},{resources},); buildRules = (); dependencies = (); name = DailyOffice; productName = "Daily Office"; productReference = {app}; productType = "com.apple.product-type.application";')
project=add('project',f'isa = PBXProject; attributes = {{LastSwiftUpdateCheck = 2700; LastUpgradeCheck = 2700;}}; buildConfigurationList = {uid("projectlist")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = es; hasScannedForEncodings = 0; knownRegions = (es,en,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
p=root/'DailyOffice.xcodeproj'; p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
