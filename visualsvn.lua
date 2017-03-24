---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

	local vstudio = premake.vstudio
	local sln2005  = vstudio.sln2005

	local svndirs = { }

	premake.override(sln2005, "premakeExtensibilityGlobals", function(base, wks)
		base(wks)

		local dir = wks.basedir
		local svnroot = svndirs[ wks.basedir ]
		-- cache lookups based on working dir, so we dont output 'SVN Root ...' for each
		-- workspace we generate
		if not svnroot then
			while not svnroot and (dir ~= '.') and (dir ~= '/') do
				if (os.isdir(path.join(dir, '.svn'))) then
					svnroot = dir
				end
				dir = path.getdirectory(dir)
			end
			svndirs[ wks.basedir ] = svnroot
			if svnroot then
				printf("SVN Root found: %s", svnroot)
			end
		end
		if svnroot then
			local path = premake.workspace.getrelative(wks, svnroot);
			premake.w('VisualSVNWorkingCopyRoot = %s', path)
		end
	end)


