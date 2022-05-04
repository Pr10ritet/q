#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_pays or &Error('�������� �������� ��������.');

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

$AddRightBlock='';		# ����, ������� ����� ���������� ������ ������ ����, �� ������� ����
@AddRightBlock=();		# �������� ����� <ul>...</ul>
@AddRightUrls=();

#  ������	�����������	����������	�������������� hidden-���� ��� �����
@filtrs=(
   ['pays',	'���',		1,	''],
   ['bonus',	'������',	1,	''],
   ['temp',	'����.�������',	1,	''],
   ['autopays',	'�����������',	1,	''],
   ['mess',	'���������',	1,	''],
   ['mess2all',	'������������� ���������',	1,	''],
   ['event',	'�������',	14,	''],
   ['jobs',	'������',	25,	''],
   ['net',	'������� ����',	1,	''],
   ['transfer',	'�������� �����', 1,	''],
);

%subs=(
 'pay'		=> \&f_pay,
 'bonus'	=> \&f_bonus,
 'client'	=> \&f_client,
 'worker'	=> \&f_worker,
 'sworker'	=> \&f_worker,		# �������� ��������� + ������
 'mess'		=> \&f_mess,		# ���������
 'mess2all'	=> \&f_mess2all,	# ��������� ����
 'event'	=> \&f_event,		# �������
 'temp'		=> \&f_temp,		# ��������� �������
 'net'		=> \&f_net,		# ������� �� ����
 'transfer'	=> \&f_transfer,	# �������� ��������
 'zarplata'	=> \&f_zarplata,	# ��������
 'admin'	=> \&f_admin,		# ������� ���������� ������
 'adminall'	=> \&f_admin,
 'category'	=> \&f_category,	# ����� �������� ��������� $F{category}
 'jobs'		=> \&f_jobs,		# ������� �����
 'autopays'	=> \&f_autopays,	# �����������
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
{  # ������ ����� �� ������� ������������ �����
   $year=$Fyear;
   $month=$Fmon;
   $form_fields{year}=$Fyear;
   $form_fields{mon}=$Fmon;
   $h=('','������','�������','����','������','���','����','����','������','��������','�������','������','�������')[$Fmon].' '.($year+1900)
}else
{# ����� ����� ��� �������� ������
   $year=$year_now;
   $month=$mon_now;
   $h='';
}

if( $Fday )
{
   $max_day=&GetMaxDayInMonth($month,$year);		# ������� ���������� ���� � ����������� ������
   $month--;
   $Fday=$max_day if $Fday>$max_day || $Fday<1;
   $time1=timelocal(0,0,0,$Fday,$month,$year);		# ������ ���
   $time2=timelocal(59,59,23,$Fday,$month,$year);	# ����� ���
   $time2++;
   $form_fields{day}=$Fday;
   $h="$Fday �����, $h";
}else
{
   $month--;
   $time1=timelocal(0,0,0,1,$month,$year);		#  ������ ������
   if ($month<11) {$month++} else {$month=0; $year++}
   $time2=timelocal(0,0,0,1,$month,$year);		#  ������ ��������� ������
}

push @AddRightBlock,"�� $h" if $h;

($A,$Asort)=&Get_adms();	# ������� ������ �������

# ������ �������� ��� ������ �������, �� �������� �������� ������. (���� � %subs �� ������ �������� �������� ����� 'client')
$sth=&sql($dbh,"SELECT id,mid,grp,name,ip FROM users".($Fnodeny eq 'client' && " WHERE id=$Fmid"));
while ($p=$sth->fetchrow_hashref)
{
   $id=$p->{id};
   $user{$id}{$_}=$p->{$_} foreach ('mid','grp','name','ip');
}

$W=&Get_workers();	# ������ ����������
$Allow_worker='';	# C����� id ����������, ������� � ��� �� ������, ��� � �����
foreach (keys %$W)
{
   $Allow_worker.="-$_," if $W->{$_}{office}==$Admin_office; # �������� ����� ����� id ���������, ��� ��� � �������� ��� � �������
}
chop $Allow_worker;	# ������ ��������� �������

$SqlS="FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE ";

# � $allow_grp ������� ������ �����, � ������� ���� ������ ������. � $allow_grp_alt ������ ���� � ���� "(u.grp>5 AND u.grp<=10) OR ..." - 
# ����� ��������� ������ ��� $allow_grp. ��������� � ���, ��� �� ����������� ������ ������������ ������ - ���, �.�. ���� � ������� pays
# ����� ������ � ������������� ������, �� ��� ����������� ��� �����������
$allow_grp=$allow_grp_alt=$allow_grp_sel=$for_grp='';
$min_grp=0;
$max_grp=-1;
foreach (sort {$a <=> $b} (keys %UGrp_name))
{  # ��������� � ������� ����������� ������� �����
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

push @AddRightBlock,"��� �����:$for_grp" if $for_grp;

$allow_grp=$allow_grp_sel if $allow_grp_sel; # ����� ������ ������ ��������

$allow_grp='-1' if $allow_grp eq ''; # ������ $allow_grp||='-1' �.�. $allow_grp ����� ���� = '0'

if( $max_grp>=0 )
{
   $allow_grp_alt.=' OR ' if $allow_grp_alt;
   $allow_grp_alt.=$min_grp!=$max_grp? "(u.grp>=$min_grp AND u.grp<=$max_grp)" : "u.grp=$min_grp";
} 
$allow_grp_alt||='0'; # ����� 0 ��������� ��� ������� false, ����� � sql �������: (0 OR u.grp IS NULL)

$SqlC='('.(length($allow_grp)<length($allow_grp_alt) || $allow_grp_sel? "u.grp IN ($allow_grp)" : $allow_grp_alt).' OR u.grp IS NULL) AND ';

$header_tbl='';
$header='';

@cols=('������',"������,&nbsp;$gr","������,&nbsp;$gr",'�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
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
 push @AddRightBlock,'����������� �������� ������ '.&bold($Offices{$Foffice});
}

sub access_admin
{
 return if $pr_other_adm_pays;
 $SqlC.=" AND p.admin_id=$Admin_id";
 push @AddRightBlock,"������ ���� ������";
}

sub what_cash
{
 return if $F{scash} eq '';
 $F{scash}+=0;
 if( $F{ecash} ne '' )
 {
    $F{ecash}+=0;
    ($F{scash},$F{ecash})=($F{ecash},$F{scash}) if $F{scash}>$F{ecash};
    push @AddRightBlock,"����� ������� � ���������:<br><b>$F{scash}</b> .. <b>$F{ecash}</b> $gr";
    $SqlC.=" AND p.cash>=$F{scash} AND p.cash<=$F{ecash}";
    $form_fields{ecash}=$F{ecash};
    $form_fields{scash}=$F{scash};
 }else
 {
    push @AddRightBlock,"����� ������� <b>$F{scash}</b> $gr";
    $SqlC.=" AND p.cash=$F{scash}";
    $form_fields{scash}=$F{scash}; # �� �������� �� ������� �.�. � ����� ���� ����� ���� ����� scash � ecash
 }
}

sub f_client
{# ������� �������
 &Error("������ id=$Fmid �� ������ � ���� ������, ������ ���������� ����� ����������� ������, �������������� � ���� ������, �������.",$tend) if $Fmid<=0 || (!defined($user{$Fmid}{grp}) && !$pr_SuperAdmin);
 &Error("������ ��������� � ������, ������ � ������� ��� ���������.",$tend) if $UGrp_allow{$user{$Fmid}{grp}}<2 && !$pr_SuperAdmin;
 ($userinfo,undef,$mId)=&ShowUserInfo($Fmid);
 $AddRightBlock.=$userinfo.$br;
 push @AddRightUrls,&ahref("$scrpt0&a=pays&mid=$Fmid",'�������� ������') if $PR{54}||$PR{56}||$PR{57};
 push @AddRightUrls,&ahref("$scrpt0&a=pays&op=mess&mid=$Fmid",'��������� ���������') if $PR{55};
 $DontShowUserField=1;
 @cols=('&nbsp;',"������,&nbsp;$gr","������,&nbsp;$gr",'�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $form_fields{mid}=$Fmid;
 $SqlC="p.mid=$Fmid";
 &what_cash;
 $Ftype_pays=int $F{type_pays};
 %f=(
   10 => '�������',
   30 => '��������',
 -495 => '���������',
   50 => '�������',
 );
 $temp_url=$scrpt.&Post_To_Get(\%form_fields);
 if( $f{$Ftype_pays} )
 {
    $SqlC.=$Ftype_pays>0? " AND p.type=$Ftype_pays" : " AND p.category=".(-$Ftype_pays);
    push @AddRightUrls,&ahref($temp_url,'�������� ��� ������� �������');
    $form_fields{type_pays}=$Ftype_pays;
    unshift @AddRightBlock,"�������� $f{$Ftype_pays} �������";
 }
  else
 {
    unshift @AddRightBlock,($user{$Fmid}{mid}? '������� '.&bold('�������� ������') : '������� �������');
 }
 foreach (keys %f)
 {
    push @AddRightUrls,&ahref("$temp_url&type_pays=$_",'�������� '.$f{$_}) if $_!=$Ftype_pays;
 }
 # � ������� �������� (���/������/�������/������) ������� ������
 push @filtrs,['client','������� �������',1,&input_h('mid'=>$Fmid)];
}

sub f_worker
{# �������� ���������
 $PR{110} or &Error("� ��� ��� ���� ������� � ���������� �������/�������.",$tend);
 $wid=-$Fmid;
 if( defined $W->{$wid}{name} )
 {
    &Error("�������� � id=$wid �������� � ������ �������� �� ������",$tend) if !$pr_oo && $W->{$wid}{office}!=$Admin_office;
    push @AddRightBlock,'��� ��������� '.&bold($W->{$wid}{name});
 }
  elsif( $pr_oo )
 {
    push @AddRightBlock,"��� ��������� �������������� � ���� ������";
 }
  else
 {
    &Error("�������� � id=$wid �� ������ � ���� ������. ���� ���� ������ �������� �� ���� id, �� �� ����� ����������� ����� � ������� ������ � ������ �������.",$tend)
 }
 $form_fields{mid}=$Fmid;
 $SqlC="p.mid=$Fmid";
 push @AddRightUrls,&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",'������ ���������');
 if( $Fnodeny ne 'sworker' )
 {
    $SqlC.=" AND p.type=10";
    %temp_files=%form_fields;
    $temp_files{nodeny}='sworker';
    push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'�������� ������� ���������');
 }
 $header_tbl="<$tc>��������</td>";
}

sub f_mess
{
 unshift @AddRightBlock,'��������� � �����������';
 $SqlC.='p.type=30';
 &access_grp;
 @cols=('������','','���������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[3]=0;
}

sub f_mess2all
{
 $PR{34} or &Error("��� ���� �� �������� ��������� ���������.",$tend);
 unshift @AddRightBlock,'��������� ���������';
 $SqlC='p.type=30 AND p.mid=0';
 @cols=('&nbsp;','���','���������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[3]=0;
}

sub f_event
{
 $pr_events or &Error("� ��� ��� ���� �� �������� �������.",$tend);
 unshift @AddRightBlock,'�������';
 $SqlC.="p.type=50 AND p.category NOT IN (460,461,112)"; # �� �������� ������ (460,461), ����������� (112)
 &access_grp;
 @cols=('������','��������','�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[3]=0;
}

sub f_temp
{# ��������� �������. ����� ��������� �� ���� ��������� ���� �������� �� ������ �������
 unshift @AddRightBlock,'��������� �������';
 $SqlC.="p.type=20";
 &access_grp;
 &what_cash;
 @cols=('������',"������,&nbsp;$gr",'&nbsp','�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
}

sub f_net
{   
 unshift @AddRightBlock,'������� ��������/������ ����';
 $SqlC='p.type=10 AND ';
 $SqlC.=$pr_oo? 'p.mid<=0' : "((p.office=$Admin_office AND p.mid=0)".($Allow_worker && " OR p.mid IN ($Allow_worker)").')';
 if( !$pr_other_adm_pays )
 {
    $SqlC.=" AND p.admin_id=$Admin_id";
    push @AddRightBlock," (<span class=data1>������ ���� �������</span>)";
 }
 &what_cash;
 @cols=('&nbsp;',"������,&nbsp;$gr","������,&nbsp;$gr",'�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
}

sub f_zarplata
{
 $PR{110} or &Error("� ��� ��� ���� ��� ������� � ���������� �� ���������/�������",$tend);
 $SqlC='p.type=10 AND ';
 # ���� ��� ���� �� ������ ������, �� �������� �������� ���������� ������ � ��� �� ������
 $SqlC.=$pr_oo? "p.mid<0" : $Allow_worker? "p.mid IN ($Allow_worker)" : '0';  # ���� ��� �� ������ ��������� � ��� �� ������, �� ������ ������ ��������
 unshift @AddRightBlock,'�������� ����������';
 &what_cash;
 @cols=('��������','&nbsp;',"������,&nbsp;$gr",'�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
}

sub f_transfer
{
 $SqlC='p.mid=0 AND p.type=40';
 $SqlC.=" AND (reason='$Admin_id' OR coment='$Admin_id')" unless $pr_other_adm_pays; # ��� ���� �� �������� �������� ������ ������� - ������� ������ �������� ��� �������� ������
 unshift @AddRightBlock,$pr_other_adm_pays? '�������� ���������� ����� ����������������' : '�������� ���������� �� ��� ��� �������';
 @cols=('&nbsp;',"�����,&nbsp;$gr",'�����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[3]=0;
}

sub f_admin
{# ������� ������ ���� ������� ���� $Fadmin==0
 $Fadmin=int $F{admin};
 &Error("���� ���������� �� ��������� ������������� ������� ������� ��������������",$tend) if !$pr_other_adm_pays && $Fadmin && $Fadmin!=$Admin_id;

 if( !$pr_oo && $Fadmin )
 {  # ��� ���� ������ � ������� ��������, �������� ������������� ����� � ��� �� ������?
    $p=&sql_select_line($dbh,"SELECT office FROM admin WHERE id=$Fadmin LIMIT 1",'������� ����� ��������������, ������� �������� ���������� �����������');
    $p or &Error("�� ���� �������� ������� �������������� �������������� �.� �� ������� �������� ��� ������, ������� ���������� ��� �������� ����� ����. ".
           "����������� ������������� ������ ����� �����, � �������� ���� ����� �� ������ � ������� ��������.",$tend);
    &Error("� ��� ��� ���� �� �������� �������� �������������� �� ������� ������.",$tend) if $p->{office}!=$Admin_office;
 }

 $form_fields{admin}=$Fadmin;

 if( $Fadmin )
 {
    push @filtrs,['admin','�������������� '.$A->{$Fadmin}{login},1,&input_h('admin'=>$Fadmin)];

    if( $Fnodeny eq 'adminall' )
    {  # ����� ��������� ����� �� ������
       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND cash>0",'����� ������ ��������');
       $i1=$p? $p->{'SUM(cash)'} : 0;

       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND cash<0",'����� ������ ��������');
       $i2=$p? $p->{'SUM(cash)'} : 0;
    }else
    {
       $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin",'�������� ������ � �����������');
       $i1=$p? $p->{'SUM(cash)'} : 0;
       $i2=0;
    }

    $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=40 AND reason='$Fadmin'",'������� ������ ���������������');
    $i3=$p? $p->{'SUM(cash)'} : 0;

    $p=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE type=40 AND coment='$Fadmin'",'������� �� ������ ���������������');
    $i4=$p? $p->{'SUM(cash)'} : 0;

    $p=&sql_select_line($dbh,"SELECT SUM(money) FROM cards WHERE r=$Fadmin",'����� ��������� �������� ����������, ����������� � ������');
    $i5=$p? $p->{'SUM(money)'} : 0;

    $Na_rukax=$i1+$i2-$i3+$i4;

    unshift @AddRightBlock,'������� �������� �������������� '.&bold($A->{$Fadmin}{login}||'<span class=error>�������������� � ���� ������</span>');
 }
  else
 {
    unshift @AddRightBlock,'������� ��������� �������';
 }

 $u1=$Fadmin? "(p.type=40 AND (p.reason='$Fadmin' OR p.coment='$Fadmin'))" : '0'; # ������� �������� ��������
 $u2="p.admin_id=$Fadmin"; # ������� �������� ������
 if( $Fnodeny eq 'adminall' )
 {  # ������� ����� ��������?
    $u2=!$pr_events? "($u2 AND p.type IN (10,20,40))" : $Fadmin? $u2 : "($u2 AND p.type IN (10,20,40,50))"; # �� ������� ��������� ��� ��������� ������ "�������"
    $header.=&Table('tbg1',
        &RRow('*','lrl','������ ��������',&bold(&split_n(int $i1)),$gr).
        &RRow('*','lrl','������ ��������',&bold(&split_n(int -$i2)),$gr).
        &RRow('*','lrl','������� �� ������ ��������������� ��������',&bold(&split_n(int $i4)),$gr).
        &RRow('*','lrl','������� ������ ��������������� ��������',&bold(&split_n(int $i3)),$gr).
        &RRow('head','lrl','�� �����',&bold(&split_n(int $Na_rukax)),$gr).
        &RRow('*','lrl','������� �� ���������� �������� ���������� ����� �� �����',&bold(&split_n(int $i5)),$gr).
        &RRow('head','lrl','�� ����� � ������ �������� ����������',&bold(&split_n(int $Na_rukax+$i5)),$gr)) if $Fadmin;
 }
  else
 {   # ������� ������ �������
     $u2="($u2 AND p.type=10)";
     push @AddRightUrls,&ahref("$scrpt&admin=$Fadmin&nodeny=adminall",'���������');
 }
 # ���������� $Allow_grp,� ������� �������� ������������ ������ - ���������� ����������, ��� ���� ������� ������
 $SqlC="(u.grp IN ($allow_grp) OR u.grp IS NULL) AND ($u1 OR $u2)";
 &what_cash;
}

sub f_category
{# ����� ����������� ��������� ��������
 $Fcategory=int $F{category};
 $name_category=$Fcategory? '��������� '.&commas($ct{$Fcategory} || "����������� � ����� $Fcategory") : '��� ���������';
 unshift @AddRightBlock,"������� $name_category";
 $form_fields{category}=$Fcategory;
 $SqlC.="p.category";
 if( $Fcategory )
 {
    $SqlC.="=$Fcategory";
 }
  else
 {  # ���� ��������� �� ��������, �� ������� ��� �������������� ���������, � �� ������ �������!
    $i=0;
    $SqlC.=" NOT IN (";
    # ������ �������� ������ ��������� ���� ��� ������ sql �� �������� ��� �� ���� ������������ ������
    $SqlC.="$_,".($i++%15? '':' ') foreach (keys %ct);
    chop $SqlC; # ������ ��������� �������
    $SqlC.=") AND p.type=10";
 }
 &access_grp;
 &access_admin;
 push @filtrs,['category',$name_category,1,&input_h('category'=>$Fcategory)];
}

sub f_jobs
{
 &Error('� ��� ��� ���� �� ��������/���������� ������� ����������.',$tend) unless $PR{25};
 $SqlC.="p.type=50 AND p.category IN (460,461)";
 unshift @AddRightBlock,'������� ������� ����������';
 &access_grp;
 @cols=('������','�������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[2]=0;
 $cols_map[3]=0;
}

sub f_autopays
{
 unshift @AddRightBlock,'�����������';
 $SqlC.="p.type=50 AND p.category=112";
 &access_grp;
 &what_cash;
 @cols=('������','����������','����,&nbsp;�����','&nbsp;','�����','&nbsp;');
 $cols_map[2]=0;
 $cols_map[3]=0
}

sub f_pay
{# ������� �������
 unshift @AddRightBlock,'������� �����������';
 $SqlC.="p.type=10 AND p.bonus=''";
 &access_grp;
 &access_admin;
 &what_cash;
}

sub f_bonus
{# ����������� �������
 unshift @AddRightBlock,'����������� �������';
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
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'�������� �� ��� �����');
}

$sql="SELECT p.*,u.name,u.grp $SqlS $SqlC ORDER BY p.time DESC";

if( $F{showgrp} )
{
   $form_fields{showgrp}=1;
   push @cols,'������';
   $cols_map[9]=1;
}
 else
{
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%form_fields).'&showgrp=1','�������� ������� '.&commas('������'));
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
   $submit_button="<tr class=rowsv><$tc colspan=$cols>".$br.&submit_a('��������� ���������').$br.'</td></tr>';
   $OUT.=&form_a('!'=>1,'a'=>'pays','act'=>'update_category','start'=>$start,%form_fields);
}

($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,$Max_list_pays,$scrpt.&Post_To_Get(\%form_fields));

$nav=$page_buttons && "<tr class=tablebg><td colspan=$cols>$page_buttons</td></tr>";
$header_tbl="<table class='usrlist width100'>$nav<thead><tr>$header_tbl</tr></thead>";
$br_line="<img src='$img_dir/fon1.gif' width=100% height=1>";
$t1='';
$n_pays=0;
undef $Na_rukax; # ������ = 0 �.�. "�� �����" ����� ���� 0
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

   # ���� ��� ���� �� �������� �������, �� ����� ����������:
   next if $f{event} && !$pr_events &&
     $category!=112 &&	# ����������
     $category!=410 &&	# ���.������ �������
     $category!=411 &&	# �������� ������ �������
     $category!=417 &&	# ������ �� ���������
     $category!=460 &&	# ������� ���������� �����������
     $category!=461;	# ������� ���������� ���������

   $r=~s|\n$||;
   $k=~s|\n$||;
   $tt=&the_time($time);

   # $pay_group - ������, � ������� ��������� ������:
   # 0 - ������������� ����������� ������ �������
   # 1 - ������������� ����������� ������ ������� (��� ������� - ����������� ��� ������� ������ �� ������)
   # 2 - �������� � ����
   # 3 - ������� �� ����
   # 4 - ���� (�������, ���������)
   # 6 - ������������� ������ �����������
   # 7 - ������������� ������ �����������
   # 9 - ��������/����� ���������
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
   {  # ��� ���������� �� ����������� ������ ������� ���-�� �������� �� ����� ������� ���
      unless (defined $Na_rukax)
      {  # ��������� ���������� � ������ ����� �������
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=10 AND bonus='' AND admin_id=$Fadmin AND time<=$time",'���������� �� ����� ������ ������� � ������������ ����� �������');
         $Na_rukax=$h? $h->{cash} : 0;
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND reason='$Fadmin' AND time<=$time",'������� ������ ���������������');
         $Na_rukax-=$h->{cash} if $h;
         $h=&sql_select_line($dbh,"SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND coment='$Fadmin' AND time<=$time",'������� �� ������ ���������������');
         $Na_rukax+=$h->{cash} if $h;
      }
      $t2=$tt=~/^(.+?) .+$/? $1 : ''; # ������� ���� ������� � ���� ������, ����, ��� ������ �������� � &the_time
      $out.=&RRow('tablebg',$cols,&div('lft','�� �����: '.&bold(sprintf("%.2f",$Na_rukax))." $gr")) if $t1 ne $t2; # ���� ����������, ������� �������� �� �����
      $t1=$t2;
      $Na_rukax-=$cash if $f{pay} && !$bonus;		# ������ ��������
      $Na_rukax-=$cash if $f{transfer} && $k==$Fadmin;	# ������� �������� �� ������� ������
      $Na_rukax+=$cash if $f{transfer} && $r==$Fadmin;	# ������� �������� ������� ������
   }

   $cash=sprintf("%.2f",$cash)+0; # �� ����� �������� $Na_rukax, ����� �� ������������� �����������

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
      {  # �������, ��� ������ ���������� �.�. ���� ����� ����� �� ������ - ����� ��������, ��� ����������� ��������� ������ �� ��� �����
         $out.=&RRow('disabled',$cols,
            "������ � ������, � ������� � ��� ".($UGrp_allow{$user{$mid}{grp}}? '�������� ������':'��� �������')." (id ������ $id)");
         next;
      } 
      # ������ (���� ����� �� �������� ��� ���, �� ��� ������ ����� ������� �� id)
      $Clnt=!defined $user{$mid}{name}? '<span class=error>��������� ������</span>' :
         &ShowClient($mid,substr($user{$mid}{name},0,20),$mid).(!!$Atunes{ShowIpInPays} && "<span class=disabled>$user{$mid}{ip}</span>");
   }
    elsif( $mid )
   {# ��������/������� ���������
      if( !$PR{110} )
      {
         $out.=&RRow('disabled',$cols,"����������� ��� ������ id: $id");
         next;
      } 
      $wid=-$mid;
      $Clnt=$W->{$wid}{name}? &tag('span','��������','class=data1').$br.&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$W->{$wid}{name}) :
        &tag('span','����������� ��������','class=error');
   }
    else
   {
      $Clnt=&bold('����');
   }

   $button2=''; # ������ '����� ���'

   {
    if ($f{transfer})
    {  # �������� ��������
       $reason="<span class='modified width100'>".&bold($A->{$r}{login}||'<span class=error>����������� �����</span>').
         ' &rarr; '.&bold($A->{$k}{login}||'<span class=error>����������� �����</span>').'</span>';
       $Clnt=&tag('span','�������� ��������','class=boldwarn');
       last;
    }

    if( $category_subs{$category} )
    {  # � ������ ��������� ���� ����������� ���� reason
       ($reason,undef,$dont_show_coment)=&{ $category_subs{$category} }($r,$k,$time,$mid);
    }else
    {
       $reason=$r!~/^\s*$/? &Show_all($r) : '';
       $dont_show_coment=0;
    }
    
    if( $f{mess} && ($category==491 || $category==492) )
    {  # ��������� � �������������
       $h="$scrpt0&a=pays&op=mess&q=$id&mid=$mid";
       if ($category==491)
       {
          $reason=&tag('span','��������� �� �������:','class=data1').$br.$reason;
          $cash_left=$PR{55} && &CenterA($h,'��������');
          $button2=&ahref("$scrpt0&a=pays&id=$id&act=markanswer",'�',"title='����� ���'") if $PR{18};
       }else
       {
          $reason=&bold('��������� �� �������:').$br.$reason;
          $cash_left=$PR{55} && &ahref($h,'�������� ��������');
       }
    }

    $cash_left.='�������' if $f{event};

    if( $k!~/^\s*$/ && !$dont_show_coment )
    {
       $reason.=$br.$br_line.$br if $reason; # �������������� �����
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
      $_.="<option value=$category selected>������������ ���������: $category</option>" if $category &&
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
   # ���� ��� �� ������� ��� ��������� �������� � ���������
   $out.=!$f{event} || $pr_events? &ahref("$scrpt0&a=pays&act=show&id=$id",'&rarr;'):'&nbsp;';
   $out.=$button2;
   $out.='<td nowrap>'.($mid? $UGrp_name{$user{$mid}{grp}}||'��� ������' : '&nbsp').'</td>' if $cols_map[9];
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
   $OUT.=$br2.&MessX('�� �������:'.$br2.&tag('ul',$out).'������� �� �������');
}
$OUT.='</form>' if $pr_edt_category_pays;  
$OUT.='</td>';

# =========================
# ������ ������������� ����
# =========================

$OUT.="<$tc valign=top>";
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightBlock);
$AddRightBlock.='������:'.&tag('ul',$out) if $out;
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightUrls);
$AddRightBlock.='��������:'.&tag('ul',$out) if $out;
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
  
$out=&Center($h2.$h1.$br.'�� '.&input_t('scash',$F{scash},4,8)." $gr �� ".&input_t('ecash',$F{ecash},4,8)." $gr").$br;

$out1='';
foreach (@filtrs)
{
   ($x,$y,$z,$i)=@{$_};
   $PR{$z} or next;
   $i=" $y$i$br";
   $Fnodeny eq $x? ($out.="<input type=radio name=nodeny value=$x checked>$i"): ($out1.="<input type=radio name=nodeny value=$x>$i");
} 

$out.=$br.&submit_a('��������').$br.&ahref('javascript:show_x("grp")','&darr; �������������');

($out2)=&List_select_grp;

$out.="<div id=my_x_grp style='display:none'>$out1$br";
$out.='������� ������� � ������:'.$br.&Get_Office_List($Foffice).$br2 if $pr_oo;
$out.="��� �����:$br2$out2</div>";

$OUT.=&Mess3('row1',&form('!'=>1,'#'=>1,$out));

$out='';
#$out.=&ahref("$scrpt0&a=multipays",'�������������') if $pr_pays_create;
$out.=&ahref("$scrpt0&a=pays",'�������� ������ ����') if $pr_net_pays_create;
$out.=&ahref("$scrpt0&a=pays&act=mess2all",'��������� ������������� ���������') if $pr_mess_all_usr;
$out.=&ahref("$scrpt0&a=report",'�����') if $pr_fin_report;
$out.=&ahref("$scrpt0&a=pays&act=send",'�������� ��������') if $pr_transfer_money;
$out.=&ahref("$scrpt&act=list_categories",'��������� ��������');
$out.=$pr_other_adm_pays? &ahref("$scrpt&act=list_admins",'��������������') :
     &ahref("$scrpt&nodeny=admin&admin=$Admin_id","���� ������� ($UU)");
$out.=&ahref("$scrpt&act=zarplata",'���������') if $pr_worker_pays_show;
$out.=&ahref("$scrpt&nodeny=adminall&admin=0",'�������');

$OUT.=&div('nav2',&Mess3('row1',$out)).'</td></tr></table>';
&Exit;

# ------------------------------------
#	����� ������ �������
# ------------------------------------
sub list_admins
{
 if( !$pr_other_adm_pays )
 {  # ��� ���� �� �������� �������� ������� ������, ����� ������� ������� �������� ������
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
 $sth=&sql($dbh,$sql,'������ �������');
 while ($p=$sth->fetchrow_hashref)
 {
    $office=$p->{office};
    if( $last_office!=$office )
    {
       if( $out )
       {
          $out.=$OUT1;
          $out.=&RRow('rowoff','C','���������� ��������������').$OUT2 if $OUT2;
          $out.='</table>';
          if ($i) {$OUTL.=$out} else {$OUTR.=$out}
          $i=1-$i;
       } 
       $out="<table class='tbg1i width100'>".&RRow('head','C','����� '.&bold($Offices{$office} || '�� ������'));
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
    $out.=&RRow('rowoff','C','���������� ��������������').$OUT2 if $OUT2;
    $out.='</table>';
    if ($i) {$OUTL.=$out} else {$OUTR.=$out}
    $i=1-$i;
 } 

 $out='';         
 # �������������� � ��������, �� ������������� � ������� �������
 $sth=&sql($dbh,"SELECT DISTINCT admin_id FROM pays p LEFT JOIN admin a ON p.admin_id=a.id WHERE a.id IS NULL AND p.admin_id<>0",
     '������� id ���������������, ������� ����������� � ������� admin, �� ������������ � ��������');
 while ($p=$sth->fetchrow_hashref)
 {
    $admin_id=$p->{admin_id};
    $out.=&ahref("$scrpt&nodeny=admin&admin=$admin_id","������������� � ���� ����� � id: $admin_id");
 }

 $i? ($OUTL.=$out) : ($OUTR.=$out);

 $OUT.=&Table('nav3 table1 width100',"<tr><td width='50%' valign=top>$OUTL</td><td valign=top>$OUTR</td></tr>");
 &Exit; # ������� ������ �� �������, ������ ������ �������
}

# --------------------------------------
#	����� ������ ����������
# --------------------------------------
sub zarplata
{
 if( !$pr_worker_pays_show )
 {
    $OUT.=&error('��������!','��� ���� �� �������� �������/�������'.$go_back);
    $Fnodeny='admin';
    $F{admin}=$Admin_id;
    return;
 }
 $Fnodeny='zarplata';
 $F{mid}=0; # ����� ������� ��������� �������� �� ����

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
       &CenterA("$scrpt&mid=-$id",'�������'),
       ($pr_worker_pays_create && &CenterA("$scrpt0&a=pays&mid=-$id",'������'))
    );
 }

 if( !$out )
 {
    &Message('� ��������� ��� ������� ��� �� ������ ���������.');
    return;
 }

 $OUT.=&Table('tbg1 width100',
   &RRow('head','5',&bold_br('���������')).
   ($page_buttons && &RRow('tablebg','5',$page_buttons)).
   &RRow('head','ccccc','���','�����','���������','�������','������<br>��������').
   $out
 ).$br2;
}

# -----------------------------------------
#	������ ��������� ��������
# -----------------------------------------
sub list_categories
{
 @cols=();
 $url="$scrpt&nodeny=category&year=$year_now&mon=$mon_now&category=";
 $cols[int($_/100)].=&ahref($url.$_,$ct{$_}) foreach (sort {$ct{$a} cmp $ct{$b}} (keys %ct));

 $OUT.=&Table('tbg1 nav2',
  &RRow('head','ccccccccc',
    '����������� ���������� ����� �������',
    '����������� ������ �� ����� �������',
    '�������� ���������� ����� �������',
    '�������� ������ �� ����� �������',
    '�������� � ����',
    '������� ����',
    '������� ����������',
    '����',
    '��� ���������'
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
    &ahref($url.'0','��� ���������')
  )
 );     
 &Exit;
}

1;
