#1
CREATE TABLE `files` (
  `name` varchar(200) NOT NULL,
  `data` text NOT NULL,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#2
CREATE TABLE `admin` (
  `id` int(11) NOT NULL auto_increment,
  `office` tinyint(3) unsigned NOT NULL,
  `admin` varchar(16) NOT NULL default '',
  `passwd` varchar(20) NOT NULL default '',
  `session` tinytext NOT NULL,
  `session_expire` int(11) NOT NULL,
  `trusted_ips` tinytext NOT NULL,
  `name` tinytext,
  `post` tinytext NOT NULL,
  `privil` text NOT NULL,
  `presets` tinytext NOT NULL,
  `regions` text NOT NULL,
  `tunes` text NOT NULL,
  `pay_mess` text NOT NULL,
  `what_in_list` tinyint(4) NOT NULL,
  `show_grp` tinyint(4) NOT NULL,
  `ext` varchar(4) NOT NULL,
  `email` tinytext NOT NULL,
  `email_grp` text NOT NULL,
  `mess` tinytext NOT NULL,
  `temp_block_grp` text NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `admin` (`admin`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#3
CREATE TABLE `admin_session` (
  `act` tinyint(3) unsigned NOT NULL,
  `salt` tinytext NOT NULL,
  `admin_id` mediumint(8) unsigned NOT NULL,
  `time_expire` int(11) unsigned NOT NULL,
  `system_id` tinytext NOT NULL,
  KEY `act` (`act`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#4
CREATE TABLE `arch_trafnames` (
  `preset` smallint(5) unsigned NOT NULL,
  `mon` tinyint(3) unsigned NOT NULL,
  `year` smallint(5) unsigned NOT NULL,
  `traf1` tinytext NOT NULL,
  `traf2` tinytext NOT NULL,
  `traf3` tinytext NOT NULL,
  `traf4` tinytext NOT NULL,
  `traf5` tinytext NOT NULL,
  `traf6` tinytext NOT NULL,
  `traf7` tinytext NOT NULL,
  `traf8` tinytext NOT NULL,
  UNIQUE KEY `preset` (`preset`,`mon`,`year`),
  KEY `date` (`mon`,`year`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#5
CREATE TABLE `arch_users` (
  `mon` tinyint(3) unsigned NOT NULL,
  `year` smallint(5) unsigned NOT NULL,
  `uid` int(10) unsigned NOT NULL,
  `uip` varchar(15) character set latin1 collate latin1_bin NOT NULL,
  `grp` tinyint(3) unsigned NOT NULL default '0',
  `paket` smallint(5) unsigned NOT NULL,
  `preset` smallint(6) NOT NULL,
  `auth` tinyint(3) unsigned NOT NULL default '0',
  `no_submoney` tinyint(3) unsigned NOT NULL default '0',
  `pay` tinyint(4) NOT NULL,
  KEY `usr_id` (`uid`),
  KEY `date` (`mon`,`year`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#6
CREATE TABLE `badlogin` (
  `time` int(10) unsigned NOT NULL default '0',
  `times` smallint(5) unsigned NOT NULL default '0',
  `ip` varchar(15) NOT NULL default '',
  KEY `time` (`time`),
  KEY `ip` (`ip`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#7
CREATE TABLE `cable` (
  `id` int(11) NOT NULL auto_increment,
  `type` tinyint(4) NOT NULL default '0',
  `green` int(11) NOT NULL default '0',
  `blue` int(11) NOT NULL default '0',
  `comment` tinytext NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#8
CREATE TABLE `cards` (
  `cid` int(10) unsigned NOT NULL auto_increment,
  `cod` tinytext NOT NULL,
  `money` float(6,2) NOT NULL default '0.00',
  `stime` int(11) NOT NULL default '0',
  `etime` int(11) NOT NULL default '0',
  `atime` int(11) NOT NULL default '0',
  `admin` mediumint(8) unsigned default NULL,
  `alive` tinytext NOT NULL,
  `rand_id` bigint(20) unsigned NOT NULL,
  `admin_sell` mediumint(8) unsigned NOT NULL,
  `time_sell` int(10) unsigned NOT NULL,
  `id_sell` int(10) unsigned NOT NULL,
  `r` mediumint(9) NOT NULL default '0',
  PRIMARY KEY  (`cid`),
  KEY `r` (`r`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#9
CREATE TABLE `changes` (
  `id` int(11) NOT NULL auto_increment,
  `tbl` char(16) NOT NULL,
  `act` tinyint(3) unsigned NOT NULL default '0',
  `time` int(10) unsigned NOT NULL default '0',
  `fid` int(10) unsigned NOT NULL default '0',
  `param_hash` binary(22) NOT NULL,
  `adm` mediumint(9) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `tbl` (`tbl`,`act`,`fid`),
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#10
CREATE TABLE `config` (
  `id` int(11) NOT NULL auto_increment,
  `time` int(11) NOT NULL default '0',
  `data` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#11
CREATE TABLE `conf_sat` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `time` int(11) NOT NULL,
  `login` tinytext NOT NULL,
  `name` tinytext NOT NULL,
  `comment` tinytext NOT NULL,
  `config` text NOT NULL,
  `Passwd_Key` tinytext NOT NULL,
  `version` float NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#12
CREATE TABLE `c_contacts` (
  `id` int(11) NOT NULL auto_increment,
  `grp` int(11) NOT NULL default '0',
  `name_contact` tinytext NOT NULL,
  `contact` text NOT NULL,
  `admin` varchar(128) NOT NULL default '',
  `id_admin` smallint(5) unsigned NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#13
CREATE TABLE `c_grps` (
  `grp` int(11) NOT NULL auto_increment,
  `name_grp` varchar(80) NOT NULL default '0',
  `office` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY  (`grp`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#14
CREATE TABLE `dblogin` (
  `id` bigint(10) unsigned NOT NULL auto_increment,
  `mid` mediumint(9) NOT NULL default '0',
  `act` tinyint(4) NOT NULL default '0',
  `time` int(11) default NULL,
  PRIMARY KEY  (`id`),
  KEY `mid` (`mid`),
  KEY `time` (`time`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#15
CREATE TABLE `dopfields` (
  `id` smallint(8) unsigned NOT NULL auto_increment,
  `template_num` tinyint(3) unsigned NOT NULL,
  `parent_type` smallint(5) unsigned NOT NULL,
  `field_type` tinyint(3) unsigned NOT NULL,
  `field_name` tinytext NOT NULL,
  `field_alias` tinytext NOT NULL,
  `field_flags` tinytext NOT NULL,
  `field_template` tinytext NOT NULL,
  `comment` tinytext NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `parent_type` (`parent_type`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#16
CREATE TABLE `dopvalues` (
  `line_id` int(10) unsigned NOT NULL auto_increment,
  `parent_id` int(10) unsigned NOT NULL,
  `dopfield_id` smallint(5) unsigned NOT NULL,
  `field_value` text NOT NULL,
  `admin_id` smallint(5) unsigned NOT NULL,
  `time` int(10) unsigned NOT NULL,
  `revision` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`line_id`),
  KEY `parent_id` (`parent_id`),
  KEY `revision` (`revision`),
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#17
CREATE TABLE `eq_list` (
  `id` int(11) NOT NULL auto_increment,
  `eq_type` mediumint(9) NOT NULL,
  KEY `id` (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#18
CREATE TABLE `j_workers` (
  `worker` smallint(5) unsigned NOT NULL auto_increment,
  `name_worker` varchar(200) NOT NULL,
  `office` tinyint(3) unsigned NOT NULL,
  `post` tinytext NOT NULL,
  `contacts` tinytext NOT NULL,
  `state` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`worker`),
  UNIQUE KEY `name_worker` (`name_worker`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#19
CREATE TABLE `login` (
  `mid` mediumint(9) NOT NULL default '0',
  `act` tinyint(4) NOT NULL default '0',
  `time` int(11) default NULL,
  KEY `mid` (`mid`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251;

#20
CREATE TABLE `login_last` (
 `id` int(11),
 `ip` tinytext,
 `time` int(11)
);

#21
CREATE TABLE `nets` (
  `id` int(11) NOT NULL auto_increment,
  `preset` smallint(6) NOT NULL,
  `priority` int(11) NOT NULL,
  `class` tinyint(4) NOT NULL,
  `net` tinytext NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `comment` tinytext NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#22
CREATE TABLE `newuser_opt` (
  `id` mediumint(9) NOT NULL auto_increment,
  `opt_name` tinytext NOT NULL,
  `opt_comment` tinytext NOT NULL,
  `opt_time` int(10) unsigned NOT NULL,
  `opt_action` tinyint(3) unsigned NOT NULL,
  `pay_reason` tinytext NOT NULL,
  `pay_comment` tinytext NOT NULL,
  `pay_sum` float NOT NULL default '0',
  `opt_enabled` tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#23
CREATE TABLE `offices` (
  `of_id` mediumint(8) unsigned NOT NULL auto_increment,
  `of_name` tinytext NOT NULL,
  KEY `of_id` (`of_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#24
CREATE TABLE `pays` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `mid` mediumint(9) NOT NULL default '0',
  `cash` float(8,2) NOT NULL default '0.00',
  `time` int(11) NOT NULL,
  `admin_id` smallint(6) NOT NULL,
  `admin_ip` int(11) unsigned NOT NULL,
  `office` tinyint(3) unsigned NOT NULL,
  `bonus` char(1) NOT NULL default '',
  `reason` text NOT NULL,
  `coment` text NOT NULL,
  `type` tinyint(3) unsigned NOT NULL,
  `category` smallint(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `mid` (`mid`),
  KEY `time` (`time`),
  KEY `bonus` (`bonus`),
  KEY `type` (`type`),
  KEY `category` (`category`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#25
CREATE TABLE `pays_opt` (
  `opt_id` mediumint(8) unsigned NOT NULL auto_increment,
  `opt_name` tinytext NOT NULL,
  `opt_pay` float NOT NULL default '0',
  `opt_time` int(11) NOT NULL,
  `opt_descr` text NOT NULL,
  `trf_class` tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (`opt_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#26
CREATE TABLE `plans2` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `name` tinytext NOT NULL,
  `mb1` int(11) NOT NULL default '0',
  `mb2` int(11) NOT NULL default '0',
  `mb3` int(11) NOT NULL default '0',
  `mb4` int(11) NOT NULL default '0',
  `price` float NOT NULL default '0',
  `maxpriceover` float NOT NULL default '0',
  `priceover1` float NOT NULL default '0',
  `priceover2` float NOT NULL default '0',
  `priceover3` float NOT NULL default '0',
  `priceover4` float NOT NULL default '0',
  `price_change` float NOT NULL default '0',
  `in_or_out1` tinyint(2) NOT NULL default '0',
  `in_or_out2` tinyint(4) NOT NULL default '0',
  `in_or_out3` tinyint(4) NOT NULL default '0',
  `in_or_out4` tinyint(4) NOT NULL default '0',
  `m2_to_m1` float NOT NULL default '0',
  `start_hour` tinyint(4) NOT NULL default '0',
  `end_hour` tinyint(4) NOT NULL default '0',
  `k` float NOT NULL default '0',
  `flags` varchar(20) NOT NULL,
  `speed` int(11) NOT NULL default '0',
  `speed_out` int(11) NOT NULL default '0',
  `speed2` int(11) NOT NULL default '0',
  `preset` smallint(6) unsigned NOT NULL default '0',
  `newuser_opt` mediumint(8) unsigned NOT NULL,
  `script` text NOT NULL,
  `offices` text NOT NULL,
  `usr_grp` text NOT NULL,
  `pays_opt` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1;

#27
CREATE TABLE `plans3` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` tinytext NOT NULL,
  `price` float NOT NULL default '0',
  `price_change` float NOT NULL default '0',
  `descr` text NOT NULL,
  `usr_grp` text NOT NULL,
  `usr_grp_ask` text NOT NULL,
  `newuser_opt` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#28
CREATE TABLE `points` (
  `id` int(11) NOT NULL auto_increment,
  `street` int(11) NOT NULL default '0',
  `house` int(11) NOT NULL default '0',
  `block` varchar(4) NOT NULL default '',
  `pod` varchar(5) NOT NULL default '0',
  `cod_pod` int(11) NOT NULL default '0',
  `connected` tinytext NOT NULL,
  `netprotects` tinytext NOT NULL,
  `kl4` tinytext NOT NULL,
  `power` tinytext NOT NULL,
  `box` int(11) NOT NULL default '0',
  `port_rezerv` tinyint(4) NOT NULL default '0',
  `unknown_ports` tinyint(4) NOT NULL default '0',
  `net` varchar(15) NOT NULL,
  `comment` tinytext NOT NULL,
  `map` tinyint(4) NOT NULL default '0',
  `x` mediumint(9) NOT NULL default '0',
  `y` mediumint(9) NOT NULL default '0',
  `best_ping` mediumint(9) NOT NULL default '0',
  `worst_ping` mediumint(9) NOT NULL default '0',
  `lost` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#29
CREATE TABLE `p_eqtype` (
  `type` int(10) unsigned NOT NULL auto_increment,
  `name_equip` tinytext NOT NULL,
  `pattern` text NOT NULL,
  PRIMARY KEY  (`type`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#30
CREATE TABLE `p_equip` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `uid` int(11) NOT NULL default '0',
  `uid_type` tinyint(4) NOT NULL,
  `type` int(11) NOT NULL default '0',
  `eq_state` tinyint(4) NOT NULL,
  `equipment` tinytext NOT NULL,
  `time` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#31
CREATE TABLE `p_graf` (
  `gid` int(11) unsigned NOT NULL auto_increment,
  `point` int(11) NOT NULL,
  `map` mediumint(8) unsigned NOT NULL,
  `x` int(11) NOT NULL,
  `y` int(11) NOT NULL,
  KEY `gid` (`gid`),
  KEY `map` (`map`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#32
CREATE TABLE `p_street` (
  `street` int(11) NOT NULL auto_increment,
  `name_street` tinytext NOT NULL,
  `region` mediumint(9) NOT NULL,
  KEY `street` (`street`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#33
CREATE TABLE `p_supplier` (
  `supplier` int(11) NOT NULL auto_increment,
  `name_supplier` tinytext NOT NULL,
  `comment` tinytext NOT NULL,
  PRIMARY KEY  (`supplier`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#34
CREATE TABLE `p_switch` (
  `switch` int(11) NOT NULL default '0',
  `box` int(11) NOT NULL default '0',
  `all_ports` tinyint(4) NOT NULL default '0',
  `bad_ports` tinyint(4) NOT NULL default '0',
  `name` tinytext NOT NULL,
  `supplier` int(11) NOT NULL default '0',
  `date` int(11) NOT NULL default '0'
) ENGINE=MyISAM DEFAULT CHARSET=cp1251

#35
CREATE TABLE `sat_log` (
  `time` int(10) unsigned NOT NULL,
  `mod_id` tinyint(3) unsigned NOT NULL,
  `sat_id` mediumint(8) unsigned NOT NULL,
  `error` tinyint(3) unsigned NOT NULL,
  `info` text NOT NULL,
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251

#36
CREATE TABLE `traf_info` (
  `time` int(10) unsigned NOT NULL,
  `cod` mediumint(8) unsigned NOT NULL,
  `data1` text NOT NULL,
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251

#37
CREATE TABLE `traf_lost` (
  `mid` mediumint(9) NOT NULL default '0',
  `time` int(11) NOT NULL default '0',
  `in` int(10) unsigned NOT NULL default '0',
  `out` int(10) unsigned NOT NULL default '0',
  `ip` tinytext NOT NULL,
  KEY `mid` (`mid`),
  KEY `time` (`time`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251

#38
CREATE TABLE `traf_oldnames` (
  `id` int(11) NOT NULL auto_increment,
  `month` tinyint(4) NOT NULL default '0',
  `year` int(11) NOT NULL default '0',
  `name_cls1` tinytext NOT NULL,
  `name_cls2` tinytext NOT NULL,
  `name_cls3` tinytext NOT NULL,
  `name_cls4` tinytext NOT NULL,
  `name_cls5` tinytext NOT NULL,
  `name_cls6` tinytext NOT NULL,
  `name_cls7` tinytext NOT NULL,
  `name_cls8` tinytext NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `month` (`month`,`year`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#39
CREATE TABLE `users` (
  `id` int(11) NOT NULL auto_increment,
  `ip` tinytext NOT NULL,
  `name` varchar(64) NOT NULL,
  `passwd` tinytext NOT NULL,
  `grp` tinyint(4) unsigned NOT NULL default '0',
  `mid` int(10) unsigned NOT NULL default '0',
  `contract` tinytext NOT NULL,
  `contract_date` int(10) unsigned NOT NULL,
  `state` char(3) NOT NULL default '',
  `auth` enum('no','on','ong','off','0','1','2','3','4','5','6','7','8','9') NOT NULL,
  `balance` float(10,2) NOT NULL default '0.00',
  `money` float(6,2) NOT NULL default '0.00',
  `limit_balance` float(6,2) NOT NULL default '0.00',
  `block_if_limit` tinyint(4) NOT NULL default '0',
  `sortip` int(11) NOT NULL default '0',
  `modify_time` int(11) NOT NULL default '0',
  `fio` tinytext NOT NULL,
  `adress` tinytext NOT NULL,
  `street` int(11) NOT NULL default '0',
  `house` varchar(6) NOT NULL default '',
  `room` smallint(5) unsigned NOT NULL default '0',
  `floor` tinyint(4) NOT NULL,
  `telefon` tinytext NOT NULL,
  `srvs` int(11) unsigned NOT NULL default '0',
  `dop_param` tinytext NOT NULL,
  `paket` smallint(5) unsigned NOT NULL default '1',
  `next_paket` smallint(5) unsigned NOT NULL default '0',
  `paket3` smallint(5) unsigned NOT NULL default '0',
  `next_paket3` smallint(5) unsigned NOT NULL,
  `start_day` tinyint(4) NOT NULL default '0',
  `discount` tinyint(4) NOT NULL default '0',
  `hops` mediumint(9) NOT NULL default '0',
  `cstate` int(11) NOT NULL default '0',
  `cstate_time` int(10) unsigned NOT NULL,
  `comment` text NOT NULL,
  `lstate` tinyint(4) NOT NULL default '0',
  `detail_traf` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `sortip` (`sortip`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#40
CREATE TABLE `users_trf` (
  `uid` int(11) unsigned NOT NULL,
  `uip` varchar(15) character set latin1 collate latin1_bin NOT NULL,
  `now_on` tinyint(3) unsigned NOT NULL default '0',
  `mon` tinyint(3) unsigned NOT NULL default '0',
  `submoney` float NOT NULL,
  `startmoney` float NOT NULL,
  `packet` smallint(5) unsigned NOT NULL,
  `in1` bigint(20) NOT NULL default '0',
  `out1` bigint(20) NOT NULL default '0',
  `in2` bigint(20) NOT NULL default '0',
  `out2` bigint(20) NOT NULL default '0',
  `in3` bigint(20) NOT NULL default '0',
  `out3` bigint(20) NOT NULL default '0',
  `in4` bigint(20) NOT NULL default '0',
  `out4` bigint(20) NOT NULL default '0',
  `in5` bigint(20) NOT NULL default '0',
  `out5` bigint(20) NOT NULL default '0',
  `in6` bigint(20) NOT NULL default '0',
  `out6` bigint(20) NOT NULL default '0',
  `in7` bigint(20) NOT NULL default '0',
  `out7` bigint(20) NOT NULL default '0',
  `in8` bigint(20) NOT NULL default '0',
  `out8` bigint(20) NOT NULL default '0',
  `options` text character set latin1 collate latin1_bin NOT NULL,
  `traf1` bigint(20) NOT NULL,
  `traf2` bigint(20) NOT NULL,
  `traf3` bigint(20) NOT NULL,
  `traf4` bigint(20) NOT NULL,
  `mess_time` int(11) unsigned NOT NULL,
  `test` tinyint(4) NOT NULL,
  UNIQUE KEY `uid` (`uid`),
  KEY `test` (`test`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251

#41
CREATE TABLE `user_grp` (
  `grp_id` mediumint(9) NOT NULL auto_increment,
  `grp_name` tinytext NOT NULL,
  `grp_property` tinytext NOT NULL,
  `grp_admins` text NOT NULL,
  `grp_admins2` text NOT NULL,
  `grp_maxflow` int(11) NOT NULL,
  `grp_maxregflow` int(11) NOT NULL,
  `grp_admin_email` tinytext NOT NULL,
  `grp_nets` text NOT NULL,
  `grp_blank_mess` tinytext NOT NULL,
  `grp_adm_contacts` text NOT NULL,
  `grp_block_limit` float NOT NULL,
  PRIMARY KEY  (`grp_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#42
CREATE TABLE `user_grppack` (
  `id` smallint(6) NOT NULL auto_increment,
  `pack_name` tinytext NOT NULL,
  `pack_grps` tinytext NOT NULL,
  `rand_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#43
CREATE TABLE `user_select` (
  `id` int(11) NOT NULL auto_increment,
  `ip` tinytext NOT NULL,
  `name` varchar(64) NOT NULL,
  `grp` tinyint(4) unsigned NOT NULL default '0',
  `mid` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `grp` (`grp`)
) ENGINE=MyISAM DEFAULT CHARSET=cp1251 AUTO_INCREMENT=1

#50
DROP VIEW IF EXISTS dopdata

#51
CREATE ALGORITHM=MERGE VIEW dopdata AS SELECT * FROM dopfields f 
  LEFT JOIN dopvalues v ON f.id=v.dopfield_id

#52
#perl
my $sth=&sql("SELECT of_id FROM offices WHERE of_id=1");
if( $sth->execute )
{ 
   ($sth->fetchrow_hashref) or &sql_do("INSERT INTO `offices` (`of_id`, `of_name`) VALUES (1, 'Офис')");
}

#53
#perl
my $sth=&sql("SELECT * FROM dopfields WHERE field_alias IN ('_speed_in','_speed_out','_open_ports') AND parent_type=0");
if ($sth->execute)
{ 
   ($sth->fetchrow_hashref) or
   &sql_do("INSERT INTO `dopfields` (`template_num`, `parent_type`, `field_type`, `field_name`, `field_alias`, `field_flags`, `field_template`, `comment`) VALUES ".
     "(1, 0, 1, '[1]Входящая скорость', '_speed_in', '', '^.{1,6}\$', 'кбайт/сек. 0 - устанавливается скорость по умолчанию'), ".
     "(1, 0, 1, '[2]Исходящая скорость', '_speed_out', '', '^.{1,6}\$', 'кбайт/сек. 0 - устанавливается скорость по умолчанию'), ".
     "(1, 0, 6, '[5]Открыть tcp порт 25', '_open_ports', '', '', ''), ".
     "(1, 0, 4, '[10]Мак-адрес', '_mac', 'abcef', '', '')");
}

#54
DROP TRIGGER IF EXISTS tr_users

#55
CREATE  
     TRIGGER tr_users AFTER UPDATE ON users  
     FOR EACH ROW
BEGIN  
  IF ( NEW.mid = 0 ) THEN
     IF ( OLD.paket3 <> NEW.paket3 )
     THEN
        IF ( ( SELECT id FROM pays WHERE mid=NEW.id AND category=433) IS NULL ) THEN
             INSERT pays SET mid=NEW.id,category=433;
        END IF;          
        UPDATE pays SET reason=CONCAT(unix_timestamp(),':',NEW.paket3,'\n',reason),time=unix_timestamp(),type=50
           WHERE mid=NEW.id AND category=433;
     END IF;

     IF ( OLD.paket <> NEW.paket )
     THEN
        IF ( ( SELECT id FROM pays WHERE mid=NEW.id AND category=432) IS NULL ) THEN
             INSERT pays SET mid=NEW.id,category=432;
        END IF;          
        UPDATE pays SET reason=CONCAT(unix_timestamp(),':',NEW.paket,'\n',reason),time=unix_timestamp(),type=50
           WHERE mid=NEW.id AND category=432;
     END IF;
  END IF;
END

#56
ALTER TABLE `users` DROP `dop_param`

#57
DROP VIEW IF EXISTS fullusers

#58
CREATE ALGORITHM=MERGE VIEW fullusers AS SELECT u.*,p.name_street,t.* FROM users u
  LEFT JOIN p_street p ON p.street=u.street LEFT JOIN users_trf t ON u.id=t.uid

#59
ALTER TABLE `admin_session` CHANGE `system_id` `system_id` TEXT
  CHARACTER SET cp1251 COLLATE cp1251_general_ci NOT NULL

#60
#perl
my ($sth,$p,$revision,$sql,$i,$id,$h);
my @adr=();
$i=0;
foreach $h (
   "(2,0,8,'[02]Улица','p_street:street:name_street','a')",
   "(2,0,1,'[03]Дом','_adr_house','a')",
   "(2,0,1,'[06]Этаж','_adr_floor','a')",
   "(2,0,1,'[07]Квартира','_adr_room','a')",
   "(2,0,4,'[10]Телефон','_adr_telefon','abc')",
   "(2,0,5,'[11]Комментарий','_adr_comment','abc')",
   "(2,0,4,'[04]Блок','_adr_block','abc')",
   "(2,0,1,'[05]Подъезд', '_adr_front_door','a')"
)
{
  $sql="INSERT INTO dopfields (template_num,parent_type,field_type,field_name,field_alias,field_flags) VALUES $h";
  &Log("[SQL] $sql\n");
  $sth=$dbh->prepare($sql);
  $sth->execute;
  $adr[$i]=$sth->{mysql_insertid} || $sth->{insertid};
  &Log("[SQL] insert_id = $adr[$i]\n");
  $i++;
}

$sth=&sql("SELECT * FROM users");
if( $sth->execute )
{ 
   while( $p=$sth->fetchrow_hashref )
   {
       $id=$p->{id};
       # сформируем номер ревизии
       $i=$dbh->prepare("INSERT INTO dopvalues SET parent_id=0");
       $i->execute;
       $revision=$i->{mysql_insertid} || $i->{insertid};
       if( !$revision )
       {
          &Log("Error getting revision!\n");
          next;
       }
       $i=0;
       $sql='';
       foreach (
          'street',
          'house',
          'floor',
          'room',
          'telefon',
          'adress'
       )
       {
          $adr[$i] or next;
          $h=$p->{$_};
          if( $i==1 )
          {  # дом
             if( $h=~s/^(\d+)([^\d].*)$/$1/ )
             {
                $i=$2; # блок
                $i=~s/^[ :`'"\-\|\/\\]//;
                $sql.="(0,$id,$adr[6],'$i',0,$revision)," if $adr[6];
                $i=1;
             }
             $h=int $h;
          }
          $h=~s|\\|\\\\|g;
          $h=~s|'|\\'|g;
          $sql.="(0,$id,$adr[$i],'$h',0,$revision),";
       }continue
       {
          $i++;
       }
       $sql=~s|,$|| or next;
       &sql_do("INSERT INTO dopvalues (admin_id,parent_id,dopfield_id,field_value,time,revision) VALUES $sql");
   }
   &sql_do("DELETE FROM dopvalues WHERE parent_id=0");
}

#61
ALTER TABLE `users` DROP `adress`

#62
ALTER TABLE `users` DROP `street`

#63
ALTER TABLE `users` DROP `house`

#64
ALTER TABLE `users` DROP `room`

#65
ALTER TABLE `users` DROP `floor`

#66
ALTER TABLE `users` DROP `telefon`

#67
DROP VIEW IF EXISTS fullusers

#68
CREATE ALGORITHM=MERGE VIEW fullusers AS SELECT u.*,t.* FROM users u LEFT JOIN users_trf t ON u.id=t.uid

#69
CREATE ALGORITHM=TEMPTABLE VIEW rev_equip AS SELECT parent_id AS id,template_num, MAX(revision) AS rev FROM dopdata WHERE parent_type=1 GROUP BY parent_id

#70
CREATE ALGORITHM=TEMPTABLE VIEW rev_users AS SELECT parent_id AS id,template_num, MAX(revision) AS rev FROM dopdata WHERE parent_type=0 GROUP BY parent_id,template_num

#71
ALTER TABLE `dopvalues` DROP INDEX `time`

#72
DROP VIEW IF EXISTS `rev_users`

#73
CREATE ALGORITHM=TEMPTABLE VIEW rev_users AS 
  SELECT parent_id AS id, template_num, MAX(revision) AS rev FROM dopdata WHERE parent_type=0 AND
  parent_id IN (SELECT id FROM users) GROUP BY parent_id,template_num

#74
ALTER TABLE `plans2` ADD `descr` TEXT NOT NULL

#75
ALTER TABLE `admin` DROP `what_in_list`

#76
ALTER TABLE `admin` DROP `trusted_ips`

#77
ALTER TABLE `admin` DROP `presets`

#78
ALTER TABLE `admin` DROP `show_grp`  

#79
ALTER TABLE `admin` CHANGE `name` `name` TINYTEXT CHARACTER SET cp1251 COLLATE cp1251_general_ci NOT NULL

#80
DROP VIEW IF EXISTS rev_users

#81
CREATE ALGORITHM=TEMPTABLE VIEW rev_users AS
  SELECT parent_id AS id, template_num, MAX(revision) AS rev FROM dopdata d
  INNER JOIN users u on d.parent_id=u.id
  WHERE parent_type=0 GROUP BY parent_id,template_num

#82
#perl
my $sth=&sql("SELECT COUNT(*) AS n FROM nets");
($sth->execute) && (my $p=$sth->fetchrow_hashref) && ($p->{n}==0) && &sql_do("INSERT INTO nets SET preset=0,priority=0,net='',port=0,class=1,comment='интернет'");
#83
ALTER TABLE `users_trf` ADD UNIQUE (`uid`)

#84
ALTER TABLE `admin_session` CHANGE `salt` `salt` VARCHAR(200) NOT NULL 

#85
ALTER TABLE `admin_session` ADD UNIQUE (`salt`)

#86
ALTER TABLE `dopfields` CHANGE `field_alias` `field_alias` VARCHAR(100) NOT NULL 

#87
ALTER TABLE `dopfields` ADD UNIQUE (`field_alias`)

#88
DELETE FROM dopvalues WHERE revision NOT IN (SELECT rev FROM rev_users) AND revision NOT IN (SELECT rev FROM rev_equip)

#89
ALTER TABLE dopvalues DROP revision, DROP time, DROP admin_id, DROP line_id

#90
ALTER TABLE dopvalues ADD UNIQUE (parent_id,dopfield_id)

#88
ALTER TABLE dopvalues ENGINE = InnoDB

#89
DROP VIEW IF EXISTS dopdata

#90
CREATE ALGORITHM=MERGE VIEW dopdata AS SELECT * FROM dopfields f LEFT JOIN dopvalues v ON f.id=v.dopfield_id

#91
CREATE TABLE IF NOT EXISTS dop_oldvalues (
  `line_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) NOT NULL,
  `dopfield_id` smallint(5) unsigned NOT NULL,
  `field_value` text NOT NULL,
  `admin_id` smallint(5) unsigned NOT NULL,
  `time` int(10) unsigned NOT NULL,
  `revision` int(10) unsigned NOT NULL,
  PRIMARY KEY (`line_id`),
  KEY `parent_id` (`parent_id`),
  KEY `revision` (`revision`)
) ENGINE=InnoDB AUTO_INCREMENT=1

#92
DROP PROCEDURE IF EXISTS set_dopvalues

#93
CREATE PROCEDURE set_dopvalues (IN rev INT)
BEGIN
  DECLARE p_id INT;
  DECLARE d_id INT;
  DECLARE n INT;

  SELECT parent_id,dopfield_id INTO p_id,d_id FROM dop_oldvalues WHERE revision=rev LIMIT 1;

  START TRANSACTION;

  DELETE FROM dopvalues WHERE parent_id=p_id AND dopfield_id IN
    (SELECT dopfield_id FROM dop_oldvalues WHERE revision=rev);

  SELECT COUNT(*),dopfield_id INTO n,d_id FROM dopvalues WHERE field_value<>'' AND
    CONCAT(dopfield_id,'~',field_value) IN 
    (SELECT CONCAT(dopfield_id,'~',field_value) FROM dop_oldvalues WHERE revision=rev AND dopfield_id IN
       (SELECT id FROM dopfields WHERE field_flags LIKE '%h%')) GROUP BY dopfield_id;
  
  IF( n>0 ) THEN
    ROLLBACK;
    SELECT 1 AS error, d_id AS descr;
  ELSE
    INSERT INTO dopvalues (parent_id,dopfield_id,field_value)
          SELECT parent_id,dopfield_id,field_value FROM dop_oldvalues WHERE revision=rev;
    COMMIT;
    SELECT 0 AS error, '' AS descr;
  END IF;
END

#94
DROP VIEW IF EXISTS rev_users

#95
DROP VIEW IF EXISTS rev_equip

#96
GRANT SELECT , INSERT , UPDATE , DELETE , EXECUTE ON `bill`.* TO 'bill_www'@'localhost'
