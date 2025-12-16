#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewMultiUser.sh tablename"
    exit
fi

Content='
local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "UserMultiEntity"

local objEntity

function init(index)
\tobjEntity = class(UserMultiEntity)

\tobjEntity = objEntity.new()
\tobjEntity.tbname = "'$1'"

\tobjEntity:Init()
\tsnax.enablecluster()
\tcluster.register(SERVICE_NAME .. index)
end

function response.empty()

end

function response.Load( uid )
\tif uid then
\t\treturn objEntity:Load(uid)
\tend
end

function response.UnLoad( uid )
\tobjEntity:UnLoad( uid )
end

function response.Add( uid, indexId, row )
\treturn objEntity:Add( uid, indexId, row )
end

function response.Delete( uid, indexId )
\treturn objEntity:Delete( uid, indexId )
end

function response.Set( uid, indexId, field, value )
\treturn objEntity:Set(uid, indexId, field, value)
end

function response.Update( uid, indexId, row, saveFlag )
\treturn objEntity:Update( uid, indexId, row, saveFlag )
end

function response.Get( uid, indexId, field )
\treturn objEntity:Get(uid, indexId, field )
end

function response.NewId()
\t return objEntity:NewId()
end

function response.Save( uid, noSave )
\treturn objEntity:Save( uid, noSave )
end
'
TargetFile="../../common/service/data/user/$1.lua"
rm -rf ${TargetFile}

echo -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"
