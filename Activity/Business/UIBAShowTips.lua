local PlayerData = require "Data.PlayerData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"
local preUpdateTime = -999
local base = require "UI.UILuaBase"
local M = base:Extend()

local tpConfig = {}
local imageLen = 5
local textLen = 3

--[[活动期间获得更多奖励]]

function M:Awake()
    base.Awake(self)
    
    self.transTimeRoot = self:FindTransform("Offset/Time")
    self.textTime=self:FindText("Offset/Time/TimeText")
    self.btnGo=self:FindGameObject("Offset/Button/")
    self.textButton = self:FindText("Offset/Button/Text")

    self.imageBG = self:FindImage("Offset/Background/Bg")

    self.images = {}
    self.transImageRoot = self:FindTransform("Offset/Images", self.rectTransform)
    for i=1,imageLen do
        self.images[i] = self:FindImage(string.format("Image (%s)", i), self.transImageRoot)
    end

    self.texts = {}
    self.transTextRoot = self:FindTransform("Offset/Texts", self.rectTransform)
    for i=1,textLen do
        self.texts[i] = self:FindText(string.format("Text (%s)", i), self.transTextRoot)
    end
	
    UguiLuaEvent.ButtonClick(self.btnGo.gameObject, self, M.OnClickGo)
end

function M:Show()
	base.Show(self)
    self.businessTab = BusinessActivityTable[self.data.id]

    local param2 = self.businessTab.param2
    self.uiconfig = tpConfig[param2.uitype]
    if not self.uiconfig then
        return
    end

    local imagesConf = self.uiconfig.images
    for i=1,imageLen do
        M.SetCustomImage(self.images[i], imagesConf and imagesConf[i])
    end

    local textConf = self.uiconfig.texts
    for i=1,textLen do
        M.SetCustomText(self.texts[i], textConf and textConf[i])
    end

    self.textButton.text = self.businessTab.buttonname or "前往"

    M.SetCustomImage(self.imageBG, self.uiconfig.bg)

    self:ResetData()
end

function M.SetCustomImage(image, conf)
    if not conf then
        UITools.SetImageEmpty(image)
        return
    end

    local atlas = conf.atlas or Const.atlasName.Activity
    local isNative = true
    if conf.native == false then
        isNative = false
    end
    UITools.SetImageIcon(image, atlas, conf.name, isNative)

    local pos = conf.pos
    if pos then
        image.transform.anchoredPosition = pos
    end
end

function M.SetCustomText(text, conf)
    if not conf then
        text.text = ""
        return
    end

    text.text = conf.str

    local pos = conf.pos
    if pos then
        text.transform.anchoredPosition = pos
    end
end

--点击跳转事件
function M:OnClickGo()
    -- body
    if self.businessTab and self.businessTab.goMenuID then
		local MenuEventManager = require "Manager.MenuEventManager"
		MenuEventManager.DoMenu(self.businessTab.goMenuID)
	end
end

function M:ResetData()
    if not self.businessTab or not self.uiconfig then
        return
    end
    
    local isShowTime = self.uiconfig.isshowtime
    self.transTimeRoot.gameObject:SetActive(isShowTime)
    
    if isShowTime then
        local endTime = BusinessData.GetEndTime(self.data.id)
        endTime = endTime - netMgr.mainClient:GetServerTime()
        local tween = TweenText.Begin(self.textTime, endTime, 0, endTime, 0)
        tween.isTime = true
    end
end

-- 类型定义 

-- 合服双倍
tpConfig[1] = {
    isshowtime = false,
    bg={name="bg_jchd14", atlas="HeFu", native = false},
    images = {
        {name="jchdzi63", atlas="HeFu", pos={x=157,y=217}},
        {name="jchdzi64", atlas="HeFu", pos={x=294,y=156}},
        {name="jchdzi65", atlas="HeFu", pos={x=301,y=-146}}
    },
    texts = {
    },
}


return M