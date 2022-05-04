#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Fact=$F{act};

%subs=(
 'help'			=> \&sub_zero,	# вывод помощи из файла
 'searchmail'		=> \&sub_zero,	# поиск по email
 'print'		=> \&sub_zero,	# печать бланка с данными клиента
 'resolv'		=> \&sub_zero,	# обратный резолв
 'payagree'		=> \&sub_zero,	# принятие/отклонение денежного перевода
 'set_temp_block'	=> \&sub_zero,	# установить временное ограничение в просмотре групп
 'setmess'		=> \&check_adm,	# установить сообщение для администратора
 'setmessnow'		=> \&check_adm,	# непосредственно установить сообщение для администратора
 'dontshowmess'		=> \&sub_zero,	# удалить сообщение для админа от суперадмина
 'cardsail'		=> \&sub_zero,	# продажа карточек пополнения счета (не ваучеров)
 'cards_oper'		=> \&sub_zero,	# операции с карточками оплаты
 'cards_move_sel'	=> \&sub_zero,	# выбор администратора для передачи
 'cards_move_go'	=> \&sub_zero,	# непосредственная передача карточек
 'cards_move_agree'	=> \&sub_zero,	# подтверждение передачи карточек принимающим админом
 'cards_move_dont_agree' => \&sub_zero,	# отказ от приема карточек
 'cards_set_good'	=> \&sub_zero,	# перевод карточек в состояние "можно активировать без продажи"
);

&Exit unless defined $subs{$Fact};

&{ $subs{$Fact} };
&{$Fact}; 
&Exit;



# ==================================================
#	Установить сообщение для администратора
# ==================================================
sub check_adm
{# 30 и 31 - права на переключения на другую учетную запись
 &Error("У вас нет прав установки напоминающего сообщения для администратора.") if !$PR{30} && !$PR{31};
 $Fid=int $F{id};
 ($A,$Asort)=&Get_adms();
 &Error("У вас нет прав установки напоминающего сообщения для администратора (id=$Fid) в отделе отличном от вашего.") if !$PR{31} && $A->{$Fid}{office}!=$Admin_office;
 $A->{$Fid}{login} or &Error("Администратор с id=$Fid не существует.");
}

sub setmess
{
 $OUT.=$br.&MessX(
   &form('!'=>1,'act'=>'setmessnow','id'=>$Fid,
     "Установить напоминающее сообщение для администратора $A->{$Fid}{admin}:".$br2.
     &div('cntr','<textarea rows=6 cols=40 name=mess>'.$A->{$Fid}{mess}.'</textarea>'.$br2).
     &submit_a('Установить').$br2.
     "Администратор после ознакомления с сообщением, может его самостоятельно удалить."
   )
 );
}

sub setmessnow
{
 $Fmess=&Filtr_mysql(&trim($F{mess}));
 $rows=&sql_do($dbh,"UPDATE admin SET mess='$Fmess' WHERE id=$Fid LIMIT 1");
 $rows<1 && &Error("Произошла ошибка sql-запроса при установке напоминающего сообщения для администратора.");
 &OkMess("Напоминающее сообщение для администратора $A->{$Fid}{admin} установлено.");
}

sub dontshowmess
{
 $rows=&sql_do($dbh,"UPDATE admin SET mess='' WHERE id=$Admin_id LIMIT 1",'Удаление сообщения от другого администратора');
 $rows<1 && &Error("Временная ошибка. Повторите запрос позже.$go_back");
 &OkMess("Сообщение, оставленное вам, удалено. Через 10 секунд произойдет переход на титульную страницу админки.");
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="10; url='$scrpt0&a='">};
}

# ==================================================
# Установка временного ограничения в просмотре групп
# ==================================================
sub set_temp_block
{
 $temp_block=',';
 foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
   {
    $temp_block.="$g," if $F{"g$g"}; # проверять есть ли доступ к группе не надо - пусть ограничивает доступ к недоступной группе
   }
 $temp_block='' if $temp_block eq ',';
 &sql_do($dbh,"UPDATE admin SET temp_block_grp='$temp_block' WHERE id=$Admin_id LIMIT 1");
 &OkMess("Ограничения на просмотр групп установлены.".$br2.&CenterA("$scrpt0&a=main",'Далее &rarr;'));
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="10; url='$scrpt0&a=listuser'">};
}

# =========================
#	Поиск по email
# =========================
sub searchmail
{
 $mail_enable or &Error('Работа с почтовыми ящиками отключена.');
 $PR{93} or &Error('Работа с почтовыми ящиками вам запрещена.');
 $OUT.=&div('message','Предупреждение: будут показаны только те email, которые принадлежат клиентам в доступных вам группах.') unless $pr_SuperAdmin;
 
 $sth=&sql($dbh,"SELECT * FROM users");
 while ($p=$sth->fetchrow_hashref)
   {
    $id=$p->{id};
    $U{$id}{name}=$p->{name};
    $U{$id}{grp}=$p->{grp};
   }
 
 $dbh2=DBI->connect("DBI:mysql:database=$mail_db;host=$mail_host;mysql_connect_timeout=3",$mail_user,$mail_pass);
 $dbh2 or &Error('Ошибка соединения с почтовой базой данных.');
 &SetCharSet($dbh2);

 $out='';
 $sth2=&sql($dbh2,"SELECT * FROM `$mail_table` WHERE `$mail_p_email` LIKE '%".&Filtr_mysql($F{email})."%' ORDER BY `$mail_p_user`");
 while ($p=$sth2->fetchrow_hashref)
   {
    $id=int $p->{$mail_p_user};
    next if !$UGrp_allow{$U{$id}{grp}} && !$pr_SuperAdmin; # суперадмину можно показывать и отсутствующие в базе записи (неопределенность $UGrp_allow{})
    $out.=&RRow('*','ll',
      defined($U{$id}{name}) && &ahref("$scrpt0&a=user&act=showmail&id=$id",&Filtr_out($U{$id}{name})),
      &Filtr_out($p->{$mail_p_email})
    )
   }
 $out or &Error('По заданным условиям поиска не найдено ни одного email.');
 
 $OUT.=&Table('tbg3',
   &RRow('head','C',&bold_br('Поиск по email')).
   &RRow('*','cc','Клиент','Email').
   $out);
}

# ===============================
#     Обратный резолв ip
# ===============================
sub resolv
{
 $host=gethostbyaddr(inet_aton($F{ip}),AF_INET);
 $host=$host || 'адрес неизвестен';
 $Fip_id=int $F{ip_id};
 $out="Content-type: text/html\n\n".
   "<html><head><title>$Title_net - обратный резолв</title>".
    "<meta http-equiv='Cache-Control' content='no-cache'><meta http-equiv='Pragma' content='no-cache'>".
    "<body>Обратный резолв $F{ip}".$br2."Результат: <b>$host</b>".
      "<script language='JavaScript'>\n".
        "opener.document.all['f$Fip_id'].innerHTML='$host ($F{ip})';\n".
        "self.close()\n".
      "</script>".
   "</body></html>";
 print $out;
 exit;
}  

# ===============================
# Печать бланка с данными клиента
# ===============================
sub print
{
 $PR{61} or &Error("Нет прав."); # просмотр паролей
 $Fid=int $F{id};
 $p=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM fullusers WHERE id=$Fid LIMIT 1");
 $p or &Error("Ошибка получения данных клиента с id=$Fid.");
 $grp=$p->{grp};
 $grp_allow=$UGrp_allow{$grp};
 $grp_allow or &Error("Клиент находится в группе, доступ к которой вам запрещен. Бланк настроек недоступен.");
 ($fio,$comment,$contract,$contract_date)=&Get_filtr_fields qw(
   fio  comment  contract  contract_date);

 &LoadDopdataMod();
 $out_adr='';
 $sth=&sql($dbh,"SELECT * FROM dopdata WHERE parent_id=$Fid AND template_num=(SELECT template_num FROM dopfields WHERE parent_type=0 AND field_alias LIKE '_adr%' LIMIT 1) ORDER BY field_name");
 while( $h=$sth->fetchrow_hashref )
 {
    $name=$h->{field_name};
    $name=~s|^\[\d+\]\s*||;
    $value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $h->{field_type},
          alias	=> $h->{field_alias},
          value	=> $h->{field_value}
       })
     );
   $value=~s|\n|<br>|g if $h->{field_type}==5; # строковое многострочное
   $out_adr.=&RRow('*','ll',&Filtr_out($name),&bold($value));
 }

 $out='';
 $out.=&RRow('','ll',$br.'ФИО'.$br2,$fio ne ''? &bold($fio) : 'не указаны') if $pr_show_fio;
 $out.=&RRow('','ll','Договор',($contract ne ''? &bold($contract) : 'не указан').(!!$contract_date && ' ('.&the_date($contract_date).')'));
 $out.=$out_adr && &RRow('','C','Адрес подключения:').$out_adr;

 $ipp=&Filtr_out($p->{ip});
 $ipp=~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
 $ip_raw=pack('CCCC',$1,$2,$3,$4);

 $gate=$dns=$mask='';
 foreach $i (@cl_nets)
 {
    ($net,$tgate,@dns)=split /\s+/,$i;
    $net=~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ or next;
    $net_mask=$5;
    $net_raw=pack('CCCC',$1,$2,$3,$4);
    $net_mask_raw=pack('B32',1 x $net_mask,0 x (32-$net_mask));
    $net_raw&=$net_mask_raw;
    next if ($ip_raw & $net_mask_raw) ne $net_raw;
    # нашли запись. вычислим шлюз
    if ($tgate=~/^\d+$/ && $tgate>0 && $tgate<32)
    {
       $net_mask_raw=pack('B32',1 x $tgate,0 x (32-$tgate));
       $gate_raw=($ip_raw & $net_mask_raw) | pack('CCCC',0,0,0,1);
       $tgate=join(".",unpack("C4",$gate_raw));
    }
    $mask=join(".",unpack("C4",$net_mask_raw));
    $gate=$tgate;
    $dns.=$_.$br foreach (@dns);
    last;
 }

 $pass=&Filtr_out($p->{"AES_DECRYPT(passwd,'$Passwd_Key')"});
 $name=&Filtr_out($p->{name}) || '&nbsp';

 $h2.=&RRow('','L','');
 $p=&sql_select_line($dbh,"SELECT * FROM user_grp WHERE grp_id=$grp");
 if ($p && $pr_show_fio && $grp_allow>1)
 {
    $grp_blank_mess=$p->{grp_blank_mess};
    $grp_blank_mess="Настройки авторизации:\nЛогин|\$l\nПароль|\$p" if $grp_blank_mess=~/^\s*$/;
    foreach $i (split/\n/,$grp_blank_mess)
    {
       $i=~s|\$p|$pass|;
       $i=~s|\$l|$name|;
       $i=~s|\$i|$ipp|;
       $i=~s|\$d|$dns|;
       $i=~s|\$g|$gate|;
       $i=~s|\$m|$mask|;
       $h2.=($i=~/(.*)\|(.*)/)? &RRow('','ll',$1,&bold($2)) : &RRow('','C',$i);
    }
 }

 $body="<div align=center><br><table width=528>$out$h2</table>$br2$br3<div id=nav>".
    &ahref("javascript:history.go(-1)",'назад').'&nbsp;&nbsp;&nbsp;'.
    &ahref(qq{javascript:document.getElementById("nav").style.display="none"; document.execCommand("Print"); history.go(-1)},'печать').
    "</div>";   

 $OUT="Content-type: text/html\n\n<html><head><title>$Title_net</title>".
    "<meta http-equiv='cache-control' content='no-cache'><meta http-equiv='pragma' content='no-cache'>".
    "<meta http-equiv='Content-Type' content='text/html; charset=windows-1251'>\n".
    "<style type='text/css'>\n".
    "body {background:#fff; margin:0px; padding:0px;}\n".
    "table {border:double black; padding:5px; border-collapse:collapse}\n".
    "table td {border:1px solid #a0a0a0; padding:4px}\n".
    "</style>\n".
   "<body>$body</body></html>";
 print $OUT;
 exit;
}  

# =======================================================
# Подтверждение/отказ от передачи наличным между админами
# =======================================================
sub payagree
{
 # обязательно проверяем все поля! 
 $Fid=int $F{id};
 $Fcash=$F{cash}+0;
 $h=(!$F{yes} && 'отказа от ')."подтверждения перевода суммы $Fcash $gr";
 $url=&ahref("$scrpt0&a=payshow&nodeny=admin&bonus=y&year=$year_now&mon=$mon_now&admin=$Admin_id",'платежи');
 $yes=$F{yes}? 408 : 409; # категории платежей соответственно для подтвержденных и нет

 $rows=&sql_do($dbh,"UPDATE pays SET category=$yes WHERE id=$Fid AND mid=0 AND type=40 AND category=470 AND coment='$Admin_id' AND cash=$Fcash LIMIT 1");
 &Error("Операция $h не выполнена. Возможные причины:$br2<ul>".
   "<li>Вы уже выполнили данное действие и повторно послали запрос.</li>".
   "<li>Пока вы посылали запрос, другой администратор отменил передачу либо изменил сумму перевода.</li>".
   "</ul>Для уточнения ситуации зайдите в раздел $url") if $rows<1;
 &OkMess("Операция $h выполнена успешно. Ваши $url");
 &ToLog("$Admin_UU Операция $h выполнена успешно. Id записи в таблице платежей: $Fid");
}

# ===============================================
# Продажа карточек пополнения счета (не ваучеров)
# ===============================================
sub cardsail
{
 $main_href=$br2.&ahref("$scrpt0&a=main",'Перейти на страницу '.&commas('операции'));
 $FcardId=int $F{cardid};
 $F{cardid}=&Filtr_out($F{cardid});
 $copy_to_buf=qq{ <span onClick='window.clipboardData.setData("Text","$F{cardid}")' class=data2 style='cursor:pointer;border:0;'>(скопировать в буфер обмена)</span>};
 $sn='Карточка пополнения с серийным номером '.&bold($FcardId).$copy_to_buf;
 $your_pays=&ahref("$scrpt0&a=payshow&nodeny=admin&admin=$Admin_id",'Смотрите свои платежи');
 &Error("Карточка пополнения не продана т.к вы указали неверный серийный номер ".&bold($F{cardid})."$copy_to_buf, который должен быть больше 0.$main_href") if $FcardId<=0;

 $p=&sql_select_line($dbh,"SELECT * FROM cards WHERE cid=$FcardId LIMIT 1");
 &Error("$sn не существует. Вероятно вы ошиблись при вводе номера.$main_href") unless $p;

 ($admin_sell,$time_sell,$r,$alive,$cash)=&Get_fields('admin_sell','time_sell','r','alive','money');

 &Error("$sn не может быть продана т.к она числится на складе. Обратитесь к администратору, который оформляет передачи карточек.$main_href") unless $r;
 &Error("$sn не может быть продана т.к. в базе данных логическое несоответствие: карточка числится у вас на руках, при этом она же числится проданной. ".
   "Обратитесь к главному администратору для разрешения данной проблемы.$main_href") if $r==$Admin_id && $admin_sell>0;
 &Error("$sn была продана ".&the_short_time($time_sell,$t).". $your_pays, возможно вы продублировали запрос.$main_href") if $admin_sell==$Admin_id;
 &Error("$sn не может быть продана т.к она оформлена в виде ваучера.$main_href") if $r<0 && !$admin_sell;
 &Error("$sn была передана на реализацию не вам!$main_href") if $r!=$Admin_id;
 &Error("$sn числится заблокированной. Необходимо вернуть на склад. $main_href") if $alive eq 'bad';
 &Error("$sn помечена для передачи другому администратору. Продажа карточки не может быть осуществлена пока принимающий админ не откажется от подтверждения приема карточки. $main_href") if $alive eq 'move';
 &Error("$sn числится активированной! Продажа заблокирована. $main_href") if $alive ne 'good' && $alive ne 'stock';

 $sth=$dbh->prepare("INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
     "VALUES(0,$cash,10,$Admin_id,INET_ATON('$ip'),$Admin_office,'','карточка пополнения $FcardId','',299,unix_timestamp())");
 if (!$sth->execute || !($pay_id=$sth->{mysql_insertid}) || !$pay_id)
   {
    &Error("Ошибка при создании платежа реализации карты пополнения счета. $your_pays и убедитесь, что нет записи о реализации карточки с сериныйм номером $FcardId. ".
     " Если запись будет присутствовать - отложите данную карточку и обратитесь к главному администратору для разрешения этой ситуации.$main_href");
   } 
 $rows=&sql_do($dbh,"UPDATE cards SET id_sell=$pay_id,admin_sell=$Admin_id,r=-2,alive='good',time_sell=unix_timestamp() WHERE cid=$FcardId AND r=$Admin_id LIMIT 1");
 &Error("Внутрення ошибка сервера. Карточка не продана, однако проводка о ее продаже оформлена. Обратитесь к главному администратору для удаления этой проводки, ".
   "в противном случае вы будете должны сумму, равную номиналу карточки.$main_href") if $rows!=1;
 &OkMess("$sn номиналом ".&bold($cash)." продана успешно.$main_href");
}

# ===============================================
#    Операции с карточками пополнения счета
# ===============================================

sub cards_chk_free
{
 $p=&sql_select_line($dbh,"SELECT COUNT(*) FROM cards WHERE r=$Admin_id");
 &Error('У вас '.&commas('на руках').' нет ни одной карточки. Если это не так - возможно вам были переданы карточки без оформления самой передачи. '.
    'Обратитесь к администратору, который передал вам карточки, чтоб он оформил это в биллинге.') if !$p || !$p->{'COUNT(*)'};
}

sub show_cid
{
 my ($start_cid,$len,$money,$alive)=@_;
 my $end_cid=$start_cid+$len-1;
 my $comment=$alives{$alive}? $alives{$alive}.'. '.&ahref("$scrpt&act=help&theme=cards_$alive",'[?]') : 'активированы';
 return &RRow('*','llllcc',$money,"$start_cid .. $end_cid",$len,$comment,
     $alive=~/^(good|stock|bad)$/? &div('nav3',&ahref("$scrpt&act=cards_move_sel&n1=$start_cid&n2=$end_cid",'Да')) : '&nbsp;',
     $PR{111} && $alive eq 'stock'? &div('nav3',&ahref("$scrpt&act=cards_set_good&n1=$start_cid&n2=$end_cid",'Да')) : '&nbsp;');
}


sub cards_oper
{
 &cards_chk_free;
 %alives=(
  'move' => 'Направлены другому админу, ожидается подтверждение',
  'bad' => '<span class=error>заблокированы</span>',
  'stock' => 'можно активировать после продажи',
  'good' =>  'можно активировать',
 );

 $i=$last_alive=$last_money=$start_cid=0;
 $out='';
 $sth=&sql($dbh,"SELECT cid,money,alive FROM cards WHERE r=$Admin_id ORDER BY cid");
 while ($p=$sth->fetchrow_hashref)
   {
    ($cid,$money,$alive)=&Get_fields('cid','money','alive');
     $start_cid||=$cid;
     $last_money||=$money;
     $alive=1 if int($alive)>0;
     $last_alive||=$alive;
     next if $cid==($start_cid+$i) && $money==$last_money && $last_alive eq $alive;
     $out.=&show_cid($start_cid,$i,$last_money,$last_alive);
     $last_money=$money;
     $last_alive=$alive;
     $start_cid=$cid;
     $i=0;
    }
     continue
    {
     $i++;
    }
     
 $out.=&show_cid($start_cid,$i,$money,$last_alive) if $start_cid;
 $out=&MessX('Карточки пополнения счета, которые числятся за вами:').'<br>'.
     &Table('tbg3',&RRow('head','cccccc',"Номинал, $gr",'Диапазон','Штук','Комментарий','Передать',$PR{111}?'Разрешить<br>активацию':'&nbsp;').$out) if $out;

 $OUT.=&div('message',$out.
   &form('!'=>1,'act'=>'cards_move_sel','<br>'.
     &Table('tbg3 nav2',&RRow('head','C',&bold('Передача карточек пополнения счета другому администратору')).
     &RRow('*','ll','Начальный номер диапазона',&input_t('n1','',20,22)).
     &RRow('*','ll','Конечный номер диапазона',&input_t('n2','',20,22)).
     &RRow('*','C','<br>'.&submit_a('Далее &rarr;').'<br>'))
   )
 );
}


sub cards_get_info
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $n1>$n2 && &Error("Начальный номер карточки $n1 больше конечного $n2. Передача карточек не выполнена.");
 $err_mess='Передача карточек не выполнена - временная ошибка. Попробуйте позже.';
 $mess1="В указанном диапазоне серийных номеров $n1 .. $n2";
 $mess2='';
 $n=$n2-$n1+1;
 $out='';
 $out.=&RRow('*','ll','Начальный номер',$n1);
 $out.=&RRow('*','ll','Конечный номер',$n2);

 $sql="SELECT COUNT(*) FROM cards WHERE cid>=$n1 AND cid<=$n2";

 $p=&sql_select_line($dbh,$sql);
 $p or &Error($err_mess);
 $all_cards=$p->{'COUNT(*)'};
 $all_cards or &Error("$mess1 нет ни одной карточки. Проверьте правильно ли вы указали диапазон.");

 # не указываем сколько именно чтоб любопытные админы не могли вычислить сколько карточек всего в биллинге
 $mess2.="<li>$mess1 всего возможно $n карточек, однако реально существующих меньше.</li>" if $all_cards!=$n; 

 $sql.=" AND r=$Admin_id";
 $p=&sql_select_line($dbh,$sql);
 $p or &Error($err_mess);
 $your_cards=$p->{'COUNT(*)'};
 $your_cards or &Error("$mess1 нет ни одной карточки, которая числилась бы за вами. Возможно на вас не была оформлена передача либо вы ошиблись при вводе диапазона серийных номеров.");

 $p=&sql_select_line($dbh,"$sql AND admin_sell<>0");
 $p or &Error($err_mess);
 &Error('Передача карточек не выполнена т.к имеются логические несоответствия в базе данных: '.$p->{'COUNT(*)'}.
   " карточек числятся у вас на руках и при этом они же числятся как проданные. Этот вопрос может разрешить только главный администратор.") if $p->{'COUNT(*)'}>0;

 $i=0;
 $sth=&sql($dbh,"SELECT COUNT(*),money FROM cards WHERE cid>=$n1 AND cid<=$n2 AND r=$Admin_id GROUP BY money");
 while ($p=$sth->fetchrow_hashref)
  {# +0 убирает точку-разделитель, если номинал целое число
   $out.=&RRow('*','rl',($p->{money}+0)." $gr",$p->{'COUNT(*)'}.' шт');
   $i++;
  }
 $mess2.='<li>В выбранном диапазоне больше одного номинала карточек</li>' if $i>1;
 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive='move'");
 $p or &Error($err_mess);
 $move_cards=$p->{'COUNT(*)'};
 $out.=&RRow('*','ll','Уже помечены для передачи другому администратору',$move_cards) if $move_cards>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive='bad'");
 $p or &Error($err_mess);
 $out.=&RRow('*','ll','В заблокированном состоянии',$p->{'COUNT(*)'}) if $p->{'COUNT(*)'}>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive NOT IN ('good','stock','move','bad')");
 $p or &Error($err_mess);
 $out.=&RRow('*','ll','Активировано клиентами',$p->{'COUNT(*)'}) if $p->{'COUNT(*)'}>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive IN ('good','bad','stock')");
 $p or &Error($err_mess);

 $moveable_cards=$p->{'COUNT(*)'};
 $out.=&RRow('*','ll','Будут переданы другому администратору, шт',&bold($moveable_cards));

 $mess2.="<li>В указанном диапазоне есть карточки, которые не будут переданы другому администратору.</li>" if $moveable_cards!=$all_cards;
 
 $mess2 && &ErrorMess("<ul>$mess2</ul>");

 $OUT.=&Table('tbg3',&RRow('head','C',&bold('Информация по передаваемому диапазону карточек')).$out).$br;
 ($A,$Asort)=&Get_adms();
}

sub cards_move_sel
{
 &cards_chk_free;
 &cards_get_info;
 $office=-1;
 $out='';
 foreach $id (@$Asort)
   {
    next if !$PR{26} && $A->{$id}{office}!=$Admin_office;
    $apriv=$A->{$id}{privil};
    next if $apriv!~/,116,/; # на этого админа нельзя осуществлять передачи
    $o=$A->{$id}{office};
    $out.=&RRow('tablebg','3','Отдел '.&bold($Offices{$o}||"№ $o")) if $o!=$office;
    $office=$o;
    $comment=$apriv=~/,300,/? '' : '<span class=disabled>должен будет подтвердить прием</span><br>';
    $comment.='Карточки будут переведены в состояние '.&commas('можно активировать') if $apriv=~/,301,/;
    $out.=&RRow('*','lll',&ahref("$scrpt&act=cards_move_go&n1=$n1&n2=$n2&id=$id",$A->{$id}{login}),$A->{$id}{name},$comment);
   }
 $OUT.=$out? &Table('tbg3 nav3',&RRow('head','3','Выберите администратора, которому собираетесь передать карточки пополнения счета').$out):
   &error('Внимание.','Нет ни одного администратора, на которого вы можете оформить передачу карточек.');
 $OUT.=$go_back;
}

sub cards_move_go
{
 &cards_get_info;
 $Fid=int $F{id};
 $Fid<=0 && &Error("Передача карточек не выполнена т.к. указан неверный id администратора на которого была запрошена передача.");
 &Error("Передача карточек не выполнена т.к. администратор, которому вы передаете карточки, работает в другом отделе. ".
   "У вас нет доступа к другим отделам.") if !$PR{26} && $A->{$Fid}{office}!=$Admin_office;
 $apriv=$A->{$Fid}{privil};
 $apriv=~/,116,/ or &Error("Передача карточек не выполнена т.к. администратор, которому вы передаете карточки, не имеет прав на их прием.");
 $where="WHERE r=$Admin_id AND cid>=$n1 AND cid<=$n2";

 if ($apriv=~/,300,/)
   {# не требуется подтверждение передачи. Установить признак "можно активировать"?
    $alive=$apriv=~/,301,/? 'good':'stock';
    $sql="UPDATE cards SET alive='$alive',r=$Fid $where AND alive IN ('good','stock')";
    $rows=&sql_do($dbh,$sql);
    $rows=0 if $rows<0;
    $sql="UPDATE cards SET r=$Fid $where AND alive='bad')"; 
    $rows+=&sql_do($dbh,$sql);
    $mess1='. Подтверждение не требуется';
    $mess2='Подтверждение принимающим админом не требуется.';
   }else
   {
    $sql="UPDATE cards SET alive='move',rand_id=$Fid $where AND alive IN ('good','bad','stock')"; 
    $rows=&sql_do($dbh,$sql);
    $mess1='';
    $mess2='Внимание. Окончательная передача карточек будет осуществлена только после подтверждения передачи принимающим администратором';
   } 
 $rows<1 && &Error("Передача карточек не выполнена. Попробуйте запрос позже.");

 # категория 415 - "перемещение карточек оплаты"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
          "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','Передано $rows карточек $n1 .. $n2 на админа id=$Fid$mess1','',415,unix_timestamp())");
 &OkMess("На администратора $A->{$Fid}{admin} передано $rows карточек. $mess2");
}

sub cards_move_agree
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $n1>$n2 && &Error("Начальный номер карточки $n1 больше конечного $n2. Подтверждение передачи карточек не выполнено.");
 $rows=&sql_do($dbh,"UPDATE cards SET r=$Admin_id,rand_id=0,alive='stock' WHERE rand_id='$Admin_id' AND alive='move' AND cid>=$n1 AND cid<=$n2");
 $rows<1 && &Error("Подтверждение передачи карточек не выполнено. Попробуйте запрос позже.");
 # категория 415 - "перемещение карточек оплаты"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
    "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','Подтвержден прием $rows карточек $n1 .. $n2','',415,$ut)");
 &OkMess("Вы подтвердили прием карточек в количестве $rows штук диапазона $n1 .. $n2.");
}

sub cards_move_dont_agree
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 &Error("Начальный номер карточки $n1 больше конечного $n2. Действие отменено.") if $n1>$n2;
 $rows=&sql_do($dbh,"UPDATE cards SET rand_id=r WHERE rand_id='$Admin_id' AND alive='move' AND cid>=$n1 AND cid<=$n2");
 &Error('Отказ от приема карточек не выполнен. Попробуйте запрос позже.') if $rows<1;
 # категория 415 - "перемещение карточек оплаты"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
          "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','Отказ от приема $rows карточек $n1 .. $n2','',415,unix_timestamp())");
 &OkMess("Вы отказались принимать карточки в количестве $rows штук диапазона $n1 .. $n2.");
}

sub cards_set_good
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $s=&commas('разрешена активация без продажи');
 &Error("Начальный номер карточки $n1 больше конечного $n2. Никакие изменения не произведены.") if $n1>$n2;
 $rows=&sql_do($dbh,"UPDATE cards SET r=$Admin_id,alive='good' WHERE r='$Admin_id' AND alive='stock' AND cid>=$n1 AND cid<=$n2");
 &Error("Перевод карточек в состояние $s не выполнен, вероятно в диапазоне серийных номеров $n1 .. $n2 нет ни одной карточки в состоянии ".&commas('можно активировать без продажи')) if $rows<1;
 # категория 415 - "перемещение карточек оплаты"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
    "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','Переведено $rows карточек $n1 .. $n2 в состоягие \"разрешена активация без продажи\"','',415,unix_timestamp())");
 &OkMess("Карточки в количестве $rows штук диапазона $n1 .. $n2 переведены в состояние $s.");
}

# ========================
sub help
{
 $go_back=&Center(&div('nav',$go_back));
 $theme=$F{theme};
 &Error("Справка недоступна - неверно указана тема.$go_back") if $theme=~/[^A-Za-z0-9_]/ || !$theme;
 $fname="$Nodeny_dir_web/help.txt";
 open(FL,$fname) or &Error(($pr_SuperAdmin? "Справка недоступна - не могу открыть файл $fname." : 'Нет справки по заданной теме').$go_back);
 @list=<FL>;
 close(FL);
 "@list"=~/~$theme([^~]+)/ or &Error("Справка по указанной теме отсутствует.$go_back");
 &OkMess('<span class=big>Справка:</span>'.$br2.$1.$go_back);
}

1;
