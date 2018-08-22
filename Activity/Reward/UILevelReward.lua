local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local SettingTable = require "Excel.SettingTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[
等级礼包
]]
function M:Awake()
	base.Awake(self)
	
	self.uiScrollView = self:FindGameObject("Scroll View")
	self.uiOutBg = self:FindGameObject("Bg")

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem, M.OnChooseItem)

	self.freeReward = SettingTable["lv1_reward"]
	self.moneyReward = SettingTable["lv2_reward"]

	self.activityItemContainer = {}
end

function M:Show()
	base.Show(self)
	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.Activity then
        if msg.cmd == Cmds.GetLvRewardInfo.index or msg.cmd == Cmds.GetLvReward.index then
           self:RefreshPanel()
        end
    end
end

function M:RefreshPanel()
	-- self.uiItemLoop:ScrollToGlobalIndex(RewardData.GetSignDays() - 2)
	self.showFreeReward = {}
	self.showMoneyReward = {}
	for i, v in ipairs(self.freeReward) do
		if not RewardData.IsLevelRewardBuy(i) then
			--已购买的不显示
			table.insert(self.showFreeReward, v)
			table.insert(self.showMoneyReward, self.moneyReward[i])
		end
	end

	--todo，测试
	-- self.showFreeReward = self.freeReward
	-- self.showMoneyReward = self.moneyReward

	if #self.showFreeReward == 0 then
		--都已经领完
		self.uiScrollView:SetActive(false)
		self.uiOutBg:SetActive(true)
	else
		self.uiScrollView:SetActive(true)
		self.uiOutBg:SetActive(false)
		--刷新UILoop
		self.uiItemLoop.ItemsCount = #self.showFreeReward
	end
end

--道具
function M:OnCreateItem(index, coms)
	-- print(index)
	coms.txtLv = self:FindText("Title/TxtLv", coms.trans)--等级
	coms.uiGet = self:FindGameObject("BtnGet", coms.trans)--领取
	coms.uiBuy = self:FindGameObject("BtnBuy", coms.trans)--购买

	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)
	UguiLuaEvent.ButtonClick(coms.uiBuy, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)

	-- coms.uiAlreadyBuy = self:FindGameObject("ImgCantGet", coms.trans)--已购买
	coms.uiNotAchieve = self:FindGameObject("ImgAchieve", coms.trans)--未达成

	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}
	
	coms.imgIcon = self:FindImage("ImgIcon", coms.trans)--消耗
	coms.txtNum = self:FindText("ImgIcon/TxtPrice", coms.trans)--数量
	coms.notIcon = self:FindImage("NotIcon", coms.trans) --原价消耗
	coms.notNum = self:FindText("NotIcon/TxtPrice", coms.trans)
	coms.time = self:FindText("Time", coms.trans)
	coms.timeText = self:FindText("Time/Text", coms.trans)
end

function M:OnChooseItem(index, coms)
   
end

function M:OnClickGet(index, coms, go)
	local realIndex = self:GetRealIndexByLv(self.showFreeReward[index].lv)
	if go.name == "BtnGet" then
		--获取
		if realIndex then
			RewardData.RequestGetLvReward(realIndex)
		end
	elseif go.name == "BtnBuy" then
		--购买
		local expendTab = excelLoader.ExpendTable[self.showMoneyReward[index].expend]
		if expendTab then
			if dataMgr.PlayerData.CheckItemsNum(expendTab.expend, true, true) then
				if realIndex then
					RewardData.RequestGetLvReward(realIndex)
				end
			end
		end
	end
end

function M:GetRealIndexByLv(lv)
	for i, v in ipairs(self.freeReward) do
		if lv == v.lv then
			return i
		end
	end
	Debugger.LogError("Invalid level reward lv: ", lv)
	return nil
end

function M:UpdateItem(index, coms)
	-- index = self.uiRewardLoop:GetItemGlobalIndex(go) + 1
	local levelTab = self.showFreeReward[index]
	if levelTab ~= nil then
		local rewardid = levelTab.rewardid

		local status = 0
		--按钮显示，根据在线时间
		local realIndex = self:GetRealIndexByLv(self.showFreeReward[index].lv)
		if realIndex then
			if RewardData.IsLevelRewardAchieved(realIndex) then
				--已领取
				rewardid = self.showMoneyReward[index].rewardid
				if RewardData.IsLevelRewardBuy(realIndex) then
					--已购买。这里已不会执行，已购买的会从列表中移除
					status = 1
					coms.imgIcon.gameObject:SetActive(false)
					--原价
					coms.notIcon.gameObject:SetActive(false)
					coms.time.gameObject:SetActive(false)
					coms.uiGet:SetActive(false)
					coms.uiBuy:SetActive(false)
					coms.uiNotAchieve:SetActive(false)
				else
					--未购买
					coms.imgIcon.gameObject:SetActive(true)
					--原价
					coms.notIcon.gameObject:SetActive(true)
					coms.time.gameObject:SetActive(true)

					coms.uiGet:SetActive(false)
					coms.uiBuy:SetActive(true)
					coms.uiNotAchieve:SetActive(false)
					--进行计时
					local numIndex = 1
					for i,v in ipairs(self.moneyReward) do
						if levelTab.lv == v.lv then
							numIndex = i
						end
					end
					local timeout = RewardData.RewardTimeState(numIndex)
					if	timeout  then
						local delta = timeout - netMgr.mainClient:GetServerTime()
						if delta >= 0 then
							self:OnCountDown(coms.timeText, function()
								--结束时刷新数据
								RewardData.RequestGetLvRewardInfo()
								self:RefreshPanel()
							end, delta)
						end
					end
					

				end
			else
				--未领取
				status = 2
				coms.imgIcon.gameObject:SetActive(false)
				--原价
				coms.notIcon.gameObject:SetActive(false)
				coms.time.gameObject:SetActive(false)
				if PlayerData.GetRoleInfo().lv >= levelTab.lv then
					--等级达到
					coms.uiGet:SetActive(true)
					coms.uiBuy:SetActive(false)
					coms.uiNotAchieve:SetActive(false)
				else
					--未达到
					coms.uiGet:SetActive(false)
					coms.uiBuy:SetActive(false)
					coms.uiNotAchieve:SetActive(true)
				end
			end
		end

		self:UpdateContainer(index, levelTab, coms, status)

		--在线时间
		coms.txtLv.text = string.format("%d 级礼包", levelTab.lv)
		-- RewardData.RewardTimeState(index)

		--显示消
		local expendTab = excelLoader.ExpendTable[self.showMoneyReward[index].expend]
		local originalPrice = self.showMoneyReward[index].expend2
		if expendTab ~= nil then
			local expendData = expendTab.expend[1]
			UITools.SetCostMoneyInfo(coms.txtNum, coms.imgIcon, expendData.itemid, expendData.num, "", true)
			coms.notNum.text = originalPrice
		end

		--显示原价
		
	
		-- 刷新奖励
		self.rewardExParams = self.rewardExParams or {isnative = true, showQualityEffect = true}
    	UITools.CopyRewardList({rewardid}, coms.rewardContainer, coms.transRewardItem, self.rewardExParams)
	end
end


--倒计时
function M:OnCountDown(uiText, _callBack, _second)
    self.time = _second
	if _second > 0 then
		TweenText.Begin(uiText, _second, 0, _second, 0)
		self.tweenTextContent = uiText.gameObject:GetComponent(typeof(TweenText))
		-- self.tweenTextContent.format = format
		self.tweenTextContent.isTime = true
		self.tweenTextContent:SetOnFinished(function()
			if _callBack then
				_callBack()
			end
		end)
	else
		print("OnCountDown wrong time")
	end
end

---------------------新手引导

function M:UpdateContainer(index, tab, coms, status)
	local container = self.activityItemContainer[index]
	if container then
		--更新
		container.tab = tab
		container.coms = coms
		container.status = status
	else
		--新增
		table.insert(self.activityItemContainer, {tab = tab, coms = coms, status = status})
	end
	
end

--传入id，返回go
function M:GetRewardItemByLv(lv)
	for k, v in pairs(self.activityItemContainer) do
		if v.status ~= 1 then
			--todo，当前只要没购买就给引导。因为已购买的不会显示在上面
			if v.tab.lv == lv then
				return v
			end
		end
	end
	return nil
end

--uiLoop滚动到该id的活动item处。返回true成功。返回false则表示该活动还没开启或者解锁，且没有显示在界面上
function M:ScorllToRewardItemByLv(lv)
	local idx = self:GetLocalIndexByLv(lv)
	if idx then
		self.uiItemLoop:ScrollToGlobalIndex(idx - 1)
		return true
	end	
	return false
end

function M:IsRewardReceived(lv)
	local realIndex = self:GetRealIndexByLv(lv)
	if realIndex then
		if RewardData.IsLevelRewardAchieved(realIndex) then
			--已领取
			return false
		else
			--未领取
			return true
		end
	end
	return false
end

function M:GetLocalIndexByLv(lv)
	for k, v in pairs(self.showFreeReward) do
		if lv == v.lv then
			return k
		end
	end
	return nil
end

return M