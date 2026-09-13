# Single pipe integration QA

Run from repository root after `godot4 --headless --audio-driver Dummy --path . --editor --quit`.

```
xvfb-run -a godot4 --audio-driver Dummy --rendering-method gl_compatibility --path . --resolution 430x932 -s qa/pipe_integration_v3_probe.gd
xvfb-run -a godot4 --audio-driver Dummy --rendering-method gl_compatibility --path . --resolution 430x932 -s qa/pipe_module_isolated_probe.gd
```

The committed baseline.gd.txt is the pre-integration source from f4241bd, not a dynamically changing HEAD. Rendering evidence is generated under qa/artifacts/pipe-integration-v3 and excluded from engine imports by .gdignore. Probes refuse to overwrite PNG evidence: on repeat runs archive generated PNGs yourself or use a separate evidence directory and copy the baseline fixture there. Do not remove the baseline or user-owned artifacts.

The probe checks exact pixel equality outside the single module, restoration of the original drawing path when disabled, start-camera visibility, near-layer parallax, zone hiding and a sampled primitive budget. The luminance-ratio check uses Godot get_luminance, not a calibrated WCAG/sRGB contrast calculation. It is an existing project regression threshold, not perceptual approval or a physical iPhone performance measurement. iPhone acceptance remains pending.
