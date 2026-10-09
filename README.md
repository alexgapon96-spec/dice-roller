# Dice Roller

A minimal D&D dice roller: tap the granite die on the purple felt to roll it.
d4, d6, d8, d10, d12 and d20, with advantage/disadvantage, crit glow and sounds.

Built with Flutter for Android, iOS and the web. The full behaviour is described
in [SPEC.md](SPEC.md).

## Run

```bash
flutter run
```

## Build

```bash
flutter build apk --release
flutter build web --release
```

Every push to `main` publishes the web version to GitHub Pages
(`.github/workflows/pages.yml`).

## Credits

- Dice sounds: cut from [Kenney "Casino Audio"](https://kenney.nl/assets/casino-audio) (CC0).
- Crit sounds: synthesized for this project.
- Font: Noto Serif Bold (SIL Open Font License 1.1, `assets/fonts/OFL.txt`).
