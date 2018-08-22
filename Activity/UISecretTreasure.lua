local ActivityData = require "Data.ActivityData"
local TeamData = require "Data.TeamData"

local TeamTable = require "Excel.TeamTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

-- M.fixedInfoData = {
--     isShow = true,
--     showPos = Vector2.zero,
--     ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
-- }
--M.needPlayShowSE = true

local tipsData = nil

function M.Open(_tipsData)
	tipsData = _tipsData
    uiMgr.ShowAsync("UISecretTreasure")
end

--[[
1.两个难度只能选择其中一个进入。<color=#00FF00>难度越高，奖励越丰富</color>。
2.每天获得一个重置次数，重置次数最多累积<color=#FFCD0000>%d次</color>
3.重置后可重新选择副本难度进入。
4.有<color=#FFCD0000>2次</color>可失败次数，次数耗尽则无法继续挑战。
--]]

------------------秘境寻宝

local settingTabDesc = string.format(Lan("secrettreasure_desc"), 3,2)

function M:Awake()
	base.Awake(self)
	self.uiOffset = self:FindGameObject("Offset")

	--规则描述
	self.txtLeftCount = self:FindText("Offset/TxLeft/TxtLeftCount")
	--简单、困难图片
	self.imgEasy = self:FindImage("Offset/Mode/ButtonEasy")
	self.imgHard = self:FindImage("Offset/Mode/ButtonHard")

	--简单、困难
	self.transBtnEasy = self:FindTransform("Offset/Mode/ButtonEasy")
	UguiLuaEvent.ButtonClick(self.transBtnEasy.gameObject, self, M.OnClickEasy)
	UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/Mode/ButtonHard"), self, M.OnClickHard)

    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
	--点击任意地方关闭。不能用UguiLuaEvent.ExternalOnDown，因为这个是判断鼠标点击位置的。
	UguiLuaEvent.ButtonClick(self:FindGameObject("Img_mask"), self, self.Hide)
end

function M:Show()
	base.Show(self)
	self:TweenOpen(self.uiOffset)

	--刷新界面
	self:RefreshDetailPanel()

	ActivityData.RequestGetMoneyChallengeInfo()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		self:RefreshDetailPanel()
    end
end

function M:OnClick(go)
	local btnName = go.name
	--print(btnName)
	if btnName == "ButtonReset" then
		--重置副本
		-- if PlayerData.GetRoleInfo().lv < then
		-- 	-- body
		-- end
		if ActivityData.GetSTLeftCount() > 0 then
			--剩余次数充足
			if ActivityData.GetCopyMode() ~= 0 then
				if ActivityData.GetProcess() >= excelLoader.SettingTable.mjxb_max_level_count then
					--精度到5，说明已经通关。直接发包
					ActivityData.RequestMoneyChallengeReset()
				else
					--未通关
					local str = string.format("当前副本尚未完成，<color=#00FF00>确定重置？</color>")
					
					TeamData.ShowMsgBox(str, 
						function()
							--点击确定。发包重置
							--print("ClickOK")
							ActivityData.RequestMoneyChallengeReset()
						end,
						function()
							--点击取消。
							--print("ClickCancel")
						end)
				end
			else
				--mode为0，无，说明还没开始
				Tips("还没开始，无需重置")
			end
		else
			Tips("无剩余重置次数")
		end
	elseif btnName == "ButtonDesc" then
		--描述按钮
		--print(settingTabDesc)
		Hint({rectTransform = go.transform, content = settingTabDesc, alignment = 0})
	elseif btnName == "ButtonClose" then
		self:Hide()
	end
end

--点击简单按钮
function M:OnClickEasy()
	self:OnClickMode(1)
end

--点击困难按钮
function M:OnClickHard()
	self:OnClickMode(2)
end

--点击不同模式按钮
function M:OnClickMode(mode)
	if ActivityData.GetCopyMode() ~= 0 and ActivityData.GetCopyMode() ~= mode then
		--已经进入另一个模式副本。没反应
		Tips("请先完成当前秘境")
		return
	end

	if ActivityData.GetProcess() >= excelLoader.SettingTable.mjxb_max_level_count then
		--精度到5，说明已经通关
		Tips("秘境夺宝已通关,请重置")
		return
	end

	if ActivityData.GetFailedCount() >= excelLoader.SettingTable.mjxb_allow_fail_count  then
		--失败次数满了
		Tips(string.format("失败%d次，已达上限，请重置",ActivityData.GetFailedCount()))
		return
	end

	if not GetLocalPlayer():CheckMovable(true) then
		return
	end

	TeamData.ShowNoTeamActionDialog(function() 
		ActivityData.RequestSelectMoneyChallengeHard(mode)
	end)
end

--刷新面板
function M:RefreshDetailPanel()
	-- print("RefreshDetailPanel")
	-- print(ActivityData.GetCopyMode())
	--按钮变灰
	if ActivityData.GetCopyMode() == 0 then
		--还没选择
		UITools.SetImageGrey(self.imgEasy, false)
		UITools.SetImageGrey(self.imgHard, false)
	elseif ActivityData.GetCopyMode() == 1 then
		--已经选择简单
		UITools.SetImageGrey(self.imgEasy, false)
		UITools.SetImageGrey(self.imgHard, true)
	elseif ActivityData.GetCopyMode() == 2 then
		--已经选择困难
		UITools.SetImageGrey(self.imgEasy, true)
		UITools.SetImageGrey(self.imgHard, false)
	end

	--剩余重置次数
	self.txtLeftCount.text = tostring(ActivityData.GetSTLeftCount())
end

return M