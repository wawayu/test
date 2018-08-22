local GuidelinesData = dataMgr.GuidelinesData
local AchievementData = dataMgr.AchievementData
local AchievementTable = excelLoader.AchievementTable

local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local openGuidelineID
function M.Open(openParams)
    openGuidelineID = openParams and openParams.guidelineID
    M.closeTween = openParams and openParams.closeTween
    uiMgr.ShowAsync("UIGuidelines")
end

function M:Awake()
    base.Awake(self)

    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/ButtonClose"), self, M.Hide)

    self.frame = self:FindGameObject("Frame")

    self.toggleTree = self:FindToggleTree("Frame/Left/Scroll View/Viewport/Content")

    self.toggleTree:BeginAdd()
    for i, v in ipairs(GuidelinesData.guidelinesPageDatas) do
        local achiTb = AchievementTable[v.extraAchi]
        if achiTb then
            self.toggleTree:AddFirst(achiTb.firstGroup)
        end
    end
    self.toggleTree:EndAdd()

    self.toggleTree.onChanged = function(firstIndex, secondIndex, toggle)
        self:OnToggleTreeChanged(firstIndex + 1)
    end
    self.toggleTree.onUpdate = function(firstIndex, secondIndex, toggle)
        self:NotifyRedPointByTreeIndex(firstIndex + 1, secondIndex + 1, toggle)
    end

    self.uiLoop = self:FindLoop("Frame/Right/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.OnUpdateItem)

    self.extraItems = {}
    for i = 1, 3 do
        self.extraItems[i] = {
            transRoot = self:FindTransform("Frame/Right/ExtraReward/Item"..tostring(i))
        }
    end
    self.extraBar = self:FindTransform("Frame/Right/ExtraReward/Bar/Bar")
    self.extraBarVal = self:FindText("Frame/Right/ExtraReward/Bar/Val")
    self.extraBtnGet = self:FindGameObject("Frame/Right/ExtraReward/BtnGet")
    self.extraGetDone = self:FindGameObject("Frame/Right/ExtraReward/Done")

    UguiLuaEvent.ButtonClick(self.extraBtnGet, self, M.OnClickGetExtraReward)

    self.toggleReward = self:FindGameObject("Frame/ToggleReward")
    self.toggleGuidelines = self:FindGameObject("Frame/ToggleGuidelines")
    UguiLuaEvent.ButtonClick(self.toggleReward, self, M.OnClickOpenReward)
end

function M:Show()
    base.Show(self)

    local openFirstIndex = 0
    if openGuidelineID then
        local found = false
        for i, v in ipairs(GuidelinesData.guidelinesPageDatas) do
            for i2, v2 in ipairs(v) do
                if v2.id == openGuidelineID then
                    openFirstIndex = i - 1
                    found = true
                    break
                end
            end
            if found then
                break
            end
        end
    end

    self.toggleTree:SelectIndex(openFirstIndex, -1)

    self:OnToggleTreeChanged(openFirstIndex + 1, openGuidelineID)

	self:TweenOpen(self.frame)
end

function M:ResetBase()
    local tableData = AchievementTable[self.pageDatas.extraAchi]
    local progress, gotReward, reachTime = AchievementData.CheckStatus(tableData.id)

    local rewards = dataMgr.ItemData.GetRewardList({tableData.reward})
    for i, v in ipairs(self.extraItems) do
        UITools.SetCommonItem(v, rewards[i], nil, {showtips = true})
    end

    if gotReward then
        self.extraBar.parent.gameObject:SetActive(false)
        self.extraBtnGet:SetActive(false)
        self.extraGetDone:SetActive(true)
    elseif progress >= tableData.needNum then
        self.extraBar.parent.gameObject:SetActive(false)
        self.extraBtnGet:SetActive(true)
        self.extraGetDone:SetActive(false)
    else
        self.extraBar.parent.gameObject:SetActive(true)
        self.extraBar.localScale = Vector3.New(Mathf.Clamp01(progress / tableData.needNum), 1, 1)
        self.extraBarVal.text = string.format("%d/%d", progress, tableData.needNum)
        self.extraBtnGet:SetActive(false)
        self.extraGetDone:SetActive(false)
    end

    self:UpdateNotify()
end

-------------------------------------------------------------------
function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.Achievement then
        self.pageDatas = GuidelinesData.GetGuidelinesPageDatas(self.currentPageIndex)
        self.uiLoop:UpdateAll()
        self:ResetBase()
    end
end

function M:OnToggleTreeChanged(index, guidelineID)
    if not GuidelinesData.IsGuidelinesOpen(index) then
        Tips("未达到指定等级")
        if GuidelinesData.IsGuidelinesOpen(self.currentPageIndex) then
            local trans = self.toggleTree.transform
            local oirPos = trans.anchoredPosition
            self.toggleTree:SelectIndex(self.currentPageIndex - 1, -1)
            trans.anchoredPosition = oirPos
        end
        return
    end

    self.currentPageIndex = index
    self.pageDatas = GuidelinesData.GetGuidelinesPageDatas(index)
    local loopIndex = 0
    if guidelineID then
        for i, v in ipairs(self.pageDatas) do
            if v.id == guidelineID then
                loopIndex = i - 1
                break
            end
        end
    end
    self.uiLoop.ItemsCount = #self.pageDatas
    self.uiLoop:ScrollToGlobalIndex(loopIndex)
    self:ResetBase()
end

function M:OnCreateItem(index, coms)
    coms.name = self:FindText("Name", coms.trans)
    coms.desc = self:FindText("Desc", coms.trans)
    coms.icon = self:FindImage("Icon", coms.trans)
    coms.rewardItem = {
        transRoot = self:FindTransform("Item", coms.trans)
    }
    coms.btnGet = self:FindGameObject("BtnGet", coms.trans)
    coms.btnGoto = self:FindGameObject("BtnGoto", coms.trans)
    coms.goDone = self:FindGameObject("Done", coms.trans)

    local clickFun = function()
        self:OnClickGetReward(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
    end

    UguiLuaEvent.ButtonClick(coms.btnGet, nil, clickFun)
    UguiLuaEvent.ButtonClick(coms.btnGoto, nil, clickFun)
end

function M:OnUpdateItem(index, coms)
    local tableData = self.pageDatas[index]
    local progress, gotReward, reachTime = AchievementData.CheckStatus(tableData.id)

    coms.name.text = UITools.FormatQualityText(tableData.quality, tableData.name)
    coms.desc.text = tableData.desc
    UITools.SetImageIcon(coms.icon, tableData.guideAtlas, tableData.guideIcon, false)

    if tableData.reward then
        local reward = dataMgr.ItemData.GetRewardSingle(tableData.reward)
        if reward.tp == Const.REWARD_SUBTYPE_ITEM then
            --物品
            UITools.SetCommonItem(coms.rewardItem, reward, nil, {showtips = true})
        else
            --称号
        end
    end

    if gotReward then
        coms.btnGet:SetActive(false)
        coms.btnGoto:SetActive(false)
        coms.goDone:SetActive(true)
    elseif progress >= tableData.needNum then
        coms.btnGet:SetActive(true)
        coms.btnGoto:SetActive(false)
        coms.goDone:SetActive(false)
    else
        coms.btnGet:SetActive(false)
        coms.btnGoto:SetActive(true)
        coms.goDone:SetActive(false)
    end
end

function M:OnClickGetReward(index, coms)
    local tableData = self.pageDatas[index]
    local progress, gotReward, reachTime = AchievementData.CheckStatus(tableData.id)
    if progress >= tableData.needNum then
        AchievementData.RequestGetReward(tableData.id)
    elseif tableData.guideMenu then
        require("Manager.MenuEventManager").DoMenu(tableData.guideMenu)
    end
end

function M:OnClickGetExtraReward()
    AchievementData.RequestGetReward(self.pageDatas.extraAchi)
end

function M:OnClickOpenReward()
    OpenUI("UIReward", {closeTween = true})
end

-------------------------------------------------------------------
function M:UpdateNotify()
    notifyMgr.AddNotify(self.toggleReward, notifyMgr.IsWelfareNotify(), notifyMgr.NotifyPosition.tab, notifyMgr.NotifyType.Common)  
    notifyMgr.AddNotify(self.toggleGuidelines, notifyMgr.IsGuidelinesNotify(), notifyMgr.NotifyPosition.tab, notifyMgr.NotifyType.Common)

    self.toggleTree:UpdateAll()
end

function M:NotifyRedPointByTreeIndex(firstIndex, secondIndex, toggle)
    local isOpen = GuidelinesData.IsGuidelinesOpen(firstIndex)
    local staticPageData = GuidelinesData.guidelinesPageDatas[firstIndex]
    local achiTb = AchievementTable[staticPageData.extraAchi]
    local notify = isOpen and AchievementData.IsContainRedPointByGroup(achiTb.firstGroup)
    notifyMgr.AddNotify(toggle, notify, Vector3.New(60, 18, 0), notifyMgr.NotifyType.Common)

    UITools.SetImageGrey(self:FindImage("Background", toggle.transform), not isOpen)
end

return M