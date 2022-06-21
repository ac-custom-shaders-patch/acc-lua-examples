Getting body roll:

```lua
local bodyRoll = math.atan2(car.transform.side.y, #vec2(car.transform.side.x, car.transform.side.z)) * 180 / math.pi
```