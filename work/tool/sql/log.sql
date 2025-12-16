CREATE TABLE IF NOT EXISTS `t_login_log` (
  `l_id` int(11) NOT NULL auto_increment,
  `l_gameid` varchar(20) NOT NULL default '',
  `l_serid` varchar(20) NOT NULL default '',  
  `l_iggid` varchar(20) NOT NULL default '',
  `l_type` tinyint(3) NOT NULL default '0',
  `l_ip` varchar(39) NOT NULL default '',
  `l_mac` varchar(17) NOT NULL default '',
  `l_time` datetime NOT NULL default CURRENT_TIMESTAMP,
  `l_online_time` int NOT NULL DEFAULT 0,
  PRIMARY KEY  (`l_id`),
  KEY `l_gameid` (`l_gameid`),
  KEY `l_iggid` (`l_iggid`),
  KEY `l_time` (`l_time`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


DELIMITER //

DROP PROCEDURE IF EXISTS `sp_add_game_login_log`//
CREATE PROCEDURE `sp_add_game_login_log`(IN in_gameid VARCHAR(20), IN in_serverid VARCHAR(20), IN in_iggid VARCHAR(20), IN in_loginip VARCHAR(39), IN in_loginmac VARCHAR(17), IN in_logintime DATETIME)
BEGIN
	SET @gameid = in_gameid;
    SET @serid = in_serverid;
	SET @iggid = in_iggid;
	SET @loginip = in_loginip;
	SET @loginmac = in_loginmac;
	SET @logintime = in_logintime;
    SET @tablesuffix = ''; -- 测试使用
	SET @sqlstr = CONCAT('INSERT INTO `t_login_log', @tablesuffix, '` (`l_gameid`, `l_serid`, `l_iggid`, `l_type`, `l_ip`, `l_mac`, `l_time`) VALUES (@gameid, @serid, @iggid, 0, @loginip, @loginmac, @logintime)');
	PREPARE stmt FROM @sqlstr;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	SELECT LAST_INSERT_ID() AS `logid`;
END//

DROP PROCEDURE IF EXISTS `sp_add_game_logout_log`//
CREATE PROCEDURE `sp_add_game_logout_log`(IN in_gameid VARCHAR(20), IN in_serverid VARCHAR(20), IN in_iggid VARCHAR(20), IN in_logoutip VARCHAR(39), IN in_logoutmac VARCHAR(17), IN in_logouttime DATETIME, IN in_online_seconds INT)
BEGIN
	SET @gameid = in_gameid;
    SET @serid = in_serverid;
	SET @iggid = in_iggid;
	SET @logoutip = in_logoutip;
	SET @logoutmac = in_logoutmac;
	SET @logouttime = in_logouttime;
    SET @online_seconds = in_online_seconds;
    SET @tablesuffix = ''; -- 测试使用
	SET @sqlstr = CONCAT('INSERT INTO `t_login_log', @tablesuffix, '` (`l_gameid`, `l_serid`, `l_iggid`, `l_type`, `l_ip`, `l_mac`, `l_time`, `l_online_time`) VALUES (@gameid, @serid, @iggid, 1, @logoutip, @logoutmac, @logouttime, @online_seconds)');
	PREPARE stmt FROM @sqlstr;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	SELECT LAST_INSERT_ID() AS `logid`;
END//

DELIMITER ;
