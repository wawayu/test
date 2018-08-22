local base = require "UI.UILuaBase"
local M = base:Extend()

--[[激活码]]

function M:Awake()
	base.Awake(self)

    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.txtContentInputField = self:FindInputField("InputFieldTitle")

	effectMgr:SpawnToUI("2d_duihuanma_jl", Vector3.zero, self.rectTransform, 0)
end

function M:Show()
	base.Show(self)

	self:RefreshPanel()
end

local strDefaultContent = "请输入兑换码"

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnSure" then
		--提交
		local strContent = self.txtContentInputField.text
		if strContent == "" or strContent == strDefaultContent then
			Tips("请输入正确的兑换码")
			return
		end
		
		self:RefreshPanel()
		dataMgr.RewardData.RequestGiftCode(strContent)
		--Tips("兑换码已发送")
	elseif btnName == "BtnPaste" then
		--粘贴
	end
end

function M:RefreshPanel()
	self.txtContentInputField.text = ""
end

return M