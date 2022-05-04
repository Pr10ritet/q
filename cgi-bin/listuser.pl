#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Allow_grp or &Error($pr_SuperAdmin? '��� ������� �� � ����� ������ �������' : '��� ���� �� ������ � ��������� �������');

&LoadJobMod();
&LoadMoneyMod();
&LoadDopdataMod();

$eurl='';				# end url - ������, ������������ � ������� � ������� �������

$Fw=int $F{w};				# ������ `���` - ����� ������� �������� � ������
$eurl.="&w=$Fw" if $Fw;
$Fed=int $F{ed};			# ������� ��������� ������� (��/��/����)
$eurl.="&ed=$Fed" if $Fed;
$Fed||=2;				# �� ��������� ����� ��
$Fed--;					# ��� ������������ ����������� ��� �� 1 ������

$Fsort=$F{sort};
$Fsort='0' if $Fsort!~/^\-?[0-9a-z]+$/;
$eurl.="&sort=$Fsort" if $Fsort;
$sort=$Fsort;
$sort=~s/^\-//;

$f=$F{f} || '0';			# filtr
%f=( $f=>1 );
$eurl.="&f=$f";

# === ������ � ������� ===

$out_grps=$h='';
# ��������� �� �������
foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
{
   if( $UGrp_allow{$g} )
   {
      $out_grps.=&ahref("$scrpt&f=0&grp=$g",$UGrp_name{$g});
   }else
   {
      $h.=$br.$UGrp_name{$g};
   }
}
$Debug.="��� ���������� �� ������ � �������: $h$br � ������ �� ����� �����������.".$br2 if $h;

# === ������ �� ������? ===
$Fgrp=int $F{grp};
if( $Fgrp )
{
   $UGrp_allow{$Fgrp} or &Error('������ �� �������� ������ ���������� �.� � ��� ��� ���� �� ������ � ���.');
   $Allow_grp=$Fgrp;
   $where_grp="grp=$Allow_grp AND";
   $scrpt.="&grp=$Fgrp";
   $FormHash{grp}=$Fgrp;
   $can_full_search=1;
   $OUT.=&MessX(&Printf('��������. �������� ������ �� ������ [bold]. ����� ����� ����� �������� ������ ���� ������!',$UGrp_name{$Fgrp}));
}
 elsif( !$F{fullsearch} )
{
   # $Allow_grp		- ������ �����, � ������� ����� ����� ������
   # $Allow_grp_less    - ������ �����, ����� ���, ������� ����� ��� ���� ��������
   # �� �� ��� %UGrp_allow=%UGrp_allow_less.
   $can_full_search=$Allow_grp ne $Allow_grp_less; # ������ ����� �������� ���� ���� �� ���� ������ ���������
   # ���� ����� �������� ��� ���� ������ � ��������� �������, �� �������� ��
   $Allow_grp=$Allow_grp_less;
   %UGrp_allow=%UGrp_allow_less;
   # ��� ����������� � ������� ������ ��� ��� ��������� ���������� ������. � ����� ������ �������� ����� ��� ����������� �����
   $where_grp=$pr_SuperAdmin && !$can_full_search? '' : "grp IN ($Allow_grp) AND";
}
 else
{
   $can_full_search=0;
   $eurl.="&fullsearch=1";
   $where_grp="grp IN ($Allow_grp) AND";
}

# === ���������� ������� �� ������� ���������� ===
if( !$f && ($p=&sql_select_line($dbh,"SELECT COUNT(id) AS n FROM users WHERE $where_grp cstate=11",'���������� ������� �� ������� ����������')) )
{  # ������� ������ ���� ������������� �� ������ ������ - �������� �������
   $p=$p->{n};
   $p=$p>4? "$p ������� ���������" : ('','1 ������ ���������','2 ������ ���������','3 ������ ���������','4 ������ ���������')[$p];
   $OUT.=&MessX(&ahref("$scrpt$eurl&f=c&cs=11",$p).' � ������� �� ������� ����������.') if $p;
}

# === ������� �������� ��� ������ �������? ===
if( $F{colnarrow} || $F{colextend} )
{
    $col_id=int($F{colnarrow} || $F{colextend});
    $h=$F{colnarrow}? 0:1;
    $tunes=$p_adm->{tunes};
    $tunes=~s|(cols-$Fw-$col_id,)\d|$1$h|;
    $Atunes{"cols-$Fw-$col_id"}=$h;
    $tunes=&Filtr_mysql($tunes);
    &sql_do($dbh,"UPDATE admin SET tunes='$tunes' WHERE id='$Admin_id' LIMIT 1",'�������� ��������� �������');
}

# === �������������� ���� ������������ �������������� ����� ===
$p=nSql->new({
  dbh		=> $dbh,
  sql		=> "SELECT * FROM dopfields",
  show		=> 'short',
  comment	=> '�������������� ���� ������������ �������������� �����'
});
%fields=(
  id		=> \$id,
  field_alias	=> \$field_alias,
  field_name	=> \$field_name,
  template_num	=> \$template_num,
  field_type	=> \$field_type,
  field_flags	=> \$field_flags
);
@title_fields=();	# ��������� ���� (���� � ������ `�������� ��� ������`)
%title_tmpl=();		# ������� � ���������� ������
while( $p->get_line(\%fields) )
{
   $field_name=~s|^\[\d+\]\s*||; # ������ ������������� �������
   $dopf_a_to_id{$field_alias}=$id;
   $dopf_id_to_a{$id}=$field_alias;
   $dopf_id_to_name{$id}=$field_name;
   $dopf_id_to_type{$id}=$field_type;
   $dopf_id_to_template{$id}=$template_num;
   $dopf_a_to_name{$field_alias}=$field_name;
   $dopf_a_to_template{$field_alias}=$template_num;
   if( $field_flags=~/q/ && $Dopfields_tmpl{$template_num} )
   {   # ��������� ���� � ������ ���������� (����� ��������� � �������)
       push @title_fields,$id;
       $title_tmpl{$template_num}++;
   }
}

$where_adr_id='';	# ������ id �������������� ����� �� ������� `�����`
$template_adr=0;	# ����� ������� `�����`
$err_tmp='';
# ��� ������ ������ �������� ��� ����������� ������ �� ����� �������������� ����� (������):
foreach $alias (
   'p_street:street:name_street',
   '_adr_house',
   '_adr_floor',
   '_adr_room',
   '_adr_telefon',
   '_adr_block',
   '_adr_front_door',
)
{
   $dopf_a_to_id{$alias} or next;
   $where_adr_id.=$dopf_a_to_id{$alias}.',';
   if( $template_adr && $template_adr!=$dopf_a_to_template{$alias} )
   {
      $err_tmp=&MessX(&Printf('[span error][]','��������!',' ���������� � �������� ��������������: ��������� ������ ��������� � ������ �������� �������������� ������. ��� �����������'));
   }
   $template_adr=$dopf_a_to_template{$alias};
}

if( $err_tmp )
{
   $Debug.="��������� ������ ��������� � ������ �������� �������������� ������. � �����, ������������ �����, ���� ������, ������������ �� `_adr_` - ��� ���� ��������� � ������ ��������. ���������� ����� �� ������ � ����� ������ ����������.".$br2;
   $OUT.=$err_tmp;
}
$where_adr_id=~s|,$|| or ($where_adr_id='0');

$template_adr or ($Debug.="� �������� �������������� ������ ��� �� ������ ���� ���������� � �������. ����� �� ������ ����������.".$br2);

# ===========================
# ������� �������������� ����
# ===========================

if( $dopf_a_to_id{_adr_house} )
{
   $adr_house_id=$dopf_a_to_id{_adr_house};
   # � �������� ���� ������� ����� + ���������� ������? �������� ���� ��������� �� ����� ���� � ����
   $adr_block=$2 if $F{"dopfield_$adr_house_id"}=~s|^ *(\d+)[\-'"\/\\]*([^\d].*)$|$1|;
   $adr_house=$F{"dopfield_$adr_house_id"};
}

if( $dopf_a_to_id{_adr_block} )
{
   $adr_block_id=$dopf_a_to_id{_adr_block};
   $F{"dopfield_$adr_block_id"}=$adr_block if $adr_block;
   $adr_block=&trim($F{"dopfield_$adr_block_id"});
}

if( $dopf_a_to_id{_adr_room} )
{
   $adr_room_id=$dopf_a_to_id{_adr_room};
   $adr_room=&trim($F{"dopfield_$adr_room_id"});
}

$adr_street_id=$dopf_a_to_id{'p_street:street:name_street'} || 0;
$adr_street=int $F{"dopfield_$adr_street_id"};


%streets=();
$streets='';
$nsql=nSql->new({
    dbh		=> $dbh,
    sql		=> "SELECT * FROM p_street ORDER BY name_street",
    show	=> 'short',
    comment	=> '������ ���� ����'
});
while( $nsql->get_line( {'street'=>\$street,'name_street'=>\$name_street} ) )
{
   $streets{$street}=$name_street;
   $streets.="<option value=$street".($adr_street==$street && ' selected').">$name_street</option>";
}

# dopfield_full_* - �������� ������������ ������ ����� (�� ��� LIKE '%data%')

$style='border:#ccd8e0 1px solid;';
$style.=' width:30px;' if !$adr_street;
$streets= !!$streets && qq{<select name=dopfield_$adr_street_id size=1 style='$style' id='sel_str' onChange='document.getElementById("sel_str").style.width="auto"'>}.
   &tag('option','&nbsp;',"value=''").$streets.'</select>'.&input_h("dopfield_full_$adr_street_id",1);

$adr_line=$streets;
$adr_line.='&nbsp;&nbsp;'.$dopf_a_to_name{_adr_house}.': '.&input_t("dopfield_$adr_house_id",$adr_house,5,10).&input_h("dopfield_full_$adr_house_id",1) if $adr_house_id;
$adr_line.='&nbsp;&nbsp;'.$dopf_a_to_name{_adr_block}.': '.&input_t("dopfield_$adr_block_id",$adr_block,2,10).&input_h("dopfield_full_$adr_block_id",1) if $adr_block_id;
$adr_line.='&nbsp;&nbsp;'.$dopf_a_to_name{_adr_room}.': '.&input_t("dopfield_$adr_room_id",$adr_room,4,10).&input_h("dopfield_full_$adr_room_id",1) if $adr_room_id;

$spacer="<img height=1 src='$spc_pic'>";

$OUT.=&Table('width100 nav2',
 &RRow('row2',' lcr ',
  '',
  &ahref('javascript:show_x("filtr")','������'),
  &Table('',
    &RRow('','l l',
      &form('#'=>1,'f'=>'n',&input_t('name',$F{name},25,50).'&nbsp;'.&submit('�����')),
      '',
      &form('#'=>1,'f'=>'d','tmpl'=>$template_adr,$adr_line.' '.&submit('�����'))
    )
  ),
  $template_adr? &ahref("$scrpt0&a=dopdata&parent_type=0&act=search&tmpl=$template_adr",'�����') : '&nbsp;',
  ,,
 )
).$br;


# �������� ����� �� ��������� �����
if( $adr_street && $adr_block_id )
{  #  ������� ����� ($adr_street) � ���� `���` ���������� � dopfields
   $houses='';
   $url="$scrpt&f=d&tmpl=$template_adr&dopfield_full_$adr_street_id=1&dopfield_$adr_street_id=$adr_street&dopfield_full_$adr_house_id=1&dopfield_$adr_house_id=";
   $sql=qq{SELECT DISTINCT b.field_value AS house FROM 
     (SELECT parent_id FROM dopdata WHERE parent_type=0 AND field_alias='p_street:street:name_street' AND field_value='$adr_street') a
      INNER JOIN dopdata b ON a.parent_id=b.parent_id WHERE b.field_alias='_adr_house'
   };
   $sth=&sql($dbh,$sql,"��� ���������� ���� �� ����� � $adr_street");
   while( $p=$sth->fetchrow_hashref )
   {
      $house=int $p->{house};
      $houses.=&ahref($url.$house,$house);
   }
   $OUT.=&MessX("$dopf_a_to_name{_adr_house} �� ����� ".&bold($streets{$adr_street}).' :'.&div('nav',$houses),0,1) if $houses;
}


# =======================
#      ������� ���� 
# =======================

$out1=&div('nav3',$out_grps);

$out2='';
$out2.=&ahref("$scrpt&f=2",'�������������� ������');
$out2.=&ahref("$scrpt&f=1",'� �������� &lt;0 ��� �����').
  &ahref("$scrpt&f=7",'� �������� &lt;0 � ��������').
  &ahref("$scrpt&f=e",'������� ��������� ������') if $pr_show_traf;
$out2.=&ahref("$scrpt&f=3",'���� �������� ������').
  &ahref("$scrpt&f=o",'���� �������� ������').
  &ahref("$scrpt&f=6",'��� �������������� ������').
  &ahref("$scrpt&f=a",'������ ������ ip').
  &ahref("$scrpt&f=b",'�� ������� ����� �����������').
  &ahref("$scrpt&f=g",'��� �����������').
  &ahref("$scrpt&f=f",'� ���� �������� ����� ������').
  &ahref("$scrpt&f=5",'� ��������������� ��������').
  &ahref("$scrpt&f=p",'�������� �� � ������ ������');
$out2=&div('nav3',$out2);

$out3.='C��������:'.$br.&ahref("$scrpt&f=w",'�� �����������').&ahref("$scrpt&f=c&cs=-1",'��� � �� '.&commas('��� ��')).$br;
foreach $cs (sort{ $cstates{$a} cmp $cstates{$b} } keys %cstates)
{
   next if !$cs || $cs==9;
   $out3.=&ahref("$scrpt&f=c&cs=$cs",$cstates{$cs});
}
$out3=&div('nav3',$out3);

$out4=&ahref("$scrpt&f=j&job=-1",'������� �������');
$out4.=$br.&ahref("$scrpt&f=j&job=-2",'��� ��������������');
$i=0;
$out4.="<a href='$scrpt&f=j&job=".$i++."'>$_</a>" foreach (@jobs);

$out4=&div('nav3',$out4);

$list_year=&Set_year_in_list($year_now);
($mon_list,$mon_name)=&Set_mon_in_list($F{mon}? int $F{mon} : $mon_now);

$out5=&form('#'=>1,'f'=>'9','����� �����������: '.&input_t('box',$Fbox||'',5,7).' '.&submit('�����')).$br.
  &form('#'=>1,'f'=>'8',"��������, ����������� �������".$br."$mon_list $list_year ".&submit('��������'));

$out.=join '',map{ &ahref("$scrpt0&a=dopdata&parent_type=0&act=search&tmpl=$_",(split /-/,$Dopfields_tmpl{$_})[0]) } 
     sort{ $Dopfields_tmpl{$a} cmp $Dopfields_tmpl{$b} } grep{ int($_/100)==0 } keys %Dopfields_tmpl;
$out5.=$br2.'����������� ����� � �������:'.$br.&div('nav2',$out) if $out;

$OUT.=&Table("' id=my_x_filtr style='display:none'",&RRow('','ttttt',&MessX($out1,0,1),&MessX($out2,0,1),&MessX($out3,0,1),&MessX($out4),&MessX($out5)));

# =======================
#         �����
# =======================

$sel_from_users="id FROM users WHERE $where_grp";
$sel_from_fullusers="id FROM fullusers WHERE $where_grp";
$sel_from_users=$sel_from_fullusers if abs($F{sort})>5; 

$msql='';
$filtr='';
$tbl_sort='';

%filtrs= (
  '0' => ["$sel_from_users mid=0",			'��� �������'],
  '1' => ["$sel_from_users balance<0",			'� ������������� �������� ��� ����� ������ �� ������'],
  '2' => ["$sel_from_users auth<>'no'",			'�������������� � ������ ������'],
  '3' => ["$sel_from_users state='off'",		'���� �������� ������'],
  '5' => ["$sel_from_users srvs>0",			'� ��������������� ��������'],
  '6' => ["$sel_from_users block_if_limit=0",		'� ���� �� ���������� �������� �����'],
  '7' => ["$sel_from_users 1",				'� ������������� �������� � ������ ������ �� ������'],
  '8' => [0,\&s_contr_date],
  '9' => ["$sel_from_users hops=".int($F{box}),			"����� ����������� ".int($F{box})],
  'a' => ["$sel_from_users mid>0",			'������ ������ ip'],
  'b' => ["$sel_from_users hops=0",			'�� ������� ����� �����������'],
  'c' => [0,\&s_state],
  'd' => [0,\&s_dopdata],				# �� ��� ������, ����� �� ���� �������� �������������� ����
  'e' => ["$sel_from_fullusers mid=0 AND ".
             "(out1=0 OR out1 IS NULL) AND ".
             "(out2=0 OR out2 IS NULL) AND ".
             "(out3=0 OR out3 IS NULL) AND ".
             "(out4=0 OR out4 IS NULL)",		'��������� ������ = 0'],
  'f' => ["$sel_from_users next_paket<>0",		'� ���� �������� ����� ������'],
  'g' => ["$sel_from_users lstate>0",			'������ ��� �����������'],
  'h' => [0,\&s_paket],
  'i' => [0,\&s_nextpaket],
  'j' => [0,\&s_work],
  'k' => [0,\&s_work],
  'l' => ["$sel_from_users mid=0",			'������ �������� ������'],
  'n' => [0,\&s_name],
  'o' => ["$sel_from_users state<>'off'",		'���� �������� ������'],
  'p' => ["$sel_from_users start_day>0",		'������, ������� � ������ �� � ������ ������'],
  'q' => [0,\&s_dopdata],
  'r' => [0,\&s_paket3],
  'w' => ["$sel_from_users (cstate=9 OR cstate=10)",	'�� �����������'],
);

if( $filtrs{$f}[0] )
{
   $msql=$filtrs{$f}[0];
   $filtr=$filtrs{$f}[1];
}
 elsif( defined $filtrs{$f}[0] )
{
   $filtr='';
   &{ $filtrs{$f}[1] }; 
}
 else
{
   $Debug.='�������������� �������. �������� ������������ � ����� ������ �� ������ �� ������� ��������.'.$br2;
   $filtr='�������, ������� ������ ���� ���������� ��������������';
}

# 0: ����
# 1: ��������
# 2: ������ ������ ��� url
# 3: ��������� ��������
# 4: what_search
sub Check_Sql
{
 my ($h,$p);
 $Fwhat_search && ($Fwhat_search ne $_[4]) && return 0; # ����� ����� �� ����������� ���� � ������� ���� ����
 # �����
 $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM users WHERE $where_grp $_[0] LIKE '$_[1]'","�����: $_[3].");
 # ���� ������ �� �������, �� �������. ���� �� ������� � ��� ����� ������ ���� ����� - �� �������
 !$p->{n} && !$Ws{$_[4]} && return 0;
 $h="&f=n&what_search=$_[4]&name=".&URLEncode($_[2]);
 $filtr.=&RRow('*','lc',$_[3],&ahref("$scrpt$h",$p->{n}));
 $esql.=($esql && ' OR ')."($_[0] LIKE '$_[1]')";
 $eurl.=$h if $Ws{$_[4]};
 return $Ws{$_[4]};
}

sub s_name
{
 $Fwhat_search=$F{what_search};
 %Ws=( $Fwhat_search=>1 );

 $Fname=&trim($F{name});

 $FnameSql=&Filtr_mysql($Fname);
 $FnameOut=&Filtr_out($Fname);

 $esql='';
 {
   &Check_Sql('fio',"%$FnameSql%",$FnameOut,'�������� ���','fio') && last;

   $like_ip=$FnameSql=~/^([\d\.\/��])+$/? $FnameSql : ''; # ������ ������ ������ �� ip
   $like_ip=~s|[��/]|.|g;

   # === ����� �� ip ���� ������ ������ �� ������ ip ===
   if( $Ws{ip} || $like_ip=~/^\d+\.\d+\.\d+\.\d+$/ )
   {
     &Check_Sql('ip',$like_ip,$like_ip,'������ ip','ip') && last;
   }

   if( $Ws{net} || ($like_ip && $like_ip!~/^\./) )
   {
     $net=$like_ip;
     $net=~s|([^\.])$|$1.|; # � ����� ��� ����� - �������
     &Check_Sql('ip',"$net%",$net,'��������','net') && last;
   }
 
   # === ����� �� ��������� ip ���� ������ ������ �� ip, ��� ���� � ����� ��� ����� ===
   if( $Ws{partip} || ($like_ip && $like_ip!~/\.$/) )
   {
     $like_ip=~s|^([^\.])|.$1|; # � ������ ��� ����� - �������
     &Check_Sql('ip',"%$like_ip",$like_ip,'�������� ip','partip') && last;
   }

   # === ����� � ��������������� ===
   if( $Fname!~/[���������������������������������������������������������������޸��]/ ) # ������ [�..��..�] �.� �������� �����
   {  # � ������� ��� ������������ ���� - ����� ������ � ���������?
     $tr_name=$Fname;
     # ������ � ������� �� �
     $tr_name=~tr/qwertyuiop[]asdfghjkl;'zxcvbnm,.QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>`��/���������������������������������������������������������������޸��/;
     $f_name=&Filtr_mysql($tr_name);
     ($f_name ne $FnameSql) && &Check_Sql('fio',"%$f_name%",$tr_name,'��� � ���������������','fio') && last;
   }

   &Check_Sql('name',"%$FnameSql%",$FnameOut,'�������� ������','partlogin') && last;
   &Check_Sql('name',"$FnameSql",$FnameOut,'�����','login') && last;
   &Check_Sql('fio',"$FnameSql%",$FnameOut,'�������','fio1') && last;
   &Check_Sql('contract',"%$FnameSql%",$FnameOut,'��������','contract') && last;
   $eurl="&f=n&name=".&URLEncode($Fname);
 }
 
 if( $esql )
 {  # ���-�� �������
    $msql="$sel_from_users ($esql)";
    $filtr&&=&Table('tbg3 nav3',&RRow('head','cc','����� ��','�������').$filtr);
 }
  else
 {
    $msql='';
    $filtr='����� �� ���� �������� �����';
    $eurl.="&name=".&URLEncode($FnameOut);
 }
}

#=== ����� �� �������������� ����� ===

sub s_dopdata
{
 $Ftmpl=int $F{tmpl};
 $eurl.="&tmpl=$Ftmpl";
 %search_data=();
 $filtr='';
 @fields=grep{ $dopf_id_to_template{$_}==$Ftmpl } keys %dopf_id_to_template;
 foreach $id ( sort{ ($sort==$a) cmp ($sort==$b) } @fields )
 {
    $val=$F{"dopfield_$id"};
    $nosearch=($val=~/^\s*$/);
    $sort!=$id && $nosearch && next; # ���� ������� ���������� �� ������� ����, �� ��� ���� �������� � sql-������, ���� ���� �� ���� ��� ������
    $dopfield_full=!!$F{"dopfield_full_$id"};
    $search_data{$id}=$dopfield_full? $val : "%$val%";
    $eurl.="&dopfield_$id=".&URLEncode($val)."&dopfield_full_$id=$dopfield_full";
    $field_value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $dopf_id_to_type{$id},
          alias	=> $dopf_id_to_a{$id},
          value	=> $val,
       })
    );
    $field_name=&Filtr_out($dopf_id_to_name{$id}) || "���� � id=$id";
    $filtr.=&RRow('*','lrc',
       $field_name,
       $field_value,
       '&nbsp;&nbsp;'.($nosearch? '����� ��������' : $F{"dopfield_full_$id"}? '������ ������������ ':'��������� ������������').'&nbsp;&nbsp;',
    );
 }

 $line1=$line2='';
 foreach $id (@fields)
 {
    $field_name=&Filtr_out($dopf_id_to_name{$id}) || "���� � id=$id";
    # ���� ���������� �� ����/��������, �� ����� ����� ��� ������ �������������� �������� � ���������
    $url="$scrpt$eurl&f=".($dopf_id_to_a{$id} eq '_adr_house' || $dopf_id_to_a{$id} eq '_adr_room'? 'd' : 'q');
    $line1.=&tag('td',$field_name,'class=cntr colspan=2');
    $line2.=&tag('td',&Printf($Fsort==$id? '[div borderblue]':'[]',&ahref("$url&sort=$id",'&nbsp;&nbsp;&nbsp;&uarr;&nbsp;&nbsp;&nbsp;')),'class=cntr').
            &tag('td',&Printf($Fsort==-$id? '[div borderblue]':'[]',&ahref("$url&sort=-$id",'&nbsp;&nbsp;&nbsp;&darr;&nbsp;&nbsp;&nbsp;')),'class=cntr');
 }

 $tbl_sort=&Table('tbg1',
    &tag('tr',&tag('td',&bold('�������� ����:').'&nbsp;&nbsp;').$line1,'class=row2').
    &tag('tr',&tag('td',&bold('�����������:').'&nbsp;&nbsp;').$line2,'class=row1')
 );

 $tmpl_name=&commas(&Filtr((split /-/,$Dopfields_tmpl{$Ftmpl})[0]) || "� $Ftmpl");

 $filtr=!$filtr? "��� �������, ������� ������".$br."� ������� $tmpl_name" :
   &Table('tbg1 nav3',
     &RRow('head',3,"����� �� ������ � ������� $tmpl_name").
     &RRow('tablebg','ccc','�������� ����','��� ����','��� ������').
     $filtr
   );

 # $msql: ����� sql-������� ������� ����� �� dopvalues, ������� ������������� �������. $msql='FROM dopvalues WHERE ....'
 $msql=&nDopdata_search
 ({
    parent_type		=> 0,		# ����� ������ ��������
    template_num	=> $Ftmpl,	# � ������� � $Ftmpl
    sort_id		=> $sort,	# ����������� �� ����
    data		=> \%search_data
 });

 $h=$Fsort<0 && ' DESC';
 $msql=~s/SELECT//;
 # ���� ������� ���������� �� �������, �� �������, ����� ��� ����� ��������� � ������� users - ��� ���� ����������
 $msql=$Fsort? "$msql ORDER BY (field_value+0)$h,field_value$h" : "$sel_from_users id IN (SELECT $msql)";
 
 if( $f{q} )
 {# ������ ����� ���� �� ������������ ������, ���� �� �� ������.
    $Atunes{"cols-$Fw-30"}=1 if $f{q};	# ��������� ������� `���������`
    %title_tmpl=( $Ftmpl => 1);		# � ���� ������� ��������� ������ ������ ��� ����������� �������
 }
}

# === ����� �� ���� ��������� ===

sub s_contr_date
{
 $month=int $F{mon};
 $year=int $F{year};
 $eurl.="&mon=$month&year=$year";
 $month-- if $month;
 $time1=timelocal(0,0,0,1,$month,$year); #  ������ ������
 if( $month<11 ) {$month++} else {$month=0; $year++}
 $time2=timelocal(0,0,0,1,$month,$year); #  ������ ���������� ������
 $msql="$sel_from_users mid=0 AND contract_date>=$time1 AND contract_date<$time2";
 $filtr="����� ���������� ��������";
 $Atunes{"cols-$Fw-6"}=1; # ��������� ������� `��������`
 $Atunes{"cols-$Fw-7"}=1; # `���� ���������`
} 

# === ������ �� ��������� ������� ������ ===

sub s_state
{
 $cs=int $F{cs};
 $eurl.="&cs=$cs";
 $filtr=" WHERE $filtr_allow ";
 if( $cs<0 )
 {  # �������� ����, � ���� ��������� "�� '��� ��'", �� ���������� cstate=6 - ��� ����������� ��������� ( � ��� ��� �� :) )
    $msql="$sel_from_users cstate>0 AND cstate<>6";
    $filtr='��������� �� '.&commas('��� ��');
 }else
 {
    $msql="$sel_from_users cstate=$cs";
    $filtr="���������: '$cstates{$cs}'";
 }
 $Fsort='e';
 $sort='e';
}

# === ������ �� ���� ������� ===
# -1 - �������������
# -2 - ��������������
# >0 - ����� �������

sub s_work
{
 $Fjob=int $F{job};
 $eurl.="&job=$Fjob";
 $filtr=$Fjob==-1? '������������� �������' :
        $Fjob<0?"�������������� �������" :
        '�������: '.($jobs[$Fjob]||'���� ��� �����');
 # � ���� reason ���������� ������ ������
 $reason=$Fjob==-1? "reason LIKE '%,%'" : $Fjob<0? "reason NOT LIKE '%,%'" : "reason=$Fjob";
 if( !$pr_oo )
 {  # ������ ������ ������ ������
    $reason.=" AND office=$Admin_office";
    &DEBUGX("��������: ����� �������� ������ ������ � ������ �������������� (��� ���������� ������ � ������� ��������).");
 }
 $msql="$sel_from_users id IN (SELECT mid FROM pays WHERE type=50 AND category=460 AND $reason)";
}

# === ������ �� ������ ===

sub s_paket
{
 $pkt=int $F{p};
 $eurl.="&p=$pkt";
 !$pr_SuperAdmin && !$Plan_allow_show[$pkt] && &Error('���� ���������� �� ��������� �������� ������ �������� � �������� �������.');
 $OUT.=&ahref("$scrpt&f=i&p=$pkt",'�������� ���, � ���� ������� ������ �����').$br;
 $filtr='����� '.&commas($Plan_name_short[$pkt] || '����������� �����');
 $msql="$sel_from_users paket=$pkt";
}

sub s_nextpaket
{
 $pkt=int $F{p};
 !$pr_SuperAdmin && !$Plan_allow_show[$pkt] && &Error('���� ���������� �� ��������� �������� ������ �������� � �������� �������.');
 $filtr='���������� ����� '.&commas($Plan_name_short[$pkt] || '����������� �����');
 $msql="$sel_from_users next_paket=$pkt";
 $eurl.="&p=$pkt";
}

sub s_paket3
{
 $pkt=int $F{p};
 $filtr=$pkt? '�������������� ����� ����������� '.&commas($Plans3{$pkt}{name_short} || '����������� �����') : '�� ������� �������������� ����� �����������';
 $msql="$sel_from_users paket3=$pkt";
 $eurl.="&p=$pkt";
}

# -------------------------------------------------------------------------------------------------------

$nsql=nSql->new({
    dbh		=> $dbh,
    sql		=> "SELECT mid FROM pays WHERE type=50 AND category=460",
    show	=> 'short',
    comment	=> '������������� ������� ����������'
});
while( $nsql->get_line( {'mid'=>\$mid} ) )
{
   $JobIsNow{$mid}=1;
}

$out_bottom=$f{j} && $br.'<table width=50%><tr><td>'.&nJob_ShowJobBlank(0,$F{job}).'</td></tr></table>'; # ������ ������ `������� ����������`. $F{job}, � �� $job !

%orders=(
  '0' => ['sortip',		'Ip',			8],
  '1' => ['id',			'Id',			1],
  '2' => ['name',		'�����',		3],
  '3' => ['fio',		'���',			2],
  '4' => ['cstate_time', 	'����� ���������',	0],
  '5' => ['balance',		'������',		4],
  '6' => ['(startmoney-submoney)','� ��������',		14],
  '7' => ['(traf1+traf2+traf3+traf4)','������',		21]
);

$order_by='';
if( !$tbl_sort )
{
  $line1=$line2='';
  foreach $h (sort keys %orders)
  {
     $line1.=&tag('td',$orders{$h}->[1],'class=cntr colspan=2');
     $line2.="<$tc>".&Printf($Fsort eq $h? '[div borderblue]':'[]',&ahref("$scrpt$eurl&sort=$h",'&nbsp;&nbsp;&nbsp;&uarr;&nbsp;&nbsp;&nbsp;')).'</td>'.
        "<$tc>".&Printf($Fsort eq "-$h"? '[div borderblue]':'[]',&ahref("$scrpt$eurl&sort=-$h",'&nbsp;&nbsp;&nbsp;&darr;&nbsp;&nbsp;&nbsp;')).'</td>';
     if( $sort eq $h )
     {
        $order_by='ORDER BY '.$orders{$h}->[0];
        $order_by.=' DESC' if $Fsort ne $h;
        $i=$orders{$h}->[2];
        $Atunes{"cols-$Fw-$i"}=1 if $i; # ��������� ������� ������ ������ ��������
     }
  }
  $tbl_sort=&Table('tbg1',
    &tag('tr',
      &tag('td',&bold('�������� ����:&nbsp;&nbsp;')).
      $line1,
     'class=row2'
    ).
    &tag('tr',
      &tag('td',&bold('�����������:&nbsp;&nbsp;')).
      $line2,
     'class=row1'
    )
  );
}


# �������������� ������� �� ����������� ������

%add_f=(
  'm'	=> '����.���',
);
$F{af}=~s|[^a-z]||g;
$line1=$line2='';
foreach $h (keys %add_f)
{
   $line1.="<$tc>$add_f{$h}</td>";
   $_=$F{af};
   $_.="$h" if !s|$h||;
   $line2.="<$tc>".&ahref("$scrpt$eurl&af=$_",$F{af}=~/$h/? '������' : '��������')."</td>";
}
$tbl_add_f=&Table('tbg1',&tag('tr',$line1,'class=row2').&tag('tr',$line2,'class=row1'));
$eurl.="&af=$F{af}" if $F{af};

$show_auth_m=($F{af}=~/m/);

$Fstart=int $F{start};
$Max_list_users=1 if $Max_list_users<1;
$start=$Fstart*$Max_list_users;


# ---  ���������� ��������� ������� ---

if( $msql )
{
   $msql="SELECT SQL_CALC_FOUND_ROWS $msql $order_by LIMIT $start,$Max_list_users";
   $t0_sql=[gettimeofday];
   $sth=$dbh->prepare($msql);
   $sth->execute;
   $t0_sql=tv_interval($t0_sql);
   $rows=$dbh->selectrow_array("SELECT FOUND_ROWS()");
   &DEBUGX(&Printf('[span data2][br][][br][][br][]','�������� ������:',$msql,"����� ���������� sql: $t0_sql ���","����� �����: $rows"));
   $T_sql+=$t0_sql;
}else
{
   $rows=0;
}

if( !$rows )
{
   $not_found='������: '.$filtr.$br.'������� �� �������. ';
   $not_found.=&ahref("$scrpt$eurl&fullsearch=1&grp=0",'���������� �����').' � �������, ������� �� ��������� �� ������������. ' if $can_full_search;
   $OUT.=&Center_Mess($not_found,1).$out_bottom;
   &Exit;
}

$OUT.=&div('',
  &Table('',
    &RRow('','t t t t',
      $f{7}? '' : "������� �������: ".&bold($rows),
      '',
      $filtr,
      '',
      $tbl_sort,
      '',
      $tbl_add_f
    )
  )
);

$i=$start;
$NowStreet='';

# � ���������� ������ � ���� tunes ���������� ������ �����, ������� ����� ������� ������ � ������ ��������. ������:
# cols-0-5,1,cols-0-6,1   - ��� ���� � 0 ���� �������� ������� 5 � 6.

$s="cols\\-$Fw\\-";
%cols=(); # �������, ������� ����� �������� � ������� � ���������
map{ /$s(\d+)/, $cols{$1}=$Atunes{$_} } grep{/$s/} keys %Atunes;

keys %cols or &Error('� ���������� ����� ������� ������ �� ������ ������ �������, ������� ���������� �������� � ������ ��������. '.$br2.&CenterA("$scrpt0&a=mytune",'������� �����'));

# ���� ��� ���� �� ����������� ���, �������� �������:
$cols{2}  && !$pr_show_fio && delete $cols{2};		# ���
$cols{6}  && !$pr_show_fio && delete $cols{6};		# ��������
$cols{7}  && !$pr_show_fio && delete $cols{7};		# ���� ���������
$cols{10} && !$pr_show_fio && delete $cols{10};		# �������

# ���� ��� ���� �� �������� ������� � �����, �������� �������:
foreach(
   4,			# ������
   9,			# ����� ������
   14,			# ��������� ������
   15,			# ������� ����������
   16,22,		# �����, ��������� �����
   17,18,19,20,21	# ������
)
{ 
   $cols{$_} && !$pr_show_traf && delete $cols{$_};
}

$cols{50} && !$pr_pays_create && delete $cols{50};	# ��� ���� �� ���������� ����� - �� ������� ������ `��������� ����`
$cols{51} && !$pr_usr_stat_page && delete $cols{51};	# ��� ���� � ���������� ����������

$show_traf_cols=defined $cols{17} || defined $cols{18} || defined $cols{19} || defined $cols{20} || defined $cols{21}; # �������� ���� �� ���� ������� � ��������


# [id �������, ������������, ��������]. ������� ������ � ������������������ ����������� �������
@cols_opt=(
  [1, 'c', 'Id'],
  [8, 'l', 'Ip'],
  [3, 'l', '�����'],
  [2, 'l', '���'],
  [5, 'c', '������'],
  [6, 'l', '��������'],
  [7, 'l', '����&nbsp;���������'],
  [10,'l', &Filtr_out($dopf_a_to_name{_adr_telefon})],
  [11,'l', &Filtr_out($dopf_a_to_name{'p_street:street:name_street'})],
  [12,'c', &Filtr_out($dopf_a_to_name{_adr_house})],
  [13,'c', &Filtr_out($dopf_a_to_name{_adr_room})],
  [16,'c', '�����'],
  [22,'c', '����.&nbsp;�����'],
  [17,'r', '������&nbsp;1'],
  [18,'r', '������&nbsp;2'],
  [19,'r', '������&nbsp;3'],
  [20,'r', '������&nbsp;4'],
  [21,'r', '&sum;&nbsp;������'],
  [9, 'r', '&sum;&nbsp;������'],
  [4, 'r', '������'],
  [14,'r', '�&nbsp;��������'],
  [15,'r', '�������'],
  [30,'l', '���������'],
);

map{ $cols_align{$_->[0]}=$_->[1] } (@cols_opt);

$cols_count=keys %cols;

$out='';
%shown=(); # ������ ��� ���������� �������
%counts=();
($r3,$r4)=('rowoff','rowoff2');


%flds=(
   grp		=> \$grp,
   mid		=> \$mid,
   ip		=> \$ip,
   fio		=> \$fio,
   name		=> \$name,
   lstate	=> \$lstate,
   state	=> \$state,
   cstate	=> \$cstate,
   cstate_time	=> \$cstate_time,
   auth		=> \$auth,
   hops		=> \$hops,
   comment	=> \$comment,
   contract	=> \$contract,
   contract_date => \$contract_date,
   balance	=> \$balance,
   paket   	=> \$paket,
   next_paket	=> \$next_paket,
   paket3	=> \$paket3,
   srvs		=> \$srvs,
   start_day	=> \$start_day,
   discount	=> \$discount,
   block_if_limit =>\$block_if_limit,
   limit_balance => \$limit_balance,
   in1		=> \$in1,
   out1		=> \$out1,
   in2		=> \$in2,
   out2		=> \$out2,
   in3		=> \$in3,
   out3		=> \$out3,
   in4		=> \$in4,
   out4		=> \$out4,
);

%dop_flds=(
   field_name	=> \$field_name,
   field_value	=> \$field_value,
   field_alias	=> \$field_alias,
   field_type	=> \$field_type,
   field_flags	=> \$field_flags
);

while( $pp=$sth->fetchrow_hashref )
{
   $id=$pp->{id};

   $nsql=nSql->new({
       dbh	=> $dbh,
       sql	=> "SELECT * FROM fullusers WHERE id=$id LIMIT 1",
       show	=> 'line',
       ret	=> \%flds
   });

   if( !$nsql->{ok} )
   {
      $Debug.="������ ��������� ������ � ����. fullusers id=$id".$br;
      $counts{errors}++;
      next;
   }

   if( $mid )
   {
      $id=$mid;
      $nsql=nSql->new({
        dbh	=> $dbh,
        sql	=> "SELECT * FROM fullusers WHERE id=$id LIMIT 1",
        show	=> 'line',
        comment	=> '���. ������',
        ret	=> \%flds
      });

      if( !$nsql->{ok} )
      {
         $Debug.="������ ��������� ������ � ����. fullusers id=$id".$br;
         $counts{errors}++;
         next;
      }
   }

   if( $shown{$id} )
   {
      &DEBUG('��� ���������� ������. Next'.$br);
      next;
   }
   $shown{$id}=1;

   if( !$UGrp_allow{$grp} )
   {  # ������ � ������ ������ ��������� ������������
      $counts{notallow}++;
      next;
   }

   # ��������� � ���� �� ������� ������ �� ����� ������, ��������� ������� ���, � ���� ������ ������
   # `<0 �� ����� ������`, �� �� �������� ������ �� ��������������� �������
   %traf=(
     in1	=> $in1,
     out1	=> $out1,
     in2	=> $in2,
     out2	=> $out2,
     in3	=> $in3,
     out3	=> $out3,
     in4	=> $in4,
     out4	=> $out4,
   );
   $money_param={
      paket	=> $paket,
      paket3	=> $paket3,
      service	=> $srvs,
      start_day	=> $start_day,
      discount	=> $discount,
      traf	=> \%traf,
      mode_report=>1
   };

   $money_ref=&Money($money_param);

   $got_money=sprintf("%.2f",$money_ref->{money});
   $block_cod=$money_ref->{block_cod};

   $balance=sprintf("%.2f",$balance);
   $rez_balance=sprintf("%.2f",$balance-$got_money);
   $f{7} && $rez_balance>=0 && next;

   $fio=&Filtr_out($fio);
   $name=&Filtr_out($name);
   
   @line=();

   $na_podkl= $cstate==9 || $cstate==10;
   $off=$state eq 'off';
   # ������� ��� ������ ������� ������, ���� ������ ��������� � ��� ������ ����. $row ����������� � �����
   $row=$off && !$alias_on{$id}? $r3 : $na_podkl? 'title' : $r1;

   $ips_tbl=$ids='';
   $sql2=nSql->new({
       dbh	=> $dbh,
       sql	=> "SELECT auth,id,ip,lstate FROM users WHERE id=$id OR mid=$id ORDER BY sortip",
       show	=> 'line',
   });
   while( %h=%{ $sql2->get_line } )
   {
      # �������� ����� �����������
      if( $show_auth_m && nSql->new({
           dbh	=>$dbh,
           sql	=>"SELECT act,time FROM login WHERE act>0 AND mid=$h{id} ORDER BY time DESC LIMIT 1",
           show	=> 'line',
           comment => '��������� �����������',
           hash	=>\%hh }) )
      {
         $auth_t=$hh{time}>0 && '('.&the_short_time($hh{time},$t).')';
         $auth_t=~s| |&nbsp;|g;
         $auth_t.='&nbsp;&nbsp;';
      }
       else
      {
         $auth_t='&nbsp;';
      }
      $ips_tbl.=&tag('tr',
         &tag('td',$auth_t,'width=50%').
         &tag('td',&ShowModeAuth($h{auth}),'width=1%').
         &tag('td',$h{ip}).
         &tag('td',$h{lstate}? &tag('acronym','&hearts;',"title='������ online' class=error") : '&nbsp;&nbsp;','width=1%')
      );
      $ids.=&RRow('','c',$h{id});
   }

   # -- ID --   
   defined $cols{1} && push @line,!!$cols{1} && ($ids? &Table('width100 table1',$ids) : $id);

   # -- ip --
   defined $cols{8} && push @line,!!$cols{8} && &Table('width100 table1',$ips_tbl);

   # -- ����� --
   defined $cols{3} && push @line,!!$cols{3} && $name;

   # -- ��� --
   defined $cols{2} && push @line,!!$cols{2} && &bold($fio);

   # -- ������ --
   defined $cols{5} && push @line,!!$cols{5} && ($UGrp_name{$grp} || &Printf('[span error]','�������������� ������'));

   # -- �������� --
   defined $cols{6} && push @line,!!$cols{6} && $contract;

   # -- ���� ��������� --
   if( defined $cols{7} )
   {
      $h=$contract_date;
      if( $cols{7} && $h )
      {
         $cdate=&the_date($h);
         $cdate=&Printf('[span error]',$cdate) if $f{w} && ($t-$h)/24/3600 >12; # ������� ������ ��������� �� ����������� > 12 ����
         push @line,$cdate;
      }
       else
      {
         push @line,'';
      }
   }


   %dopf=();
   $sql2=nSql->new({
       dbh	=> $dbh,
       sql	=> "SELECT * FROM dopdata WHERE parent_id=$id AND parent_type=0",
       show	=> 'line',
   });
   while( %h=%{ $sql2->get_line } )
   {
       $dopf{ $h{field_alias} }=$h{field_value}; # ������� � ������� $dopf{�����} = ��������
   }

   # -- ������� --
   defined $cols{10} && push @line,!!$cols{10} && &Filtr_out($dopf{_adr_telefon});

   # -- ����� --
   defined $cols{11} && push @line,!!$cols{11} && $streets{$dopf{'p_street:street:name_street'}};

   # -- ��� --
   $h=$dopf{"_adr_block"};
   defined $cols{12} && push @line,!!$cols{12} && $dopf{_adr_house}.(!$h? '' : ($h>0? '/':' ').$h);

   # -- �������� --
   defined $cols{13} && push @line,!!$cols{13} && $dopf{_adr_room};

   # -- ����� --
   defined $cols{16} && push @line,!!$cols{16} && (
      !$Plan_name[$paket]? &Printf('[span error]','��������������') :
      $Plan_allow_show[$paket]? &ahref( "$scrpt&f=h&p=$paket",$Plan_name_short[$paket] ):
      &Printf('[span disabled]','�����')
   );

   # -- ��������� ����� --
   defined $cols{22} && push @line,!!$cols{22} && (
      !$next_paket? '' :
      !$Plan_name[$next_paket]? &Printf('[span error]','��������������') :
      $Plan_allow_show[$next_paket]? &ahref( "$scrpt&f=i&p=$next_paket",$Plan_name_short[$next_paket] ):
      &Printf('[span disabled]','�����')
   );

   # -- ������ --
   if( $show_traf_cols )
   {
      $traf_sum=0;
      foreach $h (1..4)
      {
         $traf=$money_ref->{"traf$h"};
         $traf_sum+=$traf if $traf>0;
         defined $cols{$h+16} or next;
         if( !$cols{$h+16} )
         {
            push @line,'';
            next;
         }
         $traf=($traf<0 && '������ ').&Print_traf(abs($traf)*$mb,$Fed);
         push @line,&Printf('[span disabled][br][]',$PresetName{$Plan_preset[$paket]}{$h},$traf);
      }
      defined $cols{21} && push @line,!!$cols{21} && &bold(&Print_traf($traf_sum*$mb,$Fed));
   }

   # -- ����� ������ --
   defined $cols{9}  && push @line,!!$cols{9} && $got_money;

   # -- ������ --
   defined $cols{4}  && push @line,!!$cols{4} && ($balance<0? &Printf('[span error]',$balance) : $balance);

   # -- ��������� ������ --
   defined $cols{14} && push @line,!!$cols{14} && ($rez_balance<0? &Printf('[span error]',$rez_balance) : $rez_balance);

   # -- ������� ���������� --
   defined $cols{15} && push @line,!!$cols{15} && !!$block_if_limit && $limit_balance;

   # -- ��������� ���� ��������� --
   if( defined $cols{30} )
   {
      if( $cols{30} )
      {
         $and=$f{q}? '' : "AND field_flags LIKE '%q%'"; # ���� �� ����� ����� �� ���������, �� ��������� ������ ��������� ����
         $out2='';
         $h=nSql->new({
            dbh		=> $dbh,
            sql		=> "SELECT * FROM dopdata WHERE parent_id=$id AND parent_type=0 $and ORDER BY field_name",
            show	=> 'line',
            comment	=> '��������� ����'
         });
         while( $h->get_line(\%dop_flds) )
         {
            $field_name=~s|^\[\d+\]||;
            $field_name=&Printf('[span disabled]',$field_name);
            $field_value=&Filtr_out(
              &nDopdata_print_value
              ({
                 type	=> $field_type,
                 alias	=> $field_alias,
                 value	=> $field_value,
              })
            );
            $out2.=&RRow('','lr',$field_name,$field_value);
         }

         push @line,$out2 && &Table('table2 width100',$out2);
      }
       else
      {
         push @line,'';
      }
   } 

   # --- ��������� ������ (����� �����) ---
   if( $cstate || $comment!~/^\s*$/ )
   {
      $first_col=$cstate==11? "<img src='$img_dir/offn.gif'>" : $cstate=~/^(4|8|12)$/? "<img src='$err_pic' width=16 height=16> " : '';
      $second_col=(!!$cstate_time && &the_short_time($cstate_time,$t).' ').'��������� '.($cstates{$cstate}? &commas($cstates{$cstate}) : &bold('�����������')).$br.&div('data1',&Show_all($comment));
      $line2="<tr class='$row nav'><$tc>$first_col</td><td colspan=$cols_count>$second_col</td></tr>";
   }
    else
   {
      $line2='';
   }

   # --- ������������� ������� ---
   if( $JobIsNow{$id} )
   {
      $line3="<tr class='$row'><$tc>&nbsp;</td><td colspan=$cols_count>".&nJob_ShowJobBlank($id)."</td></tr>";
   }
    else
   {
      $line3='';
   }   

   @buttons=();

   $cols{50} && push @buttons,&ahref("$scrpt0&a=pays&mid=$id",'��������� ����').' ';
   $cols{51} && push @buttons,&ahref("stat.pl?".(!!$PP && "uu=$UU&pp=$PP&")."id=$id'",'����������',"target='_blank'").' ';
   $cols{52} && push @buttons,&ahref("$scrpt0&a=map&bx=$hops",'�����').' ' if $hops>0;
   $cols{53} && push @buttons,&ahref("$scrpt&f=9&box=$hops","��� �� ����� $hops").' ' if $hops>0;
   $cols{53} && push @buttons,&ahref("$scrpt&f=d&group=1&street=$street&house=$house","$Show_house_low $house").' ' if $house;

   $first_col=&ahref("$scrpt0&a=user&id=$id",'info');

   if( $#buttons>=0 )
   {
       $line_id="line$id";
       $first_col=&Table('table1 nav3',&RRow('','cc',$first_col,&ahref(qq(javascript:show_x("$line_id")),'+')));
       $line_buttons="<tr id=my_x_$line_id style='display:none' class='$row nav'><td>&nbsp;</td><td colspan=$cols_count>@buttons</td></tr>";
   }
    else
   {
       $first_col=&div('nav3',$first_col);
       $line_buttons='';
   }


   unshift @line,$first_col;

   $aling=join '',map{ $_->[1] } grep{ defined $cols{$_->[0]} } (@cols_opt);

   $lines=$line2.$line3;
   $h=$cols_count+1;
   $line_buttons.="<tr class=tablebg><td colspan=$h style='padding:0px'>$spacer</td></tr>";
   $out.=&RRow($row,'c'.$aling,@line).$lines.$line_buttons;

   ($r1,$r2,$r3,$r4)=($r2,$r1,$r4,$r3);
}   

$a=$scrpt.$eurl;

@header=( &ahref("$scrpt&f=2",'���') );

foreach $h (@cols_opt)
{
   $col_id=$h->[0];
   defined $cols{$col_id} or next;
   $col_name=$h->[2];
   $short_name=substr($col_name,0,1);
   $short_name=~s|&|&harr;|;
   push @header,$cols{$col_id}? &ahref("$a&colnarrow=$col_id",$col_name) : &div("' style='margin:-4px",&ahref("$a&colextend=$col_id",$short_name,"title='$col_name'"));
}

$header='<thead>'.&RRow('','c' x ($#header + 1),@header).'</thead>';

$Rows=$f{7}||$f{a}? '':" - $rows �������"; # ��� �������� `��������� ������ <0` � `������` �� ������� ���������� ��������� ����� �.�. ��� ������ ���� ��������� ���. ����������

# ���� ���-�� �������� ������ ���-�� � ������ �� ������
if( $rows > $Max_list_users )
{
   $i=0;
   $p=($rows/$Max_list_users)>15? '':'&nbsp;';
   $Fstart++;
   $lowNum=$Fstart-9;
   $highNum=$Fstart+9;
   $vlowNum=$Fstart-35;
   $vhighNum=$Fstart+35;
   $nav='';
   while( $rows>0 )
   {
      $h="a href='$a&start=$i'";
      $i++;
      $nav.=($i>$lowNum && $i<$highNum) || $i==1 || $rows<=$Max_list_users? ($i==$Fstart? '<td class=nav2>':'<td class=nav>')."<$h>$p$i$p</a></td>" :
             $i>$vlowNum && $i<$vhighNum? "<td><$h title='$i'>&bull;</a></td>" : $i % 10? '' : "<td><$h title='$i'>&loz;</a></td>";
      $rows-=$Max_list_users;
   }
   $nav=&Table('table0 row2',"<tr>$nav</tr>");
}
 else
{
   $nav='';
}

$i=1;
$Fed++;
$templates=&Table('table1 nav3',
  &tag('tr',
    ( join '',map{ &tag('td',&ahref("$a&ed=".$i,$_),$Fed==$i++ && 'class=head') } ('��,','��','��,','��','����') ).
    &tag('td','&nbsp;&nbsp;���:').
    ( join '',map{ &tag('td',&ahref("$a&w=$_",$_+1),$_==$Fw && 'class=head') } (0..$UsrList_cols_template_max-1) )
  )
);

$nav=&Table('table0 width100',&RRow('','l r',$nav,'',$templates));

$OUT.=$nav.&Table('width100 usrlist',$header.$out).$nav.$out_bottom;

1;
