#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$DOC->{admin_area}="mysql: ".$dbh->{mysql_stat}.$br.$DOC->{admin_area} if $Ashowsql;

$OUT.=&div('infomess',&Show_all($p_adm->{mess}).$br2.&CenterA("$scrpt0&a=operations&act=dontshowmess",'�� ����������')) if $p_adm->{mess}!~/^\s*$/;
$OUT.=&div( 'row2',&Printf('[br]������������, [filtr|bold][br2]',$Aname || '�������������') );

$ul='';
sub li { &tag('li',$_[0].$br2) }

$Admin_id && (!$PR{108} || $pr_RealSuperAdmin) && do{ $ul.=&li(&ahref("$scrpt0&a=mytune",'���� ���������')) };
$Admin_id or do{ $ul.=&li('�� ����� ��� �������, ������� ����������� ������������� ��� ��������� � �������� ������ �������. '.&ahref("$scrpt0&a=main",'����� &rarr;')) };

$ENV{SERVER_PORT} && !$ENV{HTTPS} && do{ $ul.=&li(&Printf('[span error] []','��������������:','�� �� ��������� �� ����������� ��������� https.')) };
$pr_SuperAdmin && (-e 'listuser.pl') && do{ $ul.=&li(&Printf('[span error] []','��������������:','����������, ��� � cgi-bin ����� ������������ �������, ������� ��� �� ������ ����. '.
   "������ web-������� ��������� � $Nodeny_dir_web, � � cgi-bin ������ 2 �����: adm.pl � stat.pl. ������� ��� ������ �����.")) };

# --- ���������������� �������� ���������� �� �������� ������ ---

$out='';
$sth=&sql($dbh,"SELECT p.id,p.cash,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.reason ".
   "WHERE p.mid=0 AND p.type=40 AND p.category=470 AND p.coment='$Admin_id' ORDER BY p.time DESC",
   '��������������� �������� ����������');
while( $p=$sth->fetchrow_hashref )
{
   ($id,$cash,$tt,$admin,$name)=&Get_filtr_fields('id','cash','time','admin','name');
   # � ���� ���������� ��� ����, ����� � ������ ������������� ���� ��������, ��� ���������� �� ��������������� ����� ������������ � �������� ������
   $url="$scrpt0&a=operations&act=payagree&id=$id&cash=$cash";
   $out.=&RRow('*','rrrcc',
      &the_short_time($tt,$t),
      &bold($admin).($name && " ($name)"),
      $cash,
      &ahref("$url&yes=1",'��'),
      &ahref($url,'���')
   );
}

$ul.=&li('���������������� �������� ��������'.$br2.
  &Table('nav2 tbg3',&RRow('tablebg','cccC','����','�� ��������������',"�����, $gr",'�����������?').$out).$br2
) if $out;


# --- ���������� �������� ���������� ---
$out='';
$sql=$pr_SuperAdmin? '' : "AND p.coment='$Admin_id'"; # ���� ����������, �� ������� ���, ����� ������ �������� ������
$sth=&sql($dbh,"SELECT p.id,p.cash,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.reason ".
   "WHERE p.mid=0 AND p.type=40 AND p.category=409 $sql ORDER BY p.time DESC",'����������� �������� ����������');
while ($p=$sth->fetchrow_hashref)
{
   ($id,$cash,$tt,$admin,$name)=&Get_filtr_fields('id','cash','time','admin','name');
   $out.=&RRow('*','rrrc',
     &the_short_time($tt,$t),
     &bold($admin).($name && " ($name)"),
     $cash,
     &ahref("$scrpt0&a=pays&act=show&id=$id",'��������� &rarr;')
   );
}

$ul.=&li(&bold($pr_SuperAdmin? '����������� �������� ����������' : '���� ��������� ��������� �������� ��������.<br>����������, ����� ������� ������������� ������ ��').$br2.
  &Table('nav2 tbg3',&RRow('tablebg','cccc','����','�� ��������������',"�����, $gr",'������ �������').$out)
) if $out;


# === ���� �� ���������������� �������� �������� ���������� ����� ===
sub show_cid
{
 my ($start_cid,$len,$money,$admin)=@_;
 my $end_cid=$start_cid+$len-1;
 my $yes=&ahref("$scrpt&a=operations&act=cards_move_agree&n1=$start_cid&n2=$end_cid",'��');
 my $no=$admin!=$Admin_id? &ahref("$scrpt&a=operations&act=cards_move_dont_agree&n1=$start_cid&n2=$end_cid",'���') : '&nbsp;';
 $admin=$admin!=$Admin_id? $A->{$admin}{admin} : '<span class=error>������� ��������! ����������� ����� ��������� �� ������.</span>';
 return &RRow('*','ccclcc',$money,"$start_cid .. $end_cid",$len,$admin,$yes,$no);
}

$p=&sql_select_line($dbh,"SELECT COUNT(*) FROM cards WHERE rand_id='$Admin_id' AND alive='move'",'���������������� �������� �������� ���������� �����:');
{
 next if !$p || $p->{'COUNT(*)'}<1;
 ($A)=&Get_adms;
 $i=$last_r=$last_money=$start_cid=$cards=0;
 $out='';
 $sth=&sql($dbh,"SELECT cid,money,r FROM cards WHERE rand_id='$Admin_id' AND alive='move' ORDER BY cid");
 while ($p=$sth->fetchrow_hashref)
 {
    $cards++;
    ($cid,$money,$r)=&Get_fields('cid','money','r');
    $start_cid||=$cid;
    $last_money||=$money;
    $last_r||=$r;
    next if $cid==($start_cid+$i) && $money==$last_money && $r==$last_r;
    $out.=&show_cid($start_cid,$i,$last_money,$r);
    $last_money=$money;
    $last_r=$r;
    $start_cid=$cid;
    $i=0;
 }
  continue
 {
    $i++;
 }
 $out.=&show_cid($start_cid,$i,$last_money,$r) if $start_cid;
 $ul.=&li("� ������� ������ �� ��� ��������� �������� �������� ���������� ����� � ���������� $cards ����. ����������� �������� ���� �� ������������� ������� ��� ��������. ".
    '���� ���� ���� �� ���� ��������, ������� �� �� �������, �� ������������� ��������! � ���� ������ ���������� � �������� �������������� ��� ���������� ������ ��������.'.$br2.
    &Table('tbg3 nav2',&RRow('tablebg','ccccC',"�������, $gr",'��������','���-��','����� �� �������� ���������� ��������','�������������').$out)
 ) if $cards;  
}    

# === ���� �� ������ �� ��������� ������ ===
sub ask_u
{
 $cod='�������� ������ �������';
 $data=int $data;
 $url=$data<=0? "�������� id ������� ������ �������!" : &ahref("$scrpt0&a=user&id=$data",'������ �������');
}

sub ask_d
{
 $cod=&bold('������� ������� ������ �������');
 $data=int $data;
 $url=$data<=0? "�������� id ������� ������ �������!" : &ahref("$scrpt0&a=user&id=$data",'������ �������').&ahref("$scrpt0&a=deluser&act=del&id=$data",'��������!');
}

sub ask_p
{
 $cod='�������� ������';
 $data=int $data;
 $url=$data<=0? "�������� id �������!" : &ahref("$scrpt0&a=pays&act=show&id=$data",'�������� ������');
}

sub ask_error
{
 $cod='<span class=error>������!</span> ���: '.&Filtr_out($cod);
 $url='';
}

if( $PR{115} )
{ # 115 - ����� �� ����� ������
  $out='';
  %subs=('p'=>\&ask_p,'u'=>\&ask_u,'d'=>\&ask_d);
  $sth=&sql($dbh,"SELECT p.id,p.reason,p.coment,p.time,a.admin,a.name FROM pays p LEFT JOIN admin a ON a.id=p.admin_id ".
       "WHERE p.type=50 AND p.category=417 ORDER BY p.time DESC",'������ �� ��������� ������:');
  while( $p=$sth->fetchrow_hashref )
  {
     $coment=&Show_all($p->{coment});
     ($id,$reason,$tt,$admin,$name)=&Get_filtr_fields('id','reason','time','admin','name');
     ($cod,$data)=split /:/,$reason;
     if (defined $subs{$cod}) { &{$subs{$cod}} } else {&ask_error}
     $out.=&RRow('*','llllll',
       &the_time($tt),
       &bold($admin).($name && " ($name)"),
       $cod,
       $coment,
       $url,
       &ahref("$scrpt0&a=pays&act=show&id=$id",'�������� ������')
     );
  }
  $ul.=&li('������ �� ��������� ������'.$br2.
     &Table('nav2 tbg3',&RRow('tablebg','cccccc','����','�� ��������������','��� ���������','���������','��������','�������� ������').$out)
  ) if $out;
}

nSql->new({
  dbh	=>$dbh,
  sql	=>"SELECT COUNT(*) AS n FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE u.grp IN ($Allow_grp) AND p.category=491 AND p.type=30 AND p.time>($ut-24*3600)",
  comment => '������������ ��������� �� �����',
  hash=>\%h }) && $h{n}>0 &&
  do{
      $ul.=&li('�� ��������� 24 ���� �� �������� ��������� '.&bold($h{n}).' ���������, �� ������� ��� �� ���� ���� ������. '.
          &ahref("$scrpt0&a=payshow&nodeny=category&category=491",'��������'))
  };

{
 $pr_events or last;
 %c=(
  502 => '��������� � ��������',
  410 => '��������� ������� ������� ��������',
 );
 foreach $h (keys %c)
 {
    $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE type=50 AND category=$h AND time>($ut-24*3600)",'���������� ��������� ������');
    $ul.=&li("�� ��������� 24 ���� ���� ����������� $p->{n} $c{$h}. ".&ahref("$scrpt0&a=payshow&nodeny=category&category=$h",'��������')) if $p && $p->{n}>0;
 }
}

# === ������������ �� �������������� ===

{
 $PR{103} or last;
 $p=&sql_select_line($dbh,"SELECT COUNT(parent_id) AS n FROM dopdata WHERE ".
    "field_type=7 AND field_value='1:$Admin_id'",
    '������������, ������� �������� �� ��������������');
 $ul.=&li(&Printf('�� ��� �������� [bold] ������ ������������. []',$p->{n},&ahref("$scrpt0&a=equip&act=find&owner_type=1&owner_id=$Admin_id",'��������'))) if $p && $p->{n}>0;
}

# === ������ �������� ���� ===

{
 !$pr_turn_office_adm && !$pr_turn_any_adm && last;
 $header=&RRow('tablebg','cccc','�����','���','����������?','���������� ���������');
 $old_office=-1;
 $out='';
 $sth=&sql($dbh,"SELECT * FROM admin".($PR{31}? '':" WHERE office=$Admin_office")." ORDER BY office,admin",'������ ���������������');
 while( $p=$sth->fetchrow_hashref )
 {
    $office=$p->{office};
    $out.=(!!$office && &RRow('tablebg','4','����� '.&bold($Offices{$office}||"� $office"))).$header if $office!=$old_office;
    $old_office=$office;
    %pr=();
    $pr{$_}=1 foreach (split /,/,$p->{privil});
    $pr{1} or next;
    $id=$p->{id};
    $adm_login=&ahref("$scrpt0&set_new_admin=$id",$p->{admin});
    $adm_name=&Filtr_out($p->{name});
    $adm_super=$pr{3} && $pr{5}? '<span class=error>��</span>' : $pr{2}? '�����.':'&nbsp;';
    $adm_mess=&ahref("$scrpt0&a=operations&act=setmess&id=$id",$p->{mess}=~/^\s*$/? '����������':'*** �������� ***');
    $out.=&RRow('*','llcc',$adm_login,$adm_name,$adm_super,$adm_mess);
 }
 $ul.=&li('� ��� ���� ����� ������������� �� ����� �� ������������� ������� �������'.$br2.&Table('tbg3',$out));
}


$OUT.=&div('lft',&tag('ul',$ul));

1;
