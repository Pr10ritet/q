#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
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
$Sleep_error=600;	# количество секунд, которое ждем в случае неудачного старта, после чего будет рестарт
$nowait_opt='-nowait';	# если при запуске будет эта опция, то ожидания $Sleep_error не будет
$notraf_opt='-notraf';	# если при запуске будет эта опция, то первый, полученный трафик от коллекторов, будет проигнорирован

# Шаблон таблицы детализированного трафика
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

# Шаблон таблицы трафика
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

# Шаблон таблицы информации о трафике
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

# Шаблон таблицы суточного трафика
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

# условие, по которому считаем, что клиент во включенном состоянии: неблокируемая авторизация или `всегда онлайн`
$now_on_sql="(auth IN ('on','ong','off') OR lstate=1) AND state='on'";

# $Udeny{$id} установлен, если доступ для $id запрещен жестко, т.е в БД поле state='off'
# $Uauth{$id} состояние авторизации записи с id=$id:
#   no - не авторизован 
#   on - авторизован в режиме `включить все`, претензий нет
#   off - авторизован в режиме `только сеть`, претензий нет
#   ong - авторизован в режиме `сети класса 2`, претензий нет
#   цифра - авторизован, но есть претензии и доступ закрыт

# ======================================================================
#				Начало
# ======================================================================

our($dbh,$debug,$V,$Program_dir);

$debug=10;		# лимит на количество записей при $V

%arg=map { $_=>1 } @ARGV;
$V=!!$arg{'-v'};	# $V=1 - вывод действий `на экран`

$Program_dir=$FindBin::Bin;
if( !$V )
{
  $t=localtime();
  $temp_errlog=sprintf("%s/nodeny_error_%02d.%02d.%04d.log",$Program_dir,$t->mday,$t->mon+1,$t->year+1900);
  open(STDERR,">$temp_errlog");
  open(STDOUT,">$temp_errlog");
  open(STDIN,"</dev/null");
}

$Err_mess_reconnect="Через $Sleep_error секунд будет повторная попытка запуска ядра";

$Config_file="$Program_dir/$Config";
(-e $Config_file) or &Print_Error_n_Exit("ERROR LOADING CONFIG $Config_file! NoDeny is stopped");
require $Config_file;

&Print_Error_n_Exit("DATA ERROR IN CONFIG $Config_file! NoDeny is stopped") if !$Db_name || !$Db_server || !$Db_user;

$Config_file="$Program_dir/noconf.pl"; # конфиг, полученный из БД при прошлом запуске

$Db_mysql_connect_timeout=1 if $Db_mysql_connect_timeout<1;

$DSN="DBI:mysql:database=$Db_name;host=$Db_server;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
if( !$dbh )
{  # попробуем из старого конфига получить email админа и отослать ему письмо о критической ситуации
   &Send_err_mess('Старт ядра NoDeny невозможен т.к. не удалось соединиться с основной базой данных');
   &Print_Error_n_Exit("ERROR CONNECTING TO DB $Db_name ON HOST $Db_server! NoDeny is stopped");
}

&SetCharSet($dbh);

$ut='unix_timestamp()';
# Получим последний по времени конфиг и время на сервере основной БД
$sqlc="SELECT *,$ut AS t FROM config ORDER BY time DESC LIMIT 1";
$sth=$dbh->prepare($sqlc);
$sth->execute;
unless( $p=$sth->fetchrow_hashref )
{
   &Send_err_mess('Старт ядра NoDeny невозможен т.к. не удалось получить конфиг из основной базы данных');
   &Print_Error_n_Exit("ERROR GETTING CONFIG FROM DB $Db_name ON HOST $Db_server! NoDeny is stopped"); 
}

$tt=$p->{t}-time; # разница во времени на текущем сервере и на сервере основной бд
$sqlc=~s/.+\s([^\s].+)\s[^\s]+$/\040$1\040\063\060\060/; # метка конфига

unless( open(F,">$Config_file") )
{
   &Send_err_mess('Старт ядра NoDeny невозможен т.к. не удалось записать на диск полученный из БД конфиг');
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
&ToLog('====== -  СТАРТ ЯДРА NODENY - ======','!');
$tt>600 && &ToLog("Разница во времени на текущем и сервере основной базы данных составляет $tt сек, рекомендуем исправить время на текущем сервере и перезапустить ядро",'!'); # разница больше 10 минут

$nomoney_pl="$Nodeny_dir/nomoney.pl";
unless( -e $nomoney_pl )
{
   &ToLog("Отсутствует модуль денежных расчетов $nomoney_pl! Запуск ядра NoDeny остановлен.",'!');
   &Smtp("Старт ядра NoDeny невозможен т.к. отсутствует модуль денежных расчетов $nomoney_pl! $Err_mess_reconnect");
   sleep $Sleep_error;
   exit 0;
}

$VER=0;
require $nomoney_pl;
if( $VER!=$VER_chk )
{
   &ToLog("Версия модуля $nomoney_pl не соответствует версии ядра! Запуск ядра NoDeny остановлен.",'!');
   &Smtp("Старт ядра NoDeny невозможен т.к. версия модуля $nomoney_pl не соответствует версии ядра! $Err_mess_reconnect");
   sleep $Sleep_error;
   exit 0;
}

$Title_net=~s|\000||g;
$gr=~s|\000||g;
$kb=1000 if $kb<1;
$mb=$kb*$kb;
$Sql_tuning=0;
@Sql_lens=(900,1900,2900,4900,6900,7900,9900,11900,14900,17900);	# для тюнинга максимальные длины sql-запросов, будут циклически меняться
$MaxSqlLen=5000 if $MaxSqlLen<500;	# максимальная принятая нами длина sql запроса в байтах
$MaxSqlLenNow=$MaxSqlLen;
$MaxCashIp||=1000000;
$Need_restart=0;			# >0 - надо сделать рестарт
$Need_tarif_reload=0;			# >0 - надо перечитать тарифы
$Max_tarif=$m_tarif || 100;
$T_db_error=[0,0];
&Tarif_Reload;

if( !$Tarif_loaded )
{
   &ToLog("Не удалось загрузить тарифы. Запуск NoDeny остановлен т.к. ядро не сможет блокировать абонентов по балансу, ".
     "а также будет недостаточно данных для классификации трафика по направлениям. Через 3 минуты будет произведен повторный запуск ядра",'!!');
   &Smtp("Старт ядра NoDeny остановлен т.к не удалось загрузить тарифы. Через 3 минуты будет произведен повторный запуск ядра");
   sleep 360;
   exit 0;
}

$Sql_dir="$Program_dir/sql";
unless(-d $Sql_dir)
{
   (-d $Sql_dir) or &ToLog("Отсутствует каталог $Sql_dir. Создаем...",'!');
   system("mkdir $Sql_dir");
}

$DSS="DBI:mysql:database=$Db_name;host=$Db_server_2;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$DSNA="DBI:mysql:database=$Db_name;host=$Db_server_a;mysql_connect_timeout=$Db_mysql_connect_timeout;";
$s_usr="SELECT * FROM user_grp";

$Report="Старт ядра NoDeny.\n";

%NoNeedTraf=();
foreach (keys %Collectors)
{
   if ($Collectors{$_}!~/^\s*([^\-]+)\-/)
   {
      $Collectors{$_}="127.0.0.1-ipcad:error!";
   }else 
   {
      $NoNeedTraf{$1}=$arg{$notraf_opt}; # нужно ли учитывать трафик в первый срез
      $Collectors{$_}=~s|^\s+||;
   }
}
$Report.="Статистика трафика не снимается - не указано ни одного сервера с коллектором трафика.\n" unless keys %Collectors;

&MakeHexNets;

# преобразуем адреса клиентских сетей в HEX вид с двоичной маской
@l_ints=@l_net=@l_mask=();
foreach $i (1..100)
{
   $l_nets{$i} or next;
   if( $l_nets{$i}!~/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)-\s*(.+)$/ )
   {
      &ToLog("Предупреждение: Клиентская сеть '$l_nets{$i}' указана неверно. Сеть должна быть представлена в виде xx.xx.xx.xx/xx-интерфейс",'!!');
      $Report.="Ошибка в конфиге: клиентская сеть №$i задана неверно.\n";
      next;
   }
   push @l_ints,$6;
   $net_mask=$5;
   $net_ip_raw=pack('CCCC',$1,$2,$3,$4);
   $net_mask_raw=pack('B32',(1 x $net_mask),(0 x (32-$net_mask)));
   if( ($net_ip_raw & $net_mask_raw) ne $net_ip_raw )
   {
      &ToLog("Предупреждение: Клиентская сеть '$l_nets{$i}' задана неверно.",'!!');
      $Report.="Ошибка в конфиге: клиентская сеть №$i задана неверно\n";
   }
   push @l_net,$net_ip_raw;
   push @l_mask,$net_mask_raw;
}

# Если текущий запуск ядра является его рестартом, то в БД наверняка для некоторых клиентов установлена авторизация.
# Признак авторизации пока не будем убирать чтоб им не блокировать доступ, однако через определенный промежуток времени
# уберем для тех, кто так и не авторизовался
$When_set_unauth=time+$tt+20;	# когда удалять признак авторизованности у клиентов, которые после рестарта не авторизовались

# Обновим таблицу users_trf по значениям таблицы users: для всех авторизованных и незаблокированных установим поле now_on=1 -
# при старте ядра некоторые записи могут помечены как авторизованные, некоторое время не будем убирать авторизацию
if( $dbh )
{
   $dbh->do("UPDATE users_trf SET now_on=1 WHERE uid IN (SELECT id FROM users WHERE $now_on_sql)");
   $dbh->do("UPDATE users_trf SET now_on=0 WHERE uid IN (SELECT id FROM users WHERE NOT($now_on_sql))");
}
$s_usr=~/_grp/;
$s_usr="$`s";
$s_usr.=' ORDER BY '.($sort_order_id? 'id' : 'mid');
$Report.=&Get_user_info; # Получим список клиентов и их данные из БД

&ToLog("$ULoadStat{all_users} записей в базе и $ULoadStat{deny_users} доступ в инет блокирован, $ULoadStat{noauth_users} не нужна авторизация");
&ToLog("Для $ULoadStat{dtraf_users} записей включен режим детального сохранения трафика.") if $ULoadStat{dtraf_users};

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
$When_reconect_db_auth=0;		# когда соединится с базой авторизации. 0 - сейчас же
$When_block_unauth=$t+30;		# когда нужно проверять отключать ли по таймауту (через 30 сек)
$When_user_reload=$t+80;		# когда обновлять инфу о юзерах (не меньше +45)
$When_get_traf=$t+15;			# через 15 сек снимем показания трафика
$When_Periodic_service=$t+60*60;	# когда выполнять сервисные функции
$When_reget_time=0;			# когда обновлять разницу во времени на текущем сервере и на сервере БД
$Reload_Nets_Time*=60;			# период автоматического обновления списка сетей переведем в секунды
$When_Reload_Nets=$t+$Reload_Nets_Time;

@SaveTrf=();
$ErrorDbs=0;
$ErrorDba=0;
$Traf_Act=0;

# -------------------   Основной цикл   --------------------------

while(1)
{
 &Check_auth;

 last if $Need_restart>1;				# жесткий рестарт

 $t=time+$tt;
 &Check_unauth if $t>$When_block_unauth;		# выключение авторизаций по таймауту

 if( $#SaveTrf>=0 )
 {
    &SaveTrf;						# пишем трафик в БД
    next;
 }

 last if $Need_restart;					# мягкий рестарт
 sleep 1;

 {
  # Подкорректируем время т.к время на сервере ядра может постепенно `уходить`, либо даже значительно изменено
  # Обрати внимание, что не должно быть привязки ко времени когда начинать эту проверку:), привязываемся к количеству циклов
  last if --$When_reget_time>0;
  $When_reget_time=5; # 5 циклов ~ 5 сек
  $sth=$dbh->prepare("SELECT $ut AS t");
  last unless $sth->execute;
  last unless ($p=$sth->fetchrow_hashref);
  # разница во времени на текущем сервере и на сервере основной бд
  $t=$tt+time - $p->{t}; 
  last if abs($t)<3;
  # Если разница больше 2 секунд, то слегка подкорректируем на 1 секунду, потом еще на одну и т.д.
  # 2 секунды - подстраховка т.к sql запрос выполняется какое-то время и разница времен может быть иной!
  $h=$tt;
  $tt-=$t<=>0;
  &ToLog("Разница со временем на сервере БД изменилась. Подкорректируем: было $h сек, стало $tt сек")
 }   

 $t=time+$tt;
 $V && &debug($When_get_traf-$t+1);
 
 # Время обсчета трафика. Запустим подпрограмму согласно $Traf_Act
 &{ (\&Request_Traf,\&Check_Traf,\&Count_Traf,\&Count_Traf)[$Traf_Act] } if $t>$When_get_traf;

 # Время выполнить сервисные функции (чистка логов и т.д.)
 &Periodic_service if $t>$When_Periodic_service;

 &Check_auth;

 if( $Need_tarif_reload )
 {  # Перечитаем тарифы
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

 $Nolog && &ToLog(''); # скинем лог в файл если ранее файл был заблокирован
}

&ToLog($Need_restart<3? 'Выход для рестарта' : 'Остановка ядра','!');
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

# Запись в лог
# Если второй параметр определен, то добавляется в начало сообщения
# Вызов с пустым параметром просто скидывает $Nolog в файл
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
 # если лог-файл заблокирован, то $Nolog запишем позже 
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
 # лог-файл сильно большой - ротация
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

# Отправка email админам
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

# Коннект к основной БД. Выход: $dbh
sub ConnectToDB
{
 $dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
 $dbh or return '';
 &SetCharSet($dbh);
}

sub SoftConnectToDB
{# Соединяемся с БД не чаще 5 сек
 return if tv_interval($T_db_error)<5;
 $T_db_error=[gettimeofday];
 &ConnectToDB;
}

# Выполняет sql-запрос (update или insert), если не выполнен (mysql gone away) - переконнект и повторная попытка
# Возвращает количество обновленных строк:
#	undef	- ошибка при выполнении
#	0E0	- 0 строк
#	число	- число строк
# Внимание: в результате ошибок $dbh может стать неопределенным
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

# Запись события в таблицу событий
# Вход: текст события, [категория], [id клиента]
sub SaveEventToDb
{
 my $mess=$_[0];
 my $category=$_[1]||'480'; # 480 - `сообщение ядра`
 my $mid=int $_[2];
 $mess=~s|\\|\\\\|g;
 $mess=~s|'|\\'|g;
 &sqldo("INSERT INTO pays SET mid=$mid,cash=0,type=50,category=$category,reason='$mess',time=$ut");
}

sub Tarif_Reload
{
 $dbh or &ConnectToDB;
 $dbh or return;
 &TarifReload; # из nomoney.pl
 &sqldo("UPDATE pays SET category=472 WHERE mid=0 AND type=50 AND category=471",'Установим признак `обновили тарифы`');
 # без LIMIT 1 ! Если пакеты предусматривают умножение трафика на коэффициент в определенное время суток -
 # сформируем массив $time_paket[пакет]=1, если пакет предусматривает умножение
 foreach( 1..$Max_tarif )
 {  # $Plan_k[$_] по совместительству коэфф.умножения, когда он больше 0
    $time_paket[$_]=$Plan_start_hour[$_]!=$Plan_end_hour[$_] && $Plan_k[$_]>0? 1:0;
 }
}

# ==========================================================
# На основе хеша %AuthQueue
# - установка в таблице users состояния авторизации клиентов
# - запись в таблицу логинов
# - установка состояния now_on в таблице users_trf
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
    next if ($Uauth{$id} eq $st) && !$err; # Текущее состояние авторизации такое же как и заказанное и не было ошибок записи текущего состояния
    $Uauth{$id}=$st;
    unless( $err )
    {  # если была ошибка - в логи не пишем - использовались групповые запросы
       $sql.="($id,$cod,$time),";
       if ($i++>50)
       {  # формируем групповые insert
          $i=0;
          chop $sql;
          &sqldo("$insert $sql");
          $sql='';
       }
    }
    $now_on? ($sql1.="$id,") : ($sql0.="$id,"); # скобки не убирать. $err не имеет значение - групповой запрос не insert, а update 
    next if &sqldo("UPDATE users SET auth='$st' WHERE id=$id LIMIT 1");
    @{$f{$id}}=($st,$cod,$now_on,$time,1);
 }

 if ($sql)
 {
    chop $sql;
    &sqldo("$insert $sql",'Записи о текущих авторизациях');
 }

 chop $sql0;
 chop $sql1;
 $sql0 && &sqldo("UPDATE users_trf SET now_on=0 WHERE uid IN ($sql0)");
 $sql1 && &sqldo("UPDATE users_trf SET now_on=1 WHERE uid IN ($sql1)");

 %AuthQueue=%f;
}


# Установка в таблице users_trf текущих данных клиента
# Вход:
#  0 - id основной записи
#  1 - часть sql-запроса
sub SetUserInfoInDb
{
 my ($id,$sql)=@_;
 $id or return;
 my $rows=&sqldo("UPDATE users_trf SET $sql WHERE uid=$id LIMIT 1");
 return($rows) if $rows==1 || !$rows; # если произошло обновление (строка есть в базе) или ошибка соединения с бд
 return(&sqldo("INSERT INTO users_trf SET $sql,uid=$id","В таблице users_trf нет данных по клиенту $id, создаем"));
}


# 1) Подсчет денежного снятия с выбранной записи,
# 2) Запись результирующего трафика в таблицу users_trf
# 3) Блокировка записи если превышены лимиты
# Вход:
#  0 - id
# Выход:
#  0 - код блокировки учетной записи:
#	1 - превышен лимит трафика
#	2 - превышен лимит задолженности
#	4 - по времени суток
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
 # Вычислим баланс с учетом дня последнего платежа $Plan_got_money_day
 $mercy_balance=$day >= $Plan_got_money_day? $Ubalance{$mId}-$money : $over_cmp? $Ubalance{$mId}-$money_over : $Ubalance{$mId};
 return $block_cod if $mercy_balance>=$Ulimit_balance{$mId};
 return 2 if $Udeny{$id}; # 2 - денежная переработка
 # не будем спешить отключать, могла быть ситуация:
 #  1) клиент не авторизован и в незаблокированном состоянии хотя баланс отрицательный. После &Get_user_info у нас эти данные.
 #  2) клиент пополняет счет, баланс становится положительным
 #  3) клиент авторизуется
 #  4) мы считаем $mercy_balance по старым данным и поскольку запись светится как незаблокированная ($Udeny{$id}=0), то вырубаем клиента
 # Для перестраховки получим баланс клиента, возможно он изменился
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
 &ToLog("Запрещен доступ в интернет $ip (id=$id): $mercy_balance $gr < $Ulimit_balance{$mId}");
 &SaveEventToDb("$ip:$mercy_balance:$Ulimit_balance{$mId}",423,$id);
 return 2;
}

# Получение трафика на каждого клиента из таблицы users_trf
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
    next if $Id_to_mId{$id}!=$id; # алиас
    $pkt=$Upaket{$id};
    $Utraf1{$id}=&Get_need_traf($p->{in1},$p->{out1},$InOrOut1[$pkt]);
    $Utraf2{$id}=&Get_need_traf($p->{in2},$p->{out2},$InOrOut2[$pkt]);
    $Utraf3{$id}=&Get_need_traf($p->{in3},$p->{out3},$InOrOut3[$pkt]);
    $Utraf4{$id}=&Get_need_traf($p->{in4},$p->{out4},$InOrOut4[$pkt]);
    $UpayOptOld{$id}=$p->{options};
 }

 # Разберемся с опционными платежами. Считаем максимальное время опции 62 дня.
 %ModTraf=();	# массив для каких id трафик определенной категории перераспределять на 8 категорию
 # ORDER BY time - для того чтобы строка с опциями формировалась всегда в одной последовательности
 $sth=&sql("SELECT * FROM pays WHERE category=111 AND time>($ut-3600*24*62) ORDER BY time");
 $sth or return;
 while ($p=$sth->fetchrow_hashref)
 {
    $id=$p->{mid};
    foreach $opt (split /\n/,$p->{reason})
    {  # Платежи могут редактироваться и если при этом структура была искажена - это нарушит работу (агента доступа в частности), поэтому split /:/,$opt - не катит;
       next if $opt!~/^(\d+):(\d+):(\d+):/;
       next if $t>$2;		# действие опции закончилось по времени
       $ModTraf{$id}{$3}=1;
       $UpayOpt{$id}.="$3:0\n";
    }
 }

 foreach $id (keys %UpayOptOld)
 {
    if (defined $UpayOpt{$id})
    {
       chomp $UpayOpt{$id};
       $UpayOpt{$id}=~s|[\\']||g; # перестраховка, причем фильтровать до сравнения иначе будет постоянный апдейт записи в базе если админ пропишет запрещенный символ!
       next if $UpayOpt{$id} eq $UpayOptOld{$id};
       &sqldo("UPDATE users_trf SET options='$UpayOpt{$id}' WHERE uid=$id LIMIT 1");
       next;
    }
    next unless $UpayOptOld{$id};   
    &sqldo("UPDATE users_trf SET options='' WHERE uid=$id LIMIT 1");   
 }
}

# ================================================================
#		Обновление инфы клиентов из БД
# ================================================================
sub Get_user_info
{
 my ($grp,$h,$id,$ip,$mid,$p,$rows,$report,$sql,$sth);
 my %set_auth=();
 my %UIP=();

 my $start_time=[gettimeofday]; # для статистики
 %ULoadStat=('all_users'=>0,'deny_users'=>0,'noauth_users'=>0,'dtraf_users'=>0,'auth_users'=>0);
 my $mess_lost_mysql='Вероятно пропало соединение с БД';

 if( !$Tarif_loaded )
 {  # если тарифы не загружены - будем долбать пока не загрузим
    &Tarif_Reload;
    &ToLog($Tarif_loaded? ('Тарифы загружены','!') : ('Тарифы до сих пор НЕ загружены','!!'));
 }

 # Получим соответствия ip -> id в таблице users_trf для того чтобы далее обновить изменения в них
 $sth=&sql("SELECT uid,uip FROM users_trf","Ошибка выполнения sql при получении данных клиентов. Вероятно временная.");
 $sth or return($mess_lost_mysql);
 $UIP{$_->{uid}}=$_->{uip} while ($_=$sth->fetchrow_hashref);

 $sth=&sql("SELECT grp_id,grp_property,grp_maxflow,grp_maxregflow FROM user_grp","Ошибка выполнения sql при получении данных клиентов. Вероятно временная.");
 $sth or return($mess_lost_mysql);
 while ($p=$sth->fetchrow_hashref)
 {
    $grp=$p->{grp_id};
    $Grp{$grp}{property}=$p->{grp_property};
    $Grp{$grp}{blockflow}=$p->{grp_maxflow};	# максимальное количество потоков трафика за срез по превышении которых будет блочиться доступ
    $Grp{$grp}{regflow}=$p->{grp_maxregflow};	# максимальное количество регистрируемых потоков трафика за срез
 }

 $sth=&sql($s_usr,"Ошибка при получении данных клиентов: нет соединения с БД!");
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
   {  # алиасная запись
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
         &ToLog("Ошибка: алиас $ip (id=$id) указывает на отсутствующую основную запись!",'!!');
         next;
      }
   }
    else
   {  # основная запись
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
   {  # у записи был изменен ip
      $rows=&sqldo("UPDATE users_trf SET uip='$ip' WHERE uid=$id LIMIT 1","Было изменение $UIP{$id} -> $ip");
      if( $rows && $rows<1 )
      {  # запрос выполнен, однако строки с заданным id нет
         $h=$mid? '' : ",startmoney=$Ubalance{$id},packet=$Upaket{$id}";
         &sqldo("INSERT INTO users_trf SET uip='$ip',uid=$id $h");
      }
   }

   $Ip_to_id{$ip}=$id;
   $Id_to_ip{$id}=$ip;

   $grp=$p->{grp};
   $h=$p->{detail_traf};			# детализация трафика установлена персонально?
   $h=1 if $Plan_flags[$Upaket{$id}]!~/h/ && $Grp{$grp}{property}=~/4/; # если тариф не блокирует детализацию и она включена для группы
   $ULoadStat{dtraf_users}++ if $h;
   $Udetail_traf{$id}=$h;

   $Utraf1{$id}||=0;
   $Utraf2{$id}||=0;
   $Utraf3{$id}||=0;
   $Utraf4{$id}||=0;

   $UmaxFlow{$id}=$Grp{$grp}{blockflow};	# максимально допустимое количество потоков за срез снятия трафика
   $UoverFlow{$id}||=0;				# текущий счетчик количества превышений границ потоков
   $UmaxRegFlow{$id}=$Grp{$grp}{regflow};	# максимально количество регистрируемых потоков за срез снятия трафика

   $UstateNew{$id}=$p->{cstate}==9 || $p->{cstate}==10;	# состояние `на подключении`?

   $Uauth{$id}||='no';				# новая запись? - считаем, что клиент не авторизован
   $ULoadStat{auth_users}++ if $p->{auth}=~/^(on|ong|off)$/;

   if( $p->{state} eq 'off' )
   {  # доступ запрещен
      $ULoadStat{deny_users}++;
      $Udeny{$id}=1;
   }
    else
   {  # в прошлом обновлении инет ему был запрещен
      $Udeny{$id} && &ToLog("Обнаружено: разрешен доступ для $ip (id=$id)");
      $Udeny{$id}=0;
   }

   if( $p->{lstate} )
   {  # авторизация для этой записи отключена
      $ULoadStat{noauth_users}++;
      $Uno_auth{$id}=1;
   }

   if( $t>$When_set_unauth )
   {  # установим состояние авторизации в таблице user по значению $Uauth{$id} - вдруг ранее были сбои...
      $h=$Uauth{$id}; # группируем все id по состояниям авторизации
      $set_auth{$h}.="$id,";
      if( length($set_auth{$h})>5000 )
      {
         chop $set_auth{$h};
         &sqldo("UPDATE users SET auth='$h' WHERE id IN ($set_auth{$h})");
         $set_auth{$h}='';
      }
   }

   # На каком интерфейсе считать трафик данного клиента
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
         $Uip_alrd_er{$id}=0; # надо т.к. ip может меняться
         next;
      }
      next if $Uip_alrd_er{$id}; 
      &ToLog("$ip не входит ни в одну сеть, для которой указанно с какого коллектора снимается статистика для этой сети!",'!');
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

 $report.="Время получения полного списка клиентов из БД: ".tv_interval($start_time)." сек\n";
 $start_time=[gettimeofday];

 &Get_Traf_From_Db;

 foreach $id (@all) { &CountMoney($id) }

 # Личные сообщения для клиентов
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

 # Первая активность
 $sth=$dbh->prepare("SELECT DISTINCT mid FROM pays WHERE type=50 AND category=424 AND mid>0");
 if( $sth->execute )
 {
    %Ufirst_act=(); # обнуляем т.к. события могут удаляться
    $Ufirst_act{$_->{mid}}=1 while ($_=$sth->fetchrow_hashref);
 }

 $report.="Время получения из БД сообщений для клиентов: ".tv_interval($start_time)." сек\n";
 return($report);
}

# -------------------------------------------
#	Периодические сервисные ф-и
# -------------------------------------------
sub Periodic_service
{
 my($cash,$h,$i,$mid,$ok,$p,$sql,$sth,$sth2,$t1,$t2,$tm,$t_day_keep,$tt);
 $h=localtime($t);
 my($day_now,$mon_now,$year_now,$hour_now)=($h->mday,$h->mon,$h->year,$h->hour);

 $When_Periodic_service=$t+3600; # периодичность сервисной функции - час
 $Test_net='dev.nodeny.com.ua';

 $dbh or &ConnectToDB;
 if( !$dbh )
 {
    &ToLog("Нет соединения с базой данных. Сервисные функции не выполнены (не проверены неудаленные временные платежи,...)");
    return;
 }

 {
  $T_db_error=[0,0];	# время последнего неудачного коннекта -> 0, чтобы разрешило soft reconnect

  $tm=$Kern_login_days_keep*24*3600;
  $ok=&sqldo("DELETE FROM login WHERE time<($ut-$tm)","Чистим таблицу login. Записи старше $Kern_login_days_keep дней удаляются");
  $ok or last;
  $tm=$Sat_t_monitor*3600;
  $ok=&sqldo("DELETE FROM sat_log WHERE time<($ut-$tm)");
  $ok or last;
  $t_day_keep=$t-$Kern_Dtraf_days_keep*24*3600;
  $ok=&sqldo("DELETE FROM traf_info WHERE time<$t_day_keep");
  $ok or last;

  # удалим временные платежи
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=20 AND time<$ut");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $cash=$p->{cash};
     $mid=$p->{mid};
     $ok=&sqldo("DELETE FROM pays WHERE id=".$p->{id}." LIMIT 1",'Удаляем временный платеж');
     last unless $ok;
     next if $ok<1;
     &ToLog("Удален временный платеж $cash $gr клиента id=$mid, ip=$Id_to_ip{$mid}, созданный админом id=".$p->{admin_id});
     $mid=$Id_to_mId{$mid};
     &SaveEventToDb($cash,426,$mid);
     # Изменим баланс. Если платеж был отрицательный, то включим клиента (работает только для основной записи).
     # Нет времени разбираться можно или нет включать - если ошиблись, то вырубит автоматом при первой же авторизации
     $sql=$cash<0? ", state='on'" : '';
     $ok=&sqldo("UPDATE users SET balance=balance-($cash) $sql WHERE id=$mid LIMIT 1");
     $ok<1 && &ToLog("После удаления временного платежа не удалось изменить баланс клиента id=$mid",'!!');
     $ok or last; # внимание: !$ok - утеряно соединение, <1 - либо утеряно либо не найден клиент. Прекращаем обработку только при !$ok
  }
  $ok or last;

  # Автоплатежи 
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=112 AND time<$ut");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $mid=$Id_to_mId{$p->{mid}};
     next if $p->{reason}!~/^(.+):(\d+)$/; # не соответствуешт шаблону "деньги:время"
     ($cash,$tm)=($1,$2);
     $cash+=0;
     next unless $cash;
     next if $tm<3600; # если периодичность автоплатежа меньше часа - игнорим, иначе засыпемся платежами
     $ok=&sqldo("UPDATE pays SET time=$ut+$tm WHERE type=50 AND category=112 AND id=".$p->{id}." LIMIT 1");
     $ok or last;
     next if $ok<1; # мог быть удален только что
     $_=$p->{coment};
     s/\\/\\\\/g;
     s/'/\\'/g;
     $ok=&sqldo("INSERT INTO pays (mid,cash,type,bonus,category,reason,coment,time) VALUES ".
        "($mid,$cash,10,'y',105,'','$_',$ut)",'Автоплатеж'); # 105 - `снятие за услуги`
     if( $ok<1 )
     {
        &ToLog("Не удалось произвести снятие после продления автоплатежа. Клиент id=$mid,$Id_to_ip{$mid}",'!!');
        $ok or last;
        next;
     }
     $ok=&sqldo("UPDATE users SET balance=balance+($cash) WHERE id=$mid LIMIT 1");
     $ok<1 && &ToLog("После продления автоплатежа не удалось изменить баланс клиента id=$mid,$Id_to_ip{$mid}",'!!');
     $ok or last;
  }

  $ok or last;

  # Запланированные события
  $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=430");
  $ok=$sth->execute;
  $ok or last;
  while( $p=$sth->fetchrow_hashref )
  {
     $p->{reason}=~/^(\d+):(\d+)$/ or next; # не соответствуешт шаблону `код_события:время`
     &plan_event_1($p->{id},$p->{mid},$p->{time},$2) if $1==1;
  }
  
  # снятие абонплат после часа ночи т.к. 1-го числа в 0 часов запуск скрипта перехода на новый месяц
  if( $hour_now>1 && $Tarif_loaded )
  {
     $V && &debug("=== Суточные абонплаты ===");
     $t1=timelocal(0,0,0,$day_now,$mon_now,$year_now);		# начало суток
     $t2=timelocal(59,59,23,$day_now,$mon_now,$year_now);	# конец суток
     my $alldays=0;
     # количество дней в месяце с учетом высокосного года
     map{ eval{ timelocal(0,0,0,31-$_,$mon_now,$year_now) } && ($alldays||=31-$_) } ( 0..3 );
     $alldays||=31;

     # тарифы, в которых есть абонплата
     foreach $i ( grep{ $Plan_name[$_] }(1..$Max_tarif) )
     {
        foreach $h (split /\n/,$Plan_script[$i])
        {
        $h=~s/^<time *[^>]+>//i; # если есть признак времени - игнорируем
        $h=~/^(8|9):(.+)/ or next;
        $cash=$1==8? sprintf("%.2f",-$2/$alldays) : -$2+0;   
        
        ##$h=~s/^<time *[^>]+>//i; # если есть признак времени - игнорируем
        ##$h=~/^9:(.+)/ or next;
        ##$cash=-$1+0;
           # получим список клиентов, у которых тариф № $i, а также нет абонплаты за текущий день
           $sql="SELECT id FROM users WHERE mid=0 AND paket=$i AND id NOT IN ".
             "(SELECT u.id FROM users u LEFT JOIN pays p ON u.id=p.mid WHERE u.paket=$i and p.category=114 AND time>=$t1 AND time<=$t2)";
           $sth=$dbh->prepare($sql);
           if( $sth->execute )
           {
              $V && &debug("SQL OK (".$sth->rows." rows):$sql");
              while( $p=$sth->fetchrow_hashref )
              {
                 $mid=$p->{id};
                 $Ustart_day{$mid}<0 && next; # пока не начал пользоваться услугами
                 $ok=&sqldo("INSERT INTO pays (mid,cash,type,bonus,category,reason,coment,time) VALUES ".
                    "($mid,$cash,10,'y',114,'','Суточная абонплата',$ut)",'Абонплата суточная'); # 114 - `абонплата суточная`
                 if( $ok<1 )
                 {
                    $ok or last;
                    next;
                 }
                 $ok=&sqldo("UPDATE users SET balance=balance+($cash) WHERE id=$mid LIMIT 1");
                 $ok<1 && &ToLog("Не удалось изменить баланс после проведения суточной абонплаты. Клиент id=$mid,$Id_to_ip{$mid}",'!!');
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

 $ok or &ToLog('Во время выполнения подпрограммы сервисных функций было утеряно соединение с mysql. '.
    'Вероятно не все запланированные действия были выполнены. Будут выполнены в следующий раз','!!');

 {
  $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
  $dbs or last;
  $dbs->do($User_select_Tbl);
  $i=localtime($t_day_keep);
  if( $i->hour>20 )
  {  # удаляем старые таблицы трафика только в последние 3 часа т.к. нет смысла пытаться удалять каждый час - с первого раза получится, 3 - перестраховка
     $h=(1900+$i->year).'x'.(1+$i->mon).'x'.$i->mday;
     $i=localtime($tm-26*3600); # на всякий случай захватим таблицу на сутки (+2 часа) назад
     $i=(1900+$i->year).'x'.(1+$i->mon).'x'.$i->mday;
     $dbs->do("DROP TABLE IF EXISTS $_") foreach ("v$h","v$i","x$h","x$i","y$h","y$i","z$h","z$i","s$h","s$i","t$h","t$i");
     $dbs->do("DELETE FROM traf_lost WHERE time<$t_day_keep");  
  }

  # Для каждой таблицы типа x и y создадим сгруппированные суточные таблицы: s и t соответственно
  $tt=localtime($t);
  $i=(1900+$tt->year).'x'.(1+$tt->mon).'x'.$tt->mday; # для таблиц текущего дня не создаем суточные таблицы, т.к. они будут еще обновляться
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
     $tbls{$i} && next; # для этой таблицы уже есть суточная таблица
     $dbs->do("CREATE TABLE IF NOT EXISTS $i $Slq_Create_STraf_Tbl") or next;
     $dbs->do("INSERT INTO $i (SELECT mid,class,SUM(`in`),SUM(`out`) FROM $h GROUP BY mid,class)") or $dbs->do("DROP TABLE IF EXISTS $i");
     last; # по одной таблице за раз
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

# === Запланированные события ===
#  0 - id платежа события
#  1 - id клиента
#  2 - время платежа
#  3 - время закодированное в поле reason платежа

# Запланированное событие `Удвоение платежей`
sub plan_event_1
{
 my ($id,$mid,$time,$time_event)=@_;
 my ($t_first_pay,$p,$rows,$sum_cash,$sth);
 $sum_cash=0;
 $t_first_pay=0;
 # Есть ли положительные платежи после `запланированного события`?
 $sth=$dbh->prepare("SELECT *,$ut AS t FROM pays WHERE mid=$mid AND type=10 AND cash>0 AND time>$time ORDER BY time");
 $sth->execute;
 while( $p=$sth->fetchrow_hashref )
 {
    if( !$t_first_pay )
    {  # первый по времени платеж
       $t_first_pay=$p->{time};
       return if ($p->{t}-$t_first_pay)<86400; # не прошли сутки после первого платежа
    }
     elsif (($p->{time}-$t_first_pay)>86400)
    {# удваиваются платежи проведенные только в течение суток после первого
       last;
    }
    $sum_cash+=$p->{cash};
 }
 return unless $sum_cash;
 $rows=$dbh->do("DELETE FROM pays WHERE id=$id AND mid=$mid AND type=50 AND category=430 LIMIT 1"); # избыточное условие для перестраховки
 return if $rows<1;

 $sth=$dbh->prepare("SELECT cash FROM pays WHERE mid=$mid AND type=10 AND category=100 ORDER BY time");
 $sum_cash+=$p->{cash} if $sth->execute && ($p=$sth->fetchrow_hashref);

 return if $sum_cash<=0;

 $rows=$dbh->do("INSERT INTO pays SET mid=$mid,cash=$sum_cash,type=10,bonus='y',category=3,reason='акция `деньги удваиваются`',time=$ut");
 if( $rows<1 )
 {
    &ToLog("Не удалось создать платеж-акцию `деньги удваиваются` клиента id=$mid на сумму $sum_cash",'!!');
    return;
 }

 $rows=&sqldo("UPDATE users SET balance=balance+$sum_cash WHERE id=$mid LIMIT 1");
 $rows<1 && &ToLog("Не удалось изменить баланс клиента id=$mid на сумму $sum_cash",'!!');
}


# ================================================================
# Вход: 
# 0: $id
# 1: код авторизации: 
#    6 - указание считать запись неавторизированной
#    7 - включение полного доступа
#    8 - включение доступа к сетям класса 2
#    9 - включение ограниченного (локального) доступа
# 2: время авторизации
#
# Формирует хеш в $AuthQueue со значениями авторизации для $id
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
 {  # указание считать запись неавторизированной
    $UtimeBlock{$id}=time+$tt;
    return;
 }
 $UtimeBlock{$id}=time+$tt+$Kern_t_to_deny; # отдалим время отключения по таймауту

 if( $dbh )
 {
    if( !$Ufirst_act{$id} )
    {  # Первая активность со стороны клиента
       $rows=$dbh->do("INSERT INTO pays SET mid=$id,type=50,category=424,time=$ut");
       $Ufirst_act{$id}=1 if $rows==1;
    }

    # Если запись `на подключении` - уберем это состояние
    if( $UstateNew{$id} )
    {
       $UstateNew{$id}=0; # если далее sql-запрос не будет выполнен, то установится в 1 при след.перечитке списка клиентов
       $rows=$dbh->do("UPDATE users SET cstate=0 WHERE id=$id LIMIT 1");
       $dbh->do("INSERT INTO pays SET mid=$id,type=50,category=421,time=$ut") if $rows==1;
    }

    if( $Ustart_day{$mId}<0 )
    {  # Клиент впервые авторизовался, надо выставить день начала потребления услуг
       $Ustart_day{$mId}=$Plan_flags[$Upaket{$mId}]=~/g/? 0 : $Day_Now; # флаг 'g' указывает день начала потребления услуг установить в ноль
       $rows=$dbh->do("UPDATE users SET start_day=$Ustart_day{$mId} WHERE id=$mId LIMIT 1");
       $dbh->do("INSERT INTO pays SET mid=$mId,type=50,reason='$Ustart_day{$mId}',category=422,time=$ut") if $rows==1;
    }

 }

 $block_cod=&CountMoney($id);
 $block_cod=5 if !$block_cod && $Udeny{$id};		# нет никаких переработок, доступ просто заблокирован

 $AuthQueue{$id}[0]=$block_cod || $auth_state;		# состояние авторизации для таблицы users
 # код для таблицы логинов = (код плагина авторизации) + (код переработки либо код авторизации)
 $AuthQueue{$id}[1]=int($auth_cod/10)*10+($block_cod || (7,8,9,7,7,7,7,7,8,9)[$a]);
 $AuthQueue{$id}[2]=$block_cod? 0 : 1;			# состояние now_on (включен?) для таблицы users_trf
 $AuthQueue{$id}[3]=$auth_time;
}  

# ======================================================
# Загрузка массива авторизаций с запрошенной базы данных
# Вход:
#  0 - $dbh
#  1 - № номер базы. (1 - основная, 2 - дополнительная, 3 - авторизации)
#  2 - ссылка на хеш
# Выход:
#  в хеш добавлены значения {id}=режим_авторизации
sub LoadAuth
{
 my($dbh,$num_db,$a)=@_;
 my($id,$max_id,$p,$rows,$sth);

 $max_id=0;
 $RowId_in_auth_tbl[$num_db]||=0; # id записи, на которой прошлый раз остановились, т.е ниже этой записи все авторизации уже обработаны
 # Учитываем только те записи, которые ранее не обрабатывались и авторизовались в последние 120 сек
 # Ограничение по времени это перестраховка - когда ядро долго не было запущено, в БД может быть гигантское количество устаревших записей
 $sth=$dbh->prepare("SELECT * FROM dblogin WHERE id>$RowId_in_auth_tbl[$num_db] AND time>($ut-120) ORDER BY id DESC");
 $sth->execute or return;
 while( $p=$sth->fetchrow_hashref )
 {
    $max_id||=$p->{id};
    $id=$p->{mid};
    if( !$id )
    {  # служебная запись
       $id=$p->{act};
       # удалим чтоб больше не реагировать (иначе если команда перезагрузки, то по циклу пойдет)
       $rows=$dbh->do("DELETE FROM dblogin WHERE id=".$p->{id}." LIMIT 1");
       next if $rows<1;
       &ServiceWork($id);
       next;
    }
    next if defined $a->{$id};			# более поздняя авторизация приоритетней
    $a->{$id}=[$p->{act},$p->{time}];		# режим и время авторизации
 }

 $RowId_in_auth_tbl[$num_db]=$max_id if $max_id;# в следующий раз все авторизации ниже этого id не принимаем во внимание

 $p=time+$tt;
 if( $p>$When_clean_auth_tbl{$num_db} )
 {  # если пришло время - удалим все обработанные строки
    $When_clean_auth_tbl{$num_db}=$p+58;	# каждые 58 сек. Лучше сделать настраиваемо
    $id=$RowId_in_auth_tbl[$num_db]? "DELETE FROM dblogin WHERE id<=$RowId_in_auth_tbl[$num_db]" : "DELETE FROM dblogin WHERE time<($ut-120)";
    $dbh->do($id);
 }
}
   
# ================================================================
#			Обработка авторизаций
# ================================================================
sub Check_auth
{
 my($a,$id,$n,$t);

 $t=time+$tt;
 $Day_Now=localtime($t)->mday;

 if( $When_reconect_db_auth<$t )
 {
    $When_reconect_db_auth=$t+60; # на всякий пожарный будем пересоединяться с базой авторизации каждые 60 секунд - это не нагружает, но страховка от потери соединения
    $dbha='';
 }

 $dbha=DBI->connect($DSNA,$Db_user,$Db_pw,{PrintError=>1}) if !$dbha;

 $a={};
 if( $dbha )
 {
    $ErrorDba && &ToLog("Связь с базой данных авторизаций $Db_server_a восстановлена. Процесс авторизации возобновлен");
    $ErrorDba=0;
    &LoadAuth($dbha,3,$a);
 }
  elsif( !$ErrorDba )
 {
    &SaveEventToDb("Нет соединения с базой данных авторизаций на сервере $Db_server_a. С этого момента времени ядро не получает информацию об авторизациях из БД на этом сервере!",481);
    &ToLog("Нет соединения с базой данных авторизаций $Db_server_a. С этого момента времени ядро не получает информацию об авторизациях из БД на этом сервере",'!!');
    $ErrorDba=1;
 }

 # В случае проблем, сервера авторизации могут производить запись и на основной сервер
 if( $Db_server ne $Db_server_a )
 {  # Основной сервер не должен совпадать с сервером авторизации
    # Если есть хотя бы одна запись, то обработаем таблицу
    $n=$dbh->prepare("SELECT time FROM dblogin LIMIT 1");
    $V && &debug("$n=SELECT time FROM dblogin LIMIT 1");
    &LoadAuth($dbh,1,$a) if $n->execute && $n->fetchrow_hashref;
 }

 # дабы избежать бесконечного цикла при флуде (дискредитированного сервера авторизации, а не клиентов) - ограничим кол-во циклов
 $n=$ULoadStat{all_users}<100? 100 : $ULoadStat{all_users};
 foreach $id (keys %$a)
 {
    last unless $n--;
    &Auth($id,$a->{$id}[0],$a->{$id}[1]);
 }

 &SetAuthInDB;
}

# === Обработка служебной записи в базе авторизации
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
 return "Получен сигнал остановки ядра NoDeny";
}
sub s_restart
{
 $Need_restart=2;
 return "Получен сигнал перезагрузки ядра NoDeny";
}
sub s_soft_restart
{
 $Need_restart=1;
 return "Получен сигнал `мягкой` перезагрузки ядра NoDeny";
}

sub s_tarif_reload
{
 $Need_tarif_reload=1;
 return "Получили команду `Перечитать тарифы`";
}
sub s_nets_reload
{
 $Need_nets_reload=1;
 return "Получили команду `Обновить список направлений`";
}
sub s_user_reload
{
 $When_user_reload=$t;
 return "Получили команду `Перечитать список клиентов`";
}
sub s_pong
{
 return 'pong';
}
sub s_mail
{
 &Smtp("Это тестовое письмо для проверки возможности отсылки с сервера ядра писем администратору");
 return "Получили команду `Отослать тестовое письмо администратору`";
}
sub s_tune_sql
{
 $Sql_tuning=1;
 return 'Получен сигнал включения тюнинга sql';
}
sub s_tuneoff_sql
{
 $Sql_tuning=0;
 return 'Получен сигнал выключения тюнинга sql';
}

# -------- Запись состояния снятия трафика в таблицу traf_info ----------
# Вход: код события, текст события
sub SaveTrafInfo
{
 &sqldo("INSERT INTO traf_info (time,cod,data1) VALUES($T_got_traf,$_[0],'$_[1]')",$_[2]);
}

sub SaveTrafTime {&SaveTrafInfo($_[0],sprintf("%.1f",$_[1]))}

# Вход:
#  0 - многострочный sql-запрос
#  1 - ссылка на массив запросов
# Запрос добавляет в массив, после чего запрос обнуляется
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

# Вход:
#  0 - переменная, содержащая многострочный sql-запрос
#  1 - ссылка на массив запросов
#  2 - значение, которое добавляется к запросу
# Если итоговая длина запроса превысит $MaxSqlLen байт - вызывается &Final_Sql
sub Add_Sql
{
 $_[0].=$_[2];
 &Final_Sql($_[0],$_[1]) if length($_[0])>=$MaxSqlLenNow;
}

# --------------------------------------------------------
#               Запрос трафика у коллекторов
# --------------------------------------------------------
sub Request_Traf
{
 my($dserver,$nserver,$type);
 $When_get_traf=$t+5;	# готовы ли файлы с трафиком проверим через 5 секунд
 foreach $nserver (keys %Collectors)
 {  # запустим скрипт сбора статистики для каждого коллектора
    ($dserver,$type)=split /\-/,$Collectors{$nserver};
    $type=$type=~/^(netflow|ipcad|ipacct):/? $1 : 'ipcad';
    $dserver="$Program_dir/$type.pl $dserver $Sql_dir/$nserver-$t 0 $V &";
    system($dserver);
    $V && &debug($dserver);
 }
 $T_got_traf=$t;	# запомним время среза статистики
 $Traf_Act=1;		# фаза проверки готовы ли файлы с трафиком
}

sub Check_Traf
{
 my($dserver,$nserver);
 if( ($t-$T_got_traf)>60 )
 {  # время вышло даже если некоторые файлы с трафиком не подготовлены
    $V && &debug("*** Конец мониторинга файлов статистики, возможно некоторые не существуют.");
    $Traf_Act=2;
    return; 
 }
 $When_get_traf=$t+5;	# каждые 5 сек проверяем готовы ли все файлы с трафиком
 foreach $nserver (keys %Collectors)
 {
    ($dserver)=split /\-/,$Collectors{$nserver};
    return unless -e "$Sql_dir/$nserver-$T_got_traf";
 }
 $V && &debug("*** Все файлы статистики обнаружены. Мониторинг закончен.");
 $When_get_traf=$t;
 $Traf_Act=2;		# все файлы с трафиком уже сформированы, установим фазу обсчета
}

# --------------------------------------------------------
#               Подсчет и запись трафика
# --------------------------------------------------------
sub Count_Traf
{
 $V && &debug("*** Начало обсчета трафика.");
 @SaveTrf=();
 $dbh or &ConnectToDB;
 if( !$dbh && ++$Traf_Act<4 )
 {  # возможно временные бока с БД, пока трафик не будем терять
    $V && &debug("Нет соединения с БД. Трафик за срез $T_got_traf попробуем обработать через минуту.");
    $When_get_traf=$t+60;
    return;
 }

 $When_get_traf=$T_got_traf+$Kern_t_traf;
 $Traf_Act=0;			# следующая фаза - получение трафика от коллекторов

 if( !$dbh )
 {
    $V && &debug("Нет соединения с БД. Трафик за срез $T_got_traf не обработан.");
    &ToLog("Нет соединения с БД. Трафик за текущий срез сохранен в файлах с именем: номер_коллектора-$T_got_traf.",'!!');
    return;
 }

 my($bytes,$cls,$day_now,$h,$hour,$id,$i1,$i2,$i3,$i4,$iface,$intf,$ip,$ip1,$ip2,$ip_raw,$j,$line,$mId,$mon_now);
 my($paket,$port1,$port2,$proto,$p,$pr,$pre_cls,$rows,$server,$t0,$t_traf,$when_need_auth,$year_now);

 @Sql_tune_stat=();		# статистика выполнения запросов в зависимости от их длины, это для тюнинга sql

 $h=localtime($T_got_traf);
 ($day_now,$mon_now,$year_now,$hour)=($h->mday,$h->mon,$h->year,$h->hour);
 $h=($year_now+1900).'x'.($mon_now+1).'x'.$day_now;  
 my $z_traf_tbl="z$h";		# таблица детализации трафика текущего дня
 my $x_traf_tbl="x$h";		# таблица трафика
 my $y_traf_tbl="y$h";		# таблица трафика нулевого пресета
 my $v_traf_tbl="v$h";		# таблица информации о трафике

 # Здесь будут многострочные insert чтобы повысить скорость вставки. Постепенно $sqlх перекидываются в массивы
 my $sqlv=$sqlx=$sqly=$sqlz=$sqll='';	
 my @l_traf=();			# lost traf
 my @v_traf=();
 my @x_traf=();
 my @y_traf=();
 my @z_traf=();

 $t_traf=$T_got_traf-timelocal(0,0,0,$day_now,$mon_now,$year_now); # время среза от начала дня

 my $traflog='';
 my %S=();			# статистика обработки трафика для каждого клиента

 my %has_traf=();		# список ip, которые имеют трафик подлежащий записи в БД
 my %else_ip=();		# ip адреса, которых нет в БД и для которых есть трафик в обоих направлениях. Это т.н. `неучтенный трафик`. $else_ip{ip_from-ip_to}.

 my $traf_lines=0;		# строк с трафиком, для статистики
 my $traf_lines_bytes='';	# общий объем данных, полученных от коллекторов (сам объем этой служебной информации, а не трафик клиентов)

 my %in0=();
 my %out0=();
 my %in=();
 my %out=();
 my @lines=();

 my $errors=0;

 $t0=[gettimeofday];		# отсчет времени с этого момента

 # Пройдемся по всем коллекторам
 foreach $nserver (keys %Collectors)
 {
   ($dserver,$server)=split /\-/,$Collectors{$nserver};
   $file_name="$Sql_dir/$nserver-$T_got_traf";
   unless (open(F,"<$file_name"))
   {
      $V && &debug("Не получен трафик от $server ($dserver).");
      $traflog.="Не получен трафик от $server ($dserver).\n";
      $errors++;
      next;
   }
   @lines=<F>;
   close(F);

   $traf_lines_bytes.="$dserver: ".(stat("$file_name"))[7]."\n";
   $V? &debug("$file_name сохранен т.к \$V<>0") : unlink $file_name;

   if( $NoNeedTraf{$dserver} )
   {
      $NoNeedTraf{$dserver}=0;
      $V && &debug("Не считаем первый трафик с $server ($dserver) - указано в настройках.");
      &ToLog("Ядро запущено с опцией не считать первый полученный трафик с коллекторов. Трафик коллектора $server ($dserver) проигнорирован. Все последующие срезы будем учитывать.");
      next;
   }

   %else_ip=();
   $when_need_auth=0;

   foreach $line (@lines)
   {
      if( $when_need_auth--<0 )
      {  # авторизация каждые 30 000 обработанных строк. Не привязываемся ко времени т.к оно будет запрашиваться каждую обрабатываемую строчку
         $when_need_auth=30000;
         &Check_auth;
      }
      next if $line!~/^\s*(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+\d+\s+(\d+)(.*)$/o; # скомпилированный шаблон
      ($ip1,$ip2,$bytes,$intf)=($1,$2,$3,$4);
      &debug(sprintf("       %15s -> %15s %8d байт (%s)",$ip1,$ip2,$bytes,$intf)) if $V && $V++<$debug;
      $traf_lines++;
      $j=-1; # признак `пока не определили направление`
      if( $intf )
      {  # расширенный вывод коллектора
         (undef,$port1,$port2,$proto,$intf)=split /\s+/,$intf;
         $port2=$port1 if $proto==1; # в icmp тип пакета в src_port
         # Если интерфейс равен 1 или 2, то это настройка фаервола, когда мы в коллектор раздельно посылаем потоки `к клиенту` и `от клиента`
         if( $intf eq '1' || $intf eq '2' ) # нельзя ($intf==1) т.к нечисловые значения преобразуются к числовым
         {
            if( $intf==2 )
            {
               $j=0; # трафик к клиенту
               ($ip2,$ip1,$port2,$port1)=($ip1,$ip2,$port1,$port2);
            }else
            {
               $j=1; # трафик от клиента
            }
            if( !$Ip_to_id{$ip1} )
            {# прошел левый трафик к/от незарегистрированного ip. В таблице неученного трафика зарегистрируем только трафик `от клиента`
               $V && $V<$debug && &debug("!!! $ip1 - не зарегистрирован в NoDeny. Проверяйте фаервол.");
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
         {# трафик не к/от клиентов в базе
            $V && &debug("Оба ip не зарегистрированы в NoDeny.");
            ($ip1 eq $ip2) && next;		# ситуация возможна при агрегировании
            $else_ip{"$ip1-$ip2"}=1;
            $else_ip{"$ip2-$ip1"} or next;	# пока не получим обратный трафик - не учитываем
            $sqll||="INSERT INTO traf_lost (time,`in`,`out`,ip) VALUES";
            &Add_Sql($sqll,\@l_traf,"($T_got_traf,$bytes,0,'$dserver: $ip2-$ip1'),");
            next;
         }

         next if $Ip_to_iface{$ip1}!~/^(.+)_(.+)$/;# неправильная структура либо нет данных какой коллектор обсчитывает данный ip

         next if ($1 ne '*') && $1!=$nserver;	# трафик для $ip1 снимается не с этого коллектора 
         $iface=$2;				# интерфейс, к которому подключен $ip1

         if( $intf && $iface ne '*' )
         {
            # смотрим на интерфейс, если не наш - пакеты считать не будем
            $intf=~s/\d+$// if $iface=~s/\*$//; # динамический интерфейс типа ng*
            next if $iface ne $intf;
         }
      }

      $id=$Ip_to_id{$ip1};
      $S{$id}{bytes}+=$bytes; # общее количество трафика, связанное с клиентом
      $S{$id}{$j? 'flows_out' : 'flows_in'}++;

      # Признак, что траф есть и нужно записать в базу как минимум инфо о нем. Устанавливаю в количество байт - записи, которые потребляют
      # больше трафика, в базу будут записаны первыми - при просмотре статистики будет более реальная картина по загрузке канала.
      $has_traf{$id}+=($bytes||1);

      ($i1,$i2,$i3,$i4)=split /\./,$ip2;
      $ip_raw=pack('CCCC',$i1,$i2,$i3,$i4);

      # Будем считать трафик нулевым направлением если это мультикаст или бродкаст
      # Обрати внимание, что они могут быть описаны в таблице направлений и переопределяться на другой класс
      $pre_cls=$cls=($i1>223 && $i1<240) || $i1==127 || $ip2 eq '255.255.255.255'? 0:1;

      if( defined $CLS{"0-$port2-$ip_raw"} )
      {  # возьмем из кеша
         $cls=$CLS{"0-$port2-$ip_raw"};
         $V && $V<$debug && &debug(sprintf("клиент:%15s    %15s класс %1d взят из кеша",$ip1,$ip2,$cls));
      }
       else
      {  # ---  цикл определения класса трафика по нулевому пресету (для общей статистики) ---
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
         $CLS{"0-$port2-$ip_raw"}=$cls if (keys %CLS)<=$MaxCashIp;		# кеш не превысил допустимое количество записей
         $V && $V<$debug && &debug(sprintf("клиент:%15s    %15s класс %1d",$ip1,$ip2,$cls));
      }

      if( $cls ) {if ($j) {$out0{$id}[$cls]+=$bytes} else {$in0{$id}[$cls]+=$bytes}}

      $pr=$Plan_preset[$Upaket{$id}] || 0;

      if( defined $CLS{"$pr-$port2-$ip_raw"} )
      {
         $cls=$CLS{"$pr-$port2-$ip_raw"};
      }
       else
      {  # --- цикл определения класса трафика по пресету пакета клиента ---
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

      $cls or next; # трафик 0-го направления не учитывается

      $S{$id}{flows}++;

      if( $Udetail_traf{$id} )
      {  # Для этого ip необходимо сохранять трафик детально
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

 # --- Анализ данных, полученных от коллекторов, закончен ---
 &SaveTrafTime(2,tv_interval($t0));	# Время обсчета трафика
 $t0=[gettimeofday];

 $V=!!$V; # сбрасываем verbose счетчик

 $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 if( $dbs )
 {
    sleep 1;
    $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 } 

 if( $dbs )
 {  # Создадим таблицы с информацией о трафике
    $dbs->do("CREATE TABLE IF NOT EXISTS $v_traf_tbl $Slq_Create_VTraf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $z_traf_tbl $Slq_Create_ZTraf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $x_traf_tbl $Slq_Create_Traf_Tbl");
    $dbs->do("CREATE TABLE IF NOT EXISTS $y_traf_tbl $Slq_Create_Traf_Tbl");
 } 

 &SaveTrafInfo(1,$traf_lines,'Количество обработанных строк коллекторов');
 &SaveTrafInfo(8,$traf_lines_bytes,'Трафик от коллекторов, байт');
 $cls=keys %CLS;
 &SaveTrafInfo(5,$cls,'Значений в кеше ip');
 %CLS=() if $cls>$MaxCashIp;		# Кеш превысил допустимое количество записей, обнулим

 my $n_overFlows=0; # общее количество клиентских ip, однократно превысивших допустимое количество потоков
 my ($sum_inTraf,$sum_outTraf,$start,$end,$k);

 $when_need_auth=0;
 # Начнем запись в базу в порядке убывания трафика - при просмотре статистики будет более информативная картина 
 foreach $id (sort {$has_traf{$b} <=> $has_traf{$a}} keys %has_traf)   
 {
   if( time()>$when_need_auth )
   {
      $when_need_auth=time()+3;	# каждые 3 секунды авторизация
      &Check_auth;
   }

   $ip=$Id_to_ip{$id};
   $mId=$Id_to_mId{$id};	# id основной записи

   $sum_inTraf=$sum_outTraf=0;

   foreach (1..8)
   {
      $IN[$_]=int $in{$id}[$_];
      # Обнулим исходящий если нулевой входящий
      $OUT[$_]=$Traf_zero_flush && !$IN[$_]? 0 : int $out{$id}[$_];
      $sum_inTraf+=$IN[$_];
      $sum_outTraf+=$OUT[$_];
      $in{$id}[$_]=$out{$id}[$_]=0;
   }

   if( !$Ufirst_act{$id} && $sum_outTraf )
   {  # Первая активность со стороны клиента
      $rows=$dbh->do("INSERT INTO pays SET mid=$id,type=50,category=424,time=$ut");
      $Ufirst_act{$id}=1 if $rows==1;
   }

   if( $Uno_auth{$id} && $sum_outTraf )
   {  # У записи без авторизации есть исходящий трафик
      if( $UstateNew{$id} )
      {  # Уберем `на подключении`. Записи с автризацией меняют состояние при первой авторизации
         $rows=$dbh->do("UPDATE users SET cstate=0 WHERE id=$id LIMIT 1");
         $dbh->do("INSERT INTO pays SET mid=$id,type=50,category=429,time=$ut") if $rows==1;
         $UstateNew{$id}=0 if $rows==1;
      }

      if( $Ustart_day{$mId}<0 )
      {  # День начала потребления услуг
         $Ustart_day{$mId}=$Plan_flags[$Upaket{$mId}]=~/g/? 0 : $day_now; # флаг 'g' указывает день начала потребления услуг установить в ноль
         $rows=$dbh->do("UPDATE users SET start_day=$Ustart_day{$mId} WHERE id=$mId LIMIT 1");
         $dbh->do("INSERT INTO pays SET mid=$mId,type=50,reason='$Ustart_day{$mId}',category=422,time=$ut") if $rows==1;
      }
   }

   # Стоит ограничение на количество потоков и оно превышено и доступ еще не заблокирован?
   if( $UmaxFlow{$id} && $S{$id}{flows}>$UmaxFlow{$id} && !$Udeny{$id} )
   {
      if( $UoverFlow{$id} )
      {  # это второе подряд превышение, будем блокировать
         $rows=$dbh->do("UPDATE users SET state='off' WHERE id=$id LIMIT 1");
         if( $rows==1 )
         {
            $Udeny{$id}=1;
            $p="Заблокирован $ip по причине превышения лимита потоков трафика: $S{$id}{flows} (граница $UmaxFlow{$id})";
            &ToLog($p,'!');
            $traflog.="$p\n";
            $dbh->do("INSERT INTO pays SET mid=$mId,type=50,category=425,reason='$ip:$S{$id}{flows}:$UmaxFlow{$id}',time=$ut");
         }
      }else
      {
         $UoverFlow{$id}++;	# счетчик подряд идущих превышений потоков
         $n_overFlows++;	# для статистики
      }
   }else
   {
      $UoverFlow{$id}=0;
   }

   # статистическая информация о трафике
   $sqlv||="INSERT INTO $v_traf_tbl (time,mid,flows_in,flows_out,flows_reg,bytes,bytes_reg,detail) VALUES";
   &Add_Sql($sqlv,\@v_traf,"($t_traf,$id,".int($S{$id}{flows_in}).','.int($S{$id}{flows_out}).','.int($S{$id}{flows_reg}).','.int($S{$id}{bytes}).
     ','.($sum_inTraf+$sum_outTraf).','.($S{$id}{overflow}? 2 : $Udetail_traf{$id}? 1 : 0).'),');

   ($sum_inTraf || $sum_outTraf) or next;

   $p=$Upaket{$mId};
   {
    $time_paket[$p] or last;
    # в данном пакете установлен период времени, когда применяется действие:
    $k=$Plan_k[$p];
    last if $k<=0; # <0 - блокировка доступа, 0 - никаких действий
    $start=$Plan_start_hour[$p];
    $end=$Plan_end_hour[$p];
    last unless ( ($start>$end && ($hour>=$start || $hour<$end)) || ($start<$end && $hour>=$start && $hour<$end) );
    if( $k==1 )
    {  # а указание перераспределить трафик
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
    # умножение трафика на коэффициент
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
      {  # платеж-опция указывает трафик направления $i перераспределить на направление 8
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

   # Обновление общего трафика для основной записи данного клиента
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
 $n_overFlows && &SaveTrafInfo(10,$n_overFlows,'Превышений потоков');
 # получим полный трафик каждого юзера
 &Get_Traf_From_Db;

 &SaveTrafTime(4,tv_interval($t0));
 $t0=[gettimeofday];

 &SaveTrafTime(9,tv_interval($t0));
 $t0=[gettimeofday];

 # Детальный траф по нулевому пресету
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
 $dbh->do("INSERT INTO sat_log SET sat_id=0,mod_id=0,time=$ut,info='$traflog',error=$errors"); # переполнение errors преобразуется в 255, 255 ошибок или больше будет важно?

 @SaveTrf=(@v_traf,1,@y_traf,2,@x_traf,3,@z_traf,4,@l_traf,5);
 # количество sql, которые необходимо будет выполнить (для отображения % выполнения). $#SaveTrf это индекс последнего значение, т.е. надо +1 чтоб получить кол-во
 $SafeTrafSqls=$#SaveTrf+1;
 $t_start_save_trf=[gettimeofday];
}

# =======================================================

sub SaveTrf
{
 $dbs=DBI->connect($DSS,$Db_user,$Db_pw,{PrintError=>1});
 if( !$dbs )
 {
    $V && &debug("Ошибка соединения с $DSS");
    if ($ErrorDbs++>5)
    {  # придется потерять трафик если много ошибок, иначе мы застряенем и все остановится
       $ErrorDbs=0;
       &SaveTrafTime(23,$#SaveTrf); # запишем в статистику сколько sql-запросов мы потеряли
       $V && &debug("Число попыток соединений превысило допустимое. $#SaveTrf sql-запросов не выполнено.");
       @SaveTrf=();
       return;
    } 
    sleep 1; # отоспимся чтобы не сразу переконнект к БД
    return;
 } 

 $t_for_save=5; # 5 секунд на запись
 while( ($sql=shift @SaveTrf) && $t_for_save>0 )
 {
    if (length($sql)==1)
    {  # код, сообщающий какой тип трафика будет записываться в данный момент
       &SaveTrafInfo(29,$sql);
       next;
    }
    $t0_sql=[gettimeofday];
    $rows=$dbs->do($sql);
    $t0_sql=tv_interval($t0_sql);
    $t_for_save-=$t0_sql;
    # для статистики время выполнения запроса в зависимости от длины
    $_=int(length($sql)/1000);
    $Sql_tune_stat[$_][0]+=$t0_sql;
    $Sql_tune_stat[$_][1]++;
    $Sql_tune_stat[$_][2]+=$rows;
    last unless $rows;
 } 

 if( $SafeTrafSqls )
 {  # Процент выполнения sql. Обрати внимание, что когда @SaveTrf пустой, то $#SaveTrf=-1, поэтому надо +1
    $_=sprintf("%.1f",($SafeTrafSqls-$#SaveTrf-1)*100/$SafeTrafSqls);
    $rows=&sqldo("UPDATE traf_info SET data1='$_' WHERE time=$T_got_traf AND cod=14",'Процент выполнения записи трафика');
    $rows && $rows<1 && &sqldo("INSERT INTO traf_info SET time=$T_got_traf,cod=14,data1='$_'");
 }

 return if $#SaveTrf>=0;

 &SaveTrafTime(15,tv_interval($t_start_save_trf)); # время записи детализации трафика

 if( $Sql_tuning )
 {  # Статистика основанная на длине sql-запросов
    $out='';
    $sp=' ' x 13;
    $t_sum=0; # походу это более точное общее время записи трафика чем tv_interval($t_start_save_trf), т.к. учитывается только время на sql
    foreach( 0..20 )
    {
       ($t_sql,$n_sql,$rows)=@{$Sql_tune_stat[$_]}[0..2];# (время выполнения запросов, количество запросов, рядов)
       next if !$n_sql || !$t_sql;
       $len_sql=($_*1000)||1;
       $effect=int($rows/$t_sql);	# эффективность запроса: рядов/время выполнения
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
    # Пробелы и длины полей заточены под отображение через <pre>...</pre>
    &SaveTrafInfo(30,"   Длина sql|   Кол-во|    Рядов|Время,сек|Время/запрос|   Эффект|\n$out Общее время выполнения всех запросов: $t_sum\n");
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
    $Report.="Сеть `$net` в таблице направлений задана неверно. Формат `xx.xx.xx.xx/yy` либо `xx.xx.xx.xx`. Данная сеть игнорируется\n";
    &ToLog("Предупреждение: сеть `$net` в таблице направлений задана неверно. Формат `xx.xx.xx.xx/yy` либо `xx.xx.xx.xx`. Данная сеть игнорируется",'!!');
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
    $_="в таблице направлений сеть `$net` указана неверно (в двоичном виде маска сети отсекает единичные биты сети)";
    $Report.="$_\n";
    &ToLog("Предупреждение: $_",'!!');
 }

 # Построим идексированные по 3му октету массивы
 $_=$net_mask>23? 1 : $net_mask<17? 256 : 2**(24-$net_mask); # Кол-во вариантов 3го октета (например для сети /16 вариантов 256)
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
# Преобразование адресов всех сетей в HEX вид с двоичной маской
# =============================================================
sub MakeHexNets
{
 my($class,$default_mask,$infile,$fname,$fullname,$line,$net,$p,$port,$preset,$sth);
 my @f;
 $Need_nets_reload=0;
 $Report.='Результат выполнения обновления списка направлений: ';
 # переконнектимся, иначе если вдруг mysql отвалится, а $dbh будет активно, то мы не получим сети и будут серьезные проблемы
 &ConnectToDB;
 if( !$dbh )
 {
    &ToLog("Список сетей и их классов не обновлен т.к. нет соединения с БД",'!!');
    $Report.="ошибка - нет соединения с БД\n";
    return;
 }

 $sth=$dbh->prepare("SELECT * FROM nets WHERE priority>0 ORDER BY preset,priority");
 unless ($sth->execute)
 {
    &ToLog("Список сетей и их классов не обновлен - ошибка sql-запроса. Возможно утеряно соединение с БД",'!!');
    $Report.="ошибка sql-запроса. Возможно утеряно соединение с БД\n";
    return;
 }

 foreach (0..100)
 {  # $_ - номер пресета
    @{"b_nets$_"}=();		# сети
    @{"b_masks$_"}=();		# маски
    @{"b_classes$_"}=();	# классы сетей
    @{"b_port$_"}=();		# порт
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

    # загрузка списка из файла
    $fname=$1;
    $fullname=$fname=~/^\//? $fname : "$Program_dir/$fname";
    unless (open(FL,"<$fullname"))
    {
       &ToLog("Файл $fullname, указанный в описании списка сетей, не открывается на чтение!",'!!');
       $Report.="Файл $fullname, указанный в описании списка сетей, не открывается на чтение!\n";
       next;
    }
    @f=<FL>;
    close(FL);
    $infile='';
    $default_mask=$port||32; # если маска сети не указана, то будет либо по стандарту /32 либо такой, которая указана в поле 'порт', например для UA-IX должна быть /24
    foreach $line (@f)
    {
       next if $line!~/^\d/o || $line!~/^([^\s]+)\s*(.*)$/o;
       $port=int $2; # обязательно int т.к. $2 может быть неопределен
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
 %CLS=(); # обнулим кеш ip
 $Report.="Направления обновлены\n";
}

# -------------------------------------------
#  Проверка кого нужно отключить по таймауту
# -------------------------------------------
sub Check_unauth
{
 &Start_day if $Start_day_now!=localtime($t)->mday;

 $When_block_unauth=$t+$Kern_t_chk_auth;	# когда будем проверять след. раз
 foreach $id (grep{$t>$UtimeBlock{$_} && ($Uauth{$_} ne 'no')} @all)
 {  # слишком долго нет авторизаций - считаем неавторизованным
    $AuthQueue{$id}[0]='no';			# поле auth для таблицы users
    $AuthQueue{$id}[1]=0;			# код `отключился` для таблицы логинов
    $AuthQueue{$id}[2]=0;			# код `доступ выключен` для таблицы users_trf
    $AuthQueue{$id}[3]=$t;
 }

 &SetAuthInDB;

 # если пришло время обновить в переменных данные клиентов
 $t<$When_user_reload && return;
 $When_user_reload=$t+$Kern_t_usr_reload;
 &Get_user_info;
}

# -------------------------------------------
#  Вызывается в 0 часов 0 минут каждого дня
# Внимание:
# - возможны отклонения по времени, если в 0:0 будет
#   выполняться какая-либо функция (обсчет трафика и т.д)
# - при запуске nodeny.pl будет произведен запуск &Start_day
#   вне зависимости от времени запуска и выполнялась ли
#   &Start_day в этот день!
# ------------------------------------------- 
sub Start_day
{
 # $Start_day_now не меняем пока не выполним все, что задумано
 $dbh or &ConnectToDB;
 $dbh or return;
 $h=localtime($t);
 $day_now=$h->mday;
 $mon_now=$h->mon+1;
 $year_now=$h->year+1900;
 # запланированные смены пакета тарификации
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
       &ToLog("Не удалось обновить пакет клиента id=$mid",'!');
       next;
    }
    if( $rows<0 )
    {  # клиента нет в базе, пометим событие как ошибочное
       $dbh->do("UPDATE pays SET category=599 WHERE id=$id AND type=50 AND category=431 LIMIT 1");
       &ToLog("Запись id=$id в таблице pays помечена как недействительная т.к. связана с несуществующим клиентом $mid",'!');
       next;
    }
    $rows=$dbh->do("DELETE FROM pays WHERE id=$id AND type=50 AND category=431 LIMIT 1");
    &ToLog("По событию в таблице pays `запланированная смена пакета` - у клиента id=$mid изменен пакет на № $paket");
    $rows or next; # не $rows<1 - событие могло быть удалено параллельно
    $reason="Установлен пакет № $paket как результат события `запланированная смена пакета` автора admin_id=".$p->{admin_id}.", время: ".&the_time($p->{time});
    &SaveEventToDb($reason,410,$mid);
 }
 &Get_user_info;
 $Start_day_now=$day_now;
}
