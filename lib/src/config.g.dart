// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FrameConfig _$FrameConfigFromJson(Map json) => FrameConfig(
      rewrite: (json['rewrite'] as List<dynamic>)
          .map((e) => FileNameMapping.fromJson(e as Map))
          .toList(),
      images: (json['images'] as Map).map(
        (k, e) => MapEntry(k as String,
            FrameImage.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
    );

Map<String, dynamic> _$FrameConfigToJson(FrameConfig instance) =>
    <String, dynamic>{
      'rewrite': instance.rewrite,
      'images': instance.images,
    };

FileNameMapping _$FileNameMappingFromJson(Map json) => FileNameMapping(
      pattern: json['pattern'] as String,
      replace: json['replace'] as String,
      action: $enumDecode(_$FileActionEnumMap, json['action']),
    );

Map<String, dynamic> _$FileNameMappingToJson(FileNameMapping instance) =>
    <String, dynamic>{
      'pattern': instance.pattern,
      'replace': instance.replace,
      'action': _$FileActionEnumMap[instance.action]!,
    };

const _$FileActionEnumMap = {
  FileAction.duplicate: 'duplicate',
  FileAction.exclude: 'exclude',
  FileAction.rename: 'rename',
  FileAction.include: 'include',
};

FrameImage _$FrameImageFromJson(Map json) => FrameImage(
      cropWidth: json['cropWidth'] as int,
      cropHeight: json['cropHeight'] as int,
      device: json['device'] as String,
      previewLabel: json['previewLabel'] as String,
      css: json['css'] as String,
    );

Map<String, dynamic> _$FrameImageToJson(FrameImage instance) =>
    <String, dynamic>{
      'cropWidth': instance.cropWidth,
      'cropHeight': instance.cropHeight,
      'device': instance.device,
      'previewLabel': instance.previewLabel,
      'css': instance.css,
    };

// **************************************************************************
// StaticTextGenerator
// **************************************************************************

// modify build.yaml to configure this text.
