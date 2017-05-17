---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---
local p = premake

p.api.register {
		name = 'prebakefiles',
		scope = 'project',
		kind = 'function'
	}

p.api.alias('prebakefiles', 'preBakeFiles')


p.override(p.oven, 'bakeFiles', function(base, prj)
	if prj.prebakefiles and type(prj.prebakefiles) == 'function' then
		prj.prebakefiles(prj)
	end

	return base(prj)
end)
