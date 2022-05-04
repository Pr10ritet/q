#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> 'данных работника',
	'tbl'		=> 'j_workers',
	'field_id'	=> 'worker',
	'priv_show'	=> $pr_workers,
	'priv_edit'	=> $pr_workers_edit,
};

sub o_menu
{
 &LoadJobMod;
 $W=&Get_workers();		# список работников
 &nJob_present_workers($W);	# пометим тех, кто вышел на работу
 $out=&ahref($scrpt,'Все работники');
 $out.=&ahref("$scrpt&op=new",'Новый работник') if $pr_workers_edit;
 $out.=&ahref("$scrpt0&a=job&act=showjob&mod=-1",'Текущие задания');
 $out.=&ahref("$scrpt0&a=job&act=setjob",'Выдать задание') if $pr_workers_work;
 $out.=&ahref("$scrpt0&a=job&act=grafik",'График');

 $out.=$br.&div('tablebg',&form('act'=>$Fact,&input_t('text',$F{text},20,80).' '.&submit('Поиск'))).$br;
 if ($pr_oo)
   {# есть право на работу с чужими отделами
    $Foffice=int $F{office};
    $out.=&div('tablebg',&form('act'=>$Fact,&Get_Office_List($Foffice||$Admin_office).' '.&submit('Отдел'))).$br;
   }

 return $out;
}

sub o_list
{
 $out='';
 $url=$scrpt;
 $Foffice=int $F{office};
 $txt=$F{text};
 $txt2=$txt;
 $txt2=~tr/qwertyuiop[]asdfghjkl;'zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>/йцукенгшщзхъфывапролджэячсмитьбюЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ/;
 $txt=&Filtr_mysql($txt);
 $txt2=&Filtr_mysql($txt2);
 $sql="SELECT * FROM j_workers WHERE 1";
 if ($txt) 
   {
    $url.='&text='.&URLEncode($F{text});
    $sql.=" AND (name_worker LIKE '%$txt%' OR contacts LIKE '%$txt%' OR name_worker LIKE '%$txt2%' OR contacts LIKE '%$txt2%')";
   }
 # нет права на работу с чужими отделами?
 $sql.=!$pr_oo? " AND office=$Admin_office" : defined $F{office}? " AND office=$Foffice" : '';
 $sql.=" ORDER BY office,state,name_worker";
 $url.="&office=$Foffice" if $pr_oo && defined $F{office}; 
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,50,$url);
 while ($p=$sth->fetchrow_hashref)
   {
    ($state,$id,$office,$name_worker)=&Get_fields('state','worker','office','name_worker');
    ($post)=&Get_filtr_fields('post');
    $uvolen=($state==3);
    $worker_come= !$pr_worker_come? '' :
                $W->{$id}{present}? &ahref("$scrpt0&a=job&act=come&direction=1&id=$id",'закончить') :
                                    &ahref("$scrpt0&a=job&act=come&id=$id",'начать');
    $has_job=$W->{$id}{has_jobs} && &ahref("$scrpt0&a=job&act=showjob&id=-$id",'На задании').
      ($W->{$id}{has_jobs}>1 && $br.'<span class=error>больше одного задания</span>');

    $out.=&RRow($uvolen? 'rowoff':'*','cclcclccc',
       $W->{$id}{present} && &div('rowsv pddng2','присутствует'),
       $worker_come,
       $name_worker,
       $has_job,
       $post,
       $uvolen? '<span class=disabled>уволен</span>' :
         $state==2? '<span class=data2>в отпуске</span>' :
         $state==1? '<span class=data1>стажируется</span>' : '',
       $Offices{$office},
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       ($pr_workers_edit && &ahref("$scrpt&op=del&id=$id",'X'))
    );
   }

 &Error('В базе данных нет ни одного работника.'.$br2.&ahref("$scrpt&op=new",'Внести'),$tend) if !$out && !$txt && !(defined $F{office});
 $out or &Error('По заданному фильтру работники не найдены.',$tend);

 $page_buttons&&=&RRow('head','9',$page_buttons);

 $OUT.=&Table('tbg3 width100',
     $page_buttons.
     &RRow('tablebg','ccccccccL','Состояние','Трудовой'.$br.'день','Имя','Задание','Должность','Статус','Отдел','').
     $out.
     $page_buttons);
}

sub o_new
{
 $contacts=$name_worker=$post='';
 $state=0;
 $menu='&nbsp;';
 $office=$Admin_office; # по умолчанию отдел, в котором работает работник, будет равен отделу админа
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$Fid LIMIT 1");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных работника с id=$Fid",$tend);

 !$pr_oo && $p->{office}!=$Admin_office && &Error("Работник с номером $id работает в отделе отличном от вашего. Доступ запрещен.$go_back",$tend);

 ($name_worker,$contacts,$post)=&Get_filtr_fields('name_worker','contacts','post');
 ($state,$office)=&Get_fields('state','office');
 $menu='';
 $menu.=$W->{$Fid}{present}? &ahref("$scrpt0&a=job&act=come&direction=1&id=$Fid",'Закончить день') :
     &ahref("$scrpt0&a=job&act=come&id=$Fid",'Начать день');
 $menu.=&ahref("$scrpt0&a=payshow&mid=-$Fid",'История зарплат').
        &ahref("$scrpt0&a=payshow&nodeny=sworker&mid=-$Fid",'История событий') if $pr_worker_pays_show;
 $menu.=&ahref("$scrpt0&a=pays&mid=-$Fid",'Выдать зарплату') if $pr_worker_pays_create;
 $menu.=&ahref("$scrpt0&a=job&act=history&id=$Fid",'История работ/посещений');
 
 if ($PR{103})
 {  # оборудование
    $h=&sql_select_line($dbh,"SELECT COUNT(parent_id) AS n FROM dopdata WHERE ".
      "WHERE parent_type=1 AND field_type=7 AND field_value='2:$Fid' GROUP BY parent_id",
      'Оборудование, которое числится на работнике');
    $menu.=&ahref("$scrpt0&a=equip&act=find&owner_type=2&owner_id=$Fid",$h->{n}.' единиц оборудования').$br if $h && $h->{n};
 }

 $W->{$Fid}{present} && ($d->{no_delete}='он числится вышедшим на работу.');
 &sql_select_line($dbh,"SELECT * FROM pays WHERE mid=-$Fid AND type=10 LIMIT 1") &&
    ($d->{no_delete}='ему выдавалась зарплата. Переведите '.&ahref("$scrpt&op=edit&id=$Fid",'работника').' в состояние `уволен`.');

 if ($W->{$Fid}{has_jobs})
   {
    $url="$scrpt0&a=job&act=showjob&id=-$Fid";
    $menu.=$br."В данный момент выполняет работы ($W->{$Fid}{has_jobs})".&ahref($url,'Показать');
    $d->{no_delete}='он в данный момент '.&ahref($url,'выполняет работу');
   }

 $d->{name}='данных работника с именем '.&commas($name_worker);
 $d->{old_data}="Отдел: ".(defined $Offices{$office}? &commas($Offices{$office}) : 'не указан').
   ', состояние: '.('работает','стажируется','в отпуске','уволен')[$state].
   ($post && ', должность: '.&commas($post));
}

sub o_show
{
 $liststate="<select size=1 name=state><option value=0>работает</option><option value=1>стажируется</option><option value=2>в отпуске</option><option value=3>уволен</option></select>";
 $liststate=~s/<option value=$state>/<option value=$state selected>/;
 if ($pr_oo)
   {# есть права на работу с чужими отделами
    $offices=&Get_Office_List($office);
   }else
   {# в любом случае в скрытом поле сохраним номер отдела т.к в момент записи права на изменения отдела могут быть даны
    $offices=&input_h('office',$office).($Offices{$office} || 'без отдела');
   }

 $out=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','Отдел',$offices).
     &RRow('*','ll','Имя',&input_t('name_worker',$name_worker,40,200)).
     &RRow('*','ll','Должность',&input_t('post',$post,40,200)).
     &RRow('*','ll','Контактная информация',"<textarea rows=8 cols=40 name=contacts>$contacts</textarea>").
     &RRow('*','ll','Состояние',$liststate).
     &RRow('head','C',$pr_workers_edit? &submit_a('Сохранить') : $go_back.$br2)
   )
 );

 $OUT.=&div('message cntr',$br.&Table('',&RRow('nav2','tt',$out,$menu)));
}

sub o_save
{
 $Fstate=int $F{state};
 $Fstate=0 if $Fstate<0 || $Fstate>3;
 $Foffice=$pr_oo? int $F{office} : $Admin_office;

 $Fcontacts=&Filtr_mysql($F{contacts});
 $Fpost=&Filtr($F{post});

 $Fname_worker=&trim($F{name_worker});
 $Fnew_name_worker=&Filtr($Fname_worker);

 $OUT.=&div('message','Из имени работника удалены недопустимые символы.') if $Fnew_name_worker ne $Fname_worker;
 if (length($Fnew_name_worker)<3)
   {
    $Fnew_name_worker="Работник $Fnew_name_worker";
    $OUT.=&div('message','Имя работника должно быть не менее трех символов. Изменено.');
   }

 $d->{sql}="contacts='$Fcontacts',name_worker='$Fnew_name_worker',post='$Fpost',state=$Fstate,office=$Foffice";

 $name_office=(defined $Offices{$Foffice}? &commas($Offices{$Foffice}) : 'не указан');
 $name_state=('работает','стажируется','в отпуске','уволен')[$Fstate];
 $_=&commas($Fnew_name_worker);
 if ($Fid)
   {# изменение, а не создание работника
    $new_data=$Fnew_name_worker ne $name_worker && "Новое имя работника: $_";
    $new_data.=($new_data && '. ')."Отдел: $name_office" if $Foffice!=$office;
    $new_data.=($new_data && '. ')."Состояние: $name_state" if $Fstate!=$state;
    $new_data.=($new_data && '. ').'должность: '.&commas($Fpost) if $Fpost!=$post;
   }else
   {
    $new_data="Имя: $_, отдел: $name_office, состояние: $name_state, должность: ".&commas($Fpost);
   }
 $d->{new_data}=$new_data;
}

1;
