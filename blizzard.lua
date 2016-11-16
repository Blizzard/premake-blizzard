---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

	if not premake.modules.blizzard then
		premake.modules.blizzard = {}
		local blizzard = premake.modules.blizzard

		verbosef('Loading blizzard module...')

--		if http and not _OPTIONS['no-http'] then
--			local content, result_str, result_code = http.get('http://***REMOVED***/premakeversion')
--			if content then
--				local runningVersion = '"' .. _PREMAKE_VERSION .. '"'
--				if content ~= runningVersion then
--					premake.warn("Version %s of premake is the latest available, you are running %s.", content, runningVersion)
--				end
--			end
--		end

		include('util.lua')
		include('package.lua')
		include('packageman.lua')
		include('cache.lua')
		include('consoles.lua')
		include('context.lua')
		include('prebake.lua')
		include('unity.lua')
		include('vpaths.lua')
		include('json.lua')
		include('visualsvn.lua')
		include('export.lua')
	end

	return premake.modules.blizzard
