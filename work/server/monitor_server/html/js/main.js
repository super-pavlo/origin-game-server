var monitorServerIp = "192.168.2.73"
var monitorServerPort = 58111
var monitorServerWebScoektPort = 10509
var netdataPort = 19999

var ServerLists = new Array()
var selServer
var selPanle
var ServerDetailInfo

function showMessage( msg ) {
    // simulate loading (for demo purposes only)
    setTimeout(function () {
        // create the notification
        var notification = new NotificationFx({
            message: '<p><a href="#">' + msg + '</a>.</p>',
            layout: 'attached',
            effect: 'bouncyflip',
            type: 'notice', // notice, warning or error
            ttl: 3000,
            onClose: function () {
                
            }
        })

        // show the notification
        notification.show()
    })
}

// jsonp的回调函数
function jsonpCallback(params) {
    return params
}

// 发起get请求
function HttpGet(ip, port, method, successCb, errorCb) {
    var url = "http://" + ip + ":" + port + "/" + method
    $.ajax({
        type: "get",
        async: false,
        url: url,
        dataType: "jsonp",
        jsonpCallback: "jsonpCallback",//自定义的jsonp回调函数名称，默认为jQuery自动生成的随机函数名，也可以写"?"，jQuery会自动为你处理数据
        success: successCb,
        error: errorCb
    })
}

// 加载集群的服务器列表,并填充到serverLists中(select)
function loadServerList() {
    var mainTable = document.getElementById("mainTable")
    mainTable.hidden = true
    currentSelect("a_select")
    selectServer()
    HttpGet(monitorServerIp, monitorServerPort, "getServerList", function (data) {
            ServerLists = data
            var serverListSelect = document.getElementById("serverListSelect")
            var array = new Array()
            for (const serverName in ServerLists) {
                array.push(serverName)
            }

            array.sort()
            for (const index in array) {
                // 添加进select
                serverListSelect.options.add(new Option(array[index], array[index]))
            }

            // 加载到nice-select中
            (function () {
                [].slice.call(document.querySelectorAll('select.cs-select')).forEach(function (el) {
                    new SelectFx(el, { onChange: selectChange });
                });
            })();
        },
        function (error) {
            showMessage("loadServerList Error!")
        }
    )
}

function newTd() {
    var td = document.createElement("td")
    td.className = "center"
    td.setAttribute("valign", "middle")
    return td
}

function memTrans(memCount) {
    var preFix = " Kb"
    var memCount = memCount / 1024
    if(memCount > 1024) {
        memCount = memCount / 1024
        preFix = " Mb"
        if (memCount > 1024) {
            memCount = memCount / 1024
            preFix = " Gb"
        }
    }

    return memCount.toFixed(2) + preFix
}

function ShowServerInfoByData(data) {
    //获取table
    var mainTable = document.getElementById("mainTable")
    var mainTbody = document.getElementById("mainTbody")

    var luaMem = 0
    // 清空旧数据
    $("#mainTable tbody").html("");
    // 动态插入
    for (const addr in data.service) {
        //生成元素信息
        var tr = document.createElement("tr")

        var addrTd = newTd()
        addrTd.innerText = data.service[addr]["addr"]
        tr.appendChild(addrTd)

        var nameTd = newTd()
        nameTd.innerText = data.service[addr]["name"]
        tr.appendChild(nameTd)

        var mqlenTd = newTd()
        mqlenTd.innerText = data.service[addr]["stat"]["mqlen"]
        tr.appendChild(mqlenTd)

        var taskTd = newTd()
        taskTd.innerText = data.service[addr]["stat"]["task"]
        tr.appendChild(taskTd)

        var lmemTd = newTd()
        lmemTd.innerText = data.service[addr]["mem"]
        luaMem = luaMem + parseFloat(data.service[addr]["mem"].split(" KB")[0])
        tr.appendChild(lmemTd)

        var cmemTd = newTd()
        cmemTd.innerText = data.service[addr]["cmem"] + " KB"
        tr.appendChild(cmemTd)

        var messageTd = newTd()
        messageTd.innerText = data.service[addr]["stat"]["message"]
        tr.appendChild(messageTd)

        var cpuTd = newTd()
        cpuTd.innerText = data.service[addr]["stat"]["cpu"]
        tr.appendChild(cpuTd)

        var cpuDetailTd = newTd()
        if(data.service[addr]["info"])
        {
            var span = document.createElement("span")
            for (const key in data.service[addr]["info"]) {
                var p = document.createElement("p")
                p.innerText = "func:" + key + ", count:" + data.service[addr]["info"][key]["count"]
                        + ", time:" + data.service[addr]["info"][key]["time"] + "s"
                span.appendChild(p)
            }
            cpuDetailTd.appendChild(span)
        }
        else
            cpuDetailTd.innerText = ""
        tr.appendChild(cpuDetailTd)

        mainTbody.appendChild(tr)
    }

    var serverTotalCMem = document.getElementById("serverTotalCMem")
    var memInfo = "总计LUA内存:" + memTrans(luaMem * 1024) + ",总计C内存:" + memTrans(data.totalcmem) + ",总计C内存块数量:" + data.blockcmem
    serverTotalCMem.innerText = memInfo

    mainTable.hidden = false
}

// 刷新服务器详细信息
function RefreshServerInfo() {
    getServerInfo(selServer)
}

// 获取服务器详细信息
function getServerInfo(nodeName) {
    HttpGet(monitorServerIp, monitorServerPort, "getServerInfo?serverNode=" + selServer,
        function (data) {
            //排序
            data.service.sort(function (a,b) {
                return parseInt(a.addr.substring(2), 16) - parseInt(b.addr.substring(2), 16)
            })

            ShowServerInfoByData(data)

            ServerDetailInfo = data
        },
        function (error) {
            showMessage("getServerInfo Error!")
        }
    )
    
    serverTotalOnlineCount.innerText = ""
    if(nodeName.indexOf("game") >= 0) {
        // 游戏服务器,额外请求在线数量
        HttpGet(monitorServerIp, monitorServerPort, "getOnlineCount?serverNode=" + selServer,
            function (data) {
                serverTotalOnlineCount.innerText = "在线人数:" + data.count
            },
            function (error) {
                showMessage("getOnlineCount Error!")
            }
        )
    }
}

var addrSortFlag = false
// 地址排序
function addrSort() {
    addrSortFlag = !addrSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return addrSortFlag ? parseInt(a.addr.substring(2), 16) - parseInt(b.addr.substring(2), 16)
            : parseInt(b.addr.substring(2), 16) - parseInt(a.addr.substring(2), 16)
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var nameSortFlag = false
// 名称排序
function nameSort() {
    nameSortFlag = !nameSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return nameSortFlag ? ( a.name > b.name  ? 1 : -1) : ( a.name < b.name ? 1 : -1 )
    }) 

    ShowServerInfoByData(ServerDetailInfo)
}

var mqlenSortFlag = false
// 消息队列排序
function mqlenSort() {
    mqlenSortFlag = !mqlenSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return mqlenSortFlag ? a.stat.mqlen - b.stat.mqlen : b.stat.mqlen - a.stat.mqlen
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var taskSortFlag = false
// 任务队列排序
function taskSort() {
    taskSortFlag = !taskSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return taskSortFlag ? a.stat.task - b.stat.task : b.stat.task - a.stat.task
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var lmemSortFlag = false
// lua内存排序
function lmemSort() {
    lmemSortFlag = !lmemSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return lmemSortFlag ? parseInt(a.mem.substring(0, a.mem.indexOf("Kb")), 10) - parseInt(b.mem.substring(0, b.mem.indexOf("Kb")), 10)
            : parseInt(b.mem.substring(0, b.mem.indexOf("Kb")), 10) - parseInt(a.mem.substring(0, a.mem.indexOf("Kb")), 10)
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var cmemSortFlag = false
// C内存排序
function cmemSort() {
    cmemSortFlag = !cmemSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return cmemSortFlag ? a.cmem - b.cmem : b.cmem - a.cmem
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var messageSortFlag = false
// 总消息数量排序
function messageSort() {
    messageSortFlag = !messageSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return messageSortFlag ? a.stat.message - b.stat.message : b.stat.message - a.stat.message
    })

    ShowServerInfoByData(ServerDetailInfo)
}

var cpuSortFlag = false
// CU时间排序
function cpuSort() {
    cpuSortFlag = !cpuSortFlag

    ServerDetailInfo.service.sort(function (a, b) {
        return cpuSortFlag ? a.stat.cpu - b.stat.cpu : b.stat.cpu - a.stat.cpu
    })

    ShowServerInfoByData(ServerDetailInfo)
}

// 选择改变
function selectChange( val ) {
    selServer = val
    if (selPanle=="server") {
        // 获取选择的服务器node
        var serverListSelect = document.getElementById("serverListSelect")
        var node = serverListSelect.options[serverListSelect.selectedIndex].value
        serverStatus()
        if (node != null && node != "") {
            //请求服务器信息
            getServerInfo(val)
        }
    }
    else if (selPanle == "pm" ) {
        // 显示PM指令
        var pmDiv = document.getElementById("pmDiv")
        pmDiv.hidden = false
        getPmHelp()
    }
    
}

function HideAll() {
    var mainTable = document.getElementById("mainTable")
    mainTable.hidden = true
    var selectDiv = document.getElementById("selectDiv")
    selectDiv.hidden = true
    var pmDiv = document.getElementById("pmDiv")
    pmDiv.hidden = true
    var serverInfoDiv = document.getElementById("serverInfoDiv")
    serverInfoDiv.hidden = true
    var pmInput = document.getElementById("pmInput")
    var pmButton = document.getElementById("pmButton")
    pmInput.hidden = true
    pmButton.hidden = true
    var battleInfoDiv = document.getElementById("battleInfoDiv")
    battleInfoDiv.hidden = true
    var testcaseLogPre = document.getElementById("testcaseLog")
    testcaseLogPre.hidden = true
    var createEvEDiv = document.getElementById("createEvEDiv")
    createEvEDiv.hidden = true
    var restartClusterDiv = document.getElementById("restartClusterDiv")
    restartClusterDiv.hidden = true
    var modifyDataDiv = document.getElementById("modifyDataDiv")
    modifyDataDiv.hidden = true
    var exportSpriteDataDiv = document.getElementById("exportSpriteDataDiv")
    exportSpriteDataDiv.hidden = true
    var reloadConfigDiv = document.getElementById("reloadConfigDiv")
    reloadConfigDiv.hidden = true
    var closeServerDiv = document.getElementById("closeServerDiv")
    closeServerDiv.hidden = true
    var hotfixDiv = document.getElementById("hotfixDiv")
    hotfixDiv.hidden = true
    var transDataDiv = document.getElementById("transDataDiv")
    transDataDiv.hidden = true
    var restartGameLineDiv = document.getElementById("restartGameLineDiv")
    restartGameLineDiv.hidden = true
}

function currentSelect(name) {
    var navs = ["a_select", "a_pm", "a_status", "a_battleInfo", "a_netdata",
        "a_testcase", "a_createEvE", "a_restartCluster", "a_modifyData", "a_exportSpriteData", "a_reloadConfig",
        "a_closeServer", "a_hotfix", "a_transData"]
    navs.forEach(element => {
        var select = document.getElementById(element)
        if(select != null)
            select.setAttribute("class", "")
    });

    var curselect = document.getElementById(name)
    curselect.setAttribute("class", "current-demo")
}

function emptyClass(obj) {
    obj.setAttribute("class", "")
}

// 选择服务器
function selectServer() {
    HideAll()
    var selectDiv = document.getElementById("selectDiv")
    selectDiv.hidden = false

    currentSelect("a_select")

    selPanle = "server"
}

//PM命令
function pmCmd() {
    HideAll()
    var selectDiv = document.getElementById("selectDiv")
    selectDiv.hidden = false
    var pmDiv = document.getElementById("pmDiv")
    var pmInput = document.getElementById("pmInput")
    var pmButton = document.getElementById("pmButton")
    if (selServer == null || selServer.startsWith("game") == false) {
        pmDiv.hidden = true
        pmInput.hidden = true
        pmButton.hidden = true
    }
    else {
        pmDiv.hidden = false
        pmInput.hidden = true
        pmButton.hidden = true
        getPmHelp()
    }
        
    
    currentSelect("a_pm")

    selPanle = "pm"
}

//服务器状态
function serverStatus() {
    HideAll()
    var serverInfoDiv = document.getElementById("serverInfoDiv")
    serverInfoDiv.hidden = false

    var mainTable = document.getElementById("mainTable")
    mainTable.hidden = false

    currentSelect("a_status")

    selPanle = "status"
}

//战斗数据
function battleInfo() {
    if (selServer == null || selServer.startsWith("battle") == false) {
        showMessage("请选择战斗服务器!")
        return
    }
    HideAll()

    var battleInfoDiv = document.getElementById("battleInfoDiv")
    battleInfoDiv.hidden = false

    currentSelect("a_battleInfo")
}

//监控数据
function netdata() {
    window.open("http://" + monitorServerIp + ":" + netdataPort)
}

var pmCmds

//获取PM命令帮助指令
function getPmHelp() {
    if (selServer == null || selServer.startsWith("game")== false) {
        showMessage("请选择游服!")
        return
    }
    HttpGet(monitorServerIp, monitorServerPort, "pmCmd?serverNode=" + selServer +"&cmd=showHelp", function (data) {
        pmCmds = data
        //显示PM命令列表
        var pmNav = document.getElementById("pmNav")
        // 清空旧数据
        $("#pmNav").html("");

        var i = 0
        for (const index in data) {
            var a = document.createElement("a")
            a.href = "javascript:void(0)"
            i = i + 1
            if(i >= 5) {
                a.innerHTML = "  " + data[index]["explan"] + "          <br/>"
                i = 0
            }
            else
                a.innerHTML = "  " + data[index]["explan"] + "          "
            a.onclick = function () {
                clickPM(index)
            } 
            pmNav.appendChild(a)
        }
    })
}

var pmIndex
var roleId
function clickPM(index) {
    pmIndex = index
    if (pmCmds[index]) {
        //显示PM命令的参数和说明
        var pmExplan = document.getElementById("pmExplan")
        pmExplan.innerHTML = "命令说明:" + pmCmds[index]["explan"]
        var pmInput = document.getElementById("pmInput")
        var pmButton = document.getElementById("pmButton")
        pmInput.hidden = false
        pmButton.hidden = false
        $("#pmInput").html("")

        var lable = document.createElement("lable")
        lable.innerHTML = "角色ID:"
        var input = document.createElement("input")
        input.id = "input0"
        if (roleId){
            input.value = roleId
        }
        
        pmInput.appendChild(lable)
        pmInput.appendChild(input)
        var br = document.createElement("br")
        pmInput.appendChild(br)
        var br = document.createElement("br")
        pmInput.appendChild(br)

        //生成input
        var args = pmCmds[index]["arg"].split("|")
        for (let index = 0; index < args.length; index++) {
            const name = args[index];
            if(name == "") continue;
            var lable = document.createElement("lable")
            lable.innerHTML = name + ":"
            var input = document.createElement("input")
            input.id = "input" + (index + 1)
            pmInput.appendChild(lable)
            pmInput.appendChild(input)
            var br = document.createElement("br")
            pmInput.appendChild(br)
            var br = document.createElement("br")
            pmInput.appendChild(br)
        }
        
    }
}

function clickPMButton() {
    var cmd = pmCmds[pmIndex]["cmd"]
    var args = ""
    for (let index = 0; index < 100; index++) {
        var input = document.getElementById("input"+index)
        if(input == null) break
        //记忆roleId
        if(index == 0) {
            roleId = input.value
        }
        else
            args = args + "&" + index + "=" + input.value
    }

    HttpGet(monitorServerIp, monitorServerPort, "pmCmd?serverNode=" + selServer +"&cmd=" + cmd + "&rid=" + roleId + args, function (data) {
        if(data["error"] == "success") {
            showMessage("命令:" + cmd + "执行成功")
        }
        else {
            showMessage("命令:" + cmd + "执行失败, msg:" + data["error"])
        }
    })
}

var battleScene
// 获取战斗信息
function clickBattleInfo() {
    var battleIndex = document.getElementById("battleIndex")
    HttpGet(monitorServerIp, monitorServerPort, "getBattleServerDetail?serverNode=" + selServer +"&battleIndex=" + battleIndex.value, function (data) {
        var roleArray = new Array()
        battleScene = data
        var showBattleInfo = document.getElementById("showBattleInfo")
        $("#showBattleInfo").html("");
        // 创建table
        var table = document.createElement("table")
        table.className = "bordered"
        // 创建thead
        var thead = document.createElement("thead")
        table.appendChild(thead)
        // 创建tr
        var tr = document.createElement("tr")
        thead.appendChild(tr)

        //创建tbody
        var tbody = document.createElement("tbody")
        var bodytr = document.createElement("tr")
        tbody.appendChild(bodytr)
        table.appendChild(tbody)

        for (const key in data) {
            // 创建th
            var th = document.createElement("th")
            th.className = "center"
            th.innerHTML = key
            tr.appendChild(th)

            //创建td
            var td = newTd()
            if(typeof(data[key]) == "object") {
                if(key == "roleInfos") {
                    for (const battleNo in data[key]) {
                        var roleTable = document.createElement("table")
                        roleTable.className = "bordered"
                        // 创建thead
                        var roleThead = document.createElement("thead")
                        roleTable.appendChild(roleThead)
                        // 创建tr
                        var roleTr = document.createElement("tr")
                        roleThead.appendChild(roleTr)

                        //创建tbody
                        var roleTbody = document.createElement("tbody")
                        var roleBodytr = document.createElement("tr")
                        roleTbody.appendChild(roleBodytr)
                        roleTable.appendChild(roleTbody)
                        // 创建th
                        var roleTh = document.createElement("th")
                        roleTh.className = "center"
                        roleTh.innerHTML = key + "(" + battleNo + ")"
                        roleTr.appendChild(roleTh)
                        var roleTd = newTd()
                        
                        var roleSubTable = document.createElement("table")
                        roleSubTable.className = "bordered"
                        // 创建thead
                        var roleSubThead = document.createElement("thead")
                        roleSubTable.appendChild(roleSubThead)
                        // 创建tr
                        var roleSubTr = document.createElement("tr")
                        roleSubThead.appendChild(roleSubTr)

                        //创建tbody
                        var roleSubTbody = document.createElement("tbody")
                        var roleSubBodytr = document.createElement("tr")
                        roleSubTbody.appendChild(roleSubBodytr)
                        roleSubTable.appendChild(roleSubTbody)
                        roleTd.appendChild(roleSubTable)

                        //角色属性信息
                        for (const roleKey in data[key][battleNo]) {
                            // 创建th
                            var roleSubTh = document.createElement("th")
                            roleSubTh.className = "center"
                            roleSubTh.innerHTML = roleKey
                            roleSubTr.appendChild(roleSubTh)
                            var roleSubTd = newTd()

                            if(roleKey != "roleAttr") {
                                
                                if (typeof (data[key][battleNo][roleKey]) == "object") {
                                    roleSubTd.innerText = JSON.stringify(data[key][battleNo][roleKey])
                                }
                                else {
                                    roleSubTd.innerText = data[key][battleNo][roleKey]
                                }
                            }
                            else {
                                //加入按钮
                                var btn = document.createElement("button")
                                btn.innerText = "角色属性"
                                btn.onclick = function () {
                                    clickRoleAttr(battleNo)
                                }
                                roleSubTd.appendChild(btn)
                            }

                            roleSubBodytr.appendChild(roleSubTd)
                        }
                        
                        roleBodytr.appendChild(roleTd)
                        roleArray.push(roleTable)
                    }
                    
                }
                else
                    td.innerText = JSON.stringify(data[key])
            }
            else
                td.innerText = data[key]
            bodytr.appendChild(td)
        }
        showBattleInfo.appendChild(table)

        for (const key in roleArray) {
            showBattleInfo.appendChild(roleArray[key])
        }
    })
}

function clickRoleAttr(battleNo) {
    var roleAttr = battleScene["roleInfos"][battleNo].roleAttr

    var showBattleInfo = document.getElementById("showBattleInfo")
    $("#showBattleInfo").html("");
    showBattleInfo.innerHTML = JSON.stringify(roleAttr);
/*
    // 创建table
    var table = document.createElement("table")
    table.className = "bordered"
    // 创建thead
    var thead = document.createElement("thead")
    table.appendChild(thead)
    // 创建tr
    var tr = document.createElement("tr")
    thead.appendChild(tr)

    //创建tbody
    var tbody = document.createElement("tbody")
    var bodytr = document.createElement("tr")
    tbody.appendChild(bodytr)
    table.appendChild(tbody)

    for (const key in roleAttr) {
        // 创建th
        var th = document.createElement("th")
        th.className = "center"
        th.innerHTML = key
        tr.appendChild(th)

        //创建td
        var td = newTd()
        if (typeof (roleAttr[key]) == "object") {
            td.innerText = JSON.stringify(roleAttr[key])
        }
        else {
            td.innerText = roleAttr[key]
        }
        bodytr.appendChild(td)
    }

    showBattleInfo.appendChild(table)
*/
}

function testcase() {
    HideAll()
    var testcaseLogPre = document.getElementById("testcaseLog")
    testcaseLogPre.hidden = false
    currentSelect("a_testcase")
    webSocketMessageRealTime()
}

// 通过websocket 时候获取内容
function webSocketMessageRealTime() {
    HttpGet(monitorServerIp, monitorServerPort, "runTestCase")
    var ws = new WebSocket('ws://' + monitorServerIp + ':' + monitorServerWebScoektPort)
    // helper function: log message to screen
    function log(msg) {
        document.getElementById('testcaseLog').textContent += msg + '\n';
    }
    log("执行测试用例ing...")
    ws.onmessage = function (event) {
        log(event.data)
    }
}

function createEvE() {
    if (selServer == null || selServer.startsWith("battle") == false) {
        showMessage("请选择战斗服务器!")
        return
    }
    HideAll()
    var createEvEDiv = document.getElementById("createEvEDiv")
    createEvEDiv.hidden = false
    currentSelect("a_createEvE")
}

function restartCluster() {
    if (selServer == null || selServer.startsWith("monitor") == false) {
        showMessage("请选择监控服务器!")
        return
    }
    HideAll()
    var createEvEDiv = document.getElementById("restartClusterDiv")
    createEvEDiv.hidden = false
    currentSelect("a_restartCluster")
}

function ClickCreateEVE() {
    var createEvEGroupDown = document.getElementById("createEvEGroupDown")
    var createEvEGroupUp = document.getElementById("createEvEGroupUp")
    var createEvECount = document.getElementById("createEvECount")
    var createEvEDivResult = document.getElementById("createEvEDivResult")
    var loadingLable = document.createElement("lable")
    loadingLable.innerHTML = "正在模拟,请稍后..."
    while (createEvEDivResult.hasChildNodes()) //当div下还存在子节点时 循环继续
        createEvEDivResult.removeChild(createEvEDivResult.firstChild);
    createEvEDivResult.appendChild(loadingLable)

    HttpGet(monitorServerIp, monitorServerPort,
        "createEvE?serverNode=" + selServer +"&downMonsterGroupId=" + createEvEGroupDown.value + "&upMonsterGroupId=" + createEvEGroupUp.value + "&count=" + createEvECount.value, function (data) {
            if (data.error) {
                showMessage(data.error)
                return
            }
            else {
                var createEvEDivResult = document.getElementById("createEvEDivResult")
                while (createEvEDivResult.hasChildNodes()) //当div下还存在子节点时 循环继续
                    createEvEDivResult.removeChild(createEvEDivResult.firstChild);

                var resultTable = document.createElement("table")
                resultTable.className = "bordered"

                // 创建tbody
                var resultTbody = document.createElement("tbody")
                // 创建tr、td
                var resultBodytr = document.createElement("tr")
                var resultTd = newTd()
                resultTd.innerHTML = "战斗汇总统计"
                resultTd.bgColor = "#7FFFD4"
                resultTd.colSpan = 4
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.innerHTML = "战斗场次"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = createEvECount.value
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.innerHTML = "战斗平均回合"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.innerHTML = data["arvgTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.innerHTML = "战斗最小回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["minTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.innerHTML = "战斗最大回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["maxTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.bgColor = "#7FFFD4"
                resultTd.innerHTML = "玩家方统计"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.colSpan = 2
                resultTd.bgColor = "#7FFFD4"
                resultTd.innerHTML = "怪物方统计"
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "阵容编号"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = createEvEGroupDown.value
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "阵容编号"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = createEvEGroupUp.value
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "成员数量"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["memberCount"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "成员数量"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["memberCount"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜利场次"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["win"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜利场次"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["win"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜率"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["winRate"] + "%"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜率"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["winRate"] + "%"
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜场平局回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["winArvgTrun"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜场平局回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["winArvgTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜场最小回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["winMinTrun"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜场最小回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["winMinTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜场最大回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["winMaxTrun"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜场最大回合数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["winMaxTrun"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                resultBodytr = document.createElement("tr")
                resultTd = newTd()
                resultTd.innerHTML = "胜利时平均剩余人数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["downSide"]["winMemberCount"]
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = "胜利时平均剩余人数"
                resultBodytr.appendChild(resultTd)
                resultTd = newTd()
                resultTd.innerHTML = data["upSide"]["winMemberCount"]
                resultBodytr.appendChild(resultTd)
                resultTbody.appendChild(resultBodytr)

                for (let index = 0; index < data["roleDetail"].length; index++) {
                    const element = data["roleDetail"][index];

                    var detailTr = document.createElement("tr")
                    resultTd = newTd()
                    if (element["battleNo"] < 10)
                        resultTd.innerHTML = "玩家方成员统计(" + (element["battleNo"] + 1) + ")"
                    else
                        resultTd.innerHTML = "怪物方成员统计(" + (element["battleNo"] + 1) + ")"
                    resultTd.bgColor = "#7FFFD4"
                    resultTd.colSpan = 4
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "位置编号"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.innerHTML = element["battleNo"] + 1
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "怪物ID"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.innerHTML = element["monsterId"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "怪物等级"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["level"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该怪物平均伤害总量"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgDamage"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该怪物平均受伤总量"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgHurt"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该怪物平均有效治疗量"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgHeal"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该怪物平均被治疗量"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgHealed"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该单位平均生存回合数"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgLiveTrun"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该单位胜利场的平均生存回合数"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgWinLiveTrun"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)

                    detailTr = document.createElement("tr")
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = "该单位失败场的平均生存回合数"
                    detailTr.appendChild(resultTd)
                    resultTd = newTd()
                    resultTd.colSpan = 2
                    resultTd.innerHTML = element["arvgLoseLiveTrun"]
                    detailTr.appendChild(resultTd)
                    resultTbody.appendChild(detailTr)
                }

                resultTable.appendChild(resultTbody)
                createEvEDivResult.appendChild(resultTable)
            }
        })
}

function ClickRestartCluster() {
    var restartClusterBranch = document.getElementById("restartClusterBranch")
    var branch = restartClusterBranch.value

    HttpGet(monitorServerIp, monitorServerPort,
        "restartCluster?serverNode=" + selServer +"&branch=" + branch, function (data) {
            if (data.error) {
                showMessage("重启集群失败!" + data.error)
                return
            }
            else
            {
                showMessage("重启集群完成!")
            }
        }
    )
}

// 修改数据
function modifyData() {
    if (selServer == null || selServer.startsWith("game") == false) {
        showMessage("请选择游戏服务器!")
        return
    }
    HideAll()
    var createEvEDiv = document.getElementById("modifyDataDiv")
    createEvEDiv.hidden = false
    currentSelect("a_modifyData")
}

// 查询数据
function QueryModifyData() {
    var modifyDataTable = document.getElementById("modifyDataTable")
    var modifyDataKey = document.getElementById("modifyDataKey")
    if(modifyDataTable.value == "" || modifyDataKey.value == "")
    {
        showMessage("请输入表名和主键值")
        return
    }

    HttpGet(monitorServerIp, monitorServerPort,
        "modifyData?serverNode=" + selServer +"&mode=1&tbname=" + modifyDataTable.value + "&key=" + modifyDataKey.value, function (data) {
            document.getElementById("modifyDataLable").innerText = JSON.stringify(data, null, 2)
        }
    )
}

// 导出精灵数据
function exportSpriteData() {
    HideAll()
    var exportSpriteDataDiv = document.getElementById("exportSpriteDataDiv")
    exportSpriteDataDiv.hidden = false
    currentSelect("a_exportSpriteData")
}

// 重载配置
function reloadConfig() {
    HideAll()
    var reloadConfigDiv = document.getElementById("reloadConfigDiv")
    reloadConfigDiv.hidden = false
    currentSelect("a_reloadConfig")
}

function Base64() {

    // private property
    _keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    // public method for encoding
    this.encode = function (input) {
        var output = "";
        var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
        var i = 0;
        input = _utf8_encode(input);
        while (i < input.length) {
            chr1 = input.charCodeAt(i++);
            chr2 = input.charCodeAt(i++);
            chr3 = input.charCodeAt(i++);
            enc1 = chr1 >> 2;
            enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
            enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
            enc4 = chr3 & 63;
            if (isNaN(chr2)) {
                enc3 = enc4 = 64;
            } else if (isNaN(chr3)) {
                enc4 = 64;
            }
            output = output +
                _keyStr.charAt(enc1) + _keyStr.charAt(enc2) +
                _keyStr.charAt(enc3) + _keyStr.charAt(enc4);
        }
        return output;
    }

    // public method for decoding
    this.decode = function (input) {
        var output = "";
        var chr1, chr2, chr3;
        var enc1, enc2, enc3, enc4;
        var i = 0;
        input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");
        while (i < input.length) {
            enc1 = _keyStr.indexOf(input.charAt(i++));
            enc2 = _keyStr.indexOf(input.charAt(i++));
            enc3 = _keyStr.indexOf(input.charAt(i++));
            enc4 = _keyStr.indexOf(input.charAt(i++));
            chr1 = (enc1 << 2) | (enc2 >> 4);
            chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
            chr3 = ((enc3 & 3) << 6) | enc4;
            output = output + String.fromCharCode(chr1);
            if (enc3 != 64) {
                output = output + String.fromCharCode(chr2);
            }
            if (enc4 != 64) {
                output = output + String.fromCharCode(chr3);
            }
        }
        output = _utf8_decode(output);
        return output;
    }

    // private method for UTF-8 encoding
    _utf8_encode = function (string) {
        string = string.replace(/\r\n/g, "\n");
        var utftext = "";
        for (var n = 0; n < string.length; n++) {
            var c = string.charCodeAt(n);
            if (c < 128) {
                utftext += String.fromCharCode(c);
            } else if ((c > 127) && (c < 2048)) {
                utftext += String.fromCharCode((c >> 6) | 192);
                utftext += String.fromCharCode((c & 63) | 128);
            } else {
                utftext += String.fromCharCode((c >> 12) | 224);
                utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                utftext += String.fromCharCode((c & 63) | 128);
            }

        }
        return utftext;
    }

    // private method for UTF-8 decoding
    _utf8_decode = function (utftext) {
        var string = "";
        var i = 0;
        var c = c1 = c2 = 0;
        while (i < utftext.length) {
            c = utftext.charCodeAt(i);
            if (c < 128) {
                string += String.fromCharCode(c);
                i++;
            } else if ((c > 191) && (c < 224)) {
                c2 = utftext.charCodeAt(i + 1);
                string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
                i += 2;
            } else {
                c2 = utftext.charCodeAt(i + 1);
                c3 = utftext.charCodeAt(i + 2);
                string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
                i += 3;
            }
        }
        return string;
    }
}

// 更新数据
function UpdateModifyData() {
    var modifyDataTable = document.getElementById("modifyDataTable")
    var modifyDataKey = document.getElementById("modifyDataKey")
    var modifyDataLable = document.getElementById("modifyDataLable")
    if (modifyDataTable.value == "" || modifyDataKey.value == "" || modifyDataLable.innerText == "") {
        showMessage("请输入表名和主键值,以及内容")
        return
    }

    var b = new Base64()
    var content = b.encode(modifyDataLable.innerText)
    HttpGet(monitorServerIp, monitorServerPort,
        "modifyData?serverNode=" + selServer +"&mode=2&tbname=" + modifyDataTable.value + "&key=" + modifyDataKey.value + "&value=" + content,
        function (data) {
            if(data.result) {
                showMessage("更新成功")
            }
            else {
                showMessage("更新失败")
            }
        }
    )
}

// 导出精灵问答数据
function ExportSpriteData() {
    HttpGet(monitorServerIp, monitorServerPort, "spriteData?serverNode=" + selServer,
        function (data) {
            
        }
    )
}

// 重载配置数据
function ReloadConfig() {
    HttpGet(monitorServerIp, monitorServerPort, "reloadSelfConfig?serverNode=" + selServer,
        function (data) {
            if (data.result) {
                showMessage(data.name + " 重载完成!")
            }
            else {
                showMessage(data.name + " 重载失败!")
            }
        }
    )
}

// 关闭服务器
function closeServer() {
    HideAll()
    var closeServerDiv = document.getElementById("closeServerDiv")
    closeServerDiv.hidden = false
    currentSelect("a_closeServer")
}

// 关闭服务器
function CloseServer() {
    var closeTypeSelect = document.getElementById("closeTypeSelect")
    HttpGet(monitorServerIp, monitorServerPort, "closeSelf?serverNode=" + selServer +"&type=" + closeTypeSelect.value,
        function () {
            showMessage("已通知服务器[" + selServer + "] 开始维护!")
        }
    )
}

// 点击热更
function clickHotfix() {
    if (selServer == null || selServer.startsWith("monitor")== false)
    {
        showMessage("请选择monitor服务器")
        return
    }

    HideAll()
    var hotfixDiv = document.getElementById("hotfixDiv")
    hotfixDiv.hidden = false
    currentSelect("a_hotfix")
}

// 执行热更
function Hotfix() {
    HttpGet(monitorServerIp, monitorServerPort, "hotfixServer?serverNode=" + selServer,
        function (data) {
            showMessage(data.result)
        }
    )
}

// 点击数据转换
function clickTransData() {
    if (selServer == null || selServer.startsWith("db")== false) {
        showMessage("请选择db服务器!")
        return
    }
    HideAll()
    var transDataDiv = document.getElementById("transDataDiv")
    transDataDiv.hidden = false
    currentSelect("a_transData")
}

// 点击重启游戏
function clickRestartGameLine() {
    if (selServer == null || selServer.startsWith("game")== false) {
        showMessage("请选择game服务器!")
        return
    }
    HideAll()
    var transDataDiv = document.getElementById("restartGameLineDiv")
    transDataDiv.hidden = false
    currentSelect("a_restartGameLine")
}

// 执行重启
function restartGameLine() {
    HttpGet(monitorServerIp, monitorServerPort, "restartGame?serverNode=" + selServer,
        function () {
            showMessage("已通知所有线路重启!10s左右完成!")
        }
    )
}

// 二进制转JSON
function TransDataToJSON() {
    var transDataInput = document.getElementById("transDataInput")
    if (transDataInput.value == "") {
        showMessage("请输入表名")
        return
    }

    var tbTypeSelect = document.getElementById("tbTypeSelect")

    HttpGet(monitorServerIp, monitorServerPort, "transData?serverNode=" + selServer +"&tbName="
                    + transDataInput.value + "&tbType=" + tbTypeSelect.value + "&transType=1",
        function () {
            showMessage("服务器[" + selServer + "] 二进制转换JSON完成!")
        }
    )
}

// JSON转二进制
function TransJSONToData() {
    var transDataInput = document.getElementById("transDataInput")
    if (transDataInput.value == "") {
        showMessage("请输入表名")
        return
    }

    var tbTypeSelect = document.getElementById("tbTypeSelect")

    HttpGet(monitorServerIp, monitorServerPort, "transData?serverNode=" + selServer +"&tbName="
                    + transDataInput.value + "&tbType=" + tbTypeSelect.value + "&transType=2",
        function () {
            showMessage("服务器[" + selServer + "] JSON转换二进制完成!")
        }
    )
}
