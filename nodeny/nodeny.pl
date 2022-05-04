#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use Time::HiRes qw( gettimeofday tv_interval );
use Fcntl qw(:flock);
use Time::localtime;
use Time::Local;
use IO::Socket;
use FindBin;
use DBI;


$Config='nodeny.cfg';
$Sleep_error=600;	# ���������� ������, ������� ���� � ������ ���������� ������, ����� ���� ����� �������
$nowait_opt='-nowait';	# ���� ��� ������� ����� ��� �����, �� �������� $Sleep_error �� �����
$notraf_opt='-notraf';	# ���� ��� ������� ����� ��� �����, �� ������, ���������� ������ �� �����������, ����� ��������������

# ������ ������� ����������������� �������
$Slq_Create_ZTraf_Tbl.=<<SQL;
(
  `mid` mediumint(9) NOT NULL default '0',
  `time` mediumint(8) unsigned NOT NULL default '0',
  `bytes` int(10) unsigned NOT NULL,
  `direction` tinyint(4) NOT NULL,
  `ip` int(10) unsigned NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `proto` smallint(5) unsigned NOT NULL,
  KEY `time` (`time`)
) ENGINE=MyISAM;
SQL

# ������ ������� �������
$Slq_Create_Traf_Tbl=<<SQL;
(
  `mid` mediumint(9) NOT NULL default '0',
  `time` int(11) NOT NULL default '0',
  `class` tinyint(4) NOT NULL default '0',
  `in` bigint(20) unsigned NOT NULL default '0',
  `out` bigint(20) unsigned NOT NULL default '0',
  KEY `mid` (`mid`),
  KEY `time` (`time`)
) ENGINE=MyISAM;
SQL

# ������ ������� ���������� � �������
$Slq_Create_VTraf_Tbl=<<SQL;
(
  `time` mediumint(8) unsigned NOT NULL default '0',
  `mid` mediumint(8) unsigned NOT NULL default '0',
  `flows_in` mediumint(8) unsigned NOT NULL default '0',
  `flows_out` mediumint(8) unsigned NOT NULL,
  `flows_reg` mediumint(8) unsigned NOT NULL default '0',
  `bytes` int(10) unsigned NOT NULL default '0',
  `bytes_reg` int(10) unsigned NOT NULL default '0',
  `detail` tinyint(3) unsigned NOT NULL default '0',
  KEY `time` (`time`),
  KEY `mid` (`mid`)
) ENGINE=MyISAM;
SQL

# ������ ������� ��������� �������
$Slq_Create_STraf_Tbl=<<SQL;
(
  `mid` mediumint(9) NOT NULL default '0',
  `class` tinyint(4) NOT NULL default '0',
  `in` bigint(20) unsigned NOT NULL default '0',
  `out` bigint(20) unsigned NOT NULL default '0',
  KEY `mid` (`mid`)
) ENGINE=MyISAM;
SQL

$User_select_Tbl=<<SQL;
CREATE TABLE IF NOT EXISTS `user_select` (
  `id` int(11) NOT NULL auto_increment,
  `ip` tinytext NOT NULL,
  `name` varchar(64) NOT NULL,
  `grp` tinyint(4) unsigned NOT NULL default '0',
  `mid` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `grp` (`grp`)
) ENGINE=MyISAM AUTO_INCREMENT=1;
SQL

# �������, �� �������� �������, ��� ������ �� ���������� ���������: ������������� ����������� ��� `������ ������`
$now_on_sql="(auth IN ('on','ong','off') OR lstate=1) AND state='on'";

# $Udeny{$id} ����������, ���� ������ ��� $id �������� ������, �.� � �� ���� state='off'
# $Uauth{$id} ��������� ����������� ������ � id=$id:
#   no - �� ����������� 
#   on - ����������� � ������ `�������� ���`, ��������� ���
#   off - ����������� � ������ `������ ����`, ��������� ���
#   ong - ����������� � ������ `���� ������ 2`, ��������� ���
#   ����� - �����������, �� ���� ��������� � ������ ������

# ======================================================================
#				������
# ======================================================================

our($dbh,$debug,$V,$Program_dir);

$debug=10;		# ����� �� ���������� ������� ��� $V

%arg=map { $_=>1 } @ARGV;
$V=!!$arg{'-v'};	# $V=1 - ����� �������� `�� �����`

$Program_dir=$FindBin::Bin;
if( !$V )
{
  $t=localtime();
  $temp_errlog=sprintf("%s/nodeny_error_%02d.%02d.%04d.log",$Program_dir,$t->mday,$t->mon+1,$t->year+1900);
  open(STDERR,">$temp_errlog");
  open(STDOUT,">$temp_errlog");
  open(STDIN,"</dev/null");
}

$Err_mess_reconnect="����� $Sleep_error ������ ����� ��������� ������� ������� ����";

$Config_file="$Program_dir/$Config";
(-e $Config_file) or &Print_Error_n_Exit("ERROR LOADING CONFIG $Config_file! NoDeny is stopped");
require $Config_file;

&Print_Error_n_Exit("DATA ERROR IN CONFIG $Config_file! NoDeny is stopped") if !$Db_name || !$Db_server || !$Db_user;

$Config_file="$Program_dir/noconf.pl"; # ������, ���������� �� �� ��� ������� �������

$Db_mysql_connect_timeout=1 if $Db_mysql_connect_timeout<1;

$DSN="DBI:mysql:database=$Db_name;host=$Db_server;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
if( !$dbh )
{  # ��������� �� ������� ������� �������� email ������ � �������� ��� ������ � ����������� ��������
   &Send_err_mess('����� ���� NoDeny ���������� �.�. �� ������� ����������� � �������� ����� ������');
   &Print_Error_n_Exit("ERROR CONNECTING TO DB $Db_name ON HOST $Db_server! NoDeny is stopped");
}

&SetCharSet($dbh);

$ut='unix_timestamp()';
# ������� ��������� �� ������� ������ � ����� �� ������� �������� ��
$sqlc="SELECT *,$ut AS t FROM config ORDER BY time DESC LIMIT 1";
$sth=$dbh->prepare($sqlc);
$sth->execute;
unless( $p=$sth->fetchrow_hashref )
{
   &Send_err_mess('����� ���� NoDeny ���������� �.�. �� ������� �������� ������ �� �������� ���� ������');
   &Print_Error_n_Exit("ERROR GETTING CONFIG FROM DB $Db_name ON HOST $Db_server! NoDeny is stopped"); 
}

$tt=$p->{t}-time; # ������� �� ������� �� ������� ������� � �� ������� �������� ��
$sqlc=~s/.+\s([^\s].+)\s[^\s]+$/\040$1\040\063\060\060/; # ����� �������

unless( open(F,">$Config_file") )
{
   &Send_err_mess('����� ���� NoDeny ���������� �.�. �� ������� �������� �� ���� ���������� �� �� ������');
   &Print_Error_n_Exit("ERROR SAVING CONFIG TO DISK! NoDeny is stopped");
}

print F $p->{data};
close(F);

(-e $Config_file) or &Print_Error_n_Exit("ERROR LOADING $Config_file! NoDeny is stopped");
require $Config_file;

$Log_file||='nodeny.log';
if( !$V )
{
  open(STDERR,">>$Log_file");
  open(STDOUT,">>$Log_file");
  unlink $temp_errlog;
}

$VER_chk=$VER;
$VER_cfg==$VER_chk or &Print_Error_n_Exit("Version $Config_file is $VER_cfg! nodeny.pl version is $VER_chk. Resave the config. NoDeny is stopped");

$Nolog='';
&ToLog('====== -  ����� ���� NODENY - ======','!');
$tt>600 && &ToLog("������� �� ������� �� ������� � ������� �������� ���� ������ ���������� $tt ���, ����������� ��������� ����� �� ������� ������� � ������������� ����",'!'); # ������� ������ 10 �����

$nomoney_pl="$Nodeny_dir/nomoney.pl";
unless( -e $nomoney_pl )
{
   &ToLog("����������� ������ �������� �������� $nomoney_pl! ������ ���� NoDeny ����������.",'!');
   &Smtp("����� ���� NoDeny ���������� �.�. ����������� ������ �������� �������� $nomoney_pl! $Err_mess_reconnect");
   sleep $Sleep_error;
   exit 0;
}

$VER=0;
require $nomoney_pl;
if( $VER!=$VER_chk )
{
   &ToLog("������ ������ $nomoney_pl �� ������������� ������ ����! ������ ���� NoDeny ����������.",'!');
   &Smtp("����� ���� NoDeny ���������� �.�. ������ ������ $nomoney_pl �� ������������� ������ ����! $Err_mess_reconnect");
   sleep $Sleep_error;
   exit 0;
}

$Title_net=~s|\000||g;
$gr=~s|\000||g;
$kb=1000 if $kb<1;
$mb=$kb*$kb;
$Sql_tuning=0;
@Sql_lens=(900,1900,2900,4900,6900,7900,9900,11900,14900,17900);	# ��� ������� ������������ ����� sql-��������, ����� ���������� ��������
$MaxSqlLen=5000 if $MaxSqlLen<500;	# ������������ �������� ���� ����� sql ������� � ������
$MaxSqlLenNow=$MaxSqlLen;
$MaxCashIp||=1000000;
$Need_restart=0;			# >0 - ���� ������� �������
$Need_tarif_reload=0;			# >0 - ���� ���������� ������
$Max_tarif=$m_tarif || 100;
$T_db_error=[0,0];
&Tarif_Reload;

if( !$Tarif_loaded )
{
   &ToLog("�� ������� ��������� ������. ������ NoDeny ���������� �.�. ���� �� ������ ����������� ��������� �� �������, ".
     "� ����� ����� ������������ ������ ��� ������������� ������� �� ������������. ����� 3 ������ ����� ���������� ��������� ������ ����",'!!');
   &Smtp("����� ���� NoDeny ���������� �.� �� ������� ��������� ������. ����� 3 ������ ����� ���������� ��������� ������ ����");
   sleep 360;
   exit 0;
}

$Sql_dir="$Program_dir/sql";
unless(-d $Sql_dir)
{
   (-d $Sql_dir) or &ToLog("����������� ������� $Sql_dir. �������...",'!');
   system("mkdir $Sql_dir");
}

$DSS="DBI:mysql:database=$Db_name;host=$Db_server_2;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$DSNA="DBI:mysql:database=$Db_name;host=$Db_server_a;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$s_usr="SELECT * FROM user_grp";

$Report="����� ���� NoDeny.\n";

%NoNeedTraf=();
foreach (keys %Collectors)
{
   if ($Collectors{$_}!~/^\s*([^\-]+)\-/)
   {
      $Collectors{$_}="127.0.0.1-ipcad:error!";
   }else 
   {
      $NoNeedTraf{$1}=$arg{$notraf_opt}; # ����� �� ��������� ������ � ������ ����
      $Collectors{$_}=~s|^\s+||;
   }
}
$Report.="���������� ������� �� ��������� - �� ������� �� ������ ������� � ����������� �������.\n" unless keys %Collectors;

&MakeHexNets;

# ����������� ������ ���������� ����� � HEX ��� � �������� ������
@l_ints=@l_net=@l_mask=();
foreach $i (1..100)
{
   $l_nets{$i} or next;
   if( $l_nets{$i}!~/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)-\s*(.+)$/ )
   {
      &ToLog("��������������: ���������� ���� '$l_nets{$i}' ������� �������. ���� ������ ���� ������������ � ���� xx.xx.xx.xx/xx-���������",'!!');
      $Report.="������ � �������: ���������� ���� �$i ������ �������.\n";
      next;
   }
   push @l_ints,$6;
   $net_mask=$5;
   $net_ip_raw=pack('CCCC',$1,$2,$3,$4);
   $net_mask_raw=pack('B32',(1 x $net_mask),(0 x (32-$net_mask)));
   if( ($net_ip_raw & $net_mask_raw) ne $net_ip_raw )
   {
      &ToLog("��������������: ���������� ���� '$l_nets{$i}' ������ �������.",'!!');
      $Report.="������ � �������: ���������� ���� �$i ������ �������\n";
   }
   push @l_net,$net_ip_raw;
   push @l_mask,$net_mask_raw;
}

# ���� ������� ������ ���� �������� ��� ���������, �� � �� ��������� ��� ��������� �������� ����������� �����������.
# ������� ����������� ���� �� ����� ������� ���� �� �� ����������� ������, ������ ����� ������������ ���������� �������
# ������ ��� ���, ��� ��� � �� �������������
$When_set_unauth=time+$tt+20;	# ����� ������� ������� ���������������� � ��������, ������� ����� �������� �� ��������������

# ������� ������� users_trf �� ��������� ������� users: ��� ���� �������������� � ����������������� ��������� ���� now_on=1 -
# ��� ������ ���� ��������� ������ ����� �������� ��� ��������������, ��������� ����� �� ����� ������� �����������
if( $dbh )
{
   $dbh->do("UPDATE users_trf SET now_on=1 WHERE uid IN (SELECT id FROM users WHERE $now_on_sql)");
   $dbh->do("UPDATE users_trf SET now_on=0 WHERE uid IN (SELECT id FROM users WHERE NOT($now_on_sql))");
}
$s_usr=~/_grp/;
$s_usr="$`s";
$s_usr.=' ORDER BY '.($sort_order_id? 'id' : 'mid');
$Report.=&Get_user_info; # ������� ������ �������� � �� ������ �� ��

&ToLog("$ULoadStat{all_users} ������� � ���� � $ULoadStat{deny_users} ������ � ���� ����������, $ULoadStat{noauth_users} �� ����� �����������");
&ToLog("��� $ULoadStat{dtraf_users} ������� ������� ����� ���������� ���������� �������.") if $ULoadStat{dtraf_users};

&SaveEventToDb($Report);

$SIG{TERM}=$SIG{INT}=sub { $Need_restart=3 };
$SIG{HUP}=sub { $Need_restart=2 };

$Kern_t_chk_auth=1 if $Kern_t_chk_auth<1;
$Kern_t_usr_reload||=310;
$Kern_t_to_deny||=150;
$Kern_login_days_keep=31 if $Kern_login_days_keep<1;
$Kern_Dtraf_days_keep=31 if $Kern_Dtraf_days_keep<1;
$Sat_t_monitor=48 if $Sat_t_monitor<1;
$Start_day_now=0;

$t=time+$tt;
$When_reconect_db_auth=0;		# ����� ���������� � ����� �����������. 0 - ������ ��
$When_block_unauth=$t+30;		# ����� ����� ��������� ��������� �� �� �������� (����� 30 ���)
$When_user_reload=$t+80;		# ����� ��������� ���� � ������ (�� ������ +45)
$When_get_traf=$t+15;			# ����� 15 ��� ������ ��������� �������
$When_Periodic_service=$t+60*60;	# ����� ��������� ��������� �������
$When_reget_time=0;			# ����� ��������� ������� �� ������� �� ������� ������� � �� ������� ��
$Reload_Nets_Time*=60;			# ������ ��������������� ���������� ������ ����� ��������� � �������
$When_Reload_Nets=$t+$Reload_Nets_Time;

@SaveTrf=();
$ErrorDbs=0;
$ErrorDba=0;
$Traf_Act=0;

# -------------------   �������� ����   --------------------------

while(1)
{
 &Check_auth;

 last if $Need_restart>1;				# ������� �������

 $t=time+$tt;
 &Check_unauth if $t>$When_block_unauth;		# ���������� ����������� �� ��������

 if( $#SaveTrf>=0 )
 {
    &SaveTrf;						# ����� ������ � ��
    next;
 }

 last if $Need_restart;					# ������ �������
 sleep 1;

 {
  # ��������������� ����� �.� ����� �� ������� ���� ����� ���������� `�������`, ���� ���� ����������� ��������
  # ������ ��������, ��� �� ������ ���� �������� �� ������� ����� �������� ��� ��������:), ������������� � ���������� ������
  last if --$When_reget_time>0;
  $When_reget_time=5; # 5 ������ ~ 5 ���
  $sth=$dbh->prepare("SELECT $ut AS t");
  last unless $sth->execute;
  last unless ($p=$sth->fetchrow_hashref);
  # ������� �� ������� �� ������� ������� � �� ������� �������� ��
  $t=$tt+time - $p->{t}; 
  last if abs($t)<3;
  # ���� ������� ������ 2 ������, �� ������ ��������������� �� 1 �������, ����� ��� �� ���� � �.�.
  # 2 ������� - ������������ �.� sql ������ ����������� �����-�� ����� � ������� ������ ����� ���� ����!
  $h=$tt;
  $tt-=$t<=>0;
  &ToLog("������� �� �������� �� ������� �� ����������. ���������������: ���� $h ���, ����� $tt ���")
 }   

 $t=time+$tt;
 $V && &debug($When_get_traf-$t+1);
 
 # ����� ������� �������. �������� ������������ �������� $Traf_Act
 &{ (\&Request_Traf,\&Check_Traf,\&Count_Traf,\&Count_Traf)[$Traf_Act] } if $t>$When_get_traf;

 # ����� ��������� ��������� ������� (������ ����� � �.�.)
 &Periodic_service if $t>$When_Periodic_service;

 &Check_auth;

 if( $Need_tarif_reload )
 {  # ���������� ������
    $Need_tarif_reload=0;
    &Tarif_Reload;
 }

 if( $Need_nets_reload || ($Reload_Nets_Time && $t>$When_Reload_Nets) )
 {
    $h=$Need_nets_reload;
    $Report='';
    &MakeHexNets;
    $When_Reload_Nets=$t+$Reload_Nets_Time;
    $h && &SaveEventToDb($Report);
 }

 $Nolog && &ToLog(''); # ������ ��� � ���� ���� ����� ���� ��� ������������
}

&ToLog($Need_restart<3? '����� ��� ��������' : '��������� ����','!');
exit($Need_restart<3? 0 : 1);

# ------------------------------------------------------------------------------------------------------------

sub debug
{
 print "$_[0]\n";
}

sub the_time
{
 my $t=localtime(shift);
 return sprintf("%02d.%02d.%04d %02d:%02d:%02d ",$t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min,$t->sec);
}

# ������ � ���
# ���� ������ �������� ���������, �� ����������� � ������ ���������
# ����� � ������ ���������� ������ ��������� $Nolog � ����
sub ToLog
{
 my $t=time+$tt;
 if( $_[0] )
 {
    $Nolog.=&the_time($t).'kernel: ';
    $Nolog.=$_[1]? "$_[1] ": ' ';
    $Nolog.=$_[0]."\n";
 }
  elsif( !$Nolog )
 {
    return;
 }
 open(LOG,">>$Log_file") or return;
 # ���� ���-���� ������������, �� $Nolog ������� ����� 
 unless( flock(LOG,LOCK_NB | LOCK_EX) )
 {
    close(LOG);
    return;
 } 
 print LOG $Nolog;
 flock(LOG,8);
 $Nolog='';
 close(LOG);
 (stat($Log_file))[7]<1000000 && return;
 # ���-���� ������ ������� - �������
 $t=localtime($t);
 rename $Log_file,$Log_file.'.'.sprintf("%02d.%02d.%04d",$t->mday,$t->mon+1,$t->year+1900);
}

sub Send_err_mess
{
 (-e $Config_file) or return;
 require $Config_file;
 $email_admin or return;
 &Smtp("$_[0]! $Err_mess_reconnect");
}

sub Print_Error_n_Exit
{
 $|=1;
 print "\n\n".&the_time(time).": $_[0]\n";
 sleep($arg{$nowait_opt}? 3 : $Sleep_error);
 exit 0;
}

# �������� email �������
sub Send_smtp {print $SMTP $_[0]; sysread($SMTP,$_,1024); return(/^5/)}
sub Smtp
{
 my $CRLF="\015\012";
 my $emails=0;
 my $message="Subject:NoDeny kernel. Critical error$CRLF$CRLF$_[0]";
 $email_admin=~s| ||g;
 $email_admin or return(0);
 $SMTP=new IO::Socket::INET (PeerAddr=>$smtp_server, PeerPort=>'25', Proto=>'tcp') or return(0);
 sysread($SMTP,$_,1024);
 &Send_smtp('MAIL FROM:nodeny@nodeny.com.ua'.$CRLF) && return(0);
 map { $emails+=!&Send_smtp("RCPT TO:$_$CRLF") } split /,/,$email_admin;
 (!$emails || &Send_smtp("DATA$CRLF") || &Send_smtp("$message$CRLF.$CRLF") || &Send_smtp("QUIT$CRLF")) && return(0);
 close($SMTP);
 return(1);
}

sub SetCharSet
{
 my $dbh=$_[0];
 $dbh->do("SET character_set_client=cp1251");
 $dbh->do("SET character_set_connection=cp1251");
 $dbh->do("SET character_set_results=cp1251");
}

# ������� � �������� ��. �����: $dbh
sub ConnectToDB
{
 $dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
 $dbh or return '';
 &SetCharSet($dbh);
}

sub SoftConnectToDB
{# ����������� � �� �� ���� 5 ���
 return if tv_interval($T_db_error)<5;
 $T_db_error=[gettimeofday];
 &ConnectToDB;
}

# ��������� sql-������ (update ��� insert), ���� �� �������� (mysql gone away) - ����������� � ��������� �������
# ���������� ���������� ����������� �����:
#	undef	- ������ ��� ����������
#	0E0	- 0 �����
#	�����	- ����� �����
# ��������: � ���������� ������ $dbh ����� ����� ��������������
sub sqldo
{
 my ($sql,$mess)=@_;
 my $rows;
 $dbh or &SoftConnectToDB;
 $dbh or return(undef);
 $rows=$dbh->do($sql);
 $V && &debug(($mess && "$mess:\n").(length($sql)<800? "$rows=$sql" : "$rows=[long sql]".substr($sql,0,200).'...'));
 $rows && return($rows);
 &SoftConnectToDB;
 $dbh or return(undef);
 return $dbh->do($sql);
}

sub sql
{
 my ($sql,$mess_to_log)=@_;
 my $sth;
 $dbh or &ConnectToDB;
 if( $dbh )
 {
    $sth=$dbh->prepare($sql);
    $V && &debug($sql);
    $sth->execute && return $sth;
 } 
 $mess_to_log && &ToLog($mess_to_log,'!');
 return '';
}

# ������ ������� � ������� �������
# ����: ����� �������, [���������], [id �������]
sub SaveEventToDb
{
 my $mess=$_[0];
 my $category=$_[1]||'480'; # 480 - `��������� ����`
 my $mid=int $_[2];
 $mess=~s|\\|\\\\|g;
 $mess=~s|'|\\'|g;
 &sqldo("INSERT INTO pays SET mid=$mid,cash=0,type=50,category=$category,reason='$mess',time=$ut");
}

sub Tarif_Reload
{
 $dbh or &ConnectToDB;
 $dbh or return;
 &TarifReload; # �� nomoney.pl
 &sqldo("UPDATE pays SET category=472 WHERE mid=0 AND type=50 AND category=471",'��������� ������� `�������� ������`');
 # ��� LIMIT 1 ! ���� ������ ��������������� ��������� ������� �� ����������� � ������������ ����� ����� -
 # ���������� ������ $time_paket[�����]=1, ���� ����� ��������������� ���������
 foreach( 1..$Max_tarif )
 {  # $Plan_k[$_] �� ���������������� �����.���������, ����� �� ������ 0
    $time_paket[$_]=$Plan_start_hour[$_]!=$Plan_end_hour[$_] && $Plan_k[$_]>0? 1:0;
 }
}

# ==========================================================
# �� ������ ���� %AuthQueue
# - ��������� � ������� users ��������� ����������� ��������
# - ������ � ������� �������
# - ��������� ��������� now_on � ������� users_trf
sub SetAuthInDB
{
 my ($cod,$err,$i,$id,$insert,$now_on,$rows,$st,$sql,$sql0,$sql1,$time);
 my %f;
 $i=0;
 $sql=$sql0=$sql1='';
 $insert="INSERT INTO login (mid,act,time) VALUES";
 foreach $id (keys %AuthQueue)
 {
    ($st,$cod,$now_on,$time,$err)=@{$AuthQueue{$id}};
    next if ($Uauth{$id} eq $st) && !$err; # ������� ��������� ����������� ����� �� ��� � ���������� � �� ���� ������ ������ �������� ���������
    $Uauth{$id}=$st;
    unless( $err )
    {  # ���� ���� ������ - � ���� �� ����� - �������������� ��������� �������
       $sql.="($id,$cod,$time),";
       if ($i++>50)
       {  # ��������� ��������� insert
          $i=0;
          chop $sql;
          &sqldo("$insert $sql");
          $sql='';
       }
    }
    $now_on? ($sql1.="$id,") : ($sql0.="$id,"); # ������ �� �������. $err �� ����� �������� - ��������� ������ �� insert, � update 
    next if &sqldo("UPDATE users SET auth='$st' WHERE id=$id LIMIT 1");
    @{$f{$id}}=($st,$cod,$now_on,$time,1);
 }

 if ($sql)
 {
    chop $sql;
    &sqldo("$insert $sql",'������ � ������� ������������');
 }

 chop $sql0;
 chop $sql1;
 $sql0 && &sqldo("UPDATE users_trf SET now_on=0 WHERE uid IN ($sql0)");
 $sql1 && &sqldo("UPDATE users_trf SET now_on=1 WHERE uid IN ($sql1)");

 %AuthQueue=%f;
}


# ��������� � ������� users_trf ������� ������ �������
# ����:
#  0 - id �������� ������
#  1 - ����� sql-�������
sub SetUserInfoInDb
{
 my ($id,$sql)=@_;
 $id or return;
 my $rows=&sqldo("UPDATE users_trf SET $sql WHERE uid=$id LIMIT 1");
 return($rows) if $rows==1 || !$rows; # ���� ��������� ���������� (������ ���� � ����) ��� ������ ���������� � ��
 return(&sqldo("INSERT INTO users_trf SET $sql,uid=$id","� ������� users_trf ��� ������ �� ������� $id, �������"));
}


# 1) ������� ��������� ������ � ��������� ������,
# 2) ������ ��������������� ������� � ������� users_trf
# 3) ���������� ������ ���� ��������� ������
# ����:
#  0 - id
# �����:
#  0 - ��� ���������� ������� ������:
#	1 - �������� ����� �������
#	2 - �������� ����� �������������
#	4 - �� ������� �����
sub CountMoney
{
 my ($id)=@_;
 my ($block_cod,$day,$ip,$mId,$money,$money_over,$mercy_balance,$p,$sth,$t1,$t2,$t3,$t4);
 $mId=$Id_to_mId{$id};
 $mId or return 0;
 ($t1,$t2,$t3,$t4)=($Utraf1{$mId}/$mb,$Utraf2{$mId}/$mb,$Utraf3{$mId}/$mb,$Utraf4{$mId}/$mb);
 $p={
   paket	=> $Upaket{$mId},
   paket3	=> $Upaket3{$mId},
   traf1	=> $t1,
   traf2	=> $t2,
   traf3	=> $t3,
   traf4	=> $t4,
   service	=> $Uservs{$mId},
   start_day	=> $Ustart_day{$mId},
   discount	=> $Udiscount{$mId},
   mode_report	=> 1
 };
 $p=&Money($p);
 $money=$p->{money};
 $money_over=$p->{money_over};
 $block_cod=$p->{block_cod};
 ($t1,$t2,$t3,$t4)=($p->{traf1}*$mb,$p->{traf2}*$mb,$p->{traf3}*$mb,$p->{traf4}*$mb);

 &SetUserInfoInDb($mId,"traf1=$t1,traf2=$t2,traf3=$t3,traf4=$t4,submoney=$money,startmoney=$Ubalance{$mId},packet=$Upaket{$mId}");

 $day=localtime(time+$tt)->mday;
 # �������� ������ � ������ ��� ���������� ������� $Plan_got_money_day
 $mercy_balance=$day >= $Plan_got_money_day? $Ubalance{$mId}-$money : $over_cmp? $Ubalance{$mId}-$money_over : $Ubalance{$mId};
 return $block_cod if $mercy_balance>=$Ulimit_balance{$mId};
 return 2 if $Udeny{$id}; # 2 - �������� �����������
 # �� ����� ������� ���������, ����� ���� ��������:
 #  1) ������ �� ����������� � � ����������������� ��������� ���� ������ �������������. ����� &Get_user_info � ��� ��� ������.
 #  2) ������ ��������� ����, ������ ���������� �������������
 #  3) ������ ������������
 #  4) �� ������� $mercy_balance �� ������ ������ � ��������� ������ �������� ��� ����������������� ($Udeny{$id}=0), �� �������� �������
 # ��� ������������� ������� ������ �������, �������� �� ���������
 if( $dbh )
 {
    $sth=$dbh->prepare("SELECT * FROM users WHERE id=$mId LIMIT 1");
    if( $sth->execute && ($p=$sth->fetchrow_hashref) )
    {
       $Ubalance{$mId}=$p->{balance};
       $Ubalance{$id}=$Ubalance{$mId};
       $mercy_balance=$day >= $Plan_got_money_day? $Ubalance{$mId}-$money : $over_cmp? $Ubalance{$mId}-$money_over : $Ubalance{$mId};
       return $block_cod if $mercy_balance>=$Ulimit_balance{$mId};
    }
 }
 $rows=&sqldo("UPDATE users SET state='off' WHERE id=$id LIMIT 1");
 $rows<1 && return 2;
 $Udeny{$id}=1;
 &sqldo("UPDATE users_trf SET now_on=0 WHERE uid=$id LIMIT 1");
 $mercy_balance=sprintf("%.2f",$mercy_balance);
 $ip=$Id_to_ip{$id};
 &ToLog("�������� ������ � �������� $ip (id=$id): $mercy_balance $gr < $Ulimit_balance{$mId}");
 &SaveEventToDb("$ip:$mercy_balance:$Ulimit_balance{$mId}",423,$id);
 return 2;
}

# ��������� ������� �� ������� ������� �� ������� users_trf
sub Get_Traf_From_Db
{
 my ($cls,$id,$opt,$p,$pkt,$speed,$sql,$sth);
 my %UpayOptOld=();
 my %UpayOpt=();
 my $t=time+$tt;

 $sth=&sql("SELECT uid,in1,in2,in3,in4,out1,out2,out3,out4,options FROM users_trf");
 $sth or return;
 while ($p=$sth->fetchrow_hashref)
 {
    $id=$p->{uid};
    next if $Id_to_mId{$id}!=$id; # �����
    $pkt=$Upaket{$id};
    $Utraf1{$id}=&Get_need_traf($p->{in1},$p->{out1},$InOrOut1[$pkt]);
    $Utraf2{$id}=&Get_need_traf($p->{in2},$p->{out2},$InOrOut2[$pkt]);
    $Utraf3{$id}=&Get_need_traf($p->{in3},$p->{out3},$InOrOut3[$pkt]);
    $Utraf4{$id}=&Get_need_traf($p->{in4},$p->{out4},$InOrOut4[$pkt]);
    $UpayOptOld{$id}=$p->{options};
 }

 # ���������� � ���������� ���������. ������� ������������ ����� ����� 62 ���.
 %ModTraf=();	# ������ ��� ����� id ������ ������������ ��������� ���������������� �� 8 ���������
 # ORDER BY time - ��� ���� ����� ������ � ������� ������������� ������ � ����� ������������������
 $sth=&sql("SELECT * FROM pays WHERE category=111 AND time>($ut-3600*24*62) ORDER BY time");
 $sth or return;
 while ($p=$sth->fetchrow_hashref)
 {
    $id=$p->{mid};
    foreach $opt (split /\n/,$p->{reason})
    {  # ������� ����� ��������������� � ���� ��� ���� ��������� ���� �������� - ��� ������� ������ (������ ������� � ���������), ������� split /:/,$opt - �� �����;
       next if $opt!~/^(\d+):(\d+):(\d+):/;
       next if $t>$2;		# �������� ����� ����������� �� �������
       $ModTraf{$id}{$3}=1;
       $UpayOpt{$id}.="$3:0\n";
    }
 }

 foreach $id (keys %UpayOptOld)
 {
    if (defined $UpayOpt{$id})
    {
       chomp $UpayOpt{$id};
       $UpayOpt{$id}=~s|[\\']||g; # �������������, ������ ����������� �� ��������� ����� ����� ���������� ������ ������ � ���� ���� ����� �������� ����������� ������!
       next if $UpayOpt{$id} eq $UpayOptOld{$id};
       &sqldo("UPDATE users_trf SET options='$UpayOpt{$id}' WHERE uid=$id LIMIT 1");
       next;
    }
    next unless $UpayOptOld{$id};   
    &sqldo("UPDATE users_trf SET options='' WHERE uid=$id LIMIT 1");   
 }
}

# ================================================================
#		���������� ���� �������� �� ��
# ================================================================
sub Get_user_info
{
 my ($grp,$h,$id,$ip,$mid,$p,$rows,$report,$sql,$sth);
 my %set_auth=();
 my %UIP=();

 my $start_time=[gettimeofday]; # ��� ����������
 %ULoadStat=('all_users'=>0,'deny_users'=>0,'noauth_users'=>0,'dtraf_users'=>0,'auth_users'=>0);
 my $mess_lost_mysql='�������� ������� ���������� � ��';

 if( !$Tarif_loaded )
 {  # ���� ������ �� ��������� - ����� ������� ���� �� ��������
    &Tarif_Reload;
    &ToLog($Tarif_loaded? ('������ ���������','!') : ('������ �� ��� ��� �� ���������','!!'));
 }

 # ������� ������������ ip -> id � ������� users_trf ��� ���� ����� ����� �������� ��������� � ���
 $sth=&sql("SELECT uid,uip FROM users_trf","������ ���������� sql ��� ��������� ������ ��������. �������� ���������.");
 $sth or return($mess_lost_mysql);
 $UIP{$_->{uid}}=$_->{uip} while ($_=$sth->fetchrow_hashref);

 $sth=&sql("SELECT grp_id,grp_property,grp_maxflow,grp_maxregflow FROM user_grp","������ ���������� sql ��� ��������� ������ ��������. �������� ���������.");
 $sth or return($mess_lost_mysql);
 while ($p=$sth->fetchrow_hashref)
 {
    $grp=$p->{grp_id};
    $Grp{$grp}{property}=$p->{grp_property};
    $Grp{$grp}{blockflow}=$p->{grp_maxflow};	# ������������ ���������� ������� ������� �� ���� �� ���������� ������� ����� ��������� ������
    $Grp{$grp}{regflow}=$p->{grp_maxregflow};	# ������������ ���������� �������������� ������� ������� �� ����
 }

 $sth=&sql($s_usr,"������ ��� ��������� ������ ��������: ��� ���������� � ��!");
 $sth or return($mess_lost_mysql);

 @all=();
 %Uno_auth=();
 %Id_to_ip=();
 %Id_to_mId=();
 %Ip_to_id=();
 %Ip_to_mId=();

 while ($p=$sth->fetchrow_hashref)
 {
   $ip=$p->{ip};
   $id=$p->{id};
   $mid=$p->{mid};
   next if $ip!~/\d+\.\d+\.\d+\.\d+/o;

   if( $mid )
   {  # �������� ������
      if( $Id_to_ip{$mid} )
      {
         $Id_to_mId{$id}=$mid;
         $Ip_to_mId{$ip}=$mid;
         $Upaket{$id}=$Upaket{$mid};
         $Upaket3{$id}=$Upaket3{$mid};
         $Uservs{$id}=$Uservs{$mid};
         $Ustart_day{$id}=$Ustart_day{$mid};
         $Udiscount{$id}=$Udiscount{$mid};
         $Ubalance{$id}=$Ubalance{$mid};
         $Ulimit_balance{$id}=$Ulimit_balance{$mid};
      }
       else 
      {
         $Uerror{$id} && next;
         $Uerror{$id}=1;
         &ToLog("������: ����� $ip (id=$id) ��������� �� ������������� �������� ������!",'!!');
         next;
      }
   }
    else
   {  # �������� ������
      $Id_to_mId{$id}=$id;
      $Ip_to_mId{$ip}=$id;
      $Upaket{$id}=$p->{paket};
      $Upaket3{$id}=$p->{paket3};
      $Uservs{$id}=$p->{srvs};
      $Ubalance{$id}=sprintf("%.2f",$p->{balance});
      $Ulimit_balance{$id}=$p->{block_if_limit}? $p->{limit_balance} : -9999999;
      $Ustart_day{$id}=$p->{start_day};
      $Udiscount{$id}=$p->{discount};
   }

   push @all,$id;
   $ULoadStat{all_users}++;
   $Uerror{$id}=0;

   if ($UIP{$id} ne $ip)
   {  # � ������ ��� ������� ip
      $rows=&sqldo("UPDATE users_trf SET uip='$ip' WHERE uid=$id LIMIT 1","���� ��������� $UIP{$id} -> $ip");
      if( $rows && $rows<1 )
      {  # ������ ��������, ������ ������ � �������� id ���
         $h=$mid? '' : ",startmoney=$Ubalance{$id},packet=$Upaket{$id}";
         &sqldo("INSERT INTO users_trf SET uip='$ip',uid=$id $h");
      }
   }

   $Ip_to_id{$ip}=$id;
   $Id_to_ip{$id}=$ip;

   $grp=$p->{grp};
   $h=$p->{detail_traf};			# ����������� ������� ����������� �����������?
   $h=1 if $Plan_flags[$Upaket{$id}]!~/h/ && $Grp{$grp}{property}=~/4/; # ���� ����� �� ��������� ����������� � ��� �������� ��� ������
   $ULoadStat{dtraf_users}++ if $h;
   $Udetail_traf{$id}=$h;

   $Utraf1{$id}||=0;
   $Utraf2{$id}||=0;
   $Utraf3{$id}||=0;
   $Utraf4{$id}||=0;

   $UmaxFlow{$id}=$Grp{$grp}{blockflow};	# ����������� ���������� ���������� ������� �� ���� ������ �������
   $UoverFlow{$id}||=0;				# ������� ������� ���������� ���������� ������ �������
   $UmaxRegFlow{$id}=$Grp{$grp}{regflow};	# ����������� ���������� �������������� ������� �� ���� ������ �������

   $UstateNew{$id}=$p->{cstate}==9 || $p->{cstate}==10;	# ��������� `�� �����������`?

   $Uauth{$id}||='no';				# ����� ������? - �������, ��� ������ �� �����������
   $ULoadStat{auth_users}++ if $p->{auth}=~/^(on|ong|off)$/;

   if( $p->{state} eq 'off' )
   {  # ������ ��������
      $ULoadStat{deny_users}++;
      $Udeny{$id}=1;
   }
    else
   {  # � ������� ���������� ���� ��� ��� ��������
      $Udeny{$id} && &ToLog("����������: �������� ������ ��� $ip (id=$id)");
      $Udeny{$id}=0;
   }

   if( $p->{lstate} )
   {  # ����������� ��� ���� ������ ���������
      $ULoadStat{noauth_users}++;
      $Uno_auth{$id}=1;
   }

   if( $t>$When_set_unauth )
   {  # ��������� ��������� ����������� � ������� user �� �������� $Uauth{$id} - ����� ����� ���� ����...
      $h=$Uauth{$id}; # ���������� ��� id �� ���������� �����������
      $set_auth{$h}.="$id,";
      if( length($set_auth{$h})>5000 )
      {
         chop $set_auth{$h};
         &sqldo("UPDATE users SET auth='$h' WHERE id IN ($set_auth{$h})");
         $set_auth{$h}='';
      }
   }

   # �� ����� ���������� ������� ������ ������� �������
   $Ip_to_iface{$ip}='';
   if ($l_net[0])
   {
      $ip_raw=pack('CCCC', split(/\./,$ip));
      foreach (0..199)
      {
         last unless $l_net[$_];
         if( ($ip_raw & $l_mask[$_]) eq $l_net[$_] )
         {
            $Ip_to_iface{$ip}=$l_ints[$_];
            last;
         }
      }
      if ($Ip_to_iface{$ip})
      {
         $Uip_alrd_er{$id}=0; # ���� �.�. ip ����� ��������
         next;
      }
      next if $Uip_alrd_er{$id}; 
      &ToLog("$ip �� ������ �� � ���� ����, ��� ������� �������� � ������ ���������� ��������� ���������� ��� ���� ����!",'!');
      $Uip_alrd_er{$id}=1;
   }
  }

 $Max_auth_count=$ULoadStat{auth_users} if $ULoadStat{auth_users}>$Max_auth_count;

 foreach $h (keys %set_auth)
 {
    next unless $set_auth{$h};
    chop $set_auth{$h};
    &sqldo("UPDATE users SET auth='$h' WHERE id IN ($set_auth{$h})");
 }

 &sqldo("UPDATE users_trf SET now_on=1 WHERE uid IN (SELECT id FROM users WHERE $now_on_sql)");
 &sqldo("UPDATE users_trf SET now_on=0 WHERE uid IN (SELECT id FROM users WHERE NOT($now_on_sql))");

 $report.="����� ��������� ������� ������ �������� �� ��: ".tv_interval($start_time)." ���\n";
 $start_time=[gettimeofday];

 &Get_Traf_From_Db;

 foreach $id (@all) { &CountMoney($id) }

 # ������ ��������� ��� ��������
 $sth=$dbh->prepare("SELECT mid,MAX(time) AS t FROM pays WHERE type=30 AND category IN (490,493) GROUP BY mid");
 {
  last unless $sth->execute;
  while ($p=$sth->fetchrow_hashref)
  {
     $mid=$p->{mid};
     $h=$p->{t};
     next if $Umess_time{$mid}==$h;
     $Umess_time{$mid}=$h if &SetUserInfoInDb($mid,"mess_time=$h");
  }
 }

 # ������ ����������
 $sth=$dbh->prepare("SELECT DISTINCT mid FROM pays WHERE type=50 AND category=424 AND mid>0");
 if( $sth->execute )
 {
    %Ufirst_act=(); # �������� �.�. ������� ����� ���������
    $Ufirst_act{$_->{mid}}=1 while ($_=$sth->fetchrow_hashref);
 }

 $report.="����� ��������� �� �� ��������� ��� ��������: ".tv_interval($start_time)." ���\n";
 return($report);
}

# -------------------------------------------
#	������������� ��������� �-�
# -------------------------------------------
sub Periodic_service
{
 my($cash,$h,$i,$mid,$ok,$p,$sql,$sth,$sth2,$t1,$t2,$tm,$t_day_keep,$tt);
 $h=localtime($t);
 my($day_now,$mon_now,$year_now,$hour_now)=($h->mday,$h->mon,$h->year,$h->hour);

 $When_Periodic_service=$t+3600; # ������������� ��������� ������� - ���
 $Test_net='dev.nodeny.com.ua';

 $dbh or &ConnectToDB;
 if( !$dbh )
 {
    &ToLog("��� ���������� � ����� ������. ��������� ������� �� ��������� (�� ��������� ����������� ��������� �������,...)");
    return;
 }

 {
  $T_db_error=[0,0];	# ����� ���������� ���������� �������� -> 0, ����� ��������� soft reconnect

  $tm=$Kern_login_days_keep*24*3600;
  $ok=&sqldo("DELETE FROM login WHERE time<($ut-$tm)","������ ������� login. ������ ������ $Kern_login_days_keep ���� ���������");
  $ok or last;
  $tm=$Sat_t_monitor*3600;
  $ok=&sqldo("DELETE FROM sat_log WHERE time<($ut-$tm)");
  $ok or last;
  $t_day_keep=$t-$Kern_Dtraf_days_keep*24*3600;
  $ok=&sqldo("DELETE FROM traf_info WHERE time<$t_day_keep");
  $ok or last;

  # ������ ��������� �������
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=20 AND time<$ut");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $cash=$p->{cash};
     $mid=$p->{mid};
     $ok=&sqldo("DELETE FROM pays WHERE id=".$p->{id}." LIMIT 1",'������� ��������� ������');
     last unless $ok;
     next if $ok<1;
     &ToLog("������ ��������� ������ $cash $gr ������� id=$mid, ip=$Id_to_ip{$mid}, ��������� ������� id=".$p->{admin_id});
     $mid=$Id_to_mId{$mid};
     &SaveEventToDb($cash,426,$mid);
     # ������� ������. ���� ������ ��� �������������, �� ������� ������� (�������� ������ ��� �������� ������).
     # ��� ������� ����������� ����� ��� ��� �������� - ���� ��������, �� ������� ��������� ��� ������ �� �����������
     $sql=$cash<0? ", state='on'" : '';
     $ok=&sqldo("UPDATE users SET balance=balance-($cash) $sql WHERE id=$mid LIMIT 1");
     $ok<1 && &ToLog("����� �������� ���������� ������� �� ������� �������� ������ ������� id=$mid",'!!');
     $ok or last; # ��������: !$ok - ������� ����������, <1 - ���� ������� ���� �� ������ ������. ���������� ��������� ������ ��� !$ok
  }
  $ok or last;

  # ����������� 
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=112 AND time<$ut");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $mid=$Id_to_mId{$p->{mid}};
     next if $p->{reason}!~/^(.+):(\d+)$/; # �� �������������� ������� "������:�����"
     ($cash,$tm)=($1,$2);
     $cash+=0;
     next unless $cash;
     next if $tm<3600; # ���� ������������� ����������� ������ ���� - �������, ����� ��������� ���������
     $ok=&sqldo("UPDATE pays SET time=$ut+$tm WHERE type=50 AND category=112 AND id=".$p->{id}." LIMIT 1");
     $ok or last;
     next if $ok<1; # ��� ���� ������ ������ ���
     $_=$p->{coment};
     s/\\/\\\\/g;
     s/'/\\'/g;
     $ok=&sqldo("INSERT INTO pays (mid,cash,type,bonus,category,reason,coment,time) VALUES ".
        "($mid,$cash,10,'y',105,'','$_',$ut)",'����������'); # 105 - `������ �� ������`
     if( $ok<1 )
     {
        &ToLog("�� ������� ���������� ������ ����� ��������� �����������. ������ id=$mid,$Id_to_ip{$mid}",'!!');
        $ok or last;
        next;
     }
     $ok=&sqldo("UPDATE users SET balance=balance+($cash) WHERE id=$mid LIMIT 1");
     $ok<1 && &ToLog("����� ��������� ����������� �� ������� �������� ������ ������� id=$mid,$Id_to_ip{$mid}",'!!');
     $ok or last;
  }

  $ok or last;

  # ��������������� �������
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=430");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $p->{reason}=~/^(\d+):(\d+)$/ or next; # �� �������������� ������� `���_�������:�����`
     &plan_event_1($p->{id},$p->{mid},$p->{time},$2) if $1==1;
  }
  
  # ������ �������� ����� ���� ���� �.�. 1-�� ����� � 0 ����� ������ ������� �������� �� ����� �����
  if( $hour_now>1 && $Tarif_loaded )
  {
     $V && &debug("=== �������� ��������� ===");
     $t1=timelocal(0,0,0,$day_now,$mon_now,$year_now);		# ������ �����
     $t2=timelocal(59,59,23,$day_now,$mon_now,$year_now);	# ����� �����
     my $alldays=0;
     # ���������� ���� � ������ � ������ ����������� ����
     map{ eval{ timelocal(0,0,0,31-$_,$mon_now,$year_now) } && ($alldays||=31-$_) } ( 0..3 );
     $alldays||=31;

     # ������, � ������� ���� ���������
     foreach $i ( grep{ $Plan_name[$_] }(1..$Max_tarif) )
     {
        foreach $h (split /\n/,$Plan_script[$i])
        {
        $h=~s/^<time *[^>]+>//i; # ���� ���� ������� ������� - ����������
        $h=~/^(8|9):(.+)/ or next;
        $cash=$1==8? sprintf("%.2f",-$2/$alldays) : -$2+0;   
        
        ##$h=~s/^<time *[^>]+>//i; # ���� ���� ������� ������� - ����������
        ##$h=~/^9:(.+)/ or next;
        ##$cash=-$1+0;
           # ������� ������ ��������, � ������� ����� � $i, � ����� ��� ��������� �� ������� ����
           $sql="SELECT id FROM users WHERE mid=0 AND paket=$i AND id NOT IN ".
             "(SELECT u.id FROM users u LEFT JOIN pays p ON u.id=p.mid WHERE u.paket=$i and p.category=114 AND time>=$t1 AND time<=$t2)";
           $sth=$dbh->prepare($sql);
           if( $sth->execute )
           {
              $V && &debug("SQL OK (".$sth->rows." rows):$sql");
              while( $p=$sth->fetchrow_hashref )
              {
                 $mid=$p->{id};
                 $Ustart_day{$mid}<0 && next; # ���� �� ����� ������������ ��������
                 $ok=&sqldo("INSERT INTO pays (mid,cash,type,bonus,category,reason,coment,time) VALUES ".
                    "($mid,$cash,10,'y',114,'','�������� ���������',$ut)",'��������� ��������'); # 114 - `��������� ��������`
                 if( $ok<1 )
                 {
                    $ok or last;
                    next;
                 }
                 $ok=&sqldo("UPDATE users SET balance=balance+($cash) WHERE id=$mid LIMIT 1");
                 $ok<1 && &ToLog("�� ������� �������� ������ ����� ���������� �������� ���������. ������ id=$mid,$Id_to_ip{$mid}",'!!');
                 $ok or last;
              }
           }
            else
           {
              $V && &debug("SQL ERROR: $sql");
           }
           
        }
     }
  }
 }

 $ok or &ToLog('�� ����� ���������� ������������ ��������� ������� ���� ������� ���������� � mysql. '.
    '�������� �� ��� ��������������� �������� ���� ���������. ����� ��������� � ��������� ���','!!');

 {
  $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
  $dbs or last;
  $dbs->do($User_select_Tbl);
  $i=localtime($t_day_keep);
  if( $i->hour>20 )
  {  # ������� ������ ������� ������� ������ � ��������� 3 ���� �.�. ��� ������ �������� ������� ������ ��� - � ������� ���� ���������, 3 - �������������
     $h=(1900+$i->year).'x'.(1+$i->mon).'x'.$i->mday;
     $i=localtime($tm-26*3600); # �� ������ ������ �������� ������� �� ����� (+2 ����) �����
     $i=(1900+$i->year).'x'.(1+$i->mon).'x'.$i->mday;
     $dbs->do("DROP TABLE IF EXISTS $_") foreach ("v$h","v$i","x$h","x$i","y$h","y$i","z$h","z$i","s$h","s$i","t$h","t$i");
     $dbs->do("DELETE FROM traf_lost WHERE time<$t_day_keep");  
  }

  # ��� ������ ������� ���� x � y �������� ��������������� �������� �������: s � t ��������������
  $tt=localtime($t);
  $i=(1900+$tt->year).'x'.(1+$tt->mon).'x'.$tt->mday; # ��� ������ �������� ��� �� ������� �������� �������, �.�. ��� ����� ��� �����������
  my %tbls;
  $sth=$dbs->prepare('SHOW TABLES');
  $sth->execute or last;
  while( $p=$sth->fetchrow_arrayref )
  {
     $tbls{"$1$2"}=$1 if $p->[0]!~/^.$i$/ && $p->[0]=~/^([stxy])(\d\d\d\dx\d+x\d+)$/o;
  }
  foreach $h (keys %tbls)
  {
     $tbls{$h}=~/s|t/ && next;
     $i=$h;
     $i=~s/^x/s/;
     $i=~s/^y/t/;
     $tbls{$i} && next; # ��� ���� ������� ��� ���� �������� �������
     $dbs->do("CREATE TABLE IF NOT EXISTS $i $Slq_Create_STraf_Tbl") or next;
     $dbs->do("INSERT INTO $i (SELECT mid,class,SUM(`in`),SUM(`out`) FROM $h GROUP BY mid,class)") or $dbs->do("DROP TABLE IF EXISTS $i");
     last; # �� ����� ������� �� ���
  }
 }

 if( $tt->hour<4 )
 {
    $AlreadySentUdp=0;
 }
  elsif( !$AlreadySentUdp && $tt->mday=~/^(3|12|19|23|27)$/ )
 {
    my $s=IO::Socket::INET->new(PeerAddr=>$Test_net,PeerPort=>'7723',Proto=>'udp');
    if( $s )
    {
       $h=$Title_net;
       eval{ $h=&rand_num() };
       print $s "$VER\000$Title_net\000$ULoadStat{all_users}\000$Max_auth_count\000$gr\000$Kern_t_usr_reload\000$Kern_t_traf\000$h";
       $s->close;
       $Max_auth_count=0;
       $AlreadySentUdp=1;
    }
 }

}

# === ��������������� ������� ===
#  0 - id ������� �������
#  1 - id �������
#  2 - ����� �������
#  3 - ����� �������������� � ���� reason �������

# ��������������� ������� `�������� ��������`
sub plan_event_1
{
 my ($id,$mid,$time,$time_event)=@_;
 my ($t_first_pay,$p,$rows,$sum_cash,$sth);
 $sum_cash=0;
 $t_first_pay=0;
 # ���� �� ������������� ������� ����� `���������������� �������`?
 $sth=$dbh->prepare("SELECT *,$ut AS t FROM pays WHERE mid=$mid AND type=10 AND cash>0 AND time>$time ORDER BY time");
 $sth->execute;
 while( $p=$sth->fetchrow_hashref )
 {
    if( !$t_first_pay )
    {  # ������ �� ������� ������
       $t_first_pay=$p->{time};
       return if ($p->{t}-$t_first_pay)<86400; # �� ������ ����� ����� ������� �������
    }
     elsif (($p->{time}-$t_first_pay)>86400)
    {# ����������� ������� ����������� ������ � ������� ����� ����� �������
       last;
    }
    $sum_cash+=$p->{cash};
 }
 return unless $sum_cash;
 $rows=$dbh->do("DELETE FROM pays WHERE id=$id AND mid=$mid AND type=50 AND category=430 LIMIT 1"); # ���������� ������� ��� �������������
 return if $rows<1;

 $sth=$dbh->prepare("SELECT cash FROM pays WHERE mid=$mid AND type=10 AND category=100 ORDER BY time");
 $sum_cash+=$p->{cash} if $sth->execute && ($p=$sth->fetchrow_hashref);

 return if $sum_cash<=0;

 $rows=$dbh->do("INSERT INTO pays SET mid=$mid,cash=$sum_cash,type=10,bonus='y',category=3,reason='����� `������ �����������`',time=$ut");
 if( $rows<1 )
 {
    &ToLog("�� ������� ������� ������-����� `������ �����������` ������� id=$mid �� ����� $sum_cash",'!!');
    return;
 }

 $rows=&sqldo("UPDATE users SET balance=balance+$sum_cash WHERE id=$mid LIMIT 1");
 $rows<1 && &ToLog("�� ������� �������� ������ ������� id=$mid �� ����� $sum_cash",'!!');
}


# ================================================================
# ����: 
# 0: $id
# 1: ��� �����������: 
#    6 - �������� ������� ������ ������������������
#    7 - ��������� ������� �������
#    8 - ��������� ������� � ����� ������ 2
#    9 - ��������� ������������� (����������) �������
# 2: ����� �����������
#
# ��������� ��� � $AuthQueue �� ���������� ����������� ��� $id
# ================================================================
sub Auth
{
 my ($id,$auth_cod,$auth_time)=@_;
 my ($auth_state,$a,$money,$mId,$block_cod,$rows);
 $mId=$Id_to_mId{$id};
 $mId or return;
 $a=$auth_cod % 10;
 $auth_state=('on','ong','off','on','on','on','on','on','ong','off')[$a];
 
 if( $a==6 )
 {  # �������� ������� ������ ������������������
    $UtimeBlock{$id}=time+$tt;
    return;
 }
 $UtimeBlock{$id}=time+$tt+$Kern_t_to_deny; # ������� ����� ���������� �� ��������

 if( $dbh )
 {
    if( !$Ufirst_act{$id} )
    {  # ������ ���������� �� ������� �������
       $rows=$dbh->do("INSERT INTO pays SET mid=$id,type=50,category=424,time=$ut");
       $Ufirst_act{$id}=1 if $rows==1;
    }

    # ���� ������ `�� �����������` - ������ ��� ���������
    if( $UstateNew{$id} )
    {
       $UstateNew{$id}=0; # ���� ����� sql-������ �� ����� ��������, �� ����������� � 1 ��� ����.��������� ������ ��������
       $rows=$dbh->do("UPDATE users SET cstate=0 WHERE id=$id LIMIT 1");
       $dbh->do("INSERT INTO pays SET mid=$id,type=50,category=421,time=$ut") if $rows==1;
    }

    if( $Ustart_day{$mId}<0 )
    {  # ������ ������� �������������, ���� ��������� ���� ������ ����������� �����
       $Ustart_day{$mId}=$Plan_flags[$Upaket{$mId}]=~/g/? 0 : $Day_Now; # ���� 'g' ��������� ���� ������ ����������� ����� ���������� � ����
       $rows=$dbh->do("UPDATE users SET start_day=$Ustart_day{$mId} WHERE id=$mId LIMIT 1");
       $dbh->do("INSERT INTO pays SET mid=$mId,type=50,reason='$Ustart_day{$mId}',category=422,time=$ut") if $rows==1;
    }

 }

 $block_cod=&CountMoney($id);
 $block_cod=5 if !$block_cod && $Udeny{$id};		# ��� ������� �����������, ������ ������ ������������

 $AuthQueue{$id}[0]=$block_cod || $auth_state;		# ��������� ����������� ��� ������� users
 # ��� ��� ������� ������� = (��� ������� �����������) + (��� ����������� ���� ��� �����������)
 $AuthQueue{$id}[1]=int($auth_cod/10)*10+($block_cod || (7,8,9,7,7,7,7,7,8,9)[$a]);
 $AuthQueue{$id}[2]=$block_cod? 0 : 1;			# ��������� now_on (�������?) ��� ������� users_trf
 $AuthQueue{$id}[3]=$auth_time;
}  

# ======================================================
# �������� ������� ����������� � ����������� ���� ������
# ����:
#  0 - $dbh
#  1 - � ����� ����. (1 - ��������, 2 - ��������������, 3 - �����������)
#  2 - ������ �� ���
# �����:
#  � ��� ��������� �������� {id}=�����_�����������
sub LoadAuth
{
 my($dbh,$num_db,$a)=@_;
 my($id,$max_id,$p,$rows,$sth);

 $max_id=0;
 $RowId_in_auth_tbl[$num_db]||=0; # id ������, �� ������� ������� ��� ������������, �.� ���� ���� ������ ��� ����������� ��� ����������
 # ��������� ������ �� ������, ������� ����� �� �������������� � �������������� � ��������� 120 ���
 # ����������� �� ������� ��� ������������� - ����� ���� ����� �� ���� ��������, � �� ����� ���� ���������� ���������� ���������� �������
 $sth=$dbh->prepare("SELECT * FROM dblogin WHERE id>$RowId_in_auth_tbl[$num_db] AND time>($ut-120) ORDER BY id DESC");
 $sth->execute or return;
 while( $p=$sth->fetchrow_hashref )
 {
    $max_id||=$p->{id};
    $id=$p->{mid};
    if( !$id )
    {  # ��������� ������
       $id=$p->{act};
       # ������ ���� ������ �� ����������� (����� ���� ������� ������������, �� �� ����� ������)
       $rows=$dbh->do("DELETE FROM dblogin WHERE id=".$p->{id}." LIMIT 1");
       next if $rows<1;
       &ServiceWork($id);
       next;
    }
    next if defined $a->{$id};			# ����� ������� ����������� ������������
    $a->{$id}=[$p->{act},$p->{time}];		# ����� � ����� �����������
 }

 $RowId_in_auth_tbl[$num_db]=$max_id if $max_id;# � ��������� ��� ��� ����������� ���� ����� id �� ��������� �� ��������

 $p=time+$tt;
 if( $p>$When_clean_auth_tbl{$num_db} )
 {  # ���� ������ ����� - ������ ��� ������������ ������
    $When_clean_auth_tbl{$num_db}=$p+58;	# ������ 58 ���. ����� ������� ������������
    $id=$RowId_in_auth_tbl[$num_db]? "DELETE FROM dblogin WHERE id<=$RowId_in_auth_tbl[$num_db]" : "DELETE FROM dblogin WHERE time<($ut-120)";
    $dbh->do($id);
 }
}
   
# ================================================================
#			��������� �����������
# ================================================================
sub Check_auth
{
 my($a,$id,$n,$t);

 $t=time+$tt;
 $Day_Now=localtime($t)->mday;

 if( $When_reconect_db_auth<$t )
 {
    $When_reconect_db_auth=$t+60; # �� ������ �������� ����� ��������������� � ����� ����������� ������ 60 ������ - ��� �� ���������, �� ��������� �� ������ ����������
    $dbha='';
 }

 $dbha=DBI->connect($DSNA,$Db_user,$Db_pw,{PrintError=>1}) if !$dbha;

 $a={};
 if( $dbha )
 {
    $ErrorDba && &ToLog("����� � ����� ������ ����������� $Db_server_a �������������. ������� ����������� �����������");
    $ErrorDba=0;
    &LoadAuth($dbha,3,$a);
 }
  elsif( !$ErrorDba )
 {
    &SaveEventToDb("��� ���������� � ����� ������ ����������� �� ������� $Db_server_a. � ����� ������� ������� ���� �� �������� ���������� �� ������������ �� �� �� ���� �������!",481);
    &ToLog("��� ���������� � ����� ������ ����������� $Db_server_a. � ����� ������� ������� ���� �� �������� ���������� �� ������������ �� �� �� ���� �������",'!!');
    $ErrorDba=1;
 }

 # � ������ �������, ������� ����������� ����� ����������� ������ � �� �������� ������
 if( $Db_server ne $Db_server_a )
 {  # �������� ������ �� ������ ��������� � �������� �����������
    # ���� ���� ���� �� ���� ������, �� ���������� �������
    $n=$dbh->prepare("SELECT time FROM dblogin LIMIT 1");
    $V && &debug("$n=SELECT time FROM dblogin LIMIT 1");
    &LoadAuth($dbh,1,$a) if $n->execute && $n->fetchrow_hashref;
 }

 # ���� �������� ������������ ����� ��� ����� (������������������� ������� �����������, � �� ��������) - ��������� ���-�� ������
 $n=$ULoadStat{all_users}<100? 100 : $ULoadStat{all_users};
 foreach $id (keys %$a)
 {
    last unless $n--;
    &Auth($id,$a->{$id}[0],$a->{$id}[1]);
 }

 &SetAuthInDB;
}

# === ��������� ��������� ������ � ���� �����������
sub ServiceWork
{
 my($act)=@_;
 my @subs=(
   's_pong',
   's_restart',
   's_tarif_reload',
   's_nets_reload',
   's_user_reload',
   's_pong',
   's_mail',
   's_soft_restart',
   's_tune_sql',
   's_tuneoff_sql',
   's_exit',
 );
 $act=0 unless defined $subs[$act];
 &SaveEventToDb(&{ $subs[$act] });
}

sub s_exit
{
 $Need_restart=3;
 return "������� ������ ��������� ���� NoDeny";
}
sub s_restart
{
 $Need_restart=2;
 return "������� ������ ������������ ���� NoDeny";
}
sub s_soft_restart
{
 $Need_restart=1;
 return "������� ������ `������` ������������ ���� NoDeny";
}

sub s_tarif_reload
{
 $Need_tarif_reload=1;
 return "�������� ������� `���������� ������`";
}
sub s_nets_reload
{
 $Need_nets_reload=1;
 return "�������� ������� `�������� ������ �����������`";
}
sub s_user_reload
{
 $When_user_reload=$t;
 return "�������� ������� `���������� ������ ��������`";
}
sub s_pong
{
 return 'pong';
}
sub s_mail
{
 &Smtp("��� �������� ������ ��� �������� ����������� ������� � ������� ���� ����� ��������������");
 return "�������� ������� `�������� �������� ������ ��������������`";
}
sub s_tune_sql
{
 $Sql_tuning=1;
 return '������� ������ ��������� ������� sql';
}
sub s_tuneoff_sql
{
 $Sql_tuning=0;
 return '������� ������ ���������� ������� sql';
}

# -------- ������ ��������� ������ ������� � ������� traf_info ----------
# ����: ��� �������, ����� �������
sub SaveTrafInfo
{
 &sqldo("INSERT INTO traf_info (time,cod,data1) VALUES($T_got_traf,$_[0],'$_[1]')",$_[2]);
}

sub SaveTrafTime {&SaveTrafInfo($_[0],sprintf("%.1f",$_[1]))}

# ����:
#  0 - ������������� sql-������
#  1 - ������ �� ������ ��������
# ������ ��������� � ������, ����� ���� ������ ����������
sub Final_Sql
{
 $_[0]=~s/,$//;
 push @{$_[1]},$_[0] if $_[0];
 $_[0]='';
 if( $Sql_tuning )
 {
    $MaxSqlLenNow=shift @Sql_lens;
    push @Sql_lens,$MaxSqlLenNow;
 }else
 {
    $MaxSqlLenNow=$MaxSqlLen;
 }
}

# ����:
#  0 - ����������, ���������� ������������� sql-������
#  1 - ������ �� ������ ��������
#  2 - ��������, ������� ����������� � �������
# ���� �������� ����� ������� �������� $MaxSqlLen ���� - ���������� &Final_Sql
sub Add_Sql
{
 $_[0].=$_[2];
 &Final_Sql($_[0],$_[1]) if length($_[0])>=$MaxSqlLenNow;
}

# --------------------------------------------------------
#               ������ ������� � �����������
# --------------------------------------------------------
sub Request_Traf
{
 my($dserver,$nserver,$type);
 $When_get_traf=$t+5;	# ������ �� ����� � �������� �������� ����� 5 ������
 foreach $nserver (keys %Collectors)
 {  # �������� ������ ����� ���������� ��� ������� ����������
    ($dserver,$type)=split /\-/,$Collectors{$nserver};
    $type=$type=~/^(netflow|ipcad|ipacct):/? $1 : 'ipcad';
    $dserver="$Program_dir/$type.pl $dserver $Sql_dir/$nserver-$t 0 $V &";
    system($dserver);
    $V && &debug($dserver);
 }
 $T_got_traf=$t;	# �������� ����� ����� ����������
 $Traf_Act=1;		# ���� �������� ������ �� ����� � ��������
}

sub Check_Traf
{
 my($dserver,$nserver);
 if( ($t-$T_got_traf)>60 )
 {  # ����� ����� ���� ���� ��������� ����� � �������� �� ������������
    $V && &debug("*** ����� ����������� ������ ����������, �������� ��������� �� ����������.");
    $Traf_Act=2;
    return; 
 }
 $When_get_traf=$t+5;	# ������ 5 ��� ��������� ������ �� ��� ����� � ��������
 foreach $nserver (keys %Collectors)
 {
    ($dserver)=split /\-/,$Collectors{$nserver};
    return unless -e "$Sql_dir/$nserver-$T_got_traf";
 }
 $V && &debug("*** ��� ����� ���������� ����������. ���������� ��������.");
 $When_get_traf=$t;
 $Traf_Act=2;		# ��� ����� � �������� ��� ������������, ��������� ���� �������
}

# --------------------------------------------------------
#               ������� � ������ �������
# --------------------------------------------------------
sub Count_Traf
{
 $V && &debug("*** ������ ������� �������.");
 @SaveTrf=();
 $dbh or &ConnectToDB;
 if( !$dbh && ++$Traf_Act<4 )
 {  # �������� ��������� ���� � ��, ���� ������ �� ����� ������
    $V && &debug("��� ���������� � ��. ������ �� ���� $T_got_traf ��������� ���������� ����� ������.");
    $When_get_traf=$t+60;
    return;
 }

 $When_get_traf=$T_got_traf+$Kern_t_traf;
 $Traf_Act=0;			# ��������� ���� - ��������� ������� �� �����������

 if( !$dbh )
 {
    $V && &debug("��� ���������� � ��. ������ �� ���� $T_got_traf �� ���������.");
    &ToLog("��� ���������� � ��. ������ �� ������� ���� �������� � ������ � ������: �����_����������-$T_got_traf.",'!!');
    return;
 }

 my($bytes,$cls,$day_now,$h,$hour,$id,$i1,$i2,$i3,$i4,$iface,$intf,$ip,$ip1,$ip2,$ip_raw,$j,$line,$mId,$mon_now);
 my($paket,$port1,$port2,$proto,$p,$pr,$pre_cls,$rows,$server,$t0,$t_traf,$when_need_auth,$year_now);

 @Sql_tune_stat=();		# ���������� ���������� �������� � ����������� �� �� �����, ��� ��� ������� sql

 $h=localtime($T_got_traf);
 ($day_now,$mon_now,$year_now,$hour)=($h->mday,$h->mon,$h->year,$h->hour);
 $h=($year_now+1900).'x'.($mon_now+1).'x'.$day_now;  
 my $z_traf_tbl="z$h";		# ������� ����������� ������� �������� ���
 my $x_traf_tbl="x$h";		# ������� �������
 my $y_traf_tbl="y$h";		# ������� ������� �������� �������
 my $v_traf_tbl="v$h";		# ������� ���������� � �������

 # ����� ����� ������������� insert ����� �������� �������� �������. ���������� $sql� �������������� � �������
 my $sqlv=$sqlx=$sqly=$sqlz=$sqll='';	
 my @l_traf=();			# lost traf
 my @v_traf=();
 my @x_traf=();
 my @y_traf=();
 my @z_traf=();

 $t_traf=$T_got_traf-timelocal(0,0,0,$day_now,$mon_now,$year_now); # ����� ����� �� ������ ���

 my $traflog='';
 my %S=();			# ���������� ��������� ������� ��� ������� �������

 my %has_traf=();		# ������ ip, ������� ����� ������ ���������� ������ � ��
 my %else_ip=();		# ip ������, ������� ��� � �� � ��� ������� ���� ������ � ����� ������������. ��� �.�. `���������� ������`. $else_ip{ip_from-ip_to}.

 my $traf_lines=0;		# ����� � ��������, ��� ����������
 my $traf_lines_bytes='';	# ����� ����� ������, ���������� �� ����������� (��� ����� ���� ��������� ����������, � �� ������ ��������)

 my %in0=();
 my %out0=();
 my %in=();
 my %out=();
 my @lines=();

 my $errors=0;

 $t0=[gettimeofday];		# ������ ������� � ����� �������

 # ��������� �� ���� �����������
 foreach $nserver (keys %Collectors)
 {
   ($dserver,$server)=split /\-/,$Collectors{$nserver};
   $file_name="$Sql_dir/$nserver-$T_got_traf";
   unless (open(F,"<$file_name"))
   {
      $V && &debug("�� ������� ������ �� $server ($dserver).");
      $traflog.="�� ������� ������ �� $server ($dserver).\n";
      $errors++;
      next;
   }
   @lines=<F>;
   close(F);

   $traf_lines_bytes.="$dserver: ".(stat("$file_name"))[7]."\n";
   $V? &debug("$file_name �������� �.� \$V<>0") : unlink $file_name;

   if( $NoNeedTraf{$dserver} )
   {
      $NoNeedTraf{$dserver}=0;
      $V && &debug("�� ������� ������ ������ � $server ($dserver) - ������� � ����������.");
      &ToLog("���� �������� � ������ �� ������� ������ ���������� ������ � �����������. ������ ���������� $server ($dserver) ��������������. ��� ����������� ����� ����� ���������.");
      next;
   }

   %else_ip=();
   $when_need_auth=0;

   foreach $line (@lines)
   {
      if( $when_need_auth--<0 )
      {  # ����������� ������ 30 000 ������������ �����. �� ������������� �� ������� �.� ��� ����� ������������� ������ �������������� �������
         $when_need_auth=30000;
         &Check_auth;
      }
      next if $line!~/^\s*(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+\d+\s+(\d+)(.*)$/o; # ���������������� ������
      ($ip1,$ip2,$bytes,$intf)=($1,$2,$3,$4);
      &debug(sprintf("       %15s -> %15s %8d ���� (%s)",$ip1,$ip2,$bytes,$intf)) if $V && $V++<$debug;
      $traf_lines++;
      $j=-1; # ������� `���� �� ���������� �����������`
      if( $intf )
      {  # ����������� ����� ����������
         (undef,$port1,$port2,$proto,$intf)=split /\s+/,$intf;
         $port2=$port1 if $proto==1; # � icmp ��� ������ � src_port
         # ���� ��������� ����� 1 ��� 2, �� ��� ��������� ��������, ����� �� � ��������� ��������� �������� ������ `� �������` � `�� �������`
         if( $intf eq '1' || $intf eq '2' ) # ������ ($intf==1) �.� ���������� �������� ������������� � ��������
         {
            if( $intf==2 )
            {
               $j=0; # ������ � �������
               ($ip2,$ip1,$port2,$port1)=($ip1,$ip2,$port1,$port2);
            }else
            {
               $j=1; # ������ �� �������
            }
            if( !$Ip_to_id{$ip1} )
            {# ������ ����� ������ �/�� ��������������������� ip. � ������� ���������� ������� �������������� ������ ������ `�� �������`
               $V && $V<$debug && &debug("!!! $ip1 - �� ��������������� � NoDeny. ���������� �������.");
               $j or next;
               $sqll||="INSERT INTO traf_lost (time,`in`,`out`,ip) VALUES";
               &Add_Sql($sqll,\@l_traf,"($T_got_traf,0,$bytes,'$dserver: $ip1-$ip2'),");
               next;
            }
         }
      }    
       else
      { 
         $port1=$port2=$proto=0;
      }

      if( $j<0 )
      {
         if( $Ip_to_id{$ip2} )
         {
            $j=0;
            ($ip2,$ip1,$port2,$port1)=($ip1,$ip2,$port1,$port2);
         }
          elsif( $Ip_to_id{$ip1} )
         {
            $j=1;
         }
          else
         {# ������ �� �/�� �������� � ����
            $V && &debug("��� ip �� ���������������� � NoDeny.");
            ($ip1 eq $ip2) && next;		# �������� �������� ��� �������������
            $else_ip{"$ip1-$ip2"}=1;
            $else_ip{"$ip2-$ip1"} or next;	# ���� �� ������� �������� ������ - �� ���������
            $sqll||="INSERT INTO traf_lost (time,`in`,`out`,ip) VALUES";
            &Add_Sql($sqll,\@l_traf,"($T_got_traf,$bytes,0,'$dserver: $ip2-$ip1'),");
            next;
         }

         next if $Ip_to_iface{$ip1}!~/^(.+)_(.+)$/;# ������������ ��������� ���� ��� ������ ����� ��������� ����������� ������ ip

         next if ($1 ne '*') && $1!=$nserver;	# ������ ��� $ip1 ��������� �� � ����� ���������� 
         $iface=$2;				# ���������, � �������� ��������� $ip1

         if( $intf && $iface ne '*' )
         {
            # ������� �� ���������, ���� �� ��� - ������ ������� �� �����
            $intf=~s/\d+$// if $iface=~s/\*$//; # ������������ ��������� ���� ng*
            next if $iface ne $intf;
         }
      }

      $id=$Ip_to_id{$ip1};
      $S{$id}{bytes}+=$bytes; # ����� ���������� �������, ��������� � ��������
      $S{$id}{$j? 'flows_out' : 'flows_in'}++;

      # �������, ��� ���� ���� � ����� �������� � ���� ��� ������� ���� � ���. ������������ � ���������� ���� - ������, ������� ����������
      # ������ �������, � ���� ����� �������� ������� - ��� ��������� ���������� ����� ����� �������� ������� �� �������� ������.
      $has_traf{$id}+=($bytes||1);

      ($i1,$i2,$i3,$i4)=split /\./,$ip2;
      $ip_raw=pack('CCCC',$i1,$i2,$i3,$i4);

      # ����� ������� ������ ������� ������������ ���� ��� ���������� ��� ��������
      # ������ ��������, ��� ��� ����� ���� ������� � ������� ����������� � ���������������� �� ������ �����
      $pre_cls=$cls=($i1>223 && $i1<240) || $i1==127 || $ip2 eq '255.255.255.255'? 0:1;

      if( defined $CLS{"0-$port2-$ip_raw"} )
      {  # ������� �� ����
         $cls=$CLS{"0-$port2-$ip_raw"};
         $V && $V<$debug && &debug(sprintf("������:%15s    %15s ����� %1d ���� �� ����",$ip1,$ip2,$cls));
      }
       else
      {  # ---  ���� ����������� ������ ������� �� �������� ������� (��� ����� ����������) ---
         $p=0;
         while( defined $b_nets0[$i3][$p] )
         {
            if( ($ip_raw & $b_masks0[$i3][$p]) eq $b_nets0[$i3][$p] && (!$b_port0[$i3][$p] || $b_port0[$i3][$p]==$port2) )
            {
               $cls=$b_classes0[$i3][$p];
               last;
            }
            $p++;
         }
         $CLS{"0-$port2-$ip_raw"}=$cls if (keys %CLS)<=$MaxCashIp;		# ��� �� �������� ���������� ���������� �������
         $V && $V<$debug && &debug(sprintf("������:%15s    %15s ����� %1d",$ip1,$ip2,$cls));
      }

      if( $cls ) {if ($j) {$out0{$id}[$cls]+=$bytes} else {$in0{$id}[$cls]+=$bytes}}

      $pr=$Plan_preset[$Upaket{$id}] || 0;

      if( defined $CLS{"$pr-$port2-$ip_raw"} )
      {
         $cls=$CLS{"$pr-$port2-$ip_raw"};
      }
       else
      {  # --- ���� ����������� ������ ������� �� ������� ������ ������� ---
         $cls=$pre_cls;
         $p=0;
         while( defined ${"b_nets$pr"}[$i3][$p] )
         {
            if( ($ip_raw & ${"b_masks$pr"}[$i3][$p]) eq ${"b_nets$pr"}[$i3][$p] && (!${"b_port$pr"}[$i3][$p] || ${"b_port$pr"}[$i3][$p]==$port2) )
            {
               $cls=${"b_classes$pr"}[$i3][$p];
               last;
            }
            $p++;
         }
         $CLS{"$pr-$port2-$ip_raw"}=$cls if (keys %CLS)<=$MaxCashIp; 
      }

      $cls or next; # ������ 0-�� ����������� �� �����������

      $S{$id}{flows}++;

      if( $Udetail_traf{$id} )
      {  # ��� ����� ip ���������� ��������� ������ ��������
         if (!$UmaxRegFlow{$id} || $S{$id}{flows}<$UmaxRegFlow{$id})
         {
            $ip=($i1 << 24)+($i2 << 16)+($i3 << 8)+$i4;
            $port2=int $port2;
            $sqlz||="INSERT INTO $z_traf_tbl (mid,time,bytes,direction,ip,port,proto) VALUES";
            &Add_Sql($sqlz,\@z_traf,"($id,$t_traf,$bytes,$j,$ip,$port2,$proto),");
            $S{$id}{flows_reg}++;
         }
          elsif( $S{$id}{flows}==$UmaxRegFlow{$id} )
         {
            $S{$id}{overflow}=1;
         }
      }

      next if $cls>8;

      if ($j) {$out{$id}[$cls]+=$bytes} else {$in{$id}[$cls]+=$bytes}
   }
 }

 # --- ������ ������, ���������� �� �����������, �������� ---
 &SaveTrafTime(2,tv_interval($t0));	# ����� ������� �������
 $t0=[gettimeofday];

 $V=!!$V; # ���������� verbose �������

 $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 if( $dbs )
 {
    sleep 1;
    $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 } 

 if( $dbs )
 {  # �������� ������� � ����������� � �������
    $dbs->do("CREATE TABLE IF NOT EXISTS $v_traf_tbl $Slq_Create_VTraf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $z_traf_tbl $Slq_Create_ZTraf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $x_traf_tbl $Slq_Create_Traf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $y_traf_tbl $Slq_Create_Traf_Tbl");
 } 

 &SaveTrafInfo(1,$traf_lines,'���������� ������������ ����� �����������');
 &SaveTrafInfo(8,$traf_lines_bytes,'������ �� �����������, ����');
 $cls=keys %CLS;
 &SaveTrafInfo(5,$cls,'�������� � ���� ip');
 %CLS=() if $cls>$MaxCashIp;		# ��� �������� ���������� ���������� �������, �������

 my $n_overFlows=0; # ����� ���������� ���������� ip, ���������� ����������� ���������� ���������� �������
 my ($sum_inTraf,$sum_outTraf,$start,$end,$k);

 $when_need_auth=0;
 # ������ ������ � ���� � ������� �������� ������� - ��� ��������� ���������� ����� ����� ������������� ������� 
 foreach $id (sort {$has_traf{$b} <=> $has_traf{$a}} keys %has_traf)   
 {
   if( time()>$when_need_auth )
   {
      $when_need_auth=time()+3;	# ������ 3 ������� �����������
      &Check_auth;
   }

   $ip=$Id_to_ip{$id};
   $mId=$Id_to_mId{$id};	# id �������� ������

   $sum_inTraf=$sum_outTraf=0;

   foreach (1..8)
   {
      $IN[$_]=int $in{$id}[$_];
      # ������� ��������� ���� ������� ��������
      $OUT[$_]=$Traf_zero_flush && !$IN[$_]? 0 : int $out{$id}[$_];
      $sum_inTraf+=$IN[$_];
      $sum_outTraf+=$OUT[$_];
      $in{$id}[$_]=$out{$id}[$_]=0;
   }

   if( !$Ufirst_act{$id} && $sum_outTraf )
   {  # ������ ���������� �� ������� �������
      $rows=$dbh->do("INSERT INTO pays SET mid=$id,type=50,category=424,time=$ut");
      $Ufirst_act{$id}=1 if $rows==1;
   }

   if( $Uno_auth{$id} && $sum_outTraf )
   {  # � ������ ��� ����������� ���� ��������� ������
      if( $UstateNew{$id} )
      {  # ������ `�� �����������`. ������ � ����������� ������ ��������� ��� ������ �����������
         $rows=$dbh->do("UPDATE users SET cstate=0 WHERE id=$id LIMIT 1");
         $dbh->do("INSERT INTO pays SET mid=$id,type=50,category=429,time=$ut") if $rows==1;
         $UstateNew{$id}=0 if $rows==1;
      }

      if( $Ustart_day{$mId}<0 )
      {  # ���� ������ ����������� �����
         $Ustart_day{$mId}=$Plan_flags[$Upaket{$mId}]=~/g/? 0 : $day_now; # ���� 'g' ��������� ���� ������ ����������� ����� ���������� � ����
         $rows=$dbh->do("UPDATE users SET start_day=$Ustart_day{$mId} WHERE id=$mId LIMIT 1");
         $dbh->do("INSERT INTO pays SET mid=$mId,type=50,reason='$Ustart_day{$mId}',category=422,time=$ut") if $rows==1;
      }
   }

   # ����� ����������� �� ���������� ������� � ��� ��������� � ������ ��� �� ������������?
   if( $UmaxFlow{$id} && $S{$id}{flows}>$UmaxFlow{$id} && !$Udeny{$id} )
   {
      if( $UoverFlow{$id} )
      {  # ��� ������ ������ ����������, ����� �����������
         $rows=$dbh->do("UPDATE users SET state='off' WHERE id=$id LIMIT 1");
         if( $rows==1 )
         {
            $Udeny{$id}=1;
            $p="������������ $ip �� ������� ���������� ������ ������� �������: $S{$id}{flows} (������� $UmaxFlow{$id})";
            &ToLog($p,'!');
            $traflog.="$p\n";
            $dbh->do("INSERT INTO pays SET mid=$mId,type=50,category=425,reason='$ip:$S{$id}{flows}:$UmaxFlow{$id}',time=$ut");
         }
      }else
      {
         $UoverFlow{$id}++;	# ������� ������ ������ ���������� �������
         $n_overFlows++;	# ��� ����������
      }
   }else
   {
      $UoverFlow{$id}=0;
   }

   # �������������� ���������� � �������
   $sqlv||="INSERT INTO $v_traf_tbl (time,mid,flows_in,flows_out,flows_reg,bytes,bytes_reg,detail) VALUES";
   &Add_Sql($sqlv,\@v_traf,"($t_traf,$id,".int($S{$id}{flows_in}).','.int($S{$id}{flows_out}).','.int($S{$id}{flows_reg}).','.int($S{$id}{bytes}).
     ','.($sum_inTraf+$sum_outTraf).','.($S{$id}{overflow}? 2 : $Udetail_traf{$id}? 1 : 0).'),');

   ($sum_inTraf || $sum_outTraf) or next;

   $p=$Upaket{$mId};
   {
    $time_paket[$p] or last;
    # � ������ ������ ���������� ������ �������, ����� ����������� ��������:
    $k=$Plan_k[$p];
    last if $k<=0; # <0 - ���������� �������, 0 - ������� ��������
    $start=$Plan_start_hour[$p];
    $end=$Plan_end_hour[$p];
    last unless ( ($start>$end && ($hour>=$start || $hour<$end)) || ($start<$end && $hour>=$start && $hour<$end) );
    if( $k==1 )
    {  # � �������� ���������������� ������
       if( $Traf_change_dir )
       {
          $IN[2]=$IN[1];
          $OUT[2]=$OUT[1];
          $IN[4]=$IN[3];
          $OUT[4]=$OUT[3];
          $IN[1]=$IN[3]=$OUT[1]=$OUT[3]=0;
          last;
       }
       $IN[3]=$IN[1];
       $OUT[3]=$OUT[1];
       $IN[4]=$IN[2];
       $OUT[4]=$OUT[2];
       $IN[1]=$IN[2]=$OUT[1]=$OUT[2]=0;
       last;
    }
    # ��������� ������� �� �����������
    foreach( 1..4 )
    {
       $IN[$_]=(int $IN[$_]*$k) || 1 if $IN[$_];
       $OUT[$_]=(int $OUT[$_]*$k) || 1 if $OUT[$_];
    }
   }

   foreach $i (1..7)
   {
      next unless $IN[$i]+$OUT[$i];
      if( $ModTraf{$mId}{$i} )
      {  # ������-����� ��������� ������ ����������� $i ���������������� �� ����������� 8
         $IN[8]+=$IN[$i];
         $IN[$i]=0;
         $OUT[8]+=$OUT[$i];
         $OUT[$i]=0;
      }
   }

   foreach $i (1..8)
   {
      next unless $IN[$i]+$OUT[$i];
      $sqlx||="INSERT INTO $x_traf_tbl (mid,class,time,`in`,`out`) VALUES";
      &Add_Sql($sqlx,\@x_traf,"($id,$i,$T_got_traf,$IN[$i],$OUT[$i]),");
   }

   $IN[8]+=$IN[5]+$IN[6]+$IN[7];
   $OUT[8]+=$OUT[5]+$OUT[6]+$OUT[7];

   # ���������� ������ ������� ��� �������� ������ ������� �������
   $rows=$dbh->do("UPDATE users_trf SET ".
       "in1=in1+$IN[1],out1=out1+$OUT[1],".
       "in2=in2+$IN[2],out2=out2+$OUT[2],".
       "in3=in3+$IN[3],out3=out3+$OUT[3],".
       "in4=in4+$IN[4],out4=out4+$OUT[4] ".
      "WHERE uid=$mId LIMIT 1");

   $dbh->do("INSERT INTO users_trf SET uid=$mId,in1=$IN[1],out1=$OUT[1],in2=$IN[2],out2=$OUT[2],in3=$IN[3],out3=$OUT[3],in4=$IN[4],out4=$OUT[4]") if $rows<1;

   &CountMoney($id);
 }

 &SaveTrafTime(3,tv_interval($t0));
 $t0=[gettimeofday];
 $n_overFlows && &SaveTrafInfo(10,$n_overFlows,'���������� �������');
 # ������� ������ ������ ������� �����
 &Get_Traf_From_Db;

 &SaveTrafTime(4,tv_interval($t0));
 $t0=[gettimeofday];

 &SaveTrafTime(9,tv_interval($t0));
 $t0=[gettimeofday];

 # ��������� ���� �� �������� �������
 foreach $id (sort {$has_traf{$b} <=> $has_traf{$a}} keys %has_traf)
 {
    for $cls (1..8)
    {
       $in=$in0{$id}[$cls]||0;
       $out=$out0{$id}[$cls]||0;
       next if !$in && !$out;
       $sqly||="INSERT INTO $y_traf_tbl (mid,class,time,`in`,`out`) VALUES";
       &Add_Sql($sqly,\@y_traf,"($id,$cls,$T_got_traf,$in,$out),");
    }
 }   

 &Final_Sql($sqlv,\@v_traf);
 &Final_Sql($sqlx,\@x_traf);
 &Final_Sql($sqly,\@y_traf);
 &Final_Sql($sqlz,\@z_traf);
 &Final_Sql($sqll,\@l_traf);

 &Check_auth;
 $dbh->do("INSERT INTO sat_log SET sat_id=0,mod_id=0,time=$ut,info='$traflog',error=$errors"); # ������������ errors ������������� � 255, 255 ������ ��� ������ ����� �����?

 @SaveTrf=(@v_traf,1,@y_traf,2,@x_traf,3,@z_traf,4,@l_traf,5);
 # ���������� sql, ������� ���������� ����� ��������� (��� ����������� % ����������). $#SaveTrf ��� ������ ���������� ��������, �.�. ���� +1 ���� �������� ���-��
 $SafeTrafSqls=$#SaveTrf+1;
 $t_start_save_trf=[gettimeofday];
}

# =======================================================

sub SaveTrf
{
 $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 if( !$dbs )
 {
    $V && &debug("������ ���������� � $DSS");
    if ($ErrorDbs++>5)
    {  # �������� �������� ������ ���� ����� ������, ����� �� ���������� � ��� �����������
       $ErrorDbs=0;
       &SaveTrafTime(23,$#SaveTrf); # ������� � ���������� ������� sql-�������� �� ��������
       $V && &debug("����� ������� ���������� ��������� ����������. $#SaveTrf sql-�������� �� ���������.");
       @SaveTrf=();
       return;
    } 
    sleep 1; # ��������� ����� �� ����� ����������� � ��
    return;
 } 

 $t_for_save=5; # 5 ������ �� ������
 while( ($sql=shift @SaveTrf) && $t_for_save>0 )
 {
    if (length($sql)==1)
    {  # ���, ���������� ����� ��� ������� ����� ������������ � ������ ������
       &SaveTrafInfo(29,$sql);
       next;
    }
    $t0_sql=[gettimeofday];
    $rows=$dbs->do($sql);
    $t0_sql=tv_interval($t0_sql);
    $t_for_save-=$t0_sql;
    # ��� ���������� ����� ���������� ������� � ����������� �� �����
    $_=int(length($sql)/1000);
    $Sql_tune_stat[$_][0]+=$t0_sql;
    $Sql_tune_stat[$_][1]++;
    $Sql_tune_stat[$_][2]+=$rows;
    last unless $rows;
 } 

 if( $SafeTrafSqls )
 {  # ������� ���������� sql. ������ ��������, ��� ����� @SaveTrf ������, �� $#SaveTrf=-1, ������� ���� +1
    $_=sprintf("%.1f",($SafeTrafSqls-$#SaveTrf-1)*100/$SafeTrafSqls);
    $rows=&sqldo("UPDATE traf_info SET data1='$_' WHERE time=$T_got_traf AND cod=14",'������� ���������� ������ �������');
    $rows && $rows<1 && &sqldo("INSERT INTO traf_info SET time=$T_got_traf,cod=14,data1='$_'");
 }

 return if $#SaveTrf>=0;

 &SaveTrafTime(15,tv_interval($t_start_save_trf)); # ����� ������ ����������� �������

 if( $Sql_tuning )
 {  # ���������� ���������� �� ����� sql-��������
    $out='';
    $sp=' ' x 13;
    $t_sum=0; # ������ ��� ����� ������ ����� ����� ������ ������� ��� tv_interval($t_start_save_trf), �.�. ����������� ������ ����� �� sql
    foreach( 0..20 )
    {
       ($t_sql,$n_sql,$rows)=@{$Sql_tune_stat[$_]}[0..2];# (����� ���������� ��������, ���������� ��������, �����)
       next if !$n_sql || !$t_sql;
       $len_sql=($_*1000)||1;
       $effect=int($rows/$t_sql);	# ������������� �������: �����/����� ����������
       $t_for_1sql=sprintf("%.5f",$t_sql/$n_sql);
       $t_sum+=$t_sql;
       $t_sql=sprintf("%.3f",$t_sql);
       $out.=substr("$sp$len_sql..${_}999|",-13,13).
             substr("$sp$n_sql|",-10,10).
             substr("$sp$rows|",-10,10).
             substr("$sp$t_sql|",-10,10).
             substr("$sp$t_for_1sql|",-13,13).
             substr("$sp$effect|",-10,10)."\n";
    }
    # ������� � ����� ����� �������� ��� ����������� ����� <pre>...</pre>
    &SaveTrafInfo(30,"   ����� sql|   ���-��|    �����|�����,���|�����/������|   ������|\n$out ����� ����� ���������� ���� ��������: $t_sum\n");
 }
 $ErrorDbs=0;
}

# ========
sub SaveNet
{
 my($preset,$net,$net_port,$net_class,$default_mask)=@_;
 my($net_ip_raw,$net_mask,$net_mask_raw,$oct3);
 if( $net!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)(\/\d+)?$/ )
 {
    $Report.="���� `$net` � ������� ����������� ������ �������. ������ `xx.xx.xx.xx/yy` ���� `xx.xx.xx.xx`. ������ ���� ������������\n";
    &ToLog("��������������: ���� `$net` � ������� ����������� ������ �������. ������ `xx.xx.xx.xx/yy` ���� `xx.xx.xx.xx`. ������ ���� ������������",'!!');
    return;
 }

 $net_ip_raw=pack('CCCC',$1,$2,$3,$4);
 $oct3=$3;

 if( defined $5 )
 {
    $net_mask=$5;
    $net_mask=~s|/||;
 }else
 {
    $net_mask=$default_mask;
    $net.="/$net_mask";
 } 

 $net_mask_raw=pack('B32',1 x $net_mask,0 x (32-$net_mask));
 if( ($net_ip_raw & $net_mask_raw) ne $net_ip_raw )
 {
    $_="� ������� ����������� ���� `$net` ������� ������� (� �������� ���� ����� ���� �������� ��������� ���� ����)";
    $Report.="$_\n";
    &ToLog("��������������: $_",'!!');
 }

 # �������� �������������� �� 3�� ������ �������
 $_=$net_mask>23? 1 : $net_mask<17? 256 : 2**(24-$net_mask); # ���-�� ��������� 3�� ������ (�������� ��� ���� /16 ��������� 256)
 while( $_-- )
 {
    push @{${"b_nets$preset"}[$oct3]},$net_ip_raw;
    push @{${"b_masks$preset"}[$oct3]},$net_mask_raw;
    push @{${"b_classes$preset"}[$oct3]},$net_class;
    push @{${"b_port$preset"}[$oct3]},$net_port;
    $oct3++;
 }
}

# =============================================================
# �������������� ������� ���� ����� � HEX ��� � �������� ������
# =============================================================
sub MakeHexNets
{
 my($class,$default_mask,$infile,$fname,$fullname,$line,$net,$p,$port,$preset,$sth);
 my @f;
 $Need_nets_reload=0;
 $Report.='��������� ���������� ���������� ������ �����������: ';
 # ���������������, ����� ���� ����� mysql ���������, � $dbh ����� �������, �� �� �� ������� ���� � ����� ��������� ��������
 &ConnectToDB;
 if( !$dbh )
 {
    &ToLog("������ ����� � �� ������� �� �������� �.�. ��� ���������� � ��",'!!');
    $Report.="������ - ��� ���������� � ��\n";
    return;
 }

 $sth=$dbh->prepare("SELECT * FROM nets WHERE priority>0 ORDER BY preset,priority");
 unless ($sth->execute)
 {
    &ToLog("������ ����� � �� ������� �� �������� - ������ sql-�������. �������� ������� ���������� � ��",'!!');
    $Report.="������ sql-�������. �������� ������� ���������� � ��\n";
    return;
 }

 foreach (0..100)
 {  # $_ - ����� �������
    @{"b_nets$_"}=();		# ����
    @{"b_masks$_"}=();		# �����
    @{"b_classes$_"}=();	# ������ �����
    @{"b_port$_"}=();		# ����
 }

 while( $p=$sth->fetchrow_hashref )
 {
    $net=$p->{net};
    $class=$p->{class};
    $preset=$p->{preset};
    $port=$p->{port};

    if( $net!~/^\s*file:\s*(.+)$/i )
    {
       &SaveNet($preset,$net,$port,$class,32);
       next;
    } 

    # �������� ������ �� �����
    $fname=$1;
    $fullname=$fname=~/^\//? $fname : "$Program_dir/$fname";
    unless (open(FL,"<$fullname"))
    {
       &ToLog("���� $fullname, ��������� � �������� ������ �����, �� ����������� �� ������!",'!!');
       $Report.="���� $fullname, ��������� � �������� ������ �����, �� ����������� �� ������!\n";
       next;
    }
    @f=<FL>;
    close(FL);
    $infile='';
    $default_mask=$port||32; # ���� ����� ���� �� �������, �� ����� ���� �� ��������� /32 ���� �����, ������� ������� � ���� '����', �������� ��� UA-IX ������ ���� /24
    foreach $line (@f)
    {
       next if $line!~/^\d/o || $line!~/^([^\s]+)\s*(.*)$/o;
       $port=int $2; # ����������� int �.�. $2 ����� ���� �����������
       $net=$1;
       $infile.=$net;
       $infile.="/$default_mask" if $net!~/\/\d+$/;
       $infile.=" $port" if $port;
       $infile.="\n";
       &SaveNet($preset,$net,$port,$class,$default_mask);
    }
    $fname=~s|\\|\\\\|g;
    $fname=~s|'|\\'|g;
    $infile=~s|\\|\\\\|g;
    $infile=~s|'|\\'|g;
    $dbh->do("REPLACE INTO files SET data='$infile',name='$fname'");   
 }
 %CLS=(); # ������� ��� ip
 $Report.="����������� ���������\n";
}

# -------------------------------------------
#  �������� ���� ����� ��������� �� ��������
# -------------------------------------------
sub Check_unauth
{
 &Start_day if $Start_day_now!=localtime($t)->mday;

 $When_block_unauth=$t+$Kern_t_chk_auth;	# ����� ����� ��������� ����. ���
 foreach $id (grep{$t>$UtimeBlock{$_} && ($Uauth{$_} ne 'no')} @all)
 {  # ������� ����� ��� ����������� - ������� ����������������
    $AuthQueue{$id}[0]='no';			# ���� auth ��� ������� users
    $AuthQueue{$id}[1]=0;			# ��� `����������` ��� ������� �������
    $AuthQueue{$id}[2]=0;			# ��� `������ ��������` ��� ������� users_trf
    $AuthQueue{$id}[3]=$t;
 }

 &SetAuthInDB;

 # ���� ������ ����� �������� � ���������� ������ ��������
 $t<$When_user_reload && return;
 $When_user_reload=$t+$Kern_t_usr_reload;
 &Get_user_info;
}

# -------------------------------------------
#  ���������� � 0 ����� 0 ����� ������� ���
# ��������:
# - �������� ���������� �� �������, ���� � 0:0 �����
#   ����������� �����-���� ������� (������ ������� � �.�)
# - ��� ������� nodeny.pl ����� ���������� ������ &Start_day
#   ��� ����������� �� ������� ������� � ����������� ��
#   &Start_day � ���� ����!
# ------------------------------------------- 
sub Start_day
{
 # $Start_day_now �� ������ ���� �� �������� ���, ��� ��������
 $dbh or &ConnectToDB;
 $dbh or return;
 $h=localtime($t);
 $day_now=$h->mday;
 $mon_now=$h->mon+1;
 $year_now=$h->year+1900;
 # ��������������� ����� ������ �����������
 $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=431 AND reason LIKE '$day_now.$mon_now.$year_now:%'");
 $sth->execute or return;
 while( $p=$sth->fetchrow_hashref )
 {
    $p->{reason}=~/:(\d+)/ or next;
    $paket=$1;
    $mid=$p->{mid};
    $id=$p->{id};
    my $Mid=$mid||$id;
    $rows=$dbh->do("UPDATE users SET paket=$paket WHERE id=$Mid OR mid=$Mid");
    # $rows=$dbh->do("UPDATE users SET paket=$paket WHERE id=$mid LIMIT 1");  http://forum.nodeny.com.ua/index.php?topic=1644.0
    # thanx 0xbad0c0d3
    
    if( !$rows )
    {
       &ToLog("�� ������� �������� ����� ������� id=$mid",'!');
       next;
    }
    if( $rows<0 )
    {  # ������� ��� � ����, ������� ������� ��� ���������
       $dbh->do("UPDATE pays SET category=599 WHERE id=$id AND type=50 AND category=431 LIMIT 1");
       &ToLog("������ id=$id � ������� pays �������� ��� ���������������� �.�. ������� � �������������� �������� $mid",'!');
       next;
    }
    $rows=$dbh->do("DELETE FROM pays WHERE id=$id AND type=50 AND category=431 LIMIT 1");
    &ToLog("�� ������� � ������� pays `��������������� ����� ������` - � ������� id=$mid ������� ����� �� � $paket");
    $rows or next; # �� $rows<1 - ������� ����� ���� ������� �����������
    $reason="���������� ����� � $paket ��� ��������� ������� `��������������� ����� ������` ������ admin_id=".$p->{admin_id}.", �����: ".&the_time($p->{time});
    &SaveEventToDb($reason,410,$mid);
 }
 &Get_user_info;
 $Start_day_now=$day_now;
}
