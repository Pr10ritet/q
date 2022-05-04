#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$PR{88} or &Error('Нет прав на создание учетных записей.');
&LoadMoneyMod;

$mid=int $F{mid};
if( $mid )
{
   $p=sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') AS pass FROM users WHERE id=$mid",'Данные основной записи',"скрыт: select from users where id=$mid");
   $p or &Error("Указанная основная запись id=$mid не существует!");
   $p->{mid} && &Error("Нельзя создать алиасную запись для алиасной.");
   ($grp,$paket,$paket3)=&Get_fields('grp','paket','paket3');
   $UGrp_allow{$grp}<2 && &Error("У вас нет прав на создание учетных записей в заказанной группе. Возможно, только что эти права были забраны.",$go_back);
   ($name,$fio,$passwd)=&Get_filtr_fields('name','fio','pass');
   $origpasswd=$br.'Пароль основной записи:'.$br.'<input type=radio name=passnum value=3 checked> '.&input_t('passwd3',$passwd,20,30);
   $OUT.=$br.&MessX(&Printf('Создание алиасной записи для логина: [bold], ФИО: [bold], id: [bold]',$name,$fio,$mid),0,1);
}
 else
{  # Найдем пакет, к которому админ имеет доступ
   %tarifs=();
   $first_pkt=0;
   foreach( 1..$m_tarif )
   {
      next if !$Plan_name[$_] || !$Plan_allow_show[$_];
      $first_pkt||=$_;
      $tarifs{$_}=$Plan_name_short[$_];
   }
   $paket=int $F{paket};
   $paket=$first_pkt if !$Plan_allow_show[$paket]; # сжульничал - пакет будет первым из списка
   $pakets=join '',map{ &tag('option',$tarifs{$_},"value=$_".($paket==$_ && ' selected')) } sort {$tarifs{$a} cmp $tarifs{$b}} keys %tarifs;
   $pakets=&tag('select',$pakets,'name=paket size=1');

   $fio=$origpasswd='';
   $OUT.=&Mess3('row2',&bold('Создание учетной записи клиента')).$br;

   @grps=grep{ $_ && $UGrp_allow{$_}>1 } keys %UGrp_name;
   $F{grp}=$grps[0] if $#grps==0; # если админу доступна всего одна группа, считаем, что он ее и выбрал

   if( defined $F{grp} )
   {
      $grp=int $F{grp};
      $UGrp_allow{$grp}<2 && &Error('У вас нет прав на создание учетных записей в заказанной группе. Возможно только что эти права были забраны.',$go_back);
   }
    else
   {
      $out1=$out2='';
      foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
      {
         next if $UGrp_allow{$g}<2 || !$g;
         $h="<option value=$g".($grp==$g && ' selected').">$UGrp_name{$g}</option>";
         $UGrp{$g}=~/^2$|^2,|,2,|,2$/? ($out2.=$h) : ($out1.=$h);
      }
      $out=&tag('select',$out1.$out2,'name=grp size=1');
      $out=&Center(&Table('table2',&RRow('row1','ll',$out,&submit_a('Далее &rarr;'))));
      $OUT.=&MessX(&form('!'=>1,"Выберите группу клиента, в которой собираетесь создать учетную запись:".$br3.$out));
      &Exit;
   }

   $paket3=int $F{paket3};
   $paket3=0 if !defined($Plans3{$paket3}) || $Plans3{$paket3}{usr_grp}!~/,$grp,/;
   $pakets3=join '',map {"<option value=$_".($paket3==$_ && ' selected').">$Plans3{$_}{name}</option>"}
      sort {$Plans3{$a}{name} cmp $Plans3{$b}{name}} keys %Plans3;
   $pakets3&&=&tag('select',"<option value=0>&nbsp;</option>$pakets3",'name=paket3 size=1');
}

%fileds=('mid'=>$mid,'grp'=>$grp,'paket'=>$paket,'paket3'=>$paket3);

$p=sql_select_line($dbh,"SELECT * FROM user_grp WHERE grp_id=$grp",'Данные клиентской группы');
if( $p )
{
   $grp_block_limit=$p->{grp_block_limit};
   $grp_nets=$p->{grp_nets};
   @nets=split /\n/,$grp_nets if $grp_nets;
}
 else
{
   $grp_block_limit=0;
   $grp_nets='';
   @nets=();
}

{# проверка пароля, ip
 $need_form=0;
 $ip_str='IP';

 $Ffio=&trim(defined $F{fio}? $F{fio} : $fio);

 $Fcontract_date=int $F{contract_date};
 $Fcontract_date=0 if $Fcontract_date<0 || $Fcontract_date>31;

 $Fpassnum=int $F{passnum};
 $Fpasswd=$Fpassnum>2? $F{passwd3} : $Fpassnum>1? $F{passwd2} : $Fpassnum>0? $F{passwd1} : $F{passwd0};
 if( defined $Fpasswd )
 {
    if( !$Fpasswd )
    {
       &Message('Пустой пароль не разрешен.','','Внимание');
       $need_form=1;
    }
     elsif( length($Fpasswd)<4 )
    {
       &Message('Рекомендуется для безопасности использовать пароли длинной не менее 4х символов.','','Предупреждение');
    }
 }

 $Fip=&trim($F{ip});
 unless (defined $F{ip})
 {
    $need_form=1;
    last;
 }

 if( $Fip!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ || $1>255 || $2>255 || $3>255 || $4>255 )
 {
    &Message($Fip? 'IP-адрес указан неверно.' : 'Не указан ip-адрес','','Внимание');
    $ip_str=&tag('span','IP','class=error');
    $need_form=1;
    last;
 }
 $sortip=$2*65536 + $3*256 + $4;

 if( $grp_nets && !&Check_Ip_in_Nets($Fip,@nets) )
 {
    &Message('IP не попадает в список разрешенных подсетей для данной группы.','','Внимание');
    $ip_str=&tag('span','IP','class=error');
    $need_form=1;
    last;
 }

 $p=&sql_select_line($dbh,"SELECT * FROM users WHERE ip='$Fip'",'Существует ли клиент с таким же ip?');
 if( $p )
 {
    &Message('Клиент с указанным ip уже зарегистрирован. Возможно пока вы вводили данные, указанный ip был занят.','','Внимание');
    $ip_str=&tag('span','IP','class=error');
    $need_form=1;
    last;
 }
}

{
 $need_form or last;

 $allow_nets='';
 if( $grp_nets )
 {
    &LoadNetMod;
    $first_ip='';
    foreach $net (split /\n/,$grp_nets)
    {
       ($h)=&nNet_GetNextIp($net);
       $first_ip||=$h;
       $allow_nets.=&RRow('*','ll',$net,!!$h && &ahref('#',$h,qq{OnClick="javascript:document.getElementById(1).value='$h'"}));
    }
    $allow_nets=&Table('tbg3',&RRow('tablebg','cc','Подсеть','Свободный ip').$allow_nets) if $allow_nets;
 }

 $i=0;
 $contact_sel='';
 foreach( ' (сегодня)',' (вчера)',' (позавчера)','','','','','','','' )
 {
    $contact_sel.="<option value=$i".($Fcontract_date==$i && ' selected').'>'.&the_date($t-86400*$i++)." $_</option>";
 }
 # формируем случайный пароль
 $rpass1=$rpass2='';
 $len=9+int(rand 3);
 for ($i=0; $i<$len; $i++) {$rpass1.=(0..9,'A'..'Z','a'..'z','@','.',',','-','=','%','$','(',')',':','_','?','+','#')[rand 76]}
 for ($i=0; $i<$len-3; $i++) {$rpass2.=(0..9,'A'..'Z','a'..'z')[rand 62]}

 $sth=&sql($dbh,"SELECT ip FROM users",'Получим список ip всех абонентов');
 $U{$_->{ip}}=1 while $_=$sth->fetchrow_hashref;

 $i=0;
 $out_lft=$h='';
 $old_region=0;
 $sth=&sql($dbh,"SELECT * FROM points,p_street WHERE points.street=p_street.street ORDER BY p_street.region,p_street.name_street,points.house",'Список улиц');
 while( $p=$sth->fetchrow_hashref )
 {
    ($street,$box,$house,$net,$region)=&Get_fields qw(
      street  box  house  net  region);
    $house.='('.&Filtr_out($p->{block}).')' if $p->{block};
    $nstreet=&Filtr_out($p->{name_street});
    if( $old_region!=$region )
    {
       $r=$Regions{$region};
       chop $r;
       $out_lft.=$h.&RRow('head','c',$r);
       $h='';
    }
    $old_region=$region;    
    $out_lft.="$h<tr class=row2><$td><a href='javascript:show_x($street)'>$nstreet</a></td></tr>".
        "<tr class=row1 id=my_x_$street style='display:none'><td><table class='tbg1 width100'>" if $i!=$street;
    $i=$street;
    $h||='</table></td></tr>';
    # попытаемся найти свободный ip
    $ip='';
    if( $net=~/^(\d+\.\d+\.\d+\.)(\d+)$/ && $2<254 )
    {
       $net=$1;
       for( $x=$2+1; $x<255; $x++ )
       {
          next if $U{"$net$x"};
          $ip="$net$x";
          last;
       }
    }else
    {
       $net='';
    }
    $out_lft.=&PRow."<td>Точка: <a href='$scrpt&a=map&bx=$box' target='_blank'>$box</a></td><td>Дом: <span class=data1>$house</span></td><td>Подсеть: ".($net? "<span class=data1>$net</span>" : "НЕИЗВЕСТНА").
        "</td><td>IP: ".($ip? qq{<a href='#' OnClick="javascript:document.getElementById(1).value='$ip'">$ip</a>} : 'нет вариантов')."</td></tr>";
 }
 $out_lft.=$h;

 $out=&div('message',&form('!'=>1,%fileds,&Table('tbg3',
   &RRow('*','ll ','ФИО клиента',&input_t('fio',$Ffio,36,255),'').
   &RRow('*','ll ','Дата заключения контракта',"<select name=contract_date size=1>$contact_sel</select>",'').
   &RRow('*','lll',$ip_str,&input_t('ip',$Fip || ($Auto_ip>0 && $first_ip),36,16,'id=1'),$allow_nets?
       '&nbsp;В группе клиента разрешается назначать ip адреса в таких диапазонах:'.$br2.$allow_nets :
       '&nbsp;Нет ограничений по диапазону адресов').
   &RRow('*','lll','Пароль',
       '<input type=radio name=passnum value=0> '.&input_t('passwd0',$Fpasswd,20,30).$br.
       '<input type=radio name=passnum value=1> '.&input_t('passwd1',$rpass1,20,30).$br.
       '<input type=radio name=passnum value=2'.(!$mid && ' checked').'> '.&input_t('passwd2',$rpass2,20,30).$origpasswd,
       'Введите пароль или выберите один из предложенных сгенерированных случайным образом').
   (!$mid && &RRow('*','lll',$Plan2_Title || 'Тарифный план',$pakets,'')).
   (!$mid && $pakets3 && &RRow('*','lll',$Plan3_Title || 'Дополнительный тарифный план',$pakets3,''))
   ).$br2.&submit_a('Далее &rarr;').$br));

 if( !$out_lft )
 {
    $OUT.=$out.$go_back;
    &Exit;
 }

 $OUT.=&Table('width100',
   &tag('tr',
      &tag('td',&Table('tbg width100',$out_lft),'valign=top width=36%').
      &tag('td',$out,'valign=top')
   )
 ).$go_back;
 &Exit;
}

$fileds{passwd0}=$Fpasswd;
$Fpasswd=&Filtr_mysql($Fpasswd);

$fileds{contract_date}=$Fcontract_date;
$Fcontract_date=$t-$Fcontract_date*86400;

$fileds{fio}=$Ffio;
$title="ФИО: ".&bold(&Filtr_out($Ffio) || 'не указаны').$br2;

$fileds{ip}=$Fip;

{# === Проверка логина
 if( $PR{120} )
 {  # логин не выбирает админ, присваивается автоматически
    $login=lc( &translit(&Filtr($Ffio)) ) || $Fip;
    $login=~s|^([^ ]+) +.*$|$1|; # оставим только фамилию
    $sth=&sql($dbh,"SELECT name FROM users WHERE name LIKE '$login%'");
    $L{lc($p->{name})}=1 while $p=$sth->fetchrow_hashref;
    if( $L{$login} )
    {  # найдем незанятый логин вида логин_число
       $i=1;
       $i++ while ( $L{"${login}_$i"} );
       $login.="_$i";
    }
    $Flogin=$login;
    last;
 }

 $Flogin=$F{login};
 defined $Flogin or last;
 $Flogin=&trim($Flogin);
 $Block_space_login && $Flogin=~s|\s||g && &Message('В логине убраны пробелы.','','Внимание');
 $login=&Filtr($Flogin);
 $Flogin ne $login && &Message("В логине убраны недопустимые символы. Новый логин: $login",'','Внимание');
 $Flogin='';
 if( length($login)<3 )
 {
    &Message('Логины менее 3х символов не разрешены.','','Внимание');
    last;
 }
 $p=&sql_select_line($dbh,"SELECT name FROM users WHERE name='$login'",'Существует ли клиент с таким же логином?');
 if( $p )
 {
    &Message("Уже существует клиент с логином ".&bold($login),'','Внимание');
    last;
 }
 $fileds{login}=$Flogin=$login;
}

sub push_login
{
 length($_[0])>2 && !(grep{$_ eq $_[0]} @logins) && push @logins,$_[0];
}

{# === Ввод логина
 $Flogin && last;
 @logins=();
 $h1=$h=lc( &Filtr($Ffio||$Fip) );
 if( $h1=~s/^([^ ]+) +([^ ]*).*$/$1_$2/ )
 {
    $h=$1;
    &push_login(&translit($h1));
    &push_login($h);
 }
 $h3=$h2=&translit($h);
 @logins,&push_login($h2);
 $h3=~s|[euioa]||g && &push_login($h3); # логин без гласных букв
 &push_login($h1);
 @f=$Block_space_login? ('_2','_pc2','_pc3','_comp_2','_comp_3','_notebook','_apoint','_router','_alias','_out_ip','.') :
   ('_2',' pc2',' pc3',' comp 2',' comp 3',' out ip','_pc2','_pc3','_notebook','_apoint','_router','_alias','_out_ip','.');
 push @logins,$h2.$_ foreach @f;
 $out="$title Выберите один из вариантов логина:".$br2.&input_t('login','',36,36,'id=1').$br2;
 foreach $login (@logins) 
 {
    %L=();
    $sth=&sql($dbh,"SELECT name FROM users WHERE name LIKE '$login%'");
    $L{&lc_rus(lc($p->{name}))}=1 while $p=$sth->fetchrow_hashref;
    $h=&lc_rus(lc($login));
    if( $L{$h} )
    {
       $i=0;
       $i++ while ($L{"$h$i"});
       $login="$login$i";
    } 
    $h=&Filtr_out($login);
    $out.=&ahref('#',$h,qq{OnClick="javascript:document.getElementById(1).value='$h'"}).$br;
 }
 $OUT.=&MessX(&form('!'=>1,%fileds,$out.$br.&submit_a('Далее &rarr;'))).$go_back;
 &Exit;
}

$balance=0;

# === Предустановленные подключения ===

{
 $newuser_opt=&sql_select_line($dbh,"SELECT * FROM newuser_opt WHERE opt_enabled>0 LIMIT 1",'Есть ли предустановленные подключения?');
 $newuser_opt or last;
 # в тарифе указано предустановленное подключение или его указал админ
 $Fopt=$mid? int $F{opt} : $Plan_newuser_opt[$paket] || int $F{opt};
 last if !$Fopt && defined($F{opt}) && $PR{118}; # админу разрешено не использовать предустановленные подключения

 {
  if( !$Fopt )
  {
     defined $F{opt} && &Message("Вы должны выбрать предустановленное подключение ниже",'','');
     last;
  }
  $p=&sql_select_line($dbh,"SELECT * FROM newuser_opt WHERE id=$Fopt AND opt_enabled>0");
  if( !$p )
  {
     $Plan_newuser_opt[$paket] && &Error("Ошибка в тарифном плане. Предустановленного подключения № $Fopt не существует. Обратитесь к главному администратору.",$go_back);
     &Message("Предустановленное подключение № $Fopt не существует либо неактивно. Выберите нужное в списке ниже",'','');
     $Fopt=0;
     last;
  }

  # Данные выбранного предустановленного подключения
  $fileds{opt}=$Fopt;
  ($id,$opt_time,$pay_sum,$pay_comment,$pay_reason,$opt_action,$opt_time)=&Get_fields('id','opt_time','pay_sum','pay_comment','pay_reason','opt_action','opt_time');
  $balance=$Fopt && $pay_sum? $pay_sum : 0;
  $pay_reason=~/^([^\$]*)\$(.*)$/ or last;
  # платеж "снятие за подключение" требует обязательного комментария со стороны админа
  unless( defined $F{reason} )
  {
     $OUT.=&MessX(
       &form('!'=>1,%fileds,
         "Для платежа снятия за подключение необходимо обязательно установить комментарий:".$br2.
         &Filtr_out($1).&input_t('reason','',50,50).&Filtr_out($2).$br2.&submit_a('Далее &rarr;')
       )
     ).$go_back;
     &Exit;
  }
 }

 $Fopt && last; # пред.подключение выбрано и оно существует
 # Список предустановленных подключений
 $url=$scrpt;
 $url.="&$_=".&URLEncode($fileds{$_}) foreach keys %fileds; # URLEncode нужен для символа '='
 $out='';
 # opt_enabled:
 #   0 - предустановленное подключение заблокировано
 #   1 - только для основной записи
 #   2 - только для алиасной записи
 $sth=&sql($dbh,"SELECT * FROM newuser_opt WHERE opt_enabled=".($mid? 2 : 1));
 while( $p=$sth->fetchrow_hashref )
 {
    ($id,$opt_time,$pay_sum)=&Get_fields('id','opt_time','pay_sum');
    ($opt_name,$opt_comment)=&Get_filtr_fields('opt_name','opt_comment');
    $out.=&RRow('*','lrl',&ahref("$url&opt=$id",$opt_name),$pay_sum||'&nbsp',$opt_comment);
 }
 $out.=&RRow('*','lll',&ahref("$url&opt=0",'Просто создать учетную запись'),'','') if $PR{118};

 $OUT.=&div('message',&Table('tbg3',&RRow('tablebg','ccc','Тип подключения',"Стоимость, $gr",'Условия').$out)).$go_back;
 &Exit;
}

$Ffio=&Filtr_mysql($Ffio);

$sql="INSERT INTO users SET ".
  "mid=$mid,".
  "ip='$Fip',sortip=$sortip,".
  "fio='$Ffio',".
  "passwd=AES_ENCRYPT('$Fpasswd','$Passwd_Key'),".
  "limit_balance=".($mid? 0 : $grp_block_limit).','.
  "block_if_limit=".($mid? 0 : 1).','.
  "grp=$grp,".
  "state='on',".
  "balance=0,".
  "auth='no',".
  "contract='',".
  "contract_date=$Fcontract_date,".
  "paket=$paket,".
  "paket3=$paket3,".
  "cstate=9,".
  "start_day=-1,".
  "modify_time=$ut,".
  "name='$login'";

$sth=$dbh->prepare($sql);
$sth->execute or &Error("Внутренняя ошибка. Учетная запись клиента не создана.",$go_back);
$id=$sth->{mysql_insertid} || $sth->{insertid};
$mId=$mid || $id; # id основной записи

$OUT.=$br;
&OkMess("Данные нового клиента внесены в базу данных.".$br3.&CenterA("$scrpt0&a=user&id=$id",'Редактировать данные'));
$OUT.=$br2;
&ToLog("$Admin_UU Создана клиентская учетная запись id=$id, ip: $Fip, логин: ".&commas($Flogin));

if( $balance )
{
   $rows=&sql_do($dbh,"UPDATE users SET balance=balance+($balance) WHERE id=$mId LIMIT 1");
   $rows<1 && &ToLog("! После создания учетной записи id=$id не удалось обновить баланс, необходима корректировка баланса клиента id=$mId");
}

&sql_do($dbh,"INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,time) ".
     "VALUES($mId,0,50,411,$Admin_id,INET_ATON('$ip'),$Admin_office,'ФИО: $Ffio, ip: $Fip',$ut)");

$tt="$ut+1";
if( $Fopt )
{
   $pay_comment=&Filtr_mysql($pay_comment);
   $pay_reason="$1$F{reason}$2" if $pay_reason=~/^([^\$]*)\$(.*)$/;
   $pay_reason=&Filtr_mysql($pay_reason);
   $category=$pay_sum>0? 10 : 100; # 100 - оплата подключения, 10 - бонус подключения
   $pay_sum && &sql_do($dbh,"INSERT INTO pays (mid,cash,type,bonus,category,admin_id,admin_ip,office,reason,coment,time) ".
      "VALUES($mId,$pay_sum,10,'y',$category,0,INET_ATON('$ip'),$Admin_office,'$pay_reason','$pay_comment',$tt)");
   if( $opt_action )
   {  # внесем в платежи `запланированное событие`
      $pay_sum && &sql_do($dbh,"INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,coment,time) ".
        "VALUES($mId,0,50,430,0,INET_ATON('$ip'),$Admin_office,'$opt_action:$opt_time','',$tt)");
   }
}

1;
