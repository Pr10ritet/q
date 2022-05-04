#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use DBI;
use Digest::MD5;
use Time::localtime;

# ip, при заходе с которого будут выводиться отладочные сообщения. ТОЛЬКО ДЛЯ ОТЛАДКИ. После закомментировать!
$V='172.17.17.110'; 

$Main_config='/usr/local/nodeny/nodeny.cfg.pl'; # дефолтовый путь к конфигу, переопределяется в &get_main_config()
eval{ &get_main_config() };			# название файла-конфига возьмем из подпрограммы, дописанной инсталлятором

$Max_byte_upload=8000; # максимальное количество байт, которые принимаем по методу post. Не забываем, что клиенты могут посылать длинные послания
$Time_User_ReAuth=40;

$script=$ENV{SCRIPT_NAME};
$scrpt=$script.'?';
$ip=$ENV{REMOTE_ADDR};
$ip=~s|[^\d\.]||g;
$RealIp=$ip;
$V=defined($V) && ($V eq $ip) && "Режим отладки (не забудьте отключить!). Вашему ip $ip в stat.pl разрешено просматривать информацию об ошибках более детально:<br><br>";

$VER_chk=$VER;
$VER_script='stat.pl';

if( $ENV{REQUEST_METHOD} eq 'POST' )
{
   $t=$ENV{CONTENT_LENGTH};
   $t>$Max_byte_upload && &Error_X("Объем переданных post-методом данных превысил $Max_byte_upload байт",'Объем переданных данных превысил допустимое значение.'); 
   read(STDIN,$p,$t)
}else
{
   $p='';
}

$p.='&'.$ENV{QUERY_STRING}; # Совмещаем get и post данные (в некоторых модулях это необходимо - см. SPrivatSentry.pl)

%F=();   
foreach( split /&/,$p )
{
   ($name,$value)=split /=/;
   $name=~tr/+/ /;
   $name=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $value=~tr/+/ /;
   $value=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $F{$name}=$value;
}

# сообщать о проблемах или 'обратитесь к администратору' не стоит - будет шквал звонков в техподдержку
$Er_Mess_for_Client='Данные недоступны - ведутся технические работы на сервере.';

(-e $Main_config) or &Error_X("$V Не могу загрузить конфигурационный файл $Main_config",$Er_Mess_for_Client);
eval{require $Main_config};
$@ && &Error_X("$V Ошибка в конфигурационном файле $Main_config",$Er_Mess_for_Client);

$Nodeny_dir_web="$Nodeny_dir/web";

$Lang=uc($Lang) || 'RU';
$Lang_file="$Nodeny_dir_web/LANG_$Lang.pl";
(-e $Lang_file) or &Error_X("$V Не могу загрузить файл $Lang_file",$Er_Mess_for_Client);
eval{require $Lang_file};
$@ && &Error_X("$V Ошибка в файле $Lang_file",$Er_Mess_for_Client);

$Er_Mess_for_Client=$Lang_statpl_err_for_usrs;
$V&&=$Lang_statpl_debug_mode || '!';

$call_pl="$Nodeny_dir_web/calls.pl";
(-e $call_pl) or &Error_X("$V $Lang_cannot_load_file $call_pl",$Er_Mess_for_Client);
require $call_pl;
$VER_chk==$VER or &Error_X("$V $Lang_statpl_diff_ver_callpl",$Er_Mess_for_Client);

$nSql_pl="$Nodeny_dir_web/nSql.pl";
(-e $nSql_pl) or &Error_X("$V $Lang_cannot_load_file $nSql_pl",$Er_Mess_for_Client);
require $nSql_pl;

$Ashowsql=1; # sql запросы будут складироваться в $DOC->{admin_area}. Если потом окажется, что их нельзя показывать, то обнулим

$kb||=1000; $mb=$kb*$kb;
$start=int $F{start};
$ut='unix_timestamp()';
$Html_title=$Lang_statpl_title;
$MessWrongAuth=&div('nav',&bold($Lang_statpl_wrong_auth).$br3.&ahref("$script?a=99",$Lang_statpl_auth_button));

$DSS="DBI:mysql:database=$db_name;host=$db_server2;mysql_connect_timeout=$db_conn_timeout2;";
$DSN="DBI:mysql:database=$db_name;host=$db_server;mysql_connect_timeout=$db_conn_timeout;";
$dbh=DBI->connect($DSN,$user,$pw,{PrintError=>1}); # в логи вебсервера пишем ошибки
$dbh or &Error_Y("$V Не могу соединиться с БД на $db_server",$Er_Mess_for_Client);
&SetCharSet($dbh);

$p=&sql_select_line($dbh,"SELECT $ut");
$p or &Error_Y("$V $Lang_statpl_err_get_time",$Er_Mess_for_Client);
$t=$p->{$ut};

# ============================
#      НАЧАЛО АВТОРИЗАЦИИ
# ============================

$h=localtime($t);
$day_now=$h->mday;
$year_now=$h->year;
$mon_now=$h->mon;
$ses1=$day_now.$mon_now.$year_now; # сформируем id сессии на основе текущей даты. Не перемещай вглубь - используется в форме для логина
$mon_now++;

$PP=$F{pp}||'';			# хеш пароля через форму
$PP='' if &Filtr_mysql($PP) ne $PP; # в хеше могут быть только допустимые символы, иначе это подделка

%FormHash=();
%Adm=('id'=>0);
$AUTH=0;

# авторизовался админ?
if($PP)
{  # авторизация через форму
   $p=&sql_select_line($dbh,"SELECT * FROM admin_session WHERE act=2 AND salt='$PP' AND system_id='$system_id' LIMIT 1");
   if( $p )
   {
      $url=&ahref("$Script_adm?a=login",$Lang_statpl_auth_button);
      $t>$p->{time_expire} && &Error_Y(&Printf($Lang_statpl_login_err_time,$url));
      $p=&sql_select_line($dbh,"SELECT * FROM admin WHERE id=".$p->{admin_id});
      $p or &Error_Y(&Printf($Lang_statpl_login_err_session,$url));
      $scrpt.="pp=$PP&";
      $Script_adm.="?pp=$PP&";
      $FormHash{pp}=$PP;
      $AUTH=1;
   }
}
 elsif( $ENV{REMOTE_USER} ne '' )
{  # авторизация вебсервером
   $p=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE admin='".&Filtr_mysql($ENV{REMOTE_USER})."' LIMIT 1",'',"скрыт: select from admin where admin='...'");
   if( $p )
   {
      if( $p->{"AES_DECRYPT(passwd,'$Passwd_Key')"} ne '-' )
      {
         &Login();
         &Error($Lang_statpl_need_second_login);
      }
      $AUTH=1;
   }
}

{
 if( $AUTH )
 {
    $Adm{id}=$p->{id};
    $Adm{office}=$p->{office}; # Для проверки доступности определенного тарифа в nomoney.pl 
    $Adm{login}=$p->{admin};
    $Adm{privil}=$p->{privil};
    $PR{$_}=1 foreach (split /,/,$Adm{privil});
    $pr_on=1;
    $Ashowsql=$PR{2} && $PR{3} && $p->{tunes}=~/,showsql,1/;
    $DOC->{admin_area}='' unless $Ashowsql;
    $PR{100} or &Error($Lang_statpl_no_stat_priv);
    $id=int $F{id};
    $Adm{full}="$Adm{login} (id=$Adm{id}, $RealIp)";
    next;
 }

 # Точно не админ
 $DOC->{admin_area}='';
 $Ashowsql=0;
 $id=0;

 # Логин передан через форму?
 $UU=$F{uu};
 $fUU=&Filtr_mysql($UU);
 next if $fUU eq '';

 $p=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM users WHERE name='$fUU' LIMIT 1");
 $p or &Error($V? "$V $Lang_statpl_no_usr_login":$MessWrongAuth);
 $pass=$p->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
 $salt=Digest::MD5->new;
 # Если наступили новые сутки, то возможны сессии под старым id. 2 часа максимум продолжительность сессии (7200 секунд)
 $h=localtime($t-7200);
 $ses2=($h->mday).($h->mon).($h->year);
 $hash1=$salt->add("$ses1 $pass"); $hash1=$hash1->hexdigest;
 $hash2=$salt->add("$ses2 $pass"); $hash2=$hash2->hexdigest;
 ($hash1 ne $PP) && ($hash2 ne $PP) && &Error($V? "$V $Lang_statpl_err_auth_hash":$MessWrongAuth);
 $AUTH=1;
 $PP=$hash1;
 $scrpt.="uu=".&URLEncode($UU)."&pp=$PP&";
 $FormHash{uu}=$UU;
 $FormHash{pp}=$PP;
 $id=$p->{id};
}

# ====== Здесь: ======
# $AUTH=1 если прошел авторизацию по логину клиента/админа
# $Adm{id}>0 если авторизовался админ

$where=$id? "id=$id":"ip='$ip'";
$p=&sql_select_line($dbh,"SELECT * FROM users WHERE $where LIMIT 1"); 
if( !$p )
{  # записи с запрошенным id (ip) нет
   # если не авторизован или авторизован не админ, то пусть заново логинится
   if (!$AUTH || !$Adm{id}) {&Login(); &Exit}
   # авторизовался админ, но записей с заказанным id нет, поэтому покажем статистику любого клиента
   $p=&sql_select_line($dbh,"SELECT * FROM users LIMIT 1",$Lang_statpl_sql_no_usr);
   $p or &Error($Lang_statpl_usr_tbl_is_empty);
   $OUT.=&Center_Mess(&Printf($Lang_statpl_no_usr,$where),1);
}

# Если клиент не авторизовался паролем, то проверим авторизовался ли он авторизатором
if (!$AUTH && $p->{auth} eq 'no') {&Login(); &Exit}

# ========= АВТОРИЗОВАН =========

$a=int $F{a} || 101; # код плагина
$scrpt.="a=$a";

&ReAuth($p->{state} eq 'off') if $a==98; # Периодическая авторизация

# Данные выбранной записи, возможно не основной
$id=$p->{id};
$mid=$p->{mid};
if ($mid)
{ # просматриваемая запись - алиасная
   $Mid=$mid;
   $sth=&sql($dbh,"SELECT * FROM users WHERE id=$Mid LIMIT 1",$Lang_statpl_sql_alias_get_mid);
   ($pm=$sth->fetchrow_hashref) or &Error($Lang_statpl_err_main_id_ref);
}
 else
{
   $Mid=$id;
   $pm=$p;
}
$grp=$pm->{grp};

$nAlias=0; # кол-во всех записей клиента
$sth=&sql($dbh,"SELECT * FROM users WHERE id=$Mid OR mid=$Mid",$Lang_statpl_sql_get_all_alias);
while( $h=$sth->fetchrow_hashref )
{
   $nAlias++;
   $_=$h->{id};
   $U{$_}{name}=$h->{name};
   $U{$_}{ip}=$h->{ip};
   $U{$_}{fio}=$h->{fio};
   $U{$_}{state}=$h->{state};
   $U{$_}{state_off}=$h->{state} eq 'off';
   $U{$_}{o_name}=&Filtr_out($U{$_}{name});
   $U{$_}{m_name}=&Filtr_mysql($U{$_}{name});
   $U{$_}{o_fio}=&Filtr_out($U{$_}{fio});
   $U{$_}{m_fio}=&Filtr_mysql($U{$_}{fio});
}

if( $Adm{id} )
{
  $h=$Adm{id};
  if( $grp )
  {  # разрешено ли просматривать админу данную запись?
     $p2=&sql_select_line($dbh,"SELECT grp_admins,grp_admins2 FROM user_grp WHERE grp_id=$grp",$Lang_statpl_sql_u_grp_priv);
     $p2 or &Error($Lang_statpl_err_get_u_grp_priv);
     &Error($Lang_statpl_err_no_u_grp_priv) if $p2->{grp_admins}!~/,$h,/ || $p2->{grp_admins2}!~/,$h,/;
  }
  $V=$Lang_statpl_detail_msg;
  $OUT.=&Table('nav width100 table1',&RRow('','lcr',
    (!!$Ashowsql && &ahref('javascript:show_x("adm")','Debug')).
    &ahref($Script_adm,$Lang_statpl_btn_adm).
    &ahref($Script_adm."a=user&id=$id",$Lang_statpl_btn_u_data).
    &ahref($Script_adm."a=pays&mid=$Mid",$Lang_statpl_btn_u_account),
    "$Lang_statpl_lbl_u: ".&bold($U{$id}{o_name})." ($U{$id}{ip})".(!!$mid && ", основная запись: ".&bold($U{$Mid}{o_name})." ($U{$Mid}{ip})"),
    "$Lang_statpl_lbl_adm: <span class=data2>$Adm{full}</span>")
  );
}
 else
{
  $OUT.=&Printf('[bold|div head big pddng2|div row2 borderblue|div pddng2]',$Lang_statpl_title);
}

$Fid=int $F{id};
$scrpt.="&id=$Fid" if $Fid;
$FormHash{id}=$Fid;
$FormHash{a}=$a;

$nomoney_pl="$Nodeny_dir/nomoney.pl";
(-e $nomoney_pl) or &Error($Lang_statpl_err_without_info.($V? "$V $Lang_statpl_err_4_for_adm $nomoney_pl" : $Lang_statpl_err_4_for_u));
require $nomoney_pl;
$VER_chk==$VER or &Error($Lang_statpl_err_without_info.($V? "$V $Lang_statpl_err_6_for_adm $nomoney_pl" : $Lang_statpl_err_6_for_u));
&TarifReload;

$paket=$pm->{paket};
$paket3=$pm->{paket3};
$U{$Mid}{paket}=$paket;
$U{$Mid}{paket3}=$paket3;
$U{$Mid}{balance}=$pm->{balance};
$U{$Mid}{srvs}=$pm->{srvs};
$U{$Mid}{start_day}=$pm->{start_day};
$U{$Mid}{discount}=$pm->{discount};
$U{$Mid}{preset}=$Plan_preset[$U{$Mid}{paket}];

@T=&GetClientTraf($Mid);
$traf1=&Get_need_traf($T[0],$T[1],$InOrOut1[$paket])/$mb;
$traf2=&Get_need_traf($T[2],$T[3],$InOrOut2[$paket])/$mb;
$traf3=&Get_need_traf($T[4],$T[5],$InOrOut3[$paket])/$mb;
$traf4=&Get_need_traf($T[6],$T[7],$InOrOut4[$paket])/$mb;

$money_param={
  paket=>$U{$Mid}{paket},
  paket3=>$U{$Mid}{paket3},
  traf1=>$traf1,
  traf2=>$traf2,
  traf3=>$traf3,
  traf4=>$traf4,
  service=>$U{$Mid}{srvs},
  start_day=>$U{$Mid}{start_day},
  discount=>$U{$Mid}{discount},
  mode_report=>0
};

$h=&Money($money_param);

$U{$Mid}{money}=$h->{money};
$U{$Mid}{money_over}=$h->{money_over};
$block_cod=$h->{block_cod};
$str_money=$h->{report};
($Traf1,$Traf2,$Traf3,$Traf4)=($h->{traf1},$h->{traf2},$h->{traf3},$h->{traf4});
$U{$Mid}{final_balance}=$U{$Mid}{balance}-$U{$Mid}{money};
@c=('',&Get_Name_Class($U{$Mid}{preset})); # вызывается из nomoney.pl - возвращает названия направлений от 1 до 8 для заданного пресета

# Загрузим описания плагинов
$plg_cfg="$Nodeny_dir_web/plugin_reestr.cfg";
open(F,"<$plg_cfg") or &Error($V? "$V $Lang_statpl_err_5_for_adm ".&bold(&Filtr_out($plg_cfg)) : $Lang_statpl_err_5_for_u);
@plg_list_cfg=<F>;
close(F);

%show_plg=();				# Какие плагины отображаем:
unshift @Plugins,'Smain';		# 'Главная' (будет первым), а также
$show_plg{$_}=1 foreach (@Plugins);     # указанные в настройках
$show_plg{Sother}=1;

$OUTLEFT='';				# Левая колонка клиентской статистики
$out1=$out2='';
$PlgSub='';
%Plg_Buttons=();
foreach $plg (@plg_list_cfg)
{
   next if $plg=~/^\s*#/ || $plg=~/^\s*$/; # комментарий либо пустая строка
   ($pCod,$pFile,$pSub,$pDescr,$pAdm,$pParams)=split /\t+/,$plg;
   next unless $show_plg{$pFile};	# плагин не в списке отображаемых
   next if $pAdm && !$Adm{id};		# доступен только администратору, а статистику смотрит клиент
   $Plg_Buttons{$pFile}=&ahref("$scrpt&a=$pCod",$pDescr) if $pDescr;

   $a==$pCod or next;
   # загрузим плагин
   $pFilePl="$Nodeny_dir_web/$pFile.pl";
   unless (-e $pFilePl)
   {
      $out1.="$V ".&Printf($Lang_statpl_err_no_plgn,$pFilePl) if $V;
      next;
   }
   $VER=0;
   require $pFilePl;
   if( $VER && $VER_chk!=$VER )
   {
      $out1.="$V ".&Printf($Lang_statpl_err_ver_plgn,$pFilePl) if $V;
      next;
   }
   $PlgSub=$pSub;
   $pParams=~s|\s||g;
   if( $pParams && $nAlias>1 )
   {  # меню алиасов
      @params=split /,/,$pParams;
      $url=$scrpt;
      map{ $url.="&$_=".int($F{$_}) } grep { defined $F{$_} } @params;
      foreach (sort {$U{$a}{ip} cmp $U{$b}{ip}} keys %U)
      {
         $out2.=&ahref("$url&id=$_",$U{$_}{ip})
      }
      $out2.=&ahref("$url&id=$Mid&alias=1",$Lang_statpl_show_for_all_ip);
      $out2=&Mess3('row2',$Lang_statpl_show_for_ip.$br.$out2);
   } 
}


$out1.=$Plg_Buttons{$_} foreach (@Plugins);
$OUTLEFT=&div('nav2 cntr',&Mess3('row2',$out1).$out2).$OUTLEFT;
$OUTLEFT.=&div('cntr',&Mess3('row2',$Stat_AddLines)) if $Stat_AddLines; # дополнительная информация, указанная в админке в настройках

$OUT.="<table class=width100 cellpadding=3 cellspacing=7><tr>";

# ====================
# Левая половина окна
# ====================
$OUT.="<td valign=top width=25%>$OUTLEFT</td>";

# ====================
# Правая половина окна
# ====================

$OUT.="<td valign=top>";
$EOUT='</td></tr></table>';

$Falias=int $F{alias};
if( $Falias && $nAlias>1 )
{  # статистика для всех ip
   $scrpt.='&alias=1';
   $Sel_id=join '',map{ "$_," } (keys %U);
   chop $Sel_id;
   $Sel_id||=$id;
   $For_U='';
}else
{
   $Falias=0;
   $Sel_id=$F{id} && $U{$F{id}}{ip}? $F{id} : $id;
   $For_U="$U{$Sel_id}{o_name} (ip $U{$Sel_id}{ip})";
}

&{ $PlgSub } if $PlgSub; # Выполним плагин
$OUT.=$EOUT;
&Exit;

# ==============================================================================

sub ReAuth
{# запрошена периодическая авторизация
 $mess=&the_time($t).': ';
 $mess.=$_[0]? $Lang_statpl_auth_but_blocked : $Lang_statpl_auth_for_inet;
 $dbh->do("INSERT INTO dblogin SET mid=$id,act=37,time=$ut");
 $OUT="Content-type: text/html\n\n".<<NODENY;
<html><head><title>$Html_title</title>
<meta http-equiv="refresh" content="$Time_User_ReAuth; url='$scrpt'">
<meta http-equiv='Content-Type' content='text/html; charset=windows-1251'>
<script>
var x=$Time_User_ReAuth;
function a()
{
  if (x>0) {
    document.getElementById('countdiv').innerHTML="$Lang_statpl_next_auth_will <b>"+x+"</b> $Lang_statpl_sec_str";
  } else if (x>-5) {
    document.getElementById('countdiv').innerHTML="";
  } else {
    document.getElementById('countdiv').innerHTML="$Lang_statpl_reload_for_auth";
    window.clearInterval(timer);
  }
  x-=1;
}
</script>
</head>
<body onload="javascript: timer=setInterval('a()',1000);"><br>
<div align=center>$mess</div><br>
<div align=center id=countdiv></div>
</body>
</html>
NODENY

 print $OUT;
 exit;
}

sub Error_X
{
 print "Content-type: text/html\n\n<html><head><meta http-equiv='Content-Type' content='text/html; charset=windows-1251'></head>".
   "<body><br><div align=center>".($V? $_[0]:$_[1])."</div></body></html>\n";
 exit;
}

sub Error_Y
{
 $Ashowsql=0;
 &Error($V? $_[0]:$_[1]||$_[0]);
}

sub LoginMess
{
 $Tabindex||=0;
 &OkMess(qq{<form method=get action='$script' onsubmit='pp.value=hex_md5(ses.value+" "+pp.value); return true'>}.
  "<input type=hidden name=ses value=$ses1>".
  &Table('tbg1',
    (!!$_[0] && &RRow('head','3',$_[0])).
    "<tr class=row2><$td width='33%'>$Lang_statpl_login_str:</td><td><input type=text name=uu size=25 value='' tabindex=".++$Tabindex."></td>".
    "<td rowspan=2 class=row2><input type=submit value=' $Lang_statpl_auth_button ' tabindex=".($Tabindex+2)."></td></tr>".
    "<tr class=row2><$td>$Lang_statpl_pass_str:</td><td><input type=password name=pp size=25 value='' tabindex=".++$Tabindex."></td></tr>"
  ).'</form>','',$_[1]);
 $Tabindex++; 
}

sub Login
{
 &LoginMess($Lang_statpl_login_msg,'keyb.gif');
}

sub Connect_DB2
{
 $dbs=DBI->connect($DSS,$user,$pw,{PrintError=>0});
 $dbs or &Error($V? $V.$br2."$Lang_statpl_err_db_connect $db_server2." : $Er_Mess_for_Client,$EOUT);
}

# Вход: категория платежа, текст
sub Insert_Event_In_DB
{
 return &sql_do($dbh,"INSERT INTO pays SET mid=$Mid,category=$_[0],reason='$_[1]',type=50,admin_ip=INET_ATON('$RealIp'),time=$ut");
}

# -- в этом месте будет дописана подпрограмма &get_main_config --
