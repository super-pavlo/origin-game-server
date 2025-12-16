--[[
 * @file : WebEnum.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2019-03-29 11:14:49
 * @Last Modified time: 2019-03-29 11:14:49
 * @department : Arabic Studio
 * @brief : Web相关错误定义
 * Copyright(C) 2019 IGG, All rights reserved
]]

local Enum = require "Enum"

---@see 请求结果错误码定义
---@class WebErrorEnumClass
local WebError = {
    ---@see 成功
    SUCCESS                                 =       200,
    ---@see 目标服务器节点不存在
    SERVER_NODE_NOT_FOUND                   =       401,
    ---@see 参数不存在
    ARG_NOT_FOUND                           =       404,
    ---@see 失败
    FAILED                                  =       500,
    ---@see 参数类型错误
    ARG_TYPE_ERROR                          =       900,
    ---@see 往非GameServer充道具
    ADDITEM_NOT_GAME                        =       1000,
    ---@see 封禁不存在的iggid
    ROLE_BAN_NOT_FOUND                      =       1001,
    ---@see 禁言不存在的iggid
    ROLE_SILENCE_NOT_FOUND                  =       1002,
    ---@see 公告频道类型无效
    CHAT_INVALIDE_CHANNEL                   =       1003,
    ---@see 往非GameServer充值
    RECHARGE_NOT_GAME                       =       2000,
    ---@see 订单已存在
    RECHARGE_SN_EXIST                       =       2001,
    ---@see 充值角色不存在
    RECHARGE_RID_ERROR                      =       2002,
    ---@see 今日已经充值过每日特惠
    TODAY_BUY                               =       2003,
    ---@see 所有英雄觉醒无法购买每日特惠
    HERO_ALL_WAKE                           =       2004,
    ---@see 已购买首充
    FIRST_HAVE_BUY                          =       2005,
    ---@see 购买成长基金所需VIP等级不足
    GROWN_VIP_NOT_ENOUGH                    =       2006,
    ---@see 已购买成长基金
    GROWN_HAVE_BUY                          =       2007,
    ---@see 购买vip尊享礼包vip等级不足
    VIP_NOT_ENOUGH                          =       2008,
    ---@see 已购买该等级vip尊享礼包
    VIP_HAVE_BUY                            =       2009,
    ---@see 购买礼包时间错误
    TIME_OUT                                =       2010,
    ---@see 礼包绑定的活动未开启
    ACTIVITY_NOT_OPEN                       =       2011,
    ---@see 前置礼包未购买
    PRE_NOT_BUY                             =       2012,
    ---@see 重复购买礼包
    BUY_ONE_MORE                            =       2013,
    ---@see 礼包不存在
    PACKAGE_NO_EXIST                        =       2014,
    ---@see 踢人失败
    KICK_ERROR                              =       2015,
    ---@see 往非GameServer扣道具
    DELITEM_NOT_GAME                        =       2016,
}
Enum.WebError = WebError