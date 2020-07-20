

Push-Location $PSScriptRoot

$shader_name = $args[0]
glslc.exe -c "$shader_name.vert"
glslc.exe -c "$shader_name.frag"

Pop-Location
