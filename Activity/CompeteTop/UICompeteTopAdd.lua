--[[
  谁与争锋--中途补给
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local CompeteTop = dataMgr.CompeteTopData
local intLen = 3
local preUpdateTime = -999
local buffIcon = {"skillicon_gongjizengqiang", "skillicon_fangyuzengqiang", "skillicon_qixuezengqiang"}

function M.Open(params)
    uiMgr.ShowAsync("UICompeteTopAdd")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    self.textTime = self:FindText("Offset/Bottom/TextTime")
    self.textCur = self:FindText("Offset/Bottom/TextCur")

    self.prefabParent = self:FindTransform("Offset/Content")
    self.comsTable = {}
    for i=1,intLen do
        self.comsTable[i] = {}
        self.comsTable[i].trans = self:FindTransform(string.format("Item (%s)", i), self.prefabParent)
        self.comsTable[i].go = self.comsTable[i].trans.gameObject
        self:OnCreateItem(i, self.comsTable[i])
    end

    -- 加成数据
    self.comsAddTable = {}
    for i=1,3 do
        self.comsAddTable[i] = {}
        self.comsAddTable[i].trans = self:FindTransform(string.format("Offset/Top/Add (%s)", i))
        self.comsAddTable[i].image = self:FindImage("ImageIcon", self.comsAddTable[i].trans)
        self.comsAddTable[i].text = self:FindText("TextPrice", self.comsAddTable[i].trans)
    end
end

function M:Show()
    base.Show(self)
    
    self.curSelect = 1
    self.remainTime = 30

    self:ResetData()
end

function M:ResetData()
    self.cdata = CompeteTop.GetCurCompeteConfig()
    self.curInfoPb = CompeteTop.GetCurInfo()

    if self.curInfoPb == nil or self.curInfoPb.id == 0 then
        return
    end

    self.copyId = CompeteTop.GetCurCopyId()
    self.buffList = CompeteTop.GetNextBuff(self.copyId)
    self.buffAdded = CompeteTop.GetBuffAdded()

    for i,v in ipairs(self.buffList) do
        self:OnUpdateItem(i, self.comsTable[i])
    end
    local str = "当前第<color=#00aa00>%s/%s</color>波,拥有%s"
    self.textCur.text = string.format(str, self.curInfoPb.round, self.cdata.maxRound, self.curInfoPb.star)

    self:SetCurAdd(self.buffAdded)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:SetCurAdd(tb)
    local len = #tb
    for i,v in ipairs(self.comsAddTable) do
        UITools.SetImageIcon(v.image, Const.atlasName.SkillIcon, buffIcon[i])
        if i <= len then
            v.text.text = tb[i].."%"
        else
            v.text.text = "0%"
        end
    end
end

function M:GetLoopItem(idx)
   return self.buffList[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.transButtonOK = self:FindTransform("ButtonOK", trans)
    coms.textBuff = self:FindText("Reward/Text", trans)
    coms.transSelect = self:FindTransform("ImageSelect", trans)
    coms.textPrice = self:FindText("ButtonOK/TextPrice", trans)
    coms.imageIcon = self:FindImage("#006ItemData/ImgIcon", trans)
	
    UguiLuaEvent.ButtonClick(coms.transButtonOK.gameObject, nil, function() self:OnChooseItem(index, coms) end)
end

function M:OnUpdateItem(index, coms)
    local data = self:GetLoopItem(index)
    coms.textBuff.text = string.format("%s加<color=#00aa00>%s</color>%%", CompeteTop.GetAddStr(data.addType), data.addRate)

    UITools.SetImageIcon(coms.imageIcon, Const.atlasName.SkillIcon, buffIcon[data.addType])

    coms.transSelect.gameObject:SetActive(self.curSelect == index)

    coms.textPrice.text = string.format("消耗%s星", data.cost)
end

function M:OnChooseItem(index, coms)
    if not self.curInfoPb then
        return
    end
    local data = self:GetLoopItem(index)
    if self.curInfoPb.star < data.cost then
        Tips("星数不足")
        return
    end

    self.curSelect = index
    self:ResetData()

    self:Hide()
    CompeteTop.SendChooseBuff(self.curSelect)
end

function M:OnClick(go)
    local goName = go.name

    if goName == "ButtonClose" then
        self:Hide()
    end
end

function M:Update()
    if Time.realtimeSinceStartup - preUpdateTime < 1 then
        return
    end
    preUpdateTime = Time.realtimeSinceStartup

    self.remainTime = self.remainTime - 1
    if self.remainTime <= 0 then
        self.remainTime = 0
        self:OnChooseItem(self.curSelect)
        self:Hide()
    end
    self.textTime.text = self.remainTime
end

return M