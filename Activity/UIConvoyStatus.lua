--[[
 --押镖 主界面常驻
]]

local ActivityData = require "Data.ActivityData"
local npcEventMgr = require "Manager.NpcEventManager"
local base = require "UI.UILuaBase"
local M = base:Extend()
local ConvoyData = dataMgr.ActivityConvoyData

local maxCarLength = 4
local preUpdateTime = -999

M.isInited = false
M.carInfo = nil

function M.Open(params)

	if not ConvoyData.HasCar() then
		return
	end

	local convoyCar = dataMgr.ActivityConvoyData.GetCarInfo()
    	if convoyCar.id == 4 and not dataMgr.TeamData.IsPlayerTeamLeader() then
    		return
        end
	
	
    uiMgr.ShowAsync("UIConvoyStatus")
end

function M:Awake()
	base.Awake(self)

	self.offsetGameObject = self:FindGameObject("Offset")
    self.imageCenter = self:FindImage("Offset/Panel/Background/ImageCenter")
	self.textName = self:FindText("Offset/Panel/TextName")
	self.textRob = self:FindText("Offset/Panel/TextRob")
	self.textProtect = self:FindText("Offset/Panel/TextProtect")
	self.imageCenterLong = self:FindImage("Offset/Panel/Background/ImageCenterLong")
	self.textRemain = self:FindText("Offset/Panel/TextRemain")
	self.isInited = false

	self.exp = self:FindText("Offset/Panel/Award/TextExp")
	self.money = self:FindText("Offset/Panel/Award/TextMoney")
	self.endConvoy = self:FindGameObject("Offset/Panel/ButtonEnd")

	UguiLuaEvent.ButtonClick(self.endConvoy, self, M.EndConvory)

end

function M:Show()
	base.Show(self)

	self:ResetInfo()
end

function M:Hide()
	base.Hide(self)

	-- 结束后停下来
	local p = GetLocalPlayer()
	if p and not tolua.isnull(p.unit) then
		p.unit:StopMove()
	end
end

function M:ResetInfo()
	self.imageCenter.gameObject:SetActive(true)
	self.imageCenterLong.gameObject:SetActive(false)

	local info = ConvoyData.GetConvoyInfo()
	if info and ConvoyData.IsTimeout(info.car) then
		UIMsgbox.ShowTip("由于未在时限内完成押镖任务，\n客户已经取消了该任务", '提示')
	end

	self.carInfo = ConvoyData.GetCarInfo()
	if self.carInfo == nil then
		print("------uiconvotystatus carinfo nil")
		self:Hide()
		return
	end

	self.mapPath = ConvoyData.GetMapPath()
	if self.mapPath == nil then
		print("------uiconvotystatus mapPosConfig nil")
		self:Hide()
		return
	end

	local curMapIndex = ConvoyData.content.curMapIndex
	if curMapIndex == nil then
		local mapPos
		mapPos, curMapIndex = ConvoyData.GetCurMapPos()
		if curMapIndex then
			ConvoyData.SetMapInfo(curMapIndex)
		else
			Debugger.LogWarning("-----uoconvoystatus show curmapindex is nil")
			return
		end
	end

	local etbData = excelLoader.ConvoyTable[self.carInfo.id]
	self.textName.text = UITools.FormatStarName(etbData.name, etbData.quality)
	self.textRob.text = string.format("被抢 %s/%s", self.carInfo.rob, excelLoader.SettingTable.convoy_berob_num)
	--收益
	self.exp.text = self.carInfo.exp
	self.money.text = self.carInfo.coin

	local finalMapPos = self.mapPath[#self.mapPath]
	local sceneTb = excelLoader.SceneTable[finalMapPos.s]
	local npcTb = excelLoader.NpcTable[finalMapPos.npcid]
	local sname = (sceneTb and sceneTb.name) or "??"
	local nname = (npcTb and npcTb.name) or "??"

	self.isInited = true
end

function M:Finish()
	-- 5秒执行一次
	if self.lastFinishTime and (Time.realtimeSinceStartup - self.lastFinishTime < 5) then
		return
	end
	self.lastFinishTime = Time.realtimeSinceStartup
	
	if not ConvoyData.HasCar() then
		return
	end

	if not self.curMoveTo or not self.curMoveTo.npcid then
		Debugger.LogError("self.curMoveTo or npcid is nil")
		Tips("npc 数据错误")
		return
	end

	self:FindNpc(self.curMoveTo.npcid)
end


function M:EndConvory(go)

	UIMsgbox.ShowChoose("是否放弃本次押镖？\n(放弃后不返还本次押镖次数)", function(ok, param)
		if ok == true then              
			--放弃押镖
			dataMgr.ActivityConvoyData.SendConvoyFinish(0)
		end
	end, nil, "提示")

end

function M:FindNpc(unitKey)
	local unitBase = unitMgr.FindByKey(unitKey)
    if unitBase == nil then
        Debugger.LogWarning("FindNpc dont contain target key: "..tostring(unitKey))
        return
    end

    --目标单位还未创建完成
    if unitBase.unit == nil then
		Debugger.LogWarning("unitBase.unit is nil")
        return
    end

	local localPlayer = GetLocalPlayer()
	local ui = GetVisableUI("UIStory")
	if localPlayer and not ui then
		unitBase:Communicate(localPlayer, {tp = Const.CommunicateType.Talk})
		npcEventMgr.DoNpcFun(unitBase)
	end
end

function M:Update()
	if not self.isInited then return end
	if self.carInfo == nil then return end
	if Time.realtimeSinceStartup - preUpdateTime < 1 then return end
	preUpdateTime = Time.realtimeSinceStartup

	local serverTime =  netMgr.mainClient:GetServerTime() 

	local remain = self.carInfo.timeout - serverTime
	if remain > 0 then
		self.textRemain.text = M.FormateTime(remain)
	else
		self.textRemain.text = "00:00"
		-- 超时了刷新下
		LocalEvent(LocalCmds.Convoy, nil)
		return
	end

	local sec = self.carInfo.protect - serverTime
	if sec > 0 then
		self.textProtect.text = M.FormateTime(sec)
	else
		self.textProtect.text = "--:--"
	end

	self:UpdateMove()
end

function M.FormateTime(sec)
	local minute = (sec % 3600) / 60
	return string.format("%02d:%02d", math.floor(minute), math.floor(sec % 60))
end

function M:UpdateMove()
	-- 检测状态，驱动鏢车前进、移动
	local carInfo = ConvoyData.GetCarInfo()
	if carInfo == nil then
		return
	end

	local leader = dataMgr.TeamData.GetLeaderMemberInfo()
	local me = dataMgr.PlayerData.GetRoleInfo()
	if leader and leader.guid ~= me.guid then
		--print("----not leader")
		return
	end

	self.curMoveTo = ConvoyData.GetCurMapPos()
	if self.curMoveTo == nil then
		--print("----self.curMoveTo == nil")
		return
	end

	local mapid = self.curMoveTo.s
	local pos = self.curMoveTo.pos

	local p = GetLocalPlayer()
	if p == nil then
		print("p is nil")
		return
	end
	--[[
	if not p:IsReachable(pos) then
		print("p:IsReachable(pos) error", tostring(pos.x..","..pos.y..","..pos.z))
		return
	end
	]]
	
	if sceneMgr.currentSceneID ~= mapid then
		ConvoyData.Teleport(mapid)
		return
	end

	--- 在目标场景中移动的处理
	-- 靠近目标点了，进入下一个点处理
	if Vector3.Distance(p.position, pos) < 3 then
		local nextMapPos, nextIndex = ConvoyData.GetNextMapPos()
		if nextMapPos then
			ConvoyData.SetMapInfo(nextIndex)
			-- 下一个点本场景的，直接移动
			if nextMapPos.s == sceneMgr.currentSceneID then
				p:FindPathWithAction(nextMapPos.pos, nil, nil, nil , true)
			else
				if self.curMoveTo.transfer then
					ConvoyData.Teleport(self.curMoveTo.transfer)
				else
					Debugger.LogWarning("------convoy has no transfer id, npcid is"..tostring(nextMapPos.npcid))
					ConvoyData.Teleport(nextMapPos.s)
				end
			end
		else
			self:Finish()
		end
	else
		p:FindPathWithAction(pos, nil, nil, nil , true)
	end
end



function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Convoy then
		self:ResetInfo()
	end
end

return M