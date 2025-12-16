#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewSingleUser.sh tablename"
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
require "UserSingleEntity"

local objEntity

function init(index)
\tobjEntity = class(UserSingleEntity)

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
\t\treturn objEntity:Load( uid )
\tend
end

function response.UnLoad( uid )
\tobjEntity:UnLoad( uid )
end

function response.Add( uid, row )
\treturn objEntity:Add( uid, row )
end

function response.Delete( uid )
\treturn objEntity:Delete( uid )
end

function response.Set( uid, field, value )
\treturn objEntity:Set(uid, field, value)
end

function response.Update( uid, row, saveFlag )
\treturn objEntity:Set(uid, row, saveFlag )
end

function response.Get( uid, field )
\treturn objEntity:Get( uid, field )
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
