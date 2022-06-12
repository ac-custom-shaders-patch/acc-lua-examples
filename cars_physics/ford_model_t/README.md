# Ford Model T control scheme

A silly experiment: this script would intercept car controls and swap them around recreating Ford Model T control scheme. Requires a steering wheel with gear shifting paddles, three pedals and H-shifter to work.

To add to a car, simply add `script.lua` to car’s data folder (it can be packed to `data.acd` as well).

### A brief explanation:

Left pedal acts like both gearbox and clutch, middle is for reverse and right pedal is for braking. H-shifter works like three-positional Ford Model T handbrake (start with it set to 4th gear, that would fully engage the handbrake). And throttle is controlled by gear paddles: they are in the right place and by the looks of original throttle level it’s not like it can be operated smoothly too:

![Image](https://files.acstuff.ru/shared/Rtwn/20220613-003105.png)

To start driving, move “handbrake” to a second position, vertically (in other words, select neutral gear with your H-shifter), add some throttle (using pedal app helps with it a lot) and press left pedal fully. Once enough speed is reached to shift to second gear, move “handbrake” to third position (fully away from you, aka select second gear) and fully depress left pedal. Good luck!
