--[[
	投资计划
]]

local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local rewardExParams = {isnative = true}
local preUpdateTime = -1

function M.Open()
	OpenUI("UIReward", {panelIndex=8})
end

function M:Awake()
	base.Awake(self)

	self.textMoney = self:FindText("Offset/Top/ButtonsStatus/ButtonGreen/Text")
	self.transMoneyGreen = self:FindTransform("Offset/Top/ButtonsStatus/ButtonGreen")
	self.transMoneyNot = self:FindTransform("Offset/Top/ButtonsStatus/ImgNot")
	self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem)

	UguiLuaEvent.ButtonClick(self.transMoneyGreen.gameObject, nil, function(go)
		self:OnClickGo()
	end)
end

function M:Show()
	base.Show(self)

	self:ResetData()
end

function M:ResetData()
	local bid = Const.BUSINESS_INVEST_CHARGE
	if not bid then
		Debugger.LogWarning("uibagroupbuy error no bid")
		return
	end

	self.businessTab = BusinessActivityTable[bid]
	if not self.businessTab then
		Debugger.LogWarning("BusinessActivityTable error no bid:"..tostring(bid))
		return
	end

	self.rewardConfig = BusinessData.GetInvestmentRewards()
	table.sort(self.rewardConfig, M.SortFunc)

	self.player = dataMgr.PlayerData.GetRoleInfo()
	self.playerLv = (self.player and self.player.lv or 0)

	local param1 = self.businessTab and self.businessTab.param1
	self.chargeid = param1 and param1.chargeid
	local chargeTab = excelLoader.ChargeTable[self.chargeid]
	if chargeTab then
		local money = math.ceil(chargeTab.rmb / 100 )
		self.textMoney.text = money.."元购买"
	else
		self.textMoney.text = "--"
	end
	
	self.buyInfo = dataMgr.RechargeData.GetRechargeInfoById(self.chargeid)
	self.transMoneyGreen.gameObject:SetActive(self.buyInfo == nil)
	self.transMoneyNot.gameObject:SetActive(self.buyInfo ~= nil)

	self.uiLoop.ItemsCount = #self.rewardConfig

	self.parent:CheckActive()
end

function M:Update()
	base.Update(self)

end

function M:GetLoopItem(idx)
    return self.rewardConfig[idx]
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtName", coms.trans)
	coms.textCost = self:FindText("Cost/TextPrice", coms.trans)
	coms.transNot = self:FindImage("ButtonsStatus/ImgNot", coms.trans)
	coms.transDone = self:FindImage("ButtonsStatus/BtnDone", coms.trans)
	coms.transGreen = self:FindImage("ButtonsStatus/ButtonGreen", coms.trans)

	--领取
	UguiLuaEvent.ButtonClick(coms.transGreen.gameObject, nil, function(go)
		self:OnChoose(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	local data = self:GetLoopItem(index)
	BusinessData.SendGetInvestment(data.id)
end

function M:UpdateItem(index, coms)
	local cfg = self:GetLoopItem(index)
	local status = BusinessData.GetInvestmentStatus(cfg.id)
	coms.txtName.text = cfg.lv.."级"
	coms.textCost.text = cfg.gold

	coms.transDone.gameObject:SetActive(status == 2)
	coms.transNot.gameObject:SetActive(status == 0)
	coms.transGreen.gameObject:SetActive(status == 1)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
    end
end

--跳转
function M:OnClickGo()
	if not self.buyInfo and self.chargeid then
		require("SDK.PayOrderRequest").RequestOrder(self.chargeid)
	end
end

function M.SortFunc(a, b)
	local s1 = BusinessData.GetInvestmentStatus(a.id)
	local s2 = BusinessData.GetInvestmentStatus(b.id)
	if s1 == 1 then s1 = -1 end
	if s2 == 1 then s2 = -1 end

	if s1 == s2 then
		return a.id < b.id
	else
		return s1 < s2
	end
end


return M