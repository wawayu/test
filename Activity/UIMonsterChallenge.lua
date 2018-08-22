
---爵位挑战/过关斩将

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"
local ItemData = require "Data.ItemData"
local TopData = dataMgr.TopData

local OfficeTable = excelLoader.OfficeTable
local ItemTable = excelLoader.ItemTable
local RewardTable = excelLoader.RewardTable
local PosTable = excelLoader.PosTable
local EquipAttrTable = excelLoader.EquipAttrTable
local AttrTable = excelLoader.AttrTable

local base = require "UI.UILuaBase"
local M = base:Extend()

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

function M.Open()
    uiMgr.ShowAsync("UIMonsterChallenge")
end

function M:Awake()
	base.Awake(self)
    self.offsetGameObject = self:FindGameObject("Offset")

	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
    self.uiLoop = self:FindLoop("Offset/Left/Scroll View/Viewport/Content")
    self:BindLoopEvent(self.uiLoop, M.UpdateItem, nil, function(_, index, go)
        go.name = tostring(index)
        UguiLuaEvent.ButtonClick(go, self, function(_self, _go)
            self:OnChooseItem(index, go)
        end)
        self:LoadRenderTexture("CameraModel", "RawImage", "RT256_"..(index), go.transform)
    end)
    self.itemSelect = self:FindTransform("Offset/Left/Scroll View/Viewport/Content/ItemSelect")
    self.itemReward = self:FindTransform("Offset/Right/Info/Item3/RewardList/Viewport/Grid/Item")
    self.itemAttrTrans = self:FindTransform("Offset/Right/Info/Grid/Item")
    self.itemAttrTrans.gameObject:SetActive(false)
    self.textInfoTitle = self:FindText("Offset/Right/Info/Title/Text")
    self.textMyRank = self:FindText("Offset/Right/Info/TextInfo")

    self.uiLoopRank = self:FindLoop("Offset/Right/Rank/ScrollViewRank/Viewport/Content")
    self:BindLoopEvent(self.uiLoopRank, M.UpdateRankItem)

    UguiLuaEvent.ScrollRectValueChange(self:FindGameObject("Offset/Right/Rank/ScrollViewRank"), nil, function(go, pos)
        if pos.y < 0 then
            dataMgr.TopData.LoadNextPageDatas(Const.TOP_INDEX_CHALLENGE)
        end
    end)

    self.panels = {
        self:FindTransform("Offset/Right/Info"),
        self:FindTransform("Offset/Right/Rank")
    }
    self.toggles = {}
    for i = 1, 2 do
        local toggle = self:FindToggle(string.format("Offset/Right/Toggle (%d)", i))
        UguiLuaEvent.ToggleClick(toggle.gameObject, self, function(_, _go, ison)
            if ison then
                self:ShowPanel(i)
            end
        end)
        self.toggles[i] = toggle
    end
    self.contentRect = {
        self:FindTransform("Offset/Left/Scroll View/Viewport/Content"),
        self:FindTransform("Offset/Right/Rank/ScrollViewRank/Viewport/Content"),
    }
    self.buttonChallenge = self:FindTransform("Offset/Right/Info/ButtonGo")
    self.textRankHint = self:FindText("Offset/Right/Rank/TextHint")
end

function M:Show()
    base.Show(self)
    ActivityData.GetChallengeInfo(true)    
    self:Refresh()
    UITools.SetToggleOnIndex(self.toggles, 1)
    for i = 1, #self.contentRect do
        self.contentRect[i].anchoredPosition3D = Vector3.zero
    end
    self:TweenOpen(self.offsetGameObject)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Challenge then
        self:Refresh()
    elseif cmd == LocalCmds.Top then
        self:Refresh()
    end
end

function M:Refresh()
    self.challengeInfo = ActivityData.GetChallengeInfo()
    self.playerScore = PlayerData.GetAllScore()
    local datas, current = ActivityData.GetMonsterConfig()
    self.itemList = datas
    self.currentLevel = current
    self.chooseMapconfig = OfficeTable[current]
    self.uiLoop.ItemsCount = #self.itemList
    self.rankList = ActivityData.GetAllChallengeRank()
    self.uiLoopRank.ItemsCount = #self.rankList
    --<color=#82AAD1>全服排名:</color><color=#D5E7F9>%s(当前第%s关)</color>
    self.myRankInfo = TopData.GetSelfTopInfo(Const.TOP_INDEX_CHALLENGE)
    local strrank = "未上榜"
    if self.myRankInfo and self.myRankInfo.rank > 0 then
        strrank = tostring(self.myRankInfo.rank)
    end
    self.textMyRank.text = string.format(Lan("challenge_myrank"), strrank, self.currentLevel)
    self.textRankHint.gameObject:SetActive(#self.rankList == 0)
    self:ShowChooseInfo()
end

function M:OnClick(go)
    local goname = go.name
    if goname == "ButtonClose" then
        self:Hide()
    elseif goname == "ButtonGo" then
        ActivityData.RequestStartChallengeInfo(self.chooseMapconfig.id)
    elseif goname == "ButtonFormation" then
        OpenUI("UIFormation")
    end
end

function M:GetItemInfo(index)
    return self.itemList[index]
end

---刷新副本信息
function M:UpdateItem(realIndex, go)
    local trans = go.transform
    local mapconfig = self:GetItemInfo(realIndex)

    local stage = mapconfig.id
    local stagerecode = ActivityData.GetChallengeStateInfo(stage)
    self:FindText("TextAt", trans).text = tostring(stage)
    self:FindText("Name/Text", trans).text = mapconfig.npcname
    --<color=#82AAD1>首杀:</color><color=#D5E7F9>%s</color>\n<color=#82AAD1>最佳:</color><color=#D5E7F9>%s</color>
    self:FindText("Info/TextRank", trans).text = string.format(Lan("challenge_first"), stagerecode.first, stagerecode.best)
    local color = "00ff00"
    if self.playerScore < mapconfig.fighting then
        color = "ff0000"
    end
    --推荐战力:<color=#%s>\n%s</color>
    self:FindText("Info/TextFighting", trans).text = string.format("<color=#%s>%s</color>", color, mapconfig.fighting)
    self:FindText("Info/TextDesc", trans).text = mapconfig.limitdesc
    self:FindGameObject("ImagePass", trans):SetActive(ActivityData.IsChallengeClearance(mapconfig.id))
    self:FindGameObject("Info", trans):SetActive(false)
    local modelParent = self:FindTransform("CameraModel/Model", trans)
    UITools.LoadModel(mapconfig.monsterid, "challenge"..go.name, modelParent, function(tmpunit)
        self.unitBase = tmpunit
    end)

    if not self.disableModelAlpha then
        TweenAlpha.Begin(self:FindGameObject("RawImage", trans), 0, 1, 0.5, 0)
    end

    self:FindGameObject("Lock", trans):SetActive(stage > self.currentLevel)

    if self.chooseMapconfig.id == stage then
        self:FindGameObject("Info", trans):SetActive(true)
        self:SetSelectActive(self:FindTransform("ImageBg", go.transform), true)
    else
        self:FindGameObject("Info", trans):SetActive(false)
    end
end

---选中副本
function M:OnChooseItem(realIndex, go)
    local mapconfig = self:GetItemInfo(realIndex)
    self.chooseMapconfig = mapconfig
    self:ShowChooseInfo()
    self.disableModelAlpha = true
    self.uiLoop:UpdateAll()
    self.disableModelAlpha = false
end

function M:SetSelectActive(parent, active)
    local go = self.itemSelect.gameObject
    go:SetActive(active)
    if active == true then    
        UITools.AddChild(parent.gameObject, self.itemSelect.gameObject, false)
        self.itemSelect.anchoredPosition3D = Vector3.zero
    end
end

function M:ShowChooseInfo()
    if self.rewardGoList == nil then self.rewardGoList = {} end
    UITools.CopyRewardList({self.chooseMapconfig.rewardid}, self.rewardGoList, self.itemReward)
    self.textInfoTitle.text = UITools.FormatNobilityName(self.chooseMapconfig.id)

    if not self.attrGoList then self.attrGoList = {} end

    local fromAttrConfig
    local lastmapconfig = OfficeTable[self.chooseMapconfig.id - 1]
    if lastmapconfig then
        fromAttrConfig = EquipAttrTable[lastmapconfig.attrid]
    end
    local toAttrConfig = EquipAttrTable[self.chooseMapconfig.attrid]
    local i = 1
    for k, v in ipairs(self.attrGoList) do v:SetActive(false) end
    for attrname, vallist in pairs(toAttrConfig) do
        local config = AttrTable[attrname]
        if config then
            local toatt = math.floor(vallist[1] or 0)
            local fromattr = 0
            if fromAttrConfig then
                fromattr = fromAttrConfig[attrname][1] or 0
            end
            local add = math.floor(toatt - fromattr)

            if #self.attrGoList < i then
                local tmpgo = UITools.AddChild(self.itemAttrTrans.parent.gameObject, self.itemAttrTrans.gameObject, true)
                self.attrGoList[i] = tmpgo
            end
            local go = self.attrGoList[i]
            local trans = go.transform
            go:SetActive(true)
            self:FindText("TextName", trans).text = string.format("%s", config.name)
            if add > 0 then
                local fromattrstr = ""
                if fromattr > 0 then
                    fromattrstr = tostring(fromattr)
                end
                self:FindText("TextValue", trans).text = string.format("<color=#782601>%s</color><color=#18A338>+%s</color>", fromattrstr, add)
                self:FindGameObject("TextValue/ImageAdd", trans):SetActive(true)
            else
                go:SetActive(false)
                -- self:FindText("TextValue", trans).text = string.format("<color=#782601>%s</color>", fromattr)            
                -- self:FindGameObject("TextValue/ImageAdd", trans):SetActive(false)
            end

            UguiLuaEvent.ButtonClick(go, nil, function(_go)
                Hint({rectTransform = _go.transform, content = config.desc})
            end)
            i = i + 1
        end
    end

    UITools.SetAllChildrenGrey(self.buttonChallenge, ActivityData.IsChallengeClearance(self.chooseMapconfig.id))
end

function M:UpdateRankItem(index, go)
    local roleinfo = self.rankList[index]
    if roleinfo then
        local trans = go.transform
        self:FindText("TextAt", trans).text = tostring(roleinfo.rank)
        self:FindText("TextName", trans).text = roleinfo.name
        self:FindText("TextFighting", trans).text = roleinfo.ce or 0
        self:FindText("TextCount", trans).text = tostring(roleinfo.score)
        self:FindGameObject("ImageBg", trans):SetActive(index%2==1)
    end
end

function M:ShowPanel(index)
    self.currentPanelIndex = index    
    for i = 1, #self.panels do
        self.panels[i].gameObject:SetActive(i==index)
    end
end

return M