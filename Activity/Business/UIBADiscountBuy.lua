--[[
	限时抢购
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ShopData = require "Data.ShopData"
local ItemTable = require "Excel.ItemTable"
local ShopTable = require "Excel.ShopTable"
local ShopItemTable = require "Excel.ShopItemTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local commonParamsTable = {showtips = true, showQualityEffect = true}
local preUpdateTime = -1
local TimeSync = require "TimeSync"

function M:Awake()
	base.Awake(self)
    self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem)

	self.textTime = self:FindText("Offset/Top/TextTime")
end

function M:Show()
	base.Show(self)

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end
	
	self:ResetData()
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibadiscountbuy error no bid")
		return
	end

	self.busTab = BusinessActivityTable[bid]

	local shopid = self.script:GetLimitBuyShopID()
	if shopid == nil then
		Debugger.LogWarning("uibadiscountbuy error no shopid/chargeid")
		return
	end

	self.itemList = ShopData.GetShopItems(shopid)

	self.uiLoop.ItemsCount = #self.itemList

	self.endTime = TimeSync.next_day_start(netMgr.mainClient:GetServerTime())
	if self.endTime <= 0 then
		Tips("活动结束")
		self:Hide()
	end
end

function M:GetLoopItem(idx)
    return self.itemList[idx]
end

function M:OnCreateItem(index, coms)
    coms.transFlag = self:FindTransform("Flag", coms.trans)
	coms.textFlag = self:FindText("Flag/Text", coms.trans)
	coms.transOriPrice = self:FindTransform("OriPrice", coms.trans)
	coms.transOK = self:FindTransform("ButtonOK", coms.trans)
	coms.textCost = self:FindText("ButtonOK/TextPrice", coms.trans)
	coms.textCost2 = self:FindText("ButtonOK/TextPrice2", coms.trans)
	coms.imageCost = self:FindImage("ButtonOK/TextPrice/ImageIcon", coms.trans)
	coms.goImageDone = self:FindGameObject("ImageDone", coms.trans)
	coms.transBG = self:FindTransform("Bg", coms.trans)

	coms.textOri = self:FindText("TextPrice", coms.transOriPrice)
	coms.imageOri = self:FindImage("ImageIcon", coms.transOriPrice)

	coms.transItemData = self:FindTransform("ItemData", coms.trans)
	coms.imgIconItemData = self:FindImage("ImgIcon", coms.transItemData)
	coms.transEffectDot = self:FindTransform("EffectDot", coms.transItemData)
	coms.textNameItemData = self:FindText("TextName", coms.transItemData)

	coms.textNum = self:FindText("TextNum", coms.trans)
	
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	UguiLuaEvent.ButtonClick(coms.transOK.gameObject, nil, function()
        self:OnChooseItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
	
	effectMgr:SpawnToMaskUI("2d_jchd_xscg", Vector3.zero, coms.transEffectDot, 0)
end

function M:OnChooseItem(index, coms)
	local shopItemData = self:GetLoopItem(index)
	local itemData = shopItemData.shopiteminfo
	local itemConfig = shopItemData[1]
    ShopData.RequestBuy(itemConfig.id, 1)
end

function M:UpdateItem(index, coms)
	local shopItemData = self:GetLoopItem(index)

	-- 商店物品表
	local itemConfig = shopItemData[1]
	local itemid = itemConfig.item.itemid
	-- 物品表
	local itemTableConfig = ItemTable[itemid]

	coms.go:SetActive(itemConfig.count > 0)
	if itemConfig.count == 0 then
		return
	end

	coms.textCost.text = ""
	coms.textCost2.text = ""
	local isSellDone

	UITools.SetImageIcon(coms.imgIconItemData, Const.atlasName.ItemIcon, itemTableConfig.icon, true)
	coms.textNameItemData.text = UITools.FormatItemColorName(itemid)
	
	local rewardid = dataMgr.ItemData.GetItemToReward(itemid)
	local rewards = dataMgr.ItemData.GetRewardList({rewardid})
    UITools.CopyRewardListWithItemsEx(rewards, coms.rewardContainer, coms.transRewardItem, commonParamsTable)

	coms.imageCost.gameObject:SetActive(true)

	local curNum = ShopData.GetBuyCount(itemConfig.id)
	local limitbuynum = itemConfig.count

	isSellDone = curNum >= limitbuynum
	coms.transOK.gameObject:SetActive(not isSellDone)
	coms.goImageDone:SetActive(isSellDone)

	if isSellDone then
		coms.textNum.text = ""
	else
		coms.textNum.text = string.format("剩余次数:%s/%s", limitbuynum - curNum, limitbuynum)
	end

	local price = itemConfig.price[1]
	local itemCurCost = ItemTable[price.itemid]
	local showprice = itemConfig.showprice 				-- {itemid,num,discount =7}
	local discount = ShopData.GetItemDiscount(itemConfig.id)
	
	if discount > 0 and discount < 1 then
		local itemOriCost = ItemTable[showprice.itemid]
		coms.transOriPrice.gameObject:SetActive(true)
		coms.textOri.text = showprice.num
		UITools.SetImageIcon(coms.imageOri, Const.atlasName.ItemIcon, itemOriCost.icon, false)

		coms.textCost.text = ShopData.FormatPrice(price.itemid, price.num)
		UITools.SetImageIcon(coms.imageCost, Const.atlasName.ItemIcon, itemCurCost.icon, false)

		coms.transFlag.gameObject:SetActive(true)
		coms.textFlag.text = ShopData.FormatDiscount(itemConfig.id)
	else
		coms.transFlag.gameObject:SetActive(false)
		coms.transOriPrice.gameObject:SetActive(false)

		local itemOriCost = ItemTable[price.itemid]
		coms.textCost.text = ShopData.FormatPrice(price.itemid, price.num)
		UITools.SetImageIcon(coms.imageCost, Const.atlasName.ItemIcon, itemCurCost.icon, false)
	end

	coms.transOriPrice.gameObject:SetActive(not isSellDone)
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#00aa00>%s</color>", strTime)
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Shop then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
    end
end

return M