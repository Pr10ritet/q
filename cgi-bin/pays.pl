#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

&LoadMoneyMod;
&LoadPaysTypeMod;

$default_act='payform';

%subs=(
 'show'			=> \&pay_show,		# вывод формы просмотра/редактирования
 'edit'			=> \&pay_edit,		# непосредстенное изменение/удаление
 'plzedit'		=> \&plz_edit,		# создание события с просьюой изменить платеж
 'markanswer'		=> \&mark_answer,	# установить категорию сообщения как "ответ дан"
 $default_act		=> \&payform_show,	# вывод формы для осуществления платежа
 'pay'			=> \&pay_now,		# непосредственное проведение платежа
 'send'			=> \&send_money,	# перадача наличности между админами
 'mess2all'		=> \&mess_for_all,	# отправка многоадресного сообщения
 'set_block'		=> \&set_block,		# создание блокировочной записи, например блок.сообщений клиента
 'update_category'	=> \&update_category,	# групповое обновление категорий платежей
);

$Fmid=int $F{mid};
$Fact= defined($subs{$F{act}})? $F{act} : $default_act;

&{ $subs{$Fact} };
&Exit;

sub get_pay_data
{
 $pr_pays or &Error('У вас нет прав на просмотр платежей.');

 $Fid=int $F{id};
 $p=&sql_select_line($dbh,"SELECT p.*,INET_NTOA(p.admin_ip),a.admin,a.name,a.privil FROM pays p LEFT JOIN admin a ON a.id=p.admin_id WHERE p.id=$Fid",
    'Получение данных платежа, включая инфо об админе-авторе'); 

 if( !$p )
 {
    $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='pays' AND act=2 AND fid=$Fid","Есть ли в таблице изменений информация об удалении платежа с id=$Fid");
    $p && &Error(&the_short_time($p->{time},$t,1)." запись с id=$Fid была удалена ".($p->{adm}==$Admin_id? 'вами' : 'другим администратором'));
    &Error("Ошибка получения данных записи c id=$Fid".$br2."Вероятно эта запись отсутствует в таблице платежей.$go_back");
 }

 # поля reason и coment не фильтруем т.к понадобятся переводы строк, отфильтруем позже
 ($mid,$bonus,$type,$orig_reason,$orig_coment,$category,$adm_id,$office,$t_pay)=&Get_fields('mid','bonus','type','reason','coment','category','admin_id','office','time');

 $cash=sprintf("%.2f",$p->{cash});
 $adm_login=&Filtr_out($p->{admin}||'');		# т.к может быть неопределенным 
 $adm_name=&Filtr_out($p->{name}||'-');
 $admin_ip=$p->{'INET_NTOA(p.admin_ip)'};
 $pay_time=&the_time($t_pay);
 $display_admin=$adm_id? &bold($adm_login) : 'СИСТЕМА';
 $display_admin.=" ($admin_ip)" if $admin_ip ne '0.0.0.0';

 $can_edit=$pr_edt_pays;
 $logm='';

 if( $Admin_id!=$adm_id )
 {  # чужая запись
    if( $pr_edt_pays && !$pr_edt_foreign_pays )
    {
       $logm.='<li>Разрешен только просмотр т.к. запись создана не вами.</li>';
       $can_edit=0;
    }
    $privil=$p->{privil}.',';
    if ($can_edit && $privil=~/,13,/)
    {  # привилегия 13 - запретить редактирование своих платежей другими администраторами 
       $logm.='<li>Текущая запись принадлежит админу, который имеет монопольное право на ее редактирование.';
       $logm.=$pr_SuperAdmin? ' Вам разрешено т.к. вы суперадмин</li>' : '</li>';
       $can_edit=0 unless $pr_SuperAdmin;
    }
 }

 if( $mid>0 )
 {  # запись связана с клиентом
    ($filtr_name_url,$grp,$mId)=&ShowUserInfo($mid);
    if( $mId )
    {
       &Error('Вам не разрешен доступ к запрошенной записи.') if $UGrp_allow{$grp}<2; # без подробностей т.к это на 99% жулики
    }
     elsif( $pr_SuperAdmin )
    {
       $filtr_name_url=&bold("Отсутствующий в базе клиент (id=$mid)");
    }
     else
    {
       &Error("Данная запись указывает на отсутствующего в базе клиента. К ней имеет доступ только суперадминистратор.$go_back");
    }
 }
  elsif( $mid )
 {  # запись связана с работником
    $wid=-$mid;
    $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$wid",'Получение данных работника');
    if( $p )
    {
       &Error("Запись связана с работником, который работает в недоступном для вас отделе.$go_back") if !$pr_oo && $p->{office}!=$Admin_office;
       $worker_name=$p->{name_worker};
       $filtr_name_url='работник ';
    }
     elsif( $pr_oo )
    {
       $worker_name='работник отсутствует в БД';
       $filtr_name_url='';
    }
     else
    {
       &Error('Ошибка получения данных работника с которым связана запрошенная запись. Из-за этого невозможно проверить есть ли у вас права на просмотр. '.
              'Эту запись может изменить админ с правами работы в других отделах.');
    }
    $filtr_name_url.=&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$worker_name);
 }
  elsif( !$pr_oo && $office!=$Admin_office )
 {
    &Error('Текущая запись не связана с конкретным клиентом и создана админом из другого отдела, у вас нет прав на работу с другими отделами.');
 }
  else
 {
    $filtr_name_url=&ahref("$scrpt0&a=payshow&act=list_categories",'СЕТЬ');
 }

 # area_ - поля в виде редактирования
 # html_ - поля в виде просмотра

 $area_reason=' '.&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('reason',5,13);"}).
   "<br><textarea rows=5 cols=50 name=reason id=reason>".&Filtr_out($orig_reason)."</textarea>";
 $area_coment=' '.&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('coment',5,13);"}).
   "<br><textarea rows=5 cols=50 name=coment id=coment>".&Filtr_out($orig_coment)."</textarea>";
 $area_bonus='';

 $html_reason=&Show_all($orig_reason);
 $html_coment=&Show_all($orig_coment);
 $html_bonus='';

 $reason_title='Комментарий';

 {
  if ($type==10)
  {
     $need_money=1;
     if ($mid>0)
       {
        $nm_pay='Платеж клиента';
        $html_bonus=' <span class=data1>безнал</span>' if $bonus;
        $area_bonus="<input type=checkbox name=bonus value=y style='border:1;'".(!!$bonus && ' checked')."> безнал";
        $reason_title='Комментарий для администратора';
        $coment_title='Комментарий, который видит клиент';
        last if $pr_pays_create;
        $logm.='<li>У вас нет прав на проведение платежей клиентов, поэтому редактирование данной записи вам недоступно.</li>';
        $can_edit=0;
        last;
       }
     $coment_title='Дополнительный комментарий';
     if ($mid)
       {
        $nm_pay='Выдача наличных работнику';
        last if $pr_worker_pays_create;
        $logm.='<li>У вас нет прав на проведение зарплат работников, поэтому редактирование данной записи вам недоступно.</li>';
       }else
       {
        $nm_pay=&commas('Затраты сети');
        last if $pr_net_pays_create;
        $logm.='<li>У вас нет прав на проведение затрат сети, поэтому редактирование данной записи вам недоступно.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==20)
  {
     $need_money=1;
     $nm_pay='Временный платеж';
     $area_bonus=&input_h('bonus','y');
     $reason_title='Комментарий для администратора';
     $coment_title='Комментарий, который видит клиент';
     last if $pr_tmp_pays_create;
     $logm.='<li>У вас нет прав на проведение временных платежей, поэтому редактирование данной записи вам недоступно.</li>';
     $can_edit=0;
     last;
  }

  if ($type==30)
  {
     $need_money=0;
     $coment_title='Сообщение';
     if ($mid)
       {
        $nm_pay='Сообщение';
        last if $pr_mess_create;
        $logm.='<li>У вас нет прав на отправку сообщений клиентам, поэтому редактирование данной записи вам недоступно.</li>';
       }else
       {
        $nm_pay='Многоадресное сообщение';
        last if $pr_mess_all_usr;
        $logm.='<li>У вас нет прав на отправку многоадресных сообщений, поэтому редактирование данной записи вам недоступно.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==40)
  {
     $need_money=1;
     $area_bonus=&input_h('bonus','y');
     $nm_pay='Передача наличных';
     if ($can_edit)
       {
        if ($category!=470 && !$pr_SuperAdmin)
          {
           $can_edit=0;
           $logm.='<li>Изменение платежа заблокировано, поскольку данный тип платежа является переводом наличности от одного администратора другому. '.
              'При этом админ-получатель принял решение по поводу (не)действительности данного платежа. Платеж может удалить/изменить только суперадмин.</li>';
          } 
        if (!$PR{19})
          {
           $can_edit=0;
           $logm.='<li>У вас нет прав на оформление передач наличных, поэтому редактирование данного платежа вам недоступно.</li>';
          }
       }

     $r=int $orig_reason; # id админа
     $c=int $orig_coment; # id админа

     $reason_title='Админ передающий наличные';
     $coment_title='Админ принимающий наличные';

     # Получим выпадающее меню админов
     $area_reason=$br2.'<select size=1 name=reason>';
     $area_coment=$br2.'<select size=1 name=coment>';
     $sth=&sql($dbh,"SELECT * FROM admin ORDER BY admin",'Список администраторов');
     while ($p=$sth->fetchrow_hashref)
       {
        $admin=$p->{admin};
        $id=$p->{id};
        $area_reason.="<option value=$id".($r==$id? ' selected':'').">$admin</option>";
        $area_coment.="<option value=$id".($c==$id? ' selected':'').">$admin</option>";
        $html_reason=$admin if $r==$id;
        $html_coment=$admin if $c==$id;
       }
     $area_reason.='</select>';
     $area_coment.='</select>';
     last;
  }

  if ($type==50)
  {
     $need_money=0;
     $nm_pay='Событие';
     if ($can_edit && !$pr_edt_events)
       {
        $can_edit=0;
        $logm.='<li>У вас нет прав на редактирование событий.</li>';
       }
     $reason_title='Данные события';
     $coment_title='Дополнительный комментарий';
     last;
  }

  $nm_pay="неизвестный тип платежа, код: $type";
  $need_money=1;
 }

 if( $can_edit && $ct_block_edit{$category} && !$pr_SuperAdmin )
 {
    $logm.='<li>Категория записи разрешает редактирование только суперадмину</li>';
    $can_edit=0;
 } 
}

# =======================================
#	Форма изменения платежа
# =======================================

sub pay_show
{
 &get_pay_data();
 if( $can_edit && !$pr_edt_old_pays )
 {
    $t_blk=$t_pay-$t+600;
    if ($t_blk<0)
      {
       $can_edit=0;
       $logm.='<li>Со времени создания записи прошло более 10 минут.<br>Привилегии вашей учетной записи не позволяют редактировать записи старее этого времени.</li>';
      }
       elsif ($t_blk<600)
      {
       $logm.="<li>Через ".($t_blk>=60 && int($t_blk/60).' мин ').sprintf("%02d",$t_blk % 60).' сек'.
       ' редактирование платежа будет <span class=error>заблокировано</span>.</li>';
      }
 }

 $out2='';
 $out1=$logm && &RRow('*','L',"<ul>$logm</ul>");
 $out1.=&RRow('*','ll','Тип',$nm_pay);
 $out1.=&RRow('*','ll',"Категория <span class=disabled>($category)</span>",$ct{$category}) if $ct{$category};
 $out1.=&RRow('*','ll','С кем связан',$filtr_name_url).
   &RRow('*','ll','Время занесения',$pay_time).
   &RRow('*','ll','Автор',$display_admin).
   &RRow('*','ll','Имя автора',$adm_name);
 $out1.=&RRow('*','ll','Отдел',$Offices{$office}) if $Offices{$office};
 $out1.=&RRow('*','ll','Сумма платежа',&bold($cash)." $gr$html_bonus") if $need_money;

 $reason_title=$ct_name_fields{$category}[0] if $ct_name_fields{$category}[0];
 $coment_title=$ct_name_fields{$category}[1] if $ct_name_fields{$category}[1];

 if ($category_subs{$category})
   {# в данной категории есть расшифровка поля reason
    ($mess,$error_mess)=&{$category_subs{$category}}($orig_reason,$orig_coment,$t_pay,$mid);
    $html_reason=$mess && &div('message',$mess);
    $reason_title='Закодированые данные';
   }else
   {
    $html_reason=($html_reason ne '') && &bold($reason_title).&div('message',$html_reason);
   }

 $out1.=&RRow('*','L',$html_reason) if $html_reason ne '';
 $out1.=&RRow('*','L',&bold($coment_title).&div('message',$html_coment)) if $html_coment ne '';

 if ($can_edit)
   {
    $out=$need_money? &RRow('*','ll','Сумма платежа',&input_t('cash',$cash,10,14,' autocomplete="off"')." $gr$area_bonus") : &input_h('cash',0);
    $h=$ct_decode_mess{$category};
    if ($h)
      {
       $h=~s|#|<br>|g;
       $h=~s|\{(.+?)\}|<span class='data1 big'>$1</span>|g;
       $area_reason.=&div('story bordergrey',$h)
      }
    $area_reason.=&div('message lft',"<span class=error>Закодированные данные искажены</span>:".$br2.$error_mess) if $error_mess;
    $out.=&RRow('*','C',&bold($reason_title).$area_reason);
    $out.=&RRow('*','C',&bold($coment_title).$area_coment);
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'edit',
      &Table('tbg3',
        $out.
        &RRow('*','ll','<span class=error>Удалить запись</span>',"<input type=checkbox name=del value=1 style='border:1;'>").
        (!!$PR{18} && &RRow('*','ll','Не регистрировать событие об изменении записи',"<input type=checkbox name=dontmark value=1 style='border:1;'>")).
        &RRow('*','C','<br>'.&submit_a('Изменить запись').'<br>')
      )
    );
   }else
   {
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'plzedit',
      &Table('tbg3',
       &RRow('*','l','Вы можете послать ответственному администратору сообщение с просьбой отредактировать/удалить данную запись. Ниже укажите причину:').
       &RRow('*','c','<textarea rows=7 cols=38 name=reason></textarea>').
       &RRow('*','c',&submit_a('Отослать'))
      )
    ).'<br>';
   }

 $OUT.=&div('message cntr',&Table('','<tr><td valign=top width=50%>'.&Table('tbg3',$out1)."</td><td valign=top>$out2</td></tr>").$go_back);
}

# ===========================================
# Непосредственное изменение/удаление платежа
# ===========================================

sub pay_edit
{
&get_pay_data;
$can_edit or &Error("Вы не можете изменить запрошенный платеж, причина: <ul>$logm</ul>$go_back");

&Error("Со времени создания записи прошло более 10 минут. Привилегии вашей учетной записи не позволяют редактировать записи старше 10 минут.".$br2.
        &bold('Запись не изменена.')) if !$pr_edt_old_pays && $t_pay<($t-600);

$ClientPaysUrl="$scrpt0&a=payshow".($mid? "&mid=$mid" : '&nodeny='.($type==50? 'event': $type==30? 'mess': 'net'));

{
 # не создаем событие об изменении записи если запросил админ либо для избежания замкнутого круга: удаление/редактирование события -> создние события
 $dont_mark=($F{dontmark} && $PR{18}) || $category==502 || $category==501; 
 last if $dont_mark;
 # Создадим платеж "измененная запись", которая будет являться старым вариантом для изменяемой записи
 $sql="INSERT INTO pays SET mid=$mid,type=50,category=501,cash=0,bonus='',".
   "admin_id=$adm_id,admin_ip=INET_ATON('$admin_ip'),office=$office,time=$t_pay,coment='".&Filtr_sql($orig_coment)."',".
   "reason='$Fid:$type:$category:$cash:$bonus:".&Filtr_sql($orig_reason)."'";
 $sth=$dbh->prepare($sql);
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid};
 &DEBUG(
     &Printf('[span data2][br][][br]Запрос []',
       'Создаем копию записи - это будет старый вариант записи',$sql,$iid? "выполнен. INSERT_ID=$iid" : &bold('не выполнен')
     )
 );
 $iid or &Error("Произошла внутрення ошибка. Данные не изменены.$go_back");
}

{
 $F{del} or last;
 # Удаление платежа
 $rows=&sql_do($dbh,"DELETE FROM pays WHERE id=$Fid LIMIT 1");
 if ($rows<1 || &sql_select_line($dbh,"SELECT * FROM pays WHERE id=$Fid LIMIT 1",'Проверка, что платеж действительно удален'))
   {
    $dont_mark or &sql_do($dbh,"DELETE FROM pays WHERE id=$iid LIMIT 1",'Удалим только что созданный "старый вариант записи"');
    &Error("Внутренняя ошибка. Запись с id=$Fid не удалена.");
   }

 &ToLog("$Admin_UU Удалил запись id=$Fid из таблицы платежей. mid=$mid, bonus=$bonus, cash=$cash, time=$pay_time, type=$type, category=$category");

 unless ($dont_mark)
   {# используем не unix_timestamp, а $t - для того чтоб было совпадение с логами
    &sql_do($dbh,"INSERT INTO pays SET mid=$mid,type=50,category=502,$Apay_sql,".
       "reason='$iid:0',time=$t",'Создаем событие о том, что запись была удалена');
   }

 if ($mid>0 && $need_money && $cash!=0)
   {
    $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($cash) WHERE id=$mid LIMIT 1");
    if ($rows<1)
      {
       &ToLog("! $Admin_UU После удаления платежа произошла ошибка изменения баланса клиента. Необходима ручная корректировка");
       &Error("Запись удалена из таблицы платежей, однако при изменении баланса клиента произошла ошибка! Необходимо ручная корректировка главным администратором.");
      }
   }

 &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=2,time=$t,fid=$Fid,adm=$Admin_id","В таблице изменений зафиксируем удаление записи в таблице платежей");

 &OkMess('Запись удалена из таблицы платежей.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи'));
 return;
}

# =====================
# Редактирование записи

$F{reason}=~s/(\s+|\n)$//; # уберем финальные проблеы и переводы строк
$F{coment}=~s/(\s+|\n)$//;                                           

$new_reason=&Filtr_sql($F{reason});
$new_coment=&Filtr_sql($F{coment});
$new_cash=sprintf("%.2f",$F{cash}+0);
$new_category=$category;

{
 # поскольку категория для платежа зависит от нал/безнал, положительный/отрицательный
 # переведем категорию в "запись редактировалась" (9 - для положительный бонус, 109 - отрицательный бонус, 609 - положительный нал, 709 - отриц. нал)
 if( $type==10 )
 {  # платеж
    if( $mid>0 )
    {# клиента
      $new_bonus=$F{bonus}? 'y':'';
      $new_category=$new_bonus? 9 : 609;
    }else
    {
      $new_bonus='';
      $mid && $new_cash>0 && &Error("В выдаче наличных работникам не допускается положительная сумма платежа!$go_back");
      $new_category=$mid? 809 : 209;
    }
    $new_category+=100 if $new_cash<=0;
    last;
 }

 if( $type==20 )
 {  # временный платеж только безналом
    $new_bonus='y';
    last;
 }

 if( $type==30 )
 {  # сообщение
    $new_bonus='';
    $new_cash=0;
    $new_reason=&Filtr_mysql($orig_reason) unless $mid; # нельзя менять список групп клиентов в многоадресном сообщении (доступы к группам...)
    last;
 }

 if( $type==40 )
 {  # передача наличных только безналом
    $new_bonus='y';
    $new_reason=int $new_reason;
    $new_coment=int $new_coment;
    $new_category=470; # уберез подтверждение передачи, поскольку данные трансфера изменились
    last;
 }

 # событие или неизвестный тип платежа
 $new_bonus='';
 $new_cash=0;
}

$sql="UPDATE pays SET cash=$new_cash,bonus='$new_bonus',reason='$new_reason',coment='$new_coment',category=$new_category WHERE id=$Fid LIMIT 1";
$rows=&sql_do($dbh,$sql);
if( $rows<1 )
{
   $dont_mark or &sql_do($dbh,"DELETE FROM pays WHERE id=$iid LIMIT 1",'Удалим только что созданный "старый вариант записи"');
   &Error("Внутренняя ошибка. Запись не изменена.$go_back");
}

if( !$dont_mark )
{
   &sql_do($dbh,"INSERT INTO pays SET mid=$mid,type=50,category=502,$Apay_sql,reason='$iid:$Fid',time=$t",'Создаем событие о том, что запись была изменена');
}

&ToLog("$Admin_UU Изменена запись id=$Fid в таблице платежей.");
  
if ($mid<=0 || !$need_money || $new_cash==$cash)
{
   &OkMess('Изменения сохранены.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи')).$go_back;
   return;
}

# Изменим баланс клиента
$rows=&sql_do($dbh,"UPDATE users SET balance=balance+($new_cash)-($cash) WHERE id=$mid LIMIT 1");
if( $rows<1 )
{
   &ToLog("! $Admin_UU После изменения платежа произошла ошибка изменения баланса клиента. Необходима ручная корректировка.");
   &Error("Запись изменена, однако при изменении баланса клиента произошла ошибка! Необходимо ручная корректировка главным администратором.");
}

 &OkMess('Изменения сохранены.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи')).$go_back;
}

# ===========================================
#        Просьба изменить платеж
# ===========================================
sub plz_edit
{
 &get_pay_data;
 $reason=&Filtr_mysql($F{reason});
 $p=&sql_select_line($dbh,"SELECT FROM pays WHERE mid=$mid AND category=417 AND reason='p:$Fid' AND coment='$reason' LIMIT 1",'Уже есть точно такой же запрос?');
 $p && &Error("Запрос уже сформирован. Вероятно вы послали его дважны.");
 $sql="INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,coment,time) ".
      "VALUES($mid,0,50,417,$Admin_id,INET_ATON('$ip'),$Admin_office,'p:$Fid','$reason',$ut)";
 $rows=&sql_do($dbh,$sql);
 $rows<1 && &Error("Временная ошибка. Повторите запрос позже.");
 &OkMess("Послан запрос на изменение платежа с id=$Fid. Ожидайте реакции ответственного администратора.$go_back");
}

# ===========================================
#	Пометить запись как `ответ дан`
# ===========================================
sub mark_answer
{
 &get_pay_data;
 $can_edit or &Error("Вы не можете изменить запрошенный платеж.$go_back");
 $PR{18} or &Error('Недостаточно привилегий.');
 $rows=&sql_do($dbh,"UPDATE pays SET category=492 WHERE id=$Fid AND type=30 AND category=491 LIMIT 1");
 $rows=$rows==1? 'Сообщение помечено кодом `ответ дан`' : "Никаких действий не производилось - установка признака сообщения `ответ дан` не требуется";
 &OkMess($rows.$go_back);
}

# ============================================================
#
#		Пополнение счета/Отправка сообщений
#
# ============================================================

sub pay_now
{
 # Не &Filtr_mysql т.к. нам нужен символ ~ 
 $reason=&trim(&Filtr_sql($F{reason}));
 $coment=&trim(&Filtr_sql($F{coment}));
 $Fop=$F{op};
 $mss_log='';
 $time=$t;
 $category=0;

 if( $Fmid>0 )
 {
    ($user_info,$grp,$mId)=&ShowUserInfo($Fmid);
    !$mId && &Error("Клиент с id=$Fmid не найден в базе данных.");
    $Fmid=$mId;
    !$UGrp_allow{$grp} && &Error("Клиент находится в группе, к которой у вас нет доступа."); # с ограниченными правами можно, не забывай
    $ClientPaysUrl="$scrpt0&a=payshow&mid=$Fmid";
 }

 if( $Fop eq 'mess' || $Fop eq 'cmt' )
 {
    $coment=~/^\s*$/ && &Error("Сообщение не создано т.к вы не ввели текст сообщения.$go_back");
    $Fmid<0 && &Error("Нельзя отправлять сообщения работникам.$go_back");
    if( $Fmid )
    {
       !$pr_mess_create && &Error('Вам не разрешено посылать сообщения клиентам либо оставлять комментарии.');
       $reason='';
       if ($Fop eq 'mess')
       {
          $Fq=int $F{q}; # id сообщения, которое цитировалось.
          if ($Fq)
          {
             $p=&sql_select_line($dbh,"SELECT id FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)",'Данные сообщения, которое цитируется');
             $reason=$Fq if $p;
          }
          $pay_made_mess='Сообщение сохранено.';
          $category=490;
       }else
       {
          $reason=$coment;
          $coment='';
          $pay_made_mess='Замечание клиенту сохранено.';
          $category=495;
       }
    }
     else
    {
       $pr_mess_all_usr or &Error('У вас нет прав на многоадресную отправку сообщений.');
       $ClientPaysUrl="$scrpt0&a=payshow&nodeny=mess";
       $reason=''; # в этом поле через запятую будут перечислены номера групп клиентов для которых идет отправка сообщения
       foreach (keys %UGrp_name)
       {
          $reason.="$_," if $_ && $UGrp_allow{$_}>1 && $F{"g$_"};
       }
       if( !$reason )
       {
          $coment=$coment!~/^\s*$/ && $br2.'Введенное вами сообщение:'.$br.&input_ta('pvivetik',$F{coment},50,8);
          &Error("Вы не выбрали ни одну группу клиентов, для которой отправляете сообщение.".$coment.$go_back);
       }
       $reason=",$reason"; # для поиска по шаблону, список должен быть обрамлен запятыми по краям
       $pay_made_mess='Многоадресное сообщение сохранено.';
       $category=496;
    }
    $type=30;		# тип платежа - сообщение
    $bonus='';
    $cash=0;
 }
  else
 {  # Платеж, а не сообщение
    $cash=sprintf("%.2f",$F{cash}+0);
    $cash==0 && &Error("Не указана сумма платежа! Платеж не проведен.$go_back"); # ! не unless $cash
    if( $Fmid>0 )
    {
      if( $Fop eq 'tmp' )
      {  # временный платеж
         !$pr_tmp_pays_create && &Error('Вам не разрешено осуществлять временные платежи.');
         $Fdays=int $F{days};
         $Fdays<=0 && &Error('Не выбран срок временного платежа.');
         $reason.="\nПлатеж создан $time_now";
         $time=$t+$Fdays*3600*24;
         $pay_made_mess="Временный платеж $cash $gr проведен.";
         $type=20;
         $bonus='y';
         $category=1000;
      }
       elsif( $Fop eq 'old' )
      {  # платеж задним числом
         !$pr_old_pays_create && &Error("Вам не разрешено проводить платежи `задним числом`.");
         $Fmon=int $F{mon};
         $Fyear=int $F{year};
         $Fday=int $F{day};
         ($Fday<0 || $Fmon<1 || $Fmon>12 || $Fyear<0 || $Fyear>999) && &Error('Ваш диск успешно отформатирован. Продолжить?');
         $max_day=&GetMaxDayInMonth($Fmon,$Fyear);
         ($Fday<1 || $Fday>$max_day) && &Error('День задан неверно! Платеж задним числом не проведен.'.$go_back);
         $pay_made_mess="Платеж задним числом проведен.";
         $time=timelocal(15,0,12,$Fday,$Fmon-1,$Fyear); # в 12:00
         if ($time<$Tnt_timestamp)
         {  # неактуальный платеж
            !$PR{53} && &Error('Дата платежа ниже разрешенной граничной отметки! У вас должны быть права проведения неактуальных платежей.'.$go_back);
            $bonus='y';
            $category=$cash>0? 80 : 180; # `неактуальный платеж`
            $reason="$t:$reason";
         }
          elsif ($time>$t)
         {
            &Error('Будущим числом платежи не разрешено проводить.');
         }
          else
         {
            $bonus=$F{bonus}? 'y':'';
            !$bonus && ($category=$cash>0? 600 : 700); # `наличный платеж`
            $reason="Платеж введен задним числом $time_now".(!!$reason && "\n\n$reason");
         }
         $type=10;
      }
       else
      {
         !$pr_pays_create && &Error('Вам не разрешено осуществлять обычные платежи');
         &Error('Не разрешено проводить безналичные пополнения без комментариев. Укажите причину, например, '.
           "`поощрение за...`, `по акции за...` и т.д.$go_back") if $Block_bonus_pay && $F{bonus} && !($reason || $coment);
         $pay_made_mess="Платеж $cash $gr проведен.";
         $type=10;
         $bonus=$F{bonus}? 'y':'';
         !$bonus && ($category=$cash>0? 600 : 700); # `наличный платеж`
      } 
    }
     elsif( $Fmid<0 )
    {
       $pr_worker_pays_create or &Error('Вам не разрешено производить операции с зарплатами работников.');
       $ClientPaysUrl="$scrpt0&a=payshow&mid=$Fmid";
       $wid=-$Fmid;
       $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$wid",'Данные работника');
       $p or &Error("Работник с id=$wid отсутствует в базе данных.");
       $name_worker=$p->{name_worker};
       $pay_made_mess='Зарплата (аванс) работнику '.&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$name_worker).' начислена.';
       $type=10;
       $cash=-$cash if $cash>0;	# только выдача
       $bonus='';		# только наличностью
    }
     elsif( $pr_net_pays_create )
    {
       $ClientPaysUrl="$scrpt0&a=payshow&nodeny=net";
       $pay_made_mess="Платеж $cash $gr затрат сети проведен.";
       $type=10;
       $bonus='';
    }
     else
    {
       &Error('Вам не разрешены операции по добавлению/снятию наличных с сети.');      
    }
 }

 $sql="INSERT INTO pays (mid,cash,type,time,admin_id,admin_ip,office,bonus,reason,coment,category) ".
      "VALUES($Fmid,$cash,$type,$time,$Admin_id,INET_ATON('$ip'),$Admin_office,'$bonus','$reason','$coment',$category)";
 $DOC->{admin_area}.=&MessX($sql) if $Ashowsql;
 $sth=$dbh->prepare($sql);
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid}; # id только что внесенной записи

 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$iid",'Проверим, что платеж действительно внесен в БД');
 if (!$iid || !$p || $cash!=sprintf("%.2f",$p->{cash}) )
 {
    &Error("Произошла ошибка при добавлении записи в таблицу платежей.".$br2.
      "После выполнения запроса была запрошена сумма и результат не был получен либо сумма не совпала.");
 }

 $state_off='';

 # обновим баланс клиента
 if ($Fmid>0 && $cash!=0)
 {
    $rows=&sql_do($dbh,"UPDATE users SET balance=balance+$cash WHERE id=$Fmid LIMIT 1");
    if ($rows<1)
    {
       &ToLog("После осуществления платежа произошла ошибка изменения баланса клиента id=$Fmid. Проверьте баланс по платежам, вероятно необходима ручная корректировка");
       &Error($pay_made_mess.$br2."Ошибка при изменении баланса клиента!$br2<b>Внимание:</b> вероятно необходима ручная корректировка баланса главным администратором.");
    }
    $p=&sql_select_line($dbh,"SELECT * FROM users WHERE id=$Fmid LIMIT 1",'Получим баланс клиента');
    $p or &Error("Платеж проведен, однако произошла ошибка при проверке данных клиента.");
    $balance=$p->{balance};
    $paket=$p->{paket};
    $srvs=$p->{srvs};
    $start_day=$p->{start_day};
    $discount=$p->{discount};
    $limit_balance=$p->{limit_balance};
    # Проверим, отключен ли юзер имея положительный баланс или баланс выше границы отключения.
    # Если да, то напомним, что неплохо бы включить (или сами включим если настроки указывают)
    # Не забываем что может быть ситуация когда основная запись включена, а алиасная выключена
    {
      $p->{block_if_limit} or last;
      $p=&sql_select_line($dbh,"SELECT * FROM users WHERE (id=$Fmid OR mid=$Fmid) AND state='off' LIMIT 1",'Есть ли хотя бы одна заблокированная запись у клиента?');
      $p or last;
      # как минимум одна из записей клиента заблокирована. Вычислим сколько будет на счету в конце месяца
      @T=&GetClientTraf($Fmid);
      $traf1=&Get_need_traf($T[0],$T[1],$InOrOut1[$paket])/$mb;
      $traf2=&Get_need_traf($T[2],$T[3],$InOrOut2[$paket])/$mb;
      $traf3=&Get_need_traf($T[4],$T[5],$InOrOut3[$paket])/$mb;
      $traf4=&Get_need_traf($T[6],$T[7],$InOrOut4[$paket])/$mb;
      $money_param={ paket=>$paket, traf1=>$traf1,traf2=>$traf2,traf3=>$traf3,traf4=>$traf4,
         service=>$srvs, start_day=>$start_day, discount=>$discount, mode_report=>1 };
      $h=&Money($money_param);

      $rez_balance=sprintf("%.2f",$balance - $h->{money});
      $block_balance=$day_now < $Plan_got_money_day? ($over_cmp? $balance - $h->{money_over} : $balance) : $rez_balance;
      last if $block_balance<$limit_balance;
      if( $auto_on==2 )
      {  # разрешим доступ
         &sql_do($dbh,"UPDATE users SET state='on' WHERE id=$Fmid OR mid=$Fmid");
         $pay_made_mess.=$br2.'Доступ в интернет разрешен - баланс выше установленного лимита.';
         $state_off=" После осуществления платежа доступ в интернет был открыт";
      }else
      {
         $pay_made_mess.=$br2.'Не забудьте разрешить доступ в интернет - баланс выше установленного лимита.';
         $state_off=" Необходимо включить доступ в интернет";
      }
    }

    $pay_made_mess.=$br2."Обновление баланса клиента выполенено успешно: ".&bold($balance)." $gr";
    $mss_log="Счет клиента id=$Fmid пополнен на $cash $gr ";
    $mss_log.=" (платеж временный, срок действия $Fdays дней)" if $type==20;
    $mss_log.=". Текущий баланс клиента $balance $gr.$state_off";  
 }

 if( $cash!=0 )
 {
    if( !$Fmid )
    {
       $mss_log="Проведено $cash $gr как платеж на сеть.";
       $mss_log.=" Комментарий к записи: $reason" if $reason;
    }elsif( $Fmid<0 )
    {
       $mss_log="Выдана зарлата (аванс) работнику № $wid в размере на $cash $gr.";
       $mss_log.= "Комментарий к записи: $reason" if $reason;
    }
 }
  elsif( $Fop eq 'mess' && $Fq )
 {
    &sql_do($dbh,"UPDATE pays SET category=492 WHERE id=$Fq AND type=30 AND mid=$Fmid AND category=491 LIMIT 1",'Подправим цитируемое сообщение чтоб было видно что на него уже отвечали');
 }

 #&ToLog("$Admin_UU $mss_log") if $mss_log && $AllToLog;

 $OUT.=&div( 'infomess lft',$pay_made_mess.&Table('table2 nav',&RRow('','ll',$br2.&ahref($ClientPaysUrl,'Смотреть платежи'),'')) );
 $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$ClientPaysUrl"'>};
}

# =========================================================
#	Передача наличных от одного админа другому
# =========================================================
sub send_money
{
 $pr_transfer_money or &Error('Нет прав для передачи наличных между администраторами.');
 ($A)=&Get_adms();
 $cash=sprintf("%.2f",$F{cash}+0);
 if( $cash!=0 )
 {
    $cash<0 && &Error("<b>Передача денег не осуществлена</b>: сумма наличности должна быть положительным числом.");

    $from=int $F{from};
    $to=int $F{to};

    defined($A->{$from}{admin}) or &Error("Передача денег не осуществлена: админа с id=$from нет в списке администраторов.");
    defined($A->{$to}{admin}) or &Error("Передача денег не осуществлена: админа с id=$to нет в списке администраторов.");

    ($to==$from) && &Error("Передача денег не осуществлена: получатель и отправитель одно и тоже лицо.$go_back");

    $sql="INSERT INTO pays SET $Apay_sql,mid=0,cash=$cash,type=40,bonus='y',category=470,reason='$from',coment='$to',time=$ut";

    $_=Digest::MD5->new;
    $param_hash=$_->add($sql)->b64digest;
    $Ftime=int $F{time};
    $Frand=int $F{rand};

    $href=$br3.&CenterA("$scrpt0&a=payshow&nodeny=transfer",'Далее &rarr;');

    $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='pays' AND act=1 AND time=$Ftime AND fid=$Frand AND adm=$Admin_id AND param_hash='$param_hash'");
    $p && &Error("Обнаружена повторная посылка данных. Вероятно вы обновили страницу. Передача наличных была осуществлена ранее.".$href);
    $rows=&sql_do($dbh,$sql);
    $OUT.=&div('message cntr',$br2.&bold('Передача денег ').
        ($rows<1? '<span class=error>не осуществлена</span>' : &bold('осуществлена')).$href
    ).$br;

    $rows>0 && &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=1,time=$Ftime,fid=$Frand,param_hash='$param_hash',adm=$Admin_id");
    return;
 }
 # вывод формы передачи наличных
 $AdminsList='';
 foreach $id (keys %$A)
 {
    next if $A->{$id}{privil}!~/,62,/; # 62 - админ может участвовать в передачах
    $AdminsList.="<option value=$id>$A->{$id}{admin}</option>";
 }
 # time и rand - признаки повторной посылки данных
 $OUT.=&form('!'=>1,'act'=>'send','time'=>$t,'rand'=>int(rand 2**32),
    &Table('',&RRow('','ttt',
      'Админ, передающий наличные'.$br."<select name=from size=20>$AdminsList</select>",
      $br.'Передаваемая сумма'.$br2.&input_t('cash','',14,14,' autocomplete="off"').' '.$gr.$br2.
      &submit_a('Выполнить'),
      'Админ, принимающий наличные'.$br."<select name=to size=20>$AdminsList</select>"
    ))
 );
}

# ------------------------------------------
#  Многоадресная отправка сообщений
# ------------------------------------------

sub mess_for_all
{
 $PR{34} or &Error('У вас нет прав на многоадресную отправку сообщений.');

 $out='Выберите группы клиентов,<br>для которых необходимо отправить<br>многоадресное сообщение:'.$br2;
 foreach (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
 {
    next if $UGrp_allow{$_}<2 || !$_;
    $out.="<input type=checkbox value=1 name=g$_> $UGrp_name{$_}".$br;
 }
 $out2=&Table('nav2',&RRow('','ll',&ahref('#','Выделить все группы',qq{onclick="SetAllCheckbox('grp',1); return false;"}),
    &ahref('#','Снять выделение',qq{onclick="SetAllCheckbox('grp',0); return false;"}))).
    $br2.'Сообщение:'.$br.&input_ta('coment','',44,7).$br2;

 $out=&Table('table10',&RRow('','^^',"<div id=grp>$out</div>",$out2.&submit_a('Отправить!')));
 $OUT.=$br.&form('!'=>1,'#'=>1,'act'=>'pay','op'=>'mess','id'=>0,&MessX($out));
}

sub set_block
{# установка блокировок для клиента
 %f=(
   'mess'	=> [$PR{55},451,'Нет прав на отправку/блокировку сообщений.','Вы заблокировали возможность отправки клиентом сообщений администрации через клиентскую статистику'],
   'packet'	=> [$PR{117},450,'Нет прав на установку блокировки для клиента на заказ пакета через клиентскую статистику.','Вы заблокировали возможность клиенту заказать пакет через клиентскую статистику'],
 );

 defined $f{$F{what_block}} or &Error('Неверная команда. Действие не выполнено.');

 ($priv,$category,$mess1,$mess2)=@{$f{$F{what_block}}};

 $priv or &Error($mess1);

 (undef,$grp,$mId)=&ShowUserInfo($Fmid);
 $mId or &Error("Клиент с id=$Fmid не найден в базе данных.");
 $UGrp_allow{$grp}<2 && &Error("У вас нет прав на работу с учетной записью указанного клиента.$go_back");

 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE mid=$mId AND type=50 AND category=$category LIMIT 1",'Есть ли уже блокировка для клиента?');
 $p && &Error("Для данного клиента уже существует заказанная блокировка. Возможно вы продублировали запрос.$go_back");
 &sql_do($dbh,"INSERT INTO pays SET mid=$mId,cash=0,type=50,category=$category,time=$ut,$Apay_sql");
 $url="$scrpt0&a=payshow&mid=$mId";
 &OkMess("$mess2. Отменить блокировку сможет администратор с правами редактирования событий - он должен будет удалить в платежах клиента соответствующее событие-блокировку.".$br2.
         &CenterA($url,'Смотреть платежи/события клиента').$go_back);
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="15; url='$url'">};
}

# ------------------------------------------
#     Форма для осуществления платежей
# ------------------------------------------

sub payform_show
{
 $cash=$F{cash}+0;
 $coment=&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('coment',8,18);"}).$br.
   &input_ta('coment',$F{coment},44,7,'id=coment');

 $out='';

 if( $Fmid<0 )
 {
   $pr_worker_pays_create or &Error('Нет прав на выдачу зарплат/авансов.');
   $wid=-$Fmid;
   $W=&Get_workers($wid);
   defined($W->{$wid}) or &Error("Работник № $wid не найден в базе данных.$go_back");
   !$pr_oo && $W->{$wid}{office}!=$Admin_office && &Error("Работник с № $wid работает в отделе отличном от вашего.");
   $user_info=&MessX("Имя работника: ".$W->{$wid}{url}.$br."Должность: ".&bold(&Show_all($W->{$wid}{post})));
   $out.=&input_h('mid'=>$Fmid,'coment'=>'').
      "Введите сумму которую начисляете в счет зарплаты/аванса работнику".$br2.
      &input_t('cash',$cash,14,16,'id=cash autocomplete="off"')." $gr".$br2.
      &bold('Комментарий').$br.&input_ta('reason',$F{reason},44,7);
   $DOC->{body_tag}.=qq{ onload="javascript: document.getElementById('cash').focus();"}
 }
  elsif ($Fmid)
 {
   ($user_info,$grp,$mId)=&ShowUserInfo($Fmid);
   $mId or &Error("Клиент с id=$Fmid не найден в базе данных.");
   $UGrp_allow{$grp} or &Error("У вас нет прав на работу с записью клиента.");
   $UGrp_allow{$grp}>1 or ($OUT.=&MessX('<b>Предупреждение:</b> у вас ограниченный доступ в группу данного клиента. Вы можете провести платеж, '.
     'однако не сможете потом его изменить/удалить, а также просмотреть баланс, платежи и сообщения данного клиента.',1,1));
   $user_info=&MessX($user_info,0,1);
   $out.=&input_h('mid',$mId);

   ($pr_pays_create || $pr_tmp_pays_create || $pr_old_pays_create || $pr_mess_create) or
       &Error("Вам не разрешено проводить никакие типы платежей/сообщений клиентам.");

   @f=();
   push @f,['pay',1,'обычный платеж'] if $pr_pays_create;
   push @f,['tmp',1,'временный платеж'] if $pr_tmp_pays_create;
   push @f,['old',1,'платеж задним числом'] if $pr_old_pays_create;
   push @f,['mess',0,'сообщение клиенту'] if $pr_mess_create;
   push @f,['cmt',0,'комментарий к учетной записи'] if $pr_mess_create;
   $Fop=$F{op}||'pay';
   $hide_cod=qq{hide_element("coment_div"); hide_element("cash_div"); };
   $hide_cod.=qq{hide_element("$_->[0]"); } foreach @f;
   $DOC->{header}.="<script>function hide_e() { $hide_cod }</script>";
   foreach (@f)
   {
      $h=qq{hide_e(); document.getElementById("$_->[0]").style.display=""; };
      $h.=qq{document.getElementById("coment_div").style.display=""; }.
          qq{document.getElementById("cash_div").style.display="";} if $_->[1];
      $out.="<input type=radio id=radio$_->[0] value=$_->[0] name=op style='border:0;' ".($Fop eq $_->[0] && 'checked ').
        qq{onClick='$h'><label for=radio$_->[0]>$_->[2]</label>}.$br;
   }

   ($mon_list)=&Set_mon_in_list($mon_now);
   ($year_list)=&Set_year_in_list($year_now);
   $day_list='<select size=1 name=day><option value=0>&nbsp;</option>'.
      (join '',map {"<option value=$_>$_</option>"}(1..31))."</select> $mon_list $year_list".$br;

   $opMess=$Fop eq 'mess';
   $out.=$br.'<div id=cash_div'.($opMess && " style='display:none'").'>'.
      &input_t('cash',$cash,14,16,'id=cash autocomplete="off"')." $gr ".
      "<input type=checkbox name=bonus value=1 style='border:0;'> безнал".$br2.
   '</div>';

   if ($pr_pays_create)
   {
      $out.="<div id=pay".($opMess && " style='display:none'").'>'.&bold('Комментарий для админов').'</div>';
   }

   if ($pr_tmp_pays_create)
   {
      $out.="<div id=tmp ".($Fop ne 'tmp' && "style='display:none'").'>'."Временный платеж на ".
        "<select size=1 name=days>".(join '',map {"<option value=$_>$_</option>"}(1..31))."</select> дней".$br3.
        &bold('Комментарий для админов').
      '</div>';
   }

   if ($pr_old_pays_create)
   {
      $out.="<div id=old style='display:none'>Провести платеж следующей датой: ".$br2.
        $day_list.$br2.&bold('Комментарий для админов').
      '</div>';
   }

   if ($pr_mess_create)
   {
      $Fq=int $F{q}; # id сообщения клиента, на которое дается ответ
      if ($Fq)
      {
         $p=&sql_select_line($dbh,"SELECT reason FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)",'Цитируемое сообщение');
         $Fq=0 unless $p;
      }
      $out.='<div id=mess'.(!$opMess && " style='display:none'").'>'.$br2.(!$Fq? &bold('Сообщение') :
         &input_h('q'=>$Fq).'Вы отвечаете на сообщение клиента: '.&div('message',&Show_all($p->{reason}))).
      '</div>';
      $out.="<div id=cmt style='display:none'>".$br2.&bold('Комментарий').'</div>';
   }

   $out.='<div id=coment_div'.($opMess && " style='display:none'").'>'.
        &input_ta('reason',$F{reason},44,5).$br.
        &bold('Комментарий, который будет видеть клиент ').
   '</div>';

   $out.=$coment;
   $pay_mess='';
   foreach $i (split /\n/,$p_adm->{pay_mess})
   {
      $_=&Filtr_out($i);
      s/"/`/g; # на апостроф менять нельзя, на альтернативный &#34; тоже - javascript воспринимает как кавычку
      $x=(s/^#(\-?\d+\.?\d*)\s*//)? qq{; document.getElementById("cash").value="$1"; document.getElementById("bonus").checked=true} : '';
      s/\s+$//;
      $i or next;
      $pay_mess.=&RRow('*','l',qq{<span class='data2' style='cursor:pointer;' onClick='javascript: document.getElementById("coment").value="$_"$x'>$_</span>});
   }
   $pay_mess=&Table('table0',$pay_mess).$br if $pay_mess;

   %f=('<b>Текст</b>' => ' ~bold(Текст~)',
       '<span class=borderblue>Текст в рамке</span>' => ' ~frame(Текст~)',
       '<span class=data2>ссылка</span>' => ' ~url(http://~)(Текст~)');

   foreach (keys %f)
   {
      $pay_mess.=qq{<span style='cursor:pointer;' onClick='javascript: document.getElementById("coment").value+=value="$f{$_}"'>$_</span>$br2};
   }

   $user_info.=&MessX($pay_mess,0,1);
   $DOC->{body_tag}.=qq{ onload="javascript: document.getElementById('cash').focus();"};
 }
  elsif ($pr_net_pays_create)
 {
    $out.=&bold("Вложения и затраты сети").$br2.
       "Приход (уход) в кассу:".$br2.
       "<input type=text name=cash id=cash value='$cash' size=14> $gr".$br2.
       &bold('Комментарий').$br.
       &input_ta('reason',$F{reason},50,7);
 }
  else
 {
    &Error('Выберите клиента перед тем как осуществить платеж.');
 }
 $out.=$br2.&submit_a('Провести платеж');
 $OUT.=$br.&form('!'=>1,'act'=>'pay',&Table('table0',&RRow('','t t',$user_info,'',&MessX($out))));
}




sub update_category
{# обновление категорий платежей
 $pr_edt_category_pays or &Error('Нет прав на изменение категорий платежей.');
 $i=0;
 $stop=0;
 foreach $f (keys %F)
 {
    next if $f!~/^id_(\d+)/;
    $id=$1;
    $c=int $F{$f};

    $url_id=&ahref("$scrpt&act=show&id=$id",$id);
    $no_chng_mess="<div class='message lft'>Категория платежа с id=$url_id не изменена т.к";
    $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$id");
    if( !$p )
    {
       $OUT.="$no_chng_mess не удалось получить информацию об этом платеже, что необходимо для проверки прав на изменение. ".
         "Вероятно, пока вы вносили изменения, другой администратор удалил платеж.</div>";
       $stop++;
       next
    }

    $old_c=$p->{category};
    next if $old_c==$c;

    if( !$pr_edt_foreign_pays && $Admin_id!=$p->{admin_id} )
    {
       $OUT.="$no_chng_mess у вас нет прав на изменение платежей других администраторов.</div>";
       $stop++;
       next
    }

    if( !$pr_oo && !($p->{mid}) && $Admin_office!=$p->{office} )
    {
       $OUT.="$no_chng_mess у вас нет прав на работу с платежами другого отдела</div>";
       $stop++;
       next
    }

    if( $p->{type}!=10 )
    {
       $OUT.="$no_chng_mess тип данной записи не допускает ручное изменение категории.</div>";
       $stop++;
       next
    }

    if( $c && !(defined $ct{$c}) )
    {  # это мухлеж
       $OUT.="$no_chng_mess т.к. вы указали несуществующую категорию платежа. Если вы не сжульничали - сообщите администратору о ситуации.</div>";
       $stop++;
       next
    }    

    $rows=&sql_do($dbh,"UPDATE pays SET category=$c WHERE id=$id AND category<>$c LIMIT 1");
    if( $rows==1 )
    {
       $i++; # не делаю $i+=$rows, потому что может вернуть не только нолик или единичку
    }
     else
    {
       $OUT.=&div('message error',"НЕ удалось обновить категорию платежа с id=$url_id");
       $stop++;
    }
 }

 $url="$script?$QueryString&a=payshow";
 $OUT.=&div('message cntr',"Категории выбранных платежей обновлены. Всего обновлено <b>$i</b>".$br2.&ahref($url,'Далее &rarr;'));

 return if $stop;
 $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$url"'>};
}

1;
