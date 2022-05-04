#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Mess_UntrustAdmin='�� �������� ������, ��������� ��� ����������� �� �� �������, ��� ��������� �� ���������� �����������.';

%subs=(
 'add_chngpkt'	=> \&check_priv,	# �������� ��������� ������
);

$Fact=$F{act};
exists($subs{$Fact}) or &Error('����������� ������� act='.&Filtr_out($Fact).$go_back);
$scrpt.="&act=$Fact";

&{ $subs{$Fact} };
&{$Fact};
&Exit;

sub check_priv
{
 $pr_SuperAdmin or &Error('������ ��������.',$tend);
 $AdminTrust or &Error($Mess_UntrustAdmin,$tend);
}

# ==============================================================================
#				�������� ��������� ������
# ==============================================================================
sub add_chngpkt
{
 $Fpkt1=int $F{pkt1};
 $Fpkt2=int $F{pkt2};
 $Fnext=$F{next}?1:0;
 $pkt1='<select name=pkt1 size=26><option value=-1 selected>�������� �����</option>';
 $pkt2='<select name=pkt2 size=26><option value=-1 selected>�������� �����</option>';
 %goodpkt=();

 if ($Fnext)
 {
    $field='next_paket';
    $name_zero='����� �� �������';
    $pkt2.="<option value=0 selected>$name_zero</option>";
    $goodpkt{0}=1;
    $OUT.=&MessX('�������� ��������� <b>���������� �� ��������� �����</b> ������� �����������.').'<br>';
 }else
 {
    $field='paket';
    $name_zero="�������������� ����� � 0";
    $OUT.=&MessX('�������� ��������� <b>������� �������</b> �����������.').'<br>';
 } 

 $sth=&sql($dbh,"SELECT COUNT(*) AS n,u.$field,p.name FROM users u LEFT JOIN plans2 p ON u.$field=p.id WHERE u.mid=0 GROUP BY p.id ORDER BY p.name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($paket,$name,$n)=&Get_filtr_fields($field,'name','n');
    $n=sprintf("%06d",$n);
    $pkt1.="<option value=$paket>$n - ".($paket? $name || "�������������� � $paket" : $name_zero).'</option>';
 }

 $sth=&sql($dbh,"SELECT id,name FROM plans2 WHERE name<>'' ORDER BY name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($id,$name)=&Get_filtr_fields('id','name');
    $goodpkt{$id}=1;
    $pkt2.="<option value=$id>$name</option>";
 }

 unless ($F{ok})
 {
    $OUT.=&Table('tbg3',&form('!'=>1,'act'=>'add_chngpkt','next'=>$Fnext,
        &RRow('head','C','� ����� ������� �������� �����, ������� �������� ����� ���������� �� ��������� � ������ ������� �����.<br>����� ��������� ������ ������� ���������� �������� �� ������ ������.').
        &RRow('*','cc',"$pkt1</select>","$pkt2</select>").
        &RRow('*','C',"<br>������� ����� ����� 'ok' ".&input_t('ok','',4,4).$br2.&submit_a('��������') )));
    &Exit;
 }

 (lc($F{ok}) eq 'ok') or &Error("�� ����������� ����� ������� ����� �������������� ���� ���������.$go_back");
 $goodpkt{$Fpkt2} or &Error("������� ����� ������ �������.$go_back");
 $rows=&sql_do($dbh,"UPDATE users SET $field=$Fpkt2 WHERE $field=$Fpkt1");
 &OkMess('�������� ��������� ������ ����������� ���������.'.$br2.'������� ����� � '.&bold($rows>0? $rows:0).' ��������.');
}

1;
