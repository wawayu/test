
local base = require "UI.UILuaBase"
local M = base:Extend()

local openParams
function M.Open(_openParams)
    openParams = _openParams

    uiMgr.ShowAsync("UIMPTZ")
end

function M:Awake()
    base.Awake(self)

    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/ButtonClose"), self, M.Hide)
    
    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/1"), self, M.OnClickLevel)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/2"), self, M.OnClickLevel)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/3"), self, M.OnClickLevel)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/4"), self, M.OnClickLevel)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Frame/5"), self, M.OnClickLevel)
end

function M:OnClickLevel(go)
    local index = tonumber(go.name)

    local fightID = openParams and openParams.fightlist and openParams.fightlist[index]
    if not fightID then
        Debug.LogWarning("Invalid fightIDs for UIMPTZ")
        return
    end

    local missionID = openParams and openParams.missionID
    if not missionID then
        Debug.LogWarning("Invalid missionID for UIMPTZ")
        return
    end

    if not dataMgr.MissionData.CheckMissionWithTeam(missionID) then
        return
    end

    --同时通知相关队员
    local teamInfo = dataMgr.TeamData.GetCurrentTeamInfo()
    if teamInfo then
        local str = string.format("队长选择了%d星门派挑战", index)
        for i, v in ipairs(teamInfo.members) do
            if v.follow and not dataMgr.PlayerData.IsSelfGuid(v.guid) then
                dataMgr.ChatData.SendChatNotify(str, v)
            end
        end
    end

    fightMgr.SendFight(fightID, openParams and openParams.npcKey)

    self:Hide()
end

return M