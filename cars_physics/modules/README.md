# Physics Lua modules handler

A core script allowing to use multiple physics scripts at once without conflicts.

### A brief explanation:

When dealing with physics scripts, it might be reasonable to split them into multiple files. For example, imagine if you got something like a custom braking system or a custom turbo system, all configurable with INI files so it’s basically a few bits of code that never change and you keep copying from car to car depending on which car needs what.

Well, with this script it might be as simple as dropping a new Lua file in car data folder. Just put use this script as “script.lua” and add other files next to it with “script_” prefix, like “script_turbo.lua”, “script_rocket_engine.lua”, etc. This script will iterate over any car data file with fitting prefix, load them all and just call in the alphabetical order. Modules can simply return a function that will be called in each `update()` step, return a `{update: fun(dt: number), reset: fun()}` table or better yet, could be written just as regular physics scripts with `script.update()` and optional `script.reset()`, that would also work (but might make VSCode Lua plugin concerned with single function defined multiple times).

Actual logic of the script is a bit of a mess, but it’s only because it tries to make modular system perform just as fast as the basic putting everything in `script.update()` would be. And thanks to `const()` magic it won’t even have to iterate over data files each time, results will be cached and reused until data changes.
