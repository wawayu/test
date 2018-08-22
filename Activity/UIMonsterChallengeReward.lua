
---过关挑战奖励

local ActivityData = dataMgr.ActivityData

local OfficeTable = excelLoader.OfficeTable
local EquipAttrTable = excelLoader.EquipAttrTable
local AttrTable = excelLoader.AttrTable

local base = require "UI.UILuaBase"
local M = base:Extend()

--M.needPlayShowSE = true
function M.Open()
    uiMgr.ShowAsync("UIMonsterChallengeReward")
end

function M:Awake()
	base.Awake(self)
    self.offsetGameObject = self:FindGameObject("Offset")

    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.ClickClose)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonNext"), self, M.ClickNext)
    self.itemReward = self:FindTransform("Offset/RewardList/Viewport/Grid/Item")
    self.itemAttrTrans = self:FindTransform("Offset/Scroll View/Viewport/Grid/Item")
    self.itemAttrTrans.gameObject:SetActive(false)
    self.textHint = self:FindText("Offset/TextHint")
    self.textFrom = self:FindText("Offset/TextFrom")
    self.textTo = self:FindText("Offset/TextTo")
end

function M:Show()
    base.Show(self)
    ActivityData.GetChallengeInfo(true)
    -- self:Refresh()
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
    local datas, current = ActivityData.GetMonsterConfig()
    local toid = current - 1
    local fromid = toid - 1
    self.chooseMapconfig = OfficeTable[toid]
    local lastmapconfig = OfficeTable[fromid]   
    local rewardId = self.chooseMapconfig.rewardid
    
    self.textFrom.text = UITools.FormatNobilityName(fromid)
    self.textTo.text = UITools.FormatNobilityName(toid)

    if not self.attrGoList then self.attrGoList = {} end
    local fromAttrConfig
    if lastmapconfig then
        fromAttrConfig = EquipAttrTable[lastmapconfig.attrid]
    end
    local toAttrConfig = EquipAttrTable[self.chooseMapconfig.attrid]
    
    if self.rewardGoList == nil then self.rewardGoList = {} end
    UITools.CopyRewardList({rewardId}, self.rewardGoList, self.itemReward)

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
            local textAdd = self:FindText("TextAdd", trans)
            textAdd.text = string.format("+%d", add)         
            if add > 0 then
                self:FindText("TextValue", trans).text = tostring(fromattr)
                UITools.SetActive(textAdd, true)
            else
                go:SetActive(false)
                -- self:FindText("TextValue", trans).text = tostring(fromattr)    
                -- UITools.SetActive(textAdd, false)    
            end

            i = i + 1
        end
    end
end

function M:ClickClose()
    self:Hide()
end

function M:ClickNext()
    self:Hide()
end

return M