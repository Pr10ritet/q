#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$TimeNoSave=360;	# время в секундах по истечении которого кнопка `сохранить` исчезнет
$TimeNoSave2=520;	# то же, но если пользователь пытался что-то менять

&LoadMoneyMod;

$Fid=int ($F{id} || $F{mid});
$Fact=$F{act};
$CanSave=$pr_edt_usr;

$ret=$br2.&CenterA("$scrpt&id=$Fid",'Вернуться на страницу данных клиента').$br;

# Список привилегий только на изменение полей
@SavePrivil=(71,72,73,74,75,76,77,78,79,80,81,82,84,85,86,87,90);

$sql="SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM users WHERE id=$Fid";

$p=&sql_select_line($dbh,$sql,'Данные клиента',"скрыт: select from users WHERE id=$Fid");
$p or &Error("Ошибка получения данных клиента с id=$Fid.");

${"real_$_"}=$p->{$_} foreach qw( 
 balance
 block_if_limit
 comment
 contract
 contract_date
 cstate
 detail_traf
 discount
 fio
 grp
 hops
 ip
 limit_balance
 lstate
 mid
 name
 next_paket
 next_paket3
 paket
 paket3
 sortip
 srvs
 start_day
 state
);

$mid=$real_mid;
$client=&Filtr_out(($real_fio||'без имени')." (ip: $real_ip, логин: $real_name)");
$show_client="<span class=row2>$client</span>";

{
 $real_mail_enable=$mail_enable;
 $mail_enable=0;
 last if !($real_mail_enable && $pr_mail);
 $dbh2=DBI->connect("DBI:mysql:database=$mail_db;host=$mail_host;mysql_connect_timeout=1",$mail_user,$mail_pass);
 if ($dbh2)
   {
    &SetCharSet($dbh2);
    $mail_enable=1;
   }else
   {
    $OUT.=&MessX("Не удалось соедениться с mail сервером, обработка почтовых ящиков клиентов в данный момент не работает. Возможные причины: ".
      "недоступен почтовый сервер, блокировка соединений фаерволом, неправильный логин или пароль соединения с почтовой базой данных.",'','Внимание');
   }
}

sub stop_mess
{
 &Message($_[0],'',$_[1]||'Внимание');
 $stop++;
}

sub check_ip
{
 $test_ip=$try_set_ip? $F{ip} : $real_ip;
 if ($test_ip!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ || $1>255 || $2>255 || $3>255 || $4>255)
   {
    &stop_mess($try_set_ip? 'Новый ip адрес неверен. Ip не изменен':'Текущий ip-адрес неверен. Необходимо исправить его, после чего будет разрешено изменять группу.');
    $change_fields{grp}=0;
    return;
   }

 $sortip=$2*65536 + $3*256 + $4;

 if ($Mgrp)
   {# проверим допустим ли данный ip в группе клиента
    $h=&sql_select_line($dbh,"SELECT * FROM user_grp WHERE grp_id=$Mgrp",'Данные группы клиента');
    unless ($h)
      {
       &stop_mess(($try_set_ip? 'Ip-адрес не может быть изменен' : 'Группа не может быть изменена').' т.к. не удалось получить данные группы клиента. Возможно это временная проблема, '.
          'повторите запрос позже. Если проблема повторяется - обратитесь к главному администратору, возможно текущая группа клиента не описана в списке групп.');
       $change_fields{grp}=0;
       return;
      }
    $grp_nets=$h->{grp_nets};
    if ($grp_nets)
      {# есть список ip, которые разрешены для данной группы
       @nets=split /\n/,$grp_nets;
       &LoadNetMod;
       $allow_ips='';
       foreach $net (@nets)
         {
          ($h)=&nNet_GetNextIp($net);
          $allow_ips.=qq{<span onClick='window.clipboardData.setData("Text","$h")' class=data2 style='cursor:pointer;border:0;'>$h</span><br>} if $h;
         }
       $allow_ips=". Вы можете установить один из следующих ip (щелчек по ip копирует в буфер обмена):<br><br>$allow_ips" if $allow_ips;
       unless (&Check_Ip_in_Nets($test_ip,@nets))
         {
          $grp_nets=~s/\n/<br>/g;
          &stop_mess('Ip '.&bold($test_ip)." не попадает в список разрешенных подсетей для группы ".&commas($UGrp_name{$Mgrp}).
             ':'.$br2.$grp_nets.$br2.($try_set_ip? 'Ip не изменен' : 'Группа не изменена').$allow_ips);
          $change_fields{grp}=0;
          return;
         } 
      } 
   }   

 return if !$try_set_ip;

 # Проверим есть ли в базе клиент с целевым ip
 $h=&sql_select_line($dbh,"SELECT id FROM users WHERE ip='$test_ip' AND id<>$Fid LIMIT 1","Есть ли в БД клиент с $test_ip");
 if ($h)
   {
    &stop_mess("Новый ip адрес принадлежит ".&ahref("$scrpt&id=".$h->{id},'другому клиенту').'. Ip не изменен');
    return;
   }

 $X.="IP: $real_ip -> $test_ip\n";
 $sql_set.=",ip='$test_ip'";
 $sql_set.=",sortip=$sortip" if !$Edit_sortip;
 $change_fields{ip}=1;
 &stop_mess("Во время редактирования данных клиента, параллельно с вами другой администратор изменил его ip. Смотрите логи событий") if $F{old_ip} ne $real_ip;
}

# ===================================
#	Сохранение изменений
# ===================================

if ($Fact eq 'save')
{
 $OUT.=$br;
 $WannaSave=int $F{wannasave};
 if ($WannaSave)
   {
    $CanSave=0; # !
    $PR{$_}=1 foreach @SavePrivil;
    ${"pr_$pr_def{$_}"}=$PR{$_} foreach %pr_def;
   }
    elsif (!$CanSave)
   {
    &Error('Нет прав на изменение данных клиентов.')
   }

 $X='';			# какие поля изменяет админ
 $sql_set='';		# sql с подлежащими изменению полями
 %change_fields=();	# массив полей, которые будут модифицироваться
 $stop=0;		# зафиксировать ли на экране страницу с результатом

 # Далее везде проверяем определенность параметров т.к возможна ситуация когда на момент отображения параметров
 # у админа не было прав на их изменение, а в момент посылки они были даны

 if ($mid)
   {# Алиасная запись. Получим группу основной записи, это перестраховка т.к. группа хранится и в алиасной записи
    $Mid=$mid;
    $h=&sql_select_line($dbh,"SELECT grp FROM users WHERE id=$mid LIMIT 1",'Запись алиасная. Получим группу основной записи');
    $Mgrp=$h? $h->{grp} : $real_grp;
    &stop_mess("Запись клиента $show_client алиасная и указывает на отсутствующую основную (id основной: $Mid)!") unless $h;
   }
    else
   {# Основная запись
    $Mgrp=$real_grp;
    $Mid=$Fid;
    if ($PR{73} && defined($F{grp}) && $F{grp}!=$F{old_grp})
      {# заказал смену группы и имеет на это право
       $grp=int $F{grp};
       if ($UGrp_allow{$grp}<2)
         {
          &stop_mess('Вам не разрешено переводить клиента '.($UGrp_allow{$grp}? ' в группу '.&commas($UGrp_name{$grp}):' в заказанную группу').'. Группа не изменена','Предупреждение');
         }else
         {# пока не добавляем в sql т.к. позже будет проверка разрешен ли ip в новой группе
          $Mgrp=$grp;
          $change_fields{grp}=1;
         }
      }
   }

 # В первую очередь проверим группу клиента чтобы не выводить неразрешенному админу сообщения об ошибках с упоминанием данных клиента.
 # Суперадмин сможет менять запись в запрещенной группе т.к. она может быть несуществующей
 $UGrp_allow{$Mgrp}<2 && !$pr_SuperAdmin && &Error('Клиент в группе, в которой вы не можете вносить изменения.');

 $F{old_ip} ne $F{ip} && !$F{setip} && $PR{71} && &stop_mess('Вы изменили поле `ip-адрес`, но не поставили рядом галочку. Ip-адрес не изменен.');

 $try_set_ip=$F{setip} && $PR{71} && $F{old_ip} ne $F{ip};
 # Если меняется группа или ip, проверим разрешен ли ip в этой группе
 &check_ip if $try_set_ip || $change_fields{grp};

 if ($change_fields{grp})
   {# проверяем сейчас т.к. $change_fields{grp} мог быть сброшен в &check_ip
    $sql_set.=",grp=$grp";
    if ($real_grp!=$grp)
      {
       $g1=$UGrp_name{$real_grp} || 'Без группы';
       $g2=$UGrp_name{$grp} || 'Без группы';
       $X.="Группа: $g1 -> $g2\n";
      }
   }

 {# === Логин ===
  last if !defined($F{name}) || !$PR{72} || $F{name} eq $F{old_name};
  $name=&trim($F{name});
  $name ne $F{name} && &stop_mess('Убраны пробелы в начале и конце логина.');
  $Block_space_login && $name=~s|\s||g && &stop_mess('Убраны пробелы в логине.');
  if ($Block_rus_lat && $name=~/[а-яА-Я]/ && $name=~/[a-zA-Z]/)
    {
     &stop_mess('Логин не изменен - смешение латинских и кириллических букв не разрешено.');
     last;
    }
  $nofiltr_name=$name;
  $name=&Filtr_mysql($name);
  unless ($name)
    {# логин 0 тоже не разрешаем
     &stop_mess('Логин не может быть пустым или равным 0! Логин не изменен.');
     last;
    }
  # проверим, что клиента с таким логином нет в БД (кроме того, данные которого изменяем)
  # кстати маловероятная ситуация параллельной установки одного логина разным клиентам не критична и может быть разрулена потом
  $h=&sql_select_line($dbh,"SELECT id FROM users WHERE name='$name' AND id<>$Fid",'Меняется логин, проверим, что нет клиента с таким же логином');
  if ($h)
    {
     &stop_mess('Логин '.&bold($name).' уже принадлежит '.&ahref("$scrpt&id=".$h->{id},'другому клиенту').'. Логин не изменен.');
     last;
    }
  $sql_set.=",name='$name'";
  $X.="Логин: $real_name -> $nofiltr_name\n" if $real_name ne $nofiltr_name;
  $change_fields{name}=1;
 }


 $F{block_if_limit}||='' if defined($F{limit_balance}); # сделаем определенным параметр т.к. в checkbox если нет галки, то неопределен. Привилегии потом
 $F{detail_traf}||=0 if $PR{85}; # сделаем определенной переменную

 # Виртуальные привилегии
 $PR{9999}=$Edit_sortip && $PR{71}; 
 $_=int $F{paket3};
 $PR{9998}=defined($F{paket3}) && $PR{76} && ($Plans3{$_}{usr_grp}=~/,$Mgrp,/ || !$_);
 $_=int $F{next_paket3};
 $PR{9997}=defined($F{next_paket3}) && $PR{76} && ($Plans3{$_}{usr_grp}=~/,$Mgrp,/ || !$_);

 # Тип поля:
 # 0 - строковое
 # 1 - целое
 # 2 - вещественное
 # 3 - 'галка'
 # X - целое, при этом если > 5, то X указывает на максимальное значение.
 # Поле		 | Привилегия | Тип |   Имя поля
 @fields=(
  ['contract',		74,	0,	'Контракт',			1,	'не указан'],
  ['fio',		75,	0,	'ФИО',				1,	'не указаны'],
  ['start_day',		81,	31,	'День начала потребления',	0,	'0'],
  ['discount',		69,	100,	'% скидки',			0,	'0'],
  ['comment',		86,	0,	'Комментарий',			0,	''],
  ['limit_balance',	78,	2,	'Лимит отключения',		0,	'0'],
  ['hops',		84,	1,	'Точка подключения',		0,	'не указана'],
  ['block_if_limit',	78,	3,	'Откл. при превышении лимита',	0,	'да','1','нет','0'],
  ['state',		77,	3,	'Включен ли доступ',		0,	'да','on','нет','off'],
  ['cstate',		79,	1,	'Состояние',			0,	'неизвестный код состояния',\%cstates],
  ['lstate',		80,	3,	'Нужна авторизация',		0,	'да','0','нет','1'],
  ['detail_traf',	85,	1,	'Детализация трафика',		0,	'отключена'],
  ['sortip',		9999,	1,	'Приоритет записи',		0,	'0'],
  ['paket3',		9998,	1,	'Дополнительный пакет',		0,	'0'],
  ['next_paket3',	9997,	1,	'Следующий доп. пакет',		0,	'0'],
 );

 foreach $f (@fields)
  {
   ($f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8)=@{$f};
   $fd=$F{$f0};				# переданный через форму параметр
   next if !defined($fd) || !$PR{$f1};	# параметр не передавался или нет прав на его изменение

   $fr=${"real_$f0"};			# текущее значение параметра в базе
   $fo=$F{"old_$f0"};			# значение параметра на момент отображения админу
   $fname=&commas($f3);			# название параметра

   $fdx=$frx='';

   if (!$f2)
     {# строковое поле
      $fd=~s/\s+$//;
      $fd=~s/^\s+//;
      $fd=~s/\r//g;			# надо для сравнения с текущим в базе т.к. там \r\n хранится как \n
      $fo=~s/\r//g;
      if ($Block_rus_lat && $f4 && $fd=~/[а-яА-Я]/ && $fd=~/[a-zA-Z]/)
        {
         &stop_mess("В параметре $fname не разрешено смешение латинских и кириллических букв. Параметр не изменен.");
         next;
        }
      $fset=&Filtr_mysql($fd);
     }
      elsif ($f2==2)
     {# вещественное поле
      $fset=$fd=$fd+0;
      $fr+=0;				# надо - далее будут сравниваться как строки
      $fo+=0;				# тоже
     }
      elsif ($f2==3)
     {
      if ($fd eq $f6)
        {
         $fset=$f6;
         $fdx=$f5;
        }else
        {
         $fset=$fd=$f8;
         $fdx=$f7;
        }
      $frx=$fr eq $f6? $f5 : $f7;
     }
      else
     {# целое числовое поле
      $fset=$fd=int $fd;
      if ($f2>5 && ($fd<-1 || $fd>$f2))
        {
         &stop_mess("Параметр <b>$f3</b> не изменен т.к. должен быть в пределах 0..$f2 или равен -1.");
         next;
        }
     }

   $fdx||=$fd;				# что записывать в лог когда параметр меняется, по умолчанию значения параметра
   $frx||=$fr;				# то же для значения в базе

   # если параметр для отображения клиенту надо представить как значение массива
   if ($f2!=3 && defined($f6))
     {
      $frx=$f6->{$frx} || $f5;
      $fdx=$f6->{$fdx} || $f5;
     }

   if ($fd ne $fr)
     {# устанавливаемое значение не равно значению в базе
      if ($fo eq $fd)
        {# админ не менял параметр, но параллельно кто-то изменил
         $OUT.=&div('message',"Обратите внимание. Во время редактирования данных клиента, другой администратор (система) изменил параметр <b>$f3</b>, вы не меняли этот параметр. Это информативное сообщение");
         $stop++;
         next;
        }
      if ($fo ne $fr)
        {# Было осуществлено параллельное редактирование (!)
         &stop_mess("Во время редактирования данных клиента, параллельно с вами другой администратор (система) изменил параметр <b>$f3</b>. В событиях узнайте кто это сделал и разрулите эту ситуацию");
        }
      $X.="$f3: ".($frx || $f5).' -> '.($fdx || $f5)."\n";
      $change_fields{$f0}=1;
     }
      elsif ($fo ne $fr)
     {# в этой точке админ изменил параметр в значение, которое до него установил другой админ
      &stop_mess("Вы установили параметр <b>$f3</b> в тоже значение, в которое в момент вашего редактирования установил другой администратор (система). Это информативное сообщение",'Обратите внимание');
      next
     }
      else
     {# текущее в базе = устанавливаемому = до этого отображенное админу  - значит этот параметр не меняем
      next
     }
   $sql_set.=",$f0='$fset'";
  }

 if ($change_fields{cstate})
   {
    $sql_set.=",cstate_time=unix_timestamp()";
   } 
    elsif($real_cstate==7 && $change_fields{comment} && $F{comment}=~/^\s*$/)
   {# Если состояние "читай комменты" мы не меняли, но удалили коммент (буквально: меняли и он стал пустым), тогда переведем состояние в режим 'Все ок'
    &stop_mess("В данных клиента указано наличие комментария, однако комментарий пустой. Состояние 'Читай комментарии' изменено на 'Все ОК'",'Обратите внимание');
    $sql_set.=",cstate=0";
    $X.="Состояние: 'Все ок' (переключено автоматически системой)\n";
   }

 $contract_date=$F{contract_date};
 $contract_date=~s|\s+||g;
 $contract_date||=0; # пустую строку преобразуем в 0 - необходимо для сравнения
 if (defined($F{contract_date}) && $PR{74} && $F{contract_date} ne $F{old_contract_date})
   {
    if (!$contract_date)
      {
       $X.="Удалена дата заключения контракта\n";
       $sql_set.=",contract_date=0";
      }
       elsif ($contract_date=~/^(\d+)\.(\d+)\.(\d+)$/ && eval{$h=timelocal(0,0,0,$1,$2-1,$3+100)})
      {
       if ($real_contract_date!=$h)
         {
          $X.="Дата заключения контракта: $contract_date\n";
          $sql_set.=",contract_date=$h";
         } 
      }
       else
      {
       &stop_mess("Неправильно указана дата заключения контракта, ожидается в виде <b>дд.мм.гггг</b>. Дата не изменена.");
      }
   }



 {
  last if $mid;
  $h=int $F{paket};
  if( defined($F{paket}) && $PR{76} && $h!=$F{old_paket} && $h!=$real_paket )
  {
     if( $Plan_allow_show[$h] )
     {
        $X.="Пакет: ".($Plan_name_short[$real_paket]? "'$Plan_name_short[$real_paket]'" : 'неизвестный пакет' ).' -> '.
            ($Plan_name_short[$h]? "'$Plan_name_short[$h]'" : 'неизвестный пакет' )."\n";
        $sql_set.=",paket=$h";
        $new_paket=$h;
        $change_fields{paket}=1;
        $Plan_flags[$h]=~/k/ && !$change_fields{state} && $real_state ne 'off' &&
             &stop_mess('Пакет тарификации указывает заблокировать доступ клиенту. Не забудьте сделать это.');
     }
      else
     {
        &stop_mess("Пакет тарификации не изменен т.к вы заказали пакет, к которому у вас нет доступа");
     } 
  }

  $h=int $F{next_paket};
  if( defined($F{next_paket}) && $PR{76} && $h!=$F{old_next_paket} && $h!=$real_next_paket )
  {
     $X.='Будущий пакет'.($Plan_name_short[$h]? ": $Plan_name_short[$h]" : $h? '' : ': не менять пакет' )."\n";
     $sql_set.=",next_paket=$h";
  }

  if( defined($F{balance}) && $PR{87} && $F{balance}!=$F{old_balance} )
  {
     $balance=$F{balance};
     if( $F{changeb} )
     {  # изменить состояние счета
        if( $balance!~/^-?\d+(\.\d)?\d*$/ )
        {
           &stop_mess('Ошибочно введены наличные в балансе клиента! Баланс не изменен.');
        }else
        {
           $sql_set.=",balance=$balance";
           $X.="Баланс: $real_balance -> $balance\n"; # без проверки  $real_balance != $balance
           &stop_mess("Вы изменили баланс клиента. Это действие не рекомендовано т.к будут нестыковки при просмотре статистики клиентом - не будет сходится сумма по всем платежам. Вместо изменения баланса рекомендуется редактировать платежи, это корректно",'Предупреждение');
        }
     }else
     {
        &stop_mess('Вы изменили поле `Счет клиента`, но не поставили галочку подтверждающую это действие.<br>Состояние счета изменено не будет','Предупреждение');
     }
  }

  # $F{changesrvs} - признак, что в момент отображения инфы админ мог править услуги, т.е. они пересланы через форму (проверка на определенность не катит - checkbox)
  if( defined($F{changesrvs}) && $PR{76} )
  {
     $srvs=0;
     $what_cnange='';
 
     for( $i=31;$i>0;$i-- )
     {
        $srvs<<=1;
        next unless $srv_n[$i]; # услуга не задана
        $f1=$F{"sr$i"}? 1:0;
        $f2=$F{"old_sr$i"}? 1:0;
        $srvs++ if $f1;
        $what_cnange.=" $srv_n[$i]: ".($f1? 'активировано' : 'деактивировано')."\n" if $f1!=$f2;
     }
     $X.=$what_cnange? "Услуги:\n$what_cnange" : '';
     $sql_set.=",srvs=$srvs" if $real_srvs!=$srvs;
  }
  # конец параметров, которые могут быть только у основной записи
 }

 if( $F{pass} && $PR{90} && $Passwd_Key )
 {
    $pass=$F{pass};
    $pass=~s|\s+$|| && &stop_mess("В конце пароля стоял пробел(ы), он убран(ы)",'Предупреждение');
    length($pass)<4 && &stop_mess("Ненадежный пароль - длина менее 4х символов",'Предупреждение');
    $X.="Пароль\n" if $p->{"AES_DECRYPT(passwd,'$Passwd_Key')"} ne $pass;
    $pass=&Filtr_mysql($pass);
    $sql_set.=",passwd=AES_ENCRYPT('$pass','$Passwd_Key')";
    $change_fields{pass}=1;
 }

 !$sql_set && !$mail_enable && &Error("Никакие данные учетной записи вами не менялись. Изменения не внесены".$ret);

 if( !$sql_set )
 {
    $rez_mess='Никакие данные учетной записи вами не менялись.';
    $stop++;
 }
  elsif( $CanSave )
 {
    $sql="UPDATE users SET modify_time=$ut $sql_set WHERE id=$Fid LIMIT 1";
    if( $Ashowsql && $change_fields{pass} )
    {
       $rows=$dbh->do($sql);
       $DOC->{admin_area}.=&MessX('Скрытый UPDATE sql-запрос (скрываем $Passwd_Key)',0,0);
    }else
    {
       $rows=&sql_do($dbh,$sql);
    } 
    $rows!=1 && &Error("Произошла ошибка при изменении данных клиента!".$ret);
    $rez_mess=&div('cntr big',"Данные клиента $show_client изменены.");
 }
  else
 {  # никакие данные не меняем, а пересылаем на подтверждение вышестоящему админу
    $sql="INSERT INTO pays SET $Apay_sql,mid=$Fid,cash=0,type=50,category=417,reason='u:$Fid',coment='".&Filtr_mysql($X)."',time=unix_timestamp()";
    $rows=&sql_do($dbh,$sql);
    $rows<1 && &Error("Произошла ошибка создания записи о предложениии зменения данных!".$ret);
    $OUT.=&MessX(&div('lft',"Никакие данные учетной записи клиента не были изменены - они были посланы на подтверждение вышестоящему администратору.$br$rez_mess"),1).$br2.$ret;
    &Exit;
 } 

 $stop++ if $Ashowsql;

 # была изменена группа, надо изменить и у алиасов
 $change_fields{grp} && &sql_do($dbh,"UPDATE users SET grp=$grp WHERE mid=$Fid",'Изменим группу у алиасов, если есть');
 
 if( $change_fields{paket} )
 {  # был изменен пакет - изменим у всех алиасов
    &sql_do($dbh,"UPDATE users SET paket=$new_paket WHERE mid=$Fid",'Изменим пакет у алиасов, если есть');
 }

 # === Почта ===
 if ($mail_enable && defined($F{m_email0}))
 { # Удалим существующие ящики
   $dbh2->do("DELETE FROM `$mail_table` WHERE `$mail_p_user`='$Mid'");
   # Пройдемся по всем записям переданным через форму
   for $j (0..100)
   {
      last unless defined($F{"m_email$j"});
      next unless $F{"m_email$j"};
      $m_email=&Filtr_mysql($F{"m_email$j"});
      if( $m_email=~/[йцукенгшщзхъфывапролджэячсмитьбюёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ]/ )
      {
         &stop_mess("В почтовом ящике <b>$m_email</b> присутствуют кирилические буквы",'Предупреждение');
      }
      $sth2=$dbh2->prepare("SELECT * FROM `$mail_table` WHERE `$mail_p_email`='$m_email' LIMIT 1");
      $sth2->execute;
      if( $p2=$sth2->fetchrow_hashref )
      {
         $uid=int $p2->{"$mail_p_user"};
         &stop_mess("Почтовый ящик <b>$m_email</b> уже занят ".($uid? &ahref("$scrpt&id=$uid",'другим клиентом') : &Filtr_out($p2->{"$mail_p_user"})).". Почтовый ящик не создан",'Внимание');
         next;
      }
      $m_pass=&Filtr_mysql($F{"m_pass$j"} ne '' ? $F{"m_pass$j"} : $F{"m_oldpass$j"});
      $m_dir=&Filtr_mysql($F{"m_dir$j"});
      $m_enable=&Filtr_mysql($F{"m_enable$j"});
      $m_dir=~s/([^\/])$/$1\// if $mail_check_dir;
      $dbh2->do("INSERT INTO `$mail_table` (`$mail_p_user`,`$mail_p_email`,`$mail_p_pass`,`$mail_p_dir`,`$mail_p_enable`) VALUES('$Mid','$m_email','$m_pass','$m_dir','$m_enable')");
      $X.="Почтовый ящик: $m_email\n";
   }
 }

 if( $change_fields{state} )
 {
    $sth=&sql($dbh,"SELECT id,ip FROM users WHERE (mid=$Mid OR id=$Mid) AND state<>(SELECT state FROM users WHERE id=$Fid LIMIT 1)",
       'Получим записи клиента, у которых состояние доступа иное чем у текущей записи');
    while ($p=$sth->fetchrow_hashref)
    {
       $rez_mess.=$br2.&ahref("$scrpt&id=".$p->{id},$p->{ip}).' - алиасная запись измененной только что записи. Состояние доступа алиасной записи'.
         ' отличается от текущей. Вы можете изменить состояние доступа и для нее - щелкните по ссылке';
       $stop++;
    }
 }

 $X && &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,cash=0,type=50,category=410,reason='".&Filtr_mysql($X)."',".
   "time=$ut",'Создадим событие об изменении данных клиента');

 $OUT.=&MessX(&div('lft',$rez_mess)).$br2.$ret;

 &Exit if $stop;  # зафиксируем на экране сраницу

 $DOC->{header}.=qq{<meta http-equiv="refresh" content="0; url='$scrpt&id=$Fid&mess=$t'">};
 &Exit;
}

# ======================================================================================================================

$field_change_id=5;
$set_disabled='';
sub SS
{
 $set_disabled.="\ndocument.getElementById('$field_change_id').disabled=true;";
 return($CanSave || $WannaSave? " id=$field_change_id onChange='SetRed(".$field_change_id++.");'" : '')
}

sub show_line
{# 0 - право на изменение параметра
 # 1 - заголовок
 # 2 - имя параметра
 # 3 - значение параметра
 # 4 - длина отображения
 # 5 - допустимая длина
 # 6 - [3я колонка]
 my ($priv,$title,$name,$value,$len1,$len2,$dop)=@_;
 my $line=$priv? &input_h("old_$name",$value).&input_t($name,$value,$len1,$len2,&SS) : $value;
 
 $line=&Table('width100 table0',&RRow($r2,'lr',$line,$dop)) if $dop;
 return &RRow('*','ll',$title,$line);
}


($ipp,$grp)=($real_ip,$real_grp);
$name=&Filtr_out($real_name);
$fio=&Filtr_out($real_fio);

$back_p=$p;
if ($mid)
  {
   $p=&sql_select_line($dbh,"SELECT * FROM users WHERE id=$mid LIMIT 1",'Запись алиасная. Получим данные основной записи');
   if ($p)
     {
      $Mid=$mid;
      ($MainIp,$grp)=&Get_fields('ip','grp'); # хотя группа и совпадает с алиасной, все равно для гарантии возьмем у основной
      $Mname=&Filtr_out($p->{name});
     }
      elsif ($pr_SuperAdmin)
     {
      $OUT.=&div('message cntr',"<br><span class=error>Предупреждение:</span> данная алиасная запись ссылается на отсутствующую основную запись!!!$br2");
      $MainIp='ip: ???';
      $Mname='???';
      $p=$Mstate=$block_if_limit='';
      $Mid=-1;
      $grp=$balance=$limit_balance=$start_day=$paket=$mail_enable=0;
     }else
     { 
      &Error("$br2 Даная алиасная запись указывает на отсутствующую основную запись. В данной ситуации просмотр и изменение данных может осуществить только главный администратор.$br3")
     }
  }
   else
  {# Текущая запись - основная
   ($Mid,$MainIp,$Mname)=($Fid,$ipp,$name);
  } 

($Mstate,$paket,$paket3,$balance,$limit_balance,$block_if_limit,$start_day,$srvs)=&Get_fields qw(
   state  paket  paket3  balance  limit_balance  block_if_limit  start_day  srvs ) if $p;

@T=&GetClientTraf($Mid); # Трафик по основной записи
$i=0;
map{ $traf{$_}=$T[$i++] } qw( in1 out1 in2 out2 in3 out3 in4 out4 );

$p=$back_p;

$pr_full_access=$UGrp_allow{$grp}>1;
# Есть ли право на работу с данной группой
unless ($UGrp_allow{$grp})
  {
   &Error("Запрашиваемая запись принадлежит группе, доступ к которой вам запрещен.") if !$pr_SuperAdmin || $UGrp_name{$grp};
   $OUT.=&div('message cntr','<span class=error>Предупреждение:<span> клиент находится в несуществующей группе. Измените ее.',1);
   $UGrp_allow{$grp}=2; # дадим права на изменение в несуществующей группе
  }
   elsif (!$pr_full_access)
  {# Доступ к группе ограничен. Разрешим только:
   # 1: доступ к админке; 50: просмотр ФИО; 54: платеж; 55: сообщение; 23,25: работники и работа
   %pr=();
   $pr{$_}=$PR{$_} foreach (1,50,54,55,23,25);
   %PR=%pr;
   ${"pr_$pr_def{$_}"}=$PR{$_} foreach %pr_def;
   $real_mail_enable=$mail_enable=0; # заблокируем работу с почтой
   $OUT.=&div('message cntr','Ограниченный доступ на работу с клиентом в данной группе.');
  }


$CanSave=$pr_edt_usr;	# есть ли право на изменение учетных записей

if ($F{wannasave})
  {# админ желает предложить внести изменение главному админу
   $WannaSave=1;
   $CanSave=0;
   $PR{$_}=1 foreach @SavePrivil;
   $OUT.=&error('Внимание!','Вы переключились в режим, в котором внесенные изменения не будут осуществлены, но будут предложены вышестоящему администратору');
  }else
  {
   $WannaSave=0;
  }

$ShowSave=$CanSave || $WannaSave;

# если изменять ничего нельзя, то удалим частные привилегии на изменения 
unless ($ShowSave) { $PR{$_}=0 foreach @SavePrivil }
# обновим текстовые описания привилегий
${"pr_$pr_def{$_}"}=$PR{$_} foreach %pr_def;

# ========================
#   Сохранение трафика
# ========================

if ($Fact eq 'savetraf')
 {
  &Error("Нет прав на изменение трафика клиента.") unless $pr_edt_traf;
  &Error("Прошло более 4 минут с момента начала редактирования трафика клиента $show_client.$br2 Изменение трафика отменено.") if $F{mess}<($t-240);
  @T=qw( in1 out1 in2 out2 in3 out3 in4 out4 );
  $sql='';
  $k=$F{mb}? $mb : 1;
  foreach (0..7)
    {
     $h=$F{"t$_"};
     $h=~s|\s||g;
     next if $h eq '';
     $sign=substr $h,0,1;
     $h=int $h*$k;
     $sql.="$T[$_]=".
       (
        $sign eq '+'? "$T[$_]+$h" : 
        $sign eq '-'? $T[$_].($h? $h : '') : # ! можно послать `-0`
        $h
       ).', '; 
    }
  $sql=~s|, $||;
  &Error("Трафик клиента $show_client не изменен - вы не указали ни одного изменения.$ret") unless $sql;
  # возможны случаи, когда строки с трафиком нет - клиент только что внесен в БД, поэтому вставим строку, а если она есть, то не внесется т.к ключ uid - уникальный
  &sql_do($dbh,"INSERT INTO users_trf SET uid=$Mid,uip='$MainIp',packet=$paket,startmoney=$balance",'Вставим строчку о трафике, если ее нет (если клиент новый)');
  $rows=&sql_do($dbh,"UPDATE users_trf SET $sql WHERE uid=$Mid LIMIT 1",'Обновление трафика');
  &Error("Трафик клиента $show_client не изменен - ошибка при выполнении sql-запроса.") if $rows<1;
  $comment=&trim(&Filtr_mysql($F{comment}));
  $comment=". Причина изменения:\n $comment" if $comment;
  &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Mid,type=50,reason='Изменен трафик ($sql)$comment',cash=0,category=410,time=unix_timestamp()");
  &ToLog("! $Admin_UU Изменен трафик клиента '$client'");
  &OkMess("Трафик клиента $show_client изменен.");
  $OUT.=$ret;
  &Exit;
 }


# =======================
# форма изменения трафика
# =======================

if ($Fact eq 'edittraf')
 {
  !$pr_edt_traf && &Error('Нет прав на изменение трафика клиента.');
  $comments='';
  $comments.=qq{<span class='data2' style='cursor:pointer;' onClick="javascript: document.getElementById('comment').value='$_'">$_</span><br>}
             foreach ('Перенос с другого биллинга','Перерасчет','В связи с недополученной услугой','Бонус');
  
  $out=&RRow('head','ccc','Трафик','Текущее значение','Изменить на величину'); 
  @c=&Get_Name_Class($Plan_preset[$paket]);
  foreach $i (0..3)
    {
     $out.=&RRow('*','lrl',"Входящий @c[$i]",&split_n($T[$i*2]),&input_t('t'.($i*2),'',36,30,&SS));
     $out.=&RRow('*','lrl',"Исходящий @c[$i]",&split_n($T[$i*2+1]),&input_t('t'.($i*2+1),'',36,30,&SS));
    }
  $out.=&RRow('*','Ll','Укажите причину изменения:'.$br.&input_ta('comment','',44,6,'id=comment'),$comments);
  $out.=&RRow('*','Lc',"<input type=checkbox name=mb value=1> числа введены в мегабайтах",&submit_a('Изменить'));
  $out=&Table('tbg1',$out);

  $OUT.=&div('message lft',$br."Изменение данных трафика клиента $show_client".$br2.
    "Вы можете вводить 3 типа значений: со знаком плюс, со знаком минус и без знака. Значение со знаком плюс/минус изменяет на заданную величину текущее значение трафика данной категории. ".
    "Например, если вы введете <b>-100</b> (минус 100), то от текущего значения трафика отнимется 100 байт. Если ввести значение без знака, то трафик будет установлен в ".
    "заданное значение, что не рекомендуется т.к. параллельно может идти снятие статистики и как следствие модификация трафика клиента. Если вы не хотите изменять какую-либо ".
    "категорию(и) трафика - оставьте значение пустым напротив данной категории.$br2 Результирующий трафик может быть отрицательным - это будет означать запас трафика.$br2".
    &form('!'=>1,'act'=>'savetraf','id'=>$Fid,'mess'=>$t,$out).$ret);
  &Exit;
 }

if ($Fact eq 'wanna_del')
 {
  $OUT.=&Error(&div('cntr',"Вы собираетесь предложить удалить учетную запись клиента $show_client. ".
    "Вместо удаления рекомендуется переводить учетную запись в группу ".&commas('удаленные').
    ". Если данная учетная запись внесена ошибочно и действительно требуется ее удалить, укажите причину:<br><br>".
    &form('!'=>1,'act'=>'wanna_real_del','id'=>$Fid,'time'=>$t,&input_ta('reason','',54,6).$br2.&submit_a('Послать запрос')).$ret));
  &Exit;  
 } 

if ($Fact eq 'wanna_real_del')
 {
  $reason="d:$Fid";
  $h=&sql_select_line($dbh,"SELECT time FROM pays WHERE reason='$reason' LIMIT 1",'Проверка не повторная ли заявка');
  $h && &Error("Заявка на удаление клиента $show_client уже сформирована ".&the_short_time($h->{time},$t,1).$ret);

  &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,cash=0,type=50,category=417,reason='$reason',coment='".&Filtr_mysql($F{reason})."',time=unix_timestamp()");
  &OkMess("Заявка на удаление клиента $show_client сформирована. Ожидайте реакции вышестоящего администратора.");
  $OUT.=$ret;
  &Exit;
 }
    

# ========================
#  Отсылка email клиенту
# ========================

if ($Fact eq 'mail')
 {
  $mail_enable or &Error($br2.'Недостаточно прав для отсылки email клиенту либо ошибка соединения с БД.'.$br3);

  $OUT.=&div('message cntr',$br.'Сообщение:'.$br.
     &div('message lft','<pre>'.&Filtr_out($F{mess}).'</pre>').$br.
     (&Smtp($F{mess},$F{m_email},'bill@microsoft.com')? 'отправлено ':'НЕ ОТПРАВЛЕНО ').
     &Filtr_out($F{m_email})
  ).$ret;

  &Exit unless $pr_mess_create && $MakeMailMess;
  $OUT.=$br2.&bold("Необходимо ли оставить клиенту сообщение?").
     &form('!'=>1,'a'=>'pays','act'=>'pay','mid'=>$Mid,'op'=>'mess',
       &Table('tbg1',
         &RRow('row1','c',&input_ta('coment',"Почтовый ящик $F{m_email} создан. $MakeMailMess",60,6)).
         &RRow('head','c',&submit_a('Отправить'))
       )
     );
  &Exit;
 }

# =======================================================================
#			Отображаем данные клиента
# =======================================================================

# проверяем время на случай, если страница по хистори открыта - не будем пугать админа сообщением `данные сохранены`
$OUT.=&div('message big cntr',&bold_br('Изменения данных клиента сохранены.')) if $F{mess} && $F{mess}>($t-120);

{
 $mail_enable or last;
 @m_email=@m_pass=@m_dir=@m_enable=();
 $m_i=0;
 $sth2=&sql($dbh2,"SELECT * FROM `$mail_table` WHERE `$mail_p_user`='$Mid'",'Email клиента');
 while ($p2=$sth2->fetchrow_hashref)
   {
    $m_email[$m_i]=&Filtr_out($p2->{"$mail_p_email"});
    $m_pass[$m_i]=&Filtr_out($p2->{"$mail_p_pass"});
    $m_dir[$m_i]=&Filtr_out($p2->{"$mail_p_dir"});
    $m_enable[$m_i]=&Filtr_out($p2->{"$mail_p_enable"});
    $m_i++;
   }
 if ($F{email})
   {# подготовлено имя ящика для создания
    $m_email[$m_i]=lc(&Filtr_out($F{email}));
    $m_pass[$m_i]='';
    $m_dir[$m_i]=$m_email[$m_i];
    $m_dir[$m_i]=~s/@.+$//;
    $m_dir[$m_i].='/';
    $m_enable[$m_i]='1';
    $OUT.=&div('message cntr',$br.'Первый email заполнен по данным которые прислал клиент'.$br2);
   }
}

$pass2=$pass=($Fact eq 'pswd') && $pr_show_usr_pass? $p->{"AES_DECRYPT(passwd,'$Passwd_Key')"} : '';
$pass2=~tr/qwertyuiop[]asdfghjkl;'zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>&/йцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ /;
$pass2=$pass2? " <acronym title='В русской раскладке'>$pass2</acronym>" : &ahref("$scrpt&id=$Fid&act=pswd",'Показать');

($cstate,$lstate,$next_paket,$next_paket3,$hops,$detail_traf,$discount,$sortip,$comment)=&Get_fields qw(
  cstate  lstate  next_paket  next_paket3  hops  detail_traf  discount  sortip  comment);
($contract)=&Get_filtr_fields qw( contract );

$start_balance=$balance;
$h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE mid=$Fid AND type IN (10,20) GROUP BY mid");
$check_balance=$h->{cash}+0; # может быть null

$h=$p->{contract_date};
$contract_date=!!$h && &the_date($h);

$out_pkt=$out_npkt='';
if( $ShowSave && $PR{76} && !$mid )
{
  %tarifs=();  
  foreach $i (1..$m_tarif)
  {
     $Plan_name[$i] or next;
     $h=$Plan_allow_show[$i]? $Plan_name[$i] : 'скрыт';
     $tarifs{$i}=$h;
  } 
  foreach $i (sort {$tarifs{$a} cmp $tarifs{$b}} keys %tarifs)
  {
     $tarif_name=&Del_Sort_Prefix($tarifs{$i});
     $out_pkt.=$paket==$i? "<option value=$i selected>$tarif_name</option>" : $Plan_allow_show[$i]? "<option value=$i>$tarif_name</option>" : '';
     $out_npkt.=$next_paket==$i? "<option value=$i selected>$tarif_name</option>" : $Plan_allow_show[$i]? "<option value=$i>$tarif_name</option>" : '';
  }

  $out_pkt.="<option value=$paket selected>ОШИБОЧНЫЙ НОМЕР ПАКЕТА</option>" if !$Plan_name[$paket];
  $out_npkt=!$next_paket? "<option value=0 selected>&nbsp;</option>$out_npkt" :
        !$Plan_name[$next_paket] ? "<option value=$next_paket selected>$next_paket - ОШИБОЧНЫЙ НОМЕР ПАКЕТА</option>$out_npkt" :
        "<option value=0>&nbsp;</option>$out_npkt";
  $out_pkt=&input_h('old_paket',$paket)."<select name=paket size=1".&SS.'>'.$out_pkt;
  $out_npkt=&input_h('old_next_paket',$next_paket)."<select name=next_paket size=1".&SS.'>'.$out_npkt;

  $pakets3=$next_pakets3='';
  foreach $i (keys %Plans3)
  {
     $h=$Plans3{$i}{usr_grp}=~/,$grp,/;  
     $tarif_name=&Del_Sort_Prefix($Plans3{$i}{name});
     $pakets3.="<option value=$i".($paket3==$i && ' selected').">$tarif_name</option>" if $h || $i==$paket3;
     $next_pakets3.="<option value=$i".($next_paket3==$i && ' selected').">$tarif_name</option>" if $h || $i==$next_paket3;
  }
  $pakets3&&=&input_h('old_paket3',$paket3)."<select name=paket3><option value=0> </option>$pakets3</select>";
  $next_pakets3&&=&input_h('old_next_paket3',$next_paket3)."<select name=next_paket3><option value=0>&nbsp;</option>$next_pakets3</select>";
}
 elsif( !$mid )
{ # основная запись и нет прав менять пакет
  $out_pkt=$Plan_allow_show[$paket]? $Plan_name_short[$paket] || 'ошибочный номер пакета' : 'скрыт';
  $out_npkt=!$next_paket? 'не менять' : $Plan_allow_show[$next_paket]? $Plan_name_short[$next_paket] || 'ошибочный номер пакета' : 'скрыт';
  $pakets3=$paket3? &Del_Sort_Prefix($Plans{$paket3}{name}) : '';
  $next_pakets3=$next_paket3? &Del_Sort_Prefix($Plans{$next_paket3}{name}) : '';
}

# состояние записи заблокирована/не заблокирована
$state=$p->{state};
if( $state ne 'off' )
{
   $Sstate=$ShowSave && $PR{77}? &input_h('old_state','on')."<select name=state size=1".&SS."><option value=on selected>Разрешен</option><option value=off>Запрещен</option></select>" : "<span class=data1>Разрешен</span>";
}else
{
   $Sstate=$ShowSave && $PR{77}? &input_h('old_state','off')."<select name=state size=1".&SS."><option value=on>Разрешен</option><option value=off selected>Запрещен</option></select>" : "<span class=error>Запрещен</span>";
}

if( !$mid )
{
   if( $ShowSave && $PR{73} )
   {
      $grps=&input_h('old_grp',$grp).'<select name=grp size=1'.&SS.'>';
      foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
      {
         $n_grp=$UGrp_name{$g};
         next unless $UGrp_allow{$g}; # не показывает группу только если доступ полностью запрещен (не частично)
         $grps.="<option value=$g".($grp==$g && ' selected').">$n_grp</option>";
      }
      $grps.='</select>';
   }else
   {
      $grps=$UGrp_name{$grp}||'???';
   }
}else
{
   $grps='';
}

if ($ShowSave && $PR{79})
  {
   $cst_line=&input_h('old_cstate',$cstate).'<select name=cstate size=1'.&SS.'>';
   $cstates{0}=' Все ОК'; # первым в сортировке
   $cst_line.="<option value=$_".($cstate eq $_ && ' selected').">$cstates{$_}</option>" foreach (sort {$cstates{$a} cmp $cstates{$b}} keys %cstates);
   $cst_line.='</select>';
  }else
  {
   $cst_line=$cstates{$cstate}||'Неизвестно';
  }

if ($ShowSave && $PR{80})
  {
   $Lstate=&input_h('old_lstate',$lstate).'<select name=lstate size=1'.&SS.'><option value=0'.($lstate? '':' selected').'>Включена</option>'.
           '<option value=1'.($lstate? ' selected':'').'>Всегда онлайн</option></select>';
  }else
  {
   $Lstate=$lstate? 'Выключена':'Включена';
  }

$ip_cell=qq{<span onClick='window.clipboardData.setData("Text","$ipp")' class=data2 style='cursor:pointer;border:0;' title='Копировать $ipp в буфер обмена'>Ip</span><br>};

$OUT.="<table class=width100 cellpadding=1 cellspacing=10><tr>".
 qq{<$tc valign=top><form id=formedit method=post action='$script' onsubmit="javascript:document.getElementById('savebutton').innerHTML='<div class=message>Данные посланы. Ждите...</div>';">}.
   &input_h(%FormHash).&input_h('act'=>'save','id'=>$Fid,'mess'=>$t,'wannasave'=>$WannaSave).
   ($ShowSave? "<table class='tbg1 width100'>" : "<table class='tbg3 width100'>");

$OUT.=&show_line($PR{71},'Приоритет','sortip',$sortip,32,32,"<acronym title='Чем меньше число тем больше приоритет'>&nbsp;?</acronym>") if $Edit_sortip && $PR{71};

$OUT.=&RRow('*','ll','Группа',$grps) if $grps;
$OUT.=&show_line($PR{71},$ip_cell,'ip',$ipp,18,18,$PR{71} && '<input type=checkbox name=setip value=1'.&SS.
   "> <acronym title='Поставьте галочку если хотите изменить ip'>&nbsp;?</acronym>");

$OUT.=&show_line($PR{72},'Логин','name',$name,38,32) if $pr_show_fio;
$OUT.=&show_line(1,'Пароль','pass',$pass,25,30,$pass2) if $pr_show_usr_pass;
$OUT.=&show_line($PR{74},'Контракт','contract',$contract,38,30) if !$mid;
$OUT.=&show_line($PR{74},'Дата контракта','contract_date',$contract_date,38,30) if !$mid;
$OUT.=&show_line($PR{75},'ФИО','fio',$real_fio,38,255) if $pr_show_fio;

if( $pr_show_traf && !$mid )
{
   $OUT.=&RRow('*','C',$Plan2_Title || 'Основные тарифы') if ($pakets3 || $next_pakets3) && ($out_pkt || $out_npkt);
   $OUT.=&RRow('*','ll','Пакет',$out_pkt) if $out_pkt;
   $OUT.=&RRow('*','ll','След. пакет',$out_npkt) if $out_npkt;
   if ($pakets3 || $next_pakets3)
     {
      $OUT.=&RRow('*','C',$Plan3_Title || 'Дополнительные тарифы');
      $OUT.=&RRow('*','ll','Пакет',$pakets3) if $pakets3;
      $OUT.=&RRow('*','ll','След. пакет',$next_pakets3) if $next_pakets3;
     }

   $OUT.=&RRow('*','ll',
     "На счету, $gr",
     ($PR{87}? &input_h('old_balance',$balance).&input_t('balance',$balance,30,20,&SS).
       " <input type=checkbox name=changeb value=1".&SS."> ".
       "<acronym title='Поставьте галочку если хотите изменить сумму на счету'>&nbsp;?</acronym>".
       ($check_balance!=$balance && $br."<span class=error>Баланс по платежам: </span>".$check_balance)
     : $balance)
   );
   $OUT.=&PRow."<td>Лимит</td><td>".($PR{78}?
         &input_h('old_limit_balance',$limit_balance)."<input type=text name=limit_balance value='$limit_balance' size=30".&SS."> ".
         &input_h('old_block_if_limit',$block_if_limit? 1:0)."<input type=checkbox name=block_if_limit value=1".(!!$block_if_limit && ' checked').
         &SS."> <acronym title='Поставьте галочку если хотите чтоб при балансе менее этого значения клиенту блокировался доступ в интернет'>&nbsp;?</acronym></td></tr>" :
         "$limit_balance (".($block_if_limit? 'включен' : '<b>не включен</b>').")</td></tr>");

   $sr=$srvs;

   for( $i=1;$i<32;$i++,$sr>>=1 )
   {
      $srv_n[$i] or next; # услуга без имени - значит не существует
      !($sr & 1) && !$PR{76} && next;
      $OUT.=&PRow."<td>Услуга</td><td>".($sr & 1? &input_h("old_sr$i",'yes') : '').
            &Table('table0 width100',&RRow($r1,'lr',&Filtr_out($srv_n[$i]),"$srv_p[$i] $gr ".($PR{76}? "<input type=checkbox name=sr$i value=yes".($sr & 1? ' checked':'').&SS.'>':'')));
   }

   $OUT.=&input_h('changesrvs',1);
}

$OUT.=&RRow('*','ll','Доступ',$Sstate);
$OUT.="<tr class=nav2><td colspan=2><a href='javascript:show_x(11)' id='addbutton'>&darr; Дополнительно</a></td></tr>" if $ShowSave;

$out=&RRow('*','ll','Авторизация',$Lstate).
     &RRow('*','ll','Состояние',$cst_line);

if (!$mid)
  {
   $out.=&show_line($PR{69},'Скидка, %','discount',$discount,18,5);
   $out.=&show_line($PR{81},'День начала потребления услуг','start_day',$start_day,18,5,
       &div('nav3',&ahref("$scrpt0&a=operations&act=help&theme=startday",'?')));
  }

$can_show_map=$hops>0 && $pr_topology;
$h=&Table('table2 width100',
     &RRow('nav3','lllr',
       $ShowSave && $PR{84}? &input_h('old_hops',$hops).&input_t('hops',$hops,7,10,&SS) :  $can_show_map? '' : $hops,
       $can_show_map && &ahref("$scrpt0&a=oper&act=points&op=edit&id=$hops","Точка $hops"," target='_blank'"),
       $can_show_map && &ahref("$scrpt0&a=map&bx=$hops",'К'," target='_blank'"),
       &ahref("$scrpt0&a=operations&act=help&theme=hops",'?')
     )
);
$out.=&RRow('*','ll','Точка подключения',$h);

$h=&Table('table2 width100',
     &RRow('nav3','lr',
        $PR{85}? &input_h('old_detail_traf',$detail_traf? '1':'0')."<input type=checkbox name=detail_traf value=1".
          ($detail_traf? ' checked':'').&SS."> - включить" :
           $detail_traf? 'включена':'отключена',
        &ahref("$scrpt0&a=operations&act=help&theme=detailtraf",'?')
     )
);
$out.=&RRow('*','ll','Детализация трафика',$h);
$out.=&RRow('*','C','Комментарий:'.$br.($PR{86}? &input_h('old_comment',$comment).&input_ta('comment',$comment,34,5,&SS) : 
   '<i>'.&Filtr_out($comment).'</i>')) if $PR{86} || $comment;

$OUT.="<tr id=my_x_11".($cstate || !$ShowSave? '':" style='display:none'").'><td colspan=2>'.
   &Table('tbg width100',$out).'</td></tr>';

{
 next if !$mail_enable || $Fact ne 'showmail';
 $i=$m_i;
 while ($i>=0)
  {
   $OUT.=&PRow."<td>Email</td><td><input type=text name=m_email$i value='$m_email[$i]' size=36 maxlength=40></td></tr>".
     "<tr class=$r1><td>Email пароль</td><td><input type=text name=m_pass$i value='' size=36 maxlength=30>".($m_pass[$i] ? " <acronym title='Текущий: $m_pass[$i]'> Смотри</acronym>" : '')."<input type=hidden name=m_oldpass$i value='$m_pass[$i]'></td></tr>".
     "<tr class=$r1><td>Вкл/выкл</td><td><input type=text name=m_enable$i value='$m_enable[$i]' size=36 maxlength=30></td></tr>".
     "<tr class=$r1><td>Каталог</td><td><input type=text name=m_dir$i value='$m_dir[$i]' size=36 maxlength=40></td></tr>".
     "<tr class=head><td colspan=2><img height=1 src='$spc_pic'></td></tr>";
   $i--;
  }
}

$OUT.=&RRow('head','C',"<div id=savebutton>$br<input type=submit value=' ".($WannaSave? 'Предложить изменить' : 'Сохранить')." '>$br2</div>") if $ShowSave;
$OUT.='</table></form></td>';

$money_param={ 
  paket=>$paket,
  paket3=>$paket3,
  service=>$srvs,
  start_day=>$start_day,
  discount=>$discount,
  traf=>\%traf,
  mode_report=>0
};
$h=&Money($money_param);
$got_money=sprintf("%.2f",$h->{money});
$money_over=$h->{money_over};
$report=$h->{report};

$rez_balance=sprintf("%.2f",$start_balance-$got_money);
$block_balance=localtime($t)->mday < $Plan_got_money_day? ($over_cmp? $start_balance-$money_over : $start_balance) : $rez_balance;

# ===========================
#	Средняя колонка
# ===========================

$OUT.='<td class=lft valign=top><div id=countdiv></div>'; # для счетчика когда заблокировать кнопку "сохранить"

$out=''; # выведем все записи клиента
$sth2=&sql($dbh,"SELECT u.*,MAX(l.time) AS time FROM users u LEFT JOIN login l ON u.id=l.mid WHERE u.id=$Mid OR u.mid=$Mid GROUP BY u.id ORDER BY u.mid,u.sortip",
   'Все записи клиента с учетом времени последней авторизации');
while ($h=$sth2->fetchrow_hashref)
  {
   $aid=$h->{id};
   $row=$h->{state} ne 'off'? '*' : 'rowoff';
   $maxtime=$h->{time};
   $out.=&RRow($row,'ccrrcr',
     $aid==$Fid && &bold('&rarr;'),
     &ShowModeAuth($h->{auth}).($h->{lstate}>0 && " <acronym class=error>&hearts;</acronym>"),
     !!$h->{time} &&  &the_short_time($h->{time},$t),
     $aid,
     &div('nav3',&ahref("$scrpt&id=$aid",$pr_show_fio? &Filtr_out($h->{name}): '&rarr;')),
     $h->{ip}
   );
  }

$OUT.=&Table('usrlist width100','<thead>'.&RRow('head',' ccccc','','Авт','Последняя','ID','Логин','IP').'</thead>'.$out) if $out;

$OUT.=&div('message cntr','Предупреждение: при первой авторизации клиента произойдет его отключение т.к. '.
     'баланс ниже границы отключения') if $block_if_limit && $block_balance<$limit_balance && $state ne 'off' && !$mid;

&LoadJobMod;
$out=&nJob_ShowJobBlank($Fid);
$OUT.=$out.$br if $out;

if ($PR{103})
{  # оборудование
   $out='';
   $h=&sql_select_line($dbh,"SELECT COUNT(parent_id) AS n FROM dopdata WHERE ".
     "parent_type=1 AND field_type=7 AND field_value='0:$Fid' GROUP BY parent_id",
     'Оборудование, которое числится на клиенте');
   $out.=&ahref("$scrpt0&a=equip&act=find&owner_type=0&owner_id=$Fid",$h->{n}.' единиц оборудования').$br if $h && $h->{n};
   $out.=&form('a'=>'dopdata','parent_type'=>1,'owner_type'=>0,'owner_id'=>$Fid,
     'Оборудование с внутренним № '.&input_t('id','',6,8)."&nbsp;&nbsp;&nbsp;".&submit('Передать клиенту'));
   $OUT.=$br.&MessX($out,0,1) if $PR{96};
}


if ($pr_show_traf)
 {# Админу можно просматривать трафик клиента и счет. Временные платежи?
  $temp_money=0;
  $out2='';
  $sth2=&sql($dbh,"SELECT * FROM pays WHERE mid=$Mid AND type=20",'Есть ли временные платежи?');
  while ($p2=$sth2->fetchrow_hashref)
  {
     $h=$p2->{cash};
     $temp_money+=$h;
     $h=$pr_edt_pays && ($pr_edt_foreign_pays || $p2->{admin_id}==$Admin_id)?
        &ahref("$scrpt0&a=pays&act=show&id=$p2->{id}",$h," title='изменить/удалить'") : &bold($h);
     $out2.=&div('modified',"Временный платеж в размере $h $gr").$br;
  }

  # Выведем информацию по трафику
  # Для того чтоб не был слишком большой вывод если не все направления - выведем только трафик
  # который определяется характеристиками пакета. Но если трафик в скрываемом направлении есть - его выводим!
  ($c1,$c2,$c3,$c4)=&Get_Name_Class($Plan_preset[$paket]);
  $out=&RRow('*','lr',"$c1 входящий, байт",&split_n($T[0])).
       &RRow('*','lr',"$c1 исходящий, байт",&split_n($T[1]));
  $out.=&RRow('*','lr',"$c2 входящий, байт",&split_n($T[2])).
        &RRow('*','lr',"$c2 исходящий, байт",&split_n($T[3])) if $Plan_over2[$paket] || $T[2] || $T[3];
  $out.=&RRow('*','lr',"$c3 входящий, байт",&split_n($T[4])).
        &RRow('*','lr',"$c3 исходящий, байт",&split_n($T[5])) if $Plan_over3[$paket] || $T[4] || $T[5];
  $out.=&RRow('*','lr',"$c4 входящий, байт",&split_n($T[6])).
        &RRow('*','lr',"$c4 исходящий, байт",&split_n($T[7])) if $Plan_over4[$paket] || $T[6] || $T[7];
  $out.=&RRow('row3','ll',"Оплата $c1, Мб: ".&Get_name_traf($InOrOut1[$paket]),sprintf("%.3f",&Get_need_traf($T[0],$T[1],$InOrOut1[$paket])/$mb)).
        &RRow('row3','ll',"Оплата $c2, Мб: ".&Get_name_traf($InOrOut2[$paket]),sprintf("%.3f",&Get_need_traf($T[2],$T[3],$InOrOut2[$paket])/$mb)).
        &RRow('row3','ll',"Оплата $c3, Мб: ".&Get_name_traf($InOrOut3[$paket]),sprintf("%.3f",&Get_need_traf($T[4],$T[5],$InOrOut3[$paket])/$mb)).
        &RRow('row3','ll',"Оплата $c4, Мб: ".&Get_name_traf($InOrOut4[$paket]),sprintf("%.3f",&Get_need_traf($T[6],$T[7],$InOrOut4[$paket])/$mb));
  $out.=$Plan_allow_show[$paket]? &RRow('*','L',$report) : &RRow('*','lr',"Cнятие за тарифный план, $gr",$got_money);
  $out.=&RRow('*','lr',&bold('На счете с учетом стоимости тарифного плана').", $gr",&bold($rez_balance));
  $out.=&RRow('*','lr',&bold('На счете без учета временных платежей').", $gr",&bold(sprintf("%.2f",$rez_balance-$temp_money))) if $temp_money;
  $OUT.=&Table('tbg1 nav3 width100',$out).$br.$out2;
 }

# С кем-нибудь на одном кабеле?
$p2=&sql_select_line($dbh,"SELECT * FROM cable WHERE type=0 AND (green=$Fid OR blue=$Fid) LIMIT 1",'С кем на одном кабеле:');
if ($p2)
  {
   $h=$p2->{id};
   $h2=$p2->{green}==$Fid? $p2->{blue} : $p2->{green};
   $OUT.="<table class='nav table2 width100'><tr class=head><td>";
   $h3="</td><td>".&ahref("$scrpt&a=points&act=cbledit&w=$h",'Смотреть/изменить').'</td></tr></table>';
   if ($h2>0)
     {
      $p2=&sql_select_line($dbh,"SELECT * FROM users WHERE id=$h2 LIMIT 1",'Данные клиента, с которым на одном кабеле');
      if ($p2)
        {
         $OUT.="<b>На одном кабеле с клиентом:</b></td><td>".&ahref("$scrpt&id=$h2",&Filtr_out($p2->{name})).$h3;
        }else
        {
         $OUT.="<b>2я пара кабеля, на котором подлючен клиент, указывает на подключение к несуществующему клиенту</b>$h3";
        }
     }
      elsif (!$h2)
     {
      $OUT.=&bold('2я пара кабеля, на котором подлючен клиент, свободна').$h3;
     }
      elsif ($h2==-1)
     {
      $OUT.=&bold('2я пара кабеля занята другим клиентом, однако она не подписана!').$h3;
     }
      else
     {
      $OUT.=&bold('2я свободная пара кабеля ПОВРЕЖДЕНА').$h3;
     }
  }

# Выведем сообщения для клиента из таблицы платежей
&LoadPaysTypeMod;
$out='';
$sth2=&sql($dbh,"SELECT * FROM pays WHERE mid=$Mid AND ((type=30 AND category IN (490,491,492,493)) ".($pr_show_traf && " OR type=10").') ORDER BY time DESC LIMIT 6','Сообщения клиенту');
while ($h=$sth2->fetchrow_hashref)
  {
   $mess='';
   $type=$h->{type};
   $category=$h->{category};
   if ($type==30)
     {# неотвеченное сообщение от клиента
      $mess.=&div('nav3',&ahref("$scrpt0&a=pays&op=mess&mid=$Mid&q=".$h->{id},'Ответить')) if $category==491 && $PR{55};
      $mess.=&Show_all($h->{reason}) if $category==491 || $category==492;
      $mess.=&Show_all($h->{coment}) if $category==490 || $category==493;
     }
      else
     {#$type==10)
      $mess.="<span class=data1>$h->{cash}</span> $gr ";
     }
   $out.=&RRow('*','lll',
     &the_short_time($h->{time},$t),
     $ct{$category} || ($type==10 && 'Платеж'),
     $mess,
   );
  }
$OUT.="<div><a href='javascript:show_x(16)'>&darr; Последние 6 ".($pr_show_traf? "платежей, сообщений, комментариев)" : "сообщений")." клиенту</a></div>".
  "<table class='tbg1 width100' id=my_x_16 ".($Fact ne 'showmail' && "style='display:none'").">$out</table>" if $out && $pr_full_access;

if ($mail_enable && $m_email[$m_i-1])
  {
   $OUT.=&form('!'=>1,'act'=>'mail','id'=>$Fid,
      &ahref('javascript:show_x(14)','&darr; Отправить email').
      "<table class='tbg1 width100' id=my_x_14 style='display:none'>".
        &RRow('row1','c',&input_ta('mess','',34,5)).
        &RRow('row2','c','На email '.&input_t('m_email',$m_email[$m_i-1],32,40)).
        &RRow('head','c',&submit_a('Послать письмо')).
      '</table>');
  }

$OUT.=&div('row1',&ahref('javascript:show_x(15)','&darr; Отправить сообщение').
  &form('!'=>1,'-'=>1,'a'=>'pays','act'=>'pay','op'=>'mess','mid'=>$Mid,
    "<div class=cntr id=my_x_15 style='display:none'>".
      &input_ta('coment','',34,5).$br2.&submit_a('Отправить').$br.'</div>')
) if $pr_mess_create;

$out='';
$sth2=&sql($dbh,"SELECT * FROM pays WHERE mid=$Mid AND type=30 AND category=495 ORDER BY time DESC",'Замечания клиенту');
while ($h=$sth2->fetchrow_hashref)
  {
   $out.=&RRow('*','ll',&the_short_time($h->{time},$t),&Show_all($h->{reason}));
  }
$OUT.=Table('tbg1 width100',&RRow('rowsv','C','Замечания:').($pr_full_access? $out : &RRow('*','C','<span class=disabled>скрыты</span>'))) if $out;


# ===========================
#	Правая колонка
# ===========================

$stat_url='stat.pl?'.($PP? "uu=$UU&pp=$PP&":'')."id=$Fid";
$url_mid="$scrpt0&mid=$Mid";
$url_fid="$scrpt0&mid=$Fid";

$out='';

$out.=&ahref("$scrpt0&a=dopdata&id=$Fid",'Дополнительные данные') if keys %Dopfields_tmpl;
$url="$scrpt0&a=dopdata&parent_type=0&id=$Fid";
$out.=join '',map{ &ahref("$url&tmpl=$_",(split /-/,$Dopfields_tmpl{$_})[0]) } 
     sort{ $Dopfields_tmpl{$a} cmp $Dopfields_tmpl{$b} } grep{ int($_/100)==0 } keys %Dopfields_tmpl;
$out&&=&div('nav3',$out);
$out.=&ahref("$scrpt&id=$Fid&act=showmail",'Почтовые ящики') if $pr_mail && $real_mail_enable;
$out.=&ahref($stat_url,'Клиентская статистика') if $pr_usr_stat_page;
$out.=&div('rght',&ahref("$url_mid&a=pays",'Пополнить счет')) if $pr_pays_create || $pr_tmp_pays_create || $pr_old_pays_create;
$out.=&div('rght',&ahref("$url_mid&a=pays&op=mess",'Отправить сообщение')) if $pr_mess_create;
$out.=&ahref("$url_mid&a=payshow",'Платежи и события') if $pr_pays;
$out.=&ahref("$url_fid&a=payshow",'События алиаса') if $mid && $pr_pays;

$OUT2=$out && &div('nav2',$out,1);

$OUT2.=&div('head cntr pddng2',&bold('Трафик:')).
  &div('nav3 lft',
    &ahref("$url_fid&a=chanal&c=4&ed=4",'&nbsp;&nbsp;Детализация').
    &ahref("$stat_url&a=111",'&nbsp;&nbsp;Трафик').
    &ahref("$stat_url&a=108&all=1",'&nbsp;&nbsp;Трафик посуточно'),1
  ) if $pr_usr_stat_page;

$out='';
$out.=&ahref("$scrpt0&a=operations&act=print&id=$Fid",'Бланк настроек') if $pr_show_usr_pass;
$out.=&ahref("$scrpt0&a=job&act=setjob&id=$Fid",'Задание работникам') if $pr_workers_work;
$out.=&ahref("$scrpt&id=$Fid&wannasave=1",'Предложить изменения') if $pr_full_access && !$WannaSave;
$OUT2.=&div('nav2',$out,1) if $out;

$out=&ahref("$url_fid&a=chanal&time=1&class=9&graf=1",'Канал, загрузка');
$out.=&ahref("$url_fid&a=chanal&c=1",'Канал посуточно') if $pr_full_access;
$out.=&ahref("$url_mid&a=adduser",'Добавить алиас') if $PR{88};
$out.=&ahref("$url_mid&a=setpaket",'Смена тарифа') if $pr_edt_usr && $pr_full_access && $PR{76};
$out.=&ahref("$url_mid&a=pays&act=set_block&what_block=mess",'Блокировать сообщения клиента') if $pr_mess_create;
$out.=&ahref("$url_mid&a=pays&act=set_block&what_block=packet",'Блокировать заказ пакета') if $pr_block_chng_pkt;
$out.=&ahref("$scrpt&act=edittraf&id=$Fid",'Изменить трафик') if $pr_edt_traf;
$out.=&ahref("$scrpt0&a=deluser&act=del&id=$Fid",'Удалить!') if $pr_del_usr;
$out.=&ahref("$scrpt&act=wanna_del&id=$Fid",'Предложить удалить');

$OUT2.=&div('nav3',&ahref('javascript:show_x(18)','&darr; Дополнительно').
   "<div id=my_x_18 style='display:none'>$out</div>") if $out;

@usr_comments=(
  'некорректное поведение по телефону',
  'некорректное поведение в офисе',
  'попытки обмана',
);

if( $pr_mess_create )
{
   $out='';
   $out.=&ahref("$url_mid&a=pays&act=pay&op=cmt&coment=".&URLEncode($_),$_) foreach (@usr_comments);
   $OUT2.=$br.&div('nav3',&ahref('javascript:show_x(17)','&darr; Заготовки комментариев').
     "<div id=my_x_17 style='display:none'>$out</div>");
}

$OUT.='</td><td valign=top>'.&Mess3('row2',$OUT2).'</td></tr></table>';

if( $ShowSave )
{
$DOC->{header}.=<<HEAD;
<script>
function a()
{
 x+=1;
 if (z<(y-x)) { document.getElementById('countdiv').innerHTML="<img height=1 src='$spc_pic'>"; }
 z=y-x;
 if (z<30) { document.getElementById('countdiv').innerHTML="<div class=message>Через <b>"+z+"</b> секунд редактирование будет заблокировано т.к. отображаемые данные устареют</div>"; }
 if (x==y) {
   document.getElementById('savebutton').innerHTML="<div class=message>Редактирование заблокировано.<br>Обновите страницу</div>";
   document.getElementById('countdiv').innerHTML="";$set_disabled
   window.clearInterval(timer);
 }
}
function SetRed(element)
{
 document.getElementById(element).className='modified rowoff';
 y=$TimeNoSave2;
}
</script>
HEAD

$DOC->{body_tag}.=qq{ onload="javascript: y=$TimeNoSave; z=y; x=0; timer=setInterval('a()',1000); document.getElementById('addbutton').focus();"};
&Exit;
}

1;
