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