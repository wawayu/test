--[[
  谁与争锋--结算
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local CompeteTop = dataMgr.CompeteTopData
local preUpdateTime = -999

function M.Open(params)
    uiMgr.ShowAsync("UICompeteTopResult")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    self.textCount = self:FindText("Offset/PanelTop/TextCount")
    self.textTime = self:FindText("Offset/TextTime")

    self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.OnUpdateItem)
end

function M:Show()
    base.Show(self)
    
    self.remainTime = 30
    CompeteTop.SyncSyzfRecordInfo(true)

    self:ResetData()
end

function M:ResetData()
    local curInfo = CompeteTop.GetCurInfo()
    if curInfo == nil or curInfo.id == 0 then
        return
    end

    self.data = CompeteTop.GetResult()

    self.itemList = {}
    for i,v in ipairs(self.data.itemlist) do
        self.itemList[i] = {itemid = v.itemid, num = v.num}
    end
    table.insert(self.itemList, {itemid = 0, isRound = true, num = self.data.curRound})

    self.uiLoop.ItemsCount = #self.itemList

    self.textCount.text = self.data.topRound
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:GetLoopItem(idx)
    return self.itemList[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.image = self:FindImage("Image", trans)
    coms.image2 = self:FindImage("Image2", trans)
	coms.textName = self:FindText("TextName", trans)
	coms.imageIcon = self:FindImage("ImageIcon", trans)
	coms.textValue = self:FindText("TextValue", trans)
end

function M:OnUpdateItem(index, coms)
    local data = self:GetLoopItem(index)
    coms.image.gameObject:SetActive(index % 2 == 0)
    coms.image2.gameObject:SetActive(index % 2 == 1)

    if data.isRound then
        coms.textName.text = "波次"
        coms.textValue.text = data.num.."波"
        UITools.SetImageEmpty(coms.imageIcon)
    else
        local itemConfig = excelLoader.ItemTable[data.itemid]
        coms.textName.text = itemConfig.name
        coms.textValue.text = data.num
        UITools.SetItemIcon(coms.imageIcon, data.itemid)
    end
end

function M:OnClick(go)
    local goName = go.name

    if goName == "ButtonClose" then
        self:Hide()
    end
end

function M:Hide()
    base.Hide(self)
    
    CompeteTop.ExitScene()
end

function M:Update()
    if Time.realtimeSinceStartup - preUpdateTime < 1 then
        return
    end
    preUpdateTime = Time.realtimeSinceStartup

    self.remainTime = self.remainTime - 1
    if self.remainTime <= 0 then
        self.remainTime = 0
        self:Hide()
    end
    self.textTime.text = self.remainTime
end

return M