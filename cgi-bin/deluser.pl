#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_del_usr or &Error('Вам не разрешено удалять учетные записи клиентов.');
$AdminTrust or &Error('Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.');

$OUT.=&Mess3('row2',&div('cntr',&bold_br('Удаление учетной записи клиента из базы данных.').
  &ahref("$scrpt0&a=operations&act=help&theme=deluser",'Справка'))).$br;

$F{act} or &Error('Действие не задано.');
$Fid=int $F{id};

($userinfo,$grp,$mId,$ipp)=&ShowUserInfo($Fid);
unless ($mId)
  {
   $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='users' AND act=2 AND fid=$Fid",'удален ли уже клиент');
   $p && &Error(&the_short_time($p->{time},$t,1)." учетная запись клиента № $Fid была удалена.".$br2.&CenterA("$scrpt0&a=listuser",'Далее &rarr;'));
   &Error("Учетная запись клиента № $Fid не найдена в базе данных.$go_back");
  }

&Error('Нет прав на удаление записи в текущей группе.') if $UGrp_allow{$grp}<2;

$h=&sql_select_line($dbh,"SELECT * FROM users WHERE mid=$Fid LIMIT 1",'Есть ли алиасы?');
$h && &Error('Запись имеет '.&ahref("$scrpt0&a=user&id=".$h->{id},'алиасы').'. Удалите сначала их.');

$out2='';
if ($mId==$Fid)
  {# Основная запись
   $out3='';
   $sth=&sql($dbh,"SELECT * FROM cards WHERE alive=$Fid",'Числятся ли на клиенте активированные карточки пополнения счета?');
   while ($h=$sth->fetchrow_hashref)
     {# +0 чтобы убрать дробную часть, если она нулевая
      $out3.=&RRow('*','ll',$h->{money}+0,&the_short_time($h->{atime},$t));
     }
   $out2.=&Table('tbg3',&RRow('head','C','Клиент активировал следующие карточки пополнения счета').
      &RRow('head','cc','Сумма','Время активации').$out3.
      &RRow('head','C','После удаления карточки будут переведены в состояние '.&commas('заблокированы'))
   ).$br if $out3;
   # Внимание, не надо пытаться определить нулевую сумму по платежам - у нас разные админы
   $h=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE type=10 AND bonus='' AND mid=$Fid",'Есть ли платежи на учетной записи?'); 
   !$h && &Error("Ошибка получения платежей клиента. Запись не удалена");
   $out2.=&div('error',"Наличных платежей: $h->{n} шт",1) if $h->{n};
  }
   else
  {
   $count_pays=0;
  }  
   
if ($F{act} ne 'iamshure')
  {# предупреждение
   $OUT.=&div('message',
      &form('!'=>1,'id'=>$Fid,'act'=>'iamshure',
        &Table('',&RRow('','tt',$userinfo,$out2).&RRow('','C',$br2."Введите здесь слово 'ok': ".&input_t('ok','',3,3," autocomplete='off'").$br2.&submit_a('Удалить запись')))
      )
   );
   &Exit;
  }

# =======================
# Непосредственно удаляем
lc($F{ok}) ne 'ok' && &Error("Вы не ввели кодовое слово подтверждающее ваши намерения.$go_back");

$h='Удалена '.($mId!=$Fid && 'алиасная')." запись ip: $ipp, id: $Fid.";
$p=&sql_select_line($dbh,"SELECT * FROM pays WHERE type=50 AND category=411 AND mid=$Fid",'Когда была создана запись?');
$h.=' Была создана '.&the_time($p->{time}).(!!$p->{admin_id} && ' администратором id='.$p->{admin_id}) if $p;

$mid=$mId!=$Fid? $mId : 0; # если удаляется алиасная запись, то платеж относится к основной, иначе к "затратам сети"

$sql="INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,coment,time) ".
     "VALUES($mid,0,50,420,$Admin_id,INET_ATON('$ip'),$Admin_office,'$h','',$ut)";
$sth=$dbh->prepare($sql);
$sth->execute;
$id=$sth->{mysql_insertid} || $sth->{insertid};

!$id && &Error("Запись не удалена из БД. Ошибка sql.$go_back");

&sql_do($dbh,"DELETE FROM users_trf WHERE uid=$Fid LIMIT 1");

if ($mId!=$Fid)
  {# алиас
   &sql_do($dbh,"DELETE FROM pays WHERE mid=$Fid",'Удаляем все события связанные с алиасом');
   $rows=&sql_do($dbh,"DELETE FROM users WHERE id=$Fid LIMIT 1");
   $rows<1 && &Error("Алиасная запись не удалена из БД. Ошибка sql.$go_back");
   &sql_do($dbh,"INSERT INTO changes SET tbl='users',act=2,time=$ut,fid=$Fid,adm=$Admin_id");
   &OkMess("Алиасная запись удалена из БД.".$br2.&CenterA("$scrpt0&a=user&id=$mId",'Данные основной записи'));
   &ToLog("!! $Admin_UU Удалена алиасная запись id=$Fid ($ipp), id основной записи $mId");
   &Exit;
  }

&sql_do($dbh,"DELETE FROM pays WHERE mid=$Fid AND (cash=0 OR bonus<>'')",'Удаляем все неналичные платежи и события');
&sql_do($dbh,"UPDATE pays SET mid=0,reason=CONCAT('~(Запись удаленного клиента ip: $ipp, id: $Fid~)\n',reason) WHERE mid=$Fid");

$rows=&sql_do($dbh,"DELETE FROM users WHERE id=$Fid LIMIT 1");
$rows<1 && &Error("Учетная запись клиента не удалена из БД. Ошибка sql.$go_back");

&ToLog("!! $Admin_UU Удален клиент id=$Fid ($ipp)");

&sql_do($dbh,"INSERT INTO changes SET tbl='users',act=2,time=$ut,fid=$Fid,adm=$Admin_id","В таблице изменений зафиксируем, что клиент id=$Fid удален");

&OkMess("Учетная запись клиента удалена из БД.".$br2.&CenterA("$scrpt0&a=",'На титульную страницу &rarr;'));
$DOC->{header}.=qq{<meta http-equiv="refresh" content="15; url='$scrpt0&a='">};

1;
