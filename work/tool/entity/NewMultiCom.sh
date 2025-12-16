#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewMultiCom.sh tablename"
    exit
fi

Content='
local string = string
local table = table
local math = math

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "CommonMultiEntity"

local objEntity

function init(index)
\tobjEntity = class(CommonMultiEntity)

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

function response.Add( pid, indexId, row )
\treturn objEntity:Add( pid, indexId,row )
end

function response.Delete( pid, indexId )
\treturn objEntity:Delete( pid, indexId )
end

function response.Set( pid, indexId, key, value )
\treturn objEntity:Set( pid, indexId, key, value )
end

function response.Get( pid, indexId, key )
\treturn objEntity:Get( pid, indexId, key )
end

function response.Update( pid, indexId, row )
\treturn objEntity:Update( pid, indexId, row )
end
'

TargetFile="../../common/service/data/common/$1.lua"
rm -rf ${TargetFile}
echo -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"