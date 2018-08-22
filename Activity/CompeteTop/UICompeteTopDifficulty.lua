--[[
  谁与争锋--难度选择
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local CompeteTop = dataMgr.CompeteTopData
local intLen = 3
local preUpdateTime = -999

function M.Open(params)
    uiMgr.ShowAsync("UICompeteTopDifficulty")
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
end

function M:Show()
    base.Show(self)
    
    self.curSelect = 2
    self.remainTime = 30

    CompeteTop.AutoSelect()

    self:ResetData()
end

function M:ResetData()
    self.curInfoPb = CompeteTop.GetCurInfo()
    if not self.curInfoPb or self.curInfoPb.id == 0 then
        return
    end

    self.monsterList = CompeteTop.GetNextDifficulty()

    for i,v in ipairs(self.monsterList) do
        self:OnUpdateItem(i, self.comsTable[i])
    end

    self.cdata = CompeteTop.GetCurCompeteConfig()
    local str = "当前第<color=#00aa00>%s/%s</color>波,拥有%s"
    self.textCur.text = string.format(str, self.curInfoPb.round, self.cdata.maxRound, self.curInfoPb.star)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:GetLoopItem(idx)
   return self.monsterList[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.transButtonOK = self:FindTransform("ButtonOK", trans)
    coms.textStar = self:FindText("Reward/TextStar", trans)
    coms.transMonster = self:FindTransform("#018MonsterInfo", trans)
    coms.transSelect = self:FindTransform("ImageSelect", trans)
    coms.monsterComs = {}
    coms.monsterComs.trans = coms.transMonster
	
    UguiLuaEvent.ButtonClick(coms.transButtonOK.gameObject, nil, function() self:OnChooseItem(index, coms) end)
end

function M:OnUpdateItem(index, coms)
    local data = self:GetLoopItem(index)
    coms.textStar.text = data.reward

    local mid = CompeteTop.GetMonster(data.battleid)
    UITools.SetMonsterInfo(coms.monsterComs, mid)

    coms.transSelect.gameObject:SetActive(self.curSelect == index)
end

function M:OnChooseItem(index, coms)
    self.curSelect = index
    self:ResetData()

    self:Hide()
    CompeteTop.SendChooseDifficutly(self.curSelect)
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