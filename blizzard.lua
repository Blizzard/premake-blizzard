---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---
	local p = premake

	if not p.modules.blizzard then
		p.modules.blizzard = {}
		local blizzard = p.modules.blizzard

		verbosef('Loading blizzard module...')

		include('export.lua')
		include('installer.lua')
		include('prebake.lua')
		include('telemetry.lua')
		include('unity.lua')
		include('visualsvn.lua')
		include('vpaths.lua')

		-- Add additional systems and it's tags.
		p.api.addAllowed('system', {'centos6', 'centos7', 'ubuntu'})

		-- override linux,macosx, windows and add tags for centos6,7 and ubuntu.
		os.systemTags["linux"]    = { "linux",             "posix", "desktop" }
		os.systemTags["macosx"]   = { "macosx",  "darwin", "posix", "desktop" }
		os.systemTags["windows"]  = { "windows", "win32"          , "desktop" }
		os.systemTags["centos6"]  = { "centos6", "linux",  "posix", "desktop" }
		os.systemTags["centos7"]  = { "centos7", "linux",  "posix", "desktop" }
		os.systemTags["ubuntu"]   = { "ubuntu",  "linux",  "posix", "desktop" }

		-- SC2/Heroes and some package need the Unicode and MacOSXBundle flag for a while longer.
		p.api.addAllowed('flags', {'Unicode', 'MacOSXBundle'})

		p.api.deprecateValue("flags", "Unicode", 'Use `characterset "Unicode"` instead',
			function(value)
				characterset "Unicode"
			end,
			function(value)
				characterset "Default"
			end
		)

		p.api.deprecateValue("flags", "MacOSXBundle", 'Use `sharedlibtype "OSXBundle"` instead',
			function(value)
				sharedlibtype "OSXBundle"
			end,
			function(value)
				sharedlibtype "Default"
			end
		)

		-- SC2/Heroes and some packages need the "buildoutputsasinputs" api still.
		p.api.register {
			name = "buildoutputsasinputs",
			scope = "config",
			kind = "boolean"
		}

		p.api.deprecateField("buildoutputsasinputs", nil, function(value)
			p.warn("buildoutputsasinputs has been deprecated, please use 'compilebuildoutputs' instead.")
			compilebuildoutputs(value)
		end)
	end

	return p.modules.blizzard
