import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

part 'config.g.dart';

@JsonSerializable(anyMap: true)
class FrameConfig {
  FrameConfig({
    required this.rewrite,
    required this.images,
  });

  factory FrameConfig.fromJson(Map json) => _$FrameConfigFromJson(json);

  static const FILE_NAME = 'frameit.yaml';

  Map<String, dynamic> toJson() => _$FrameConfigToJson(this);

  final List<FileNameMapping> rewrite;
  final Map<String, FrameImage> images;

  static Future<FrameConfig> load(String baseDir) async {
    final configFile = File(path.join(baseDir, FrameConfig.FILE_NAME));
    if (!configFile.existsSync()) {
      return FrameConfig(rewrite: [], images: {});
    }
    return FrameConfig.fromJson(
        loadYaml(await configFile.readAsString()) as Map);
  }

  FrameImage findImageConfig(String screenshotName) {
    return images.entries
        .firstWhere((element) => screenshotName.contains(element.key))
        .value;
  }
}

enum FileAction {
  duplicate,
  exclude,
  rename,
  include,
}

@JsonSerializable(nullable: false, anyMap: true)
class FileNameMapping {
  FileNameMapping({
    required this.pattern,
    required this.replace,
    // @JsonKey(defaultValue: false) this.duplicate,
    // @JsonKey(defaultValue: false) this.exclude,
    @JsonKey(defaultValue: FileAction.rename) required this.action,
  }) {
    _patternRegExp = RegExp('');
  }

  factory FileNameMapping.fromJson(Map json) => _$FileNameMappingFromJson(json);

  Map<String, dynamic> toJson() => _$FileNameMappingToJson(this);

  final String pattern;
  final String replace;

  // final bool duplicate;
  // final bool exclude;
  final FileAction action;

  late RegExp _patternRegExp;

  RegExp get patternRegExp => _patternRegExp;
}

@JsonSerializable(anyMap: true)
class FrameImage {
  FrameImage({
    required this.cropWidth,
    required this.cropHeight,
    required this.device,
    required this.previewLabel,
    required this.css,
  });

  factory FrameImage.fromJson(Map<String, dynamic> json) =>
      _$FrameImageFromJson(json);

  Map<String, dynamic> toJson() => _$FrameImageToJson(this);

  /// Crop with of the final image. (null for using the original width)
  final int cropWidth;

  /// Crop height of the final image. (null for using the original width)
  final int cropHeight;

  /// device name used to look up correct frame.
  final String device;

  /// Optional label used only for the `_preview.html`
  final String previewLabel;

  /// Allows customizing the css.
  final String css;
}
