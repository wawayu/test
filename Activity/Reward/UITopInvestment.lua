--[[
    至尊投资
]]
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
local PanelType = {
    Profit = 1, 
    Investment = 2,
}

local LeftTab = {
    {name = "一本万利", type = PanelType.Profit, notifyfun = notifyMgr.IsProfitRewardNotify},
    {name = "投资计划", type = PanelType.Investment, notifyfun = BusinessData.IsInvestmentRewardExisted},
}

local SubPanelPath = {
    "Offset/UIBAMillionProfit",
    "Offset/UIBAInvestment",
}

M.childPanelConfig = {
    [SubPanelPath[PanelType.Profit]] = "UI.Activity.Business.UIBAMillionProfit",
    [SubPanelPath[PanelType.Investment]] = "UI.Activity.Business.UIBAInvestment",
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
    uiMgr.ShowAsync("UITopInvestment")
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

    --以type作为索引
    self.rewardItemContainer = {}
end

function M:Close()
    -- body
    self:Hide()
    --mainEntryNotify.RefreshAllNotify()
end

function M:Show()
    base.Show(self)
    self:TweenOpen(self.offset)

    for i, v in ipairs(LeftTab) do
        v.hide = nil
    end 
    self.curLeftTab = LeftTab

    self:ResetCurLeftTab()
    
    -- 删除tog已经完成
    if openParams and openParams.panelType then
        self.selectIndex = self:GetSelectIndex(openParams.panelType)
        openParams.panelType = nil
    else
        self.selectIndex = 1
    end
    self:ResetBase()
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
    --一本万利特殊处理，所有天数都领取完了，隐藏该界面
    if self:GetLeftTabByType(PanelType.Profit) then
        if dataMgr.RechargeData.IsProfitHide() then
           self:RemovePanel(PanelType.Profit)
        end
    end

    --投资计划特殊处理，所有天数都领取完了，隐藏该界面
    if self:GetLeftTabByType(PanelType.Investment) then
        if dataMgr.BusinessData.IsAllInvestmentGet() then
            self:RemovePanel(PanelType.Investment)
        end
    end

    ---IOS审核
    if IOS_VERIFY then
        self:RemovePanel(PanelType.Profit)
        self:RemovePanel(PanelType.Investment)
    end

    self.curLeftTab = self:SortPanel()
end

function M:ResetBase()
    self:ResetCurLeftTab()

    if #self.curLeftTab == 0 then
        Tips("至尊投资已领取完")
        return
    end
    --刷新左侧界面
    self.uiLeftLoop.ItemsCount = #self.curLeftTab
    
    if self.selectIndex > #self.curLeftTab then
        self.selectIndex = 1
    end
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

----------------------------------------------------------------------

--左边
function M:AddTabNotify(go, tabInfo)
    if not tabInfo then return end
    local isNotify = false
    if tabInfo.notifyfun then
        isNotify = tabInfo.notifyfun()
    end
    notifyMgr.AddNotify(go, isNotify, toggleNotifyPos, notifyMgr.NotifyType.Common)
end

function M:CheckActive()
    if not moduleMgr.IsModuleEntryShow(moduleMgr.moduleID.TopInvestment) then
        self:Hide()
    end
end

return M