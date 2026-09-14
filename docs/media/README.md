# Demonstration media

- `demo-30s-1440p.mp4`: 30 seconds, 2560 × 1440, 30 fps, H.264, no audio. Recorded in Apple Silicon VMD 2.0b1 from source `4e2bb57`; build fingerprint `cbfd6196a68e8d99740538830bf681a7063b4520927ac0218343e42da9113304`.
- `demo-thumbnail.png`: actual dashboard and molecular display from the video.
- `protease-tachyon-hd.png`: 2560-pixel-wide raster preview of the exported annotated SVG. Its molecular image was rendered by VMD's TachyonInternal renderer with ambient occlusion and shadows. Nine unmasked protease windows cover frames 0–26 in three-frame windows; Viridis legend 0.06–1.22 Å. Labels are editable in the original local SVG.

The video shows the precomputed single-chain ubiquitin example in Turbo, in-place rotation and linked residue selection, a freshly calculated unmasked two-chain protease result in Viridis, the actual Figure/Save action, and the resulting PNG/SVG appearance. It cuts loading and rendering waits; it makes no calculation-runtime claim. All 900 encoded frames were decoded successfully and playback was reviewed in QuickTime. The later input-autopopulation change (`4eb669d`) is not shown.

Generated from the bundled fixtures; applicable source notices remain in THIRD_PARTY_NOTICES.md and fixtures/provenance.json. These images and recording are original project media. They do not include a VMD executable. Media verification is separate from final cross-platform artifact qualification.
