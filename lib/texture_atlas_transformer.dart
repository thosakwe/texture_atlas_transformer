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
    Map<String, dynamic> atlasJson = {'name': transform.key};
    List<Image> images = [];

    for (var input in inputs) {
      var i = decodeImage(await transform
          .readInput(input.id)
          .fold<List<int>>([], (out, b) => out..addAll(b)));
      var img = i;

      if (_settings.scale != null) {
        var w = (img.width * _settings.scale.x).toInt();
        var h =
            (img.width * (_settings.scale.y ?? _settings.scale.x)).toInt();
        img = copyResize(img, w, h);
      } else if (_settings.resize != null) {
        img = copyResize(
            img, _settings.resize.x?.toInt(), _settings.resize.y?.toInt());
      }

      images.add(img);
    }

    int width = 0, height = 0;

    for (var img in images) {
      width += img.width;
      if (img.height > height) height = img.height;
    }

    var outputImage = new Image(width, height);
    int x = 0;

    List<Map> cells = atlasJson['cells'] = [];

    for (var img in images) {
      Map cellInfo = {'x': x, 'y': 0, 'w': img.width, 'h': img.height};
      cells.add(cellInfo);

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

    var outputPath = '${transform.key}.json';
    if (_settings.outputDir != null)
      outputPath = p.url.join(_settings.outputDir, outputPath);

    transform.addOutput(new Asset.fromString(
        new AssetId(transform.package, outputPath), JSON.encode(atlasJson)));
    transform.addOutput(new Asset.fromBytes(
        new AssetId(transform.package,
            outputPath.replaceAll(_rgxJson, '.' + _settings.extension)),
        buf));
  }
}
