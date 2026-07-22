local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.Packages.TestEZ)

local results = TestEZ.TestBootstrap:run({ ServerScriptService.Tests })

assert(results.failureCount == 0, `TestEZ failed with {results.failureCount} failure(s)`)
print("[BalapKarung] Studio proof completed successfully")
