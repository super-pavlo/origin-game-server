#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewMultiRole.sh tablename"
    exit
fi

Content='
require "skynet.manager"
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "RoleMultiEntity"

local objEntity

function init(index)
\tobjEntity = class(RoleMultiEntity)

\tobjEntity = objEntity.new()
\tobjEntity.tbname = "'$1'"

\tobjEntity:Init()
\tsnax.enablecluster()
\tcluster.register(SERVICE_NAME .. index)
end

function response.empty()

end

function response.Load( rid )
\treturn objEntity:lock( rid )( objEntity.Load, objEntity, rid )
end

function response.UnLoad( rid )
\tif rid then
\t\treturn objEntity:lock( rid )( objEntity.UnLoad, objEntity, rid )
\telse
\t\treturn objEntity:UnLoad()
\tend
end

function response.Add( rid, indexId, row )
\treturn objEntity:lock( rid )( objEntity.Add, objEntity, rid, indexId, row )
end

function response.Delete( rid, indexId )
\treturn objEntity:lock( rid )( objEntity.Delete, objEntity, rid, indexId )
end

function response.Set( rid, indexId, field, value )
\treturn objEntity:lock( rid )( objEntity.Set, objEntity, rid, indexId, field, value )
end

function response.Update( rid, indexId, row, saveFlag )
\treturn objEntity:lock( rid )( objEntity.Update, objEntity, rid, indexId, row, saveFlag )
end

function response.Get( rid, indexId, field )
\treturn objEntity:lock( rid )( objEntity.Get, objEntity, rid, indexId, field )
end

function response.NewId()
\treturn objEntity:NewId()
end

function response.Save( rid, noSave )
\treturn objEntity:lock( rid )( objEntity.Save, objEntity, rid, noSave )
end
'
TargetFile="../../common/service/data/role/$1.lua"
rm -rf ${TargetFile}

echo -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"
