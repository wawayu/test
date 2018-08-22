local UguiLuaEvent = require "UguiLuaEvent"

local SkillTable = require "Excel.SkillTable"
local BusinessData =dataMgr.BusinessData
local mainEntryNotify = require("Manager.MainEntryNotify")
local base = require "UI.UILuaBase"
local M = base:Extend()
local toggleNotifyPos = Vector3.New(90,17,0)

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

--需要同时修改UIReward.lua文件的 PanelType, LeftTab, SubPanelPath, M.childPanelConfig, 以及NotifyManager.lua的 M.RewardNotifyFunction
local PanelType = {
    Daily = 1, 
    Seven = 2,  
    Online = 3, 
    Level = 4, 
    Resource = 5, 
    Card = 6, 
    Flip=7,
    ActiveCode = 8, 
    Problem = 9,
}

--需要同时修改UIReward.lua文件的 PanelType, LeftTab, SubPanelPath, M.childPanelConfig, 以及NotifyManager.lua的 M.RewardNotifyFunction
local LeftTab = {
    {name = "每日签到", type = PanelType.Daily},
    {name = "7日登陆", type = PanelType.Seven},
    {name = "在线福利", type = PanelType.Online},
    {name = "等级礼包", type = PanelType.Level},
    {name = "资源找回", type = PanelType.Resource},
    {name = "月卡至尊", type = PanelType.Card},
    {name = "翻翻乐", type = PanelType.Flip},
    {name = "兑换码", type = PanelType.ActiveCode},
    {name = "反馈问题", type = PanelType.Problem},
}

--需要同时修改UIReward.lua文件的 PanelType, LeftTab, SubPanelPath, M.childPanelConfig, 以及NotifyManager.lua的 M.RewardNotifyFunction
local SubPanelPath = {
    "Offset/SignPanel",
    "Offset/SevenLoginPanel",
    "Offset/OnlinePanel",
    "Offset/LevelPanel",
    "Offset/ResourcePanel",
    "Offset/UIBAMonthCard",
    "Offset/FlipCards",
    "Offset/ActivePanel",
    "Offset/ProblemPanel",
}

--需要同时修改UIReward.lua文件的 PanelType, LeftTab, SubPanelPath, M.childPanelConfig, 以及NotifyManager.lua的 M.RewardNotifyFunction
M.childPanelConfig = {
    [SubPanelPath[1]] = "UI.Activity.Reward.UIDailySign",
    [SubPanelPath[2]] = "UI.Activity.Reward.UISevenLogin",
    [SubPanelPath[3]] = "UI.Activity.Reward.UIOnlineReward",
    [SubPanelPath[4]] = "UI.Activity.Reward.UILevelReward",
    [SubPanelPath[5]] = "UI.Activity.Reward.UIResourceFind",
    [SubPanelPath[6]] = "UI.Activity.Business.UIBAMonthCard",
    [SubPanelPath[7]] = "UI.Activity.Reward.UIFlipCards",
    [SubPanelPath[8]] = "UI.Activity.Reward.UIActivePanel",
    [SubPanelPath[9]] = "UI.Activity.Reward.UIProblemSubmit",
}

local openParams
--[[
    panelIndex == panelType
]]
function M.Open(_openParams)
    
    openParams= _openParams
    if openParams and openParams.panelIndex then
        openParams.panelType = openParams.panelIndex
    end
    
    M.closeTween = _openParams and _openParams.closeTween
    uiMgr.ShowAsync("UIReward")
end

function M:Awake()
	base.Awake(self)

    self.offset = self:FindGameObject("Offset")

    --左边UILoop
	self.uiLeftLoop = self:FindGameObject("Offset/Left/ScrollView/Viewport/Content"):GetComponent(typeof(UILoop))
    self:BindLoopEventEx(self.uiLeftLoop, M.OnCreateItem, M.UpdateTabItem, M.OnChooseTab)

    self.tranSelect = self:FindTransform("Offset/Left/ScrollView/Viewport/ImgSelect")

    --关闭按钮
    self.tranClose = self:FindTransform("Offset/ButtonClose")
    UguiLuaEvent.ButtonClick(self.tranClose.gameObject, self, M.Close)

    self.toggleReward = self:FindGameObject("Offset/ToggleReward")
    self.toggleGuidelines = self:FindGameObject("Offset/ToggleGuidelines")
    UguiLuaEvent.ButtonClick(self.toggleGuidelines, self, M.OnClickOpenGuidelines)

    --以type作为索引
    self.rewardItemContainer = {}
end

function M:Close()
    -- body
    self:Hide()
    mainEntryNotify.RefreshAllNotify()
end
function M:Show()
    base.Show(self)
    self:TweenOpen(self.offset)

    for i, v in ipairs(LeftTab) do
        v.hide = nil
    end 
    self.curLeftTab = LeftTab

    self:ResetCurLeftTab()

    local isNotifySeven = self:IsLeftNotify(PanelType.Seven)
    local isNotifyDaily = self:IsLeftNotify(PanelType.Daily)
    
    -- 删除tog已经完成
    if openParams and openParams.panelType then
        self.selectIndex = self:GetSelectIndex(openParams.panelType)
        openParams.panelType = nil
    -- 优先显示七日/ 次优先显示红点的
    elseif dataMgr.SevenDayData.IsAllSevenLoginGet() or (isNotifyDaily and not isNotifySeven) then
        self.selectIndex = 1
    else
        self.selectIndex = 2
    end
    self:ResetBase()

    local scrollTo = self.selectIndex - 1
    if scrollTo == 1 then
        scrollTo = 0
    end
    self.uiLeftLoop:ScrollToGlobalIndex(scrollTo)
end

function M:GetSelectIndex(panelType)
    if self.curLeftTab == nil then
        return 1
    end

    for i,v in ipairs(self.curLeftTab) do
        if v.type == panelType then
            return i
        end
    end

    return 1
end

-- 重置当前左边tog数据
function M:ResetCurLeftTab()
    --7日登陆特殊处理，所有天数都领取完了，隐藏该界面
    if self:GetLeftTabByType(PanelType.Seven) then
        if dataMgr.SevenDayData.IsAllSevenLoginGet() then
            self:RemovePanel(PanelType.Seven)
        end
    end

    --翻翻乐特殊处理，当奖励领取完毕隐藏
    if self:GetLeftTabByType(PanelType.Flip) then
        local bid = BusinessData.GetFlipCardsID()
	    if bid>0 then
            local script = BusinessData.GetScript(bid)
            if script:IsGetMoney() then
                self:RemovePanel(PanelType.Flip)
            end
        else
            self:RemovePanel(PanelType.Flip)
        end
    end

    --一本万利特殊处理，所有天数都领取完了，隐藏该界面
    if self:GetLeftTabByType(PanelType.Profit) then
        if dataMgr.RechargeData.IsProfitHide() then
           self:RemovePanel(PanelType.Profit)
        end
    end

    --一本万利特殊处理，所有天数都领取完了，隐藏该界面
    if self:GetLeftTabByType(PanelType.Investment) then
        if dataMgr.BusinessData.IsAllInvestmentGet() then
            self:RemovePanel(PanelType.Investment)
        end
    end
    ---关闭问题反馈
    self:RemovePanel(PanelType.Problem)

    ---IOS审核
    if IOS_VERIFY then
        self:RemovePanel(PanelType.Card)
        self:RemovePanel(PanelType.Profit)
        self:RemovePanel(PanelType.Investment)
        self:RemovePanel(PanelType.ActiveCode)
    end

    self.curLeftTab = self:SortPanel()
end

function M:ResetBase()
    self:ResetCurLeftTab()
    -- PrintTable(self.curLeftTab)
    --刷新左侧界面
    self.uiLeftLoop.ItemsCount = #self.curLeftTab
    
    self:UpdateNotify()

    --默认第一个子面板（每日签到）
    self:ShowChildPanelByIndex(self.selectIndex)
end

function M:GetLeftTabByType(tp)
    if self.curLeftTab then
        for i, v in ipairs(self.curLeftTab) do
            if v.type == tp then
                return v
            end
        end
    end
    return nil
end

function M:SortPanel()
	local tabs = {}
    -- PrintTable(PanelType)
    for i, v in ipairs(LeftTab) do
        if not v.hide then
           table.insert(tabs, v)
        end
    end
    return tabs
end

function M:RemovePanel(tp)
    for i, v in ipairs(LeftTab) do
        if v.type == tp then
            --print(v.name)
            v.hide = true
            break
        end
    end
end

function M:OnCreateItem(index, coms)
	coms.txtLv = self:FindText("Name", coms.trans)--等级
end

--选中左边的Tab
function M:OnChooseTab(index, coms)
    self.selectIndex = index

    self:ResetBase()
end

--显示子面板
function M:ShowChildPanelByIndex(index)
    local tabInfo = self.curLeftTab[index]
	if tabInfo then
		local panelPath = SubPanelPath[tabInfo.type]
        if panelPath ~= nil then
            self.curChildPanel = self.childs[panelPath]
            --当前面板show，其他面板hide
            self:ShowSingleChild(self.curChildPanel)
        end
    else
        print("error UIReward ShowChildPanelByIndex no Index ", type)
	end
end

function M:UpdateTabItem(index, coms)
	local tabInfo = self.curLeftTab[index]
	if tabInfo then
		coms.txtLv.text = tabInfo.name

        --新手引导
        self:UpdateContainer(tabInfo.type, coms)

         --红点
        self:AddTabNotify(coms.go, tabInfo)        
	end

    --设置选中框
	if self.selectIndex == index then
		self:SetSelectedBound(coms.go, self.tranSelect)
	elseif self.tranSelect.parent == coms.trans then
  		self.tranSelect.anchoredPosition = Vector2.New(99999, 99999)
	end
end

-- 设置选中框
function M:SetSelectedBound(parentGo, boundTrans)
	UITools.AddChild(parentGo, boundTrans.gameObject, false)
	boundTrans.anchoredPosition3D = Vector3.zero
	boundTrans.gameObject:SetActive(true)
    boundTrans:SetSiblingIndex(0)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity or cmd == LocalCmds.RecordUpdate 
        or cmd == LocalCmds.Recharge or cmd == LocalCmds.Business  then
        self:ResetBase()
    end
end

-----------------新手引导
function M:UpdateContainer(type, coms)
	for i, v in ipairs(self.rewardItemContainer) do
		if v.type == type then
			v.coms = coms
			return
		end
	end
    
    --新增
    table.insert(self.rewardItemContainer, {type = type, coms = coms})
end

--传入type（这里是LeftTab中的type），返回组件容器
function M:GetRewardItemByTp(type)
	for i, v in ipairs(self.rewardItemContainer) do
		if v.type == type then
			return v
		end
	end
	return nil
end

function M:OnClickOpenGuidelines()
    OpenUI("UIGuidelines", {closeTween = true})
end

----------------------------------------------------------------------

function M:IsLeftNotify(tp)
    local func = notifyMgr.RewardNotifyFunction[tp]
    if func then
        return func()
    end

    return false
end

--左边
function M:AddTabNotify(go, tabInfo)
    if not tabInfo then return end
    notifyMgr.AddNotify(go, self:IsLeftNotify(tabInfo.type), toggleNotifyPos, notifyMgr.NotifyType.Common)
end

--右边，福利，指引的tab
function M:UpdateNotify()
    notifyMgr.AddNotify(self.toggleReward, notifyMgr.IsWelfareNotify(), notifyMgr.NotifyPosition.tab, notifyMgr.NotifyType.Common)  
    notifyMgr.AddNotify(self.toggleGuidelines, notifyMgr.IsGuidelinesNotify(), notifyMgr.NotifyPosition.tab, notifyMgr.NotifyType.Common)
end

return M