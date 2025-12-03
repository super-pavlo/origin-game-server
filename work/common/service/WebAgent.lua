--[[
 * @file : WebAgent.lua
 * @type : snax multi service
 * @author : linfeng
 * @created : 2019-01-14 21:35:42
 * @Last Modified time: 2019-01-14 21:35:42
 * @department : Arabic Studio
 * @brief : Web命令处理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local webFiles = {}

local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local table = table
local string = string
local cjson = require "cjson.safe"
local urllib = require "http.url"
local WebCmd = require "WebCmd"

local function response(id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        LOG_ERROR(string.format("response err:fd = %d, %s", id, err))
    end
end

local function readWebFile( filename )
	if webFiles[filename] then return webFiles[filename] end
	if Common.getSelfNodeName():find("monitor") then
		local f = io.open("server/monitor_server/html" .. filename, "r")
		if not f then return end
		webFiles[filename] = f:read("a")
		f:close()
		return webFiles[filename]
	end
end

function init()
	require "WebLogic"
end

function accept.WebCmd( id )
    socket.start(id)
    -- limit request body size to 65536 (you can pass nil to unlimit)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 65536)
    if code then
        if code ~= 200 then
            response(id, code)
        else
print(url)
            if url == "/" or url:find("/css") or url:find("/js") or url:find("/fonts") then
                -- default index.html
                if url == "/" then url = "/index.html" end
                if url:find("fonts") then
                    url = string.split(url,"?")
                    url = url[1]
                end
                response(id, code, readWebFile(url))
            else
				--content response
				local path, query = urllib.parse(url)
				local cmd = path:sub(2)
print(path, cmd)
				if not cmd or cmd == "" then
					response(id, code, "jsonpCallback(" .. cjson.encode({ error = "invalid request" }) .. ")" )
				end
				if query then
                    local q = urllib.parse_query(query)
                    local serverNode = q.serverNode
                    local f = WebCmd[cmd]
                    if f then
                        q["_"] = nil
                        q["callback"] = nil
                        LOG_INFO("http recv request(%s) q(%s) body(%s)", cmd, tostring(q), tostring(body))
                        if serverNode and serverNode ~= Common.getSelfNodeName() then
                            -- 发往其他服务器
                            q.serverNode = nil
                            local ret, resultData = SM.MonitorPublish.req.runWebCmd( serverNode, cmd, q, body )
                            if ret then
                                response(id, code, resultData)
                            else
                                response(id, code, cjson.encode( { code = Enum.WebError.ARG_TYPE_ERROR } ) )
                            end
                        else
                            local ret, resultData = pcall(f, q, body)
                            if ret then
                                response(id, code, resultData)
                            else
                                LOG_ERROR("WebCmd(%s) error(%s)", cmd, tostring(resultData))
                                response(id, code, cjson.encode( { code = Enum.WebError.ARG_TYPE_ERROR } ) )
                            end
                        end
                    else
                        response(id, code, "jsonpCallback(" .. cjson.encode({ error = "invalid request" }) .. ")" )
                    end
				end
            end
        end
    else
        if url == sockethelper.socket_error then
            LOG_ERROR("Web socket closed")
        else
            LOG_ERROR(url)
        end
    end
    socket.close(id)
end
