import 'dart:convert';
import 'dart:io';

import 'package:frameit_chrome/src/frame_colors.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('frameit_frame');

String _prepareString(String str) =>
    str.replaceAll(RegExp(r'[_-]'), ' ').toLowerCase();

class FramesProvider {
  FramesProvider._(this.frames);

  static final offsetPattern = RegExp(r'^([+-]+\d+)([+-]+\d+)');

  final List<Frame> frames;

  static MapEntry<String, String> _frameInfo(
      String deviceName, String fileBasename) {
    if (fileBasename.startsWith('Apple ') && !deviceName.startsWith('Apple ')) {
      fileBasename = fileBasename.replaceAll('Apple ', '');
    }
    if (fileBasename.startsWith(deviceName)) {
      if (fileBasename.length > deviceName.length) {
        final color = fileBasename.substring(deviceName.length + 1);
        if (FRAME_COLORS.contains(color)) {
          _logger.finest('Found for $deviceName: $fileBasename');
          return MapEntry(deviceName, color);
        }
      } else {
        return MapEntry(deviceName, '');
      }
    }
    return MapEntry('', '');
  }

  static Future<FramesProvider> create(Directory baseDir) async {
    final frameImages = (await baseDir
        .list()
        .where((event) => event.path.endsWith('png'))
        .toList())
        .whereType<File>()
        .toList();

    final offsetsFile = path.join(baseDir.path, 'offsets.json');
    final offsetJson = json.decode(await File(offsetsFile).readAsString())
        as Map<String, dynamic>;

    final frames = <Frame>[];

    for (var e in (offsetJson['portrait'] as Map<String, dynamic>).entries) {
      String deviceName = e.key;
      final offsetString = e.value['offset'] as String;
      final offsetMatch = offsetPattern.firstMatch(offsetString);

      if (offsetMatch == null) {
        _logger.warning(
            'Invalid offset format => $offsetString, valid format => ${offsetPattern.toString()}');
        continue;
      }

      final offsetX = int.parse(offsetMatch.group(1)!);
      final offsetY = int.parse(offsetMatch.group(2)!);
      final width = int.parse(e.value['width'].toString());

      final image = frameImages
          .where((frame) =>
              _frameInfo(deviceName, path.basenameWithoutExtension(frame.path))
                  .key
                  .isNotEmpty)
          .firstOrNull;

      if (image == null) {
        _logger.warning('No matching image found for device: $deviceName');
        continue;
      }

      frames.add(Frame(
        name: deviceName,
        orientation: Orientation.portrait,
        offsetX: offsetX,
        offsetY: offsetY,
        width: width,
        image: image,
      ));
    }

    frames.sort((a, b) => -a.nameMatch.compareTo(b.nameMatch));

    return FramesProvider._(frames);
  }

  Frame frameForScreenshot(String screenshotName) {
    final match = _prepareString(screenshotName);

    for (final element in frames) {
      print('여기서 기기 이름 목록 확인:${element.nameMatch} 사용하려는 스크린샷 이름:$match');
    }

    return frames.firstWhere((element) {
      return match.contains(element.nameMatch);
    }, orElse: () {
      throw Exception('unable to find frame for $match');
    });
  }

// void
}

enum Orientation {
  portrait,
  landscape,
}

class Frame {
  Frame({
    required this.name,
    required this.orientation,
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.image,
  }) : nameMatch = _prepareString(name);

  final String name;
  final String nameMatch;
  final Orientation orientation;
  final int offsetX;
  final int offsetY;
  final int width;
  final File image;

  @override
  String toString() {
    return 'Frame{name: $name, orientation: $orientation, offsetX: $offsetX, offsetY: $offsetY, width: $width, image: $image}';
  }
}
