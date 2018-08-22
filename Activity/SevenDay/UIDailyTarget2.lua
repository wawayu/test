local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local ActivityData = require "Data.ActivityData"

local ItemTable = require "Excel.ItemTable"
local SettingTable = require "Excel.SettingTable"

local DailyTargetData = dataMgr.DailyTargetData
local AchievementData = dataMgr.AchievementData
local AchievementTable = excelLoader.AchievementTable

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[
七日目标——每日目标
]]
function M:Awake()
	base.Awake(self)

	-- self.uiScrollView = self:FindGameObject("Scroll View")
	-- self.uiOutBg = self:FindGameObject("Bg")

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem, nil)

	-- self.freeReward = SettingTable["lv1_reward"]
	-- self.moneyReward = SettingTable["lv2_reward"]
end

function M:Show()
	base.Show(self)

	--print("Show UIDailyTarget")
	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.Achievement then
        self:RefreshPanel()
    end
end

function M:RefreshPanel()
	self.dailyTargetAchieveTable = DailyTargetData.GetDailyTargetData(self.parent.selectDayIndex)
	-- table.sort(self.dailyTargetAchieveTable, M.SortByUp)
	-- print(self.parent.selectDayIndex)
	-- PrintTable(self.dailyTargetAchieveTable)

	if #self.dailyTargetAchieveTable >= 0 then
		--刷新UILoop
		self.uiItemLoop.ItemsCount = #self.dailyTargetAchieveTable
	end
end

--成就排序
function M.SortByUp(left, right)
    local leftProgress, leftGotReward = AchievementData.CheckStatus(left.id)
    local rightProgress, rightGotReward = AchievementData.CheckStatus(right.id)
    local leftReach = leftProgress >= left.needNum
    local rightReach = rightProgress >= right.needNum
    if leftReach and not rightReach then
        return not leftGotReward
    end
    if not leftReach and rightReach then
        return rightGotReward
    end
    if leftReach and rightReach then
        if leftGotReward and not rightGotReward then
            return false
        end
        if not leftGotReward and rightGotReward then
            return true
        end
    end
    return left.order < right.order
end

--道具
function M:OnCreateItem(index, coms)
	-- coms.txtName = self:FindText("TxtName", coms.trans)--等级
	coms.txtDesc = self:FindText("TxtName", coms.trans)--描述
	coms.uiGet = self:FindGameObject("BtnGet", coms.trans)--领取
	coms.uiCharge = self:FindGameObject("BtnCharge", coms.trans)--充值

	--已领取
	coms.uiAlreadyBuy = self:FindGameObject("ImgCantGet", coms.trans)
	-- coms.uiNotAchieve = self:FindGameObject("ImgAchieve", coms.trans)--未达成
	
	--奖励
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)
	coms.rewardContainer = {}

	--按钮事件
	UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)
	UguiLuaEvent.ButtonClick(coms.uiCharge, nil, function(go)
		self:OnClickGet(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms, go)
	end)
end

function M:OnClickGet(index, coms, go)
	local achieveTab = self.dailyTargetAchieveTable[index]
	local progress, gotReward, reachTime = AchievementData.CheckStatus(achieveTab.id)
	if progress >= achieveTab.needNum then
		AchievementData.RequestGetReward(achieveTab.id)
	elseif achieveTab.guideMenu then
		require("Manager.MenuEventManager").DoMenu(achieveTab.guideMenu)
	end
end

function M:UpdateItem(index, coms)
	local achieveTab = self.dailyTargetAchieveTable[index]
	if achieveTab ~= nil then

		local progress, gotReward, reachTime = AchievementData.CheckStatus(achieveTab.id)

		--名称、描述
		-- coms.name.text = UITools.FormatQualityText(achieveTab.quality, achieveTab.name)
		-- print(achieveTab.desc)
		coms.txtDesc.text = string.format("%s(<color=#45CF75>%d/%d</color>)", achieveTab.desc, progress, achieveTab.needNum)
		-- UITools.SetImageIcon(coms.icon, achieveTab.guideAtlas, achieveTab.guideIcon, false)

		-- 刷新奖励
		if achieveTab.reward then
			self.rewardExParams = self.rewardExParams or {isnative = true, showQualityEffect = true}
			-- print(achieveTab.reward)
			UITools.CopyRewardList({achieveTab.reward}, coms.rewardContainer, coms.transRewardItem, self.rewardExParams)
		end

		if gotReward then
			--已经领取
			coms.uiGet:SetActive(false)
			coms.uiCharge:SetActive(false)
			coms.uiAlreadyBuy:SetActive(true)
		elseif progress >= achieveTab.needNum then
			--可领取
			coms.uiGet:SetActive(true)
			coms.uiCharge:SetActive(false)
			coms.uiAlreadyBuy:SetActive(false)
		else
			--充值
			coms.uiGet:SetActive(false)
			coms.uiCharge:SetActive(true)
			coms.uiAlreadyBuy:SetActive(false)
		end
	end
end

return M