--!strict
--!optimize 2
--[[
vLuau - vLua but supports Luau too!
Original by kosukeReboyX (GitHub: kosuke14)

LuauCeption by RadiatedExodus (GitHub: RadiatedExodus/LuauCeption)
Fiu by rce-incorporated (GitHub: rce-incorporated/Fiu)

Rewrite by littleBitsman

(yes this exists on GitHub already, but I didn't like how the main vLuau was written so I made this!)

Licensed under the MIT License.
]]

--[=[
	@class Main
	
	Provides Luau compilation and execution methods.
	
	Internally uses [LuauCeption](https://github.com/RadiatedExodus/LuauCeption) 
	for compiling code and [Fiu](https://github.com/rce-incorporated/Fiu) for 
	the Luau VM.

	Calling the module itself is an alias for `vLuau.execute`.
]=]
local vLuau = {}

local DEPENDENCIES = {"getenv", "LuauCeption", "Fiu"}
for _, d in DEPENDENCIES do
	script:WaitForChild(d)
end

local getenv = require("@self/getenv") -- get around deoptimization?
local Compiler = require("@self/LuauCeption")
local VM = require("@self/Fiu")

function vLuau.isValidBytecode(bytecode: buffer | string): boolean
	local buf
	if typeof(bytecode) == "string" then
		buf = buffer.fromstring(bytecode)
	elseif typeof(bytecode) == "buffer" then
		buf = bytecode
	else
		return false
	end
	
	if buffer.len(buf) == 0 then
		return false
	end
	
	local Version = buffer.readu8(buf, 0)
	if Version < 3 or Version > 6 then
		return false
	end
	
	return true
end

--[=[
	@within Main
	@type CompilationOptions { optLevel?: number, debugLevel?: number, typeInfoLevel?: number, coverageLevel?: number }

	Options for compiling Luau source code.

	Default compilation options from LuauCeption:
	| Name | Default Value |
	| ---- | ------------- |
	| optLevel 		| 1 |
	| debugLevel 	| 1 |
	| typeInfoLevel | 0 |
	| coverageLevel | 0 |
]=]
type CompilationOptions = {
	optLevel: number?,
	debugLevel: number?,
	typeInfoLevel: number?,
	coverageLevel: number?
}

--[=[
	@within Main
	@private
	@type VMSettings { [string]: any }

	Options for executing Luau bytecode. 

	Read `Fiu.luau` for a list of available options.

	You will likely not need to change any of these, hence
	the options are not documented here.
]=]
type VMSettings = VM.Settings

function compileOptionsToArgs(opts: CompilationOptions?): ...number?
	if not opts then return end
	
	return opts.optLevel, opts.debugLevel, opts.typeInfoLevel, opts.coverageLevel
end

--[=[
	@within Main
	@function compile

	Compiles Luau source code into bytecode.

	See [`CompilationOptions`](#CompilationOptions) for default compilation options.

	@param source string -- The Luau source code to compile.
	@param chunkname string? -- The name of the chunk (for error messages). Defaults to the source code if not provided.
	@param options CompilationOptions? -- Options for compiling the source code.
	@return buffer -- The compiled Luau bytecode.
]=]
function vLuau.compile(source: string, chunkname: string?, options: CompilationOptions?)
	local bytecode: buffer, _size: number = Compiler.luau_compile(source, compileOptionsToArgs(options))
	
	if buffer.readu8(bytecode, 0) == 0 then -- Error occured
		local err = buffer.readstring(bytecode, 1, buffer.len(bytecode) - 1)
		error(`[string "{chunkname or source}"]{err}`, 0)
	end
	
	return bytecode
end

--[=[
	@within Main
	@function loadBytecode

	Loads Luau bytecode as a callable function.

	Returns the loaded chunk as a function, and a stop function
	that guarantees execution of the chunk will halt when called.

	@param bytecode buffer | string -- The Luau bytecode to load.
	@param chunkname string? -- The name of the chunk (for error messages). Defaults to `(main)` if not provided.
	@param env { [string]: any }? -- The environment to execute the code in. Defaults to the caller's environment.
	@param executionOptions VMSettings? -- Options for executing the bytecode. You will likely not need to use this.
	@return ((...any) -> ...any, () -> ()) -- The loaded chunk and the stop function.
]=]
function vLuau.loadBytecode(bytecode: buffer | string, chunkname: string?, env: { [string]: any }?, executionOptions: VMSettings?): ((...any) -> ...any, () -> ())
	local buf
	if typeof(bytecode) == "string" then
		buf = buffer.fromstring(bytecode)
	elseif typeof(bytecode) == "buffer" then
		buf = bytecode
	else
		error(`invalid argument #1 to 'load' (buffer or string expected, got {typeof(bytecode)}`, 0)
	end
	
	local settings = VM.luau_newsettings()
	if typeof(executionOptions) == "table" then
		for k, v in executionOptions do
			settings[k] = v
		end
	end

	settings.chunkname = chunkname or settings.chunkname
	settings.fiuErrorFormat = false
	settings.allowProxyErrors = false
	settings.errorHandling = true

	return VM.luau_load(buf, env or getenv(2), settings)
end

--[=[
	@within Main
	@function execute

	Executes Luau bytecode or source code.

	If the `source` is a string, it will be compiled first using
	the compilation options, if provided.

	See [`CompilationOptions`](#CompilationOptions) for default compilation options.

	@param source buffer | string -- The Luau source code or bytecode to execute.
	@param chunkname string? -- The name of the chunk (for error messages). Defaults to `(main)` if not provided.
	@param env { [string]: any }? -- The environment to execute the code in. Defaults to the caller's environment.
	@param compilationOptions CompilationOptions? -- Options for compiling the source code (if `source` is a string).
	@param executionOptions VMSettings? -- Options for executing the bytecode. You will likely not need to use this.
]=]
function vLuau.execute(source: buffer | string, chunkname: string?, env: { [string]: any }?, compilationOptions: CompilationOptions?, executionOptions: VMSettings)
	local bytecode
	if typeof(source) == "buffer" then
		bytecode = source
	elseif typeof(source) == "string" then
		bytecode = vLuau.compile(source, chunkname, compilationOptions)
	else
		error(`invalid argument #1 to 'execute' (buffer or string expected, got {typeof(source)}`, 0)
	end
	
	vLuau.loadBytecode(bytecode, chunkname, env, executionOptions)()
end

--[=[
	@within Main
	@readonly 
	@private
	@prop Compiler any

	Reference to the Luau compiler module, [LuauCeption](https://github.com/RadiatedExodus/LuauCeption).

	Unless you plan on doing something very specific, you should not need to use this.
]=]
vLuau.Compiler = Compiler

--[=[
	@within Main
	@readonly
	@private
	@prop VM any

	Reference to the Luau VM module, [Fiu](https://github.com/rce-incorporated/Fiu).

	Unless you plan on doing something very specific, you should not need to use this.
]=]
vLuau.VM = VM

return setmetatable(vLuau, {
	__newindex = function()
		error("attempt to modify read-only table", 0)
	end,
	__call = function(self, source, chunkname, env, compOpts, execSettings)
		vLuau.execute(source, chunkname, env or getenv(2), compOpts, execSettings)
	end,
	__metatable = "The metatable is locked"
})
