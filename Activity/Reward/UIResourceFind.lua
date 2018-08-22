
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local RewardData = require "Data.RewardData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[资源找回]]

function M:Awake()
	base.Awake(self)
	
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.uiEmptyRoot = self:FindGameObject("Empty")
	self.uiSrollView = self:FindGameObject("Scroll View")

	--UIloop
	self.uiRewardLoop = self:FindLoop("Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiRewardLoop, M.OnCreateItem, M.UpdateItem)

	--toggle
	self.toggles = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("Top/BtnGetBack (%d)" , i))
		table.insert(self.toggles, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
        	if _isOn then
        		if i == 1 then
        			--普通找回
        			self.getBackType = 1
        		elseif i == 2 then
        			--完美找回
        			self.getBackType = 2
        		end

				self:RefreshPanel()
        	end
        end)
    end
end

function M:Show()
	base.Show(self)
	if not self.getBackType then
		self.getBackType=1
	end
	self.toggles[self.getBackType].isOn = true

	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		if msg.cmd == Cmds.GetBackReward.index or msg.cmd == Cmds.GetGetBackInfo.index then
			self:RefreshPanel()
		end
    end
end

function M:RefreshPanel()
	local getBackInfo = RewardData.GetAllGetBackInfo()
	if not getBackInfo or #getBackInfo == 0 then
		--没有可收回的（所有活动都做完了）
		self.uiEmptyRoot:SetActive(true)
		self.uiSrollView:SetActive(false)
	else
		--有可回收
		self.uiEmptyRoot:SetActive(false)
		self.uiSrollView:SetActive(true)

		--刷新UILoop
		self.uiRewardLoop.ItemsCount = #getBackInfo
	end
	
end

M.GetBackName = {"普通", "完美"}

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnOnekey" then
		--一键找回
		self:OnClickOnekey()
	elseif btnName == "BtnDesc" then
		--描述按钮
		Hint({rectTransform = go.transform, content = Lan("getback_desc"), alignment = 0})
	end
end

--一键找回
function M:OnClickOnekey()
	local num = self:CalOnekeyCostNum()
	if num == 0 then
		Tips(Lan("activity_res_getback_empty"))
		return
	end
	local itemid
	if self.getBackType == 1 then
		itemid = Const.ITEM_ID_SILVER
	elseif self.getBackType == 2 then
		itemid = Const.ITEM_ID_VCOIN
	end

	local str = string.format("是否愿意花费%s<color=#09ADFF>%d</color>一键找回所有资源？", UITools.FormatItemIconText(itemid), num) 
	require ("Data.TeamData").ShowMsgBox(str, 
		function()
			if dataMgr.PlayerData.CheckItemsNum({{itemid=itemid, num=num}}, true, true) then
				RewardData.RequestGetBackReward(0, self.getBackType)
			end
		end,
		function() end)
end

function M:CalOnekeyCostNum()
	--计算一键找回消耗
	local num = 0
	local getBackInfo = RewardData.GetAllGetBackInfo()
	if getBackInfo then
		for i,v in ipairs(getBackInfo) do
			if not v.reward then
				--未找回
				local rewardId,expendId = self:GetRewardIdAndExpendId(v.id)
				local expendTab = ExpendTable[expendId]
				if expendTab ~= nil then
					local expendData = expendTab.expend[1]
					-- print(expendData.num, getBackInfo.num)
					num = num + expendData.num * v.num
				end
			end
		end
	end
	return num
end

function M:GetRewardIdAndExpendId (activityId)
	local activityTab = ActivityTable[activityId]
	local rewardId = nil
	local expendId = nil
	if self.getBackType == 1 then
		--普通找回
		rewardId = activityTab.normalgetback
		expendId = activityTab.normalexpend
	elseif self.getBackType == 2 then
		--完美找回
		rewardId = activityTab.perfectgetback
		expendId = activityTab.perfectexpend
	end

	return rewardId,expendId
end

--道具
function M:OnCreateItem(index, coms)
	coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiFind = self:FindGameObject("BtnFind", coms.trans)--可找回
	coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已找回
	coms.uiCostItem = self:FindGameObject("CostItem", coms.trans)--消耗
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	--消耗
	coms.txtItemName = self:FindText("CostItem/TxtNum", coms.trans)
	coms.imgIcon = self:FindImage("CostItem", coms.trans)

	UguiLuaEvent.ButtonClick(coms.uiFind, nil, function(go)
		self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(coms.go) + 1, coms, 2)
	end)
end

--点击可找回按钮
function M:OnChoose(index, go, tp)
	if tp == 2 then
		--点击可找回按钮
		local getBackInfo = RewardData.GetGetBackInfoByIndex(index)
		if getBackInfo ~= nil then
			local activityId = getBackInfo.id
			local rewardId,expendId = self:GetRewardIdAndExpendId(activityId)

			--判断消耗
			local expendTab = ExpendTable[expendId]
			if dataMgr.PlayerData.CheckItemsNum(expendTab.expend, true, true) then
				--消耗充足，发包
				RewardData.RequestGetBackReward(activityId, self.getBackType)
			end
		end
	end
end

local itemCount = 5

function M:UpdateItem(index, coms)
	-- index = self.uiRewardLoop:GetItemGlobalIndex(go) + 1
	local getBackInfo = RewardData.GetGetBackInfoByIndex(index)
	if getBackInfo ~= nil then
		local activityTab = ActivityTable[getBackInfo.id]
		local groupId, expendId = self:GetRewardIdAndExpendId(getBackInfo.id)
	
		--活动名称
		coms.txtName.text = activityTab.name
		if getBackInfo.reward then
			--已找回
			coms.uiFind:SetActive(false)
			coms.uiDone:SetActive(true)
			coms.uiCostItem:SetActive(false)
		else
			--未找回
			coms.uiFind:SetActive(true)
			coms.uiDone:SetActive(false)
			coms.uiCostItem:SetActive(true)
		end

		--消耗
		local expendTab = ExpendTable[expendId]
		if expendTab ~= nil then
			local expendData = expendTab.expend[1]
			UITools.SetCostMoneyInfo(coms.txtItemName, coms.imgIcon, expendData.itemid, expendData.num*getBackInfo.num, "", true)
		else
			-- print("aaaaaaaaaaaaaaaaaa")
		end

		-- 刷新奖励
		-- if not self.loopContainer then
		-- 	self.loopContainer = {}
		-- end
		-- local localIndex = 1
		-- if index <= itemCount then
		-- 	localIndex = index
		-- else
		-- 	local rate = index%itemCount
		-- 	if rate == 0 then
		-- 		localIndex = itemCount
		-- 	else
		-- 		local mul = math.floor(index/itemCount)
		-- 		localIndex = index - itemCount*mul
		-- 	end
		-- end
		-- if not self.loopContainer[localIndex] then
		-- 	self.loopContainer[localIndex] = {}
		-- end
		local hightLv = self:GetRewardLv(groupId, PlayerData.GetRoleInfo().lv)
		local rewardGroupId = groupId * 1000 + hightLv
		local rewardGroupTab = excelLoader.RewardGroupplusTable[rewardGroupId]
		if rewardGroupTab then
			self.rewardExParams = self.rewardExParams or {isnative = true}
			self.rewardExParams.multiple = getBackInfo.num
			-- print(self.getBackType, activityTab.name, rewardGroupTab.rewardid, hightLv)
			UITools.CopyRewardList({rewardGroupTab.rewardid}, coms.rewardContainer, coms.transRewardItem, self.rewardExParams)
		end
	end
end

function M:GetRewardLv(groupId, lv)
	local lastLv = 1
	for i,v in pairs(excelLoader.RewardGroupplusTable) do
		if v.type == groupId then
			if lv >= v.lv and v.lv >= lastLv then
				lastLv = v.lv
			end
		end
	end
	return lastLv
end

return M