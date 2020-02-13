package = "relative_require"
version = "dev-1"
source = {
   url = "git@github.com:jasper-lyons/relative_require.git"
}
description = {
   homepage = "https://github.com/jasper-lyons/relative_require",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {
      relative_require = "init.lua"
   }
}
