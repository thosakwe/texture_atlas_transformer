# texture_atlas_transformer
A transformer to build JSON Atlas files for inclusion in games.

Example `pubspec.yaml`:

```yaml
transformers:
  - texture_atlas_transformer:
      output_dir: web/assets/textures
      scale: 0.125
      files:
        flying:
          frames:
            - "web/assets/green_flapper/Transparent PNG/flying/*.png"
```

## Options
* `output_dir`: Output directory to generate files into.
* `scale`: Either a `num` or a `Map` (ex. `{'x': 0.5, 'y': 1.0}`).
This ratio is applied to every frame.
* `resize`: Same as `scale`; however, each frame is resized to the exact size,
instead of being scaled.
* `files`: A `Map` of `String`s to atlas definitions.
* `extension`: The output image extension. Default: `png`. Supports `jpg`, `jpeg`, `gif`, and `tga`.

### Atlas Definitions
* `frames`: A `List` of Strings representing files to be combined. Supports globbing.
* `animations`: A `Map` of `String`s to animations.
