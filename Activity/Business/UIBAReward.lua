---演武、讨伐、平蛮、丝绸之路、挖宝、铜雀台奖励

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

	self.imgActivityDesc = self:FindImage("Top/ImageDesc1", self.transOffset) 
	
	self.textProgress = self:FindText("Top/TxtProgress", self.transOffset)

    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)
end

function M:Show()
	base.Show(self)
	
	self:ResetData()
end

function M:ResetData()
	if not self.data.id then
		return
	end

	self.dataHandler = BusinessData.GetScript(self.data.id)
	if not self.dataHandler then
		self:Hide()
		return
	end

	self.activityID = self.data.id
	self.businessTab = BusinessActivityTable[self.activityID]

	self.activityRewardList = self.businessTab.rewardconfig

	self.uiSrollView:SetActive(true)

	--刷新UILoop
	self.uiItemLoop.ItemsCount = #self.activityRewardList

	--内容
	self.txtContent.text = self.businessTab.desc

	self.endTime = self.dataHandler:GetEndTime()

	UITools.SetImageIcon(self.imgActivityDesc, Const.atlasName.Activity, self.businessTab.param2.descIcon, true)

	if self.businessTab.param2 and self.businessTab.param2.progressDesc then
		self.textProgress.text = string.format(self.businessTab.param2.progressDesc, self.dataHandler:GetJoinCount(self.activityID))
	else
		self.textProgress.text = ""
	end
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
	local rewardData = self:GetLoopItem(index)
	if rewardData == nil then
		return
	end
	self.dataHandler:SendGetReward(index, true)
end

function M:UpdateItem(index, coms)
	local rewardData = self:GetLoopItem(index)
	if rewardData == nil then
		return
	end
		
	--名称,图标
	coms.txtName.text = string.format(self.businessTab.itemdesc, rewardData.score)
	local status = self.dataHandler:GetSingleStatus(index)

	coms.uiGet:SetActive(status == 1)
	coms.uiDone:SetActive(status == 2)
	coms.uiCantGet:SetActive(status == 0)
	

	-- 刷新奖励
	UITools.CopyRewardList({rewardData.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
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