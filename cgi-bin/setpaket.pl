#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});
(!$pr_edt_usr || !$PR{76}) && &Error('��� ����');

&LoadMoneyMod;

$Fid=int $F{mid};
$Fact=$F{act};
$Fpaket=int $F{paket};

$OUT.=$br;

$U=&Get_users($Fid);
defined($U->{$Fid}{grp}) || &Error("������� ������ ������� id=$Fid �� ����������.$go_back");
$Fid=$U->{$Fid}{mid} || $Fid;

$UGrp_allow{$U->{$Fid}{grp}}<2 && &Error("������ ������� id=$Fid � ������, ������ � ������� ��� ��������.$go_back");

%tarifs=();
foreach $i (1..$m_tarif)
{
   next if !$Plan_name[$i] || !$Plan_allow_show[$i];
   # �������� ����� � ������ ������
   $tarifs{$i}=($Plan_flags[$i]=~/e/ && ' &nbsp;&nbsp;').$Plan_name[$i];
} 

$pakets='<select name=paket size=1>';
$pakets.="<option value=$_".($Fpaket==$_ && ' selected').">".&Del_Sort_Prefix($tarifs{$_})."</option>" foreach (sort {$tarifs{$a} cmp $tarifs{$b}} keys %tarifs);
$pakets.='</select>';

$year=$year_now+1900;
$day=$mon=0;
&show_form unless $Fact;

$F{date}=~s|\s||g;
$F{date}!~/^(\d+).(\d+)\.(\d+)$/ && &show_err('���� ������ �������. ������� � ���� '.&commas('����.�����.���'));
($day,$mon,$year)=(int $1,int $2,int $3); # ������ ����!
($mon<1 || $mon>12) && &show_err('����� ����� �������.');
$year+2000 if $year<1900;
$max_day=&GetMaxDayInMonth($mon,$year-1900);
$day<1 && &show_err('���� ����� �������.');
$day>$max_day && &show_err("���� ����� �������: � $year ���� � $mon-� ������ $max_day ".($max_day==31? '����':'����'));

$set_time=timelocal(0,0,0,$day,$mon-1,$year-1900);
$set_time<$t && &show_err("���� $day.$mon.$year ��� � �������. ���������� ������� ������� �����.");

(!$Plan_name[$Fpaket] || !$Plan_allow_show[$Fpaket]) && &show_err('�� ����� ����� �����������.');

$p=&sql_select_line($dbh,"SELECT * FROM pays WHERE mid=$Fid AND type=50 AND category=431 AND reason LIKE '$day.$mon.$year:%'");
$p && &Center_Mess("��������������: �� $day.$mon.$year ��� �������� ����� ������, �������������");

$rows=&sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,type=50,category=431,reason='$day.$mon.$year:$Fpaket',time=unix_timestamp()");
&Error('��������� ������.') if $rows<0;
&OkMess("$day.$mon.$year ���������� ����� ��������� ����� �� ".&commas($Plan_name_short[$Fpaket]).$br2.
   &CenterA("$scrpt0&a=user&id=$Fid",'������ �������'));

&Exit;

sub show_err
{
 $OUT.=&error('��������: ',$_[0],1);
 &show_form;
}

sub show_form
{
 $OUT.=&MessX(&div('cntr',
   &form('!'=>1,'act'=>1,'mid'=>$Fid,"�������� �����: $pakets � ����: ".&input_t('date',"$day.$mon.$year",12,12).
    "$br$br$br � 0 ����� 0 ����� ����� ����������� ����� ������ �� ���������$br$br$br".
    &submit_a('���������')
   )
 ));
 &Exit;
}

1;
