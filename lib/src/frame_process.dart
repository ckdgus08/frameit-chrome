import 'dart:io';

import 'package:frameit_chrome/src/config.dart';
import 'package:frameit_chrome/src/frameit_frame.dart';
import 'package:image/image.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:quiver/check.dart';
import 'package:supercharged_dart/supercharged_dart.dart';

final _logger = Logger('process_screenshots');

class FrameProcess {
  FrameProcess({
    required this.workingDir,
    required this.config,
    required this.chromeBinary,
    required this.framesProvider,
    required this.pixelRatio,
  });

  final Directory workingDir;
  final FrameConfig config;
  final String chromeBinary;
  final FramesProvider framesProvider;
  final double pixelRatio;
  bool validatedPixelRatio = false;

  List<String> rewriteScreenshotName(String name) {
    if (name.contains('framed')) {
      return [];
    }
    final rewrite = config.rewrite;

    final ret = <String>[];
    for (final r in rewrite) {
      final hasMatch = name.contains(r
          .pattern); // r.pattern.contains(name);// r.patternRegExp.hasMatch(name);
      if (!hasMatch) {
        if (r.action == FileAction.include) {
          return ret;
        }
        continue;
      }
      var newName = name;
      newName = name.replaceAll(r.patternRegExp, r.replace);
      switch (r.action) {
        case FileAction.duplicate:
          ret.add(newName);
          break;
        case FileAction.rename:
          return ret..add(newName);
        case FileAction.exclude:
          return [];
        case FileAction.include:
          break;
      }
    }
    ret.add(name);
    return ret;
  }

  Future<void> processScreenshots(
      Directory dir,
      Directory outDir,
      Map<String, String> titleStrings,
      Map<String, String> keywordStrings,
      ) async {
    checkArgument(dir.existsSync(), message: 'Dir does not exist $dir');
    final createdScreenshots = <ProcessScreenshotResult>[];
    await for (final file in dir.list(recursive: true)) {
      if (file is! File || !file.path.contains('af')) {
        continue;
      }

      final name =
      rewriteScreenshotName(path.basenameWithoutExtension(file.path));

      for (final variant in name) {
        print('name => ${name}');
        print('dir: => ${dir}, variant => ${variant.toString()}');

        final result = await _processScreenshot(
          dir,
          outDir,
          file,
          titleStrings,
          keywordStrings,
          variant,
        );

        createdScreenshots.add(result);
      }
    }

    final imageHtml = createdScreenshots
        .groupBy<String, ProcessScreenshotResult>(
            (element) => element.config.previewLabel)
        .entries
        .expand((e) {
      e.value.sort((a, b) => a.compareTo(b));
      return [
        '<h1>${e.key}</h2>',
        ...e.value.map((e) {
          final src = path.relative(e.path, from: outDir.path);
          return '''<img src="$src" alt="${path.basename(e.path)}" />''';
        })
      ];
    }).join('');
    // createdScreenshots.sort((a, b) => a.compareTo(b));

    // final imageHtml = createdScreenshots.map((e) {
    //   final src = path.relative(e.path, from: outDir.path);
    //   return '''<img src="$src" alt="" />''';
    // }).join('');

    print("하이루:${outDir.path}");
    await File(path.join(outDir.path, '_preview.html')).create(recursive: true);

    await File(path.join(outDir.path, '_preview.html')).writeAsString('''
    <!--suppress ALL --><html lang="en"><head><title>present me</title>
    <style>
      :root {
        --height: 600;
      }
      body { background-color: #efefef; }
      img {
        max-height: calc(var(--height) * 1px);
        margin-left: 16px;
      }
      input {
        width: 400px;
      }
    </style>
    <script>
    document.addEventListener('DOMContentLoaded', function () {
      let h = document.getElementById('height');
      let root = document.documentElement;
      h.addEventListener('input', function () {
        console.log('setting to ' + h.value);
        root.style.setProperty('--height', h.value);
      });
    });
    </script>
    </head>
    <div><label for="height">Preview Height:</label> <input type="range" min="100" max="2000" value="600" id="height" /></div>
    $imageHtml
    <body></body></html>
    ''');

    print("하이루2");
  }

  Future<ProcessScreenshotResult> _processScreenshot(
      Directory srcDir,
      Directory outDir,
      File file,
      Map<String, String> titleStrings,
      Map<String, String> keywordStrings,
      String screenshotName) async {
    // final outFile = path.join(file.parent.path,
    //     '{path.basenameWithoutExtension(file.path)}_framed.png');

    // find title and keyword
    final imageConfig = config.findImageConfig(screenshotName);
    final title = _findString(titleStrings, screenshotName);
    final keyword = _findString(keywordStrings, screenshotName);

    final replacedTargetName =
    path.join(file.parent.path, '$screenshotName.png');
    final outFilePath = path.join(
        outDir.path, path.relative(replacedTargetName, from: srcDir.path));
    await File(outFilePath).parent.create(recursive: true);

    print(
        'screenshotName:$screenshotName imageConfig?.device:${imageConfig.device}');

    // 여기서 찾았네ㅇㅇ
    final frame = framesProvider.frameForScreenshot(imageConfig.device);
    _logger.fine(
        'Rendering $screenshotName with title: $title ($keyword) and $frame');

    final image = decodeImage(await file.readAsBytes());
    if (image == null) {
      throw Exception('[ERROR] 이미지 null');
    }

    final css = await _createCss(
      frame,
      image.width,
      image.height,
      screenshot: file,
      title: title,
      keyword: keyword,
    ) +
        '\n${imageConfig.css}\n';
    final indexHtml = File(path.join(workingDir.path, 'index.html'));
    final cssFile = File(path.join(workingDir.path, 'index_override.css'));
    final screenshotFile = File(path.join(workingDir.path, 'screenshot.png'));
    if (screenshotFile.existsSync()) {
      await screenshotFile.delete();
    }
    if (!indexHtml.existsSync()) {
      throw StateError('Expected index.html to be in the current directory.');
    }
    await cssFile.writeAsString(css);
    final runStopwatch = Stopwatch()..start();

    final width = imageConfig.cropWidth;
    final height = imageConfig.cropHeight;

    final result = await Process.run(
        chromeBinary,
        [
          '--headless',
          '--no-sandbox',
          '--disable-gpu',
          '--screenshot',
          '--hide-scrollbars',
          '--window-size=${width ~/ pixelRatio},${height ~/ pixelRatio}',
          'index.html',
        ],
        workingDirectory: workingDir.path);
    if (result.exitCode != 0) {
      throw StateError(
          'Chrome headless did not succeed. ${result.exitCode}: $result');
    }

    if (!validatedPixelRatio) {
      final screenshot = decodeImage(await screenshotFile.readAsBytes());
      if (screenshot == null) {
        throw Exception('[ERROR] 이미지 null');
      }
      if (screenshot.width != width) {
        // throw StateError(
        //     'Generated image width did not match original image width. '
        //     'Wrong device pixel ratio?'
        //     ' was: ${screenshot.width}'
        //     ' expected: $width'
        //     ' ratio: $pixelRatio');
      }
      validatedPixelRatio = true;
    }
    // final screenshotResized = copyResize(screenshot, width: image.width);
    // await File(outFilePath).writeAsBytes(encodePng(screenshotResized));

    await screenshotFile.copy(outFilePath);

    _logger.info('Created (${runStopwatch.elapsedMilliseconds}ms) '
        '$outFilePath');
    // if (srcDir.path.contains('de-DE') && outFilePath.contains('launchscreen')) {
    //   print('DEBUG me.');
    //   exit(0);
    // }

    return ProcessScreenshotResult(imageConfig, outFilePath);
  }

  static String cssEscape(String str) {
    str = str.replaceAllMapped(RegExp('[^A-Za-z _-]+'), (match) {
      // str.replaceAllMapped(RegExp('[\n\t\'\"]'), (match) {
      final str = match.group(0);
      return str?.runes.map((e) {
        return '\\${e.toRadixString(16).padLeft(6, '0')} ';
      }).join('') ??
          '';
    });
    return '"$str"';
  }

  Future<String> _createCss(
      Frame frame,
      int targetWidth,
      int targetHeight, {
        required File screenshot,
        required String title,
        required String keyword,
      }) async {
    final ratio = pixelRatio;
    final image = decodeImage(await frame.image.readAsBytes());
    if (image == null) {
      throw Exception('[ERROR] 이미지 null');
    }
    final w = image.width / ratio;
    final h = image.height / ratio;
    final separator = title.isNotEmpty && keyword.isNotEmpty ? ' ' : '';
    return '''
:root {
  --frame-orig-width: $w;
  --frame-orig-height: $h;

  --frame-orig-offset-x: ${frame.offsetX / ratio};
  --frame-orig-offset-y: ${frame.offsetY / ratio};

  --target-width: ${targetWidth / ratio};
  --target-height: ${targetHeight / ratio};
}
.keyword:before {
    content: ${cssEscape(keyword)};
}
.keyword:after {
    content: '$separator';
}
.title:after {
    content: ${cssEscape(title)};
}
.screenshot-bg {
    background-image: url("${screenshot.absolute.path}");
}
.frame-bg {
    background-image: url("${frame.image.absolute.path}");
}
''';
  }

  String _findString(Map<String, String> strings, String filename) {
    for (final entry in strings.entries) {
      if (filename.contains(entry.key)) {
        return entry.value;
      }
    }
    return '';
  }
}

class ProcessScreenshotResult implements Comparable<ProcessScreenshotResult> {
  ProcessScreenshotResult(this.config, this.path);

  final FrameImage config;
  final String path;

  @override
  int compareTo(ProcessScreenshotResult other) {
    return config.previewLabel.compareTo(other.config.previewLabel);
  }
}
