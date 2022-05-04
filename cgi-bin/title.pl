#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$DOC->{admin_area}="mysql: ".$dbh->{mysql_stat}.$br.$DOC->{admin_area} if $Ashowsql;

$OUT.=&div('infomess',&Show_all($p_adm->{mess}).$br2.&CenterA("$scrpt0&a=operations&act=dontshowmess",'Не напоминать')) if $p_adm->{mess}!~/^\s*$/;
$OUT.=&div( 'row2',&Printf('[br]Здравствуйте, [filtr|bold][br2]',$Aname || 'администратор') );

$ul='';
sub li { &tag('li',$_[0].$br2) }

$Admin_id && (!$PR{108} || $pr_RealSuperAdmin) && do{ $ul.=&li(&ahref("$scrpt0&a=mytune",'Ваши настройки')) };
$Admin_id or do{ $ul.=&li('Вы зашли под логином, который применяется исключительно для настройки и создания других логинов. '.&ahref("$scrpt0&a=main",'Далее &rarr;')) };

$ENV{SERVER_PORT} && !$ENV{HTTPS} && do{ $ul.=&li(&Printf('[span error] []','Предупреждение:','вы НЕ работаете по защищенному протоколу https.')) };
$pr_SuperAdmin && (-e 'listuser.pl') && do{ $ul.=&li(&Printf('[span error] []','Предупреждение:','обнаружено, что в cgi-bin папке присутствуют скрипты, которые там не должны быть. '.
   "Теперь web-скрипты находятся в $Nodeny_dir_web, а в cgi-bin только 2 файла: adm.pl и stat.pl. Удалите все лишние файлы.")) };

# --- Неподтвержденные передачи наличности на текущего админа ---

$out='';
$sth=&sql($dbh,"SELECT p.id,p.cash,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.reason ".
   "WHERE p.mid=0 AND p.type=40 AND p.category=470 AND p.coment='$Admin_id' ORDER BY p.time DESC",
   'Неподвержденные передачи наличности');
while( $p=$sth->fetchrow_hashref )
{
   ($id,$cash,$tt,$admin,$name)=&Get_filtr_fields('id','cash','time','admin','name');
   # в урле наличность для того, чтобы в момент подтверждения была гарантия, что наличность не отредактировали между отображением и нажатием ссылки
   $url="$scrpt0&a=operations&act=payagree&id=$id&cash=$cash";
   $out.=&RRow('*','rrrcc',
      &the_short_time($tt,$t),
      &bold($admin).($name && " ($name)"),
      $cash,
      &ahref("$url&yes=1",'Да'),
      &ahref($url,'Нет')
   );
}

$ul.=&li('Неподтвержденные передачи наличных'.$br2.
  &Table('nav2 tbg3',&RRow('tablebg','cccC','Дата','От администратора',"Сумма, $gr",'Подтвердить?').$out).$br2
) if $out;


# --- Непринятые передачи наличности ---
$out='';
$sql=$pr_SuperAdmin? '' : "AND p.coment='$Admin_id'"; # Если суперадмин, то покажем все, иначе только текущего админа
$sth=&sql($dbh,"SELECT p.id,p.cash,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.reason ".
   "WHERE p.mid=0 AND p.type=40 AND p.category=409 $sql ORDER BY p.time DESC",'Отклоненные передачи наличности');
while ($p=$sth->fetchrow_hashref)
{
   ($id,$cash,$tt,$admin,$name)=&Get_filtr_fields('id','cash','time','admin','name');
   $out.=&RRow('*','rrrc',
     &the_short_time($tt,$t),
     &bold($admin).($name && " ($name)"),
     $cash,
     &ahref("$scrpt0&a=pays&act=show&id=$id",'детальнее &rarr;')
   );
}

$ul.=&li(&bold($pr_SuperAdmin? 'Отклоненные передачи наличности' : 'Вами отклонены следующие передачи наличных.<br>Проследите, чтобы главный администратор удалил их').$br2.
  &Table('nav2 tbg3',&RRow('tablebg','cccc','Дата','От администратора',"Сумма, $gr",'Детали платежа').$out)
) if $out;


# === Есть ли неподтвержденные передачи карточек пополнения счета ===
sub show_cid
{
 my ($start_cid,$len,$money,$admin)=@_;
 my $end_cid=$start_cid+$len-1;
 my $yes=&ahref("$scrpt&a=operations&act=cards_move_agree&n1=$start_cid&n2=$end_cid",'Да');
 my $no=$admin!=$Admin_id? &ahref("$scrpt&a=operations&act=cards_move_dont_agree&n1=$start_cid&n2=$end_cid",'НЕТ') : '&nbsp;';
 $admin=$admin!=$Admin_id? $A->{$admin}{admin} : '<span class=error>Возврат карточек! Принимающий админ отказался от приема.</span>';
 return &RRow('*','ccclcc',$money,"$start_cid .. $end_cid",$len,$admin,$yes,$no);
}

$p=&sql_select_line($dbh,"SELECT COUNT(*) FROM cards WHERE rand_id='$Admin_id' AND alive='move'",'Неподтвержденные передачи карточек пополнения счета:');
{
 next if !$p || $p->{'COUNT(*)'}<1;
 ($A)=&Get_adms;
 $i=$last_r=$last_money=$start_cid=$cards=0;
 $out='';
 $sth=&sql($dbh,"SELECT cid,money,r FROM cards WHERE rand_id='$Admin_id' AND alive='move' ORDER BY cid");
 while ($p=$sth->fetchrow_hashref)
 {
    $cards++;
    ($cid,$money,$r)=&Get_fields('cid','money','r');
    $start_cid||=$cid;
    $last_money||=$money;
    $last_r||=$r;
    next if $cid==($start_cid+$i) && $money==$last_money && $r==$last_r;
    $out.=&show_cid($start_cid,$i,$last_money,$r);
    $last_money=$money;
    $last_r=$r;
    $start_cid=$cid;
    $i=0;
 }
  continue
 {
    $i++;
 }
 $out.=&show_cid($start_cid,$i,$last_money,$r) if $start_cid;
 $ul.=&li("В текущий момент на вас оформлены передачи карточек пополнения счета в количестве $cards штук. Подтвердите передачи если вы действительно приняли эти карточки. ".
    'Если есть хотя бы одна карточка, которую вы не приняли, не подтверждайте передачу! В этом случае обратитесь к главному администратору для разрешения данной ситуации.'.$br2.
    &Table('tbg3 nav2',&RRow('tablebg','ccccC',"Номинал, $gr",'Диапазон','Кол-во','Админ от которого передаются карточки','Подтверждение').$out)
 ) if $cards;  
}    

# === Есть ли заявки на изменение данных ===
sub ask_u
{
 $cod='изменить данные клиента';
 $data=int $data;
 $url=$data<=0? "Неверный id учетной записи клиента!" : &ahref("$scrpt0&a=user&id=$data",'данные клиента');
}

sub ask_d
{
 $cod=&bold('удалить учетную запись клиента');
 $data=int $data;
 $url=$data<=0? "Неверный id учетной записи клиента!" : &ahref("$scrpt0&a=user&id=$data",'данные клиента').&ahref("$scrpt0&a=deluser&act=del&id=$data",'Удаление!');
}

sub ask_p
{
 $cod='изменить платеж';
 $data=int $data;
 $url=$data<=0? "Неверный id платежа!" : &ahref("$scrpt0&a=pays&act=show&id=$data",'смотреть платеж');
}

sub ask_error
{
 $cod='<span class=error>ошибка!</span> код: '.&Filtr_out($cod);
 $url='';
}

if( $PR{115} )
{ # 115 - право на прием заявок
  $out='';
  %subs=('p'=>\&ask_p,'u'=>\&ask_u,'d'=>\&ask_d);
  $sth=&sql($dbh,"SELECT p.id,p.reason,p.coment,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.admin_id ".
       "WHERE p.type=50 AND p.category=417 ORDER BY p.time DESC",'Заявки на изменение данных:');
  while( $p=$sth->fetchrow_hashref )
  {
     $coment=&Show_all($p->{coment});
     ($id,$reason,$tt,$admin,$name)=&Get_filtr_fields('id','reason','time','admin','name');
     ($cod,$data)=split /:/,$reason;
     if (defined $subs{$cod}) { &{$subs{$cod}} } else {&ask_error}
     $out.=&RRow('*','llllll',
       &the_time($tt),
       &bold($admin).($name && " ($name)"),
       $cod,
       $coment,
       $url,
       &ahref("$scrpt0&a=pays&act=show&id=$id",'смотреть заявку')
     );
  }
  $ul.=&li('Заявки на изменение данных'.$br2.
     &Table('nav2 tbg3',&RRow('tablebg','cccccc','Дата','От администратора','Что требуется','Детальнее','Операции','Смотреть заявку').$out)
  ) if $out;
}

nSql->new({
  dbh	=>$dbh,
  sql	=>"SELECT COUNT(*) AS n FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE u.grp IN ($Allow_grp) AND p.category=491 AND p.type=30 AND p.time>($ut-24*3600)",
  comment => 'Неотвеченных сообщений за сутки',
  hash=>\%h }) && $h{n}>0 &&
  do{
      $ul.=&li('За последние 24 часа от клиентов поступило '.&bold($h{n}).' сообщений, на которые еще не было дано ответа. '.
          &ahref("$scrpt0&a=payshow&nodeny=category&category=491",'Смотреть'))
  };

{
 $pr_events or last;
 %c=(
  502 => 'изменений в платежах',
  410 => 'изменений учетных записей клиентов',
 );
 foreach $h (keys %c)
 {
    $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE type=50 AND category=$h AND time>($ut-24*3600)",'Количество изменений данных');
    $ul.=&li("За последние 24 часа было произведено $p->{n} $c{$h}. ".&ahref("$scrpt0&a=payshow&nodeny=category&category=$h",'Смотреть')) if $p && $p->{n}>0;
 }
}

# === Оборудование на администраторе ===

{
 $PR{103} or last;
 $p=&sql_select_line($dbh,"SELECT COUNT(parent_id) AS n FROM dopdata WHERE ".
    "field_type=7 AND field_value='1:$Admin_id'",
    'Оборудование, которое числится на администраторе');
 $ul.=&li(&Printf('На вас числится [bold] единиц оборудования. []',$p->{n},&ahref("$scrpt0&a=equip&act=find&owner_type=1&owner_id=$Admin_id",'Смотреть'))) if $p && $p->{n}>0;
}

# === Правая половина окна ===

{
 !$pr_turn_office_adm && !$pr_turn_any_adm && last;
 $header=&RRow('tablebg','cccc','Логин','Имя','Суперадмин?','Установить сообщение');
 $old_office=-1;
 $out='';
 $sth=&sql($dbh,"SELECT * FROM admin".($PR{31}? '':" WHERE office=$Admin_office")." ORDER BY office,admin",'Список администраторов');
 while( $p=$sth->fetchrow_hashref )
 {
    $office=$p->{office};
    $out.=(!!$office && &RRow('tablebg','4','Отдел '.&bold($Offices{$office}||"№ $office"))).$header if $office!=$old_office;
    $old_office=$office;
    %pr=();
    $pr{$_}=1 foreach (split /,/,$p->{privil});
    $pr{1} or next;
    $id=$p->{id};
    $adm_login=&ahref("$scrpt0&set_new_admin=$id",$p->{admin});
    $adm_name=&Filtr_out($p->{name});
    $adm_super=$pr{3} && $pr{5}? '<span class=error>Да</span>' : $pr{2}? 'Огран.':'&nbsp;';
    $adm_mess=&ahref("$scrpt0&a=operations&act=setmess&id=$id",$p->{mess}=~/^\s*$/? 'установить':'*** изменить ***');
    $out.=&RRow('*','llcc',$adm_login,$adm_name,$adm_super,$adm_mess);
 }
 $ul.=&li('У вас есть право переключиться на любую из перечисленных учетных записей'.$br2.&Table('tbg3',$out));
}


$OUT.=&div('lft',&tag('ul',$ul));

1;
