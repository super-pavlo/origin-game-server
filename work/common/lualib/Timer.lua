--[[
* @file : Timer.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 14:41:12 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 定时器实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local string = string
local table = table
local os = os
local assert = assert
local math = math

local Timer = {}

local TimerSession = {}
local TimerId = 0

---@see 生成一个新的timerSessionId
---@return integer
local function NewSession()
	TimerId = TimerId + 1
	TimerSession[TimerId] = true
	return TimerId
end

---@see 检查一个timerSessionId是否还生效
---@param timerid integer Timer session id
---@return boolean true/false
function Timer.CheckSession( timerid )
	return TimerSession[timerid]
end

---@see 回收一个timerSessionId
---@param timerid integer Timer session id
---@return void
local function RecoverSession( timerid )
	TimerSession[timerid] = nil
end

---@see 注册interval秒后触发.仅触发一次
---@param interval integer 时间间隔
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runAfter( interval, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			f(table.unpack(args.farg))
		end
		RecoverSession(args.timerid)
	end

	skynet.timeout(interval, run)
	return timerid
end

---@see 注册interval秒后触发.持续触发
---@param interval integer 时间间隔,秒
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runEvery( interval, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			local ret, error = xpcall(f, debug.traceback, table.unpack(args.farg))
			if not ret then LOG_ERROR("runEvery error:%s", error) end
			skynet.timeout(interval, run)
		else
			RecoverSession(args.timerid)
		end
	end

	skynet.timeout(interval, run)
	return timerid
end

---@see 注册在interval时刻触发.仅触发一次
---@param timepoint integer unix时间戳
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runAt( timepoint, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			f(table.unpack(args.farg))
		end
		RecoverSession(args.timerid)
	end

	local secs = timepoint - os.time()
	skynet.timeout(math.floor(secs * 100), run)
	return timerid
end

---@see 注册每小时整点回调
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runEveryHour(f, ...)
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			local ret, error = xpcall(f, debug.traceback, table.unpack(args.farg))
			if not ret then LOG_ERROR("runEveryHour error:%s", error) end
			skynet.timeout(Timer.GetDiffSecToNextHour()*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	--获取当前时间距离下一个整点相差的秒数
	local secs = Timer.GetDiffSecToNextHour()
	skynet.timeout(secs*100, run)
	return timerid
end

---@see 注册每分钟整点回调
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runEveryMin(f, ...)
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			local ret, error = xpcall(f, debug.traceback, table.unpack(args.farg))
			if not ret then LOG_ERROR("runEveryMin error:%s", error) end
			skynet.timeout(Timer.GetDiffSecToNextMin()*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	--获取当前时间距离下一个整点相差的秒数
	local secs = Timer.GetDiffSecToNextMin()
	skynet.timeout(secs*100, run)
	return timerid
end

---@see 注册每天某个时刻回调
---@param h integer 小时
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runEveryDayHour( h, f, ... )
	assert(Timer.IsValidHMS(h))

	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			local ret, error = xpcall(f, debug.traceback, table.unpack(args.farg))
			if not ret then LOG_ERROR("runEveryDayHour error:%s", error) end
			skynet.timeout(Timer.GetDiffSecToNextHMS(h, 0)*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	local secs = Timer.GetDiffSecToNextHMS(h, 0)
	skynet.timeout(secs*100, run)
	return timerid
end


---@see 注册每天某个时刻某分钟回调
---@param h integer 小时
---@param m integer 分钟
---@param s integer 秒
---@param f function 回调函数
---@param ... any 参数
---@return integer
function Timer.runEveryDayHourMin( h, m, s, f, ... )
	assert(Timer.IsValidHMS(h, m, s))

	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if Timer.CheckSession(args.timerid) then
			local ret, error = xpcall(f, debug.traceback, table.unpack(args.farg))
			if not ret then LOG_ERROR("runEveryDayHourMin error:%s", error) end
			skynet.timeout(Timer.GetDiffSecToNextHMS(h, m, s) * 100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	local secs = Timer.GetDiffSecToNextHMS(h, m, s)
	skynet.timeout(secs*100, run)
	return timerid
end

---@see 移除一个定时器
---@param timerid integer 定时器id
---@return boolean true(delete ok)/ false反之
function Timer.delete( timerid )
	if TimerSession[timerid] then
		TimerSession[timerid] = nil
		return true
	end

	return false
end


---@see 获取下N个小时的时间点
---@param interval integer 若干小时
---@param timepoint integer 起始时间点,为nil时则为当前时间
---@return 小时点Hour,unix时间戳
function Timer.GetNextHour( interval,timepoint )
	local tt = timepoint or os.time()

	tt = tt + 3600 * interval

	local time = os.date('*t',tt)

	return time.hour,tt
end

---@see 获取下N个半小时的时间点
---@param interval integer 若干小时
---@param timepoint integer 起始时间点,为nil时则为当前时间
---@return unix时间戳
function Timer.GetNextHalfHour( interval, timepoint )
	local time = os.date("*t",timepoint + (1800 * interval))
	time.sec = 0

	if time.min < 30 then
		time.min = 0
	else
		time.min = 30
	end

	return os.time(time)

end

---@see 获取下N个时刻的时间点
---@param interval integer 若干小时
---@return unix时间戳
function Timer.GetNextHourPoint( interval )
	interval = interval or 1
	local ti = os.time() + 3600 * interval --获取下一时刻

	ti = os.date("*t",ti)

	ti.min = 0
	ti.sec = 0

	return os.time(ti)
end

---@see HMS时间格式的大于等于判断函数
---@param ... any h,m必填 s可以不填,默认=0
---@return boolean true(hms1 >= hms2)/ false反之
-- eg: 判断17:50:30与21:30:30哪个时间点更大
--	   Timer.CheckHmsGreaterEqual(17, 50, 30, 21, 30, 30)
function Timer.CheckHmsGreaterEqual( h1, m1, s1, h2, m2, s2 )
	s1 = s1 or 0
	s2 = s2 or 0
	assert(Timer.IsValidHMS(h1, m1, s1))
	assert(Timer.IsValidHMS(h2, m2, s2))

	if h1 ~= h2 then
		return h1 > h2
	elseif m1 ~= m2 then
		return m1 > m2
	elseif s1 ~= s2 then
		return s1 > s2
	else
		return true --相等
	end
end

---@see 计算当前时间到下一个HMS的秒数.如果此时间点已过则取至第二天此HM的秒数
---@param h integer 小时
---@param m integer 分钟
---@param s integer 秒
---@return integer 当前时间到下一个HMS的秒数,如果此时间点已过则取至第二天此HM的秒数
function Timer.GetDiffSecToNextHMS( h, m, s )
	s = s or 0
	assert(Timer.IsValidHMS(h, m, s))

	local now = os.date('*t')
	if Timer.CheckHmsGreaterEqual(now.hour, now.min, now.sec, h, m, s) then
		--时间点已过, 取当前时间到第二天hh:mm:ss的秒数
		local passed_secs = (now.hour - h) * 3600 + (now.min - m) * 60 + (now.sec - s)
		return 24 * 3600 - passed_secs
	else
		--未过
		return (h - now.hour) * 3600 + (m - now.min) * 60 + (s - now.sec)
	end
end

---@see 获取当前时间距离某一个整点的秒数
---@param interval integer 若干小时
---@return secs,相差的秒数
function Timer.GetDiffSecToNextHour(interval)
	local now = os.date('*t')
	return (interval or 1 ) * 3600-(now.min*60+now.sec)
end

---@see 获取当前时间距离某一个整分的秒数
---@param interval integer 若干小时
---@return integer 相差的秒数
function Timer.GetDiffSecToNextMin(interval)
	local now = os.date('*t')
	return (interval or 1 ) * 60 - now.sec
end

---@see 获取当前时间距下一天某时刻的秒.以x点为新的一天
---@param x integer 时刻点
---@return integer 相差的秒数
function Timer.GetDiffSecToNextDayX(x)
	local now = os.time()
	local ti = now + 3600 * 24 --获取下一天

	local nexttime = os.date('*t', ti)

	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = x, min = 0, sec = 0 }
	local next_day_ti = os.time(next_day)
	return next_day_ti - now
end

---@see 获取下一天某时刻的时间点
---@param x integer 时刻点
---@return unix时间戳
function Timer.GetNextDayX( x, isFix )
	local now = os.time()
	if isFix then
		now = Timer.fixCrossDayTime(now, true)
	end
	local ti = now + 3600 * 24 --获取下一天

	local nexttime = os.date('*t', ti)

	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = x, min = 0, sec = 0 }
	return os.time(next_day)
end

---@see 获取下一月某时刻的时间点
---@param x integer 时刻点
---@return unix时间戳
function Timer.GetNextMonthX( x )
	local now = os.time()
	local month = os.date("%m")
	local nextMonth
	local nexttime
	while true do
		now = now + 3600 * 24 --获取下一天
		nextMonth = os.date('%m', now)
		nexttime = os.date('*t', now)
		if nextMonth ~= month then
			break
		end
	end

	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = x, min = 0, sec = 0 }
	return os.time(next_day)
end

---@see 获取下x天x时刻的时间点
---@param x integer 天数
---@param hour integer 小时,默认为配置的跨天小时
---@return unix时间戳
function Timer.GetDayX( x, hour, fixTime )
	local now = os.time()
	if fixTime then now = Timer.fixCrossDayTime(now, true) end
	local ti = now + 3600 * 24 * x --获取下x天

	local nexttime = os.date('*t', ti)
	hour = hour or CFG.s_Config:Get("systemDayTime") or 0
	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = hour or 0, min = 0, sec = 0 }
	return os.time(next_day)
end

---@see 根据时间戳ti格式化日期
---@param ti integer unix时间戳
---@return time table
function Timer.GetYmd(ti)
	return os.date('%Y%m%d', ti)
end

---@see 根据时间戳ti格式化日期
---@param ti integer unix时间戳
---@return time table
function Timer.GetYmdh(ti)
	return os.date('%Y%m%d%H', ti)
end

---@see 根据时间戳ti格式化日期
---@param ti integer unix时间戳
---@return time table
function Timer.GetYmdhms(ti)
	return os.date('%Y%m%d%H%M%S', ti)
end

---@see 判断时间参数是否合法
---@param h integer 小时
---@param m integer 分钟
---@param s integer 秒 三个参数至少有一个不是nil
---@return boolean true/false
function Timer.IsValidHMS( h, m, s )
	local ret = true
	assert(h ~= nil or m ~= nil or s ~= nil)
	if h ~= nil then
		ret = (h >= 0 and h <= 23) and ret
	end
	if m ~= nil then
		ret = (m >= 0 and m <= 59) and ret
	end
	if s ~= nil then
		ret = (s >= 0 and s <= 59) and ret
	end
	return ret
end

---@see 获得本日开始时间
---@param now_time integer
---@return 当天的起始时间的unix时间戳
function Timer.GetDayBegin(nowTime, beginHour)
	nowTime = nowTime or os.time()
	beginHour = beginHour or CFG.s_Config:Get("systemDayTime") or 0

	local now_date = os.date("*t", nowTime)

	now_date.hour = beginHour
	now_date.min = 0
	now_date.sec = 0
	return os.time(now_date)
end

---@see 修正时间跨度的时间戳
function Timer.fixCrossDayTime( lastTime, _isTimeStamp )
	local beginHour = CFG.s_Config:Get("systemDayTime") or 0
	if not lastTime then lastTime = os.time() end
	local lastDateTime = os.date("*t", lastTime )
	if beginHour ~= 0 then
		if lastDateTime.hour >= 0 and lastDateTime.hour < beginHour then
			-- 此时间点算前一天
			lastDateTime = os.date("*t", lastTime - beginHour * 3600 )
		end
	end

	if not _isTimeStamp then
		return lastDateTime
	else
		return os.time(lastDateTime)
	end
end

---@see 判断给定的时间和当前时间是否是同一天
function Timer.isDiffDay( _lastTime, _noFix )
	local nowTime = _noFix and os.date( "*t" ) or Timer.fixCrossDayTime()
	local lastTime = _noFix and os.date( "*t", _lastTime ) or Timer.fixCrossDayTime( _lastTime )
	return not ( nowTime.year == lastTime.year and nowTime.month == lastTime.month and nowTime.day == lastTime.day )
end

---@see 判断给定的时间和当前时间是否是同一周.周日是每周开始
function Timer.isDiffWeek( _lastTime )
	-- 本周结束时间(%w返回的是0-6 = 星期天-星期六)
	local nowTime = Timer.fixCrossDayTime( nil, true )
	local dayOffset = 7 - tonumber(os.date("%w", nowTime ) )
	local endTime = Timer.GetDayX( dayOffset, CFG.s_Config:Get("systemDayTime") or 0, true )

	-- 当前时间不处于_lastTime的周跨度内
	return ( _lastTime < ( endTime - 7 * 24 * 3600 ) or _lastTime >= endTime )
end

---@see 判断给定的时间和当前时间是否是同一月
function Timer.isDiffMonth( _lastTime )
	local nowTime = Timer.fixCrossDayTime()
	_lastTime = Timer.fixCrossDayTime( _lastTime )
	return not ( nowTime.year == _lastTime.year and nowTime.month == _lastTime.month )
end

---@see 判断是否是同一小时
function Timer.isDiffHour( _lastTime )
	local nowDate = os.date("*t")
	local lastDate = os.date("*t", _lastTime)
	return nowDate.year ~= lastDate.year or nowDate.month ~= lastDate.month
		or nowDate.day ~= lastDate.day or nowDate.hour ~= lastDate.hour
end

---@see 判断当前是否是每周日
function Timer.isWeekBegin()
	local nowTime = Timer.fixCrossDayTime()
	return os.date("%w", nowTime) == "0"
end

---@see 获取2个时间点的时间天数间隔
function Timer.getDiffDays( _lTime, _rTime )
	_lTime = Timer.fixCrossDayTime( _lTime, true)
	_rTime = Timer.fixCrossDayTime( _rTime, true)
	local lData = os.date("*t", _lTime)
	local rData = os.date("*t", _rTime)
	if lData.year ~= rData.year then
		-- 不同年
		local diffDays = 0
		local lastData = { year = lData.year, month = 12, day = 31, hour = 0 }
		for i = lData.year, rData.year do
			if i == rData.year then
				diffDays = diffDays + rData.yday
			elseif i == lData.year then
				lastData.year = i
				os.time( lastData ) -- 利用os.time填充yday
				diffDays = diffDays + lastData.yday - lData.yday
			else
				lastData.year = i
				os.time( lastData ) -- 利用os.time填充yday
				diffDays = diffDays + lastData.yday
			end
		end
		return math.abs( diffDays )
	else
		-- 同一年
		return math.abs( rData.yday - lData.yday )
	end
end

---@see 获取指定年份的周数
---@param _timeStamp integer 指定时间戳
function Timer.getYearWeeks( _timeStamp, _year )
	local timeStampX = table.copy(Timer.fixCrossDayTime(_timeStamp), true)
	local timeStamp = { year = timeStampX.year, month = 12, day = 31 }
	if _year then timeStamp.year = _year end

	return os.date("%U", os.time(timeStamp))
end

---@see 获取2个时间点的时间周数间隔.周日是每周开始
function Timer.getDiffWeeks( _lTime, _rTime )
	-- 交换时间
	if _lTime > _rTime then
		_lTime = _lTime ~ _rTime
		_rTime = _lTime ~ _rTime
		_lTime = _lTime ~ _rTime
	end
	_lTime = Timer.fixCrossDayTime(_lTime, true)
	_rTime = Timer.fixCrossDayTime(_rTime, true)
	local lTime = os.date("*t", _lTime)
	local rTime = os.date("*t", _rTime)
	if lTime.year == rTime.year then
		return math.abs( os.date("%U", _rTime) - os.date("%U", _lTime) )
	else
		local smallYear = lTime.year
		local bigYear = rTime.year

		local diffWeeks = 0
		for year = smallYear, bigYear do
			if year == smallYear then
				diffWeeks = diffWeeks + Timer.getYearWeeks( nil, year ) - os.date("%U", _lTime)
			elseif year == bigYear then
				diffWeeks = diffWeeks + os.date("%U", _rTime)
			else
				diffWeeks = diffWeeks + Timer.getYearWeeks( nil, year )
			end
		end
		return diffWeeks
	end
end

---@see 判断2个时间是否在指定时间的分区内属于同一天
function Timer.isDiffDayByHour( lastTime, Hour )
	local nowTime = Timer.fixCrossDayTime()
	lastTime = Timer.fixCrossDayTime(lastTime)

	if nowTime.year == lastTime.year and nowTime.month == lastTime.month then
		if nowTime.day == lastTime.day then
			return not ( ( ( nowTime.hour - Hour ) * ( lastTime.hour - Hour ) ) > 0 )
		elseif math.abs( nowTime.day - lastTime.day ) == 1 then
			return not ( ( ( nowTime.hour - Hour ) * ( lastTime.hour - Hour ) ) < 0 )
		end
	end
	return true
end

---@see 获取下某个时间后x天x时刻的时间点
---@param x integer 天数
---@param hour integer 小时,默认为配置的跨天小时
---@return unix时间戳
function Timer.GetTimeDayX( time, x, hour, min, sec, fixTime )
	local now = time or os.time()
	if fixTime then now = Timer.fixCrossDayTime(now, true) end
	local ti = now + 3600 * 24 * x --获取下x天
	local nexttime = os.date('*t', ti)
	hour = hour or CFG.s_Config:Get("systemDayTime") or 0
	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = hour or 0, min = min or 0, sec = sec or 0 }
	return os.time(next_day)
end


return Timer