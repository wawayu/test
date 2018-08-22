
local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"

local ItemTable = require "Excel.ItemTable"
local SignTable = require "Excel.SignTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[
1.每月累积签到天数，领取相应的签到奖励，累积签到天数越多，获得奖励越多。
2.每日签到奖励每日刷新，未领取的奖励不能补领，所以不要错过哦！
3.每日签到后，还可以花费元宝再签到一次。
]]

function M:Awake()
	base.Awake(self)
	
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	--------每日签到
	--轮次
	self.txtSignInTitle = self:FindText("ImageTitle/Text")

	--签到，补签，已签到
	-- self.btnSign = self:FindGameObject("Bottom/BtnSign")
	-- self.btnResign = self:FindGameObject("Bottom/BtnResign")
	-- self.imgItem = self:FindImage("Bottom/BtnResign/imgIcon")
	-- self.txtNum = self:FindText("Bottom/BtnResign/imgIcon/TxtNum")
	-- self.btnSigned = self:FindGameObject("Bottom/BtnSigned")

    --右边UILoop
	self.uiRewardLoop = self:FindLoop("DailyPanel/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiRewardLoop, M.OnCreateReward, M.UpdateRewardItem, M.OnChooseReward)
	self.rewardItemParam = {showtips=false, clickCallback=nil, showQualityEffect=false, isNative = true, disableClick = true}
end

function M:Show()
	base.Show(self)
	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		if msg.cmd == Cmds.GetSignInfo.index then
			-- print("aaaaaaaaa")
			self:RefreshPanel()
		end
    end
end

function M:RefreshPanel()
	self.txtSignInTitle.text = string.format( "第 %d 轮签到", RewardData.GetRealSignRounds())

	self.uiRewardLoop:ScrollToGlobalIndex(RewardData.GetSignDays() - 2)
	-- self.uiRewardLoop:ScrollToGlobalIndex(17)
	--刷新UILoop
	self.uiRewardLoop.ItemsCount = Const.SIGNIN_DAYS_PER_ROUND --#SignTable
end

function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "BtnSign" then
		--签到。
		RewardData.RequestSignIn()
	elseif btnName == "ButtonDesc" then
		--描述按钮
		-- print(btnName)
		Hint({rectTransform = go.transform, content = Lan("dailysign_desc"), alignment = 0})
	elseif btnName == "BtnResign" then
	
	elseif btnName == "BtnSigned" then
		--已经签到
        Tips("今日已签到")
	end
end

function M:OnCreateReward(index, coms)
    coms.uiGou = self:FindGameObject("ImgMask", coms.trans)
    coms.imgIcon = self:FindImage("Info/ImgIcon", coms.trans)
    coms.transQuality = self:FindTransform("Info/ImgQuality", coms.trans)
    coms.txtNum = self:FindText("Info/ImgNumBg/TextNum", coms.trans)
	coms.txtDay = self:FindText("TextDay", coms.trans)

	coms.txtName = self:FindText("Info/TextName", coms.trans)

	--用于UITools.SetCommonItem
	coms.comStuff = {}
    coms.comStuff.transRoot = self:FindTransform("Info", coms.trans)

	coms.uiBtnGet = self:FindGameObject("BtnSign", coms.trans)
	--领取按钮
	UguiLuaEvent.ButtonClick(coms.uiBtnGet, nil, function(go)
		self:OnClickGet(self.uiRewardLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnClickGet(index, coms)
	local chargeNum = dataMgr.RechargeData.GetChargeNumToday()
	if chargeNum > 0 then
		RewardData.RequestSignIn()
		return
	end

	local str = "充值任意金额,可领取额外的签到奖励"
	self:ShowMsgBox(str, "充值",
		function()
			OpenUI("UIRecharge")
		end,
	nil)
end

function M:ShowMsgBox(str, strOK, _onClickOK, _onClickCancel)
	UIMsgbox.ResetInput()
    UIMsgbox.style = UIMsgbox.Style.ChooseCancel
    UIMsgbox.strContent = str
	UIMsgbox.strBtnOK = strOK
    --回调
    UIMsgbox.callbackFun = function(flag) 
    	if flag then
    		--确定
    		if _onClickOK ~= nil then
    			_onClickOK()
    		end
    	else
    		--取消
    		if _onClickCancel ~= nil then
    			_onClickCancel()
    		end
    	end
    end
    UIMsgbox.countdown = 30
    UIMsgbox.hideWhenLoading = false
    uiMgr.ShowAsync("UIMsgbox")
end

--选中签到奖励物品
function M:OnChooseReward(index, coms)	
	if RewardData.GetSignDays() > index then
		--前面几天已经领取。变灰
	elseif RewardData.GetSignDays() == index then
		--今天的。是否签到过
		--签到次数
		if RewardData.GetSignCount() == 0 then
			--当天。未签到。显示特效
			RewardData.RequestSignIn()
		elseif RewardData.GetSignCount() == 1 then
			--已经签到，关闭特效
		elseif RewardData.GetSignCount() == 2 then
			--已付费签到
		end
	elseif RewardData.GetSignDays() < index then
		--未来的
	end
end

--签到奖励
function M:UpdateRewardItem(index, coms)
	local rounds = RewardData.GetSignRounds()
	local signTab = SignTable[rounds*100+index]
	if not signTab then return end

	local trans = coms.trans

	local signDays = RewardData.GetSignDays()
	local signCountToday = RewardData.GetSignCount()

	local reward = signTab.rewardid
	if signTab.rewardid2 then
		if signDays > index or signDays == index and signCountToday >= 1 then
			reward = signTab.rewardid2 
		end
	end

	local itemTab = ItemTable[reward.itemid]

	--icon、品质、个数
	UITools.SetCommonItem(coms.comStuff, nil, itemTab, self.rewardItemParam)
    coms.txtNum.text = tostring(reward.num)
	--名称
	coms.txtName.text = UITools.FormatItemColorName(reward.itemid)
	coms.txtName.gameObject:SetActive(true)
	coms.uiBtnGet:SetActive(false)

	if signDays > index then
		--前面几天已经领取。变灰
		-- UITools.SetImageGrey(coms.imgIcon, true)
		coms.uiGou:SetActive(true)
		if self.uiSignEffect and self.uiSignEffect.parent == coms.transQuality then
			self.uiSignEffect.gameObject:SetActive(false)
		end
	elseif signDays == index then
		--今天的。是否签到过

		--不变灰色，去掉打钩
		-- UITools.SetImageGrey(coms.imgIcon, false)
		coms.uiGou:SetActive(false)
		--签到次数
		if signCountToday == 0 then
			--当天。未签到。显示特效
			--签到特效
			if not self.uiSignEffect then
				self.uiSignEffect = UITools.SetItemQualityEffect(self:FindTransform("DailyPanel/Scroll View/Viewport/Content/Item/Info/ImgQuality"), 5)
			end
			self.uiSignEffect:SetParent(coms.transQuality)
			self.uiSignEffect.localPosition = Vector3.zero
			self.uiSignEffect.gameObject:SetActive(true)
		elseif signCountToday == 1 then
			--已经签到，关闭特效
			if self.uiSignEffect then
				self.uiSignEffect.gameObject:SetActive(false)
			end
			coms.uiBtnGet:SetActive(true)
			coms.txtName.gameObject:SetActive(false)
		elseif signCountToday == 2 then
			--已付费签到
			-- UITools.SetImageGrey(coms.imgIcon, true)
			coms.uiGou:SetActive(true)
			coms.uiBtnGet:SetActive(false)
		end
	elseif signDays < index then
		--未来的
		-- UITools.SetImageGrey(coms.imgIcon, false)
		coms.uiGou:SetActive(false)
		if self.uiSignEffect and self.uiSignEffect.parent == coms.transQuality then
			self.uiSignEffect.gameObject:SetActive(false)
		end
	end

	--第几天
	coms.txtDay.text = string.format( "第%d天", index)
end

return M