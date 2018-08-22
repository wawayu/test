local BugReport = require "Common.BugReport"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[问题反馈]]

function M:Awake()
	base.Awake(self)
	
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.txtDesc = self:FindText("TxtDesc")
	self.txtDesc.text = Lan("problem_desc")

	self.txtTitleInputField = self:FindInputField("Title/InputField")
	self.txtContentInputField = self:FindInputField("Content/InputField")
end

function M:Show()
	base.Show(self)

	self:RefreshPanel()
end

function M:RefreshPanel()
	self.txtTitleInputField.text = ""
	self.txtContentInputField.text = ""
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnSubmit" then
		local strTitle = self.txtTitleInputField.text
		local strContent = self.txtContentInputField.text
		if string.isEmpty(strTitle) then
			Tips("标题不能为空")
			return
		end
		if string.isEmpty(strContent) then
			Tips("内容不能为空")
			return
		end

		strContent = string.gsub(BugReport.GetSystemInfo()..strContent, "\n", "<br>")
		--提交到禅道
		BugReport.CreateByZentaoPHP(strTitle, nil, nil, strContent)
		--通过引导方式获取第一次反馈的成就奖励
		guideMgr.SetGuideBranch(25)
		self:RefreshPanel()
	end
end

return M