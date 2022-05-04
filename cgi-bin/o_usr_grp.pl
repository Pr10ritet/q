#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> 'группы клиентов',
	'tbl'		=> 'user_grp',
	'field_id'	=> 'grp_id',
	'priv_show'	=> $pr_main_tunes,
	'priv_edit'	=> $pr_edt_main_tunes,
	'allow_copy'	=> 1,
};

sub o_menu
{
 return &ahref($scrpt,'Список групп').
	($pr_edt_main_tunes && &ahref("$scrpt&op=new",'Новая группа')).
	&ahref("$scrpt&act=usr_pack",'Объединения');
}

sub o_list
{
 $out='';
 $order_by=('grp_name','grp_id','clients DESC')[int $F{sort}]||'grp_name';
 $sth=&sql($dbh,"SELECT g.*,COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp GROUP BY g.grp_id ORDER BY $order_by");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$clients,$grp_admins,$grp_name)=&Get_fields('grp_id','clients','grp_admins','grp_name');
    $out.=&RRow('*nav3','clccccc',
       $id,
       '&nbsp;&nbsp;'.&Filtr($grp_name),
       ($grp_admins=~s/,/,/g)-1,
       $clients,
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       $pr_edt_main_tunes && &ahref("$scrpt&op=copy&id=$id",'Копия'),
       $pr_edt_main_tunes && !$clients && &ahref("$scrpt&op=del&id=$id",'Х')
    );
   }

 !$out && &Error('В базе данных нет ни одной группы клиентов.'.$br2.&ahref("$scrpt&op=new",'Создать'),$tend);

 $OUT.=&Table('tbg1 width100',
   &RRow('head','7',&bold_br('Группы клиентов')).
   &RRow('tablebg','cccc3',
     &ahref("$scrpt&sort=1",'Id группы'),
     &ahref($scrpt,'Название'),
     'Доступ администраторам<br>(количество)',
     &ahref("$scrpt&sort=2",'Клиентов в группе'),
     'Операции').
   $out);
}

sub o_new
{
 $grp_name=$grp_property=$grp_admin_email=$grp_nets=$grp_blank_mess='';
 $grp_maxflow=$grp_maxregflow=0;
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT g.*,COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp WHERE g.grp_id=$Fid GROUP BY g.grp_id");
 !$p && &Error($d->{when_deleted} || "Ошибка получения данных запрашиваемой группы клиентов с id=$Fid",$tend);
 $d->{no_delete}="в группе числится $p->{clients} учетных записей клиентов. Переведите их в другую группу." if $p->{clients}>0;
 $grp_property=$p->{grp_property};
 $grp_p{$_}=' checked' foreach (split //,$grp_property);
 $grp_admins=$p->{grp_admins};  
 $grp_adm{int $_}=' checked' foreach (split /,/,$grp_admins);
 $grp_admins2=$p->{grp_admins2};  
 $grp_admm{int $_}=' checked' foreach (split /,/,$grp_admins2);
 $grp_maxflow=int $p->{grp_maxflow};
 $grp_maxregflow=int $p->{grp_maxregflow};
 ($grp_name,$grp_admin_email,$grp_blank_mess,$grp_nets,$grp_adm_contacts,$grp_block_limit)=
   &Get_filtr_fields('grp_name','grp_admin_email','grp_blank_mess','grp_nets','grp_adm_contacts','grp_block_limit');
 $d->{old_data}='';
 $d->{name}='группы клиентов '.&commas($grp_name);
}

sub o_show
{
 ($A,$Asort)=&Get_adms();
 $out_right='Доступ разрешен для администраторов:'.$br;
 $out_right.='<div nowrap>'.
   "<input type=checkbox value=1 name=adm$_$grp_adm{$_}> ".
   "<input type=checkbox value=1 name=admm$_$grp_admm{$_}> ".
     $Offices{$A->{$_}{office}}.' - '.$A->{$_}{admin}.'</div>' foreach (@$Asort);

 $out_right.=$br2."<span class=disabled>Комментарий:</span> одна галочка дает возможность ограниченного доступа к группе ".
   "(только просмотр ip, логина, ФИО, адреса), две галочки - полный доступ к группе. Отсутствие галочек - полное сокрытие группы";

 $out_left=&Table('',
    &RRow('head','C',&bold_br($d->{name_action})).
    &RRow('*','ll','Название группы',&input_t('grp_name',$grp_name,26,128)).
    &RRow('*','ll','При переходе на новый месяц не производить снятие денежных средств',"<input type=checkbox value=1 name=grp_p1 $grp_p{1}>").
    #&RRow('*','ll','Не отображать группу в обычном списке клиентов (например, для группы "удаленные")',"<input type=checkbox value=1 name=grp_p2 $grp_p{2}>").
    &RRow('*','ll','Клиентам данной группы не разрешено самостоятельно заказывать пакет на следующий месяц',"<input type=checkbox value=1 name=grp_p3 $grp_p{3}>").
    &RRow('*','ll','Включить детализацию трафика для всех клиентов данной группы',"<input type=checkbox value=1 name=grp_p4 $grp_p{4}>").
    &RRow('*','ll','Максимальное количество двунаправленных потоков трафика одного клиента за срез снятия статистики. При превышении два среза подряд, доступ клиенту '.
       'будет заблокирован (ДОС атака, вирусы). 0 - отсутствие ограничений. Рекомендуется 20000',&input_t('grp_maxflow',$grp_maxflow,26,26)).
    &RRow('*','ll','Максимальное количество двунаправленных потоков трафика одного клиента, которое может быть зарегистрировано в детализированной статистике. Это защита '.
       'от большой нагрузки на БД в момент ДОС атак и вирусов). 0 - отсутствие ограничений. Рекомендуется 10000',&input_t('grp_maxregflow',$grp_maxregflow,26,26)).
    &RRow('*','ll','Email-ы админов, ответственных за группу, максимально 3 перечисленных через запятую',&input_t('grp_admin_email',$grp_admin_email,26,128)).
    &RRow('*','ll','Лимит отключения для создаваемых учетных записей клиентов',&input_t('grp_block_limit',$grp_block_limit,26,16)." $gr").
    &RRow('*','L','Перечислите допустимые подсети в формате xx.xx.xx.xx/yy. Если ни одна сеть не будет указана, то в данной группе будут допустимы любые ip.<br>'.
       "<textarea rows=6 name=grp_nets cols=38>$grp_nets</textarea>").
    &RRow('*','L','Это сообщение будет добавляться к сформированному бланку настроек. Бланк оформляется в виде таблицы, состоящей из двух колонок. Вы можете оформить '.
       "текст в виде колонок: разделитель колонок символ '|'.<br>\$l - логин<br>\$p - пароль<br>\$i - ip адрес</br>\$m - маска подсети<br>\$g - шлюз<br>\$d - ДНС<br><br> Например:<br>".
       '<em>Настройки подключения<br>Пароль|$p<br>Сервер авторизации|10.0.0.1<br>По вопросам обращайтесь по телефону XXX-XXX</em>.<br>'.
       "<textarea rows=8 name=grp_blank_mess cols=38>$grp_blank_mess</textarea>").
    &RRow('*','L',"Укажите контакты администрации и/или техподдержки. Данный текст будет отображаться в клиентской статистике.<br><textarea rows=8 name=grp_adm_contacts cols=38>$grp_adm_contacts</textarea>")        
 );
 
 $out=&RRow('*','^^',$out_left,$out_right);
 $out.=&RRow('*','L',&div('message','Изменение параметров не требует рестарта сервера, ядро системы получит изменения при обновлении списка клиентов. ')).
       &RRow('*','C',&submit_a('Сохранить')) if $pr_edt_main_tunes;
 $OUT.=&form(%{$d->{form_header}},&Table('tbg3',$out));
}

sub o_save
{
 $Fgrp_maxflow=int $F{grp_maxflow};
 $Fgrp_maxregflow=int $F{grp_maxregflow};
 $Fgrp_admin_email=&Filtr_mysql($F{grp_admin_email});
 $Fgrp_blank_mess=&Filtr_mysql($F{grp_blank_mess});
 $Fgrp_nets='';
 foreach $net (split/\n/,$F{grp_nets})
   {
    $net=&trim($net);
    next unless $net;
    $Fgrp_nets.="$net\n";
    &ErrorMess('Предупреждение: сеть '.&bold(&Filtr_out($net)).' задана неверно!') if $net!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ || $5>32;
   }
 $Fgrp_adm_contacts=&Filtr_mysql($F{grp_adm_contacts});
 $Fgrp_block_limit=$F{grp_block_limit}+0;
 $Fgrp_name=&trim(&Filtr($F{grp_name})) || "Группа № $Fid";

 # в grp_admins дважды будет встречаться 0 (в начале и в конце) - это для упрощения будущих операций
 $Fgrp_admins=$Fgrp_admins2='0';
 $sth=&sql($dbh,"SELECT id FROM admin ORDER BY id"); # order - чтоб результирующую строку grp_admins можно было сравнивать с предыдущей
 while ($p=$sth->fetchrow_hashref)
   {
    $h=$p->{id};
    $Fgrp_admins.=",$h" if $F{"adm$h"} || $F{"admm$h"};
    $Fgrp_admins2.=",$h" if $F{"adm$h"} && $F{"admm$h"};
   }
 $Fgrp_admins.=',0';
 $Fgrp_admins2.=',0';
 $Fgrp_property='';
 foreach (0..9,'a'..'z')
   {
    $Fgrp_property.="$_," if $F{"grp_p$_"};
   }
 $Fgrp_property.='0';

 $sql="grp_name='$Fgrp_name',grp_maxflow=$Fgrp_maxflow,grp_maxregflow='$Fgrp_maxregflow',grp_admin_email='$Fgrp_admin_email',".
    "grp_nets='$Fgrp_nets',grp_blank_mess='$Fgrp_blank_mess',grp_adm_contacts='$Fgrp_adm_contacts',grp_block_limit=$Fgrp_block_limit,".
    "grp_admins='$Fgrp_admins',grp_admins2='$Fgrp_admins2',grp_property='$Fgrp_property'";

 $d->{sql}=$sql;
 $_=&commas($Fgrp_name);
 if ($Fid)
   {# изменение, а не создание группы
    $new_data=$Fgrp_name ne $grp_name && "Новое имя группы: $_";
    $new_data.=($new_data && '. ').'Изменен список админов, имеющих доступ к группе' if $Fgrp_admins ne $grp_admins || $Fgrp_admins2 ne $grp_admins2;
    $new_data.=($new_data && '. ').'Изменен список сетей, разрешенных в группе' if $Fgrp_nets ne $grp_nets;
   }else
   {
    $new_data="Имя: $_";
   }
 $d->{new_data}=$new_data;
}

1;
