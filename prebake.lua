---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

premake.api.register {
		name = 'prebakefiles',
		scope = 'project',
		kind = 'function'
	}

premake.api.alias('prebakefiles', 'preBakeFiles')


premake.override(premake.oven, 'bakeFiles', function(base, prj)
	if prj.prebakefiles and type(prj.prebakefiles) == 'function' then
		prj.prebakefiles(prj)
	end

	return base(prj)
end)
