local separator = package.config:sub(1, 1)

-- todo handle windows '!' (path from .exe)
local function collapsePath(path)
  -- turn 'a/./b' into 'a/b'
  path = path:gsub(separator .. '.' .. separator, separator)

  while path:find(separator .. '..' .. separator) do
    -- turn '/a/../b/c' into '/b/c' 
    path = path:gsub(
      separator .. '[^' .. separator .. ']-' .. separator .. '..' .. separator,
      separator
    )
    -- turn 'a/./b' into 'a/b'
  end

  return path
end

table.insert(package.searchers, 2, function (relativeModule)
  local sourceLocation = debug.getinfo(3, 'S').source

  local currentDir = ''
  if sourceLocation == '=stdin' then
    print('relative_require: Requiring from interpreter relative to current working directory')
    currentDir = (os.getenv('PWD') or os.getenv('CD')) .. separator
  elseif sourceLocation == '=[C]' then
    return 'Cannot require relative from C file'
  else
    currentDir = sourceLocation:match("@(.*"..separator..").*.lua") or ''
  end

  local modulePath = relativeModule:match("^(.+)"..separator..".-$") or ''
  local moduleName = relativeModule:match(separator.."?([^"..separator.."]+)$") or ''

  -- use collapse path to identify the canonical path for the module
  local moduleSearchPath = collapsePath(currentDir .. modulePath .. separator .. '?.lua')

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
        package.loaded[module] = loadfile(module)()
      end
      
      return package.loaded[moduleName]
    end
  else
    return err
  end
end)
