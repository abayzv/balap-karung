$ErrorActionPreference = "Stop"

function Get-AftmanToolPath {
	param (
		[string] $Owner,
		[string] $Tool,
		[string] $Version,
		[string] $Executable
	)

	$toolPath = Join-Path $env:USERPROFILE ".aftman\tool-storage\$Owner\$Tool\$Version\$Executable"
	if (Test-Path $toolPath) {
		return $toolPath
	}

	return $Executable
}

$rojo = Get-AftmanToolPath "rojo-rbx" "rojo" "7.7.0-rc.1" "rojo.exe"
$runInRoblox = Get-AftmanToolPath "rojo-rbx" "run-in-roblox" "0.3.0" "run-in-roblox.exe"
$testPlace = "build/BalapKarungTests.rbxlx"

New-Item -ItemType Directory -Force build | Out-Null
& $rojo build test.project.json --output $testPlace
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& $runInRoblox --place $testPlace --script tests/StudioProof.server.luau
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
