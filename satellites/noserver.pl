#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
our $VER=50.33;

# Глобальные переменные, доступные nofire.pl:
#   %NET	- список сетей для определенного пресета и направления
#   %Tables	- номер таблицы ipfw, если эти сети занесены в нее
#   %NetsTbl	- массив сетей для определенного пресета и направления
# Ключем в массивах является: preset-номер_направления, например:
#   $NET{1-2}='10.0.0.0/8,100.200.200.200' - строка сетей пресета 1, направления 2
#   $Tables{3-4}=50 - сети пресета 3 направления 4 будут записаны в таблицу 50 ipfw
#   $NetsTbl{1-2}{10.1.1.0/24} - сеть '10.1.1.0/24' присутствует в таблице ipfw: $Tables{1-2}

use Time::HiRes qw( gettimeofday );
use Time::localtime;
use IO::Socket;
use DBI;
use nosat qw( 
  &Nosat_init &Debug &Log &Exit &Error &TimeNow &Sql &SaveSatStateInDb
  $v %c $Exit_reason $Exit_cod $ReStat $Program_dir $SQL_BUF $FiltrDb_user $Config_time $Err_connect
);

&Nosat_init($VER,'noserver',2); #(версия, имя агента, id агента);

our $Start_num_ipfw=$c{Start_num_ipfw};
our $End_num_ipfw=$c{End_num_ipfw};
our $Start_num2_ipfw=$c{Start_num2_ipfw};
our $End_num2_ipfw=$c{End_num2_ipfw};

my $nofire="$Program_dir/nofire.pl";
( -e $nofire ) or &Error("Script $nofire is not found!");
eval{require $nofire};
$@ && &Error("Check $nofire!");

# условие включения
our $Where_auth='';
$Where_auth.=" AND auth<>'off'" if !$c{Allow_auth_off};
$Where_auth.=" AND (auth<>'no' OR lstate<>0)" if !$c{Allow_unauth};
$c{Usr_nosrvr_groups}=~s|\s||g;
our $Where_grp=$c{Usr_nosrvr_groups}? " AND grp IN($c{Usr_nosrvr_groups})" : '';
our $Dopdata_tmpl=int $c{Noserver_dopdata_tmpl};
our $Where_tmpl='WHERE parent_type=0'.(!!$Dopdata_tmpl && " AND template_num=$Dopdata_tmpl");

our $t=&TimeNow();

our %ON=();			# список всех ip обслуживаемых групп, кому разрешен доступ
our %All=();			# список ВСЕХ существующих ip в NoDeny (не только обслуживаемых групп)
our %AllOn=();			# список всех ip в NoDeny (не только обслуживаемых групп), кому разрешен доступ
our %Uday_traf=();
our %U=();
our %Num_id=();
our %Now_revision=();
our %Revision=();
our %Udop=();
our %Utraf=();
our %Opt=();
our %id_to_ip=();

our %NET=();
our %Tables=();
our %NetsTbl=();

our @Plan_flags=();
our @Plan_speed=();
our @Plan_speed_out=();
our @Plan_speed2=();
our @Plan_preset=();
our @Plan_script=();

our $No_activity=0;
our $Err_get_uinfo=0;
our $LastTrafDay=0;
our $When_load_user_info=0;	# Когда получаем данные о клиентах, сразу же
our $Reload_period=0;
our $num_i=0;			# С этого числа будет идти отсчет числового идентификационного номера каждого ip-адреса
our $t_stat=0;			# Время когда необходимо записать в базу статистику о ходе работы агента, сейчас же
our $nRules=0;
our $sql_time=0;		# Общее время выполнения основных sql-запросов
our $sql_count=0;		# Их количество
our $report='';

our $t_db_error=0;
our $dbh;

&Log('Starting noserver');

while( !&Load_Tarif )
{
   &Log('Cannot load tarifs!');
   $dbh && &SaveSatStateInDb('Ошибка при загрузке тарифов. Повторная попытка через 60 сек',1);
   sleep 60;
}

my ($p,$sth);
$p=localtime();
my($mon,$year,$day)=($p->mon,$p->year,$p->mday);
my $tbl_traf='x'.($year+1900).'x'.($mon+1).'x'.$day; 
&Debug("Для каждого клиента получим его трафик за текущий день.");
%Uday_traf=();
$sth=&Sql("SELECT mid, SUM(`in`) as tin, SUM(`out`) as tout FROM $tbl_traf WHERE class=1 GROUP BY mid");
if( $sth )
{
   while( $p=$sth->fetchrow_hashref )
   {
      $Uday_traf{$p->{mid}}=$p->{tin}+$p->{tout};
      $v && &Debug(sprintf("id: %d in: %d out: %d sum: %d",$p->{mid},$p->{tin},$p->{tout},$Uday_traf{$p->{mid}}));
   }
}

&Flush(); # обнуление фаервола

while(1)
{
  sleep 1;
  &Run_Ipfw_Rules;
  $t=&TimeNow();
  &LoadClientInfo if $t>$When_load_user_info;
  &SendAgentStat if $t>$t_stat; # пора записать статистику о ходе работы
  $Exit_reason && last;
}

&Exit;

# Соединяемся с БД не чаще 5 сек
sub SoftConnectToDB
{
 tv_interval($t_db_error)<5 && return;
 $t_db_error=[gettimeofday];
 &ConnectToDB;
}

sub Load_Tarif
{
 &Debug('Загружаем тарифы');
 my ($hour,$i,$id,$p,$speed,$speed_out,$speed2,$sth,$t1,$t2);
 $hour=localtime()->hour;
 $sth=&Sql("$SQL_BUF * FROM plans2");
 $sth or return(0);
 $i=6;
 &Debug("Показано только $i строк:");
 while( $p=$sth->fetchrow_hashref )
 {
    $id=$p->{id};
    $Plan_flags[$id]=$p->{flags};
    $speed=$p->{speed};
    $speed_out=$p->{speed_out};
    $speed2=$p->{speed2};
    $t1=$p->{start_hour};
    $t2=$p->{end_hour};

    if(
        $Plan_flags[$id]=~/n/ && (
          ($t1<$t2 && ($hour>=$t1 && $hour<$t2)) ||
          ($t1>$t2 && ($hour>=$t1 || $hour<$t2))
        )
      )
    {  # в период времени с $t1 по $t2 удвоение скорости
       $speed*=2;
       $speed_out*=2;
    }

    $Plan_speed[$id]=$speed;
    $Plan_speed_out[$id]=$speed_out;
    $Plan_speed2[$id]=$speed2;
    $Plan_preset[$id]=$p->{preset};
    $Plan_script[$id]=$p->{script};

    $v && (--$i>=0) && print "\tid: $id\tpreset: $Plan_preset[$id]\tspeed: $speed\tspeed_out: $speed_out\tspeed2: $speed2\tflags: $Plan_flags[$id]\n";
 }
 return(1);
}

# Возврат уникального номера для текущего id 
sub Num
{
 my $id=shift;
 $Num_id{$id} && return($Num_id{$id});
 $Num_id{$id}=++$num_i;
 return($num_i);
}

# --- Запретить доступ ---
sub Deny_inet
{
 my $id=shift;
 $ON{$id} or return;
 $ON{$id}='';
 &Debug("$U{$id}{ip} вызов &Deny из nofire.pl");
 &Deny({
    paket	=> $U{$id}{paket},
    num		=> &Num($id),
    ip		=> $U{$id}{ip},
    options	=> $U{$id}{options},
    main_num	=> &Num($U{$id}{mid}),
    plan_flags	=> $Plan_flags[$U{$id}{paket}],
 });
}

# ---  Разрешить доступ  ---
sub Allow_inet
{
 my ($id)=@_;
 my ($auth,$data,$hash,$ip,$mid,$options,$p,$paket,$plan_flags,$speed_in,$speed_out,$speed2,$sth,$time,$traf);

 $ip=$U{$id}{ip};
 $mid=$U{$id}{mid};
 $auth=$U{$id}{auth};
 $paket=$U{$id}{paket};
 $options=$U{$id}{options};
 $speed2=$Plan_speed2[$paket];
 $speed_in=$Plan_speed[$paket];
 $speed_out=$Plan_speed_out[$paket];
 $plan_flags=$Plan_flags[$paket];

 &Debug("ip: $ip Userid: $id. Удовлетворяет условиям включения");
 
 if( $Now_revision{$id} != $Revision{$id} )
 {  # изменились дополнительные данные клиента
    &Debug("Обнаружено изменение ревизии дополнительных данных:\n".
           "\told: ".($Now_revision{$id}||'отсутствует')."\n".
           "\tnow: $Revision{$id}");
    $sth=&Sql("$SQL_BUF field_alias,field_value,field_name FROM dopdata $Where_tmpl AND parent_id=$id");
    $data='';
    if( $sth )
    {
       $Udop{$id}={};
       while( $p=$sth->fetchrow_hashref )
       {
          $Udop{$id}{$p->{field_alias}}=$p->{field_value};
          $data.="\n\t\talias: ".$p->{field_alias}.
                 "\n\t\t name: ".$p->{field_name}.
                 "\n\t\tvalue: ".$p->{field_value}.
                 "\n\t\t------";
       }
       &Debug($data);
       $Now_revision{$id}=$Revision{$id};
    }
 }

 # === Start обработки сриптов ===

 {
    $plan_flags=~/p/ or last; # скрипты отключены
    $Plan_script[$paket] or last;
    &Debug('Обработка скриптов');
    $time=localtime()->hour;
    foreach $p (split /\n/,$Plan_script[$paket])
    {
       $v && &Debug("Анализируем строку: $p");
       if( $p=~s/^<time *([^>]+)>// )
       {  # у скрипта есть время работы
          $data=",$1,";
          if( $data!~/,$time,/ )
          {
             &Debug('По времени не подходит');
             next; 
          }
       }
 # ===  Динамическое управление скоростями ===
       if(  $p=~/^(0|1):(.+)$/o )
       {  
          $data=$2;
          $traf=int( ($1? $Uday_traf{$mid} : $Utraf{$mid})/1000000 );
          &Debug("$ip traf=$traf Mb [script: $data]");
          foreach( split /:/,$data )
          {
             /^(\d+)\-(\d+)$/o or next;
             $traf<$1 && last;
             $speed_out=int($2*$speed_out/($speed_in||1));
             $speed_in=$2;
          }
       }
    }
    &Debug('Обработка скриптов закончена');
 }

 # === End обработки сриптов ===

 # сформируем строку, включающую все параметры
 $hash="$auth $paket si:$speed_in so:$speed_out s2:$speed2 sf:$plan_flags [$Now_revision{$id}][$options]";
 &Debug("Текущий хеш всех актуальных данных клиента:\n\t\t$hash");
 if( $ON{$id} )
 {
    if( $ON{$id} eq $hash )
    {
       &Debug('Cовпадает с предыдущим. Клиент остается подключенным');
       return;
    }
    &Debug("Хеш данных изменился - отключим и включим. Предыдущий хеш:\n\t\t$ON{$id}");
    &Deny_inet($id);			# переформирование правил
    
 }
 $ON{$id}=$hash;

 &Debug("Вызов &Allow из nofire.pl");
 &Allow({
    num		=> &Num($id),
    main_num	=> &Num($mid),
    id		=> $id,
    mid		=> $mid,
    ip		=> $ip,
    auth	=> $auth,
    paket	=> $paket,
    speed2	=> $speed2,   
    speed_in	=> $speed_in,
    speed_out	=> $speed_out,
    dop_param	=> $Udop{$id},
    plan_flags	=> $plan_flags,
    options	=> $options
 });
}

# ==========================
# Считывание инфы о клиентах
# ==========================
sub LoadClientInfo
{
 my ($auth,$fname,$h,$id,$ip,$lstate,$mess,$mid,$msql,$net,$now_getting_all_info,$paket,$sql,$sth,$sth2,$traf);
 &Debug('Получение данных клиентов');
 
 $When_load_user_info=&TimeNow()+$c{Period_load_user_info};

 $h=localtime()->mday;
 %Uday_traf=() if $LastTrafDay && $LastTrafDay!=$h; # начались новые сутки, обнулим суточный трафик
 $LastTrafDay=$h;

 $msql="$SQL_BUF id,mid,ip,auth,lstate,paket FROM $c{Db_usr_table} WHERE state<>'off'$Where_grp";
 if( $Reload_period-- <= 0 )
 {  # пришло время получить полный список ip
    $mess='$Reload_period <= 0 - получим полный список клиентов.';
    $Reload_period=$c{Period_load_all_info};
    $now_getting_all_info=1;
 }
  else
 {
    $mess='Получим список клиентов, удовлетворяющих условию включения';
    $msql.=$Where_auth;
    $now_getting_all_info=0;
 }

 # загрузим модификаторы скоростей (результаты опционных платежей)
 &Debug('Получим все модификаторы скоростей (опции).');
 $sth=&Sql("$SQL_BUF uid,options FROM users_trf WHERE options<>''");
 if( $sth )
 {
    %Opt=();
    $Opt{$_->{uid}}=$_->{options} while ($_=$sth->fetchrow_hashref);
 }
  else
 {
    &Debug('Будем пользоваться утаревшими данными, если есть');
 }

 my %NowAll=(); # список абсолютно всех ip NoDeny. В этой точке:
 # %All   - список всех ip за прошлый срез
 # %AllOn - состояние включения, 1 - ip включен
 $sql="$SQL_BUF uid,uip,now_on,in1,out1 FROM users_trf";
 $sth=&Sql($sql);
 if( !$sth )
 {
    $Err_get_uinfo++<3 && &Log("Error: $sql");
    $v && &Debug('Прекращаем выполнение подпрограммы. Следующий запуск через '.int($When_load_user_info-&TimeNow()).' сек');
    return;
 }

 while( $p=$sth->fetchrow_hashref )
 {
    $ip=$p->{uip} or next; # бывает для удаленных записей
    $id=$p->{uid};
    $NowAll{$ip}=1;
    $traf=$p->{in1}+$p->{out1};
    if( defined($Utraf{$id}) && $traf>$Utraf{$id})
    {
       $Uday_traf{$id}+=$traf-$Utraf{$id};
       $v && &Debug(sprintf("Обнаружено увеличение трафика на %d",$traf-$Utraf{$id}));
    }
    $Utraf{$id}=$traf;
    if( !$All{$ip} )
    {  # новый ip в базе
       &Debug("$ip новый для нас. Запомним в %All. Запуск из nofire.pl: &Add_To_All_Ip($ip)");
       &Add_To_All_Ip($ip);
       $All{$ip}=1;
       $AllOn{$ip}=0;
    }
    $h=$p->{now_on};
    $v && &Debug(sprintf("%s трафик: %d за сутки: %d состояние now_on: %d",$ip,$Utraf{$id},$Uday_traf{$id},$h));
    $AllOn{$ip}!=$h or next;
    $AllOn{$ip}=$h;
    $h? &Add_To_Allow_Ip($ip) : &Delete_From_Allow_Ip($ip);
 }

 # все ip, которые присутствовали в прошлый срез, а в этот отсутствуют - удалим
 foreach $ip (grep !$NowAll{$_}, keys %All)
 {
    &Debug("Обнаружено, что $ip удален из БД");
    &Delete_From_All_Ip($ip);
 }
 %All=%NowAll;

 sub SaveNet
 {
   my ($net,$id)=@_;
   $NET{$id}.=$NET{$id}? ",$net" : $net;
   $Tables{$id} or return;
   # Текущую сеть необходимо добавить в таблицу ipfw
   $id=$Tables{$id}; # номер таблицы ipfw
   if( !$NetsTbl{$id}{$net} )
   {  # в таблице $id еще нет сети $net
      &Debug("В таблице $id еще нет сети $net, добавляем");
      &Add_To_Table($net,$id);
   }
   # 2 - признак, что сеть в _текущем_ срезе присутствует в описании сетей  
   $NetsTbl{$id}{$net}=2;
 }

 {
  $now_getting_all_info or last;
  # Получим ревизии дополнительных параметров клиентов
  &Debug("Получим актуальные ревизии допданных всех клиентов.");
  $sth=&Sql("$SQL_BUF parent_id,MAX(revision) AS r FROM dop_oldvalues GROUP BY parent_id");
  $sth or last;
  $Revision{$_->{parent_id}}=int($_->{r}) while( $_=$sth->fetchrow_hashref );

  $sth=&Sql("$SQL_BUF * FROM nets ORDER BY priority");
  $sth or last;

  %U=();		# Обнулим массив клиентов т.к он будет формироваться с нуля чтобы исключить удаленных из базы
  &Load_Tarif;		# Обновим тарифы т.к в тарифах могут измениться скорости
  %NET=();
  %Tables=();		# глобальный - должен быть доступен в nofire.pl
  # загрузим сети для направлений
  while( $p=$sth->fetchrow_hashref )
  {
     $net=$p->{net};
     $id=$p->{preset}.'-'.$p->{class};
     unless ($p->{priority})
     {  # текущая запись - название направления. При этом, если port!=0, то он указывает на номер таблицы ipfw,
        # куда нужно записать все сети указаного класса и пресета
        $h=$p->{port};
        next if $h<30 || $h>126; # До 30й таблицы зарезервированы, 126 - потому что +1 для таблицы с клиентами
        &Debug('Для направления `'.$p->{comment}."` все сети будут добавлены в таблицу $h");
        $Tables{$id}=$h;
        next;
     }

     $net or next;
     if( $net!~/^\s*file:\s*(.+)$/i )
     {
        &SaveNet($net,$id);
        next;
     }

     $fname=$1;
     &Debug("Список сетей динамический и находится в таблице files с именем $fname");
     $fname=~s|\\|\\\\|g;
     $fname=~s|'|\\'|g;
     $sql="$SQL_BUF data FROM files WHERE name='$fname'";
     $h=&Sql($sql);
     if( !$h || !($h=$h->fetchrow_hashref) )
     {
        next;
     }
     foreach $net (split /\n/,$h->{data})
     {
        next if $net!~/^\d/o || $net!~/^([^\s]+)\s*(.*)$/o;
        &SaveNet($1,$id);
     }
  }

  # удалим из ipfw-таблиц сети, которые удалены из БД
  foreach $id (keys %NetsTbl)
  {
     for $net (keys %{$NetsTbl{$id}})
     {
        if( $NetsTbl{$id}{$net}>1 )
        {
           $NetsTbl{$id}{$net}=1;
           next;
        }
        delete $NetsTbl{$id}{$net};
        &Debug("Удаляем сеть $net из таблицы $id т.к. сеть удалена из БД");
        &Delete_From_Table($net,$id);
     }
  }
 }

 $t=&TimeNow();
 &Debug($mess);
 $sth=&Sql($msql);
 if( !$sth )
 {
    $Err_get_uinfo++<3 && &Log("Error: $msql");
    return;
 }

 $h=&TimeNow()-$t;
 $sql_time+=$h;
 $sql_count++;

 if( $sth->rows )
 {
    $No_activity=0;
 }
  elsif( $No_activity++>4 )
 {
    &Debug(">4 попыток получить список авторизованных клиентов дал пустой результат. Либо никто не авторизован, либо ошибка. Поставим признак переконнектиться с БД");
    $dbh='';
 }

 my %NowOn=(); # кому мы включаем доступ в текущий срез
 while( $p=$sth->fetchrow_hashref )
 {
    $ip=$p->{ip};
    $id=$p->{id};
    # произошла смена ip и при этом старый ip во включеном состоянии - вырубаем старый ip
    $id_to_ip{$id} && ($id_to_ip{$id} ne $ip) && $ON{$id} && &Deny_inet($id);
    $id_to_ip{$id}=$ip;
    $mid=$p->{mid} || $id;
    $auth=$p->{auth};
    $paket=$p->{paket};
    $lstate=$p->{lstate};

    $U{$id}{ip}=$ip;
    $U{$id}{mid}=$mid;
    $U{$id}{auth}=$auth;
    $U{$id}{paket}=$paket;
    $U{$id}{options}=$Opt{$mid};

    &Debug("ip: $ip auth: $auth".(!!$lstate && ' (всегда онлайн)'));
    # поскольку иногда мы считываем полный список клиентов, то проверим авторизацию
    if( !$c{Allow_unauth} && ($auth eq 'no') && !$lstate )
    {
       &Debug('Не удовлетворяет условиям включения');
       next;
    }
    # авторизован в режиме `отключен` и при этом опция "разрешить доступ при авторизации `сеть`" не включена
    ($auth eq 'off') && !$c{Allow_auth_off} && next;
    # если клиент превысил лимиты - доступ не разрешаем
    $auth>0 && !$c{Allow_overlimits} && next;
    &Allow_inet($id);
    $NowOn{$id}=1;
 }
 # отключим тех, кто включен и в новом списке не присутствует
 foreach $id (grep $ON{$_} && !$NowOn{$_}, keys %ON)
 { 
    &Debug("$ip в прошлый срез удовлетворял условиям включения, сейчас нет - выключаем");
    &Deny_inet($id);
 }

 &Debug('Запрошена ли тестовая информация о каком либо клиенте');
 $sth=&Sql("SELECT uid,test FROM users_trf WHERE test>0");
 if( $sth )
 {
    while( $p=$sth->fetchrow_hashref )
    {
       $id=$p->{uid};
       $U{$id}{test}!=$p->{test} or next;
       $ip=$U{$id}{ip};
       $report.="Состояние клиента id=$id. ";
       if( !$ip )
       {
          $report.='Нет данных. Вероятно клиент в группе, которую не обслуживает данный сателлит. '.
             'Если учетка клиента была только что создана - повторите запрос примерно через '.
             $c{Period_load_user_info}*$c{Period_load_all_info}." сек\n";
          next;
       }
       $U{$id}{test}=$p->{test};
       $h=$U{$id}{auth};
       $report.="ip=$ip. Поле auth: $h (".($h eq 'no'? 'не авторизован': $h>0? 'авторизован, но заблокирован по переработке' : 'авторизован').'). '.
         ($NowOn{$id}? 'Доступ в фаерволе разрешен' : 'Доступ в фаерволе заблокирован').". Пакет тарификации: $U{$id}{paket}.\n";
    }
 }

 if( $now_getting_all_info )
 {
    &Debug('Изменился ли конфиг?');
    $sth=&Sql("SELECT time FROM conf_sat WHERE login='$FiltrDb_user' AND time<>$Config_time LIMIT 1");
    if( $sth && $sth->fetchrow_hashref )
    {
       &Log("I found new config! Reloading...");
       $Exit_reason='Обнаружено, что конфиг изменился. Перезагрузка приведет к перечитыванию конфига.';
       $Exit_cod=0;
       &Exit; # вертушка запустит скрипт снова
    }
 }
 $v && &Debug('Нормальное завершение работы подпрограммы. Следующий запуск через '.int ($When_load_user_info-&TimeNow()).
   " сек. Периодов до следующего полного перечитывания: $Reload_period");
}

# =========================================
#      Запись статистики о ходе работы
# =========================================
sub SendAgentStat
{
 $t_stat=$t+$ReStat; # когда следующая статистика
 $report.="Запусков ipfw: $nRules";
 $report.="\nСреднее время выполнения sql-запросов ".sprintf("%.3f",$sql_time/$sql_count).' сек' if $sql_count;
 $report.="\nошибок соединения с БД: $Err_connect" if $Err_connect;
 $report.="ошибок получения info клиентов: $Err_get_uinfo\n" if $Err_get_uinfo;
 &SaveSatStateInDb($report||'ok',($Err_get_uinfo+$Err_connect)>3? 1:0);
 $Err_connect=$Err_get_uinfo=0;
 $report='';
 $nRules=0;
}
