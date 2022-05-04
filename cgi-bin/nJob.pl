#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nJob.pl');

# Задание работникам - запись в таблице платежей с категорией 460 (выполняется) или 461 (выполнено).
# Поле coment - комментарий к заданию
# Поле reason - закодированное задание: 
#   код_задания[,id_работника_1,id_работника_2...]
# Если перед id работника стоит минус - работник ответственный за задание, может быть несколько ответственных
# Если задание выполнено, то в конце добавляется символ #, после чего идет закодированный результат:
#   время выполнения работы,время получения задания,уровень выполнения работы[,id_работника_1,id_работника_2...]
# id работника присутствует только если ему дано замечание
#
# Пример: 2,3,-4,5
# Расшифровка: задание с кодом 2; выполяют работники 3,4,5; ответственный работник 4
#
# Если не указан ни один работник - задание считается подготовленным на будущее (бланк задания)


# Формирование карточки выполняющихся заданий
# Вход: 
# 0 - id
#  undef: все работы
#      0: только задания по сети
#     >0: только связанные с клиентом id
#     <0: только связанные с работником id
# 1 - режим 
#  undef: все
#     -1: выполняющиеся
#     -2: подготовленные
#    >=0: подготовленные задания типа работ, на которое указывает данное число
sub nJob_ShowJobBlank
{
 my($id,$mod)=@_;
 my($blank,$coment,$form,$h,$job,$out,$p,$pay_id,$sth,$tbl,$tt,$w,$where,$wid);
 my @workers;

 $h=int $id;
 $nJob_W=&Get_workers() unless defined $nJob_W;
 ($nJob_A)=&Get_adms() unless defined $nJob_A;

 $out='';

 if( $h<0 )
 {  # все задания работника, $mod игнорируем т.к подготовленные задания не связаны с работниками
    $wid='\-?'.(-$h);
    $where="AND (reason REGEXP ',$wid\$' || reason REGEXP ',$wid,')";
 }else
 {
    $job=int $mod;
    $where=defined($id)? "AND mid=$h " : '';
    $where.="AND reason LIKE '%,%'" if $mod==-1;
    $where.="AND reason NOT LIKE '%,%'" if $mod==-2;
    $where.="AND reason='$job'" if defined($mod) && $mod>=0;
 }

 $sth=&sql($dbh,"SELECT * FROM pays WHERE type=50 AND category=460 $where ORDER BY time",'nJob.pl');
 while( $p=$sth->fetchrow_hashref )
 {
    $out.=$br2 if $out;
    ($pay_id,$wid,$coment,$tt)=map {$p->{$_}} qw( id mid coment time );
    $wid=-$wid;
    ($job,@workers)=split /,/,$p->{reason};	# вид_работ, список работников выполняющих работу
    $blank=$#workers<0;				# бланк задания или выполняющееся задание?
    $tbl=$blank? &RRow('head','C','Подготовленное задание') : &RRow('rowsv','C','В данный момент ведутся работы');
    $tbl.="<tr class=row1><td width=20% class=disabled>Вид работ</td><td>".($jobs[$job]||'не указан').'</td></tr>';
    $tbl.=&RRow('row1','ll','<span class=disabled>Комментарий</span>',&Show_all($coment)) if $coment;
    if( $tt>$t )
    {  # задание на будущее
       $h=&the_short_time($tt,$t);
       # если до начала задания менее 30 минут - время выделим красным цветом
       $h=($tt-$t)<1800? "<span class='modified title'>$h</span>" : $h;		
       $tbl.=&RRow('row1','ll','<span class=disabled>Рекомендовано выполнить в</span>',$h);
    }else
    {
       $tbl.=&RRow('row1','ll','<span class=disabled>Время постановки задания</span>',&the_time($tt));
    }
    $tbl.=&RRow('row1','ll','<span class=disabled>'.($blank? 'В очереди':'Выполняется').'</span>',&the_hh_mm(($t-$tt)/60));
    $tbl.=&RRow('row1','ll','<span class=disabled>Админ, выдавший задание</span>',$nJob_A->{$wid}{admin}) if defined $nJob_A->{$wid}{admin};
    $h='';
    foreach $w (@workers)
    {
       $wid=abs int $w;				# id может быть с минусом, что означает `ответственный`
       next unless defined $nJob_W->{$wid}{name};
       $h=!$PR{26} && $nJob_W->{$wid}{office}!=$Admin_office? '<span class=error>работник недоступного вам отдела</span>':
            $PR{23}? &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$nJob_W->{$wid}{name}) : $nJob_W->{$wid}{name};
       $h.=' <span class=disabled>(ответственный)</span>' if $w<0;
       $tbl.=&RRow('row1',' l','',$h);
    }
    if( $PR{25} )
    {
       $form=&form('!'=>1,'#'=>1,'a'=>'job','idjob'=>$pay_id,($blank? 
         &input_h('act'=>'setjob','job'=>int $job,'tjob'=>$coment,'id'=>$id).&submit_a('Начать/удалить задание').$spc : 
         &input_h('act'=>'endjob').&submit_a('Завершить задание')).$spc
       );
       $tbl.=&RRow('row1','C',$form);
    }
    $out.=&Table('table1 width100 '.($blank? 'borderblue':'modified'),$tbl);
 }
 return $out;
}

# Вход: ссылка на хеш-массив работников
# Устанавливаются такие ключи:
# $W->{id}{present}		>0, если работник присутствует (в течение последние 48 часов)
# $W->{id}{come_time}		время выхода на работу
# $W->{id}{has_jobs}		количество работ, которые выполняются работником в данный момент

sub nJob_present_workers
{
 my ($W)=@_;
 my ($p,$sth,$wid);
 my @workers;
 $sth=&sql($dbh,"SELECT mid,category,time FROM pays WHERE type=50 AND category IN (465,466) AND time>(unix_timestamp()-172800) ORDER BY time DESC",
     'nJob.pl: Выходы/уходы с работы');
 while( $p=$sth->fetchrow_hashref )
 {
    $wid=$p->{mid}*-1;
    next if $wid<=0;
    next if defined $W->{$wid}{present};
    $W->{$wid}{present}=$p->{category}==465? 1:0;
    $W->{$wid}{come_time}=$p->{time};
 }
 $sth=&sql($dbh,"SELECT reason FROM pays WHERE type=50 AND category=460 ORDER BY time",'nJob.pl: Список выполняющихся работ');
 while( $p=$sth->fetchrow_hashref )
 {
    (undef,@workers)=split /,/,$p->{reason};
    $W->{abs(int $_)}{has_jobs}++ foreach (@workers);
 }
}

1;
