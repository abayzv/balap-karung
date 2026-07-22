local SackSizing = {}

function SackSizing.getSizeClass(sizeClasses, hipHeight)
	for _, sizeClass in sizeClasses do
		if not sizeClass.maximumHipHeight or hipHeight <= sizeClass.maximumHipHeight then
			return sizeClass
		end
	end
	error("Sack size classes membutuhkan preset fallback")
end

return SackSizing
