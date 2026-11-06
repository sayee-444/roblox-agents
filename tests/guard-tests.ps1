# Runs the guard against known tool calls. Exit code 0 means every case behaved as expected.
$guard = Join-Path $PSScriptRoot '..\plugins\roblox-world\hooks\guard.ps1'
$cases = @(
  @{ name='chained rojo upload'; want=2; json='{"tool_name":"Bash","tool_input":{"command":"cd x && rojo upload"}}' },
  @{ name='rojo build';          want=2; json='{"tool_name":"PowerShell","tool_input":{"command":"rojo build -o x.rbxl"}}' },
  @{ name='rojo serve';          want=0; json='{"tool_name":"Bash","tool_input":{"command":"rojo serve"}}' },
  @{ name='message mentions rojo build'; want=0; json='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"docs: explain why rojo build is avoided\""}}' },
  @{ name='curl publish';        want=2; json='{"tool_name":"Bash","tool_input":{"command":"curl -X POST https://apis.roblox.com/universes/v1/1/places/2/versions"}}' },
  @{ name='curl asset place';    want=2; json='{"tool_name":"Bash","tool_input":{"command":"curl -X PATCH https://apis.roblox.com/assets/v1/assets/5 -d assetType=Place"}}' },
  @{ name='open cloud publish';  want=2; json='{"tool_name":"mcp__Roblox_Studio__open_cloud_invoke","tool_input":{"endpoint":"/universes/v1/1/places/2/versions?versionType=Published"}}' },
  @{ name='open cloud read';     want=0; json='{"tool_name":"mcp__Roblox_Studio__open_cloud_invoke","tool_input":{"endpoint":"/cloud/v2/universes/1"}}' },
  @{ name='luau SavePlace';      want=2; json='{"tool_name":"mcp__Roblox_Studio__execute_luau","tool_input":{"code":"game:GetService(\"AssetService\"):SavePlaceAsync()"}}' },
  @{ name='luau harmless';       want=0; json='{"tool_name":"mcp__Roblox_Studio__execute_luau","tool_input":{"code":"return workspace.Terrain.MaxExtents"}}' }
)
$failures = 0
foreach ($case in $cases) {
  $case.json | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard 2>$null | Out-Null
  $got = $LASTEXITCODE
  if ($got -ne $case.want) { $failures++; "FAIL $($case.name): want $($case.want), got $got" } else { "ok   $($case.name)" }
}
"failures: $failures"
exit $failures
