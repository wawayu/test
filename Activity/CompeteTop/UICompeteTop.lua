--[[
  谁与争锋--主界面
]]
local base = require "UI.UILuaBase"
local M = base:Extend()
local UguiLuaEvent = require "UguiLuaEvent"

local CompeteTop = dataMgr.CompeteTopData
local extraParams = {TeamTableId = 1, autoRecruit = false}

function M.Open(params)
    if not activityMgr.CheckActivityJoinable(Const.ACTIVITY_ID_SYZF) then
        return
    end

    uiMgr.ShowAsync("UICompeteTop")
end

function M:Awake()
    base.Awake(self)

    UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, Button)

    self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.OnUpdateItem, M.OnChooseItem)
    
    self.textCount = self:FindText("Offset/PanelTop/TextCount")
	self.textContent = self:FindText("Offset/PanelDesc/TextContent")
    
    self.transCha = self:FindTransform("Offset/PanelBot/ButtonChallenge/ButtonGreen")
	
    self.textNum = self:FindText("Offset/PanelBot/TextNum")
	self.imageBG = self:FindImage("Offset/BG/ImageBg/Image")
end

function M:Show()
    base.Show(self)
    
    -- 刷新一遍
    CompeteTop.SendSyncSyzfCurrentInfo(true)
    CompeteTop.SyncSyzfRecordInfo(true)

    self.curSelect = 1

    self.roleInfo = dataMgr.PlayerData.GetRoleInfo()
    self.syzfTable = excelLoader.SyzfTable
    self.showList = {}
    for i,v in ipairs(self.syzfTable) do
        if v.lv <= self.roleInfo.lv then
            table.insert(self.showList, v)
        end
    end
    if #self.showList == 0 then
        Debugger.LogError("SYZF has no fit lv option")
        self:Hide()
        return
    end

    self:ResetData()
end

function M:ResetData()
    self.curCfg = self.showList[self.curSelect]

    UITools.SetImageIcon(self.imageBG, Const.atlasName.Background, self.curCfg.bg)
    self.textContent.text = self.curCfg.desc

    self.curRemainNum = CompeteTop.GetRemainNum()
    self.textNum.text = self.curRemainNum

    local topRound = CompeteTop.GetCopyTopRound(self.curCfg.id)
    self.textCount.text = topRound
    
    self.curTeamId = self.curCfg.teamid

    self.uiLoop.ItemsCount = #self.showList
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.ActivityCompeteTop then
        self:ResetData()

        if msg and msg.cmd == Cmds.StartSyzfBattle.index then
            CompeteTop.GotoScene()
        end
    elseif cmd == LocalCmds.Activity then
        self:ResetData()
    end
end

function M:GetLoopItem(idx)
   return self.showList[idx]
end

function M:OnCreateItem(index, coms)
    local trans = coms.trans
    coms.textName = self:FindText("TextName", trans)
	coms.textLv = self:FindText("TextLv", trans)
	coms.transSelect = self:FindTransform("ItemSelect", trans)
end

function M:OnUpdateItem(index, coms)
    local trans = coms.trans
    local data = self:GetLoopItem(index)

    coms.textName.text = data.name
    coms.textLv.text = data.lv.."级"

    coms.transSelect.gameObject:SetActive(index == self.curSelect)
end

function M:OnChooseItem(index, coms)
    self.curSelect = index
    self:ResetData()
end

function M:OnClick(go)
    local goName = go.name

    if goName == "ButtonClose" then
        self:Hide()
    elseif goName == "ButtonTips" then
        Hint({content = Lan("rule_compete_top") , rectTransform = go.transform, alignment = 0})
    elseif goName == "ButtonTeam" then
        OpenUI("UITeam", {panelIndex = 2, TeamTableId = self.curTeamId})
    elseif goName == "ButtonGreen" then
        if CompeteTop.CheckHasChallenge(true) then
            return
        end

        local res, status = CompeteTop.CanChallenge(self.curCfg.id, true)
        if not res then
            if status == 100 then
                local str = "该难度建议三人组队挑战，\n是否立即组队?"
                extraParams.TeamTableId = self.curTeamId
                dataMgr.TeamData.ShowOpenTeamDialog(str, extraParams)
            end
        else
            CompeteTop.SendChallenge(self.curCfg.id)
        end
    elseif goName == "ButtonExchange" then
        OpenUI("UIShop",{shopid = {1000, 2000, 3000}, panelIndex = 3, chooseshopid = 3006, closeTween = true})
    end
end

return M