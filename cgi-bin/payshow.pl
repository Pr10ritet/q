#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_pays or &Error('Просмотр платежей запрещен.');

&LoadMoneyMod;
&LoadPaysTypeMod;

$Fmid=int $F{mid};
$Fyear=int $F{year};
$Fmon=int $F{mon};
$Fday=int $F{day};
$Foffice=int $F{office};
$Fact=$F{act};

$OUT.="<table class=width100><tr><td>&nbsp;&nbsp;</td><$tc valign=top width=80%>";
$tend='</td></tr></table>';

$AddRightBlock='';		# блок, который будет выводиться справа вверху меню, за которым идут
@AddRightBlock=();		# элементы блока <ul>...</ul>
@AddRightUrls=();

#  фильтр	расшифровка	привилегия	дополнительные hidden-поля для формы
@filtrs=(
   ['pays',	'нал',		1,	''],
   ['bonus',	'безнал',	1,	''],
   ['temp',	'врем.платежи',	1,	''],
   ['autopays',	'автоплатежи',	1,	''],
   ['mess',	'сообщения',	1,	''],
   ['mess2all',	'многоадресные сообщения',	1,	''],
   ['event',	'события',	14,	''],
   ['jobs',	'работы',	25,	''],
   ['net',	'затраты сети',	1,	''],
   ['transfer',	'передачи денег', 1,	''],
);

%subs=(
 'pay'		=> \&f_pay,
 'bonus'	=> \&f_bonus,
 'client'	=> \&f_client,
 'worker'	=> \&f_worker,
 'sworker'	=> \&f_worker,		# зарплата работника + работы
 'mess'		=> \&f_mess,		# сообщения
 'mess2all'	=> \&f_mess2all,	# сообщения всем
 'event'	=> \&f_event,		# события
 'temp'		=> \&f_temp,		# временные платежи
 'net'		=> \&f_net,		# затраты на сеть
 'transfer'	=> \&f_transfer,	# передачи наличных
 'zarplata'	=> \&f_zarplata,	# зарплаты
 'admin'	=> \&f_admin,		# платежи выбранного админа
 'adminall'	=> \&f_admin,
 'category'	=> \&f_category,	# вывод платежей категории $F{category}
 'jobs'		=> \&f_jobs,		# история работ
 'autopays'	=> \&f_autopays,	# автоплатежи
);

$Fnodeny=defined $subs{$F{nodeny}}? $F{nodeny} : $Fmid>0? 'client' : $Fmid? 'worker' : 'pay';

%subs2=(
 'list_admins'		=> \&list_admins,
 'zarplata'		=> \&zarplata,
 'list_categories'	=> \&list_categories,
);

&{ $subs2{$Fact} } if defined $subs2{$Fact};

%form_fields=('nodeny' => $Fnodeny);


if( $Fyear && $Fmon>0 )
{  # указан месяц на который предоставить отчет
   $year=$Fyear;
   $month=$Fmon;
   $form_fields{year}=$Fyear;
   $form_fields{mon}=$Fmon;
   $h=('','январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь')[$Fmon].' '.($year+1900)
}else
{# иначе отчет для текущего месяца
   $year=$year_now;
   $month=$mon_now;
   $h='';
}

if( $Fday )
{
   $max_day=&GetMaxDayInMonth($month,$year);		# получим количество дней в запрошенном месяце
   $month--;
   $Fday=$max_day if $Fday>$max_day || $Fday<1;
   $time1=timelocal(0,0,0,$Fday,$month,$year);		# начало дня
   $time2=timelocal(59,59,23,$Fday,$month,$year);	# конец дня
   $time2++;
   $form_fields{day}=$Fday;
   $h="$Fday число, $h";
}else
{
   $month--;
   $time1=timelocal(0,0,0,1,$month,$year);		#  начало месяца
   if ($month<11) {$month++} else {$month=0; $year++}
   $time2=timelocal(0,0,0,1,$month,$year);		#  начало следущего месяца
}

push @AddRightBlock,"За $h" if $h;

($A,$Asort)=&Get_adms();	# Получим список админов

# Список клиентов или данные клиента, по платежам которого фильтр. (Выше в %subs не должно меняться название ключа 'client')
$sth=&sql($dbh,"SELECT id,mid,grp,name,ip FROM users".($Fnodeny eq 'client' && " WHERE id=$Fmid"));
while ($p=$sth->fetchrow_hashref)
{
   $id=$p->{id};
   $user{$id}{$_}=$p->{$_} foreach ('mid','grp','name','ip');
}

$W=&Get_workers();	# Массив работников
$Allow_worker='';	# Cписок id работников, которые в том же отделе, что и админ
foreach (keys %$W)
{
   $Allow_worker.="-$_," if $W->{$_}{office}==$Admin_office; # поставим минус перед id работника, так как в платежах они с минусом
}
chop $Allow_worker;	# Уберем последнюю запятую

$SqlS="FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE ";

# В $allow_grp получим список групп, к которым есть полный доступ. В $allow_grp_alt список груп в виде "(u.grp>5 AND u.grp<=10) OR ..." - 
# может получится короче чем $allow_grp. Опасности в том, что не перечислены строго существующие группы - нет, т.к. если в таблице pays
# будет запись в несуществующй группе, то она отобразится как недоступная
$allow_grp=$allow_grp_alt=$allow_grp_sel=$for_grp='';
$min_grp=0;
$max_grp=-1;
foreach (sort {$a <=> $b} (keys %UGrp_name))
{  # обработка в порядке возрастания номеров групп
   if( $UGrp_allow{$_}<2 )
   {
      next if $max_grp<0;
      $allow_grp_alt.=' OR ' if $allow_grp_alt;
      $allow_grp_alt.=$min_grp!=$max_grp? "(u.grp>=$min_grp AND u.grp<=$max_grp)" : "u.grp=$min_grp";
      $min_grp=0;
      $max_grp=-1;
      next;
   }
   if( $F{"g$_"} )
   {
      $allow_grp_sel.="$_,";
      $form_fields{"g$_"}=1;
      $for_grp.=$br.$UGrp_name{$_};
   }
   $allow_grp.="$_,";
   $min_grp||=$_;
   $max_grp=$_;
}
chop $allow_grp;
chop $allow_grp_sel;

push @AddRightBlock,"Для групп:$for_grp" if $for_grp;

$allow_grp=$allow_grp_sel if $allow_grp_sel; # админ указал группы клиентов

$allow_grp='-1' if $allow_grp eq ''; # нельзя $allow_grp||='-1' т.к. $allow_grp может быть = '0'

if( $max_grp>=0 )
{
   $allow_grp_alt.=' OR ' if $allow_grp_alt;
   $allow_grp_alt.=$min_grp!=$max_grp? "(u.grp>=$min_grp AND u.grp<=$max_grp)" : "u.grp=$min_grp";
} 
$allow_grp_alt||='0'; # здесь 0 выступает как условие false, далее в sql получим: (0 OR u.grp IS NULL)

$SqlC='('.(length($allow_grp)<length($allow_grp_alt) || $allow_grp_sel? "u.grp IN ($allow_grp)" : $allow_grp_alt).' OR u.grp IS NULL) AND ';

$header_tbl='';
$header='';

@cols=('Клиент',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
@cols_map=(1,1,1,1,1,1,1,1);

&{ $subs{$Fnodeny} };

sub access_grp
{
 if( !$pr_oo )
 {
    $SqlC.=" AND (p.office=$Admin_office OR p.mid>0)";
    return;
 }  
 $Foffice or return;
 $form_fields{office}=$Foffice;
 $SqlC.=" AND p.office=$Foffice";
 push @AddRightBlock,'Проведенные админами отдела '.&bold($Offices{$Foffice});
}

sub access_admin
{
 return if $pr_other_adm_pays;
 $SqlC.=" AND p.admin_id=$Admin_id";
 push @AddRightBlock,"Только ваши записи";
}

sub what_cash
{
 return if $F{scash} eq '';
 $F{scash}+=0;
 if( $F{ecash} ne '' )
 {
    $F{ecash}+=0;
    ($F{scash},$F{ecash})=($F{ecash},$F{scash}) if $F{scash}>$F{ecash};
    push @AddRightBlock,"Сумма платежа в диапазоне:<br><b>$F{scash}</b> .. <b>$F{ecash}</b> $gr";
    $SqlC.=" AND p.cash>=$F{scash} AND p.cash<=$F{ecash}";
    $form_fields{ecash}=$F{ecash};
    $form_fields{scash}=$F{scash};
 }else
 {
    push @AddRightBlock,"Сумма платежа <b>$F{scash}</b> $gr";
    $SqlC.=" AND p.cash=$F{scash}";
    $form_fields{scash}=$F{scash}; # не переноси до условия т.к. в блоке выше может быть обмен scash и ecash
 }
}

sub f_client
{# платежи клиента
 &Error("Клиент id=$Fmid не найден в базе данных, только суперадмин может просмотреть записи, отсутствующего в базе данных, клиента.",$tend) if $Fmid<=0 || (!defined($user{$Fmid}{grp}) && !$pr_SuperAdmin);
 &Error("Клиент находится в группе, доступ к которой вам ограничен.",$tend) if $UGrp_allow{$user{$Fmid}{grp}}<2 && !$pr_SuperAdmin;
 ($userinfo,undef,$mId)=&ShowUserInfo($Fmid);
 $AddRightBlock.=$userinfo.$br;
 push @AddRightUrls,&ahref("$scrpt0&a=pays&mid=$Fmid",'Провести платеж') if $PR{54}||$PR{56}||$PR{57};
 push @AddRightUrls,&ahref("$scrpt0&a=pays&op=mess&mid=$Fmid",'Отправить сообщение') if $PR{55};
 $DontShowUserField=1;
 @cols=('&nbsp;',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $form_fields{mid}=$Fmid;
 $SqlC="p.mid=$Fmid";
 &what_cash;
 $Ftype_pays=int $F{type_pays};
 %f=(
   10 => 'платежи',
   30 => 'собщения',
 -495 => 'замечания',
   50 => 'события',
 );
 $temp_url=$scrpt.&Post_To_Get(\%form_fields);
 if( $f{$Ftype_pays} )
 {
    $SqlC.=$Ftype_pays>0? " AND p.type=$Ftype_pays" : " AND p.category=".(-$Ftype_pays);
    push @AddRightUrls,&ahref($temp_url,'Показать всю историю клиента');
    $form_fields{type_pays}=$Ftype_pays;
    unshift @AddRightBlock,"Показаны $f{$Ftype_pays} клиента";
 }
  else
 {
    unshift @AddRightBlock,($user{$Fmid}{mid}? 'История '.&bold('алиасной записи') : 'История клиента');
 }
 foreach (keys %f)
 {
    push @AddRightUrls,&ahref("$temp_url&type_pays=$_",'Показать '.$f{$_}) if $_!=$Ftype_pays;
 }
 # в менюшку фильтров (нал/безнал/события/работы) добавим фильтр
 push @filtrs,['client','историю клиента',1,&input_h('mid'=>$Fmid)];
}

sub f_worker
{# зарплата работника
 $PR{110} or &Error("У вас нет прав доступа к статистике зарплат/авансов.",$tend);
 $wid=-$Fmid;
 if( defined $W->{$wid}{name} )
 {
    &Error("Работник с id=$wid работает в отделе отличном от вашего",$tend) if !$pr_oo && $W->{$wid}{office}!=$Admin_office;
    push @AddRightBlock,'Для работника '.&bold($W->{$wid}{name});
 }
  elsif( $pr_oo )
 {
    push @AddRightBlock,"Для работника отсутствующего в базе данных";
 }
  else
 {
    &Error("Работник с id=$wid не найден в базе данных. Если есть записи зарплаты на этот id, то их может просмотреть админ с правами работы в разных отделах.",$tend)
 }
 $form_fields{mid}=$Fmid;
 $SqlC="p.mid=$Fmid";
 push @AddRightUrls,&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",'Данные работника');
 if( $Fnodeny ne 'sworker' )
 {
    $SqlC.=" AND p.type=10";
    %temp_files=%form_fields;
    $temp_files{nodeny}='sworker';
    push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'Показать события работника');
 }
 $header_tbl="<$tc>Работник</td>";
}

sub f_mess
{
 unshift @AddRightBlock,'Сообщения и комментарии';
 $SqlC.='p.type=30';
 &access_grp;
 @cols=('Клиент','','Сообщение','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_mess2all
{
 $PR{34} or &Error("Нет прав на просмотр групповых сообщений.",$tend);
 unshift @AddRightBlock,'Групповые сообщения';
 $SqlC='p.type=30 AND p.mid=0';
 @cols=('&nbsp;','Тип','Сообщение','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_event
{
 $pr_events or &Error("У вас нет прав на просмотр событий.",$tend);
 unshift @AddRightBlock,'События';
 $SqlC.="p.type=50 AND p.category NOT IN (460,461,112)"; # не включаем работы (460,461), автоплатежи (112)
 &access_grp;
 @cols=('Клиент','Событите','Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_temp
{# временные платежи. Отдел проверять не надо поскольку идет проверка по группе клиента
 unshift @AddRightBlock,'Временные платежи';
 $SqlC.="p.type=20";
 &access_grp;
 &what_cash;
 @cols=('Клиент',"Платеж,&nbsp;$gr",'&nbsp','Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
}

sub f_net
{   
 unshift @AddRightBlock,'История вложений/затрат сети';
 $SqlC='p.type=10 AND ';
 $SqlC.=$pr_oo? 'p.mid<=0' : "((p.office=$Admin_office AND p.mid=0)".($Allow_worker && " OR p.mid IN ($Allow_worker)").')';
 if( !$pr_other_adm_pays )
 {
    $SqlC.=" AND p.admin_id=$Admin_id";
    push @AddRightBlock," (<span class=data1>только ваши платежи</span>)";
 }
 &what_cash;
 @cols=('&nbsp;',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
}

sub f_zarplata
{
 $PR{110} or &Error("У вас нет прав для доступа к статистике по зарплатам/авансам",$tend);
 $SqlC='p.type=10 AND ';
 # если нет прав на другие отделы, то разрешим просмотр работников только в том же отделе
 $SqlC.=$pr_oo? "p.mid<0" : $Allow_worker? "p.mid IN ($Allow_worker)" : '0';  # если нет ни одного работника в том же отделе, то нельзя ничего выводить
 unshift @AddRightBlock,'Зарплаты работников';
 &what_cash;
 @cols=('Работник','&nbsp;',"Выдано,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
}

sub f_transfer
{
 $SqlC='p.mid=0 AND p.type=40';
 $SqlC.=" AND (reason='$Admin_id' OR coment='$Admin_id')" unless $pr_other_adm_pays; # нет прав на просмотр платежей других админов - выводим только передачи для текущего админа
 unshift @AddRightBlock,$pr_other_adm_pays? 'Передачи наличности между администраторами' : 'Передачи наличности на вас или обратно';
 @cols=('&nbsp;',"Сумма,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_admin
{# Платежи админа либо системы если $Fadmin==0
 $Fadmin=int $F{admin};
 &Error("Ваши привилегии не позволяют просматривать платежи другого администратора",$tend) if !$pr_other_adm_pays && $Fadmin && $Fadmin!=$Admin_id;

 if( !$pr_oo && $Fadmin )
 {  # нет прав работы с другими отделами, проверим запрашиваемый админ в том же отделе?
    $p=&sql_select_line($dbh,"SELECT office FROM admin WHERE id=$Fadmin LIMIT 1",'Получим права администратора, платежи которого собираемся просмотреть');
    $p or &Error("Не могу показать платежи запрашиваемого администратора т.к не удалось получить его данные, которые необходимы для проверки ваших прав. ".
           "Просмотреть запрашиваемые записи может админ, у которого есть права на работу с другими отделами.",$tend);
    &Error("У вас нет прав на просмотр платежей администратора из другого отдела.",$tend) if $p->{office}!=$Admin_office;
 }

 $form_fields{admin}=$Fadmin;

 if( $Fadmin )
 {
    push @filtrs,['admin','администратора '.$A->{$Fadmin}{login},1,&input_h('admin'=>$Fadmin)];

    if( $Fnodeny eq 'adminall' )
    {  # Более детальный отчет по админу
       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND cash>0",'Админ принял наличных');
       $i1=$p? $p->{'SUM(cash)'} : 0;

       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND cash<0",'Админ вернул наличных');
       $i2=$p? $p->{'SUM(cash)'} : 0;
    }else
    {
       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin",'Операции админа с наличностью');
       $i1=$p? $p->{'SUM(cash)'} : 0;
       $i2=0;
    }

    $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=40 AND reason='$Fadmin'",'Передал другим администраторам');
    $i3=$p? $p->{'SUM(cash)'} : 0;

    $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=40 AND coment='$Fadmin'",'Получил от других администраторов');
    $i4=$p? $p->{'SUM(cash)'} : 0;

    $p=&sql_select_line($dbh,"SELECT SUM(money) FROM cards WHERE r=$Fadmin",'Сумма номиналов карточек пополнения, находящихся у админа');
    $i5=$p? $p->{'SUM(money)'} : 0;

    $Na_rukax=$i1+$i2-$i3+$i4;

    unshift @AddRightBlock,'История платежей администратора '.&bold($A->{$Fadmin}{login}||'<span class=error>отсутствующего в базе данных</span>');
 }
  else
 {
    unshift @AddRightBlock,'История системных событий';
 }

 $u1=$Fadmin? "(p.type=40 AND (p.reason='$Fadmin' OR p.coment='$Fadmin'))" : '0'; # условие передачи наличных
 $u2="p.admin_id=$Fadmin"; # условия платежей админа
 if( $Fnodeny eq 'adminall' )
 {  # События можно выводить?
    $u2=!$pr_events? "($u2 AND p.type IN (10,20,40))" : $Fadmin? $u2 : "($u2 AND p.type IN (10,20,40,50))"; # не выводим сообщения при просмотре админа "система"
    $header.=&Table('tbg1',
        &RRow('*','lrl','Принял наличных',&bold(&split_n(int $i1)),$gr).
        &RRow('*','lrl','Вернул наличных',&bold(&split_n(int -$i2)),$gr).
        &RRow('*','lrl','Получил от других администраторов наличных',&bold(&split_n(int $i4)),$gr).
        &RRow('*','lrl','Передал другим администраторам наличных',&bold(&split_n(int $i3)),$gr).
        &RRow('head','lrl','На руках',&bold(&split_n(int $Na_rukax)),$gr).
        &RRow('*','lrl','Получил на реализацию карточек пополнения счета на сумму',&bold(&split_n(int $i5)),$gr).
        &RRow('head','lrl','На руках с учетом карточек пополнения',&bold(&split_n(int $Na_rukax+$i5)),$gr)) if $Fadmin;
 }
  else
 {   # выводим только платежи
     $u2="($u2 AND p.type=10)";
     push @AddRightUrls,&ahref("$scrpt&admin=$Fadmin&nodeny=adminall",'Детальнее');
 }
 # используем $Allow_grp,в который включены ограниченные группы - необходимо показывать, что есть скрытые записи
 $SqlC="(u.grp IN ($allow_grp) OR u.grp IS NULL) AND ($u1 OR $u2)";
 &what_cash;
}

sub f_category
{# вывод запрошенной категории платежей
 $Fcategory=int $F{category};
 $name_category=$Fcategory? 'категории '.&commas($ct{$Fcategory} || "неизвестной с кодом $Fcategory") : 'без категории';
 unshift @AddRightBlock,"Платежи $name_category";
 $form_fields{category}=$Fcategory;
 $SqlC.="p.category";
 if( $Fcategory )
 {
    $SqlC.="=$Fcategory";
 }
  else
 {  # если категория не заказана, то выведем все несуществующие категории, а не только нулевую!
    $i=0;
    $SqlC.=" NOT IN (";
    # походу разрядим строку пробелами чтоб при выводе sql на страницу она не была километровой ширины
    $SqlC.="$_,".($i++%15? '':' ') foreach (keys %ct);
    chop $SqlC; # уберем последнюю запятую
    $SqlC.=") AND p.type=10";
 }
 &access_grp;
 &access_admin;
 push @filtrs,['category',$name_category,1,&input_h('category'=>$Fcategory)];
}

sub f_jobs
{
 &Error('У вас нет прав на просмотр/назначение заданий работникам.',$tend) unless $PR{25};
 $SqlC.="p.type=50 AND p.category IN (460,461)";
 unshift @AddRightBlock,'История заданий работников';
 &access_grp;
 @cols=('Клиент','Задание','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[2]=0;
 $cols_map[3]=0;
}

sub f_autopays
{
 unshift @AddRightBlock,'Автоплатежи';
 $SqlC.="p.type=50 AND p.category=112";
 &access_grp;
 &what_cash;
 @cols=('Клиент','Автоплатеж','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[2]=0;
 $cols_map[3]=0
}

sub f_pay
{# обычные платежи
 unshift @AddRightBlock,'Платежи наличностью';
 $SqlC.="p.type=10 AND p.bonus=''";
 &access_grp;
 &access_admin;
 &what_cash;
}

sub f_bonus
{# безналичные платежи
 unshift @AddRightBlock,'Безналичные платежи';
 $SqlC.="p.type=10 AND p.bonus<>''";
 &access_grp;
 &access_admin;
 &what_cash;
}

if( $F{year} )
{
   $SqlC.=" AND p.time>$time1 AND p.time<$time2";
   %temp_files=%form_fields;
   delete $temp_files{year};
   delete $temp_files{mon};
   delete $temp_files{day};
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'Показать за все время');
}

$sql="SELECT p.*,u.name,u.grp $SqlS $SqlC ORDER BY p.time DESC";

if( $F{showgrp} )
{
   $form_fields{showgrp}=1;
   push @cols,'Группа';
   $cols_map[9]=1;
}
 else
{
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%form_fields).'&showgrp=1','Показать столбец '.&commas('группа'));
} 

$OUT.=&div('message',$header) if $header;

$cols=0;
$header_tbl='';
foreach (@cols)
{
   $header_tbl.="<$tc>$_</td>";
   $cols++;
}

if( $pr_edt_category_pays )
{
   $submit_button="<tr class=rowsv><$tc colspan=$cols>".$br.&submit_a('Сохранить категории').$br.'</td></tr>';
   $OUT.=&form_a('!'=>1,'a'=>'pays','act'=>'update_category','start'=>$start,%form_fields);
}

($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,$Max_list_pays,$scrpt.&Post_To_Get(\%form_fields));

$nav=$page_buttons && "<tr class=tablebg><td colspan=$cols>$page_buttons</td></tr>";
$header_tbl="<table class='usrlist width100'>$nav<thead><tr>$header_tbl</tr></thead>";
$br_line="<img src='$img_dir/fon1.gif' width=100% height=1>";
$t1='';
$n_pays=0;
undef $Na_rukax; # нельзя = 0 т.к. "на руках" может быть 0
%pay_types=(
 '10' => 'pay',
 '20' => 'temp',
 '30' => 'mess',
 '40' => 'transfer',
 '50' => 'event'
);

$out='';
while ($p=$sth->fetchrow_hashref)
{
   %f=();
   $f{$pay_types{$p->{type}}}=1;
   ($id,$mid,$cash,$bonus,$admin_id,$time,$r,$k,$category)=&Get_fields('id','mid','cash','bonus','admin_id','time','reason','coment','category');

   # Если нет прав на просмотр событий, то можно показывать:
   next if $f{event} && !$pr_events &&
     $category!=112 &&	# автоплатеж
     $category!=410 &&	# изм.данных клиента
     $category!=411 &&	# создание нового клиента
     $category!=417 &&	# запрос на изменение
     $category!=460 &&	# задание работникам выполняется
     $category!=461;	# задание работникам выполнено

   $r=~s|\n$||;
   $k=~s|\n$||;
   $tt=&the_time($time);

   # $pay_group - группа, к которой относится платеж:
   # 0 - положительный безналичный платеж клиента
   # 1 - отрицательный безналичный платеж клиента (или нулевой - обязательно для нулевых снятий за услуги)
   # 2 - вложение в сеть
   # 3 - затраты на сеть
   # 4 - иные (событие, сообщение)
   # 6 - положительный платеж наличностью
   # 7 - отрицательный платеж наличностью
   # 9 - зарплата/аванс работнику
   if( $f{pay} )
   {
      $pay_group=!$mid? 2 : $mid<0? 8 : $bonus? 0 : 6;
      $pay_group++ if $cash<=0;
   }
    else
   {
      $pay_group=4;
   }

   if( $Fadmin )
   {  # для статистики по конкретному админу выведем кол-во наличных на конец каждого дня
      unless (defined $Na_rukax)
      {  # посчитаем наличность в данный момен времени
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND time<=$time",'Наличность на руках админа начиная с отображаемой точки отсчета');
         $Na_rukax=$h? $h->{cash} : 0;
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND reason='$Fadmin' AND time<=$time",'Передал другим администраторам');
         $Na_rukax-=$h->{cash} if $h;
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND coment='$Fadmin' AND time<=$time",'Получил от других администраторов');
         $Na_rukax+=$h->{cash} if $h;
      }
      $t2=$tt=~/^(.+?) .+$/? $1 : ''; # получим дату платежа в виде строки, учти, что формат привязан к &the_time
      $out.=&RRow('tablebg',$cols,&div('lft','На руках: '.&bold(sprintf("%.2f",$Na_rukax))." $gr")) if $t1 ne $t2; # дата изменилась, выведем наличные на руках
      $t1=$t2;
      $Na_rukax-=$cash if $f{pay} && !$bonus;		# принял наличные
      $Na_rukax-=$cash if $f{transfer} && $k==$Fadmin;	# получил наличные от другого админа
      $Na_rukax+=$cash if $f{transfer} && $r==$Fadmin;	# передал наличные другому админу
   }

   $cash=sprintf("%.2f",$cash)+0; # не ранее подсчета $Na_rukax, чтобы не накапливалась погрешность

   if( $cash>0 )
   {
      $cash_left=$bonus? &tag('span',$cash,'class=data1') : &bold($cash);
      $cash_right='';
      $colspan_cash=$f{transfer}? 1 : 0;
   }
    elsif ($cash<0)
   {
      $cash_left='';
      $cash_right=$bonus? &tag('span',-$cash,'class=error') : &bold(-$cash);
      $colspan_cash=0;
   }
    else
   {
      $cash_left=$cash_right='';
      $colspan_cash=1;
   } 

   if( $mid>0 )
   {
      if( $UGrp_allow{$user{$mid}{grp}}<2 && !$pr_SuperAdmin )
      {  # Выведем, что запись недоступна т.к. если будет вывод по админу - будет казаться, что неправильно считаются деньги на его руках
         $out.=&RRow('disabled',$cols,
            "клиент в группе, к которой у вас ".($UGrp_allow{$user{$mid}{grp}}? 'неполный доступ':'нет доступа')." (id записи $id)");
         next;
      } 
      # клиент (если права на просмотр ФИО нет, то при выводе логин заменим на id)
      $Clnt=!defined $user{$mid}{name}? '<span class=error>Удаленный клиент</span>' :
         &ShowClient($mid,substr($user{$mid}{name},0,20),$mid).(!!$Atunes{ShowIpInPays} && "<span class=disabled>$user{$mid}{ip}</span>");
   }
    elsif( $mid )
   {# зарплата/событие работника
      if( !$PR{110} )
      {
         $out.=&RRow('disabled',$cols,"недоступная вам запись id: $id");
         next;
      } 
      $wid=-$mid;
      $Clnt=$W->{$wid}{name}? &tag('span','работник','class=data1').$br.&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$W->{$wid}{name}) :
        &tag('span','неизвестный работник','class=error');
   }
    else
   {
      $Clnt=&bold('Сеть');
   }

   $button2=''; # кнопка 'ответ дан'

   {
    if ($f{transfer})
    {  # передача наличных
       $reason="<span class='modified width100'>".&bold($A->{$r}{login}||'<span class=error>неизвестный админ</span>').
         ' &rarr; '.&bold($A->{$k}{login}||'<span class=error>неизвестный админ</span>').'</span>';
       $Clnt=&tag('span','Передача наличных','class=boldwarn');
       last;
    }

    if( $category_subs{$category} )
    {  # в данной категории есть расшифровка поля reason
       ($reason,undef,$dont_show_coment)=&{ $category_subs{$category} }($r,$k,$time,$mid);
    }else
    {
       $reason=$r!~/^\s*$/? &Show_all($r) : '';
       $dont_show_coment=0;
    }
    
    if( $f{mess} && ($category==491 || $category==492) )
    {  # сообщение к администрации
       $h="$scrpt0&a=pays&op=mess&q=$id&mid=$mid";
       if ($category==491)
       {
          $reason=&tag('span','Сообщение от клиента:','class=data1').$br.$reason;
          $cash_left=$PR{55} && &CenterA($h,'Ответить');
          $button2=&ahref("$scrpt0&a=pays&id=$id&act=markanswer",'О',"title='ответ дан'") if $PR{18};
       }else
       {
          $reason=&bold('Сообщение от клиента:').$br.$reason;
          $cash_left=$PR{55} && &ahref($h,'Ответить повторно');
       }
    }

    $cash_left.='Событие' if $f{event};

    if( $k!~/^\s*$/ && !$dont_show_coment )
    {
       $reason.=$br.$br_line.$br if $reason; # разделительная линия
       $reason.=&Show_all($k);
    }
   }

   $out.=&PRow.( $DontShowUserField? &tag('td','&nbsp;') : &tag('td',$Clnt,'class=nav3') );
   if ($colspan_cash && $cols_map[2] && $cols_map[3])
   {
      $out.=&tag('td',$cash_left,'colspan=2');
   }else
   { 
      $out.=&tag('td',$cash_left) if $cols_map[2];
      $out.=&tag('td',$cash_right) if $cols_map[3];
   } 
   $out.="<td>$reason</td><td class=disabled>$tt</td><$tc>";

   if( $pr_edt_category_pays && $f{pay} )
   {
      $n_pays++;
      $_=$ct_category_select[$pay_group];
      $_.="<option value=$category selected>НЕДОПУСТИМАЯ КАТЕГОРИЯ: $category</option>" if $category &&
          !(s/<option value=$category>/<option value=$category selected>/);
      $out.="<select name=id_$id class=sml><option value=0>&nbsp;</option>$_</select>";
   }
    else
   {
      $out.=$ct{$category}||'&nbsp;';
   } 
   $out.="</td><$tc>";
   $out.=!$admin_id? '&nbsp;' : $admin_id==$Admin_id? "<span class=data2>$A->{$admin_id}{login}</span>" : $A->{$admin_id}{login}||'???';
   $out.="</td><$tc class=nav3>";
   # если это не событие или разрешено работать с событиями
   $out.=!$f{event} || $pr_events? &ahref("$scrpt0&a=pays&act=show&id=$id",'&rarr;'):'&nbsp;';
   $out.=$button2;
   $out.='<td nowrap>'.($mid? $UGrp_name{$user{$mid}{grp}}||'без группы' : '&nbsp').'</td>' if $cols_map[9];
   $out.="</td></tr>";
}

if( $out )
{
   $OUT.=$header_tbl.$out;
   $OUT.=$submit_button if $n_pays;
   $OUT.="$nav</table>";
}
 else
{
   $out='';
   $out.="<li>$h</li>" while ($h=shift @AddRightBlock);
   $OUT.=$br2.&MessX('По фильтру:'.$br2.&tag('ul',$out).'записей не найдено');
}
$OUT.='</form>' if $pr_edt_category_pays;  
$OUT.='</td>';

# =========================
# Правое навигационное меню
# =========================

$OUT.="<$tc valign=top>";
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightBlock);
$AddRightBlock.='Фильтр:'.&tag('ul',$out) if $out;
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightUrls);
$AddRightBlock.='Операции:'.&tag('ul',$out) if $out;
$OUT.=&Mess3('row1',&div('lft',$AddRightBlock)) if $AddRightBlock;


($mon_list,$mon_name)=&Set_mon_in_list($Fmon||$mon_now);
$h1="$mon_list <select size=1 name=year>";
#$h1.="<option value=$_>".($_+1900).'</option>' foreach (100..);
$h1.="<option value=$_>".($_+1900).'</option>' foreach ($year_now-5..$year_now);
$h1.='</select>';
$year=$Fyear || $year_now;
$h1=~s/=$year>/=$year selected>/;

$h2='<select size=1 name=day><option value=0>&nbsp;</option>';
$h2.="<option value=$_>$_</option>" foreach (1..31);
$h2.='</select>';
  
$out=&Center($h2.$h1.$br.'От '.&input_t('scash',$F{scash},4,8)." $gr до ".&input_t('ecash',$F{ecash},4,8)." $gr").$br;

$out1='';
foreach (@filtrs)
{
   ($x,$y,$z,$i)=@{$_};
   $PR{$z} or next;
   $i=" $y$i$br";
   $Fnodeny eq $x? ($out.="<input type=radio name=nodeny value=$x checked>$i"): ($out1.="<input type=radio name=nodeny value=$x>$i");
} 

$out.=$br.&submit_a('Показать').$br.&ahref('javascript:show_x("grp")','&darr; Дополнительно');

($out2)=&List_select_grp;

$out.="<div id=my_x_grp style='display:none'>$out1$br";
$out.='Платежи админов в отделе:'.$br.&Get_Office_List($Foffice).$br2 if $pr_oo;
$out.="Для групп:$br2$out2</div>";

$OUT.=&Mess3('row1',&form('!'=>1,'#'=>1,$out));

$out='';
#$out.=&ahref("$scrpt0&a=multipays",'Мультиплатежи') if $pr_pays_create;
$out.=&ahref("$scrpt0&a=pays",'Провести платеж сети') if $pr_net_pays_create;
$out.=&ahref("$scrpt0&a=pays&act=mess2all",'Отправить многоадресное сообщение') if $pr_mess_all_usr;
$out.=&ahref("$scrpt0&a=report",'Отчет') if $pr_fin_report;
$out.=&ahref("$scrpt0&a=pays&act=send",'Передача наличных') if $pr_transfer_money;
$out.=&ahref("$scrpt&act=list_categories",'Категории платежей');
$out.=$pr_other_adm_pays? &ahref("$scrpt&act=list_admins",'Администраторы') :
     &ahref("$scrpt&nodeny=admin&admin=$Admin_id","Ваши платежи ($UU)");
$out.=&ahref("$scrpt&act=zarplata",'Работники') if $pr_worker_pays_show;
$out.=&ahref("$scrpt&nodeny=adminall&admin=0",'Система');

$OUT.=&div('nav2',&Mess3('row1',$out)).'</td></tr></table>';
&Exit;

# ------------------------------------
#	Вывод списка админов
# ------------------------------------
sub list_admins
{
 if( !$pr_other_adm_pays )
 {  # нет прав на просмотр платежей другого админа, далее покажем платежи текущего админа
    $Fnodeny='admin';
    $F{admin}=$Admin_id;
 }

 $last_office=-1;
 $r3=$r1;
 $r4=$r2;
 $i=1;
 $out='';
 $OUTL=$OUTR='';
 $sql="SELECT * FROM admin".(!$pr_oo && " WHERE office=$Admin_office")." ORDER BY office,admin";
 $sth=&sql($dbh,$sql,'Список админов');
 while ($p=$sth->fetchrow_hashref)
 {
    $office=$p->{office};
    if( $last_office!=$office )
    {
       if( $out )
       {
          $out.=$OUT1;
          $out.=&RRow('rowoff','C','Неактивные администраторы').$OUT2 if $OUT2;
          $out.='</table>';
          if ($i) {$OUTL.=$out} else {$OUTR.=$out}
          $i=1-$i;
       } 
       $out="<table class='tbg1i width100'>".&RRow('head','C','Отдел '.&bold($Offices{$office} || 'не указан'));
       $OUT1=$OUT2='';
    } 
    $last_office=$office;

    $admin=$p->{admin} || '????';
    $name=&Filtr_out($p->{name});

    $id=$p->{id};
    $h="<td width=35%>".&ahref("$scrpt&nodeny=admin&year=$year_now&mon=$mon_now&admin=$id",$admin)."</td><td>$name</td></tr>";
    $privil=$p->{privil}.',';
    if ($privil=~/,1,/) {$OUT1.="<tr class=$r1>$h"; ($r1,$r2)=($r2,$r1)} else {$OUT2.="<tr class=$r3>$h"; ($r3,$r4)=($r4,$r3)}
 }

 if( $out )
 {
    $out.=$OUT1;
    $out.=&RRow('rowoff','C','Неактивные администраторы').$OUT2 if $OUT2;
    $out.='</table>';
    if ($i) {$OUTL.=$out} else {$OUTR.=$out}
    $i=1-$i;
 } 

 $out='';         
 # Присутствующие в платежах, но отсутствующие в таблице админов
 $sth=&sql($dbh,"SELECT DISTINCT admin_id FROM pays p LEFT JOIN admin a ON p.admin_id=a.id WHERE a.id IS NULL AND p.admin_id<>0",
     'Получим id администраторов, которые отсутствуют в таблице admin, но присутствуют в платежах');
 while ($p=$sth->fetchrow_hashref)
 {
    $admin_id=$p->{admin_id};
    $out.=&ahref("$scrpt&nodeny=admin&admin=$admin_id","Отсутствующий в базе админ с id: $admin_id");
 }

 $i? ($OUTL.=$out) : ($OUTR.=$out);

 $OUT.=&Table('nav3 table1 width100',"<tr><td width='50%' valign=top>$OUTL</td><td valign=top>$OUTR</td></tr>");
 &Exit; # платежи админа не выводим, только список админов
}

# --------------------------------------
#	Вывод списка работников
# --------------------------------------
sub zarplata
{
 if( !$pr_worker_pays_show )
 {
    $OUT.=&error('Внимание!','Нет прав на просмотр зарплат/авансов'.$go_back);
    $Fnodeny='admin';
    $F{admin}=$Admin_id;
    return;
 }
 $Fnodeny='zarplata';
 $F{mid}=0; # далее покажем последние зарплаты на всех

 $out='';
 $sql="SELECT * FROM j_workers".(!$pr_oo && " WHERE office=$Admin_office")." ORDER BY state,office,name_worker";
 ($sql,$page_buttons,undef,$sth)=&Show_navigate_list($sql,$start,25,"$scrpt&act=$Fact");
 while ($p=$sth->fetchrow_hashref)
 {
    $name_worker=$p->{name_worker};
    $id=$p->{worker};
    $out.=&RRow($p->{state}==3? 'rowoff':'*','lllcc',
       &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$id",$name_worker),
       $Offices{$p->{office}},
       &Show_all($p->{post}),
       &CenterA("$scrpt&mid=-$id",'история'),
       ($pr_worker_pays_create && &CenterA("$scrpt0&a=pays&mid=-$id",'Выдать'))
    );
 }

 if( !$out )
 {
    &Message('В доступных вам отделах нет ни одного работника.');
    return;
 }

 $OUT.=&Table('tbg1 width100',
   &RRow('head','5',&bold_br('Работники')).
   ($page_buttons && &RRow('tablebg','5',$page_buttons)).
   &RRow('head','ccccc','Имя','Отдел','Должность','История','Выдать<br>зарплату').
   $out
 ).$br2;
}

# -----------------------------------------
#	Список категорий платежей
# -----------------------------------------
sub list_categories
{
 @cols=();
 $url="$scrpt&nodeny=category&year=$year_now&mon=$mon_now&category=";
 $cols[int($_/100)].=&ahref($url.$_,$ct{$_}) foreach (sort {$ct{$a} cmp $ct{$b}} (keys %ct));

 $OUT.=&Table('tbg1 nav2',
  &RRow('head','ccccccccc',
    'Безналичное пополнение счета клиента',
    'Безналичное снятие со счета клиента',
    'Наличное пополнение счета клиента',
    'Наличное снятие со счета клиента',
    'Вложения в сеть',
    'Затраты сети',
    'Выплаты работникам',
    'Иные',
    'Без категории'
  ).
  &RRow('row2','^^^^^^^^^',
    $cols[0],
    $cols[1],
    $cols[6],
    $cols[7],
    $cols[2],
    $cols[3],
    $cols[9],
    $cols[4].$cols[5],
    &ahref($url.'0','БЕЗ категории')
  )
 );     
 &Exit;
}

1;
