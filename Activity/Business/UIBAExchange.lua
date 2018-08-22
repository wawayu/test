--[[
	单笔充值
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

local strDefaultContent = "请输入兑换码"

function M:Awake()
	base.Awake(self)

	--按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.txtContentInputField = self:FindInputField("Offset/InputFieldTitle")
end

function M:Show()
	base.Show(self)

	self:ResetData()
end

function M:ResetData()
	self.txtContentInputField.text = ""
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnSure" then
		--提交
		local strContent = self.txtContentInputField.text
		if strContent == "" or strContent == strDefaultContent then
			Tips("请输入正确的兑换码")
			return
		end
		
		self:ResetData()
		dataMgr.RewardData.RequestGiftCode(strContent)
		Tips("兑换码已发送")
	elseif btnName == "BtnPaste" then
		--粘贴
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		
    end
end

return M