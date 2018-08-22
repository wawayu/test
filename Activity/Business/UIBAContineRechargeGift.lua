---连充豪礼

local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local rewardExParams = {isnative = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)
	self.transOffset = self:FindTransform("Offset")
	self.uiSrollView = self:FindGameObject("Scroll View", self.transOffset)
	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtTime", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)

	self.textProgress = self:FindText("Top/TxtProgress", self.transOffset)

    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)
end

function M:Show()
	base.Show(self)

	self:ResetData()
end

function M:ResetData()
	if not self.data.id  then
		return
	end
	
	self.dataHandler = BusinessData.GetScript(self.data.id)
	if not self.dataHandler then
		self:Hide()
		return
	end

	self.activityID = self.data.id
	self.businessTab = BusinessActivityTable[self.activityID]
	self.needGold = self.businessTab.rewardconfig.gold
	self.activityRewardList = self.businessTab.rewardconfig.rewardid

	self.uiSrollView:SetActive(true)

	--刷新UILoop
	self.uiItemLoop.ItemsCount = #self.activityRewardList

	--内容
	self.txtContent.text = self.businessTab.desc

	local day = self.dataHandler:GetActivityOpenDay(self.activityID)
	self.textProgress.text = string.format("今日进度：%d/%d", self.dataHandler:GetProgress(day))

	self.endTime = self.dataHandler:GetEndTime()
end

function M:GetLoopItem(index) 
	return self.activityRewardList[index]
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
	coms.uiCantGet = self:FindGameObject("ImgCantGet", coms.trans)--未达成
	coms.txtCurRecharge = self:FindText("TxtNum", coms.trans)--当前充值
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	--领取
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnChoose(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	self.dataHandler:SendGetReward(index, true)
end

function M:UpdateItem(index, coms)
	local rewardid = self:GetLoopItem(index)
	if rewardid == nil then
		return
	end
		
	--名称,图标
	coms.txtName.text = string.format(self.businessTab.itemdesc, self.needGold, index)
	local status = self.dataHandler:GetSingleStatus(index)
	UITools.SetActive(coms.uiGet, status == 1)
	UITools.SetActive(coms.uiDone, status == 2)
	UITools.SetActive(coms.uiCantGet, status == 0)	

	-- 刷新奖励
	UITools.CopyRewardList({rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
end

function M:UpdateChild()
	if self.endTime then
		self.textTime.text = string.format("<color=#2cffee>%s</color>", Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime()))
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Record then
		self:ResetData()
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M