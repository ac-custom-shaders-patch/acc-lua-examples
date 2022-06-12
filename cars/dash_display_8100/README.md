# Dash Display 8100

<a href="https://gfycat.com/BronzeDeliriousKudu"><img src="https://thumbs.gfycat.com/BronzeDeliriousKudu-size_restricted.gif"></a>

Recreation of ST8100 Display System with 5 display layers, warnings, peak values, four working and animated switches, Predictive Lap Timer, Corner Speed feature, alarms and some settings.

To add to config, copy files to your `extension` folder and add to `ext_config.ini`:

```ini
[EXTRA_SWITCHES]
SWITCH_A = Switch display page
SWITCH_A_FLAGS = HOLD_MODE

[SCRIPTABLE_DISPLAY_...]
MESHES = st8100_display
RESOLUTION = 2048, 2048   ; texture resolution
DISPLAY_POS = 1846, 16    ; position of left top corner in your texture in pixels
DISPLAY_SIZE = 172, 1152  ; size of screen area in pixels
SKIP_FRAMES = 0           ; update every frame to get RPM needle to move smoothly. to make sure performance would be top notch, instead we’ll skip frames on Lua side
KEEP_BACKGROUND = 1       ; without clearing background: let’s do it from a script to make display look a bit laggy
SCRIPT = dash_display_8100.lua
```

It works the best if display on texture is horizontal, but if it’s turned, it’s also possible to set it to work, you’d just need to set the rotation as well. 

After adding those sections, go through integration settings in “dash_display_8100.lua” and adjust them for your car.
