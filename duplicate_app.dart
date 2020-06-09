import 'dart:io';
import 'package:args/args.dart';

var srcName = 'TFBase';
var srcOrg = 'com.tachyonfactory';
var dstName = 'new_app_name';
var dstOrg = '';

String srcProjectPath;
String dstProjectPath;
bool forceOverwrite = false;

void deleteAllDir(String path) {
  try {
    Directory(path).deleteSync(recursive: true);
  } catch (_) {}
}

void copyDirRecursive(String src, String dst) {
  final entries = Directory(src).listSync(recursive: true);
  for (final entry in entries) {
    final newPath = entry.path.replaceFirst(src, dst);
    final relativePath = entry.path.replaceFirst(src, '');
    if (entry is Directory) {
      if (relativePath.startsWith('/build')) continue;
      if (relativePath.startsWith('/.git')) continue;
      if (relativePath.startsWith('/.dart_tool')) continue;
      Directory(newPath).createSync(recursive: true);
    }
  }
  for (final entry in entries) {
    final oldPath = entry.path;
    final relativePath = entry.path.replaceFirst(src, '');
    final newPath = entry.path.replaceFirst(src, dst);
    if (entry is File) {
      if (relativePath.startsWith('/build')) continue;
      if (relativePath.startsWith('/.git')) continue;
      if (relativePath.startsWith('/.dart_tool')) continue;
      final bytes = File(oldPath).readAsBytesSync();
      File(newPath).writeAsBytesSync(bytes);
    }
  }
}

Future<bool> copyProjectFolder() async {
  // remove $newName folder (for testing)
  if (forceOverwrite) {
    deleteAllDir(dstProjectPath);
  }

  if (Directory(dstProjectPath).existsSync()) {
    print('$dstProjectPath already exists!');
    return false;
  }

  // copy project folder
  copyDirRecursive(srcProjectPath, dstProjectPath);

  return true;
}

String extractOrgFromAppId(String appId) {
  final x = appId.substring(0, appId.lastIndexOf('.'));
  return x;
}

void getOldOrg(String path) {
  try {
    // my_hello_app/android/app/build.gradle
    //    applicationId "com.eee.my_new_app"
    final txt = File(path + '/android/app/build.gradle').readAsStringSync();
    RegExp re = RegExp(r'.*\bapplicationId "([\w\.]+)".*');
    final m = re.firstMatch(txt);
    srcOrg = extractOrgFromAppId(m.group(1));
    return;
  } catch (_) {}

  try {
    // my_hello_app/android/app/src/main/AndroidManifest.xml
    //    package="com.eee.my_new_app">
    final txt = File(path + '/android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    RegExp re = RegExp(r'.*\package="([\w\.]+)".*');
    final m = re.firstMatch(txt);
    srcOrg = extractOrgFromAppId(m.group(1));
    return;
  } catch (_) {}

  try {
    // my_hello_app/ios/Runner.xcodeproj/project.pbxproj
    //    PRODUCT_BUNDLE_IDENTIFIER = com.eee.my_new_app;
    final txt =
        File(path + '/ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    RegExp re = RegExp(r'.*\PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([\w\.]+);.*');
    final m = re.firstMatch(txt);
    srcOrg = extractOrgFromAppId(m.group(1));
    return;
  } catch (_) {}

  try {
    // my_hello_app/macos/Runner.xcodeproj/project.pbxproj
    //    PRODUCT_BUNDLE_IDENTIFIER = com.eee.my_new_app;
    final txt = File(path + '/macos/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    RegExp re = RegExp(r'.*\PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([\w\.]+);.*');
    final m = re.firstMatch(txt);
    srcOrg = extractOrgFromAppId(m.group(1));
    return;
  } catch (_) {}

  print('failed to extract org from existing project');
  exit(1);
}

Future updateFiles() async {
  final entries = Directory(dstProjectPath).listSync(recursive: true);

  for (final entry in entries) {
    if (entry is File) {
      final ext = entry.path.split('.').last;

      try {
        var txt = File(entry.path).readAsStringSync();
        if (ext == 'dart') {
          // print('dart:' + entry.path);
          txt = txt.replaceAll(
              'package:${srcName.toLowerCase()}', 'package:$dstName');
        } else {
          // print(ext + ':' + entry.path);
          txt = txt.replaceAll(srcOrg, dstOrg);
          txt = txt.replaceAll(srcName, dstName);
          txt = txt.replaceAll(srcName.toLowerCase(), dstName);
        }
        File(entry.path).writeAsStringSync(txt);
      } catch (_) {}
    }
  }

  final findPath = srcOrg.replaceAll('.', '/') + '/' + srcName.toLowerCase();
  final replacePath = dstOrg.replaceAll('.', '/') + '/' + dstName.toLowerCase();
  for (final entry in entries) {
    if (entry is Directory) {
      if (entry.path.indexOf(findPath) != -1) {
        copyFiles(entry.path, entry.path.replaceAll(findPath, replacePath));
      }
    }
  }
}

void createAllDirs(String path) {
  Directory(path).createSync(recursive: true);
}

void copyFiles(String srcFolder, String dstFolder) {
  createAllDirs(dstFolder);

  final entries = Directory(srcFolder).listSync(recursive: true);

  for (final entry in entries) {
    if (entry is File) {
      final dstPath = dstFolder + entry.path.substring(srcFolder.length);
      print(dstPath);
      entry.copySync(dstPath);
      entry.deleteSync();
    } else if (entry is Directory) {
      final dstPath = dstFolder + entry.path.substring(srcFolder.length);
      Directory(dstPath).createSync(recursive: true);
    }
  }
}

ArgResults argResults;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('org')
    ..addFlag('force-overwrite', negatable: false, abbr: 'f')
    ..addFlag('test', negatable: false, abbr: 't');

  argResults = parser.parse(arguments);

  if (argResults['org'] != null) {
    dstOrg = argResults['org'];
  }

  forceOverwrite = argResults['force-overwrite'];
  bool test = argResults['test'];

  if (argResults.rest.length != 2) {
    print('dart duplicate_app.dart srcProjectPath new_app_name');
    exitCode = 2;
  } else {
    srcProjectPath = argResults.rest[0];
    if (Platform.isWindows) {
      srcProjectPath = srcProjectPath.replaceAll('\\','/');
    }
    if (srcProjectPath.endsWith('/')) {
      // remove trailing /
      srcProjectPath = srcProjectPath.substring(0, srcProjectPath.length - 1);
    }
    srcName = srcProjectPath.split('/').last;
    dstName = argResults.rest[1];
    final arr = srcProjectPath.split('/');
    arr.removeLast();
    arr.add(dstName);
    dstProjectPath = arr.join('/');

    getOldOrg(srcProjectPath);
    if (dstOrg.isEmpty) {
      dstOrg = srcOrg;
    }

    print('srcProject = $srcName ($srcOrg)');
    print('dstProject  = $dstName ($dstOrg)');
    print('srcProjectPath = $srcProjectPath');
    print('dstProjectPath = $dstProjectPath');

    if (test) return;
    if (await copyProjectFolder()) {
      await updateFiles();

      print('project copied to \'$dstProjectPath\'');
    }
  }
}
