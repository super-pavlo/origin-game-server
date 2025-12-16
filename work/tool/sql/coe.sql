/*
Navicat MySQL Data Transfer

Source Server         : 10.0.3.117
Source Server Version : 50720
Source Host           : 10.0.3.117:3306
Source Database       : ig

Target Server Type    : MYSQL
Target Server Version : 50720
File Encoding         : 65001

Date: 2020-10-19 18:47:07
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for c_account
-- ----------------------------
DROP TABLE IF EXISTS `c_account`;
CREATE TABLE `c_account` (
  `iggid` varchar(255) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`iggid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_activity
-- ----------------------------
DROP TABLE IF EXISTS `c_activity`;
CREATE TABLE `c_activity` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_alliance_flag
-- ----------------------------
DROP TABLE IF EXISTS `c_alliance_flag`;
CREATE TABLE `c_alliance_flag` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_alliance_kill
-- ----------------------------
DROP TABLE IF EXISTS `c_alliance_kill`;
CREATE TABLE `c_alliance_kill` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_alliance_power
-- ----------------------------
DROP TABLE IF EXISTS `c_alliance_power`;
CREATE TABLE `c_alliance_power` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_chat
-- ----------------------------
DROP TABLE IF EXISTS `c_chat`;
CREATE TABLE `c_chat` (
  `gameNode` varchar(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`gameNode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_chat_guild
-- ----------------------------
DROP TABLE IF EXISTS `c_chat_guild`;
CREATE TABLE `c_chat_guild` (
  `gameNode` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`gameNode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- Table structure for c_combat_first
-- ----------------------------
DROP TABLE IF EXISTS `c_combat_first`;
CREATE TABLE `c_combat_first` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_email_content
-- ----------------------------
DROP TABLE IF EXISTS `c_email_content`;
CREATE TABLE `c_email_content` (
  `contentId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`contentId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_expedition
-- ----------------------------
DROP TABLE IF EXISTS `c_expedition`;
CREATE TABLE `c_expedition` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_expeditionShop
-- ----------------------------
DROP TABLE IF EXISTS `c_expeditionShop`;
CREATE TABLE `c_expeditionShop` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_fight_horn
-- ----------------------------
DROP TABLE IF EXISTS `c_fight_horn`;
CREATE TABLE `c_fight_horn` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_fight_horn_alliance
-- ----------------------------
DROP TABLE IF EXISTS `c_fight_horn_alliance`;
CREATE TABLE `c_fight_horn_alliance` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild
-- ----------------------------
DROP TABLE IF EXISTS `c_guild`;
CREATE TABLE `c_guild` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_abbname
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_abbname`;
CREATE TABLE `c_guild_abbname` (
  `abbname` varchar(255) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`abbname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_building
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_building`;
CREATE TABLE `c_guild_building` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_gift
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_gift`;
CREATE TABLE `c_guild_gift` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_message_board
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_message_board`;
CREATE TABLE `c_guild_message_board` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_name
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_name`;
CREATE TABLE `c_guild_name` (
  `name` varchar(255) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_resource_help
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_resource_help`;
CREATE TABLE `c_guild_resource_help` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_role_build
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_role_build`;
CREATE TABLE `c_guild_role_build` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_role_donate
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_role_donate`;
CREATE TABLE `c_guild_role_donate` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_role_help
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_role_help`;
CREATE TABLE `c_guild_role_help` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_role_kill
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_role_kill`;
CREATE TABLE `c_guild_role_kill` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_role_power
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_role_power`;
CREATE TABLE `c_guild_role_power` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_guild_shop
-- ----------------------------
DROP TABLE IF EXISTS `c_guild_shop`;
CREATE TABLE `c_guild_shop` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_hallActivity
-- ----------------------------
DROP TABLE IF EXISTS `c_hallActivity`;
CREATE TABLE `c_hallActivity` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_hell_activity_rank
-- ----------------------------
DROP TABLE IF EXISTS `c_hell_activity_rank`;
CREATE TABLE `c_hell_activity_rank` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_holy_land
-- ----------------------------
DROP TABLE IF EXISTS `c_holy_land`;
CREATE TABLE `c_holy_land` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_kill_type
-- ----------------------------
DROP TABLE IF EXISTS `c_kill_type`;
CREATE TABLE `c_kill_type` (
  `id` varchar(255) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_kill_type_history
-- ----------------------------
DROP TABLE IF EXISTS `c_kill_type_history`;
CREATE TABLE `c_kill_type_history` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_king
-- ----------------------------
DROP TABLE IF EXISTS `c_king`;
CREATE TABLE `c_king` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_map_object
-- ----------------------------
DROP TABLE IF EXISTS `c_map_object`;
CREATE TABLE `c_map_object` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_monument
-- ----------------------------
DROP TABLE IF EXISTS `c_monument`;
CREATE TABLE `c_monument` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_pkid
-- ----------------------------
DROP TABLE IF EXISTS `c_pkid`;
CREATE TABLE `c_pkid` (
  `id` varchar(255) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_recharge
-- ----------------------------
DROP TABLE IF EXISTS `c_recharge`;
CREATE TABLE `c_recharge` (
  `id` varchar(60) NOT NULL,
  `value` mediumblob,
  `json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_recommend
-- ----------------------------
DROP TABLE IF EXISTS `c_recommend`;
CREATE TABLE `c_recommend` (
  `node` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`node`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- Table structure for c_refresh
-- ----------------------------
DROP TABLE IF EXISTS `c_refresh`;
CREATE TABLE `c_refresh` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_reserve
-- ----------------------------
DROP TABLE IF EXISTS `c_reserve`;
CREATE TABLE `c_reserve` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_rise_up
-- ----------------------------
DROP TABLE IF EXISTS `c_rise_up`;
CREATE TABLE `c_rise_up` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_role_collect_res
-- ----------------------------
DROP TABLE IF EXISTS `c_role_collect_res`;
CREATE TABLE `c_role_collect_res` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_role_kill
-- ----------------------------
DROP TABLE IF EXISTS `c_role_kill`;
CREATE TABLE `c_role_kill` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_role_name
-- ----------------------------
DROP TABLE IF EXISTS `c_role_name`;
CREATE TABLE `c_role_name` (
  `name` varchar(255) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_role_power
-- ----------------------------
DROP TABLE IF EXISTS `c_role_power`;
CREATE TABLE `c_role_power` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_system
-- ----------------------------
DROP TABLE IF EXISTS `c_system`;
CREATE TABLE `c_system` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_systemmail
-- ----------------------------
DROP TABLE IF EXISTS `c_systemmail`;
CREATE TABLE `c_systemmail` (
  `id` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------
-- Table structure for c_townhall
-- ----------------------------
DROP TABLE IF EXISTS `c_townhall`;
CREATE TABLE `c_townhall` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for c_tribe_king
-- ----------------------------
DROP TABLE IF EXISTS `c_tribe_king`;
CREATE TABLE `c_tribe_king` (
  `guildId` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`guildId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_army
-- ----------------------------
DROP TABLE IF EXISTS `d_army`;
CREATE TABLE `d_army` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_building
-- ----------------------------
DROP TABLE IF EXISTS `d_building`;
CREATE TABLE `d_building` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_chat
-- ----------------------------
DROP TABLE IF EXISTS `d_chat`;
CREATE TABLE `d_chat` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_email
-- ----------------------------
DROP TABLE IF EXISTS `d_email`;
CREATE TABLE `d_email` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_hero
-- ----------------------------
DROP TABLE IF EXISTS `d_hero`;
CREATE TABLE `d_hero` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_item
-- ----------------------------
DROP TABLE IF EXISTS `d_item`;
CREATE TABLE `d_item` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_role
-- ----------------------------
DROP TABLE IF EXISTS `d_role`;
CREATE TABLE `d_role` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_scouts
-- ----------------------------
DROP TABLE IF EXISTS `d_scouts`;
CREATE TABLE `d_scouts` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_task
-- ----------------------------
DROP TABLE IF EXISTS `d_task`;
CREATE TABLE `d_task` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_transport
-- ----------------------------
DROP TABLE IF EXISTS `d_transport`;
CREATE TABLE `d_transport` (
  `rid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for d_user
-- ----------------------------
DROP TABLE IF EXISTS `d_user`;
CREATE TABLE `d_user` (
  `uid` bigint(20) NOT NULL,
  `value` mediumblob NOT NULL,
  `json` json DEFAULT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
