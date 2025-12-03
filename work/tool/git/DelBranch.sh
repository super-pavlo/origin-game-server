#!/bin/bash
if [ $# -le 0 ]; then
    echo "Usage: DelBranch.sh [del_branch]"
    exit
fi

echo $1
if [[ $1 == "master" || $1 == "develop" ]]; then
    echo "Can't delete master|develop branch"
    exit
fi

#删除branch
Branches=("IG-Server" "IG-Protocol" "IG-ErrorCode" "CO-MapMesh" "IG-Config")
LocalBranches=("../../" "../../common/protocol" "../../common/errorcode" "../../common/mapmesh")
for((i=0;i<${#LocalBranches[@]};i++))
do
    cd ${LocalBranches[i]} && git checkout $1 && git checkout develop \
    && git branch -d $1 && git push origin --delete $1
    cd -
    echo -e "\033[31mdel ${Branches[i]} branch $1 ok.\033[0m"
done

rm -rf NewBranchTmp
