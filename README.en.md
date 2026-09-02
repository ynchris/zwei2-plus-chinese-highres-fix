# Zwei II Plus Chinese Patch High-Resolution Fix

[简体中文说明](README.md)

Fixes the white 3D scene caused by the old Chinese executable when **Use Back Buffer / effect caching** is enabled above 2048 pixels in either dimension.

## What the fix changes

The Chinese executable rejects internal effect textures larger than 2048×2048 before calling Direct3D:

```text
00468E76  cmp width,  0x800
00468E84  cmp height, 0x800
```

The installer changes only those two limits from 2048 (`0x800`) to 4096 (`0x1000`). It also installs [d3d8to9 v1.15.1](https://github.com/crosire/d3d8to9), the D3D8-to-D3D9 translation layer used during testing.

It does **not** include or install game executables, Chinese text, restored event data, Japanese voices, or any other copyrighted game assets.

## Supported executable

The installer accepts only the known 2010 Chinese executable:

```text
Original SHA-256: F132FE28EC24393C5FD885BEA593F481B8F5D502C3D68ECAEF9C3A1F3ABFB6B2
Patched  SHA-256: C2668F2B546B8491C4AC32A5D2839CE2AD52F1506BB60A34F7BF8D982BA0C882
```

Unknown files are rejected before anything is modified.

## Installation

1. Install the Steam game.
2. Apply your legally obtained Chinese patch.
3. Apply any restored-event or Japanese-voice patches you own.
4. Run `Install.cmd` and select the game directory, or copy this package into the game directory and run it there.
5. Enable **Use Back Buffer** in the configuration program.

The installer patches both `ZWEI2P.exe` and `ZWEI2PDX9.exe`, creates `.highres-fix.backup` files, verifies the result, and refuses to overwrite an unrelated local `d3d8.dll`.

If an old Chinese patcher displays garbled text or fails in a path containing Chinese characters, temporarily install it from a short ASCII-only physical path.

## Uninstallation

Run `Uninstall.cmd`. It restores only verified backups and removes `d3d8.dll` only when this installer originally added it.

## Verified configuration

- Steam assets with the known 2010 Chinese executable
- 3840×2160 windowed rendering
- Use Back Buffer enabled (`USEBKB=1`)
- Internal 4096×4096 effect textures
- Stable 60 Present calls per second
- Chinese text and Japanese voice replacement
- NVIDIA GeForce RTX 2070 Max-Q, Windows 10

The restored hot-spring event file behavior was structurally inspected, but the event itself was not played during verification. Players with a suitable save are welcome to test the complete hot-spring sequence and report any event-trigger, text, animation, or stability results through GitHub Issues.

## Known behavior

- The tested executable renders at 60 FPS even on a 144 Hz desktop.
- 4K uses substantially more VRAM than 1080p.
- This package does not add arbitrary-resolution support above the 4096 internal texture limit.

## Author

ynchris（汉化老兵）

## Legal

The patching scripts are released under the MIT License. The bundled `d3d8.dll` is from d3d8to9 and is redistributed under its own permissive license; see `THIRD_PARTY_NOTICES.md`.
