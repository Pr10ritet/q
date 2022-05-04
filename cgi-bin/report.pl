#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_fin_report or &Error('��� ������� ������������ ����������.');

&LoadMoneyMod;
&LoadPaysTypeMod;

$Ftype=int $F{type}; # ��� ������
$Fyear=int $F{year};
$Fmon=int $F{mon};

$Fmon=$mon_now if $Fmon<1 || $Fmon>12;
$Fyear=$year_now if $Fyear<100 || $Fyear>200;

$scrptf="$scrpt&mon=$Fmon&year=$Fyear";

($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
$year_list=&Set_year_in_list($Fyear);

# ���������� ������ �����, ������� ����������� �����, � ����������� �������
($out,$where_grp)=&List_select_grp;

#$out.='<br>';

$out2='';
$where_active=''; # ������� ���������� �������

$OUT.="<table class='width100'><tr><td valign=top width=22%>".
  &div('message lft',
    &form('!'=>1,'#'=>1,&bold('���������� ����� ��').$br."$mon_list $year_list".$br2.&submit_a('��������').
      $br2.'��� �����:'.$br2."<div id=grp>$out</div>".$br
    )
  )."</td><td valign=top>";
$tend="</td></tr></table>";

&Error("����� � ���� �������� ������, ��� ������� ���������� ������������ �����.",$tend) if $where_grp eq '';

$time1=timelocal(0,0,0,1,$Fmon-1,$Fyear); # ������ ������
if ($Fmon<12) {$mon=$Fmon; $year=$Fyear} else {$mon=0; $year=$Fyear+1}
$time2=timelocal(0,0,0,1,$mon,$year); # ������ ��������� ������

$where_time="WHERE p.time>=$time1 AND p.time<$time2";

unless ($Ftype)
{
# ===================
# ����� �� ����������
# ===================

$row_title=$head_row=&RRow('tablebg','cccccc','������',"�����������, $gr","������, $gr","�������� ����������, $gr","�������� ������, $gr",'�����������');

$sql_start="SELECT SUM(p.cash) AS money,p.category FROM pays p LEFT JOIN users u ON p.mid=u.id ".
     "$where_time AND u.grp IN ($where_grp) AND p.type=10 AND p.mid>0";
$sql_end="GROUP BY p.category ORDER BY p.category";

sub show_table
{
 ($sql,$title)=@_;
 $sum=0;
 $tbl=&RRow('head','C',&bold_br($title)).
      &RRow('tablebg','cc','���������',"�����, $gr");
 $sth=&sql($dbh,"$sql_start AND $sql $sql_end");
 while ($p=$sth->fetchrow_hashref)
   {
    $c=$p->{category};
    $m=int $p->{money};
    $sum+=$m;
    $tbl.=&RRow('*','ll',$c? $ct{$c} || "<span class=error>����������� ��������� $c</span>": &bold('��� ���������'),$m);
   }
 $tbl.=&RRow('head','ll',&bold('�����'),&split_n($sum));
 return &Table('tbg3 width100',$tbl).'<br><br>';
}

$OUT.=&Table('width100',
 &RRow('','^^',
   &show_table("p.bonus='' AND p.cash>0",'�������� ����������'),
   &show_table("p.bonus='' AND p.cash<0",'������� ��������')
 ).
 &RRow('','^^',
   &show_table("p.bonus<>'' AND p.cash>0",'����������� ����������'),
   &show_table("p.bonus<>'' AND p.cash<0",'����������� ������ �� �����')
 )
);

$OUT.=&div('message cntr',&bold_br('�������/����������� ���� (������� �� ���������� ������ ���������)'),1);

$sql_start="SELECT SUM(p.cash) AS money,p.category FROM pays p $where_time AND p.type=10 AND p.mid=0";

$out='';
foreach $i (sort keys %Offices)
  {
   next if !$PR{26} && $i!=$Admin_office; # ������ ������������� ���� ������ �������
   $office=$i? '����� '.&commas($Offices{$i}) : '����� �� ������';
   $out.=&RRow('','^^',
       &show_table("p.office=$i AND p.bonus='' AND p.cash>0","$office. ������ � �����"),
       &show_table("p.office=$i AND p.bonus='' AND p.cash<0","$office. ���� �� �����")
   );
  }

$OUT.=&Table('width100',$out);

&Exit;
}

1;
