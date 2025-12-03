#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewSingleCom.sh tablename"
    exit
fi

Content='
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "CommonSingleEntity"

local objEntity

function init( index )
\tobjEntity = class(CommonSingleEntity)
\tobjEntity = objEntity.new()
\tobjEntity.tbname = "'$1'"

\tobjEntity:Init()
\tsnax.enablecluster()
\tcluster.register(SERVICE_NAME)
end

function response.empty()

end

function response.Load()
\treturn objEntity:Load()
end

function response.UnLoad()
\treturn objEntity:UnLoad()
end

function response.Add( pid, row )
\treturn objEntity:Add( pid, row )
end

function accept.Add( pid, row )
\tobjEntity:Add( pid, row )
end

function response.Delete( pid )
\treturn objEntity:Delete( pid )
end

function response.DeleteAll()
\treturn objEntity:DeleteAll()
end

function response.Set( pid, field, value )
\treturn objEntity:Set(pid, field, value)
end

function accept.Set( pid, field, value )
\tobjEntity:Set(pid, field, value)
end

function response.Get( pid, field )
\treturn objEntity:Get( pid, field )
end

function response.Update( pid, row, lockFlag )
\treturn objEntity:Update( pid, row, lockFlag )
end

function response.NewId()
\treturn objEntity:NewId()
end

function response.LockSet( pid, field, value )
\treturn objEntity:Set( pid, field, value, true )
end
'

TargetFile="../../common/service/data/common/$1.lua"
rm -rf ${TargetFile}
echo -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"