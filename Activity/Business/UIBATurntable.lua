--[[
	元宝抽奖
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

local preUpdateTime = -1
local panelLen = 2		-- 礼包奖励长度
local rewardExParams = {isnative = true}
local moneyGet = 0
local ConstLen = 8
local TT = dataMgr.BusinessData.CreateTable(ConstLen)

local targetItem,endCallback

local strReward = "恭喜玩家<color=#2ea7ec>%s</color>喜获<color=#18A338FF>%s</color>倍赐福，获得元宝<color=#18A338FF>%s</color>"

--- targetItem 1.2 倍率
local bid	-- 活動id
function M.Open(params)
	bid = params and params.id or BusinessData.GetMammonID()
	if not bid then
		return
	end
    uiMgr.ShowAsync("UIBATurntable")
end

function M:Awake()
	base.Awake(self)

	self.textTime = self:FindText("Offset/Right/TextTime")
	self.textReward = self:FindText("Offset/Left/TextReward")

	self.transButtonOK = self:FindTransform("Offset/Right/ButtonOK")
	self.transButtonDone = self:FindTransform("Offset/Right/ButtonDone")
	self.transButtonAllDone = self:FindTransform("Offset/Right/ButtonAllDone")
	self.textNumOk = self:FindText("TextNum", self.transButtonOK)
	self.textCostOK = self:FindText("TextCost", self.transButtonOK)
	self.textNumDone = self:FindText("TextNum", self.transButtonDone)
	self.textCostDone = self:FindText("TextCost", self.transButtonDone)

	self.transPointer = self:FindTransform("Offset/Right/Pointer")
	self.textTips = self:FindText("Offset/Right/TextTips")

	UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

	TT.Init(self.transPointer, function()
		self:AnimationEnd()
	end)
end

function M:Show()
	base.Show(self)

	self.bConf = excelLoader.BusinessActivityTable[bid]
	self.script = BusinessData.GetScript(bid)
	if self.bConf == nil or not self.script then
		self:Hide()
		return
	end
	-- 倍数顺序
	local order = self.bConf.param2 and self.bConf.param2.order
	self.multipleConf = {}
	for i,v in ipairs(order) do
		self.multipleConf[i] = math.floor(v * 10)
	end

	moneyGet = 0
	self.startTime = -1
	TT.Reset()
	
	self:ResetData()

	-- 请求祈福列表数据
	BusinessData.RequestBusinessInfo()
end

function M:ResetData()
	self.nowDay, self.isCharged = self.script:GetMammonCharge()

	self:UpdateRewardList()

	self:UpdateRemain()
	self.endTime = BusinessData.GetEndTime(bid)
	if self.endTime <= 0 then
		Tips("活动结束")
		self:Hide()
	end
end

function M:UpdateRewardList()
	local blesslist = self.script:GetMammonList()

	local r
	local strText = ""
	for i=1,5 do
		local index = #blesslist + 1 - i
		if index > 0 then
			r = blesslist[index]
			if r then
				strText = textBuilder.AppendTrim(strText, string.format(strReward, r.name, r.rate/10, r.get))
			end
		end
	end
	self.textReward.text = strText
end

function M:UpdateRemain()
	local remainNum, useNum = self.script:GetMammonRemain()
	local color = remainNum > 0 and "18A338FF" or "aa0000"

	self.transButtonAllDone.gameObject:SetActive(remainNum == 0)
	self.transButtonDone.gameObject:SetActive(false)
	self.transButtonOK.gameObject:SetActive(remainNum > 0)
	
	self.textNumOk.text = "次数:"..remainNum
	self.textNumDone.text = "次数:"..remainNum

	self.costItem = self.bConf.param1.cost[useNum+1] or {}
	self.textCostOK.text = self.costItem.num
	self.textCostDone.text = self.costItem.num

	self.textTips.text = ""
end

function M:OnClick(go)
	local name = go.name

	if name == "ButtonClose" then
		self:Hide()
	elseif name == "ButtonOK" then
		self:OnClickOK()
	elseif name == "ButtonDone" then
		Tips("次数已用完")
	elseif name == "ButtonAllDone" then
		Tips("次数已用完")
	elseif name == "ButtonTips" then
		Hint({content = Lan("rule_gold_table") , rectTransform = go.transform, alignment = 0})
	end
end

function M:StartRotate()

	local fitResults = {}
	for i=1,ConstLen do
		if self.multipleConf[i] == targetItem then
			table.insert(fitResults, i)
		end
	end
	local ran = math.random(1, #fitResults)
	local index = fitResults[ran]
	if not index then
		Debugger.LogWarning("财神赐福获取index失败")
		return
	end
	
	self.startTime = Time.time
	TT.Start(Time.time, index)
end

function M:OnClickOK()
	if self.startTime and self.startTime > 0 then
		Tips("赐福中")
		return
	end

	local remainNum, useNum = self.script:GetMammonRemain()
	if remainNum <= 0 then
		Tips("剩余次数不足")
		return
	end

	local vip = PlayerData.GetRoleInfo().vip
	local limit = self.bConf.limit
	local needVip = limit and limit.vip
	if needVip and vip < needVip then
		local str = string.format("%s需要VIP%s级以上才能参加\n是否前往充值?",self.bConf.name,needVip)
		UIMsgbox.ShowChoose(str, function(ok, param)
			if ok == true then              
				OpenUI("UIRecharge")
			end
		end, nil, "提示")
		return
	end

	if not dataMgr.PlayerData.CheckItemsNum({self.costItem}, true, true) then
		return
	end
	
	self.script:SendMammonBless(bid)
end

function M:Hide()
	self:End()

	base.Hide(self)
end

function M:Update()
	base.Update(self)

	TT.UpdateTable()

	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time

	if self.endTime then
		local curTime = netMgr.mainClient:GetServerTime()
		self.textTime.text = Utility.GetVaryTimeFormat(self.endTime - curTime)

		if self.endTime < 0 then
			self:ResetData()
		end
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business and msg then
		if msg.cmd == Cmds.MammonBless.index then
			if msg.pb then
				moneyGet = msg.pb.get
				targetItem = msg.pb.rate
				self:StartRotate()
			end
		elseif msg.cmd == Cmds.GetBusinessActivityInfo.index then
			self.script:SetMammonList()
			self:ResetData()
		end
	elseif cmd == LocalCmds.Recharge then
		BusinessData.RequestBusinessInfo()
    end
end

function M:End()
	if endCallback then
		local _endCallback = endCallback
		endCallback = nil
		_endCallback()
	end

	if moneyGet > 0 then
		local item = {itemid = Const.ITEM_ID_VCOIN, num = moneyGet}
		dataMgr.PlayerData.ShowAddItems({item}, true)
		moneyGet = -1

		BusinessData.RequestBusinessInfo()
	end
end

function M:Hide()
	self:End()

	base.Hide(self)
end

function M:AnimationEnd()
	self.startTime = -1
	self:End()
	self:ResetData()
end

return M