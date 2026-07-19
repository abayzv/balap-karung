local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.Packages.TestEZ)

local results = TestEZ.TestBootstrap:run({ ServerScriptService.Tests })

if results.failureCount > 0 then
	error(`TestEZ failed with {results.failureCount} failure(s)`)
end
