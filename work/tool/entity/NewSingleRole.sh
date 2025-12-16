#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage:bash NewSingleRole.sh tablename"
    exit
fi

Content='

require "skynet.manager"
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "RoleSingleEntity"

local objEntity

function init(index)
\tobjEntity = class(RoleSingleEntity)

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

function response.Add( rid, row )
\treturn objEntity:lock( rid )( objEntity.Add, objEntity, rid, row )
end

function response.Delete( rid )
\treturn objEntity:lock( rid )( objEntity.Delete, objEntity, rid )
end

function response.Set( rid, field, value )
\treturn objEntity:lock( rid )( objEntity.Set, objEntity, rid, field, value )
end

function response.Update( rid, row, lockFlag, saveFlag )
\treturn objEntity:lock( rid )( objEntity.Update, objEntity, rid, row, lockFlag, saveFlag )
end

function response.Get( rid, field )
\treturn objEntity:lock( rid )( objEntity.Get, objEntity, rid, field )
end

function response.NewId()
\t return objEntity:NewId()
end

function response.Save( rid, noSave )
\treturn objEntity:lock( rid )( objEntity.Save, objEntity, rid, noSave )
end

function response.LockSet( rid, field, value )
\treturn objEntity:lock( rid )( objEntity.Set, objEntity, rid, field, value, true )
end
'
TargetFile="../../common/service/data/role/$1.lua"
rm -rf ${TargetFile}

echo -e "${Content}" > ${TargetFile}
sed 's/^[ ]*//g' ${TargetFile}
echo "New ${TargetFile} ok!"
