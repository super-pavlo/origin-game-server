--[[
 * @file : AuthImage.lua
 * @type : single snax service
 * @author : linfeng
 * @created : 2019-09-03 08:39:50
 * @Last Modified time: 2019-09-03 08:39:50
 * @department : Arabic Studio
 * @brief : 图片验证服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local httpc = require "http.httpc"
local cjson = require "cjson.safe"
local Random = require "Random"
local rsa = require "rsa.core"
local crypt = require "skynet.crypt"

local reqHost = "http://api-us.open.tuputech.com"
local reqUrl = "/v3/recognition/5d6dc83689b9ffc0c2ea1387"
local secretId = "5d6dc83689b9ffc0c2ea1387"
local taskId = "54bcfc6c329af61034f7c2fc"
local privateKey

function response.Init()
    snax.enablecluster()
    cluster.register(SERVICE_NAME)
    -- 读取private key
    local f = io.open("common/tupu/pkcs8_private_key.pem")
    privateKey = f:read("a")
    f:close()
end

local function makeSignature( _timeStamp, _nonce )
    local signStr = string.format("%s,%d,%d", secretId, _timeStamp, _nonce )
    return crypt.base64encode(rsa.rsa_sha256_sign(signStr, privateKey))
end

---@see 验证图片是否有效
function response.AuthImageInvalid( _url )
    local timeStamp = os.time()
    local nonce = Random.Get(1, 1000000)
    local form = {
        image = _url,
        timestamp = timeStamp,
        nonce = nonce,
        signature = makeSignature( timeStamp, nonce )
    }
    local _, respBody = httpc.post(reqHost, reqUrl, form)
    respBody = cjson.decode(respBody)
    if not respBody then
        return false
    end

    -- verify
    if respBody.json then
        respBody.json = cjson.decode(respBody.json)
        if respBody.json[taskId] then
            if respBody.json[taskId].fileList[1].label ~= 2 then
                return false -- 需要复审,色情图片
            else
                return true
            end
        end
    end
    return false
end