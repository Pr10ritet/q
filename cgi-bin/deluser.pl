#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_del_usr or &Error('��� �� ��������� ������� ������� ������ ��������.');
$AdminTrust or &Error('�� �������� ������, ��������� ��� ����������� �� �� �������, ��� ��������� �� ���������� �����������.');

$OUT.=&Mess3('row2',&div('cntr',&bold_br('�������� ������� ������ ������� �� ���� ������.').
  &ahref("$scrpt0&a=operations&act=help&theme=deluser",'�������'))).$br;

$F{act} or &Error('�������� �� ������.');
$Fid=int $F{id};

($userinfo,$grp,$mId,$ipp)=&ShowUserInfo($Fid);
unless ($mId)
  {
   $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='users' AND act=2 AND fid=$Fid",'������ �� ��� ������');
   $p && &Error(&the_short_time($p->{time},$t,1)." ������� ������ ������� � $Fid ���� �������.".$br2.&CenterA("$scrpt0&a=listuser",'����� &rarr;'));
   &Error("������� ������ ������� � $Fid �� ������� � ���� ������.$go_back");
  }

&Error('��� ���� �� �������� ������ � ������� ������.') if $UGrp_allow{$grp}<2;

$h=&sql_select_line($dbh,"SELECT * FROM users WHERE mid=$Fid LIMIT 1",'���� �� ������?');
$h && &Error('������ ����� '.&ahref("$scrpt0&a=user&id=".$h->{id},'������').'. ������� ������� ��.');

$out2='';
if ($mId==$Fid)
  {# �������� ������
   $out3='';
   $sth=&sql($dbh,"SELECT * FROM cards WHERE alive=$Fid",'�������� �� �� ������� �������������� �������� ���������� �����?');
   while ($h=$sth->fetchrow_hashref)
     {# +0 ����� ������ ������� �����, ���� ��� �������
      $out3.=&RRow('*','ll',$h->{money}+0,&the_short_time($h->{atime},$t));
     }
   $out2.=&Table('tbg3',&RRow('head','C','������ ����������� ��������� �������� ���������� �����').
      &RRow('head','cc','�����','����� ���������').$out3.
      &RRow('head','C','����� �������� �������� ����� ���������� � ��������� '.&commas('�������������'))
   ).$br if $out3;
   # ��������, �� ���� �������� ���������� ������� ����� �� �������� - � ��� ������ ������
   $h=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE type=10 AND bonus='' AND mid=$Fid",'���� �� ������� �� ������� ������?'); 
   !$h && &Error("������ ��������� �������� �������. ������ �� �������");
   $out2.=&div('error',"�������� ��������: $h->{n} ��",1) if $h->{n};
  }
   else
  {
   $count_pays=0;
  }  
   
if ($F{act} ne 'iamshure')
  {# ��������������
   $OUT.=&div('message',
      &form('!'=>1,'id'=>$Fid,'act'=>'iamshure',
        &Table('',&RRow('','tt',$userinfo,$out2).&RRow('','C',$br2."������� ����� ����� 'ok': ".&input_t('ok','',3,3," autocomplete='off'").$br2.&submit_a('������� ������')))
      )
   );
   &Exit;
  }

# =======================
# ��������������� �������
lc($F{ok}) ne 'ok' && &Error("�� �� ����� ������� ����� �������������� ���� ���������.$go_back");

$h='������� '.($mId!=$Fid && '��������')." ������ ip: $ipp, id: $Fid.";
$p=&sql_select_line($dbh,"SELECT * FROM pays WHERE type=50 AND category=411 AND mid=$Fid",'����� ���� ������� ������?');
$h.=' ���� ������� '.&the_time($p->{time}).(!!$p->{admin_id} && ' ��������������� id='.$p->{admin_id}) if $p;

$mid=$mId!=$Fid? $mId : 0; # ���� ��������� �������� ������, �� ������ ��������� � ��������, ����� � "�������� ����"

$sql="INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,coment,time) ".
     "VALUES($mid,0,50,420,$Admin_id,INET_ATON('$ip'),$Admin_office,'$h','',$ut)";
$sth=$dbh->prepare($sql);
$sth->execute;
$id=$sth->{mysql_insertid} || $sth->{insertid};

!$id && &Error("������ �� ������� �� ��. ������ sql.$go_back");

&sql_do($dbh,"DELETE FROM users_trf WHERE uid=$Fid LIMIT 1");

if ($mId!=$Fid)
  {# �����
   &sql_do($dbh,"DELETE FROM pays WHERE mid=$Fid",'������� ��� ������� ��������� � �������');
   $rows=&sql_do($dbh,"DELETE FROM users WHERE id=$Fid LIMIT 1");
   $rows<1 && &Error("�������� ������ �� ������� �� ��. ������ sql.$go_back");
   &sql_do($dbh,"INSERT INTO changes SET tbl='users',act=2,time=$ut,fid=$Fid,adm=$Admin_id");
   &OkMess("�������� ������ ������� �� ��.".$br2.&CenterA("$scrpt0&a=user&id=$mId",'������ �������� ������'));
   &ToLog("!! $Admin_UU ������� �������� ������ id=$Fid ($ipp), id �������� ������ $mId");
   &Exit;
  }

&sql_do($dbh,"DELETE FROM pays WHERE mid=$Fid AND (cash=0 OR bonus<>'')",'������� ��� ���������� ������� � �������');
&sql_do($dbh,"UPDATE pays SET mid=0,reason=CONCAT('~(������ ���������� ������� ip: $ipp, id: $Fid~)\n',reason) WHERE mid=$Fid");

$rows=&sql_do($dbh,"DELETE FROM users WHERE id=$Fid LIMIT 1");
$rows<1 && &Error("������� ������ ������� �� ������� �� ��. ������ sql.$go_back");

&ToLog("!! $Admin_UU ������ ������ id=$Fid ($ipp)");

&sql_do($dbh,"INSERT INTO changes SET tbl='users',act=2,time=$ut,fid=$Fid,adm=$Admin_id","� ������� ��������� �����������, ��� ������ id=$Fid ������");

&OkMess("������� ������ ������� ������� �� ��.".$br2.&CenterA("$scrpt0&a=",'�� ��������� �������� &rarr;'));
$DOC->{header}.=qq{<meta http-equiv="refresh" content="15; url='$scrpt0&a='">};

1;
