#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewCfg.sh tablename"
    exit
fi

Content='
local string = string
local table = table
require "ConfigEntity"

local objEntity

function init()
\tobjEntity = class(ConfigEntity)

\tobjEntity = objEntity.new()
\tobjEntity.tbname = "'$1'"

\tobjEntity:Init()
end

function response.Load( reload )
\tobjEntity:Load( reload )
end

function response.UnLoad()
\treturn objEntity:UnLoad()
end

function response.Set(row)
\tobjEntity:Set(row)
end
'
TargetFile="../../common/service/data/config/$1.lua"
rm -rf ${TargetFile}

echo  -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"