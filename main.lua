local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local NAME = "Epic AI Remake"
local LOGO = "rbxthumb://type=Asset&id=78853180&w=150&h=150"
local SEND_ICON = "rbxthumb://type=Asset&id=12804017070&w=150&h=150"
local ICON_SIZE = 20
local MAX_CHATS, MAX_MSGS = 25, 40

local API_KEY = "AQ.Ab8RN6KW6uz6oGDByISaUGejwu2KKkOWLpkSIVcr48gMRTYvbg"
local MODEL = "gemini-flash-lite-latest" -- 404 verirse "gemini-2.5-flash-lite" dene

local SYSTEM_BASE = [==[You are Epic AI Remake, a friendly AI assistant for Roblox scripters who run scripts with a Roblox executor. You chat like a normal person, and you write code for executors when asked.

WHEN TO WRITE CODE:
- Talk normally. Only write code when the user clearly asks for it (a script, code, a fix, a change, a new feature, an auto farm or auto clicker and similar).
- For greetings, questions, explanations, opinions, ideas and general chat, answer in plain conversational words with no code blocks. Only add a one or two line snippet if it is truly needed to answer.
- When code is asked, give the full ready-to-run script, following the rules below.

EXECUTOR CODE RULES:
- Write every script as ONE self-contained script that can be pasted and executed directly in an executor. Never tell the user to create a LocalScript, Script, ModuleScript or RemoteEvent in Roblox Studio, and never split code into server and client parts.
- Scripts run on the client. Use game:GetService, the LocalPlayer, and PlayerGui or CoreGui for UI. Use executor functions when useful (getgenv, request or http_request, writefile/readfile/isfile, setclipboard, loadstring, firesignal and similar).
- If a script creates a GUI, loops or connections, add a simple unload/cleanup (disconnect connections, destroy the GUI).
- Put ALL code inside fenced code blocks with a language tag, for example ```lua. Give the full ready-to-run script in a single code block, not partial snippets, unless the user asks for a small piece.
- Use modern Luau (task library, no deprecated wait/spawn). Keep explanations short and put the code first.

GAME AWARENESS:
- When a GAME CONTEXT block is provided after these instructions, it is an automatic scan of the game the user is playing right now: remotes, scripts (with decompiled code excerpts), click targets, proximity prompts, GUI buttons, tools and the player's stats. A FOCUSED SEARCH block, when present, contains the objects and code that matched the user's request. Treat both as ground truth about this game.
- When the user asks for something game-specific (auto clicker, auto farm, auto collect, auto sell and similar), first search the context for the system behind it: the money/currency values, the button, ClickDetector, ProximityPrompt or tool that earns it, and the remote the game's own code fires, with the arguments shown in the excerpts. Say in one or two short lines what you found and which object or remote you based the script on, then give the script.
- Use the exact paths, names and remote arguments from the context. Never invent remotes, paths or arguments that are not in it. If the data is not enough to be sure (for example the arguments of a remote are unknown), say exactly what is missing and write the most reliable version you can, for example one that triggers the real button, ClickDetector or ProximityPrompt instead of the remote.
- Prefer driving what the game already exposes to the client (fireclickdetector, fireproximityprompt, the button's own connections or signals, or the same remote with the same arguments the game's own code uses). Add an on/off toggle and a sensible delay so the script does not spam.
- If the context says the scan is unavailable or turned off, tell the user that briefly (only when they ask for something game-specific) and write a generic script instead.

HOW YOU BEHAVE:
- Listen to the user and do what they ask, the way they ask for it. Follow their instructions, naming, style and requests closely. If something is unclear, make a sensible assumption and mention it briefly instead of refusing.
- Helping with coding is your whole job. Never say things like "I can't help with coding", "I'm not able to write that code" or "as an AI I can't". Refusing or dodging a normal coding request breaks this app's usage rules, so always give a real, working answer.
- Be friendly, casual and concise, like a dev friend.
- Get straight to the point. Do not add filler such as "Of course!" or "Sure!", and never tell the user to paste or run the script in their executor, they already know how to do that.]==]

local INTENT_PROMPT = [==[You analyze the latest message of a user who is chatting with a Roblox scripting assistant. Return ONLY a JSON object with exactly this shape:
{"wants_code": boolean, "needs_game": boolean, "topic": string, "keywords": string[]}

- wants_code: true only if the user is asking for a script, code, a fix, a modification or a feature to be written. Greetings, casual chat, questions about concepts, or questions about the game that do not ask for code are false.
- needs_game: true if answering well requires knowing how THIS game works (its scripts, remotes, buttons, currency), for example auto farm, auto clicker, auto collect, auto sell requests, or questions about this game's systems. Generic scripts that do not depend on the game (fly, ESP, UI libraries) are false.
- topic: a short English summary of the goal (2 to 6 words), or an empty string for casual chat.
- keywords: up to 8 lowercase single English words likely to appear in the names, text or code of the relevant game objects (for example click, tap, coin, cash, money, collect, sell). If the message is not in English, still output English keywords. Empty array for casual chat.]==]

local function buildSystemPrompt(lang)
	return "LANGUAGE (very important):\n- The user chose " .. lang .. " as the reply language. Write every reply, explanation and code comment in " .. lang .. ", even if the user's message or earlier messages are written in another language.\n- Only switch language if the user explicitly asks you to reply in a different one.\n- Keep code, variable names and Roblox API names in English.\n\n" .. SYSTEM_BASE
end

-- Reply languages (English first, rest alphabetical)
local LANGS = {
	{name = "Afrikaans", native = "Afrikaans"}, {name = "Albanian", native = "Shqip"},
	{name = "Amharic", native = "አማርኛ"}, {name = "Arabic", native = "العربية"},
	{name = "Armenian", native = "Հայերեն"}, {name = "Azerbaijani", native = "Azərbaycanca"},
	{name = "Basque", native = "Euskara"}, {name = "Bengali", native = "বাংলা"},
	{name = "Bosnian", native = "Bosanski"}, {name = "Bulgarian", native = "Български"},
	{name = "Burmese", native = "မြန်မာ"}, {name = "Catalan", native = "Català"},
	{name = "Chinese (Simplified)", native = "简体中文"}, {name = "Chinese (Traditional)", native = "繁體中文"},
	{name = "Croatian", native = "Hrvatski"}, {name = "Czech", native = "Čeština"},
	{name = "Danish", native = "Dansk"}, {name = "Dutch", native = "Nederlands"},
	{name = "English", native = "English"}, {name = "Esperanto", native = "Esperanto"},
	{name = "Estonian", native = "Eesti"}, {name = "Filipino", native = "Filipino"},
	{name = "Finnish", native = "Suomi"}, {name = "French", native = "Français"},
	{name = "Galician", native = "Galego"}, {name = "Georgian", native = "ქართული"},
	{name = "German", native = "Deutsch"}, {name = "Greek", native = "Ελληνικά"},
	{name = "Gujarati", native = "ગુજરાતી"}, {name = "Hausa", native = "Hausa"},
	{name = "Hebrew", native = "עברית"}, {name = "Hindi", native = "हिन्दी"},
	{name = "Hungarian", native = "Magyar"}, {name = "Icelandic", native = "Íslenska"},
	{name = "Indonesian", native = "Bahasa Indonesia"}, {name = "Irish", native = "Gaeilge"},
	{name = "Italian", native = "Italiano"}, {name = "Japanese", native = "日本語"},
	{name = "Kannada", native = "ಕನ್ನಡ"}, {name = "Kazakh", native = "Қазақша"},
	{name = "Khmer", native = "ខ្មែរ"}, {name = "Korean", native = "한국어"},
	{name = "Kurdish", native = "Kurdî"}, {name = "Lao", native = "ລາວ"},
	{name = "Latin", native = "Latina"}, {name = "Latvian", native = "Latviešu"},
	{name = "Lithuanian", native = "Lietuvių"}, {name = "Macedonian", native = "Македонски"},
	{name = "Malay", native = "Bahasa Melayu"}, {name = "Malayalam", native = "മലയാളം"},
	{name = "Maltese", native = "Malti"}, {name = "Marathi", native = "मराठी"},
	{name = "Mongolian", native = "Монгол"}, {name = "Nepali", native = "नेपाली"},
	{name = "Norwegian", native = "Norsk"}, {name = "Pashto", native = "پښتو"},
	{name = "Persian", native = "فارسی"}, {name = "Polish", native = "Polski"},
	{name = "Portuguese", native = "Português"}, {name = "Punjabi", native = "ਪੰਜਾਬੀ"},
	{name = "Romanian", native = "Română"}, {name = "Russian", native = "Русский"},
	{name = "Serbian", native = "Српски"}, {name = "Sinhala", native = "සිංහල"},
	{name = "Slovak", native = "Slovenčina"}, {name = "Slovenian", native = "Slovenščina"},
	{name = "Somali", native = "Soomaali"}, {name = "Spanish", native = "Español"},
	{name = "Swahili", native = "Kiswahili"}, {name = "Swedish", native = "Svenska"},
	{name = "Tamil", native = "தமிழ்"}, {name = "Telugu", native = "తెలుగు"},
	{name = "Thai", native = "ไทย"}, {name = "Turkish", native = "Türkçe"},
	{name = "Ukrainian", native = "Українська"}, {name = "Urdu", native = "اردو"},
	{name = "Uzbek", native = "Oʻzbekcha"}, {name = "Vietnamese", native = "Tiếng Việt"},
	{name = "Welsh", native = "Cymraeg"}, {name = "Yoruba", native = "Yorùbá"},
	{name = "Zulu", native = "isiZulu"},
}
table.sort(LANGS, function(a, b)
	if a.name == "English" then return true end
	if b.name == "English" then return false end
	return a.name < b.name
end)

local SAVE_DIR = "EpicAIRemake"
local SAVE_FILE = SAVE_DIR .. "/" .. player.UserId .. ".json"
local SETTINGS_FILE = SAVE_DIR .. "/settings_" .. player.UserId .. ".json"

local hasFS = (writefile and readfile and isfile) and true or false
local clipFn = setclipboard or toclipboard

-- Settings (saved between sessions)
local currentLang = "English"
local aware = true -- "Scan game" mode: scan + analyze the prompt + tailor the code
local function saveSettings()
	if not hasFS then return end
	pcall(function()
		if isfolder and makefolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
		writefile(SETTINGS_FILE, HttpService:JSONEncode({lang = currentLang, aware = aware}))
	end)
end
if hasFS then
	pcall(function()
		if isfile(SETTINGS_FILE) then
			local d = HttpService:JSONDecode(readfile(SETTINGS_FILE))
			if type(d) == "table" then
				if type(d.lang) == "string" then
					for _, l in ipairs(LANGS) do
						if l.name == d.lang then currentLang = d.lang end
					end
				end
				if type(d.aware) == "boolean" then aware = d.aware end
			end
		end
	end)
end

-- Re-execute safe: unload the previous instance first (no stacking)
local genv = (getgenv and getgenv()) or _G
if genv.EpicAIRemakeUnload then pcall(genv.EpicAIRemakeUnload) end
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("EpicAIRemake")
if oldGui then oldGui:Destroy() end

local conns = {}
local unloaded = false
local function track(c) table.insert(conns, c); return c end

-- Collect every HTTP request function this executor offers
local requestFns = {}
do
	local function add(name, fn)
		if type(fn) == "function" then table.insert(requestFns, {name = name, fn = fn}) end
	end
	add("request", request)
	add("http_request", http_request)
	add("syn.request", syn and syn.request)
	add("http.request", http and http.request)
	add("fluxus.request", fluxus and fluxus.request)
	add("HttpService", function(o) return HttpService:RequestAsync(o) end)
end

local C = {
	bg = Color3.fromRGB(255, 255, 255),
	side = Color3.fromRGB(245, 245, 250),
	card = Color3.fromRGB(246, 246, 251),
	stroke = Color3.fromRGB(225, 225, 235),
	text = Color3.fromRGB(30, 30, 40),
	sub = Color3.fromRGB(120, 120, 140),
	user = Color3.fromRGB(110, 90, 240),
	tint = Color3.fromRGB(236, 232, 253),
	codeBg = Color3.fromRGB(24, 24, 32),
	codeTop = Color3.fromRGB(42, 42, 56),
	codeText = Color3.fromRGB(230, 230, 240),
}
local GRAD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 140, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 80, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 160)),
})

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, c, t) return new("UIStroke", {Color = c or C.stroke, Thickness = t or 1}, o) end
local function pad(o, t, b, l, r)
	return new("UIPadding", {PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r)}, o)
end
local function cut(s, n)
	if #s <= n then return s end
	local i = n
	while i > 0 do
		local b = s:byte(i + 1)
		if b and b >= 128 and b < 192 then i -= 1 else break end
	end
	return s:sub(1, i)
end

local function makeLogo(size, parent, pos, radius)
	local f = new("Frame", {Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(),
		BackgroundTransparency = 1, BorderSizePixel = 0}, parent)
	local img = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = LOGO,
		ScaleType = Enum.ScaleType.Crop}, f)
	if radius then corner(img, radius) end
	return f
end

-- State
local chats = {}
local current = nil
local busy = false

-- Persistence (writefile)
local function sanitize(data)
	local out = {}
	if type(data) ~= "table" then return out end
	for _, c in ipairs(data) do
		if type(c) == "table" and type(c.id) == "string" and type(c.title) == "string" and type(c.messages) == "table" then
			local msgs = {}
			for _, m in ipairs(c.messages) do
				if type(m) == "table" and (m.r == "user" or m.r == "ai") and type(m.t) == "string" then
					table.insert(msgs, {r = m.r, t = m.t, n = (type(m.n) == "string") and m.n or nil})
				end
			end
			table.insert(out, {id = c.id, title = c.title, messages = msgs})
		end
	end
	return out
end

local function loadChats()
	if not hasFS then return {} end
	local ok, data = pcall(function()
		if not isfile(SAVE_FILE) then return {} end
		return HttpService:JSONDecode(readfile(SAVE_FILE))
	end)
	if ok then return sanitize(data) end
	return {}
end

local function writeNow()
	if not hasFS then return end
	pcall(function()
		if isfolder and makefolder and not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
		writefile(SAVE_FILE, HttpService:JSONEncode(chats))
	end)
end

local saveQueued = false
local function save()
	if not hasFS or saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		writeNow()
	end)
end

-- GUI
local gui = new("ScreenGui", {Name = "EpicAIRemake", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true}, player:WaitForChild("PlayerGui"))

local function unload()
	if unloaded then return end
	unloaded = true
	writeNow()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	pcall(function() gui:Destroy() end)
	if genv.EpicAIRemakeUnload == unload then genv.EpicAIRemakeUnload = nil end
end
genv.EpicAIRemakeUnload = unload

local main = new("Frame", {Size = UDim2.fromScale(0.9, 0.85), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.bg, BorderSizePixel = 0}, gui)
corner(main, 20)
stroke(main)
new("UISizeConstraint", {MaxSize = Vector2.new(920, 540), MinSize = Vector2.new(480, 300)}, main)

-- Sidebar
local side = new("Frame", {Size = UDim2.new(0, 210, 1, 0), BackgroundColor3 = C.side, BorderSizePixel = 0}, main)
corner(side, 20)
new("Frame", {Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(1, -24, 0, 0),
	BackgroundColor3 = C.side, BorderSizePixel = 0}, side)

local title = new("TextLabel", {Size = UDim2.new(1, -28, 0, 42), Position = UDim2.new(0, 14, 0, 14),
	BackgroundTransparency = 1, Text = NAME, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
	TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, side)
new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 12}, title)
local titleGrad = new("UIGradient", {Color = GRAD, Rotation = 0}, title)
track(RunService.Heartbeat:Connect(function(dt)
	titleGrad.Rotation = (titleGrad.Rotation + dt * 60) % 360
end))

local newChat = new("TextButton", {Size = UDim2.new(1, -32, 0, 40), Position = UDim2.new(0, 16, 0, 70),
	BackgroundColor3 = Color3.new(1, 1, 1), Text = "+  New chat", TextColor3 = C.text,
	Font = Enum.Font.GothamMedium, TextSize = 14}, side)
corner(newChat, 12)
stroke(newChat)

new("TextLabel", {Size = UDim2.new(1, -32, 0, 20), Position = UDim2.new(0, 16, 0, 126), BackgroundTransparency = 1,
	Text = "History", TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left}, side)
local histEmpty = new("TextLabel", {Size = UDim2.new(1, -32, 0, 30), Position = UDim2.new(0, 16, 0, 150),
	BackgroundTransparency = 1, Text = "No chats yet", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, side)
local histList = new("ScrollingFrame", {Size = UDim2.new(1, -20, 1, -216), Position = UDim2.new(0, 10, 0, 150),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.sub,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, side)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, histList)

-- Settings button (bottom of sidebar)
local settingsBtn = new("TextButton", {Size = UDim2.new(1, -32, 0, 40), Position = UDim2.new(0, 16, 1, -56),
	BackgroundColor3 = Color3.new(1, 1, 1), Text = "Settings", TextColor3 = C.text,
	Font = Enum.Font.GothamMedium, TextSize = 14}, side)
corner(settingsBtn, 12)
stroke(settingsBtn)

-- Right area
local content = new("Frame", {Size = UDim2.new(1, -210, 1, 0), Position = UDim2.new(0, 210, 0, 0),
	BackgroundTransparency = 1}, main)

-- Header (drag area + language button + X unload button)
local header = new("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1}, content)
local headerLabel = new("TextLabel", {Size = UDim2.new(1, -200, 1, 0), Position = UDim2.new(0, 22, 0, 0),
	BackgroundTransparency = 1, Text = "Chat", TextColor3 = C.sub, Font = Enum.Font.GothamMedium, TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left}, header)
local closeBtn = new("TextButton", {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -48, 0.5, -17),
	BackgroundColor3 = C.card, Text = "X", TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 15}, header)
corner(closeBtn, 17)
closeBtn.MouseButton1Click:Connect(unload)

local langBtn = new("TextButton", {Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -176, 0.5, -17),
	BackgroundColor3 = C.card, Text = currentLang, TextColor3 = C.text, Font = Enum.Font.GothamMedium,
	TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd}, header)
corner(langBtn, 17)
stroke(langBtn)
pad(langBtn, 0, 0, 12, 12)

do
	local dragging, startPos, startInput
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, main.Position, i.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end

-- Chat area (welcome + messages)
local area = new("Frame", {Size = UDim2.new(1, 0, 1, -170), Position = UDim2.new(0, 0, 0, 56),
	BackgroundTransparency = 1}, content)

local welcome = new("Frame", {Size = UDim2.new(1, -48, 1, 0), Position = UDim2.new(0, 24, 0, 0),
	BackgroundTransparency = 1}, area)
new("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, welcome)
local wl = makeLogo(60, welcome, nil, 16); wl.LayoutOrder = 1
new("TextLabel", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 2,
	Text = "Hello, I'm " .. NAME, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 24}, welcome)
new("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 3,
	Text = "How can I help you today?", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 15}, welcome)
local grid = new("Frame", {Size = UDim2.new(1, 0, 0, 108), BackgroundTransparency = 1, LayoutOrder = 4}, welcome)
new("UIGridLayout", {CellSize = UDim2.new(0.5, -6, 0, 50), CellPadding = UDim2.fromOffset(12, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, grid)
local chips = {"Make an auto clicker", "Find the money system", "What can you do?", "Fix this code"}
local chipButtons = {}
for i, t in ipairs(chips) do
	local b = new("TextButton", {BackgroundColor3 = C.card, Text = t, TextColor3 = C.text,
		Font = Enum.Font.GothamMedium, TextSize = 14, LayoutOrder = i}, grid)
	corner(b, 14)
	stroke(b)
	chipButtons[i] = b
end

local scroll = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.sub, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false}, area)
pad(scroll, 8, 8, 20, 20)
new("UIListLayout", {Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

-- Input bar
local inputBar = new("Frame", {Size = UDim2.new(1, -48, 0, 54), Position = UDim2.new(0, 24, 1, -76),
	BackgroundColor3 = C.card, BorderSizePixel = 0}, content)
corner(inputBar, 27)
stroke(inputBar)
local box = new("TextBox", {Size = UDim2.new(1, -76, 1, 0), Position = UDim2.new(0, 20, 0, 0),
	BackgroundTransparency = 1, PlaceholderText = "Message " .. NAME, PlaceholderColor3 = C.sub, Text = "",
	TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false}, inputBar)
local sendBtn = new("TextButton", {Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -48, 0.5, -20),
	BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false}, inputBar)
corner(sendBtn, 20)
new("UIGradient", {Color = GRAD, Rotation = 45}, sendBtn)
new("ImageLabel", {Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Image = SEND_ICON,
	ScaleType = Enum.ScaleType.Fit}, sendBtn)

-- DeepSeek-style toggle pill above the input bar
local pills = new("Frame", {Size = UDim2.new(1, -48, 0, 28), Position = UDim2.new(0, 24, 1, -110),
	BackgroundTransparency = 1}, content)
local scanPill = new("TextButton", {Size = UDim2.fromOffset(116, 28), BackgroundColor3 = C.card, Text = "",
	AutoButtonColor = false}, pills)
corner(scanPill, 14)
local scanPillStroke = stroke(scanPill)
local scanDot = new("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 12, 0.5, -4),
	BackgroundColor3 = Color3.fromRGB(180, 180, 195), BorderSizePixel = 0}, scanPill)
corner(scanDot, 4)
local scanPillLabel = new("TextLabel", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 26, 0, 0),
	BackgroundTransparency = 1, Text = "Scan game", TextColor3 = C.sub, Font = Enum.Font.GothamMedium, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left}, scanPill)

-- Toast
local toast = new("TextLabel", {Size = UDim2.fromOffset(260, 34), Position = UDim2.new(0.5, -130, 1, -152),
	BackgroundColor3 = C.text, TextColor3 = Color3.new(1, 1, 1), Text = "",
	Font = Enum.Font.GothamMedium, TextSize = 13, Visible = false, ZIndex = 10}, content)
corner(toast, 17)
local toastId = 0
local function showToast(msg)
	toastId += 1
	local my = toastId
	toast.Text = msg
	toast.Visible = true
	toast.BackgroundTransparency = 0
	toast.TextTransparency = 0
	task.delay(1.8, function()
		if my ~= toastId or unloaded then return end
		local t = TweenService:Create(toast, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1})
		t:Play()
		t.Completed:Wait()
		if my == toastId then toast.Visible = false end
	end)
end

-- =====================================================================
-- Game scanner: gives the AI eyes on the game the user is in
-- =====================================================================
local scan = {state = "idle", text = "", counts = {}, canDecompile = false, took = 0, err = nil,
	remotes = {}, buttons = {}, prompts = {}, clicks = {}, scripts = {}}
local scanId = 0
local updateScanUI = function() end

local KEYWORDS = {"click", "tap", "coin", "cash", "money", "gold", "gem", "farm", "collect", "sell", "reward",
	"claim", "buy", "shop", "upgrade", "rebirth", "spin", "mine", "chop", "punch", "swing", "attack", "pickup",
	"orb", "currency", "crate", "chest", "hatch", "egg", "tycoon", "dropper", "stat", "level", "xp"}
local function hot(s)
	s = tostring(s or ""):lower()
	for _, k in ipairs(KEYWORDS) do
		if s:find(k, 1, true) then return true end
	end
	return false
end

local function hotFirst(list)
	local a, b = {}, {}
	for _, x in ipairs(list) do
		if x.hot then a[#a + 1] = x else b[#b + 1] = x end
	end
	for _, x in ipairs(b) do a[#a + 1] = x end
	return a
end

-- Lua-ready path, e.g. game:GetService("ReplicatedStorage").Remotes.Click
local function luaPath(inst)
	local chain = {}
	local cur = inst
	while cur and cur ~= game do
		table.insert(chain, 1, cur)
		cur = cur.Parent
	end
	if cur ~= game or #chain == 0 then return nil end
	local s = ('game:GetService("%s")'):format(chain[1].ClassName)
	for i = 2, #chain do
		local n = chain[i].Name
		if chain[i] == player then
			s = s .. ".LocalPlayer"
		elseif n:match("^[%a_][%w_]*$") then
			s = s .. "." .. n
		else
			s = s .. ("[%q]"):format(n)
		end
	end
	return s
end

-- Player currency/stat values (also refreshed on every request)
local function playerStats()
	local parts = {}
	local function dump(folder, prefix)
		for _, v in ipairs(folder:GetChildren()) do
			if v:IsA("ValueBase") and #parts < 30 then
				table.insert(parts, prefix .. v.Name .. "=" .. tostring(v.Value))
			end
		end
	end
	pcall(function()
		dump(player, "")
		for _, f in ipairs(player:GetChildren()) do
			if f:IsA("Folder") or f:IsA("Configuration") then dump(f, f.Name .. ".") end
		end
		local n = 0
		for k, v in pairs(player:GetAttributes()) do
			local t = type(v)
			if (t == "number" or t == "string" or t == "boolean") and n < 10 then
				table.insert(parts, "attr:" .. k .. "=" .. tostring(v))
				n += 1
			end
		end
	end)
	if #parts == 0 then return "none found" end
	return table.concat(parts, ", ")
end

local function safeDecompile(inst)
	if type(decompile) ~= "function" then return nil end
	local done, result = false, nil
	task.spawn(function()
		local ok, res = pcall(decompile, inst)
		if ok and type(res) == "string" then result = res end
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 4 do task.wait(0.05) end
	return done and result or nil
end

-- Decompiled source cache (so focused searches don't redo work)
local srcCache, srcOrder = {}, {}
local function getSource(inst)
	if srcCache[inst] then return srcCache[inst] end
	local src = safeDecompile(inst)
	if src then
		src = cut(src, 80000)
		srcCache[inst] = src
		table.insert(srcOrder, inst)
		if #srcOrder > 40 then
			local old = table.remove(srcOrder, 1)
			srcCache[old] = nil
		end
	end
	return src
end

local LINE_KEYS = {"FireServer", "InvokeServer", ":Fire(", "leaderstats", "Activated", "MouseButton1Click",
	"MouseButton1Down", "Touched", "ClickDetector", "MouseClick", "Triggered", "RemoteEvent", "RemoteFunction",
	"Coins", "Cash", "Money", "Gold", "Gems", "Click", "Collect", "Sell", "Reward"}
local function excerpt(src, isHot)
	local out, n, chars, ln = {}, 0, 0, 0
	for line in (src .. "\n"):gmatch("([^\n]*)\n") do
		ln += 1
		local hit = false
		for _, k in ipairs(LINE_KEYS) do
			if line:find(k, 1, true) then hit = true break end
		end
		if hit then
			local t = line:gsub("^%s+", "")
			t = cut(t, 160)
			table.insert(out, ("L%d: %s"):format(ln, t))
			n += 1
			chars += #t + 8
			if n >= 45 or chars >= 3500 then break end
		end
	end
	if #out == 0 and isHot then
		ln = 0
		for line in (src .. "\n"):gmatch("([^\n]*)\n") do
			ln += 1
			local t = line:gsub("^%s+", "")
			if t ~= "" then table.insert(out, ("L%d: %s"):format(ln, cut(t, 120))) end
			if #out >= 15 then break end
		end
	end
	return table.concat(out, "\n")
end

-- Same idea, but also keeps lines that mention the request's keywords
local function excerptFocus(src, kws)
	local out, chars, ln = {}, 0, 0
	for line in (src .. "\n"):gmatch("([^\n]*)\n") do
		ln += 1
		local hit = false
		for _, k in ipairs(LINE_KEYS) do
			if line:find(k, 1, true) then hit = true break end
		end
		if not hit then
			local l = line:lower()
			for _, k in ipairs(kws) do
				if k ~= "" and l:find(k, 1, true) then hit = true break end
			end
		end
		if hit then
			local t = line:gsub("^%s+", "")
			t = cut(t, 170)
			table.insert(out, ("L%d: %s"):format(ln, t))
			chars += #t + 8
			if #out >= 70 or chars >= 6000 then break end
		end
	end
	return table.concat(out, "\n")
end

local function runScan(my)
	local t0 = os.clock()
	local cnt = {remotes = 0, scripts = 0, clicks = 0, prompts = 0, touches = 0, buttons = 0, decompiled = 0}
	local remotes, clicks, prompts, touches, buttons, labels, scripts = {}, {}, {}, {}, {}, {}, {}

	local function consider(inst, where)
		local cn = inst.ClassName
		if cn == "RemoteEvent" or cn == "RemoteFunction" or cn == "UnreliableRemoteEvent" then
			cnt.remotes += 1
			if #remotes < 400 then
				local p = luaPath(inst)
				if p and not p:find("ChatEvents", 1, true) and not p:find("DefaultChat", 1, true) then
					table.insert(remotes, {p = p, c = cn, hot = hot(inst.Name)})
				end
			end
		elseif cn == "ClickDetector" then
			cnt.clicks += 1
			if #clicks < 60 then
				local par = inst.Parent
				local p = luaPath(par or inst)
				if p then table.insert(clicks, {p = p, d = inst.MaxActivationDistance, hot = hot(par and par.Name or "")}) end
			end
		elseif cn == "ProximityPrompt" then
			cnt.prompts += 1
			if #prompts < 60 then
				local par = inst.Parent
				local p = luaPath(par or inst)
				if p then
					table.insert(prompts, {p = p, a = inst.ActionText, o = inst.ObjectText, h = inst.HoldDuration,
						hot = hot(inst.ActionText .. " " .. inst.ObjectText .. " " .. (par and par.Name or ""))})
				end
			end
		elseif cn == "TouchTransmitter" then
			cnt.touches += 1
			local par = inst.Parent
			if par and #touches < 40 and hot(par.Name) then
				local p = luaPath(par)
				if p then table.insert(touches, p) end
			end
		elseif cn == "LocalScript" or cn == "ModuleScript" or cn == "Script" then
			cnt.scripts += 1
			if #scripts < 600 then
				local p = luaPath(inst)
				if p then
					local par = inst.Parent
					table.insert(scripts, {inst = inst, p = p, c = cn, hot = hot(inst.Name) or (par and hot(par.Name)) or false})
				end
			end
		elseif where == "player" then
			if cn == "TextButton" or cn == "ImageButton" then
				cnt.buttons += 1
				if #buttons < 120 then
					local p = luaPath(inst)
					local text = (cn == "TextButton") and inst.Text or ""
					if p then table.insert(buttons, {inst = inst, p = p, t = text, hot = hot(inst.Name .. " " .. text)}) end
				end
			elseif cn == "TextLabel" and #labels < 15 then
				local s = inst.Name .. " " .. inst.Text
				if hot(s) or s:find("%$") then
					local p = luaPath(inst)
					if p then table.insert(labels, {p = p, t = inst.Text}) end
				end
			end
		end
	end

	local function walkRoot(root, where)
		if not root then return end
		pcall(consider, root, where)
		local ok, list = pcall(function() return root:GetDescendants() end)
		if not ok then return end
		for i = 1, #list do
			if my ~= scanId or unloaded then return end
			pcall(consider, list[i], where)
			if i % 1200 == 0 then task.wait() end
			if i >= 120000 then break end
		end
	end

	walkRoot(game:GetService("ReplicatedStorage"), "rs")
	walkRoot(game:GetService("ReplicatedFirst"), "rs")
	walkRoot(game:GetService("Workspace"), "ws")
	for _, ch in ipairs(player:GetChildren()) do
		if ch:IsA("PlayerGui") then
			for _, g in ipairs(ch:GetChildren()) do
				if g ~= gui then walkRoot(g, "player") end
			end
		else
			walkRoot(ch, "player")
		end
	end
	if my ~= scanId or unloaded then return end

	-- Pick the most relevant scripts and decompile them (if the executor can)
	for _, s in ipairs(scripts) do
		local score = 0
		if s.hot then score += 3 end
		local mine = s.inst:IsDescendantOf(player) or (player.Character and s.inst:IsDescendantOf(player.Character))
		if mine then score += 2 end
		if s.c ~= "Script" then score += 1 end
		s.score = score
	end
	table.sort(scripts, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.p < b.p
	end)

	local canDec = type(decompile) == "function"
	scan.canDecompile = canDec
	local blocks = {}
	if canDec then
		local tDec, used, attempts = os.clock(), 0, 0
		for _, s in ipairs(scripts) do
			if cnt.decompiled >= 28 or attempts >= 40 or used > 42000 then break end
			if my ~= scanId or unloaded then return end
			if os.clock() - tDec > 18 then break end
			if s.score >= 2 then
				attempts += 1
				local src = getSource(s.inst)
				if src and #src > 20 then
					local ex = excerpt(src, s.hot)
					if ex ~= "" then
						local block = ("--- %s (%s, %d chars) ---\n%s"):format(s.p, s.c, #src, ex)
						table.insert(blocks, block)
						used += #block
						cnt.decompiled += 1
					end
				end
			end
		end
	end

	-- Game info
	local gname = tostring(game.Name)
	pcall(function()
		local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		if info and info.Name then gname = info.Name end
	end)
	local exec = "unknown"
	pcall(function()
		if identifyexecutor then exec = tostring((identifyexecutor())) end
	end)

	local B = {}
	local function add(s) B[#B + 1] = s end
	add("GAME CONTEXT (automatic scan)")
	add(("Game: %s | PlaceId: %s | GameId: %s | Players: %s | Executor: %s | decompile: %s"):format(
		gname, tostring(game.PlaceId), tostring(game.GameId), tostring(#Players:GetPlayers()), exec,
		canDec and "available" or "NOT available (no code excerpts)"))
	add("Local player: " .. player.Name .. " | Stats at scan time: " .. playerStats())

	add(("\nREMOTES (%d found, hot names first):"):format(cnt.remotes))
	for i, r in ipairs(hotFirst(remotes)) do
		if i > 220 then break end
		add(("[%s] %s"):format(r.c, r.p))
	end

	add(("\nCLICK DETECTORS (%d found):"):format(cnt.clicks))
	for i, c in ipairs(hotFirst(clicks)) do
		if i > 40 then break end
		add(("on %s (max distance %s)"):format(c.p, tostring(c.d)))
	end

	add(("\nPROXIMITY PROMPTS (%d found):"):format(cnt.prompts))
	for i, p in ipairs(hotFirst(prompts)) do
		if i > 40 then break end
		add(('on %s action="%s" object="%s" hold=%s'):format(p.p, p.a, p.o, tostring(p.h)))
	end

	if #touches > 0 then
		add(("\nTOUCH PARTS with relevant names (%d total touch parts):"):format(cnt.touches))
		for i, p in ipairs(touches) do
			if i > 25 then break end
			add(p)
		end
	end

	add(("\nGUI BUTTONS in PlayerGui (%d found):"):format(cnt.buttons))
	for i, b in ipairs(hotFirst(buttons)) do
		if i > 80 then break end
		local n = "?"
		if type(getconnections) == "function" then
			local ok, res = pcall(function() return #getconnections(b.inst.MouseButton1Click) end)
			if ok then n = tostring(res) end
		end
		add(('%s text="%s" connections=%s'):format(b.p, cut(b.t, 40), n))
	end

	if #labels > 0 then
		add("\nGUI LABELS that look like currency/stats:")
		for _, l in ipairs(labels) do add(('%s text="%s"'):format(l.p, cut(l.t, 40))) end
	end

	local tools = {}
	local function addTools(parent)
		if not parent then return end
		for _, t in ipairs(parent:GetChildren()) do
			if t:IsA("Tool") then
				local rem, sc = {}, 0
				for _, d in ipairs(t:GetDescendants()) do
					if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then table.insert(rem, d.Name) end
					if d:IsA("LuaSourceContainer") then sc += 1 end
				end
				table.insert(tools, ("%s (scripts: %d, remotes: %s)"):format(t.Name, sc, #rem > 0 and table.concat(rem, ",") or "none"))
			end
		end
	end
	pcall(addTools, player:FindFirstChildOfClass("Backpack"))
	pcall(addTools, player.Character)
	if #tools > 0 then
		add("\nTOOLS the player has:")
		for _, t in ipairs(tools) do add(t) end
	end

	add(("\nSCRIPTS (%d found, most relevant first):"):format(cnt.scripts))
	for i, s in ipairs(scripts) do
		if i > 150 then break end
		add(("[%s] %s"):format(s.c, s.p))
	end

	if #blocks > 0 then
		add(("\nDECOMPILED CODE EXCERPTS (%d scripts, only lines about remotes, clicks and currency):"):format(#blocks))
		for _, b in ipairs(blocks) do add(b) end
	end

	local text = table.concat(B, "\n")
	if #text > 70000 then text = cut(text, 70000) .. "\n[truncated]" end

	if my ~= scanId or unloaded then return end
	scan.text = text
	scan.counts = cnt
	scan.took = os.clock() - t0
	scan.err = nil
	scan.remotes, scan.buttons, scan.prompts, scan.clicks, scan.scripts = remotes, buttons, prompts, clicks, scripts
	scan.state = "done"
	updateScanUI()
end

local function startScan()
	scanId += 1
	local my = scanId
	scan.state = "scanning"
	scan.text = ""
	updateScanUI()
	task.spawn(function()
		local ok, err = pcall(runScan, my)
		if my ~= scanId or unloaded then return end
		if not ok then
			scan.state = "failed"
			scan.err = tostring(err)
			updateScanUI()
		end
	end)
end

-- =====================================================================
-- Gemini (client-side via executor request functions)
-- =====================================================================
local function pick(t, ...)
	for _, k in ipairs({...}) do
		if t[k] ~= nil then return t[k] end
	end
	return nil
end

-- One Gemini call. Returns data, or nil + error text
local function postGemini(payload)
	if #requestFns == 0 then
		return nil, "No HTTP request function found in this executor."
	end
	local body = HttpService:JSONEncode(payload)
	local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. MODEL .. ":generateContent"

	-- Try each request function until one gives a real response body
	local tried, rbody, status = {}, nil, nil
	for _, rf in ipairs(requestFns) do
		local ok, res = pcall(rf.fn, {
			Url = url,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json", ["x-goog-api-key"] = API_KEY},
			Body = body,
		})
		if not ok then
			table.insert(tried, rf.name .. ": " .. cut(tostring(res), 80))
		elseif type(res) ~= "table" then
			table.insert(tried, rf.name .. ": returned " .. type(res))
		else
			local b = pick(res, "Body", "body")
			local st = tonumber(pick(res, "StatusCode", "status_code", "Status", "status"))
			if type(b) == "string" and b ~= "" then
				rbody, status = b, st
				break
			else
				table.insert(tried, rf.name .. ": empty body (status " .. tostring(st) .. ")")
			end
		end
	end
	if not rbody then
		return nil, "HTTP request failed. " .. table.concat(tried, " | ")
	end

	local okD, data = pcall(function() return HttpService:JSONDecode(rbody) end)
	if not okD or type(data) ~= "table" then
		return nil, "Invalid response: " .. cut(rbody, 150)
	end
	if (status and (status < 200 or status >= 300)) or data.error then
		local msg = data.error and data.error.message or ("HTTP " .. tostring(status))
		return nil, "Gemini error: " .. tostring(msg)
	end
	return data
end

local function extractText(data)
	local cand = data.candidates and data.candidates[1]
	local parts = cand and cand.content and cand.content.parts
	local out = {}
	if parts then
		for _, p in ipairs(parts) do
			if type(p.text) == "string" then table.insert(out, p.text) end
		end
	end
	local text = table.concat(out)
	if text == "" then
		local reason = data.promptFeedback and data.promptFeedback.blockReason
		if reason then return nil, "Blocked by Gemini: " .. tostring(reason) end
		return nil, "Gemini returned an empty reply (finish reason: " .. tostring(cand and cand.finishReason) .. ")."
	end
	return text
end

-- Step 1: understand the request (wants code? needs game data? what topic?)
local function analyzeIntent(history)
	local lines = {}
	for i = math.max(1, #history - 3), #history do
		local m = history[i]
		local who = (m.r == "user") and "User" or "Assistant"
		lines[#lines + 1] = ((i == #history) and "LATEST " or "") .. who .. ": " .. cut(tostring(m.t), 600)
	end
	local data = postGemini({
		systemInstruction = {parts = {{text = INTENT_PROMPT}}},
		contents = {{role = "user", parts = {{text = table.concat(lines, "\n\n")}}}},
		generationConfig = {responseMimeType = "application/json", temperature = 0},
	})
	if not data then return nil end
	local text = extractText(data)
	if not text then return nil end
	text = text:gsub("^%s*```%a*", "")
	text = text:gsub("```%s*$", "")
	local ok, d = pcall(function() return HttpService:JSONDecode(text) end)
	if not ok or type(d) ~= "table" then return nil end
	local kws = {}
	if type(d.keywords) == "table" then
		for _, k in ipairs(d.keywords) do
			if type(k) == "string" and #kws < 10 then
				k = k:lower():gsub("[^%w_]", "")
				if k ~= "" then kws[#kws + 1] = k end
			end
		end
	end
	return {
		code = d.wants_code == true,
		game = d.needs_game == true,
		topic = (type(d.topic) == "string") and cut(d.topic, 80) or "",
		keywords = kws,
	}
end

local function fallbackKeywords(text)
	local t = tostring(text or ""):lower()
	local out = {}
	for _, k in ipairs(KEYWORDS) do
		if t:find(k, 1, true) and #out < 8 then out[#out + 1] = k end
	end
	if #out == 0 then out = {"click", "coin", "cash", "money", "collect"} end
	return out
end

local function kwMatch(s, kws)
	s = tostring(s or ""):lower()
	local n = 0
	for _, k in ipairs(kws) do
		if k ~= "" and s:find(k, 1, true) then n += 1 end
	end
	return n
end

-- Step 2: dig into the game for exactly what the request is about
local function focusedSearch(kws, topic)
	local lines = {}
	local function add(s) lines[#lines + 1] = s end
	local found = {remotes = 0, ui = 0, scripts = 0}
	add(('FOCUSED SEARCH for "%s" (keywords: %s):'):format(topic ~= "" and topic or "the request", table.concat(kws, ", ")))

	local rem = {}
	for _, r in ipairs(scan.remotes) do
		if kwMatch(r.p, kws) > 0 then rem[#rem + 1] = ("[%s] %s"):format(r.c, r.p) end
	end
	found.remotes = #rem
	if #rem > 0 then
		add("Matching remotes:")
		for i, s in ipairs(rem) do
			if i > 25 then break end
			add(s)
		end
	end

	local ui = {}
	for _, b in ipairs(scan.buttons) do
		if kwMatch(b.p .. " " .. b.t, kws) > 0 then ui[#ui + 1] = ('button %s text="%s"'):format(b.p, cut(b.t, 40)) end
	end
	for _, p in ipairs(scan.prompts) do
		if kwMatch(p.p .. " " .. p.a .. " " .. p.o, kws) > 0 then
			ui[#ui + 1] = ('proximity prompt on %s action="%s" object="%s" hold=%s'):format(p.p, p.a, p.o, tostring(p.h))
		end
	end
	for _, c in ipairs(scan.clicks) do
		if kwMatch(c.p, kws) > 0 then ui[#ui + 1] = ("click detector on %s"):format(c.p) end
	end
	found.ui = #ui
	if #ui > 0 then
		add("Matching buttons / prompts / click targets:")
		for i, s in ipairs(ui) do
			if i > 25 then break end
			add(s)
		end
	end

	local cands = {}
	for _, s in ipairs(scan.scripts) do
		local m = kwMatch(s.p, kws)
		cands[#cands + 1] = {s = s, m = m, pts = m * 4 + (s.score or 0)}
	end
	table.sort(cands, function(a, b) return a.pts > b.pts end)
	local tDec, blocks = os.clock(), 0
	for _, c in ipairs(cands) do
		if blocks >= 6 or os.clock() - tDec > 14 then break end
		if (c.m > 0 or (c.s.score or 0) >= 3) and c.s.inst.Parent then
			local src = getSource(c.s.inst)
			if src and #src > 20 then
				local ex = excerptFocus(src, kws)
				if ex ~= "" then
					add(("--- %s (%s, %d chars) ---"):format(c.s.p, c.s.c, #src))
					add(ex)
					blocks += 1
				end
			end
		end
	end
	found.scripts = blocks

	local text = table.concat(lines, "\n")
	if #text > 30000 then text = cut(text, 30000) .. "\n[truncated]" end
	return text, found
end

local function lastUserText(history)
	for i = #history, 1, -1 do
		if history[i].r == "user" then return tostring(history[i].t) end
	end
	return ""
end

-- Full pipeline. setStage(text) updates the "thinking" bubble.
local function askAI(history, setStage)
	local lang = currentLang
	local intent, focused, note = nil, "", nil
	local includeGlobal = false

	if aware then
		if scan.state == "scanning" then
			setStage("Scanning the game")
			local t = os.clock()
			while scan.state == "scanning" and os.clock() - t < 45 and not unloaded do task.wait(0.2) end
		end
		setStage("Reading your request")
		intent = analyzeIntent(history)
		includeGlobal = (intent == nil) or intent.game
		if includeGlobal and scan.state == "done" then
			setStage("Searching the game")
			local kws = (intent and #intent.keywords > 0) and intent.keywords or fallbackKeywords(lastUserText(history))
			local text, found = focusedSearch(kws, intent and intent.topic or "")
			focused = text
			local topicPart = (intent and intent.topic ~= "") and ('"' .. intent.topic .. '" · ') or ""
			note = ("Searched the game · %s%d remotes · %d UI targets · %d scripts"):format(
				topicPart, found.remotes, found.ui, found.scripts)
		end
	end
	if unloaded then return {ok = false, text = "Unloaded."} end
	setStage("Writing")

	local contents = {}
	for _, m in ipairs(history) do
		table.insert(contents, {role = (m.r == "user") and "user" or "model", parts = {{text = tostring(m.t)}}})
	end
	while #contents > 0 and contents[1].role ~= "user" do table.remove(contents, 1) end
	if #contents == 0 then return {ok = false, text = "Bad request."} end

	-- Hidden language reminder on the latest user message (only in the request, never shown or saved)
	local last = contents[#contents]
	if last.role == "user" then
		last.parts[1].text = last.parts[1].text .. "\n\n[Reminder: write your entire reply in " .. lang .. ".]"
	end

	-- System prompt + request analysis + game context
	local sys = buildSystemPrompt(lang)
	if aware then
		if intent then
			sys = sys .. "\n\nREQUEST ANALYSIS (done automatically before you answer): the user "
				.. (intent.code and "IS asking for code" or "is NOT asking for code")
				.. "; game data " .. (intent.game and "is needed" or "is not needed")
				.. "; topic: " .. (intent.topic ~= "" and intent.topic or "general chat") .. ". "
				.. (intent.code
					and "Write the complete script now and customize it to this game using the context below (exact paths, remotes and arguments)."
					or "Reply like a normal conversation in plain words with no code blocks, unless the message really does ask for code.")
		end
		if includeGlobal then
			if scan.state == "done" and scan.text ~= "" then
				sys = sys .. "\n\n" .. scan.text .. "\n\nLive player stats right now: " .. playerStats()
				if focused ~= "" then sys = sys .. "\n\n" .. focused end
			else
				sys = sys .. "\n\n[GAME CONTEXT: the game scan is unavailable.]"
			end
		end
	else
		sys = sys .. "\n\n[GAME CONTEXT: the Scan game mode is turned off, so no game data is available.]"
	end

	local data, err = postGemini({
		systemInstruction = {parts = {{text = sys}}},
		contents = contents,
	})
	if not data then return {ok = false, text = err} end
	local text, why = extractText(data)
	if not text then return {ok = false, text = why} end
	return {ok = true, text = text, note = note}
end

-- =====================================================================
-- Settings panel: fades + scales in/out
-- =====================================================================
local settingsPanel = new("CanvasGroup", {Size = UDim2.new(1, -32, 1, -72), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 20), BackgroundColor3 = C.side, BorderSizePixel = 0,
	GroupTransparency = 1, Visible = false, Active = true, ZIndex = 20}, content)
corner(settingsPanel, 16)
stroke(settingsPanel)
local panelScale = new("UIScale", {Scale = 0.94}, settingsPanel)
local settingsBody = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.sub, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y}, settingsPanel)
pad(settingsBody, 16, 16, 18, 18)
new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, settingsBody)

local function settingRow(order, titleText, subText)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, LayoutOrder = order}, settingsBody)
	corner(row, 12)
	stroke(row)
	new("TextLabel", {Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 8), BackgroundTransparency = 1,
		Text = titleText, TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left}, row)
	local sub = new("TextLabel", {Size = UDim2.new(1, -110, 0, 18), Position = UDim2.new(0, 14, 0, 31),
		BackgroundTransparency = 1, Text = subText, TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, row)
	return row, sub
end

-- Row 1: Scan game switch (same as the pill above the message box)
local awareRow = settingRow(1, "Scan game", "Scans the game, reads your request and tailors the code")
local awareTrack = new("TextButton", {Size = UDim2.fromOffset(44, 24), Position = UDim2.new(1, -58, 0.5, -12),
	BackgroundColor3 = aware and C.user or Color3.fromRGB(205, 205, 218), Text = "", AutoButtonColor = false}, awareRow)
corner(awareTrack, 12)
local awareKnob = new("Frame", {Size = UDim2.fromOffset(18, 18),
	Position = aware and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, awareTrack)
corner(awareKnob, 9)

-- Row 2: scan status + rescan
local statusRow, statusSub = settingRow(2, "Scan status", "Waiting...")
local rescanBtn = new("TextButton", {Size = UDim2.fromOffset(78, 30), Position = UDim2.new(1, -92, 0.5, -15),
	BackgroundColor3 = C.tint, Text = "Rescan", TextColor3 = C.user, Font = Enum.Font.GothamMedium,
	TextSize = 13}, statusRow)
corner(rescanBtn, 15)

local function styleScanPill()
	local on = aware
	scanPill.BackgroundColor3 = on and C.tint or C.card
	scanPillStroke.Color = on and Color3.fromRGB(160, 140, 240) or C.stroke
	scanPillLabel.TextColor3 = on and C.user or C.sub
	local dot = Color3.fromRGB(180, 180, 195)
	if on then
		if scan.state == "scanning" then
			dot = Color3.fromRGB(240, 170, 40)
		elseif scan.state == "done" then
			dot = Color3.fromRGB(50, 170, 100)
		elseif scan.state == "failed" then
			dot = Color3.fromRGB(210, 70, 70)
		end
	end
	scanDot.BackgroundColor3 = dot
end

updateScanUI = function()
	styleScanPill()
	local st = scan.state
	if not aware then
		statusSub.Text = "Turned off. The AI can't see the game."
	elseif st == "scanning" then
		statusSub.Text = "Scanning..."
	elseif st == "done" then
		local c = scan.counts
		statusSub.Text = ("%d remotes · %d scripts · %d decompiled · %d click targets · %.1fs%s"):format(
			c.remotes or 0, c.scripts or 0, c.decompiled or 0, (c.clicks or 0) + (c.prompts or 0), scan.took or 0,
			scan.canDecompile and "" or " · no decompile")
	elseif st == "failed" then
		statusSub.Text = "Failed: " .. cut(tostring(scan.err or "unknown error"), 70)
	else
		statusSub.Text = "Waiting..."
	end
end

local function setAware(v)
	aware = v
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(awareTrack, info, {BackgroundColor3 = v and C.user or Color3.fromRGB(205, 205, 218)}):Play()
	TweenService:Create(awareKnob, info, {Position = v and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)}):Play()
	saveSettings()
	if v and scan.state ~= "done" and scan.state ~= "scanning" then
		startScan()
	else
		updateScanUI()
	end
end
awareTrack.MouseButton1Click:Connect(function() setAware(not aware) end)
scanPill.MouseButton1Click:Connect(function() setAware(not aware) end)
rescanBtn.MouseButton1Click:Connect(function()
	if not aware then
		setAware(true)
	else
		startScan()
	end
end)

local settingsOpen = false
local settingsToken = 0
local function setSettings(open)
	if open == settingsOpen then return end
	settingsOpen = open
	settingsToken += 1
	local my = settingsToken
	headerLabel.Text = open and "Settings" or "Chat"
	TweenService:Create(settingsBtn, TweenInfo.new(0.25), {BackgroundColor3 = open and C.tint or Color3.new(1, 1, 1)}):Play()
	if open then
		settingsPanel.Visible = true
		local info = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(settingsPanel, info, {GroupTransparency = 0}):Play()
		TweenService:Create(panelScale, info, {Scale = 1}):Play()
	else
		local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local t = TweenService:Create(settingsPanel, info, {GroupTransparency = 1})
		TweenService:Create(panelScale, info, {Scale = 0.94}):Play()
		t:Play()
		t.Completed:Connect(function()
			if my == settingsToken and not settingsOpen then settingsPanel.Visible = false end
		end)
	end
end
settingsBtn.MouseButton1Click:Connect(function() setSettings(not settingsOpen) end)

-- =====================================================================
-- Language dropdown (search + list). Backdrop closes it on outside click.
-- =====================================================================
local langBackdrop = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
	AutoButtonColor = false, Visible = false, ZIndex = 25}, gui)
local langPanel = new("CanvasGroup", {Size = UDim2.fromOffset(270, 340), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(300, 80), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	GroupTransparency = 1, Visible = false, Active = true, ZIndex = 30}, gui)
corner(langPanel, 16)
stroke(langPanel)
local langScale = new("UIScale", {Scale = 0.94}, langPanel)

local searchWrap = new("Frame", {Size = UDim2.new(1, -20, 0, 38), Position = UDim2.new(0, 10, 0, 10),
	BackgroundColor3 = C.card, BorderSizePixel = 0}, langPanel)
corner(searchWrap, 19)
stroke(searchWrap)
local searchBox = new("TextBox", {Size = UDim2.new(1, -28, 1, 0), Position = UDim2.new(0, 14, 0, 0),
	BackgroundTransparency = 1, Text = "", PlaceholderText = "Search language...", PlaceholderColor3 = C.sub,
	TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false}, searchWrap)

local langList = new("ScrollingFrame", {Size = UDim2.new(1, -12, 1, -62), Position = UDim2.new(0, 6, 0, 56),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.sub,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, langPanel)
pad(langList, 2, 6, 4, 4)
new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, langList)
local noResults = new("TextLabel", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
	Text = "No languages found", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 13,
	Visible = false, LayoutOrder = 10000}, langList)

local langItems = {}
local function refreshSelection()
	for _, it in ipairs(langItems) do
		local sel = (it.name == currentLang)
		it.btn.BackgroundTransparency = sel and 0 or 1
		it.btn.BackgroundColor3 = C.tint
	end
end

local langOpen = false
local langToken = 0
local function setLangOpen(open)
	if open == langOpen then return end
	langOpen = open
	langToken += 1
	local my = langToken
	if open then
		local bp, bs = langBtn.AbsolutePosition, langBtn.AbsoluteSize
		local top = bp.Y + bs.Y + 8
		local h = math.max(160, math.min(340, gui.AbsoluteSize.Y - top - 12))
		langPanel.Size = UDim2.fromOffset(270, h)
		langPanel.Position = UDim2.fromOffset(math.clamp(bp.X + bs.X, 280, math.max(280, gui.AbsoluteSize.X - 8)), top)
		searchBox.Text = ""
		for _, it in ipairs(langItems) do it.btn.Visible = true end
		noResults.Visible = false
		refreshSelection()
		langBackdrop.Visible = true
		langPanel.Visible = true
		local info = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(langPanel, info, {GroupTransparency = 0}):Play()
		TweenService:Create(langScale, info, {Scale = 1}):Play()
	else
		langBackdrop.Visible = false
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local t = TweenService:Create(langPanel, info, {GroupTransparency = 1})
		TweenService:Create(langScale, info, {Scale = 0.94}):Play()
		t:Play()
		t.Completed:Connect(function()
			if my == langToken and not langOpen then langPanel.Visible = false end
		end)
	end
end

local function selectLang(name)
	currentLang = name
	langBtn.Text = name
	saveSettings()
	setLangOpen(false)
	showToast("Reply language: " .. name)
end

for i, l in ipairs(LANGS) do
	local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.tint,
		BackgroundTransparency = 1, AutoButtonColor = false, Text = "", LayoutOrder = i}, langList)
	corner(btn, 10)
	new("TextLabel", {Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
		RichText = true, Text = l.name .. '  <font color="rgb(150,150,170)">' .. l.native .. "</font>",
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, btn)
	langItems[i] = {btn = btn, key = (l.name .. " " .. l.native):lower(), name = l.name}
	btn.MouseButton1Click:Connect(function() selectLang(l.name) end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = searchBox.Text:lower()
	q = q:gsub("^%s+", "")
	q = q:gsub("%s+$", "")
	local any = false
	for _, it in ipairs(langItems) do
		local show = (q == "") or (it.key:find(q, 1, true) ~= nil)
		it.btn.Visible = show
		if show then any = true end
	end
	noResults.Visible = not any
end)

langBtn.MouseButton1Click:Connect(function() setLangOpen(not langOpen) end)
langBackdrop.MouseButton1Click:Connect(function() setLangOpen(false) end)
refreshSelection()

-- Layout helpers
local resizers = {}
local stickies = {}
local function maxW()
	local w = scroll.AbsoluteSize.X
	if w <= 0 then w = 420 end
	return math.max(180, w - 110)
end
track(scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	for _, f in ipairs(resizers) do f() end
end))

-- Sticky copy buttons: follow the viewport top while the code block is on screen
local BTN_H = 22
track(RunService.RenderStepped:Connect(function()
	if not scroll.Visible then return end
	local viewTop = scroll.AbsolutePosition.Y
	for i = #stickies, 1, -1 do
		local s = stickies[i]
		if not s.block.Parent then
			table.remove(stickies, i)
		else
			local delta = viewTop - s.top.AbsolutePosition.Y
			local maxY = math.max(5, s.block.AbsoluteSize.Y - BTN_H - 6)
			local y = math.clamp(delta + 8, 5, maxY)
			if s.btn.Position.Y.Offset ~= y then
				s.btn.Position = UDim2.new(1, -78, 0, y)
			end
		end
	end
end))

local order = 0
local function nextOrder() order += 1; return order end

local function scrollDown()
	task.defer(function()
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		if unloaded then return end
		scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y))
	end)
end

-- Markdown helpers
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function parseMarkdown(text)
	local segs, pos = {}, 1
	while true do
		local s, e = text:find("```", pos, true)
		if not s then break end
		local before = text:sub(pos, s - 1)
		if before:match("%S") then table.insert(segs, {k = "text", v = trim(before)}) end
		local cs, ce = text:find("```", e + 1, true)
		local inner
		if cs then
			inner = text:sub(e + 1, cs - 1)
			pos = ce + 1
		else
			inner = text:sub(e + 1)
			pos = #text + 1
		end
		local lang, rest = inner:match("^([%w_%+%-]*)[ \t]*\r?\n(.*)$")
		if not lang then lang, rest = "", inner end
		rest = (rest:gsub("\r", ""):gsub("\n%s*$", ""))
		table.insert(segs, {k = "code", lang = lang, v = rest})
	end
	local tail = text:sub(pos)
	if tail:match("%S") then table.insert(segs, {k = "text", v = trim(tail)}) end
	return segs
end

local function toRich(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	s = s:gsub("%*%*(.-)%*%*", "<b>%1</b>")
	s = s:gsub("`([^`\n]+)`", '<font face="RobotoMono" color="rgb(130,70,230)">%1</font>')
	s = s:gsub("^#+%s*([^\n]+)", "<b>%1</b>")
	s = s:gsub("\n#+%s*([^\n]+)", "\n<b>%1</b>")
	s = s:gsub("^[%*%-] ", "• ")
	s = s:gsub("\n[%*%-] ", "\n• ")
	return s
end

-- Bubbles
local function textBubble(parent, text, isUser, layoutOrder)
	text = tostring(text or "")
	local bubble = new("Frame", {Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = isUser and C.user or C.card, BorderSizePixel = 0, LayoutOrder = layoutOrder}, parent)
	corner(bubble, 16)
	pad(bubble, 10, 10, 13, 13)
	local lbl = new("TextLabel", {Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1, RichText = not isUser, Text = isUser and text or toRich(text),
		TextColor3 = isUser and Color3.new(1, 1, 1) or C.text, Font = Enum.Font.Gotham, TextSize = 15,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left}, bubble)
	local sc = new("UISizeConstraint", {MaxSize = Vector2.new(maxW() - 26, math.huge)}, lbl)
	table.insert(resizers, function() sc.MaxSize = Vector2.new(maxW() - 26, math.huge) end)
	return bubble, lbl
end

local function codeBlock(parent, lang, code, layoutOrder)
	local block = new("Frame", {Size = UDim2.new(0, maxW(), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.codeBg, BorderSizePixel = 0, LayoutOrder = layoutOrder}, parent)
	corner(block, 12)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, block)
	table.insert(resizers, function() block.Size = UDim2.new(0, maxW(), 0, 0) end)

	-- ZIndex 5 so the top bar and the floating Copy button draw above the code text
	local top = new("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.codeTop, BorderSizePixel = 0,
		LayoutOrder = 1, ZIndex = 5}, block)
	corner(top, 12)
	new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = C.codeTop, BorderSizePixel = 0, ZIndex = 5}, top)
	new("TextLabel", {Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
		Text = (lang ~= "" and lang or "code"), TextColor3 = Color3.fromRGB(170, 170, 190),
		Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, top)
	local copyBtn = new("TextButton", {Size = UDim2.fromOffset(70, BTN_H), Position = UDim2.new(1, -78, 0, 5),
		BackgroundColor3 = Color3.fromRGB(80, 80, 104), Text = "Copy", TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium, TextSize = 12, ZIndex = 7}, top)
	corner(copyBtn, 6)
	stroke(copyBtn, Color3.fromRGB(110, 110, 140), 1)

	local tb = new("TextBox", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Text = code, TextColor3 = C.codeText, Font = Enum.Font.Code, TextSize = 13,
		TextWrapped = true, MultiLine = true, TextEditable = false, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, block)
	pad(tb, 10, 12, 12, 12)

	table.insert(stickies, {block = block, top = top, btn = copyBtn})

	copyBtn.MouseButton1Click:Connect(function()
		local done = false
		if clipFn then done = pcall(clipFn, code) end
		if done then
			copyBtn.Text = "Copied!"
		else
			pcall(function()
				tb:CaptureFocus()
				tb.SelectionStart = 1
				tb.CursorPosition = #tb.Text + 1
			end)
			copyBtn.Text = "Selected"
		end
		task.delay(1.5, function() copyBtn.Text = "Copy" end)
	end)
	return block
end

local function renderAIContent(col, text, note)
	text = tostring(text or "")
	for _, c in ipairs(col:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if type(note) == "string" and note ~= "" then
		local nl = new("TextLabel", {Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1, Text = note, TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0}, col)
		local sc = new("UISizeConstraint", {MaxSize = Vector2.new(maxW() - 26, math.huge)}, nl)
		table.insert(resizers, function() sc.MaxSize = Vector2.new(maxW() - 26, math.huge) end)
	end
	local segs = parseMarkdown(text)
	if #segs == 0 then segs = {{k = "text", v = text}} end
	for i, s in ipairs(segs) do
		if s.k == "code" then codeBlock(col, s.lang, s.v, i) else textBubble(col, s.v, false, i) end
	end
end

local function addUserRow(text)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
	new("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder}, row)
	textBubble(row, text, true, 1)
	return row
end

local function addAIRow()
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = nextOrder()}, scroll)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top}, row)
	local av = makeLogo(34, row, nil, 17)
	av.LayoutOrder = 1
	local col = new("Frame", {Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1, LayoutOrder = 2}, row)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, col)
	return row, col
end

-- Chats / history
local renderHistory, openChat, deleteChat

local function trimMessages(chat)
	while #chat.messages > MAX_MSGS do table.remove(chat.messages, 1) end
end

local function renderMessages(chat)
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	resizers = {}
	stickies = {}
	order = 0
	if chat and #chat.messages > 0 then
		welcome.Visible = false
		scroll.Visible = true
		for _, m in ipairs(chat.messages) do
			if m.r == "user" then
				addUserRow(m.t)
			else
				local _, col = addAIRow()
				renderAIContent(col, m.t, m.n)
			end
		end
		scrollDown()
	else
		scroll.Visible = false
		welcome.Visible = true
	end
end

function renderHistory()
	for _, c in ipairs(histList:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	histEmpty.Visible = #chats == 0
	for i, chat in ipairs(chats) do
		local active = (chat == current)
		local item = new("Frame", {Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = active and Color3.new(1, 1, 1) or C.side, BorderSizePixel = 0, LayoutOrder = i}, histList)
		corner(item, 10)
		if active then stroke(item) end
		local b = new("TextButton", {Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1, Text = chat.title,
			TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd}, item)
		pad(b, 0, 0, 10, 0)
		local del = new("TextButton", {Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -30, 0.5, -13),
			BackgroundTransparency = 1, Text = "x", TextColor3 = C.sub, Font = Enum.Font.GothamBold,
			TextSize = 14}, item)
		b.MouseButton1Click:Connect(function() openChat(chat) end)
		del.MouseButton1Click:Connect(function() deleteChat(chat) end)
	end
end

function openChat(chat)
	setSettings(false)
	current = chat
	renderMessages(chat)
	renderHistory()
end

function deleteChat(chat)
	local idx = table.find(chats, chat)
	if idx then table.remove(chats, idx) end
	if current == chat then
		current = nil
		renderMessages(nil)
	end
	renderHistory()
	save()
end

newChat.MouseButton1Click:Connect(function()
	setSettings(false)
	current = nil
	renderMessages(nil)
	renderHistory()
end)

-- Sending
local function send(text)
	text = tostring(text or "")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	if busy or unloaded or text == "" then return end
	text = cut(text, 2000)
	busy = true
	box.Text = ""

	local chat = current
	if not chat then
		chat = {id = "c" .. os.time() .. math.random(100, 999), title = cut(text, 28), messages = {}}
		table.insert(chats, 1, chat)
		while #chats > MAX_CHATS do table.remove(chats) end
		current = chat
	end
	table.insert(chat.messages, {r = "user", t = text})
	trimMessages(chat)

	welcome.Visible = false
	scroll.Visible = true
	addUserRow(text)
	renderHistory()
	save()

	local row, col = addAIRow()
	local _, lbl = textBubble(col, ".", false, 1)
	scrollDown()

	local alive = true
	local stage = aware and "Reading your request" or "Thinking"
	local function setStage(s) stage = s end
	task.spawn(function()
		local n = 0
		while alive and not unloaded do
			n = n % 3 + 1
			lbl.Text = stage .. string.rep(".", n)
			task.wait(0.35)
		end
	end)

	task.spawn(function()
		local history = {}
		for i = math.max(1, #chat.messages - 19), #chat.messages do
			history[#history + 1] = {r = chat.messages[i].r, t = chat.messages[i].t}
		end
		local ok, res = pcall(askAI, history, setStage)
		alive = false
		if unloaded then busy = false return end

		if ok and type(res) == "table" and res.ok and type(res.text) == "string" then
			table.insert(chat.messages, {r = "ai", t = res.text, n = res.note})
			trimMessages(chat)
			save()
			if current == chat and row.Parent then
				renderAIContent(col, res.text, res.note)
				scrollDown()
			end
		else
			local msg
			if ok and type(res) == "table" and res.text then
				msg = tostring(res.text)
			else
				msg = "Script error: " .. tostring(res)
			end
			if current == chat and row.Parent then
				renderAIContent(col, "Error: " .. msg)
				scrollDown()
			end
		end
		busy = false
	end)
end

sendBtn.MouseButton1Click:Connect(function() send(box.Text) end)
box.FocusLost:Connect(function(enter) if enter then send(box.Text) end end)
for i, b in ipairs(chipButtons) do
	b.MouseButton1Click:Connect(function() send(chips[i]) end)
end

-- Startup
chats = loadChats()
renderHistory()
updateScanUI()
if aware then startScan() end
if not hasFS then
	showToast("No file access: chats won't be saved")
elseif #requestFns <= 1 then
	showToast("No executor HTTP function found")
end
