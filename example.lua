local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/test.guilib/refs/heads/main/skeet%20lib.lua"))()

local window = library:CreateWindow({})

local page = window:CreatePage({
	Icon = "rbxassetid://8547236654"
})

local section = page:CreateSection({
	Name = "Main",
	Size = 200,
	Side = "Left"
})
