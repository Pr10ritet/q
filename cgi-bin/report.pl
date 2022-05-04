#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_fin_report or &Error('Для доступа недостаточно привилегий.');

&LoadMoneyMod;
&LoadPaysTypeMod;

$Ftype=int $F{type}; # тип отчета
$Fyear=int $F{year};
$Fmon=int $F{mon};

$Fmon=$mon_now if $Fmon<1 || $Fmon>12;
$Fyear=$year_now if $Fyear<100 || $Fyear>200;

$scrptf="$scrpt&mon=$Fmon&year=$Fyear";

($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
$year_list=&Set_year_in_list($Fyear);

# Сформируем список групп, включая объединения групп, с отмеченными галками
($out,$where_grp)=&List_select_grp;

#$out.='<br>';

$out2='';
$where_active=''; # условие активности клиента

$OUT.="<table class='width100'><tr><td valign=top width=22%>".
  &div('message lft',
    &form('!'=>1,'#'=>1,&bold('Финансовый отчет за').$br."$mon_list $year_list".$br2.&submit_a('Показать').
      $br2.'Для групп:'.$br2."<div id=grp>$out</div>".$br
    )
  )."</td><td valign=top>";
$tend="</td></tr></table>";

&Error("Слева в меню отметьте группы, для которых необходимо сформировать отчет.",$tend) if $where_grp eq '';

$time1=timelocal(0,0,0,1,$Fmon-1,$Fyear); # начало месяца
if ($Fmon<12) {$mon=$Fmon; $year=$Fyear} else {$mon=0; $year=$Fyear+1}
$time2=timelocal(0,0,0,1,$mon,$year); # начало следущего месяца

$where_time="WHERE p.time>=$time1 AND p.time<$time2";

unless ($Ftype)
{
# ===================
# ОТЧЕТ ПО КАТЕГОРИЯМ
# ===================

$row_title=$head_row=&RRow('tablebg','cccccc','Статья',"Поступления, $gr","Расход, $gr","Бонусное пополнение, $gr","Бонусное снятие, $gr",'Комментарий');

$sql_start="SELECT SUM(p.cash) AS money,p.category FROM pays p LEFT JOIN users u ON p.mid=u.id ".
     "$where_time AND u.grp IN ($where_grp) AND p.type=10 AND p.mid>0";
$sql_end="GROUP BY p.category ORDER BY p.category";

sub show_table
{
 ($sql,$title)=@_;
 $sum=0;
 $tbl=&RRow('head','C',&bold_br($title)).
      &RRow('tablebg','cc','Категория',"Сумма, $gr");
 $sth=&sql($dbh,"$sql_start AND $sql $sql_end");
 while ($p=$sth->fetchrow_hashref)
   {
    $c=$p->{category};
    $m=int $p->{money};
    $sum+=$m;
    $tbl.=&RRow('*','ll',$c? $ct{$c} || "<span class=error>Неизвестная категория $c</span>": &bold('Без категории'),$m);
   }
 $tbl.=&RRow('head','ll',&bold('Итого'),&split_n($sum));
 return &Table('tbg3 width100',$tbl).'<br><br>';
}

$OUT.=&Table('width100',
 &RRow('','^^',
   &show_table("p.bonus='' AND p.cash>0",'Наличное пополнение'),
   &show_table("p.bonus='' AND p.cash<0",'Возврат наличных')
 ).
 &RRow('','^^',
   &show_table("p.bonus<>'' AND p.cash>0",'Безналичные пополнения'),
   &show_table("p.bonus<>'' AND p.cash<0",'Безналичные снятия со счета')
 )
);

$OUT.=&div('message cntr',&bold_br('Затраты/поступления сети (платежи не касающиеся счетов абонентов)'),1);

$sql_start="SELECT SUM(p.cash) AS money,p.category FROM pays p $where_time AND p.type=10 AND p.mid=0";

$out='';
foreach $i (sort keys %Offices)
  {
   next if !$PR{26} && $i!=$Admin_office; # нельзя просматривать стат других отделов
   $office=$i? 'отдел '.&commas($Offices{$i}) : 'Отдел не указан';
   $out.=&RRow('','^^',
       &show_table("p.office=$i AND p.bonus='' AND p.cash>0","$office. Приход в кассу"),
       &show_table("p.office=$i AND p.bonus='' AND p.cash<0","$office. Уход из кассы")
   );
  }

$OUT.=&Table('width100',$out);

&Exit;
}

1;
