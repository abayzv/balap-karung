return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
	local SackSizing = require(ReplicatedStorage.Shared.SackSizing)

	describe("SackSizing", function()
		it("classifies the three inspected reference avatars by HipHeight", function()
			expect(SackSizing.getSizeClass(GameConfig.sack.sizeClasses, 1.773).name).to.equal(
				"Short"
			)
			expect(SackSizing.getSizeClass(GameConfig.sack.sizeClasses, 1.843).name).to.equal(
				"Standard"
			)
			expect(SackSizing.getSizeClass(GameConfig.sack.sizeClasses, 4.958).name).to.equal(
				"Tall"
			)
		end)

		it("returns the exact configured preset without body calculations", function()
			for index, hipHeight in { 1.773, 1.843, 4.958 } do
				local selected = SackSizing.getSizeClass(GameConfig.sack.sizeClasses, hipHeight)
				expect(selected.size).to.equal(GameConfig.sack.sizeClasses[index].size)
				expect(selected.mountOffset).to.equal(
					GameConfig.sack.sizeClasses[index].mountOffset
				)
			end
		end)
	end)
end
