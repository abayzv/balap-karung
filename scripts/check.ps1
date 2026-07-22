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

$stylua = Get-AftmanToolPath "JohnnyMorganz" "StyLua" "2.1.0" "StyLua.exe"
$rojo = Get-AftmanToolPath "rojo-rbx" "rojo" "7.7.0-rc.1" "rojo.exe"

& $stylua --check src tests
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& $rojo sourcemap default.project.json --output sourcemap.json
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
