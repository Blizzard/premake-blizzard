--
-- Add durango & orbis support to Visual Studio backend.
-- Copyright (c) 2015 Blizzard Entertainment
--

--
-- Non-overrides
--

local vstudio = premake.vstudio

if vstudio.vs2010_architectures ~= nil then
	vstudio.vs2010_architectures.orbis   = "Orbis"
	vstudio.vs2010_architectures.durango = "Durango"

	premake.api.addAllowed("system", "orbis")
	premake.api.addAllowed("system", "durango")
end

premake.api.register {
	name = "appxmanifest",
	scope = "project",
	kind = "path",
}

function path.isappxmanifest(fname)
	return path.hasextension(fname, '.appxmanifest')
end

-- PS4 configurations

premake.ORBIS       = "orbis"

filter { "system:Orbis", "kind:ConsoleApp or WindowedApp" }
	targetextension ".elf"

-- XboxOne configurations

premake.DURANGO     = "durango"

filter { "system:Durango", "kind:ConsoleApp or WindowedApp" }
	targetextension ".exe"

filter { "system:Durango", "kind:StaticLib" }
	targetprefix ""
	targetextension ".lib"

--
-- Overrides
--

premake.override(vstudio.vc2010, "wholeProgramOptimization", function (base, cfg)
	if cfg.platform ~= "orbis" then
		return base(cfg)
	end

	if cfg.flags.LinkTimeOptimization then
		-- Note: On the PS4, this is specified in the global flags
		vstudio.vc2010.element("LinkTimeOptimization", nil, "true")
	end
end)

premake.override(vstudio.vc2010, "optimization", function (base, cfg, condition)
	if cfg.platform ~= "orbis" then
		return base(cfg, condition)
	end

	local map = { Off="Level0", On="Level1", Debug="Level0", Full="Level2", Size="Levels", Speed="Level3" }
	local value = map[cfg.optimize]
	if levelValue or not condition then
		vstudio.vc2010.element('OptimizationLevel', condition, value or "Level0")
	end
	if cfg.flags.LinkTimeOptimization then
		-- PS4 link time optimization is specified in the CLCompile flags
		vstudio.vc2010.element("LinkTimeOptimization", nil, "true")
	end
end)


premake.override(vstudio.vc2010, "treatWarningAsError", function (base, cfg)
	if cfg.platform ~= "orbis" then
		return base(cfg)
	end

	-- PS4 uses a different tag for treating warnings as errors
	if cfg.flags.FatalLinkWarnings and cfg.warnings ~= "Off" then
		vstudio.vc2010.element("WarningsAsErrors", nil, "true")
	end
end)

premake.override(vstudio.vc2010, "debuggerFlavor", function (base, cfg)
	if cfg.platform ~= "orbis" then
		return base(cfg)
	end

	-- PS4 does not set this at all.
end)


function addappxmanifest(prj)
	-- Ensure proper extension of .appxmanifest file
	if prj.appxmanifest == nil or not path.isappxmanifest(prj.appxmanifest) then
		return
	end

	premake.push('<ItemGroup>')
	premake.push('<AppxManifest Include="%s">', premake.project.getrelative(prj, prj.appxmanifest))
	premake.x('<Filter>Xbox</Filter>')
	premake.pop('</AppxManifest>')
	premake.pop('</ItemGroup>')
end


premake.override(vstudio.vc2010.elements, "project", function(base, prj)
	local calls = base(prj)
	-- AppXManifest is only for Xbox One
	if table.contains(prj.platforms, 'durango') then
		table.insert(calls, addappxmanifest)
	end
	return calls
end)

function xdkConfig(prj)
	vstudio.vc2010.element("DefaultLanguage", nil, "en-US")
	vstudio.vc2010.element("ApplicationEnvironment", nil, "title")
	vstudio.vc2010.element("TargetRuntime", nil, "Native")
end


premake.override(vstudio.vc2010.elements, "globals", function(base, prj)
	local calls = base(prj)
	-- XDK Configuration is only for XB1
	if table.contains(prj.platforms, 'durango') then
		table.insert(calls, xdkConfig)
	end
	return calls
end)

function xdkProperties(cfg)
	vstudio.vc2010.element("ReferencePath", nil, "$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)")
	vstudio.vc2010.element("LibraryWPath", nil, "$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)")
end

premake.override(vstudio.vc2010.elements, "outputProperties", function(base, cfg)
	local calls = base(cfg)
	-- XDK Properties are only for XB1
	if cfg.platform == 'durango' then
		table.insert(calls, xdkProperties)
	end
	return calls
end)

premake.override(vstudio.vc2010, "libraryPath", function(base, cfg)
	local dirs = vstudio.path(cfg, cfg.syslibdirs)
	if cfg.platform == 'durango' then
		table.insert(dirs, '$(Console_SdkLibPath)')
	end
	if #dirs > 0 then
		vstudio.vc2010.element("LibraryPath", nil, "%s;$(LibraryPath)", table.concat(dirs, ";"))
	end
end)

premake.override(vstudio.vc2010, "includePath", function(base, cfg)
	local dirs = vstudio.path(cfg, cfg.sysincludedirs)
	if cfg.platform == 'durango' then
		table.insert(dirs, '$(Console_SdkIncludeRoot)')
	end
	if #dirs > 0 then
		vstudio.vc2010.element("IncludePath", nil, "%s;$(IncludePath)", table.concat(dirs, ";"))
	end
end)

premake.override(vstudio.vc2010, "executablePath", function(base, cfg)
	local dirs = vstudio.path(cfg, cfg.bindirs)
	if cfg.platform == 'durango' then
		table.insert(dirs, '$(Console_SdkRoot)bin;$(VCInstallDir)bin\\x86_amd64')
	end
	if #dirs > 0 then
		vstudio.vc2010.element("ExecutablePath", nil, "%s;$(ExecutablePath)", table.concat(dirs, ";"))
	end
end)

function generateDebugInformation(cfg)
	vstudio.vc2010.element("GenerateDebugInformation", nil, tostring(cfg.flags.Symbols ~= nil))
end

function fastMath(cfg)
	vstudio.vc2010.element("FastMath", nil, tostring(premake.config.isOptimizedBuild(cfg)))
end

function winrt(cfg)
	vstudio.vc2010.element("CompileAsWinRT", nil, 'true')
end

function deploy0(cfg, context)
	if not context.excluded and (context.prjCfg.kind == premake.CONSOLEAPP or context.prjCfg.kind == premake.WINDOWEDAPP) then
		premake.x('{%s}.%s.Deploy.0 = %s|%s', context.prj.uuid, context.descriptor, context.platform, context.architecture)
	end
end

premake.override(vstudio.vc2010.elements, "clCompile", function(base, cfg)
	local calls = base(cfg)
	-- PS4 has GenerateDebugInformation and FastMath
	if cfg.platform == 'orbis' then
		table.insert(calls, generateDebugInformation)
		table.insert(calls, fastMath)
	-- XB1 apps need to have CompileAsWinRT
	elseif cfg.platform == 'durango' and
		(cfg.kind == premake.CONSOLEAPP or cfg.kind == premake.WINDOWEDAPP) then
		cfg.flags.NoMinimalRebuild = true
		table.insert(calls, winrt)
	end
	return calls
end)

premake.override(vstudio.vc2010.elements, "link", function(base, cfg, explicit)
	local calls = base(cfg, explicit)
	-- PS4 has GenerateDebugInformation during linking too
	if cfg.platform == 'orbis' then
		table.insert(calls, generateDebugInformation)
	end
	return calls
end)

premake.override(vstudio.sln2005.elements, "projectConfigurationPlatforms", function(base, cfg, context)
	local calls = base(cfg, context)
	-- XB1 - Enable "Deploy" in the configuration manager for executable targets
	if cfg.platform == "durango" then
		table.insert(calls, deploy0)
	end
	return calls
end)
