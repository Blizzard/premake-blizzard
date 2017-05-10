---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---
	local p = premake

	if not p.modules.blizzard then
		p.modules.blizzard = {}
		local blizzard = p.modules.blizzard

		verbosef('Loading blizzard module...')

		include('util.lua')
		include('package.lua')
		include('packageman.lua')
		include('cache.lua')
		include('context.lua')
		include('prebake.lua')
		include('unity.lua')
		include('vpaths.lua')
		include('visualsvn.lua')
		include('export.lua')

		-- provide overrides here.
		p.api.addAllowed('system', {'centos6', 'centos7', 'ubuntu'})

		p.override(os, "getSystemTags", function (base, name)
			local tags =
			{
				["centos6"] = { "centos6", "linux", "posix" },
				["centos7"] = { "centos7", "linux", "posix" },
				["ubuntu"]  = { "ubuntu",  "linux", "posix" },
			}
			return tags[name] or base(name)
		end)

	end

	return p.modules.blizzard
