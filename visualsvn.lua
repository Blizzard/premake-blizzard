---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

	local vstudio = premake.vstudio
	local sln2005  = vstudio.sln2005


	premake.override(sln2005, "premakeExtensibilityGlobals", function(base, wks)
		base(wks)

		local dir = wks.basedir
		local svnroot
		while not svnroot and (dir ~= '.') and (dir ~= '/') do
			if (os.isdir(path.join(dir, '.svn'))) then
				svnroot = dir
			end
			dir = path.getdirectory(dir)
		end

		if svnroot then
			printf("SVN Root found: %s", svnroot)
			local path = premake.workspace.getrelative(wks, svnroot);
			premake.w('VisualSVNWorkingCopyRoot = %s', path)
		end
	end)


