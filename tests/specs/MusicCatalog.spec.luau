return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local MusicCatalog = require(ReplicatedStorage.Shared.MusicCatalog)

	describe("MusicCatalog", function()
		it("defines unique playable tracks", function()
			local ids = {}
			for _, track in MusicCatalog do
				expect(ids[track.id]).to.equal(nil)
				expect(type(track.soundId)).to.equal("number")
				expect(track.soundId > 0).to.equal(true)
				expect(typeof(track.accent)).to.equal("Color3")
				ids[track.id] = true
			end
			expect(#MusicCatalog > 1).to.equal(true)
		end)
	end)
end
