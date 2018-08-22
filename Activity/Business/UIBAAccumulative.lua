
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
local preUpdateTime = -999
local rewardExParams = {isnative = true, showQualityEffect = true}

--[[累计充值]]

function M:Awake()
	base.Awake(self)
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.transOffset = self:FindTransform("Offset")

	--
	self.uiEmptyRoot = self:FindGameObject("Empty", self.transOffset)
	self.uiSrollView = self:FindGameObject("Scroll View", self.transOffset)

	--倒计时
	self.textTime = self:FindText("Top/LeftTime/TxtTime", self.transOffset)
	--内容
	self.txtContent = self:FindText("Top/Desc/TxtContent", self.transOffset)
	--跳转按钮
	self.uiBtnGo = self:FindGameObject("Top/BtnGo", self.transOffset)
	self.txtBtnGo = self:FindText("Top/BtnGo/TxtNum", self.transOffset)

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)
end

function M:Show()
	base.Show(self)

	if self.data.id then
		self.businessTab = BusinessActivityTable[self.data.id]
	end
	
	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	self:ResetData()
end

function M:ResetData()
	if not self.data.id or not self.businessTab  then
		return
	end

	self.activityRewardList = self.script:GetRewards()
	self.chargeNumToday = dataMgr.RechargeData.GetChargeNumToday()

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

	self.endTime = BusinessData.GetEndTime(self.data.id)
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
	local rewardData = self.activityRewardList[index]
	if rewardData ~= nil and not self.script:IsRewardGot(rewardData.id) then
		self.script:SendGetReward(rewardData.id)
	end
end

function M:UpdateItem(index, coms)
	local rewardData = self:GetLoopItem(index)
	if rewardData == nil then
		return
	end
		
	--名称,图标
	coms.txtName.text = string.format(self.businessTab.itemdesc, rewardData.money)
	local status = self.script:Status(rewardData.id)

	coms.uiGet:SetActive(status == 1)
	coms.uiDone:SetActive(status == 2)
	coms.uiCantGet:SetActive(status == 0)
	
	--todo，累计充值
	coms.txtCurRecharge.text = string.format("%d/%d", self.chargeNumToday ,rewardData.money)

	-- 刷新奖励
	UITools.CopyRewardList({rewardData.reward}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
end

function M:UpdateChild()
	if self.endTime then
		self.textTime.text = string.format("<color=#2cffee>%s</color>", Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime()))
	end
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnGo" then
		if self.businessTab and self.businessTab.goMenuID then
			local MenuEventManager = require "Manager.MenuEventManager"
			MenuEventManager.DoMenu(self.businessTab.goMenuID)
		end
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Recharge then
		self:ResetData()
	elseif cmd == LocalCmds.Record then
		self:ResetData()
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end


return M