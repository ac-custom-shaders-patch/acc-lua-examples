loadstring(const((function ()
  local files = table.map(ac.getCarDataFiles(car.index), function (v)
    return v:startsWith('_ext_') and v:endsWith('.lua') and v:sub(1, #v - 4) or nil
  end)
  local s, u, t = {}, {}, {}
  for i, v in ipairs(files) do
    local r = require(v)
    if r then
      if r == true then
        if type(_G.update) == 'function' then
          _G['__mcache%d' % i] = _G.update
          s[#s + 1] = 'require(%s)' % stringify(v)
          s[#s + 1] = 'local m%d = _G.__mcache%d or _G.update' % {i, i}
          s[#s + 1] = '_G.update = {}'
          u[#u + 1] = '  m%d(dt)' % i
          _G.update = nil
        elseif type(_G.script) == 'table' then
          _G['__mcache%d' % i] = _G.script
          s[#s + 1] = 'require(%s)' % stringify(v)
          if type(_G.script) == 'table' then
            if _G.script.reset then 
              s[#s + 1] = 'local r%d = (_G.__mcache%d or _G.script).reset' % {i, i}
              t[#t + 1] = '  r%d()' % i
            end
            if _G.script.update then
              s[#s + 1] = 'local m%d = (_G.__mcache%d or _G.script).update' % {i, i}
              u[#u + 1] = '  m%d(dt)' % i
            end
          end
          s[#s + 1] = '_G.script = {}'
          _G.script = {}
        end
      else
        s[#s + 1] = 'local m%d = require(%s)' % {i, stringify(v)}
        if type(r) == 'function' then
          u[#u + 1] = '  m%d(dt)' % i
        elseif type(r) == 'table' then
          if r.reset then 
            s[#s + 1] = 'local r%d = m%d.reset' % {i, i}
            t[#t + 1] = '  r%d()' % i
          end
          if r.update then
            s[#s + 1] = 'm%d = m%d.update' % {i, i}
            u[#u + 1] = '  m%d(dt)' % i
          end
        end
      end
    end
  end
  table.clear(script)
  if #u > 0 then
    s[#s + 1] = 'function script.update(dt)'
    for _, v in ipairs(u) do s[#s + 1] = v end
    s[#s + 1] = 'end'
  end
  if #t > 0 then
    s[#s + 1] = 'function script.reset()'
    for _, v in ipairs(t) do s[#s + 1] = v end
    s[#s + 1] = 'end'
  end  
  return table.concat(s, '\n')
end)()))()