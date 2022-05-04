#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_workers or &Error('Доступ к разделу управления работниками вам запрещен.');
&LoadJobMod;

# ! Админ может назначать задания для клиентов, к которым у него неполный доступ
$Fact=$F{act};                                                                          
$Fid=int $F{id};
$Fidjob=int $F{idjob};

%subs=(
 'setjob'	=> \&workers_menu,	# выдача задания
 'setjobnow'	=> \&workers_menu,
 'deljob'	=> \&workers_menu,	# удаление задания
 'endjob'	=> \&workers_menu,
 'endjobnow'	=> \&workers_menu,
 'setcstate'	=> \&workers_menu,	# установка состояния для клиентской записи
 'showjob'	=> \&workers_menu,	# вывод списка текущих заданий
 'come'		=> \&workers_menu,	# начать/закончить трудовой день работника
 'grafik'	=> \&grafik_menu,
 'history'	=> \&workers_menu,	# история работ
);

$W=&Get_workers();		# список работников
&nJob_present_workers($W);	# пометим тех, кто вышел на работу

!defined($subs{$Fact}) && &Error('Ошибка. Действие не задано.');

$OUT.="<table class='width100 pddng'><tr><td valign=top class=nav2 width=16%>";
$tend='</td></tr></table>';
 
&{ $subs{$Fact} };
$OUT.="</td><td valign=top>";
&{$Fact};
$OUT.=$tend;
&Exit;

sub check_access_2worker
{
 my ($id)=@_;
 defined($W->{$id}{name}) or &Error("Работник с номером $id отсутствует в базе данных.$go_back",$tend);
 !$pr_oo && $W->{$id}{office}!=$Admin_office && &Error("Работник с номером $id работает в отделе отличном от вашего. Доступ запрещен.$go_back",$tend);
}

sub workers_menu
{
 $out=&ahref("$scrpt0&a=oper&act=workers",'Список работников');
 $out.=&ahref("$scrpt&act=showjob&mod=-1",'Текущие задания');
 $out.=&ahref("$scrpt&act=showjob&mod=-2",'Подготовленные задания');
 $out.=&ahref("$scrpt&act=setjob",'Выдать задание') if $pr_workers_work;
 $out.=&ahref("$scrpt&act=grafik",'График');
 $out.=$br.&div('tablebg',&form('a'=>'oper','act'=>'workers',&input_t('text','',20,80).' '.&submit('Поиск'))).$br;
 $OUT.=&Mess3('row2',$out);
}

sub get_users_data
{
 my ($id)=@_;
 my $U;
 $pr_workers_work or &Error("Нет прав на выдачу задания работникам.$go_back",$tend);
 if ($id>0)
   {# задание связано с клиентом
    $U=&Get_users($id);
    defined($U->{$id}{grp}) or &Error("Ошибка получения даннных клиента с id=$id.$go_back",$tend);
    $UGrp_allow{$U->{$id}{grp}} or &Error("Клиент находится в группе, доступ к которой вам запрещен.",$tend);
    ($_)=&ShowUserInfo($id);
    return($_,$U->{$id}{cstate});
   }
    elsif ($id<0)
   {
    &Error("Неверно задан id клиента: $id.$go_back",$tend);
   }
    else
   {
    return('Работа по сети',0);
   }
}

sub setjob
{
 ($client_info,$cstate)=&get_users_data($Fid);
 
 if ($Fidjob)  
   {# запрос модификации уже подготовленного бланка задания
    $p=&check_del_job;
    ($job,@workers)=split /,/,$p->{reason};
    $#workers>=0 && &Error("Вы не можете начать/удалить задание т.к. оно уже выдано работникам. Вы можете только отменить его.$go_back",$tend);
    $title_mess='Вы открыли подготовленное в '.&the_time($p->{time}).' задание'.$br2.&form('!'=>1,'act'=>'deljob','idjob'=>$Fidjob,&submit_a('Удалить задание'));
   }else
   {
    $title_mess='Выдача задания работникам';
   }

 $help=<<help;
<br><br><div class='row2 story'>&nbsp;&nbsp;Для непосредственной выдачи задания, выберите работников справа
в списке путем установки галочки в любой колонке напротив имени работника. Если работник(и) главный в бригаде, то
галочку надо ставить в столбце 'Ответственный' (первый) иначе во втором столбце.<br>
<br>
&nbsp;&nbsp;Задание может быть выдано только тем работникам, которые считаются вышедшими на работу.<br>
<br>
&nbsp;&nbsp;Вы можете подготовить задание на будущее - смотрите третью колонку
</div>
help

 # вид работ заказан админом или, в зависимости от текущего состояния учетной записи клиента, выберем предполагаемый вид работ
 $job=defined $F{job}? int $F{job} : (99,2,2,99,99,1,99,99,99,0,1)[$cstate];

 $sel_job='<select size=1 name=job><option value=99>Иной вид работ</option>';
 $sel_job.="<option value=$_".($_==$job && ' selected').">$jobs[$_]</option>" foreach (0 .. $#jobs);
 $sel_job.='</select>';

 $left_col=$br2.&submit_a('Выдать задание').$br2.
   $sel_job.$br2.
   'Детальное описание задания:'.$br.
   &input_ta('tjob',$F{tjob},28,10).$br2.
   $client_info.$br2.
   $help;

 $i=0;
 $cols=$pr_oo? 'll' : 'L'; # если есть доступ к другим отделам - покажем колонку `отдел` иначе объединим 2 колонки в одну
 $workers='';
 $sth=&sql($dbh,"SELECT * FROM j_workers WHERE state<2".(!$pr_oo && " AND office=$Admin_office")." ORDER BY office,state,name_worker");
 while ($p=$sth->fetchrow_hashref)
   {
    $i++;
    ($post)=&Get_filtr_fields('post');
    ($id,$office,$name_worker)=&Get_fields('worker','office','name_worker');
    next if !$W->{$id}{present};
    $href=&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$id",$name_worker);
    $href="<span style='white-space:nowrap;'>$href</span>";
    $workers.=&RRow('*',$cols.'cccc',
       $pr_oo? ( $Offices{$office},$href ) : ($href),
       $post,
       "<input type=checkbox name=w$id value=1 style='border:0'>",
       "<input type=checkbox name=j$id value=1 style='border:0'>",
       (!!$W->{$id}{has_jobs} && &ahref("$scrpt&act=showjob&id=-$id",'На задании')).
         ($W->{$id}{has_jobs}>1 && "$br<span class=error>&gt; 1 задания</span>")
    );
   }

 if ($workers)
   {
    $workers=&Table('tbg1',&RRow('head','Ccc c','Работник','Должность','О','','Комментарий').$workers);
   }
    else
   {
    $workers=&MessX(&div('story',
      $i? 'Ни один работник не зарегистрирован вышедшим на работу. Необходимо оформить начало трудового дня.'.$br2.
             &ahref("$scrpt0&a=oper&act=workers",'Оформление выходов') :
          'В доступных отделах нет ни одного работника в состоянии не уволен и не в отпуске'
    ));
   }

 $i=0;
 $out='';
 $tt=timelocal(0,0,5,$day_now,$mon_now-1,$year_now);
 @days=('<span class=error>воскресенье</span>','понедельник','вторник','среда','четверг','пятница','суббота');
 foreach ('день','дня','дня','дня','дней','дней','дней')
   {
    $tt=$tt+3600*24; # + сутки вперед
    $i++;
    $out.=&RRow('','llll',
        "<input type=radio name=add value=$i>",
        "+$i $_:",
        &the_date($tt),
        @days[localtime($tt)->wday]
    );
   }

 ($mon_list,$mon_name)=&Set_mon_in_list($mon_now);
 $right_col.=&div('row1 lft pddng','Если не выбран ни один работник - будет подготовлен бланк задания на будущее. '.
    'В таком случае укажите желательное время начала задания:'.$br2.
    &Table('table1',&RRow('','l l',&input_t('day',$day_now,3,3),'',"$mon_list ".&Set_year_in_list($year_now))).$br.
    &input_t('hour','',3,3).' час '.&input_t('min','',3,3).' мин'.$br2.
    'Вы можете не вводить число, а выбрать ниже из списка:'.$br.
    &Table('table1',$out)
 );

 $OUT.=&Center(&MessX(&bold($title_mess),1,0)).$spc.
   &form('!'=>1,'act'=>'setjobnow','id'=>$Fid,'idjob'=>$Fidjob,
     &Table('tbg1',&RRow('row2','ttt',$left_col,$workers,$right_col))
   ).$br2;
}
  
sub setjobnow
{
 ($client_info,$cstate)=&get_users_data($Fid);
 $reason='';
 foreach $id (keys %$W)
   {
    next if !$pr_oo && $W->{$id}{office}!=$Admin_office;
    $h=$F{"w$id"}? ",-$id": $F{"j$id"}? ",$id" : '';
    next unless $h;
    $reason && $office!=$W->{$id}{office} && &Error("Задание не может быть выдано работникам из разных отделов.$go_back",$tend);
    $office=$W->{$id}{office};
    $reason.=$h;
   }

 $office=$Admin_office unless $reason; # если на задание не выделено ни одного работника, то задание приписывается к отделу в котором работает админ

 $Fjob=int $F{job};
 $Ftjob=&trim(&Filtr_mysql($F{tjob}));
 $Fjob==99 && $Ftjob eq '' && &Error("Для задания `иной тип работ` необходимо заполнить поле `детальное описание задания`.$go_back",$tend);

 if ($reason)
   {# работники указаны - это задание, а не будущее задание (бланк)
    $tt='unix_timestamp()';
   }else
   {# бланк задания, получим время активации задания
    $add=int $F{add};
    if ($add>0)
      {# выбрана не дата, а смещение в днях
       $day=$day_now;
       $mon=$mon_now;
       $year=$year_now;
      }else
      {
       $day=int $F{day};
       $mon=int $F{mon};
       $year=int $F{year};
       $add=0;
      }

    eval{$tt=timelocal(0,$F{min} eq ''? localtime($t)->min : int $F{min},int $F{hour}||localtime($t)->hour,$day,$mon-1,$year)};
    $@ && &Error("Бланк задания не подготовлен т.к. дата задана неверно.$go_back",$tend);
    $tt+=$add*3600*24; # плюс заказанных суток вперед
    $tt<($t-120) && &Error("Бланк задания не подготовлен т.к. рекомендованное время начала задания некорректно либо указывает в прошлое.$go_back",$tend);
   } 

 # В sql не использовать $Apay_sql т.к. выше может подменяться отдел
 $sql="mid=$Fid,reason='$Fjob$reason',coment='$Ftjob',time=$tt,office=$office,admin_id=$Admin_id,admin_ip=INET_ATON('$ip')";
 $rows=$Fidjob? # перевод бланка задания в выполнение задания
    &sql_do($dbh,"UPDATE pays SET $sql WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1") :
    &sql_do($dbh,"INSERT INTO pays SET $sql,category=460,type=50,cash=0");

 $rows<1 && &Error("Задание работникам не выдано - внутренняя ошибка.$go_back",$tend);

 $out=&div('big',$reason? 'Задание работникам выдано' : 'Бланк задания подготовлен');
 $out.=!!$Fid && $br.&Center(&div('nav',&ahref("$scrpt0&a=user&id=$Fid",'Данные клиента').
       &ahref("$scrpt0&a=operations&act=print&id=$Fid",'Бланк настроек')));
 &OkMess($out);
}

sub deljob
{# удаление задания (только если это бланк задания)
 $pr_workers_work or &Error("Нет прав на выдачу/закрытие/отмену заданий работников.$go_back",$tend);
 $p=&check_del_job;
 $id=$p->{mid};
 if ($id)
   {
    $U=&Get_users($id);
    $grp=$U->{$id}{grp};
    defined($grp) or &Error("Задание id=$Fidjob связано с несуществующим клиентом. Необходимо вмешательство главного администратора.$go_back",$tend);
    $UGrp_allow{$grp} or &Error("Клиент находится в группе, доступ к которой вам запрещен. Задание не может быть отменено.$go_back",$tend);
   } 
 ($job,@workers)=split /,/,$p->{reason};
 $#workers>=0 && &Error("Задание не может быть удалено т.к. оно уже выдано работникам. Вы можете только отменить его.$go_back",$tend);
 $rows=&sql_do($dbh,"DELETE FROM pays WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1");
 &Error("Задание не удалено - ошибка при выполнении sql-запроса. Возможно пока вы вводили данные другой админ произвел операции с данным заданием.$go_back",$tend) if $rows<1;
 &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=2,time=unix_timestamp(),fid=$Fidjob,adm=$Admin_id",'В таблице изменений зафиксируем, что задание удалено');
 &OkMess(&div('big','Задание удалено'));
}

sub check_del_job
{
 my $p=&sql_select_line($dbh,"SELECT p.*,a.admin FROM pays p LEFT JOIN admin a ON a.id=p.admin_id WHERE p.id=$Fidjob AND p.type=50 AND category=460 LIMIT 1");
 return($p) if $p;
 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$Fidjob");
 $p && &Error("Задание id=$Fidjob уже помечено как выполненное.$go_back",$tend);
 $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='pays' AND act=2 AND fid=$Fidjob",'удалялось ли задание');
 $p or &Error("Задания id=$Fidjob не существует.$go_back",$tend);
 $tt=&the_short_time($p->{time},$t);
 &Error(($tt=~/ /? $tt : "Сегодня в $tt")." задание № $Fidjob было удалено.",$tend);
}

sub endjob
{ 
 $p=&check_del_job;
 $mid=$p->{mid};
 ($job,@workers)=split /,/,$p->{reason};
 $out='';
 foreach $w (@workers)
   {
    $wid=abs int $w;
    next unless $W->{$wid}{name};
    !$pr_oo && $W->{$wid}{office}!=$Admin_office && &Error("Вы не можете закрыть задание, поскольку его выполняет по крайней мере один работник из чужого отдела. ".
       "Завершить задание может администратор из этого отдела (если у него есть доступ к учетной записи клиента) либо администратор с правами работы со всеми отделами.",$tend);
    $out.=&RRow('*','lc',
       $W->{$wid}{url}.($w<0 && ' (ответственный)'),
       "<input type=checkbox name=w$wid value=1>"
    );
   }

 $out=&Table('tbg1',&RRow('head','cc','Работник','Есть ли замечания').$out).$br if $out;
 $out.='Комментарий к выполненной работе:'.$br.
   &input_ta('coment','',40,8);

 $joblevel='Оценка выполнения работы:'.$br2.'<select size=1 name=level>';
 $joblevel.="<option value=$_>$joblevel[$_]</option>" foreach (0..$#joblevel);
 $joblevel.='</select>';

 if ($mid)
   {
    ($userinfo)=&ShowUserInfo($mid);
    $userinfo="Данные клиента, с которым связано задание:".$br2.$userinfo.$br2;
   }else
   {
    $userinfo='';
   }

 $OUT.=$br.&div('message cntr',&bold_br('Закрытие задания').$br2.
     &form('!'=>1,'act'=>'endjobnow','idjob'=>$Fidjob,
       &Center(&Table('',&RRow('','t t',$out,'',$userinfo))).
       $joblevel.$br2.
       &submit_a('Закончить выполнение задания').$br2
   )
 );
}

sub endjobnow
{
 $p=&check_del_job;
 $mid=$p->{mid};
 $time=$t-$p->{time};
 $h=int $F{level};
 $h=0 if $h<0;
 # работники, которым стоит галка `замечание`
 $h.=(!!$F{"w$_"} && ",$id") foreach (keys %$W);

 $reason=$p->{reason};
 $h="$reason#$time,$p->{time},$h";
 $coment="Админ, выдавший задание: ".&Filtr($p->{admin})."\n";
 $coment.="Комментарий при постановке задания: ".&Filtr_mysql($p->{coment})."\n\n" if $p->{coment};
 $coment.="Комментарий при принятии работы: ".&Filtr_mysql($F{coment}) if $F{coment};

 # ставим полное условие на случай если после запроса параллельно кто-то дал команду закончить задание
 $rows=&sql_do($dbh,"UPDATE pays SET category=461,admin_id=$Admin_id,admin_ip=INET_ATON('$ip'),reason='$h',coment='$coment',time=$t WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1");
 $rows<1 && &Error("Задание не отмечено как завершенное. Возможно пока вы вводили данные другой админ завершил выполнение задания, либо удалил его.$go_back",$tend);
 &OkMess(&div('big','Задание работников отмечено как завершенное'));

 $out='';
 {
  $mid or last;
  # данные клиента для которого завершено задание
  ($userinfo,undef,$mId)=&ShowUserInfo($mid);
  $mId or last;
  $out.=$userinfo.$br2;
  $U=&Get_users($mid);
  defined $U->{$mid}or last;
  $cstate=$U->{$mid}{cstate};
  $comment=$U->{$mid}{comment};
  $filtr_comment=&Show_all($comment);

  $h='';
  $h.='Текущий комментарий к учетной записи клиента:'.$br.&div('message lft',$filtr_comment).$br if $filtr_comment;
  $h.='Текущее состояние записи: '.&bold($cstates{$cstate}).$br2 if $cstates{$cstate};
  $out=&Table('',&RRow('','t t',$out,'',$h)) if $h;
  $out='Задание было связано с клиентом:'.$out;
  # Предложим админу изменить состояние записи (если есть права) исходя из того, если
  # $cstate=9 - клиент на подключении, перевести в 'настроить', все остальные состояния перевести во 'все ок'
  #  79 - состояние клиента, 86 - изменение комментария
  if ($pr_edt_usr && $PR{79} && $PR{86})
    {
     $h=$cstate==9? 5:0;
     $cstate='<select name=cstate size=1>';
     $cstate.="<option value=$_".($_==$h && ' selected').">$cstates{$_}</option>" foreach (sort {$cstates{$a} cmp $cstates{$b}} keys %cstates);
     $cstate.='</select>';
     $out.=&form('!'=>1,'act'=>'setcstate','id'=>$mid,
        "Перевести учетную запись клиента в состояние $cstate".$br2.
        'и установить комментарий:'.$br2.
         &input_ta('comment',$comment,70,6).$br2.
         &submit_a('Выполнить')
        ).$br2;
     }
  $OUT.=&div('message lft',$out);   
 }   

 # если для какого либо работника параллельно выполняется задание, то для этого задания поставим время как будто оно только что было поставлено
 $i=0;
 %changed=();
 ($job,@workers)=split /,/,$reason;
 foreach $w (@workers)
   {
    $wid=abs int $w;
    $sth=&sql($dbh,"SELECT id FROM pays WHERE type=50 AND category=460 AND (reason LIKE '%,$wid,%' OR reason LIKE '%,-$wid,%' OR reason LIKE '%,$wid' OR reason LIKE '%,-$wid')");
    while ($p=$sth->fetchrow_hashref)
      {
       $id=$p->{id};
       next if $changed{$id};
       $changed{$id}++;
       $i++;
       &sql_do($dbh,"UPDATE pays SET time=$t WHERE id=$id LIMIT 1");
      }
   }

 $OUT.=&div('message lft',$br."<span class=error>Внимание!</span> Работники, которые закончили текущее задание, выполняют параллельно еще ".
   &bold($i)." заданий. Для всех этих работ устанавливаю текущее время постановки задания".$br2) if $i;
}

# ===========================
# установка состояние клиента
# ===========================
sub setcstate
{
 &Error('У вас нет прав на изменение состояния клиента.',$tend) if !$pr_edt_usr || !$PR{79} || !$PR{86}; # 79 - изменение состояния, 86 - комментария

 $U=&Get_users($Fid);
 defined($U->{$Fid}) or &Error("Не удалось получить данные клиента с id=$Fid. Состояние не изменено. Переведите в нужное состояние вручную.",$tend);
 $UGrp_allow{$U->{$Fid}{grp}}<2 && &Error("Клиент находится в группе, доступ к которой вам запрещен (ограничен). Состояние клиента не изменено.",$tend);

 $cstate=int $F{cstate};
 $comment=&Filtr_mysql($F{comment});
 $X="Администратор перевел абонента в состояние: ".&Filtr_mysql($cstates{$cstate});
 $X.="\n".($comment? "Комментарий изменен на: $comment":"Комментарий удален");
 $rows=&sql_do($dbh,"UPDATE users SET cstate=$cstate,comment='$comment' WHERE id=$Fid LIMIT 1");
 $rows<1 && &Error("Состояние клиента не изменено - внутренняя ошибка.Измените состояние вручную.",$tend);

 &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,type=50,reason='$X',category=410,time=$ut");

 &OkMess('Состояние клиента изменено в '.&bold($cstates{$cstate}).$br2.&CenterA("$scrpt0&a=user&id=$Fid",'Данные клиента'));
}
  
sub showjob
{
 $out=&nJob_ShowJobBlank($F{id},$F{mod}); # int параметров не надо - undef имеет значение
 if ($Fid<0)
   {
    $wid=-$Fid;
    $OUT.=&div('message',"Работы, которые в данный момент проводит ".
      &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",'работник '.$nJob_W->{$wid}{name}));
   }else
   {
    $U=&Get_users($Fid) if $Fid;
    $OUT.=&div('message',(!!$Fid && 'Для клиента '.&ahref("$scrpt0&a=user&id=$Fid",$U->{$Fid}{fio_o}).$br).(
      $F{mod}==-1? "Все работы, которые выполняются в данный момент" :
      $F{mod}==-2? "Подготовленные задания на будущее" :
      defined($F{mod})? "Подготовленные задания типа ".&commas($jobs[int $F{mod}]) :
      "Все текущие и подготовленные задания")
    );
   }
 $out or &Error('Не найдено.',$tend);
 $OUT.=$out;
}  

# ===============================================
# Приход/уход в офис (начало/конец трудового дня)
# ===============================================

sub come
{
 $pr_worker_come or &Error("Вам не разрешено регистрировать начало/окончание трудового дня работника.$go_back",$tend);
 &check_access_2worker($Fid);

 $direction=int $F{direction};
 @name_direction=$direction? ('окончание','окончания','закончил'):('начало','начала','начал');

 $W->{$Fid}{present} && !$direction && &Error("Работник $W->{$Fid}{url} уже зарегистрирован вышедним на работу ".&the_time($W->{$Fid}{come_time}).$go_back,$tend);
 !$W->{$Fid}{present} && $direction && &Error("Работник $W->{$Fid}{url} не зарегистрирован как вышедшим на работу, поэтому вы не можете оформить окончание трудового дня.$go_back",$tend);
 $W->{$Fid}{has_jobs} && $direction && &Error("Работник $W->{$Fid}{url} в данный момент на задании, необходимо сперва оформить окончание задания, потом окончание трудового дня.".$br2.
    &ahref("$scrpt0&a=job&act=showjob&id=-$Fid",'Показать задания работника').$go_back,$tend);

 ($office)=&Get_fields('office');

 if ($F{yes})
   {
    $category=$direction? 466:465;
    $tt=int $F{time};
    $tt=10 if $tt<0 ||$tt>10; # не мухлевать
    $tt*=60;
    if (defined($W->{$Fid}{come_time}) && $W->{$Fid}{come_time}>=($t-$tt))
      {# попытка оформить приход/уход хронологически ДО завершения/начала предыдущего действия
       $tt=0;
       $OUT.=&div('message',&bold('Предупреждение:')." вы пытаетесь оформить $name_direction[0] рабочего дня временем ранним чем последняя регистрация начала или окончание трудового дня. Время установлено в текущее значение.").$br;
      }
    $reason=&trim(&Filtr_mysql($F{comment}));
    $rows=&sql_do($dbh,"INSERT INTO pays SET mid=-$Fid,type=50,$Apay_sql,category=$category,reason='$reason',coment='',cash=0,time=unix_timestamp()-$tt");
    $rows<1 && &Error("Регистрация $name_direction[1] трудового дня работника $W->{$Fid}{url} не выполнена.",$tend);
    &OkMess("Регистрация $name_direction[1] трудового дня работника $W->{$Fid}{url} выполнена.".$br2.
            "Через 10 секунд произойдет переход на страницу просмотра списка работников.",$tend);
    $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$scrpt0&a=oper&act=workers"'>};
    return;
   }

 $timelist='<select size=1 name=time><option value=0>в данный момент</option>';
 foreach $i ('1у','2ы','3ы','4ы','5&nbsp;&nbsp;&nbsp;','7&nbsp;&nbsp;&nbsp;','10 ') {$i=~/^(\d+)(.+)$/; $timelist.="<option value=$1>$1 минут$2&nbsp;назад (".&the_time($t-$1*60).")</option>"}
 $timelist.="</select>";

 $OUT.=&div('message cntr',$br2.&form('!'=>1,'act'=>'come','direction'=>$direction,'yes'=>1,'id'=>$Fid,
   "Работник $W->{$Fid}{url} $name_direction[2] трудовой день $timelist".$br2.
   'Необязательный комментарий:'.$br.&input_ta('comment','',70,4).$br2.
   &submit_a('Подтвердить').$br2));

 $OUT.=$br2.&div('message','Комментарий: '.($direction? 'работник начал':'последний раз работник закончил').
       ' трудовой день '.&bold(&the_time($W->{$Fid}{come_time}))) if defined($W->{$Fid}{come_time});
}

# ================

sub Show_time_line
{
 $out.=&RRow('*','lclrl',$wday,$last_day,$t_list,&the_hh_mm(int $t_work/60),$reason);
 $t_work=0;
 $t_list='';
 $reason='';
}

sub Add_time
{
 my $t_add=$t_end-$t_start;
 $t_work+=$t_add;
 $sum_time+=$t_add;
 $t_list.=&the_hour($t_start).' - '.&the_hour($t_end).$br;
}

# === История посещений и работ ===
sub history
{
 &check_access_2worker($Fid);

 $mon=int $F{mon} || $mon_now;
 $year=int $F{year} || $year_now;
 ($mon_list,$mon_name)=&Set_mon_in_list($mon);
 $year_list=&Set_year_in_list($year);

 $t1=timelocal(0,0,0,1,$mon-1,$year);				# начало месяца
 $t2=timelocal(0,0,0,1,$mon>11?0:$mon,$mon>11?$year+1:$year)-1;	# конец месяца

 $OUT.=&MessX(&form_a('act'=>$F{act},'id'=>$Fid)."История работ $W->{$Fid}{url} за $mon_list $year_list <input type=submit value='показать'></form>").$br;

 $last_day=0;
 $t_last=0;
 $t_start=0;
 $h=0;
 $err_mess='';
 $sum_time=0;
 $work_day=0;
 $out='';
 $reason='';
 $sth=&sql($dbh,"SELECT * FROM pays WHERE mid=-$Fid AND type=50 AND category IN (465,466) AND time>$t1 AND time<$t2 ORDER BY time");
 while ($p=$sth->fetchrow_hashref)
   {
    $tt=$p->{time};
    $category=$p->{category};
    if ($category==$h)
      {
       $err_mess.="Внимание. Ошибка в данных. ".&the_time($tt).($h==465? ' оформлено начало трудового дня без окончания предыдущего':' оформлено окончание трудового дня без его начала').$br;
      }

    $t1=localtime($tt);
    $day=$t1->mday;
    if ($day!=$last_day)
      {
       if ($h==3)
         {# новый день, а в прошлом не оформлен уход. Считаем, что прошлый трудовой день окончился в  23:59
          $t_end=timelocal(59,59,23,$last_day,$mon-1,$year);
          &Add_time;
          $t_start=timelocal(0,0,0,$day,$mon-1,$year);
         }
       &Show_time_line if $last_day;
       $last_day=$day;
      }
    $h=$category;
    $wday=('<span class=error>воскресенье</span>','понедельник','вторник','среда','четверг','пятница','<span class=error>суббота</span>')[$t1->wday];

    if ($h==465)  
      {# выход на работу
       $t_start=$tt;
       next;
      }

    # уход с работы
    unless ($t_start)
      {# нет выхода на работу в этом дне - вероятно был в предыдущий (или даже ранее, если бардак в сети). Считаем, что день начался в 0 часов
       $t_start=timelocal(0,0,0,$day,$mon-1,$year);
      }
    $t_end=$tt;
    $reason.='(в '.&the_hour($tt).') '.&Show_all($p->{reason}).$br2 if $p->{reason};
    &Add_time;
   }

 if ($category==465)
   {# работник вышел на работу (неважно в какой день) и работает до сих пор
    $t_list.=&the_hour($tt).' -&nbsp;&nbsp;...';
    $OUT.='Комментарий: в данный момент работник числится на работе. Время за последний выход будет отображено после того как вы оформите окончание трудового дня.'.$br2;
   } 
 &Show_time_line if $last_day;
 $OUT.="<table class='width100'><tr><$tc valign=top>";
 if ($out)
   {
    $OUT.="<table class='tbg3 width100'>".
      &RRow('head','ccccc','День недели','День','Начало - Окончание','Общее время','Комментарий').$out.
      &RRow('head',' Lr ','','Итого',&the_hh_mm(int $sum_time/60),'').'</table>';
   } else
   {
    $OUT.=&MessX('Нет данных посещаемости за выбранный месяц',1)
   }   
 $OUT.=$err_mess;  
#    "<tr class=head><td colspan=3>Итого рабочих дней</td><td>$work_day</td></tr></table>"  
# $OUT.="</td><$tc valign=top>";

 push @jobs,'иной вид работ';
 $other_job_num=$#jobs; # индекс 'иной вид работ'
 $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=461 ORDER BY time"); # список завершенных заданий
 $sth->execute;
 while ($p=$sth->fetchrow_hashref)
   {
    ($w1,$w2)=split /#/,$p->{reason};
    $w1.=',';
    next if $w1!~/,$Fid,|,-$Fid,/;
    @workers=split /,/,$w1;
    $job=shift @workers;
    $job=$other_job_num unless $jobs[$job]; # если вид работ отсутствует в списке, считаем 'иной вид работ'
    $n=$#workers; # количество работников в задании -1
    $Job{$job}++;
    $w2=~/^(\d+),(\d+),(\d+)(.*)$/;
    $w3=$1; # время выполнения работы
    $w4=$2; # время постановки задания
    $w5=$3; # оценка выполнения работы
    $w2="$4,";
    #  $OUT.=$p->{'id'}." === ".$p->{'reason'}."<br>w2=$w2  w3=$w3<br>";
    $Job_kill{$job}++ if $w2=~/,$Fid,/; # работнику есть замечание
    if ($w5==5)
       {# задание было отменено
        $Job_3{$job}++;
        $Job_3time{$job}+=$w3;
       }
        elsif ($n)
       {# задание выполнял не один
        $Job_2{$job}++;
        $Job_2time{$job}+=$w3;
       }
        else
       {# задание выполнял он сам
        $Job_1{$job}++;
        $Job_1time{$job}+=$w3;
       }
    $Job_rez[$w5]++;
    $Job_time[$w5]+=$w3;
   }
 $OUT.=$br."<table class='tbg3 width100'>";    
 $OUT.="<tr class=head><$tc>Вид заданий</td><$tc colspan=2>Выполнял самостоятельно</td><$tc colspan=2>Выполнял в бригаде</td><$tc colspan=2>Отмененные задания</td><$tc>Количество замечаний</td></tr>";
 $OUT.="<tr class=head><td>&nbsp;</td><$tc>заданий</td><$tc>общее время</td><$tc>заданий</td><$tc>общее время</td><$tc>заданий</td><$tc>общее время</td><td>&nbsp;</td></tr>";
 $n=-1;
 foreach $job (@jobs)
   {
    $n++;
    $Job{$n} or next;
    $j1=$Job_1{$n}+0;
    $j2=$Job_2{$n}+0;
    $j3=$Job_3{$n}+0;
    $t1=$Job_1time{$n}+0;
    $t2=$Job_2time{$n}+0;
    $t3=$Job_3time{$n}+0;
    $jk=$Job_kill{$n}+0;
    $OUT.=&PRow."<td>$job</td><$tc>$j1</td><$tc>".int($t1/3600).":".($t1/60 % 60)."</td><$tc>$j2</td><$tc>".int($t2/3600).":".($t2/60 % 60)."</td><$tc>$j3</td><$tc>".int($t3/3600).":".($t3/60 % 60)."</td><$tc>$jk</td></tr>";
    $j1s+=$j1; $j2s+=$j2; $j3s+=$j3;
    $t1s+=$t1; $t2s+=$t2; $t3s+=$t3;
    $jks+=$jk;
   }
 $OUT.="<tr class=head><td>Сумма".
     "</td><$tc>$j1s</td><$tc>".int($t1s/3600).":".substr('0'.($t1s/60 % 60),-2,2).
     "</td><$tc>$j2s</td><$tc>".int($t2s/3600).":".substr('0'.($t2s/60 % 60),-2,2).
     "</td><$tc>$j3s</td><$tc>".int($t3s/3600).":".substr('0'.($t3s/60 % 60),-2,2).
     "</td><$tc>$jks</td></tr>";
 $OUT.="</table>";   
 $OUT.=$br."<table cellpadding=2 cellspacing=1 class=tablebg>";    
 $OUT.="<tr class=head><$tc>Всего выполненных заданий</td><$tc>Общее время выполнения</td><$tc>Среднее время выполнения одного задания</td></tr>";
 $ts=$t1s+$t2s;
 $js=$j1s+$j2s;
 $OUT.="<tr class=row1><$tc>$js</td><$tc>".int($ts/3600).":".substr('0'.($ts/60 % 60),-2,2)."</td><$tc>";
 $OUT.=$js ? int($ts/$js/3600).":".substr('0'.($ts/$js/60 % 60),-2,2) : '0:00';
 $OUT.="</td></tr>";
 $OUT.="<tr class=head><td colspan=3>Комментарий: отмененные задания не попали в статистику</td></tr>" if $t3s;
 $OUT.="</table>";   
 $OUT.=$br."<table cellpadding=2 cellspacing=1 class=tablebg>";    
 $OUT.="<tr class=head><$tc>Результат выполнения задание</td><$tc>Количество заданий</td><$tc>Время выполнения</td></tr>";
 $i=-1;
 foreach $w5 (@Job_rez)
   {
    $i++;
    next unless $w5;
    $OUT.=&PRow."<td>".($joblevel[$i] || '<b>неизвестно!</b>')."</td><td>$w5</td><$tc>".int($Job_time[$i]/3600).":".($Job_time[$i]/60 % 60)."</td></tr>";
   }
 $OUT.='</table>';
 $OUT.='</td></tr><table>';  
}

# =============================================
sub grafik
{
 $t1=timelocal(0,0,0,1,$mon-1,$year); # начало месяца
 $t2=timelocal(0,0,0,1,$mon>11?0:$mon,$mon>11?$year+1:$year)-1; # конец месяца

 $OUT.="<div class=message>".($mod>1?'История выполенных заданий':$mod?'Задания, выполняющиеся в текущий момент':'График подготовленных заданий').'</div>';
 $h=$mod>1?461:460;
 $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=$h AND time>=$t1 AND time<=$t2");
 $sth->execute;
 %Jobs=();
 while ($p=$sth->fetchrow_hashref)
   {
    ($mid,$workers,$tt)=Get_fields('mid','reason','time');
    ($job,@workers)=split /,/,$workers;
    next if $#workers>=0 && !$mod; # заказан вывод бланков, а это выполняющееся задание
    next if $#workers<0 && $mod==1; # заказан вывод выполняющихся заданий, а это бланк задания
    $tt=localtime($tt);
    $min=$tt->min;
    # бреобразуем время задания так, чтобы оно было кратно четверти часа
    $min=$min>45?45 :$min>30?30 :$min>15?15: 0;
    $tt=timelocal(0,$min,$tt->hour,$tt->mday,$tt->mon,$tt->year);
    $Jobs{$job}{$tt}++; # количество заданий в определенную четверть часа
   }

 $tt=localtime($t2);
 $day=$mon==$mon_now && $year==$year_now? $day_now : $tt->mday;
 $min=localtime($t)->min;
 $min=$min>45?45 :$min>30?30 :$min>15?15: 0; # текущие минуты кратные 15
 $red_time=timelocal(0,$min,localtime($t)->hour,$day_now,$mon_now-1,$year_now); # текущее время, которое надо вадо выделить красным цветом
 $max_job=$#jobs;
 $max_day=&GetMaxDayInMonth($mon,$year); # дней в месяце
 while ($day>0 && $day<=$max_day) 
   {
    $tt=timelocal(0,0,0,$day,$mon-1,$year); # Начало суток
    $wday=('<span class=error>воскресенье</span>','понедельник','вторник','среда','четверг','пятница','суббота')[localtime($tt)->wday];
    $i=24*4; # 24 часа по четыре периода в часе
    $OUT.="<table class='tbg1 width100'><tr class=tablebg><$tc colspan=".($i+1).">$wday <b>$day</b> $mon_name</td></tr><tr class=head><td>Час</td>";
    $OUT.="<$tc colspan=4>$_</td>" foreach (0..23);
    $OUT.='</tr>';
    %out=();
    while ($i--)
      {
       $j=0;
       foreach (@jobs,'')
         {
          $job=$j<=$max_job? $j:99;
          $out{$job}.=($red_time!=$tt?'<td>':'<td class=rowoff2>').($Jobs{$job}{$tt}||'&nbsp;').'</td>';
          $j++;
         }
       $tt+=900; # шаг 15 минут
      }

    $j=0;    
    foreach (@jobs,'Иной вид работ')
      {
       $job=$j<=$max_job? $j:99;
       $OUT.="<tr><td><b>$_</b></td>$out{$job}</tr>";
       $j++;
      }
    $OUT.='</table>'.$br;
    $day=$mod? $day-1:$day+1;
   }  
}

sub grafik_menu
{
 &workers_menu;
 $mod=int $F{mod};
 $mon=int $F{mon} || $mon_now;
 $year=int $F{year} || $year_now;
 ($mon_list,$mon_name)=&Set_mon_in_list($mon);
 $year_list=&Set_year_in_list($year);
 $OUT.=&Mess3('row2',
   &form('act'=>'grafik','mod'=>$mod,'График за'.$br.$mon_list.' '.$year_list.' '.&submit('OK')).$br.
   &ahref("$scrpt&act=grafik&mod=0&mon=$mon&year=$year",'Подготовленные').
   &ahref("$scrpt&act=grafik&mod=1&mon=$mon&year=$year",'Выполняющиеся').
   &ahref("$scrpt&act=grafik&mod=2&mon=$mon&year=$year",'Выполненные')
 );
}

1;
