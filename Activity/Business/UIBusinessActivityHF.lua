--[[
    合服活动
]]
--------------
local uiType = Const.BusinessType.UIHF
local uiName = "UIBusinessActivityHF"
local uiTitle = "合服活动"

local UguiLuaEvent = require "UguiLuaEvent"
local SkillTable = require "Excel.SkillTable"
local BusinessData = require "Data.BusinessData"
local base = require "UI.UIMultiPage"
local M = base:Extend()

local preUpdateTime = -999
local toggleNotifyPos = Vector3.New(90,17,0)

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

-------------------------运营活动
local curOpenParams = nil
--[[
    openParams {bid = xx}
]]
function M.Open(openParams)
    if not BusinessData.HasBusinessOpen(uiType) then
        Tips("活动已全部结束")
        return
    end

    curOpenParams = openParams
    uiMgr.ShowAsync(uiName)
end

function M:Awake()
    self.curChild = nil

    --测试，先生成子面板数据
    self:GenAllToggles()

	base.Awake(self)

    self.offset = self:FindGameObject("Offset")
    self.title = self:FindText("Offset/Others/Title")
    self.title.text = uiTitle or ""

    --关闭按钮
    self.tranClose = self:FindTransform("Offset/ButtonClose")
    UguiLuaEvent.ButtonClick(self.tranClose.gameObject, self, M.Hide)
end

--筛选出今天的（每个服务器不同，所以由服务器传来），已经开启的，运营活动
function M:GenAllToggles()
    self.transPrefab = self:FindTransform("Offset/Left/ScrollView/Viewport/Content/Toggle")
    self.transPrefab.gameObject:SetActive(false)

    self.transTogList = {}

    local businessCfg = excelLoader.BusinessActivityTable
    self.sortedBusinessCfg = {}
    for k,v in pairs(businessCfg) do
        if v.uitype == uiType and v.isShow then
            table.insert(self.sortedBusinessCfg, v)
        end
    end
    local sortFunc = function(a, b)
        if a.priority == b.priority then
            return a.id < b.id
        else
            return a.priority < b.priority
        end
    end
    table.sort(self.sortedBusinessCfg, sortFunc)

    -- 显示
    if #self.sortedBusinessCfg > 0 then
        local parentGo = self.transPrefab.parent.gameObject
        local go = self.transPrefab.gameObject
        local newGo
        for i,v in ipairs(self.sortedBusinessCfg) do
            newGo = UITools.AddChild(parentGo, go, true)
            newGo.name = string.format("Toggle (%s)", i)
            self.transTogList[i] = newGo.transform
            newGo:SetActive(true)
            self:FindText("Label", self.transTogList[i]).text = v.name
        end
    end
end

function M:InitConfig()
    base.InitConfig(self)

    self.uiChilds = {
        --{index = 1,name = "UIGuildMission", path = "UI.Guild", instance = nil, notify = GuildData.NoticeGuildTask},
    }

    for i,v in ipairs(self.sortedBusinessCfg) do
        self.uiChilds[i] = {}
        self.uiChilds[i].index = i
        self.uiChilds[i].name = v.uiname
        self.uiChilds[i].path = v.uipath
        self.uiChilds[i].instance = nil
        self.uiChilds[i].notify = nil
        self.uiChilds[i].data = {id=v.id}
        self.uiChilds[i].parent = self
    end

    local togLen = #self.transTogList
    self.toggleConfig = {path = "Offset/Left/ScrollView/Viewport/Content", len = togLen}
    self.notifyPosition = Vector3.New(58.6,12.8,0)

    self.transChildParent = self:FindTransform("Offset/Right")
end

function M:Show()
    base.Show(self)
    
    --self:TweenOpen(self.offset)

    BusinessData.RequestBusinessInfo()

    self.curTog = nil
    if curOpenParams then
        if curOpenParams.toggle then
            self.curTog = curOpenParams.toggle
        elseif curOpenParams.bid then
            for i,v in ipairs(self.uiChilds) do
                if v.data.id == curOpenParams.bid then
                    self.curTog = i
                    break
                end
            end
        end
        
        if self.curTog then
            UITools.SetToggleOnIndex(self.toggles, self.curTog)
        end
    end
    curOpenParams = nil

    self.curChild = nil

    self:ResetData()
    self:TweenOpen(self.offset)
end

function M:GetFirstActiveIndex()
    for i,v in ipairs(self.sortedBusinessCfg) do
        if BusinessData.IsBusinessActivityOpen(v.id) then
            return i
        end
    end
end 

function M:UpdateNotifys()
    for i,v in ipairs(self.uiChilds) do
        notifyMgr.AddNotify(self.toggles[i], BusinessData.IsNotify(v.data.id), toggleNotifyPos, notifyMgr.NotifyType.Common)
    end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Recharge then
		BusinessData.RequestBusinessInfo()
    elseif cmd == LocalCmds.Business and msg then
        if msg.cmd == "resetroot" then
            self:ResetData()
        elseif msg.cmd == Cmds.GetBusinessActivityInfo.index then
            self:ResetData()
        else
            self:UpdateNotifys()
        end
    end
end

function M:ResetData()
    base.ResetData(self)

    local tab
    for i,v in ipairs(self.uiChilds) do
        self.toggles[i].gameObject:SetActive(BusinessData.IsBusinessActivityOpen(v.data.id))
    end

    self:UpdateNotifys()

    if not self.curTog or not self.toggles[self.curTog].gameObject.activeSelf then
        self.curTog = self:GetFirstActiveIndex()

        if self.curTog then
            UITools.SetToggleOnIndex(self.toggles, self.curTog)
        else
            Tips("活动已全部结束")
            self:Hide()
        end
    end

    self.curChild = self.curTog and self.uiChilds[self.curTog]
end

function M:Update()
	base.Update(self)

	if Time.time - preUpdateTime < 0.3 then
		return
	end
	preUpdateTime = Time.time

    if self.curChild and self.curChild.instance and self.curChild.instance.UpdateChild then
        self.curChild.instance:UpdateChild()
    end

	if self.curChild and not BusinessData.IsBusinessActivityOpen(self.curChild.data.id) then
        Tips("当前活动结束")
        self:ResetData()
    end
end

return M