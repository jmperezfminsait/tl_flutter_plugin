import 'dart:convert';
import 'dart:io';

class SetupMobilePlatforms {
  void run(String flutterDir, String projectDir) {
    // Check if android and ios directories exist
    if (!Directory('$projectDir/android').existsSync() ||
        !Directory('$projectDir/ios').existsSync()) {
      stdout.writeln(
          "Error with Flutter project's root directory. Please confirm the directory contains an android and ios directory.");
      exit(1);
    }

    // Set up Android
    // Copy assets from plugin to flutter project
    print("\nCopying Android assets");
    bool androidSuccess = copyAssets('$flutterDir/automation/android/',
        '$projectDir/android/app/src/main/assets/');

    if (androidSuccess) {
      stdout.writeln("Complete Copying Android assets\n");
    } else {
      exit(1);
    }

    // Update build gradle
    String androidBuildGradle = '$projectDir/android/app/build.gradle';
    updateBuildGradle(androidBuildGradle);

    // Update config
    var input = File("$projectDir/TealeafConfig.json").readAsStringSync();
    Map<String, dynamic> configMap = jsonDecode(input);
    Map<String, dynamic> tealeafMap = configMap['Tealeaf'];
    String eocoreVersion = tealeafMap["AndroidEOCoreVersion"];
    String tealeafVersion = tealeafMap["AndroidTealeafVersion"];

    Map<String, String> properties = {
      "tealeaf": tealeafVersion,
      "eocore": eocoreVersion
    };

    String androidPluginBuildGradle = '$flutterDir/android/build.gradle';
    updateSDKBuildVersion(androidPluginBuildGradle, properties);

    bool useRelease = tealeafMap["useRelease"];
    updateUseRelease(androidPluginBuildGradle, useRelease);

    if (!androidSuccess) {
      stdout.writeln("Android environment problem copy assets. \n");
    }
  }

  bool copyAssets(String sourceDir, String destinationDir) {
    try {
      Directory(destinationDir).createSync(recursive: true);
      Process.runSync('cp', ['-r', sourceDir, destinationDir]);
      return true;
    } catch (e) {
      stdout.writeln('Failed to copy assets: $e');
      return false;
    }
  }

  /// MinSDKVersion needs to be >= 21
  ///
  void updateBuildGradle(String? androidBuildGradle) {
    if (androidBuildGradle == null) {
      stdout.writeln('Error: androidBuildGradle path is null');
      return;
    }

    String content = File(androidBuildGradle).readAsStringSync();

    // Check if minSdkVersion is below 21
    RegExp minSdkVersionRegex = RegExp(r'flutter\.minSdkVersion\s*=\s*(\d+)');
    if (minSdkVersionRegex.hasMatch(content)) {
      int minSdkVersion =
          int.parse(minSdkVersionRegex.firstMatch(content)!.group(1)!);
      if (minSdkVersion < 21) {
        content = content.replaceFirst(
            minSdkVersionRegex, 'flutter.minSdkVersion = 21');
      }
    }

    File(androidBuildGradle).writeAsStringSync(content);
  }

  void updateUseRelease(String androidBuildGradle, bool useRelease) {
    const String mavenUrl =
        'maven { url "https://s01.oss.sonatype.org/content/repositories/staging" }';

    RegExp mavenUrlPattern = RegExp(
        r'\s*maven\s*{\s*url\s*"https://s01\.oss\.sonatype\.org/content/repositories/staging"\s*}\s*');

    // Read the content of the file.
    String content = File(androidBuildGradle).readAsStringSync();

    // Simplified check for the Maven URL's presence, assuming standard formatting might not exist.
    bool mavenUrlExists = content.contains(mavenUrl.trim());

    // Find the beginning of the repositories block.
    String startMarker = 'rootProject.allprojects {\n    repositories {';
    int startIndex = content.indexOf(startMarker);

    if (useRelease) {
      // If useRelease is true and the Maven URL exists, remove it.
      content = content.replaceAll(mavenUrlPattern, '\n');
    } else {
      // If useRelease is false and the Maven URL does not exist, add it.
      if (!mavenUrlExists && startIndex != -1) {
        // Locate where to insert the Maven URL.
        int insertIndex =
            content.indexOf('}', startIndex + startMarker.length) - 1;
        if (insertIndex != -1) {
          String beforeInsert = content.substring(0, insertIndex + 1);
          String afterInsert = content.substring(insertIndex);

          // Inserting the Maven URL with proper indentation.
          content = "$beforeInsert\n        ${mavenUrl.trim()}\n $afterInsert";
        }
      }
    }

    // Write the modified content back to the file.
    File(androidBuildGradle).writeAsStringSync(content);
  }

  /// Which SDK version to be used by plugin
  ///
  void updateSDKBuildVersion(
      String androidBuildGradle, Map<String, String> properties) {
    String content = File(androidBuildGradle).readAsStringSync();

    properties.forEach((key, value) {
      // String dependencyRegex =
      //     "(?<=(api|implementation)\\s+)[\"']io\\.github\\.acoustic-analytics:$key:[\\d.]+[\"']";
      String dependencyRegex =
          "(?<=(api|implementation)\\s+)[\"']io\\.github\\.acoustic-analytics:$key:.*[\"']";

      String replacement = "'io.github.acoustic-analytics:$key:$value'";
      content = content.replaceAll(RegExp(dependencyRegex), replacement);
    });

    File(androidBuildGradle).writeAsStringSync(content);
  }

  // bool installPods(String projectDir) {
  //   try {
  //     Directory('$projectDir/ios/').createSync();
  //     Process.runSync('rm', ['-rf', 'Podfile.lock'],
  //         workingDirectory: '$projectDir/ios/');
  //     Process.runSync('flutter', ['precache', '--ios'],
  //         workingDirectory: '$projectDir/ios/');
  //     Process.runSync('pod', ['update'], workingDirectory: '$projectDir/ios/');
  //     Process.runSync('pod', ['install'], workingDirectory: '$projectDir/ios/');
  //     return true;
  //   } catch (e) {
  //     print('Issue installing pods: $e');
  //     return false;
  //   }
  // }
}

void main(List<String> args) {
  // String currentProjectDir = Directory.current.path;
  // String pluginRoot = getPluginPath(currentProjectDir);

  // Get the Flutter project path from the environment variable
  // final flutterProjectPath = Platform.environment['FLUTTER_PROJECT_PATH'];
  // print(flutterProjectPath);
  // print(Platform.resolvedExecutable);

  // if (pluginRoot.isEmpty) {
  //   print('Error: FLUTTER_PROJECT_PATH environment variable not set.');
  //   exit(1);
  // }

  if (args.length != 2) {
    print('Usage: dart run flutter_setup.dart <flutterDir> <projectDir>');
    exit(1);
  }

  String flutterDir = args[0];
  String projectDir = args[1];

  print(flutterDir);
  print(projectDir);

  SetupMobilePlatforms().run(flutterDir, projectDir);
}
