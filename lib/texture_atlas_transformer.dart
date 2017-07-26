import 'dart:convert';
import 'package:barback/barback.dart';
import 'package:glob/glob.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;
import 'src/settings.dart';

final RegExp _rgxJson = new RegExp(r'\.json');

class TextureAtlasTransformer extends AggregateTransformer {
  final Map<String, String> _cache = {};
  final Map<String, Glob> _globs = {};
  TextureAtlasSettings _settings;
  final BarbackSettings barbackSettings;

  TextureAtlasTransformer.asPlugin(this.barbackSettings) {
    _settings = new TextureAtlasSettings.fromBarback(barbackSettings);
  }

  @override
  classifyPrimary(AssetId id) async {
    if (_cache.containsKey(id.path)) return _cache[id.path];

    for (var key in _settings.textureAtlases.keys) {
      var atlas = _settings.textureAtlases[key];
      for (var path in atlas.frames) {
        var glob = _globs.putIfAbsent(path, () => new Glob(path));
        var idPath = Uri.decodeFull(id.path);
        if (glob.matches(idPath)) return _cache[id.path] = key;
      }
    }

    return _cache[id.path] = null;
  }

  @override
  apply(AggregateTransform transform) async {
    var inputs = await transform.primaryInputs.toList();
    var outputPath = '${transform.key}.json';
    if (_settings.outputDir != null)
      outputPath = p.url.join(_settings.outputDir, outputPath);
    var imagePath = outputPath.replaceAll(_rgxJson, '.' + _settings.extension);

    Map<String, dynamic> atlasJson = {};
    List<Image> images = [];
    Map<Image, String> _img = {};
    Map<Image, Image> _source = {};

    for (var input in inputs) {
      var i = decodeImage(await transform
          .readInput(input.id)
          .fold<List<int>>([], (out, b) => out..addAll(b)));
      var img = i;

      if (_settings.scale != null) {
        var w = (img.width * _settings.scale.x).toInt();
        var h = (img.width * (_settings.scale.y ?? _settings.scale.x)).toInt();
        img = copyResize(img, w, h);
      } else if (_settings.resize != null) {
        img = copyResize(
            img, _settings.resize.x?.toInt(), _settings.resize.y?.toInt());
      }

      images.add(img);
      _img[img] = input.id.path;
      _source[img] = i;
    }

    int width = 0, height = 0;

    for (var img in images) {
      width += img.width;
      if (img.height > height) height = img.height;
    }

    var outputImage = new Image(width, height);
    int x = 0;

    List<Map> frames = atlasJson['frames'] = [];

    for (var img in images) {
      /*
      {
        "filename": "cactuar",
        "frame": {"x":249,"y":205,"w":213,"h":159},
        "rotated": false,
        "trimmed": true,
        "spriteSourceSize": {"x":0,"y":0,"w":213,"h":159},
        "sourceSize": {"w":231,"h":175}
      }
       */
      Map frameInfo = {'x': x, 'y': 0, 'w': img.width, 'h': img.height};
      var src = _source[img];
      Map frame = {
        'frame': frameInfo,
        'rotated': false,
        'trimmed': false,
        'filename': p.basenameWithoutExtension(_img[img]),
        'spriteSourceSize': {'x': 0, 'y': 0, 'w': img.width, 'h': img.height},
        'sourceSize': {'w': src.width, 'h': src.height}
      };

      frames.add(frame);

      copyInto(outputImage, img, dstX: x);
      x += img.width;
    }

    List<int> buf;

    switch (_settings.extension) {
      case 'jpg':
      case 'jpeg':
        buf = encodeJpg(outputImage);
        break;
      case 'png':
        buf = encodePng(outputImage);
        break;
      case 'gif':
        buf = encodeGif(outputImage);
        break;
      case 'tga':
        buf = encodeTga(outputImage);
        break;
      default:
        throw 'Unsupported output extension: "${_settings.extension}"';
    }

    // Animations
    var atlas = _settings.textureAtlases[transform.key];

    if (atlas.animations.isNotEmpty) {
      List<Map> sequences = atlasJson['sequences'] = [];

      atlas.animations.forEach((name, animation) {
        Map sequence = {'speed': animation.speed, 'loop': animation.loop};

        var cellString = animation.cells.trim();

        if (cellString == '*' || cellString.toLowerCase() == 'all') {
          sequence['cells'] = new List<int>.generate(images.length, (i) => i);
        } else {
          sequence['cells'] = cellString
              .split(',')
              .map((s) => s.trim())
              .map<int>(int.parse)
              .toList();
        }

        sequences.add(sequence);
      });
    }

    /*
    "meta": {
      "app": "http://www.codeandweb.com/texturepacker ",
      "version": "1.0",
      "image": "atlas_array_trim.png",
      "format": "RGBA8888",
      "size": {"w":650,"h":497},
      "scale": "1",
      "smartupdate": "$TexturePacker:SmartUpdate:b6887183d8c9d806808577d524d4a2b9:1e240ffed241fc58aca26b0e5d350d80:71eda69c52f7d9873cb6f00d13e1e2f8$"
    }
     */
    atlasJson['meta'] = {
      'app': 'https://github.com/thosakwe/texture_atlas_transformer',
      'version': '1.0.1',
      'image': p.basename(imagePath),
      'format': 'RGBA8888',
      'size': {},
      'scale': 1
    };

    transform.addOutput(new Asset.fromString(
        new AssetId(transform.package, outputPath), JSON.encode(atlasJson)));
    transform.addOutput(
        new Asset.fromBytes(new AssetId(transform.package, imagePath), buf));
  }
}
