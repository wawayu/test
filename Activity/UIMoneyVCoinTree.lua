--[[
 活动 - 铜钱摇钱树
]]
local ActivityData = require "Data.ActivityData"

local base = require "UI.UILuaBase"

local PlayerData = require "Data.PlayerData"

local M = base:Extend()

local RecordTable = excelLoader.RecordTable

local ExpendGroupTable = excelLoader.ExpendGroupTable

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}

function M.Open(params)
	uiMgr.ShowAsync("UIMoneyVcoinTree")
end

function M:Awake()
    base.Awake(self)
    self.offset = self:FindGameObject("Offset")

    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
    self.buttonVcoin = self:FindGameObject("Offset/Panel/VcoinTree/WaveVcoinBt")
    self.getVcoinText = self:FindText("Offset/Panel/VcoinTree/Vcoin/GetVcoin/GetMonText")
   
    self.remainVcionText = self:FindText("Offset/Panel/VcoinTree/Vcoin/WaveNum/NumImage/NumText")
   
    self.costVcionText = self:FindText("Offset/Panel/VcoinTree/Vcoin/WaveNum/CostText")
    
   
    self.notShakeVImg = self:FindGameObject("Offset/Panel/VcoinTree/NotWaveVcoin")
   
    self.shakeVcoinBt = self:FindGameObject("Offset/Panel/VcoinTree/WaveVcoinBt")

    self.vcionCritTrans = self:FindTransform("Offset/Panel/VcoinTree/Vcoin/VcionCrit")

    self.effectVcionTrans = self:FindTransform("Offset/Panel/VcoinTree/VcionEffect")
   
    self.effectVTrans = self:FindTransform("Offset/Panel/VcoinTree/Vcoin/Effect")
   

    effectMgr:SpawnToUI("2d_yqs_2", Vector3.zero, self.effectVcionTrans, 0)
end
function M:Show()
	base.Show(self)
	self:ResetData()
	self:TweenOpen(self.offset)

end

function M:Hide()
    base.Hide(self)
end

function M:ResetData()
    self.treeData = ActivityData.GetMoneyTreeConfig()
    local treeData = self.treeData
   
	--铜钱摇钱树
    self.getVcoinText.text = treeData.shakeRewardVcion.num
    if treeData.shakeCostVcion.num == 0 then
        self.costVcionText.text = "免费"
    else
        self.costVcionText.text = treeData.shakeCostVcion.num  
    end
    self.remainVcionText.text = treeData.remainTimeV.."/"..treeData.maxTimeV 
    if treeData.remainTimeV > 0 then
        self.shakeVcoinBt:SetActive(true)
        self.notShakeVImg:SetActive(false)
    else
    	self.shakeVcoinBt:SetActive(false)
    	self.notShakeVImg:SetActive(true)
    end
    notifyMgr.AddNotify(self.buttonVcoin, ActivityData.IsFreeShakeVcionTree(), Vector3.New(76, 15, 0), notifyMgr.NotifyType.Common)
    
end
--点击事件按钮
function M:OnClick(go)
	local name = go.name
	if name == "ButtonClose" then
		--隐藏摇钱树面板
		self:Hide()
	elseif name == "VipBt" then
		--跳转VIP界面
		OpenUI("UIVip")
    elseif name == "WaveVcoinBt" then
        if self.treeData and self.treeData.shakeCostVcion then
            PlayerData.AutoExpendWithMoney({self.treeData.shakeCostVcion}, "moneytree", function(moneyInstead)
                self:PLayAnimation(false)
                --铜币树发送请求
                ActivityData.SendMoneyTreeVcion()
                self:ResetData()
            end)
        end
	end	
end
--概率暴击事件(是否暴击，是否银树，获得暴击奖励，物品id)
function M:ProbabilityCritEvent(isCrit, isSilver, reward, itemid)
    if isCrit then
        local tip1 = string.format("天降鸿福,暴击获得双倍%s%s<color=#2a9e1a>%s</color>", UITools.FormatItemColorName(itemid), UITools.FormatItemIconText(itemid), reward)
    	if isSilver then
    		UITools.PlayImageEffectBig(self.silverCritTrans, nil, 3, 1, true)
    		Tips(tip1)
            dataMgr.ChatData.SendLocalSystemChat(tip1, true)
    	else
    		UITools.PlayImageEffectBig(self.vcionCritTrans, nil, 3, 1, true)
    		Tips(tip1)
            dataMgr.ChatData.SendLocalSystemChat(tip1, true)
    	end
    else
         local tip2 = string.format("获得%s%s<color=#2a9e1a>%s</color>", UITools.FormatItemColorName(itemid), UITools.FormatItemIconText(itemid), reward)
        if isSilver then
            Tips(tip2)
            dataMgr.ChatData.SendLocalSystemChat(tip2, true, true)
        else
            Tips(tip2)
            dataMgr.ChatData.SendLocalSystemChat(tip2, true, true)
        end
    end
end

function M:OnLocalMsg(cmd,msg)
	if cmd == LocalCmds.UpdateMoneyTree then
		self:ResetData()
        --MoneyTree1Shake摇铜钱   MoneyTree2Shake摇银两
        if msg and (msg.cmd == Cmds.MoneyTree1Shake.index or msg.cmd == Cmds.MoneyTree2Shake.index) then
            if msg.pb and msg.pb.reward and #msg.pb.reward > 0 then
               local itemid = msg.pb.reward[1].itemid
               local num = msg.pb.reward[1].num
               self:ProbabilityCritEvent(msg.pb.crit, msg.cmd == Cmds.MoneyTree2Shake.index, num, itemid)
            end
        end
	end
end
--播放动画
function M:PLayAnimation(isSilver)
    local treeData = self.treeData
    --元宝数量
    local ingotCount = PlayerData.GetItemCount(Const.ITEM_ID_VCOIN)
  
        if ingotCount >= treeData.shakeCostVcion.num then
            if not self.effectAnimatorV then
                self.effectAnimatorV = self.effectVcionTrans.gameObject:GetComponentInChildren(typeof(UnityEngine.Animator), true)
            end
            if self.effectAnimatorV then
                self.effectAnimatorV:Play("SP1")
            end
            effectMgr:SpawnToUI("2d_yqs_2_2", Vector3.zero, self.effectVTrans, 0)
        end
    
end
return M