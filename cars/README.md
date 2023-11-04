Some short snippers:

### Getting body roll

```lua
local bodyRoll = math.atan2(car.transform.side.y, #vec2(car.transform.side.x, car.transform.side.z)) * 180 / math.pi
```

### Using UVFlow shader for animating a belt linked to car RPM

```lua
local meshes = ac.findMeshes('MESH_NAME')
local texOffset = 0

function script.update(dt)
  texOffset = (texOffset + dt * car.rpm * 0.01) % 1
  meshes:setMaterialProperty('uvOffsetX', texOffset)
end
```

### Playing animation once when Extra A switch is pressed

```lua
local root = ac.findNodes('luaRoot:yes') 
local progress = -1

function script.update(dt)
  if car.extraA then
    -- Kicking off animation
    if progress == -1 then progress = 0 end
  elseif progress > 1 then
    -- Button is released and animation is done: revert back to initial state
    progress = -1
  end

  if progress >= 0 then
    -- If animation is playing, progress further
    progress = progress + dt
    root:setAnimation(__dirname..'/my_anim.ksanim', math.min(progress, 1))
  end
end
```

### Simplest custom needle

```lua
local needle = ac.findNodes('MY_ARROW')
local axis = vec3(0, 0, 1) -- doesn’t have to be here, but not recreating vectors each frame can help with performance

function script.update(dt)
  needle:setRotation(axis, math.rad(car.speedKmh)) -- simply use speed in km/h as degrees and convert to radians
end
```

Of course better needle needs to have boundaries, maybe some lag, all of that, but this is the simplest example.

### Simplest dashboard indicator

```lua
local indicator = ac.findMeshes('MY_INDICATOR')
local colorGlowing = rgb(10, 0, 0)

function script.update(dt)
  indicator:setMaterialProperty('ksEmissive', car.ballast > 0 and colorGlowing or rgb.colors.transparent)
end
```
