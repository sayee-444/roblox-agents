# PreToolUse guard for actions reserved for the developer.
# Exit code 2 blocks the tool call and shows the message to the agent.
# It catches mistakes; it is not a security boundary.

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$tool = [string]$payload.tool_name
$toolInput = $payload.tool_input

function Deny([string]$reason) {
    [Console]::Error.WriteLine("Blocked by roblox-world guard: $reason")
    exit 2
}

$publishReason = 'publishing to Roblox is reserved for the developer.'

if ($tool -eq 'Bash' -or $tool -eq 'PowerShell') {
    $command = [string]$toolInput.command

    foreach ($segment in ($command -split '&&|\|\||;|\||\r?\n')) {
        if ($segment -match '^\s*(\S*[\\/])?rojo(\.exe)?\s+(build|upload|syncback)\b') {
            Deny 'rewriting a place with Rojo can lose terrain. The developer runs these commands.'
        }
        if ($segment -match 'world\.js.*\bwipe\b.*--confirm') {
            # A second stop that does not depend on the model: Claude Code asks the developer itself.
            @{ hookSpecificOutput = @{
                hookEventName = 'PreToolUse'
                permissionDecision = 'ask'
                permissionDecisionReason = 'THIS DELETES ALL TERRAIN IN THE PLACE. Approve only if you confirmed it.'
            } } | ConvertTo-Json -Compress
            exit 0
        }
    }

    if ($command -match '/places/[^/\s]+/versions') {
        Deny $publishReason
    }
    if ($command -match 'assets/v1/assets/' -and $command -match 'assetType' -and $command -match '\bPlace\b') {
        Deny $publishReason
    }
}

if ($tool -eq 'mcp__Roblox_Studio__open_cloud_invoke') {
    $endpoint = [string]$toolInput.endpoint
    $body = [string]$toolInput.body
    if ($endpoint -match '/places/[^/]+/versions') {
        Deny $publishReason
    }
    if ($endpoint -match 'assets/v1/assets/' -and $body -match '\bPlace\b') {
        Deny $publishReason
    }
}

if ($tool -eq 'mcp__Roblox_Studio__execute_luau') {
    if ([string]$toolInput.code -match '\b(SavePlaceAsync|SavePlace|CreatePlaceAsync)\b') {
        Deny $publishReason
    }
    if ([string]$toolInput.code -match 'Terrain\s*:\s*Clear\s*\(' -or [string]$toolInput.code -match '\.wipe\s*\(') {
        Deny 'deleting all terrain goes through tools/world.js wipe, which warns the developer first.'
    }
}

exit 0
