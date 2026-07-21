return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TrailCatalog = require(ReplicatedStorage.Shared.TrailCatalog)

	describe("TrailCatalog", function()
		it("has unique purchasable trail definitions", function()
			local seen = {}
			for _, trail in TrailCatalog.list do
				expect(seen[trail.id]).to.equal(nil)
				expect(trail.price >= 0).to.equal(true)
				expect(#trail.colors >= 2).to.equal(true)
				seen[trail.id] = true
			end
			expect(seen[TrailCatalog.defaultTrailId]).to.equal(true)
		end)
	end)
end
