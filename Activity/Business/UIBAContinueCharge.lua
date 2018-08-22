-- 连续充值奖励
local PlayerData = require "Data.PlayerData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true}

local base = require "UI.UILuaBase"
local M = base:Extend()

function M:Awake()
	base.Awake(self)

    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")

	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtLeft", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	self.textCharge = self:FindText("Top/TextCharge", self.transOffset)

	self.transEmpty = self:FindTransform("Offset/Empty")
	--UIloop
	self.uiLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem)
end

function M:Show()
	base.Show(self)

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end
	
	self.businessTab = BusinessActivityTable[self.data.id]
	if not self.businessTab then
		self:Hide()
		return
	end

	self:ResetData()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
	end
end

function M:OnClick(go)
	local btnName = go.name
	
end

function M:ResetData()
	if not self.data.id or not self.businessTab  then
		self.uiLoop.ItemsCount = 0
		self.transEmpty.gameObject:SetActive(true)
		return
	end
	self.rewardConfigs = self.script:GetRewards()

	self.chargeGoldToday = dataMgr.RechargeData.GetChargeNumToday()

	self.chargeValue = self.businessTab.param1.gold
	self.textCharge.text = string.format("今日进度:%s/%s", self.chargeGoldToday, self.chargeValue)

	local info = self.script:Info()
	self.progress = (info and info.intparam) or 0

	--右边奖励
	self.uiLoop.ItemsCount = #self.rewardConfigs
	self.transEmpty.gameObject:SetActive(#self.rewardConfigs == 0)

	--内容
	self.txtContent.text = self.businessTab.desc

	self.endTime = self.script:GetEndTime()
end

function M:GetLoopItem(index)
	return self.rewardConfigs[index]
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TextDesc", coms.trans)--活动名称
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	coms.textProgress = self:FindText("TextProgress", coms.trans)

	coms.goGet = self:FindGameObject("ButtonGet", coms.trans)--领取
	coms.goDone = self:FindGameObject("ButtonDone", coms.trans)--已领取
	coms.goNot = self:FindGameObject("ImageNot", coms.trans)

	--领取
	UguiLuaEvent.ButtonClick(coms.goGet, nil, function(go)
		self:OnChoose(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:UpdateItem(index, coms)
	local data = self:GetLoopItem(index)
	local id = data.id
	local progress = self.progress >= id and id or self.progress
	coms.txtName.text = string.format("充值%s元宝累计%s天", self.chargeValue, id)
	coms.textProgress.text = string.format("进度:%s/%s", progress, id)
	-- 刷新奖励
	UITools.CopyRewardList({data.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)

	local status = self.script:Status(id)
	coms.goDone:SetActive(status == 2)
	coms.goGet:SetActive(status == 1)
	coms.goNot:SetActive(status == 0)
end

function M:OnChoose(index, go)
	local data = self:GetLoopItem(index)
	self.script:SendGetReward(data.id)
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	else
		self.textTime.text = "--"
	end
end

return M