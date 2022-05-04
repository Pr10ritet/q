#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use Time::HiRes qw( gettimeofday tv_interval );
use Time::localtime;
use DBI;

$Main_config='/usr/local/nodeny/nodeny.cfg.pl'; # дефолтовый путь к конфигу, переопределяется в &get_main_config()
eval{ &get_main_config() };		# название файла-конфига возьмем из подпрограммы, дописанной инсталлятором

$Session_live		= 300;		# секунд жизни сессии, если не будет активности
$Session_trusted_live	= 14400;	# секунд жизни сессии с доверенного PC, если не будет активности
$Max_byte_upload	= 40000;	# максимальное количество байт, которые мы можем принять по методу post

$script=$ENV{SCRIPT_NAME};
$script=~s/'/&#39;/g;			# апостроф нельзя в ссылках NoDeny

$VER_chk=$VER;
$VER=0;
$VER_script=$0;				# полное имя текущего скрипта

(-e $Main_config) or &Hard_exit(100);
eval{require $Main_config};
$@ && &Hard_exit(101);

$Html_title="$Title_net (ver $VER_chk)";

$Nodeny_dir_web="$Nodeny_dir/web";
$call_pl="$Nodeny_dir_web/calls.pl";
(-e $call_pl) or &Hard_exit(102);
eval{require $call_pl};
$@ && &Hard_exit(103);
$VER_chk==$VER or &Hard_exit(104);

&LoadMod("$Nodeny_dir_web/nSql.pl",'модуль nSql');

%F=('a'=>'');

$Debug='';

{
 if( $ENV{REQUEST_METHOD} ne 'POST' )
 {
    $QueryString=$ENV{QUERY_STRING};
    $Debug='Данные, переданые методом get:';
    last;
 }

 if( exists($ENV{CONTENT_TYPE}) && $ENV{CONTENT_TYPE}=~m|^\s*multipart/form-data|i )
 {  # multipart/form-data разгребем модулем cgi (тяжелый, поэтому его не юзаем в обычных случаях)
    # все скрипты, которые предусматривают работу с multipart/form-data должны будут сами получать
    # параметры из CGI, мы лишь передаем им ключевые данные: a,uu,pp,act
    use CGI;
    $cgi=new CGI;
    $F{a}=$cgi->param('a');
    $F{uu}=$cgi->param('uu');
    $F{pp}=$cgi->param('pp');
    $F{act}=$cgi->param('act');
    $F{set_new_admin}=$cgi->param('set_new_admin');
    $QueryString='';
    $Debug='Данные переданы как multipart/form-data';
    last;
 }

 $t=$ENV{CONTENT_LENGTH};
 $t>$Max_byte_upload && &Error("Превышение допустимой длины запроса: $t > $Max_byte_upload (байт)".$go_back);

 $Debug='Данные, переданые методом post:';  
 read(STDIN,$QueryString,$t)
} 

foreach $t (split(/&/,$QueryString))
{
   ($name,$value)=split(/=/,$t);
   $name=~tr/+/ /;
   $name=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $value=~tr/+/ /;
   $value=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $F{$name}=$value;
   $Debug.=&Printf('[br][filtr|bold] = [filtr]',$name,substr $value,0,200);
}

%Command_list=(
 'adduser'	=> 'Создание учетной записи абонента',
 'admin'	=> 'Управление учетными записями администраторов',
 'cards'	=> 'Управление карточками оплаты',
 'chanal'	=> 'Статистика и загрузка канала',
 'check'	=> 'Проверки',
 'deluser'	=> 'Удаление учетной записи абонента',
 'dopdata'	=> 'Дополнительные данные',
 'equip'	=> 'Оборудование',
 'job'		=> 'Работники',
 'listuser'	=> 'Список абонентов',
 'main'		=> 'Работа',
 'map'		=> 'Карты',
 'monitoring'	=> 'Мониторинг системы',
 'mytune'	=> 'Личные настройки',
 'operations'	=> 'Операции',
 'oper'		=> 'Операции администратора',
 'pays'		=> 'Осуществление платежей',
 'payshow'	=> 'Платежи, снятия, события',
 'report'	=> 'Отчет',
 'restart'	=> 'Управление/логи/рестарт',
 'setpaket'	=> 'Программирование смены тарифов',
 'superoper'	=> 'Операции суперадмина',
 'tarif'	=> 'Тарифные планы',
 'title'	=> 'Титульная страница',
 'tune'		=> 'Настройки',
 'user'		=> 'Данные клиента',
);

foreach (values %PluginsAdm) {$Command_list{$1}=$2 if /^(.+?)\-(.+)$/} # Добавим плагины

$Fa=$F{a};
$start=int $F{start};

%PR=();
%FormHash=();
$UU=$Display_admin='';
$Adm_pic="$img_dir/title_left.gif";
$Passwd_Key=&Filtr_mysql($Passwd_Key);
$AdminTrust=1; # пока считаем, что админ указал комп доверенным

if( $F{rand_login} )
{
   $t=int $F{rand_login};
   $F{uu}=$F{"uu$t"};
   undef $F{rand_login};
   undef $F{"uu$t"};
   undef $F{"pp$t"};
}

$t=time;
if( $F{uu} eq 'admin' && defined($sadmin) )
{ # попытка работы на системном (настроечном) логине при существующем системном логине
  $hash=Digest::MD5->new;
  $hash=$hash->add($F{salt}.' '.$sadmin);
  $hash=$hash->hexdigest;
  if( $hash eq $F{pp} )
  {
     $UU=$Display_admin=$F{uu};
     $Aname='Настройщик NoDeny';
     $PP=$hash;
     $Admin_id=0;
     $scrpt0="$script?salt=".&URLEncode($F{salt})."&uu=admin&pp=$hash";
     $scrpt="$scrpt0&a=$Fa";
     %FormHash=('salt'=>$F{salt},'pp'=>$hash,'uu'=>'admin');
     # дадим права на доступ к админке, просмотр и изменение настроек, привилегии админов, логи
     foreach (1,2,3,5,97) { $PR{$_}=1; ${"pr_$pr_def{$_}"}=1; }
     $pr_SuperAdmin=1;
  }
   elsif( $F{pp} eq 'error' )
  {
     &ErrorMess('Внимание! Вероятно, авторизация не прошла по причине того, что ваш браузер не загрузил '.
        'скрипт md5.js или в нем отключен javascript.');
  }
}

$DSN="DBI:mysql:database=$db_name;host=$db_server;mysql_connect_timeout=$db_conn_timeout";
$DSS="DBI:mysql:database=$db_name;host=$db_server2;mysql_connect_timeout=$db_conn_timeout2";
 
$dbh=DBI->connect($DSN,$user,$pw,{PrintError=>1});
if( !$dbh )
{
   $file='nErrConnect.pl';
   eval{require "$Nodeny_dir_web/$file"};
   &Error("Не найден модуль $file");
}

&SetCharSet($dbh);

($Fa eq 'login') && &Login;

$Ashowsql=1; # временно. Если авторизация не будет пройдена - все ок - в &Login() $DOC->{admin_area}='';

&sql_do($dbh,"DELETE FROM admin_session WHERE time_expire<unix_timestamp()",0); # Удалим устаревшие сессии запросов на авторизацию

{
 $UU && next;
 # Не системный логин
 $UU=&Filtr_mysql($ENV{REMOTE_USER});		# логин, переданный вебсервером
 $PP=&Filtr_mysql($F{pp});			# хеш пароля, или это id сессии

 $Fa=$PP='' if $Fa eq 'enter' && !$F{uu};	# админ возвращается к веб-авторизации 

 if( $Fa eq 'enter' )
 {  # Попытка авторизации средствами NoDeny
    $Fuu=&Filtr_mysql($F{uu});	# логин, переданный через форму
    &Login if !$Fuu || !$PP;	# логин был с запрещенными символами или не передан хеш - отправим логиниться
    $where="admin='$Fuu'";
 }
  elsif( $PP )
 {  # админ передал id сессии, есть такая сессия? act=2 - признак, что это именно сессия, а не запрос на авторизацию
    $p=&sql_select_line($dbh,"SELECT * FROM admin_session WHERE act=2 AND salt='$PP' AND system_id='$system_id' LIMIT 1",0);
    $p or &Login; # такой сессии нет - либо мухлеж либо ее время истекло и она была удалена либо смена браузера/ip

    if( substr($PP,0,1) eq 'T' )
    {  # администратор считает комп, с которого зашел, доверенным
       $Session_live=$Session_trusted_live;
    }else
    {
       $AdminTrust=0;
    }
    # продлим сессию
    &sql_do($dbh,"UPDATE admin_session SET time_expire=unix_timestamp()+$Session_live WHERE salt='$PP' AND system_id='$system_id' LIMIT 1",0);
    $Display_admin="$UU &rarr; " if $UU; # отобразим, что имя переопределено
    $where="id=$p->{admin_id}";
 }
  elsif( $UU )
 {  # авторизуется средствами вебсервера
    $where="admin='$UU'";
 }
  else
 {
    &Login; # для админки NoDeny отключена веб-авторизация (либо сбой) - авторизация только средствами NoDeny
 }
 $p_adm=&sql_select_line($dbh,"SELECT *,unix_timestamp(),AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE $where LIMIT 1",0,
    "SELECT *,unix_timestamp(),AES_DECRYPT(passwd,'...') FROM admin WHERE $where");
 unless ($p_adm)
 {  # нет такого админа
    &Login if $UU && !$PP; # если авторизовался вебсервером и не пытался авторизоваться через форму - просто предложим переавторизоваться
    &Error_Login;
 }

 $privil=$p_adm->{privil};
 $PR{$_}=1 foreach (split /,/,$privil);
 $pr_SuperAdmin=$PR{2} && $PR{3};

 $Ashowsql=$pr_SuperAdmin && $AdminTrust && $p_adm->{tunes}=~/,showsql,1/;
 $DOC->{admin_area}=$Ashowsql? &MessX($Debug).$DOC->{admin_area} : '';
 $Debug='';

 # Получим список отделов, не раньше, чтобы не было sql-запросов до проверок существования логина
 %Offices=();
 $sth=&sql($dbh,"SELECT * FROM offices",0);
 $Offices{$p->{of_id}}=$p->{of_name} while ($p=$sth->fetchrow_hashref); # фильтровать не надо

 $t=$p_adm->{'unix_timestamp()'};			# время на сервере основной БД
 $Admin_id=$p_adm->{id};				# id админа
 $UU=$p_adm->{admin};					# его логин
 $pp=$p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"};	# его пароль
 $Admin_office=$p_adm->{office};			# его отдел
 $Admin_UU="Адм. $UU (id=$Admin_id, ip=$ip).";

 if( $Fa eq 'enter' )
 {  # Попытка NoDeny-авторизации
    require "$Nodeny_dir_web/nLogin.pl";
    &Enter;
 }
  elsif( $Fa eq 'logout' )
 {
    &sql_do($dbh,"DELETE FROM admin_session WHERE act=2 AND admin_id=$Admin_id");
    &OkMess("Произведен выход из системы.");
    &Login;
 }
  elsif( !$PP && $pp ne '-' )
 {  # админ авторизовался вебсервером, при этом учетная запись требует авторизацию внутренними средствами
    &Login;
 } 

 require "$Nodeny_dir_web/nChngCom.pl" if $Fa eq 'sv'; # команда sv - предопределенная команда, необходимо преобразовать

 $scrpt0="$script?pp=$PP";
 $scrpt="$scrpt0&a=$Fa";
 $FormHash{pp}=$PP if $PP;
 $Display_admin.=$UU;

 if( ($PR{30}||$PR{31}) && $F{set_new_admin} )
 {  # переключение на логин другого администратора
    $Admin_id=int $F{set_new_admin};
    $Real_Admin_office=$Admin_office;
    $p_adm=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE id=$Admin_id",0,
       "SELECT *,AES_DECRYPT(passwd,'...') FROM admin WHERE id=$Admin_id");
    &Login unless $p_adm;
    $Admin_office=$p_adm->{office};
    !$PR{31} && $Admin_office!=$Real_Admin_office && &Error("Вам дано право переключаться только на администраторов своего отдела.");
    $UU=$p_adm->{admin};
    $Admin_UU.=" Переключился на админа $UU (id=$Admin_id).";
    $FormHash{set_new_admin}=$Admin_id;
    $scrpt.="&set_new_admin=$Admin_id";
    $scrpt0.="&set_new_admin=$Admin_id";
    $Display_admin.=" &rarr; $UU";
    $privil=$p_adm->{privil};
    %PR=(); # !
    $PR{$_}=1 foreach (split /,/,$privil);
    $pr_RealSuperAdmin=$pr_SuperAdmin;
    $pr_SuperAdmin=$PR{2} && $PR{3};
    $OUT.=&error('Внимание.','Вы переключились на администратора '.&bold($UU).(!!$Admin_office && ' отдела '.&bold($Offices{$Admin_office}))); 
 }

 $Aname=$p_adm->{name};				# имя админа
 $Aext=$p_adm->{ext};				# расширение у аватара админа
 $Admin_regions=','.$p_adm->{regions}.',';	# приоритетные географические районы
 $Atemp_block_grp=$p_adm->{temp_block_grp};	# админ выставил себе временное ограничение в виде отказа от работы с данными номерами групп клиентов
 %Atunes=split ',',$p_adm->{tunes};		# личные настройки
 $Adm_pic="$Adm_img_dir/Adm_$Admin_id.$Aext" if $Aext;
}

${"pr_$pr_def{$_}"}=$PR{$_} foreach %pr_def;	# текстовые представления привилегий

$tt=localtime($t);
$day_now=$tt->mday;
$mon_now=$tt->mon+1;
$year_now=$tt->year;
$time_now=&the_time($t);

# === Титул ===

{
 $F{notitle} && last;

 $h=!!$Admin_id;
 $h=&Table('table2 title2',
     &RRow('navtitle','llllllcllll',
       &ahref("$scrpt0&a=title",'&sect;'),
       $h && &ahref("$scrpt0&a=listuser",'Клиенты'),
       &ahref("$scrpt0&a=main",'Операции'),
       $h && $pr_pays && &ahref("$scrpt0&a=payshow&nodeny=admin&year=$year_now&mon=$mon_now&admin=$Admin_id",'Платежи'),
       $h && &ahref("$scrpt0&a=chanal&class=1",'Статистика'),
       $h && $pr_edt_main_tunes && &ahref("$scrpt0&a=restart",'Управление'),
       $h && &form('#'=>1,'a'=>'sv',
         &Table('table1',&RRow('row2','ll',
            &input_t('name','',12,60,qq{style='width:16px' id='txtTopFind' onClick='document.getElementById("txtTopFind").style.width="80px"; document.getElementById("divTopFind").style.display="";'}),
            &tag('div',&submit('Найти'),"id='divTopFind' style='display:none'")
         ))
       ),
       &ahref("$script?a=login",'Авторизация'),
       &ahref("$scrpt0&a=logout",'Выход'),
       !!$Ashowsql && &ahref('javascript:show_x("adm")','Debug&darr;'),
     )
 );

 $out=&Table('table0 title2',
   &tag('tr',
     &tag('td','&nbsp;','class=title1l width=8').
     &tag('td',  &tag('span','NoDeny - '.($Command_list{$Fa}||'Hello'),'class=title3'),"class='title1 cntr'").
     &tag('td','&nbsp;','class=title1r width=8'),
   'height=23').
   &RRow('',' l ','',$h,'').
   &RRow('title4','3',"<img height=5 src='$spc_pic'>")
 );

 $OUT.=&Table('width100',
   &tag('tr',
      &tag('td',&ahref("$scrpt0&a=mytune","<img src='$Adm_pic'>")).
      &tag('td','&nbsp;',"width='16%'").
      &tag('td',$out,"align=center valign=top").
      &tag('td','&nbsp;',"width='16%'").
      &tag('td','Адм:'.$br.$Display_admin)
   ).
   &tag('tr',&tag('td',"<img height=10 src='$spc_pic'>","colspan=5 class=row2"))
 );
}
$out='';

$pr_on or &Error(&Printf('Доступ в админку для логина [bold] заблокирован.',$UU));

# к каким группам разрешен доступ
$Allow_grp=$Allow_grp_less='';
%UGrp_name=%UGrp=%UGrp_allow=%UGrp_allow_less=();
$sth=&sql($dbh,"SELECT * FROM user_grp",0);
while ($p=$sth->fetchrow_hashref)
{
   $h=$p->{grp_id};
   if( $p->{grp_admins}=~/,$Admin_id,/ )
   {  # админ имеет доступ к группе
      $Allow_grp.="$h,";
      $UGrp_allow{$h}=1;
      if( $Atemp_block_grp!~/,$h,/ )
      {  # он не ограничил себя в доступе к этой группе
         $Allow_grp_less.="$h,";
         $UGrp_allow_less{$h}=1;
      } 
   }
   if( $p->{grp_admins2}=~/,$Admin_id,/ )
   {
      $UGrp_allow{$h}++;
      $UGrp_allow_less{$h}++ if $Atemp_block_grp!~/,$h,/;
   }
   $UGrp{$h}=$p->{grp_property};
   $UGrp_name{$h}=&Filtr($p->{grp_name});
}

$Allow_grp.='0';	# доступ к нулевой группе имеют все, кроме того завершает запятую
$UGrp_allow{0}=2;	# тоже в другом виде
$Allow_grp_less.='0';
$UGrp_allow_less{0}=2;
$UGrp_name{0}='без группы';

&DEBUG("<small>Время выполнения adm.pl: $T_sql сек</small>".$br);
if( $VER_cfg!=$VER_chk )
{
   $pr_SuperAdmin or &Error('Административный интерфейс отключен по техническим причинам. Обратитесь к главному администратору.');
   $Fa='tune';
}
 elsif( !$Fa or !$Command_list{$Fa} )
{
   $F{a}=$Fa='title';
}

# Не настроено отображение колонок в списке клиентов? Отметим по дефолту
if( !join '',grep{ /^cols-/ } keys %Atunes )
{
  foreach $_ qw(
    0-2 0-3 0-4 0-8 0-9 0-10 0-11 0-12 0-13 0-14 0-16 0-21 0-50 0-51 0-52 0-53 0-54
    1-1 1-2 1-3 1-5 1-6 1-8 1-14 1-15 1-16 1-17 1-18 1-22 1-50 1-51 1-52 1-53 1-54
    2-1 2-2 2-3 2-4 2-9 2-14 2-16 2-17 2-18 2-19 2-20 2-21 2-22
  )
  {
    $Atunes{"cols-$_"}=1;
  }
}

$FormHash{a}=$Fa;
$Apay_sql="admin_id=$Admin_id,admin_ip=INET_ATON('$ip'),office=$Admin_office";

$fileFa="$Nodeny_dir_web/$Fa.pl";
(-e $fileFa) or &Error($pr_SuperAdmin? "Модуль $fileFa не найден!" : 'Модуль не найден. Обратитесь к главному администратору.');
require $fileFa;
&Exit;


sub Login
{
 eval{require "$Nodeny_dir_web/nLogin.pl"};
 $@ && &Error("Не могу загрузить модуль авторизации nLogin.pl.");
 &Login_now;
}

sub Error_Login
{
 &Message(&div('big','Неверный логин или пароль'),$err_pic,'Ошибка','','infomess');
 &Login;
}

sub Hard_exit
{
 print "Content-type: text/html\n\n<html><body><br><div align=center>ВНИМАНИЕ! Ошибка $_[0]. Обратитесь к главному администратору.</div></body></html>\n";
 exit;
}

# -- в этом месте будет дописана подпрограмма &get_main_config --
