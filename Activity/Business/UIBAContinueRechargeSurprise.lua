---连充惊喜

local PlayerData = dataMgr.PlayerData
local ItemData = dataMgr.ItemData
local BusinessData = dataMgr.BusinessData

local BusinessActivityTable = excelLoader.BusinessActivityTable

local base = require "UI.UILuaBase"
local M = base:Extend()
local rewardExParams = {isnative = true, showQualityEffect = true}

local DayCountMax = 6

function M:Awake()
	base.Awake(self)
	self.transOffset = self:FindTransform("Offset")
	--倒计时
	self.textTime = self:FindText("LeftTime/TxtTime", self.transOffset)
	self.imageBar = self:FindImage("Offset/Slider/ImageBar")

	self.transPoint = {}
	for i=1, DayCountMax do
		local trans = self:FindTransform(string.format("Offset/Slider/Grid/Point (%d)",i))
		self:FindText("Text", trans).text = string.format("第%s天", UITools.GetChineseNumber(i))
		self.transPoint[i] = trans		
	end

	self.lastReward = {
		uiGet = self:FindGameObject("BtnGet", self.transOffset),--领取
		uiDone = self:FindGameObject("BtnDone", self.transOffset),--已领取
		uiCantGet = self:FindGameObject("ImgCantGet", self.transOffset)--未达成
	}

	self.transRewardItem = self:FindTransform("Offset/RewardList/Viewport/Grid/Item")
	self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.OnUpdateItem)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/BtnGet"), self, M.OnClickGet)	
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
	self.reward = self.businessTab.rewardconfig.rewardid
	self.needGold = self.businessTab.rewardconfig.gold
	self.showReward = self.reward[#self.reward]
	self.uiLoop.ItemsCount = #self.reward - 1

	self.endTime = self.dataHandler:GetEndTime()
	-- 刷新奖励
	if not self.showRewardGoList then self.showRewardGoList = {} end
	UITools.CopyRewardList({self.showReward}, self.showRewardGoList, self.transRewardItem, rewardExParams)

	-- local day = BusinessData.GetRechargeSurpriseContinueDays()
	-- local v = 0
	-- if day > 1 then
	-- 	v = (day-1)/(DayCountMax-1)
	-- 	v = math.min(v, 1)
	-- end
	self.imageBar.transform.localScale = Vector3.New(0, 1, 1)
	for i=1, DayCountMax do
		local status = self.dataHandler:GetSingleStatus(i)
		UITools.SetAllChildrenGrey(self.transPoint[i], status==0)
	end

	local status = self.dataHandler:GetStatus()
	UITools.SetActive(self.lastReward.uiGet, status == 1)
	UITools.SetActive(self.lastReward.uiDone, status == 2)
	UITools.SetActive(self.lastReward.uiCantGet, status == 0)
end

function M:GetLoopItem(index) 
	return self.activityRewardList[index]
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

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.textName = self:FindText("TextDay", trans) 
    coms.transItem = {
		self:FindTransform("Item1", trans), 
        self:FindTransform("Item2", trans), 
		self:FindTransform("Item3", trans) 
	}
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
	coms.uiCantGet = self:FindGameObject("ImgCantGet", coms.trans)--未达成
		--领取
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnChoose(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, coms)
	self.dataHandler:SendGetReward(index)
end

function M:OnUpdateItem(index, coms)
	local rewardid = self.reward[index]
	local items = ItemData.GetRewardList({rewardid})
	coms.textName.text = string.format("第%s天", UITools.GetChineseNumber(index))
	for i=1, 3 do
		UITools.SetItemInfo(coms.transItem[i], items[i], false, true, true)
	end
	local status = self.dataHandler:GetSingleStatus(index)
	UITools.SetActive(coms.uiGet, status == 1)
	UITools.SetActive(coms.uiDone, status == 2)
	UITools.SetActive(coms.uiCantGet, status == 0)
end

---领取
function M:OnClickGet(go)
	self.dataHandler:SendGetReward(self.dataHandler:GetRechargeSurpriseMaxIndex())
end

return M