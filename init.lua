local separator = package.config:sub(1, 1)

-- todo handle windows '!' (path from .exe)
local function collapsePath(path)
  while path:find(separator .. '%.%.' .. separator) do
    -- turn '/a/../b/c' into '/b/c' 
    path = path:gsub(
      separator .. '[^' .. separator .. ']+' .. separator .. '%.%.' .. separator,
      separator,
      1
    )
  end

  while path:find(separator .. separator) do
    -- turn 'a//b' into 'a/b'
    path = path:gsub(separator .. separator, separator)
  end

  -- turn 'a/./b' into 'a/b'
  path = path:gsub(separator .. '%.' .. separator, separator)

  return path
end

local function exists(filename)
  local file = io.open(filename, 'r')
  if file then
    file:close()
    return true
  else
    return false
  end
end

local function resolveCurrentDirectory(depth)
  local source = debug.getinfo(depth, 'S').source

  local currentDir = (os.getenv('PWD') or os.getenv('CD')) .. separator

  if source == '=stdin' then
    print('relative_require: Requiring from interpreter relative to current working directory')
  elseif source == '=[C]' then
    return nil, 'Cannot require relative from C file'
  else
    local sourceLocation = source:match('@(.*'..separator..').*%.lua')
    -- only works for unix...
    if sourceLocation then
      if sourceLocation:find('^'..separator) and exists(sourceLocation) then
        currentDir = sourceLocation
      else
        currentDir = currentDir .. sourceLocation
      end
    end
  end

  return currentDir, nil
end

table.insert(package.searchers, 2, function (relativeModule)
  local currentDir, err = resolveCurrentDirectory(4)
  if err then
    return err
  end

  local modulePath = relativeModule:match("^(.+)"..separator..".-$") or ''
  local moduleName = relativeModule:match(separator.."?([^"..separator.."]+)$") or ''

  -- use collapse path to identify the canonical path for the module
  local moduleSearchPath = collapsePath(currentDir .. modulePath .. separator .. '?.lua') .. ';' ..
                           collapsePath(currentDir .. modulePath .. separator .. '?' .. separator .. 'init.lua')

  local module, err = package.searchpath(moduleName, moduleSearchPath)
  if module then
    return function ()
      -- Each invocation of require for a relative may have a unique
      -- name. The module will be instantiated for every unique name.
      -- We create a canonical name for the module 'moduleName' and
      -- store the loaded module into package.loaded manually.
      --
      -- We can then check if the cannonical moduleName is loaded and
      -- return it if so.
      if not package.loaded[module] then
        -- create a new env that holds values just for that file that
        -- transparently puches reads and changes to the global env
        -- just like in a normal require
        local env = setmetatable({ FILE = module }, { __index = _G, __newindex = _G })
        local loader, msg = loadfile(module, 'tb', env)
        if not loader then return msg end

        package.loaded[module] = loader()
      end
      
      return package.loaded[module]
    end
  else
    return err
  end
end)

return resolveCurrentDirectory
