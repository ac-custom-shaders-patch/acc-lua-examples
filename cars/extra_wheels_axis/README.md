# Extra Wheels Axis

https://github.com/ac-custom-shaders-patch/acc-lua-examples/assets/3996502/4f4f7619-c934-4ccc-92bc-c24a817848fb

Currently AC doesn’t allow to add a new axis, but with something like this it can at least be visualized a bit nicer than static wheels.

To add to config, copy the script to your `extension` folder and add to `ext_config.ini`:

```ini
[SCRIPT_...]
SCRIPT = extra_wheels_axis.lua
SKIP_FRAMES = 0           ; run script every frame (default value is 1, to run script once every two frames)
ACTIVE_FOR_UNFOCUSED = 1  ; active even if is not focused (be careful with this one!)
ACTIVE_FOR_LOD = B        ; active for LOD A and LOD B (number could be used here as well)
ACTIVE_FOR_NEAREST = 12   ; active for 12 nearest cars
```

You might also need to go through code and adapt coordinates and mesh names.
