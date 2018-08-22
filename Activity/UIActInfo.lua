local ActivityTable = require "Excel.ActivityTable"
local RecordTable = require "Excel.RecordTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"
local ActivityCalendarTable = require "Excel.ActivityCalendarTable"
local ConfRule = require "ConfRule"
local TimeSync = require "TimeSync"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")



local base          = require "UI.UILuaBase"
local M             = base:Extend()





--M.needPlayShowSE = true

local getType = 0
function M:Awake()
    base.Awake(self)  
   --活力值
	self.txtActive = self:FindText("Detail/ActiveRoot/TxtLive/TxtCount")
	--当前的活跃度
	self.txtTotalLiveness = self:FindText("Detail/LivenessRoot/SliderProcess/Handle/ImgHandle/TxtProcess")
	self.sliderProcess = self:FindSlider("Detail/LivenessRoot/SliderProcess")

	--UIloop
	self.uiLoop = self:FindLoop("Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem)

	--限时活动，UIloop
	self.uiTimeLoop = self:FindLoop("Scroll View Right/Viewport/Content")
	self:BindLoopEventEx(self.uiTimeLoop, M.OnCreateTimeItem, M.UpdateTimeItem)


    --Toggle事件
	self.toggles = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("ToggleTop/Toggle (%d)" , i))
        table.insert(self.toggles, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, M.OnToggle)
    end

	self:SpawnLivenessBar()
    self.activityItemContainer = {}
    
	--点选类型
	self.togSelectGroup = self:FindGameObject("Top/ToggleGroup")
	self.selectToggles = {}
	for i=0,3 do
		local tog = self:FindToggle(string.format("Top/ToggleGroup/Toggle%d" , i))
		table.insert(self.selectToggles, tog)
		UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
            if _isOn then
				getType = i
				self:RefreshActivityItem()
			end
		end)
	end


	--按钮。Button
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	--ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
end


--{score=50,maxscore=100,weekmaxscore=10000}，活动双倍点数
local settingTabDouble = SettingTable["activity_doublescore"]
--{500,20}，活力值上限
local settingTabActive = SettingTable["activity_vitalityscore"]

local ActivityType = {Daily = 1, Time = 2, Unopened = 3}



function M:Show()
	base.Show(self)


	--默认点击第一个Toggle，日常活动
	if self.toggles[1].isOn == false then
		self.toggles[1].isOn = true
	else
		self:RefreshActivityItem()
	end
		
	--print(self.toggles[1].name)
	self.curTab = ActivityType.Daily
	self:RefreshOtherPanel()
	self:RefreshGiftInfo()
end

function M:ResetSelect()
	self.selectToggles[1].isOn = true
	for i=2,#self.selectToggles do
		self.selectToggles[i].isOn = false
	end
end

local LivenessDesc = string.format(Lan("activity_liveness_desc"), 100) 
local DoubleDesc = string.format(Lan("activity_doublepoint_desc"),"50%", settingTabDouble.weekmaxscore, settingTabDouble.maxscore, 100) 
--点击按钮
function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "ButtonClose" then
		self:Hide()
	elseif btnName == "ButtonGet" then
		--领取双倍点数
		ActivityData.RequestDoublePointOpt(1)
	elseif btnName == "ButtonFreeze" then
		--冻结双倍点数
		ActivityData.RequestDoublePointOpt(2)
	elseif btnName == "ButtonLiveSkill" then
		--生活技能。打开生活技能分页
		OpenUI("UIPlayerSkill", {panelIndex = 3})
	elseif btnName == "ButtonActiveDesc" then
		--活力值
		Hint({rectTransform = go.transform, content = LivenessDesc, alignment = 0})
	elseif btnName == "ButtonDouble" then
		--双倍点数
		Hint({rectTransform = go.transform, content = DoubleDesc, alignment = 0})
	end
end

--活动点选
function M:OnToggle(go, _isOn)
	if _isOn then
		local toggleName = go.name
		if toggleName == "Toggle (1)" then
			--日常活动
			self.curTab = ActivityType.Daily
			self.togSelectGroup:SetActive(true)
		elseif toggleName == "Toggle (2)" then
			--即将开启
			self.curTab = ActivityType.Unopened
			self.togSelectGroup:SetActive(false)
		end

		self:RefreshActivityItem()
	end
end

------------------活动条目

function M:RefreshActivityItem(keepScroll)
	if not keepScroll then
		activityMgr.SortActivity()
	end

	--日常活动，即将开启
	if self.curTab == ActivityType.Daily then
		--日常任务
		-- print("Daily")
		self.uiLoop.ItemsCount = #self:actInputType(getType)
	elseif self.curTab == ActivityType.Time then
		--限时活动
		-- print("Time")
		-- self.uiLoop.ItemsCount = #activityMgr.openTimeActivity + #activityMgr.unopenedTimeActivity
	elseif self.curTab == ActivityType.Unopened then
		--即将开启
		-- print("Unopened")
		self.uiLoop.ItemsCount = #activityMgr.unopenedActivity
	end

	if not keepScroll then
		--if self.curTab == ActivityType.Daily and guideMgr.guideBranchActivityID and self:IsShowGuideNotify(guideMgr.guideBranchActivityID) then
		--	self:ScorllToAcitivtyItemById(guideMgr.guideBranchActivityID)
		--else
		--end
		self.uiLoop:ScrollToGlobalIndex(0)
	end
	
	--限时活动
	self.uiTimeLoop.ItemsCount = #activityMgr.openTimeActivity + #activityMgr.unopenedTimeActivity
	-- self.uiTimeLoop:ScrollToGlobalIndex(0)
end

--本地监听
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
    	local servercmd = msg.cmd
    	if servercmd == Cmds.DoublePointOpt.index then
			--双倍点数刷新
	    	self:RefreshOtherPanel()
		elseif servercmd == Cmds.GetActivityInfo.index then
			--活力值，双倍点数、礼包数据
			self:RefreshOtherPanel()
			self:RefreshGiftInfo()
			self:RefreshActivityItem(true)
		elseif servercmd == Cmds.GetActivityReward.index then
			--领取礼包回复
			self:RefreshGiftInfo()
	    end
    end
end

----------------------判断选中活动类型
function M:actInputType(num)
	local info = activityMgr.openActivity
	local tablelist = {}
	if num == 1 then
		for i,v in ipairs(info) do
			for x,y in ipairs(v.inputtype) do
				if y == 1 then
					table.insert(tablelist,v)
				end
			end
		end
	elseif num == 2 then
		for i,v in ipairs(info) do
			for x,y in ipairs(v.inputtype) do
				if y == 2 then
					table.insert(tablelist,v)
				end
			end
		end
	elseif num == 3 then
		for i,v in ipairs(info) do
			for x,y in ipairs(v.inputtype) do
				if y == 3 then
					table.insert(tablelist,v)
				end
			end
		end
	else
		tablelist = info
	end
	--返回筛选的活动
	return tablelist
	
end



----------------------日常活动，即将开启

--道具
function M:OnCreateItem(index, coms)
	--活动图标
	coms.imgActivityIcon = self:FindImage("ImgActivity/ImageIcon", coms.trans)
	--名称
	coms.txtName = self:FindText("TxtName", coms.trans)
	--次数
	coms.uiNumRoot = self:FindGameObject("TxtNumDesc", coms.trans)
	coms.txtNum = self:FindText("TxtNumDesc/TxtNum", coms.trans)
	coms.uiNoNumRoot = self:FindGameObject("TxtNoNum", coms.trans)
	--活跃
	coms.txtActive = self:FindText("TxtActiveDesc/TxtActive", coms.trans)
	coms.uiActiveRoot = self:FindGameObject("TxtActiveDesc", coms.trans)
	--获得的物品，比如经验图片
	coms.imgAchieve = self:FindImage("TxtName/ImgAchieve", coms.trans)
	--单人，还是组队
	coms.txtTeam = self:FindText("TxtTeam", coms.trans)

	--StatusRoot
	--几级开启
	coms.txtLevel = self:FindText("StatusRoot/TxtLevel", coms.trans)
	--参与按钮
	coms.uiButtonJoin = self:FindGameObject("StatusRoot/ButtonJoin", coms.trans)
	coms.tranButtonJoin = self:FindTransform("StatusRoot/ButtonJoin", coms.trans)
	--已完成图片
	coms.uiFinish = self:FindGameObject("StatusRoot/ImgFinish", coms.trans)

	--引导红点
	coms.guideRedPoint = self:FindGameObject("StatusRoot/ButtonJoin/RedPoint", coms.trans)
	
	--推荐图片
	coms.uiRecommend = self:FindGameObject("ImgBanner", coms.trans)

	UguiLuaEvent.ButtonClick(coms.go, nil, function(go)
		self:OnClickItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms, 1, self.curTab)
	end)

	UguiLuaEvent.ButtonClick(coms.uiButtonJoin, nil, function(go)
		self:OnClickItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms, 2, self.curTab)
	end)
end

function M:OnClickItem(index, coms, type, activityType)
	local activityTab = self:GetActivityByIndexAndType(index, activityType)

	if type == 1 then
		OpenUI("UIActivityBox", activityTab.id)
	elseif type == 2 then
		--参与按钮，发包
		activityMgr.JoinActivity(activityTab)
	end
end

function M:UpdateItem(index, coms)
	self:RefreshSingleItem(index, coms, self.curTab)
end

function M:IsShowGuideNotify(id)
	return (id ~= Const.ACTIVITY_ID_CONVOY_ROB)
end


--刷新日常活动
function M:RefreshSingleItem(index, coms, activityType)	
	local activityTab, isUnopenTimeActivity = self:GetActivityByIndexAndType(index, activityType)
	if not activityTab then
		Debugger.LogError("UIActivity UpdateItem error")
		return
	end

	--新手引导
	self.activityItemContainer[coms] = activityTab.id

	--默认隐藏，几级开启、参与按钮、已完成图片
	coms.txtLevel.gameObject:SetActive(false)
	coms.uiButtonJoin:SetActive(false)
	coms.uiFinish:SetActive(false)
	if coms.guideRedPoint then
		coms.guideRedPoint:SetActive(self:IsShowGuideNotify(activityTab.id) and (guideMgr.guideBranchActivityID == activityTab.id))
	end

	--活动图标,获得的物品图标。todo
	uiMgr.SetSpriteAsync(coms.imgActivityIcon, Const.atlasName.ItemIcon, activityTab.icon)
	if coms.imgAchieve then
		uiMgr.SetSpriteAsync(coms.imgAchieve, Const.atlasName.ItemIcon, activityTab.rewardIcon)
	end

	--推荐图片
	coms.uiRecommend:SetActive(activityTab.showRecommend)

	--单人还是组队
	coms.txtTeam.text = activityTab.missionTypeDesc

	--名称
	coms.txtName.text = activityTab.name
	--次数。从Record中获取
	local curCount, totalCount = ActivityData.GetActivityNum(activityTab.id)

	if totalCount == 0 then
		--RecordTable中max值为0时表示不限次数,不显示次数
		coms.uiNumRoot:SetActive(false)
		coms.uiNoNumRoot:SetActive(true)
	else
		local num, max = dataMgr.ActivityData.GetRecordInstance():ActivityRewardCount(activityTab.id)
		if num then
			coms.txtNum.text = string.format("%d/%d",num, max)
		else
			coms.txtNum.text = string.format("%d/%d",curCount, totalCount)
		end
		coms.uiNumRoot:SetActive(true)
		coms.uiNoNumRoot:SetActive(false)
	end
	
	--活跃值
	if coms.txtActive and coms.uiActiveRoot then
		if activityTab.activeValue == 0 then
			--没有活跃值奖励
			coms.uiActiveRoot:SetActive(false)
		else
			coms.uiActiveRoot:SetActive(true)

			--活跃值不能大于上限
			local curTotalValue = curCount*activityTab.activeValue
			if curTotalValue > activityTab.activeLimit then
				curTotalValue = activityTab.activeLimit
			end
			coms.txtActive.text = string.format("%d/%d", curTotalValue, activityTab.activeLimit)
		end
	end
	
	--根据服务器数据判断是否已经完成
	local doCount = false
	if activityType == ActivityType.Daily then
		--日常任务
		doCount = true
	elseif activityType == ActivityType.Time then
		--限时活动
		if isUnopenTimeActivity then
			--未开启限时
			coms.txtLevel.gameObject:SetActive(true)
			coms.txtLevel.text = string.format("时间 : %s", activityMgr.GetOpenTime(activityTab)) 
		else
			--已开启
			doCount = true
		end
	elseif activityType == ActivityType.Unopened then
		--即将开启，几级开启。
		coms.txtLevel.gameObject:SetActive(true)
		coms.txtLevel.text = string.format("%d级", activityTab.limit.lv)
	end

	--完成状态处理
	if doCount then
		if activityMgr.IsShowJoinButton(activityTab.id) then
			UITools.SetActive(coms.uiButtonJoin, true)
		else
			UITools.SetActive(coms.uiFinish, activityMgr.IsActivityFinish(activityTab.id))
		end
	end
end

function M:GetActivityByIndexAndType(index, _type)
	local Info, isUnopenTimeActivity = nil, false
	if _type == 1 then
		--日常活动
		local info = self:actInputType(getType)
		Info = info[index]
	elseif _type == 2 then
		--限时活动

		--已开启
		Info = activityMgr.openTimeActivity[index]
		-- print("aaaaaaaaaaaaa")
		if Info == nil then
			-- print("bbbbbbbbbbbb")
			--未开启限时活动
			Info = activityMgr.unopenedTimeActivity[index - #activityMgr.openTimeActivity]
			isUnopenTimeActivity = true
		end
	elseif _type == 3 then
		--即将开启
		Info = activityMgr.unopenedActivity[index]
	end

	return Info, isUnopenTimeActivity
end

---------------------限时活动

function M:OnCreateTimeItem(index, coms)
	--活动图标
	coms.imgActivityIcon = self:FindImage("ImgActivity/ImageIcon", coms.trans)
	--名称
	coms.txtName = self:FindText("TxtName", coms.trans)
	--次数
	coms.uiNumRoot = self:FindGameObject("TxtNumDesc", coms.trans)
	coms.txtNum = self:FindText("TxtNumDesc/TxtNum", coms.trans)
	coms.uiNoNumRoot = self:FindGameObject("TxtNoNum", coms.trans)
	--单人，还是组队
	coms.txtTeam = self:FindText("TxtTeam", coms.trans)

	--StatusRoot
	--几级开启
	coms.txtLevel = self:FindText("StatusRoot/TxtLevel", coms.trans)
	--参与按钮
	coms.uiButtonJoin = self:FindGameObject("StatusRoot/ButtonJoin", coms.trans)
	coms.tranButtonJoin = self:FindTransform("StatusRoot/ButtonJoin", coms.trans)
	--已完成图片
	coms.uiFinish = self:FindGameObject("StatusRoot/ImgFinish", coms.trans)

	--推荐图片
	coms.uiRecommend = self:FindGameObject("ImgBanner", coms.trans)

	UguiLuaEvent.ButtonClick(coms.go, nil, function(go)
		self:OnClickTimeItem(self.uiTimeLoop:GetItemGlobalIndex(coms.go) + 1, coms, 1, ActivityType.Time)
	end)

	UguiLuaEvent.ButtonClick(coms.uiButtonJoin, nil, function(go)
		self:OnClickTimeItem(self.uiTimeLoop:GetItemGlobalIndex(coms.go) + 1, coms, 2, ActivityType.Time)
	end)
end

function M:OnClickTimeItem(index, coms, type, activityType)
	local activityTab = self:GetActivityByIndexAndType(index, activityType)

	--print(index, activityType)
	if type == 1 then
		OpenUI("UIActivityBox", activityTab.id)
	elseif type == 2 then
		--参与按钮，发包
		activityMgr.JoinActivity(activityTab)
	end
end

function M:UpdateTimeItem(index, coms)
	self:RefreshSingleItem(index, coms, ActivityType.Time)
end

function M:GetTimeActivityByIndex(index)
	local Info = activityMgr.openTimeActivity[index]
	local isUnopenTimeActivity = false
	if Info == nil then
		--未开启限时活动
		Info = activityMgr.unopenedTimeActivity[index - #activityMgr.openTimeActivity]
		isUnopenTimeActivity = true
	end

	return Info, isUnopenTimeActivity
end

---------------------活力值、双倍点数

local activeId = 906
local doublePointId = 1006

function M:RefreshOtherPanel()
	--活力值
	local maxActive = settingTabActive[1] + settingTabActive[2]*PlayerData.GetRoleInfo().lv
	local curActive = PlayerData.GetItemCount(activeId)
	--ActivityData.GetActiveValue()
	self.txtActive.text = string.format("%d/%d", curActive, maxActive)

	--双倍点数
	-- self.txtDoublePoint.text = string.format("%d/%d", ActivityData.GetDoublePoint(), dataMgr.PlayerData.GetItemCount(Const.ITEM_ID_DOUBLE_POINT))
end

----------------------活跃度条

local GiftLayoutDelta = 50
local GiftLayout = {
	                {id = 1, offset = 20},
	                {id = 2, offset = 20},
	                {id = 3, offset = 18},
	                {id = 4, offset = 30},
	                {id = 5, offset = 60},
                 }

function M:SpawnLivenessBar()
	self.tranSliderProgress = self:FindTransform("Detail/LivenessRoot/SliderProcess")
	--将生成的gift放在Slider下面。因为是以Slider的左边为初始位置
	self.tranGiftRoot = self:FindTransform("Detail/LivenessRoot/SliderProcess/GiftRoot")
	self.tranGiftPrefab = self:FindGameObject("Detail/LivenessRoot/SliderProcess/ActivityGift")
	self.tranGiftPrefab:SetActive(false)
	
	--{{20,5101},{40,5102},{60,5103},{80,5104},{100,5105}}，活跃值——RewardId
	self.processTab = SettingTable["activity_reward"]
	local highest = self.processTab[#self.processTab][1]
	self.totalLiveness = highest + highest * 0.15
	--print(self.totalLiveness)
	local beginPos = self.tranSliderProgress.anchoredPosition3D
	self.sliderTotalLength = self.tranSliderProgress.sizeDelta.x
	local posY = self.tranGiftPrefab.transform.anchoredPosition3D.y

	--实例化
	self.uiActitityGift = {}
	UIWidgetBase.DynamicCreateMore(self.uiActitityGift, #self.processTab, self.tranGiftPrefab, self.tranGiftRoot, nil, nil)

	for k,v in ipairs(self.uiActitityGift) do
		--组件缓存
		v.ImgIcon = self:FindImage("ImageIcon", v.go.transform)
		v.TxtValue = self:FindText("TxtValue", v.go.transform)

		--修改名称
		v.go.name = tostring(k)
		v.go:SetActive(true)

		--位置摆放
		--{20,5101}，活跃值——ItemId
		local settingTab = self.processTab[k]
		local rate = settingTab[1]/self.totalLiveness	--比例
		--local posX = self.sliderTotalLength*rate + GiftLayout[k].offset
		local posX = self.sliderTotalLength*rate
		v.go.transform.anchoredPosition3D = Vector3.New(posX, posY, 0)

		--礼包icon
		local rewardTab = RewardTable[settingTab[2]]
		if rewardTab then
			local atlas = rewardTab.atlas
			if not atlas then
				atlas = Const.atlasName.ItemIcon
			end
			UITools.SetImageIcon(v.ImgIcon, atlas, rewardTab.rewardUi, true)
		end
		--活跃值
		v.TxtValue.text = tostring(settingTab[1])

		--Toggle事件
		UguiLuaEvent.ToggleClick(v.go, self, M.OnToggleGift)
	end

	self:RefreshGiftInfo()
end

local giftNotifyPos = Vector3.New(35,35,0)

--活跃度礼包数据初始化。礼包可领取显示特效，礼包已领取
function M:RefreshGiftInfo()
	local curLiveness = ActivityData.GetActiveValue()
	local lowIndex = 0
	local highIndex = 0
	local firstHigh = false

	for i, v in ipairs(self.uiActitityGift) do
		local settingTab = self.processTab[i]
		--判断当前进度是否达到该礼包进度
		if curLiveness >= settingTab[1] then
			--达到进度，显示特效
			if ActivityData.IsRewardReceived(i) then
				--已经领取过
				if v.uiEffect then
					v.uiEffect:SetActive(false)
				end
				UITools.SetImageGrey(v.ImgIcon, true)
			else
				--没领取过，显示特效
				if not v.uiEffect then
					v.uiEffect = effectMgr:SpawnToUI("2d_wppz_violet", Vector3.zero, v.go.transform, 0).gameObject
				else
					v.uiEffect:SetActive(true)
				end
				UITools.SetImageGrey(v.ImgIcon, false)
			end

			lowIndex = i
		else
			--未达到进度
			if v.uiEffect then
				v.uiEffect:SetActive(false)
			end
			UITools.SetImageGrey(v.ImgIcon, false)

			if firstHigh == false then
				highIndex = i
				firstHigh = true
			end
		end

		--红点
		notifyMgr.AddNotify(v.go, notifyMgr.IsActivityGiftNotityByIndex(i), giftNotifyPos, notifyMgr.NotifyType.Common)
	end

	--计算slider的value值，因为进度条不是根据数值等比例摆放，所以实际的UI界面value值要实时计算
	if curLiveness >= self.processTab[#self.processTab][1] then
		--超过上限
		self.sliderProcess.value = 1
		--不显示当前活力值
		self.txtTotalLiveness.text = ""
	else
		--未超过上限。计算Slider.value值
		local beginX = 0
		local endX = 0
		local beginValue = 0
		local endValue = 0
		if lowIndex == 0 then
			--说明没有到达任何一个礼包的活跃度
			beginX = 0
			beginValue = 0
		elseif lowIndex > 0 then
			beginX = self.uiActitityGift[lowIndex].go.transform.anchoredPosition3D.x
			beginValue = self.processTab[lowIndex][1]
		end
		endX = self.uiActitityGift[highIndex].go.transform.anchoredPosition3D.x
		endValue = self.processTab[highIndex][1]

		local destX = beginX + (endX - beginX)*(curLiveness-beginValue)/(endValue-beginValue)

		--进度条
		self.sliderProcess.value = destX/self.sliderTotalLength
		--当前活跃度
		self.txtTotalLiveness.text = tostring(curLiveness)
	end
end

function M:OnToggleGift(_go, _isOn)
	if _isOn then
		local idx = tonumber(_go.name)
		--礼包Item
		local settingTab = self.processTab[idx]
		local rewardID = settingTab[2]

		if ActivityData.GetActiveValue() >= settingTab[1] then
			--达到活力值
			if ActivityData.IsRewardReceived(idx) then
				--已领取过
				self:ShowRewardTips(_go, settingTab[2])
			else
				--未领取过。发包领取
				ActivityData.RequestGetActivityReward(idx)
			end
		else
			--未达到活力值
			self:ShowRewardTips(_go, settingTab[2])
		end
	end
end

function M:ShowRewardTips(_go, rewardId)
	local parasTB = {rectTransform = _go.transform, rewardID = rewardId, isShowBot = false}
	parasTB.title = "活动奖励"
	parasTB.descMid = "达到相应的进度可领取"
	OpenUI("UIBoxReward", parasTB)
end
------------------------------新手引导

--传入id，返回coms
function M:GetActivityItemById(id)
	for k, v in pairs(self.activityItemContainer) do
		if v == id then
			--无效位置为(99999, 99999)
			if k.trans.anchoredPosition.x < 90000 then
				return k
			else
				return nil
			end
		end
	end
	return nil
end

--uiLoop滚动到该id的活动item处。返回true成功。返回false则表示该活动还没开启或者解锁，且没有显示在界面上
function M:ScorllToAcitivtyItemById(id)
	local activityTab = ActivityTable[id]
	if activityTab then
		local isOpen, idx = M.GetActivityStatusAndIndex(activityTab.id, activityTab.type)
		if isOpen then
			if activityTab.type == 1 then
				--日常活动
				self.toggles[1].isOn = true
				self.uiLoop:ScrollToGlobalIndex(idx - 1)
			elseif activityTab.type == 2 then
				--限时活动
				self.toggles[2].isOn = true
				self.uiTimeLoop:ScrollToGlobalIndex(idx - 1)
			end			
			
			return true
		end
	end
	
	return false
end

function M.GetActivityStatusAndIndex(id, activityType)
	local activityTabs = nil
	if activityType == 1 then
		--日常活动
		activityTabs = activityMgr.openActivity
	elseif activityType == 2 then
		--限时活动
		activityTabs = activityMgr.openTimeActivity
	end

	if activityTabs then
		for i, v in ipairs(activityTabs) do
			if id == v.id then
				return true, i
			end
		end
	end

	return false, nil
end
return M