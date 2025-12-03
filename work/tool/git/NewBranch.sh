#!/bin/bash
if [ $# -le 1 ]; then
    echo "Usage: NewBranch.sh [base_branch] [new_branch]"
    exit
fi

#httpUrl="http://10.15.122.62/root"
httpUrl="https://gitlab.skyunion.net/lf723"

rm -rf NewBranchTmp && mkdir NewBranchTmp && cd NewBranchTmp

Branches=("IG-Server" "IG-Protocol" "IG-ErrorCode")

for branch in ${Branches[@]}; do
    git clone $httpUrl/$branch.git && cd $branch && git checkout $1 && git checkout -b $2 \
    && git push --set-upstream origin $2 \
    && git add --all && git commit -a -m "new branch $2" && git push && cd ..
    echo -e "\033[32mnew branch $branch $2 base on $1 ok.\033[0m"
done

rm -rf NewBranchTmp
