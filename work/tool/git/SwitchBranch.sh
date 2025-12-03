#!/bin/bash
if [ $# -le 0 ]; then
    echo "Usage: DelBranch.sh [switch_branch]"
    exit
fi

rawPath=`pwd`
Branches=("IG-Server" "IG-Protocol" "IG-ErrorCode")
Path=("." "common/protocol" "common/errorcode" "common/mapmesh")

cd ../..

for((i=0;i<${#Path[@]};i++))
do
    cd ${Path[i]}
    git pull
    git checkout $1
    echo -e "\033[32mswitch branch ${Branches[i]} to $1 ok.\033[0m"
    cd -
done

cd $rawPath
