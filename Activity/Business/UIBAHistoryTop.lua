
local base = require "UI.UILuaBase"
local M = base:Extend()
local idrule	= require "IdRule"

--[[历史榜单]]

function M:Awake()
	base.Awake(self)

end

function M:Show()
	base.Show(self)

	CloseUI("UIBusinessActivity")
	OpenUI("UITop", {topType = idrule.TopBackIndex(Const.TOP_INDEX_BASCORE_HERO)})
end

return M