import 'package:barback/barback.dart';

class TextureAtlasSettings {
  final Map<String, TextureAtlas> textureAtlases;
  final String outputDir, extension;
  final TextureAtlasScale scale, resize;

  TextureAtlasSettings(
      {this.textureAtlases,
      this.outputDir,
      this.extension,
      this.scale,
      this.resize});

  factory TextureAtlasSettings.fromBarback(BarbackSettings barbackSettings) {
    Map<String, TextureAtlas> atlases = {};
    var outputDir = barbackSettings.configuration['output_dir']?.toString();

    barbackSettings.configuration['files']?.forEach((k, v) {
      if (v is Map) {
        List<String> frames;
        Map<String, TextureAtlasAnimation> animations = {};

        if (v['animations'] is Map) {
          v['animations'].forEach((k, v) {
            animations[k] = new TextureAtlasAnimation.parse(k, v);
          });
        } else if (v['animations'] != null)
          throw '"animations" in file "$k" must be a Map.';

        if (v['frames'] is List) {
          frames = v['frames'].map<String>((x) => x.toString()).toList();
        } else
          throw 'File "$k" must have a "frames" field.';

        atlases[k] = new TextureAtlas(frames: frames, animations: animations);
      }
    });

    return new TextureAtlasSettings(
        textureAtlases: atlases,
        outputDir: outputDir,
        extension:
            barbackSettings.configuration['extension']?.toString() ?? 'png',
        scale: barbackSettings.configuration['scale'] == null
            ? null
            : new TextureAtlasScale.parse(
                barbackSettings.configuration['scale']),
        resize: barbackSettings.configuration['resize'] == null
            ? null
            : new TextureAtlasScale.parse(
                barbackSettings.configuration['resize']));
  }
}

class TextureAtlas {
  final Map<String, TextureAtlasAnimation> animations;
  final List<String> frames;
  TextureAtlas({this.animations, this.frames});
}

class TextureAtlasAnimation {
  final String cells;
  final bool loop;
  final double speed;

  TextureAtlasAnimation(this.cells, this.loop, this.speed);

  factory TextureAtlasAnimation.parse(String name, Map m) {
    if (!m.containsKey('cells'))
      throw 'Animation "$name" must contain a "cells" field.';

    return new TextureAtlasAnimation(
        m['cells'], m['loop'] == true, m['speed'] ?? 1.0);
  }
}

class TextureAtlasScale {
  final num x, y;

  TextureAtlasScale({this.x, this.y});
  factory TextureAtlasScale.parse(m) => m is num
      ? new TextureAtlasScale(x: m)
      : new TextureAtlasScale(x: m['x'], y: m['y']);
}
