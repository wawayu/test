local base = require "UI.UILuaBase"
local M = base:Extend()

--M.needPlayShowSE = true

function M.Open(openParams)	
    uiMgr.ShowAsync("UIMatching")
end

function M:Awake()
	base.Awake(self)

	self.btnCancel = self:FindGameObject("Frame/BtnCancel")
	UguiLuaEvent.ButtonClick(self.btnCancel, self, M.OnClickCancel)
	
	self.selfName = self:FindText("Frame/Self/Name")
	self.selfIcon = self:FindImage("Frame/Self/Icon")
	self.selfLv = self:FindText("Frame/Self/Lv")
	self.selfScore = self:FindText("Frame/Self/Score")
	self.selfFrame = self:FindImage("Frame/Self/ImageFrame")
	
	self.targetInfo = self:FindGameObject("Frame/Target/Info")
	self.targetName = self:FindText("Frame/Target/Info/Name")
	self.targetIcon = self:FindImage("Frame/Target/Info/Icon")
	self.targetLv = self:FindText("Frame/Target/Info/Lv")
	self.targetScore = self:FindText("Frame/Target/Info/Score")
	self.targetEmpty = self:FindGameObject("Frame/Target/TipEmpty")
	self.targetFrame = self:FindImage("Frame/Target/Info/ImageFrame")

	self.matchingTip = self:FindText("Frame/Matching")
end

function M:Show()
	base.Show(self)

	--倒计时需重置
	self.countDownStart = nil

	--等待开始时间
	self.waitingStart = Time.realtimeSinceStartup

	self:SetVSEffect(false)

	self:RefreshSelf()
	self:RefreshTarget()
	self:RefreshMatchingTip()
end

function M:RefreshSelf()
    local roleInfo = dataMgr.PlayerData.GetRoleInfo()

	self.selfName.text = roleInfo.name
	self.selfLv.text = tostring(roleInfo.lv) 

	UITools.SetUnitIconAndFrame(self.selfIcon, self.selfFrame, roleInfo)

	self.selfScore.text = tostring(dataMgr.ActivityData.GetDouJiScore(1))
end

function M:RefreshTarget()
	local matchingBattleInfo = dataMgr.ActivityData.content.doujiMatchingBattleInfo
	if not matchingBattleInfo then
		self.targetInfo:SetActive(false)	
		self.targetEmpty:SetActive(true)	

		self.btnCancel:SetActive(true)
	else
		self.targetInfo:SetActive(true)	
		self.targetEmpty:SetActive(false)	

		local battleMembers = dataMgr.FightData.GetMembersByType(matchingBattleInfo, false, Const.ID_TYPE_CHARACTER)
		if battleMembers == nil or #battleMembers == 0 then
			battleMembers = dataMgr.FightData.GetMembersByType(matchingBattleInfo, false, Const.ID_TYPE_MONSTER)
		end

		local targetInfo = battleMembers[1]

		self.targetName.text = fightMgr.GetUnitName(targetInfo)
		self.targetLv.text = fightMgr.GetUnitLv(targetInfo)

		UITools.SetUnitIconAndFrame(self.targetIcon, self.targetFrame, targetInfo)
		
		self.targetScore.text = tostring(targetInfo.ext)
	end
end

function M:RefreshMatchingTip()
	local matchingBattleInfo = dataMgr.ActivityData.content.doujiMatchingBattleInfo
	if not matchingBattleInfo then
		self.btnCancel:SetActive(true)
		self.matchingTip.text = "匹配对手中..."
	else
		self.btnCancel:SetActive(false)

		--开始倒计时处理
		self.countDownStart = Time.realtimeSinceStartup
		self.lastCountDownSecond = nil
		self:SetVSEffect(true)
		
		--首次强制刷新
		self:Update()
	end
end

function M:SetVSEffect(isShow)
	if not tolua.isnull(self.eff) then
		GameObject.Destroy(self.eff.gameObject)
	end

	if isShow then
		self.eff = effectMgr:SpawnToUI("2d_duijue", Vector3.zero, self.rectTransform, 0)  
	end
end

local CountDownMax = 3

function M:Update()
	if self.countDownStart then
		local timeElapse = Time.realtimeSinceStartup - self.countDownStart
		if timeElapse >= CountDownMax then
			self:Hide()
			return
		end

		--3秒倒计时
		local countDownSecond = CountDownMax - math.ceil(timeElapse)
		if self.lastCountDownSecond ~= countDownSecond then
			self.lastCountDownSecond = countDownSecond
			self.matchingTip.text = "开始倒计时："..tostring(countDownSecond)
		end
	else
		--等待计时
		local waitingSecond = Time.realtimeSinceStartup - self.waitingStart
		if self.lastWaitingSecond ~= waitingSecond then
			self.lastWaitingSecond = waitingSecond
			self.matchingTip.text = "匹配对手中...\n"..Utility.FormatTimeMinSec(waitingSecond)
		end
	end
end

-------------------------------------------------------

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.DouJi then
		self:RefreshTarget()
		self:RefreshMatchingTip()
    end
end

function M:OnClickCancel()
	dataMgr.ActivityData.RequestCancelMatch()
	self:Hide()
end

return M