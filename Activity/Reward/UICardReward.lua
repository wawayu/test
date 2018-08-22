local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local RechargeData = require "Data.RechargeData"

local ExpendTable = require "Excel.ExpendTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[奖励——周卡、月卡]]

function M:Awake()
    --右边UILoop
	self.uiRewardLoop = self:FindGameObject("Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
	self:BindLoopEvent(self.uiRewardLoop, M.UpdateItem, nil, function(_self, index, go)
		--点击自己
		UguiLuaEvent.ButtonClick(go, nil, function(_go)
        	self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(go) + 1, go, 1)                
        end)
		--购买
		UguiLuaEvent.ButtonClick(self:FindGameObject("BtnBuy", go.transform), nil, function(_go)
			self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(go) + 1, go, 2)                
		end)
		--领取
		UguiLuaEvent.ButtonClick(self:FindGameObject("BtnGet", go.transform), nil, function(_go)
			self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(go) + 1, go, 3)                
		end)
	end)
end

function M:Show()
	base.Show(self)

	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Recharge then
		self:RefreshPanel()
    end
end

function M:RefreshPanel()
	--刷新UILoop
	self.uiRewardLoop.ItemsCount = #RechargeData.GetCardTable()
end

function M:OnChoose(index, go, tp)
	local cardRechargeTab = RechargeData.GetCardTable()[index]
	if cardRechargeTab ~= nil then
		if tp == 2 then
			--充值
			require("SDK.PayOrderRequest").RequestOrder(cardRechargeTab.id)
		elseif tp == 3 then
			--领取
			RechargeData.RequestGetRechargeReward(cardRechargeTab.id)
		end	
	end
end

--月卡、周卡
function M:UpdateItem(index, go)
	local cardRechargeTab = RechargeData.GetCardTable()[index]
	if cardRechargeTab ~= nil then
		local trans = go.transform
		--组件
		-- local txtName = self:FindText("TxtName", trans)--名称
		-- local imgIcon = self:FindImage("ImgIcon", trans)--图片
		-- local txtDesc = self:FindText("ImgDescBg/TxtDesc", trans)

		local txtLeft = self:FindText("TxtLeft", trans)--剩余
		local txtBuyMoney = self:FindText("BtnBuy/Text", trans)
		
		local uiBtnBuy = self:FindGameObject("BtnBuy", trans)
		local uiBtnDone = self:FindGameObject("BtnDone", trans)
		local uiBtnGet = self:FindGameObject("BtnGet", trans)
		

		--卡名
		-- txtName.text = cardRechargeTab.name
		-- txtDesc.text = cardRechargeTab.desc
		-- --图片
		-- uiMgr.SetSpriteAsync(imgIcon, Const.atlasName.Common, cardRechargeTab.icon)
		-- print(cardRechargeTab.id)
		local cardInfo = RechargeData.GetRechargeInfoById(cardRechargeTab.id)
		local getStatus = RechargeData.IsTodayRechargeRewardGetted(cardRechargeTab.id)
		-- print(getStatus)
		if not cardInfo then
			-- print("aaaaaaaaaaaa")
			--未购买
			txtBuyMoney.text = string.format("%d元购买", cardRechargeTab.rmb)
			uiBtnBuy:SetActive(true)
			uiBtnDone:SetActive(false)
			uiBtnGet:SetActive(false)
		elseif getStatus then
			--已领取
			-- print("vvvvvvvvvvv")
			uiBtnBuy:SetActive(false)
			uiBtnDone:SetActive(true)
			uiBtnGet:SetActive(false)
		else
			--未领取
			-- print("cccccccccccccc")
			uiBtnBuy:SetActive(false)
			uiBtnDone:SetActive(false)
			uiBtnGet:SetActive(true)
		end

		--剩余
		local left = RechargeData.GetRechargeRewardLeftDay(cardRechargeTab.id) - 1
		-- print(left)
		-- print(getStatus)
		if left > 0 then
			txtLeft.text = string.format("剩余<color=#00FF00>%d</color>天", left) 
			txtLeft.gameObject:SetActive(true)
		elseif left == 0 then
			--最后一天
			txtLeft.gameObject:SetActive(false)
			if getStatus then
				--已经领了，那么重新显示购买按钮
				uiBtnBuy:SetActive(true)
				uiBtnDone:SetActive(false)
				uiBtnGet:SetActive(false)
			else
				--未领取
				uiBtnBuy:SetActive(false)
				uiBtnDone:SetActive(false)
				uiBtnGet:SetActive(true)
			end
		elseif left < 0 then
			txtLeft.gameObject:SetActive(false)
			--超过了，重新显示购买按钮
			uiBtnBuy:SetActive(true)
			uiBtnDone:SetActive(false)
			uiBtnGet:SetActive(false)
		end
	end
end

return M