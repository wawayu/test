
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"
local rewardExParams = {isnative = true, showQualityEffect = true}

local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

local preUpdateTime = -999

--[[进阶]]

function M:Awake()
	base.Awake(self)
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")

	--
	self.uiEmptyRoot = self:FindGameObject("Empty", self.transOffset)
	self.uiSrollView = self:FindGameObject("Scroll View", self.transOffset)

	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtLeft", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	--跳转按钮
	self.uiBtnGo = self:FindGameObject("Top/BtnGo", self.transOffset)
	self.txtBtnGo = self:FindText("Top/BtnGo/Text", self.transOffset)

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)

end

function M:Show()
	base.Show(self)

	self.businessTab = BusinessActivityTable[self.data.id]

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	self:ResetData()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		if msg.cmd == Cmds.GetBackReward.index or msg.cmd == Cmds.GetGetBackInfo.index then
			self:ResetData()
		end
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGo" then
		--进阶
		self:OnClickGo()
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	end
end

--跳转
function M:OnClickGo()
	if self.businessTab and self.businessTab.goMenuID then
		local MenuEventManager = require "Manager.MenuEventManager"
		MenuEventManager.DoMenu(self.businessTab.goMenuID)
	end
end

function M:ResetData()
	if not self.data.id or not self.businessTab  then
		return
	end

	self.activityRewardList = self.script:GetRewards()
	
	self.uiEmptyRoot:SetActive(false)
	self.uiSrollView:SetActive(true)

	--刷新UILoop
	self.uiItemLoop.ItemsCount = #self.activityRewardList

	--跳转按钮
	self.uiBtnGo:SetActive(self.businessTab.goMenuID ~= nil)
	if self.businessTab.buttonname then
		self.txtBtnGo.text = self.businessTab.buttonname
	end

	--内容
	self.txtContent.text = self.businessTab.desc

	self.endTime = self.script:GetEndTime()
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
	coms.uiNot = self:FindGameObject("ImgNot", coms.trans)
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	--领取
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnChoose(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	local rewardData = self:GetLoopItem(index)
	self.script:SendGetReward(rewardData.id)
end

function M:GetLoopItem(index)
	return self.activityRewardList[index]
end

function M:UpdateItem(index, coms)
	local rewardData = self:GetLoopItem(index)
	local id = rewardData.id
	--名称,图标
	coms.txtName.text = self.script:GetUpgradeDesc(id)

	local status = self.script:Status(id)
	coms.uiNot:SetActive(status == 0)
	coms.uiGet:SetActive(status == 1)
	coms.uiDone:SetActive(status == 2)

	-- 刷新奖励
	UITools.CopyRewardList({rewardData.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end
end

return M