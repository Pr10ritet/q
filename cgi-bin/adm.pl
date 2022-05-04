#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use Time::HiRes qw( gettimeofday tv_interval );
use Time::localtime;
use DBI;

$Main_config='/usr/local/nodeny/nodeny.cfg.pl'; # ���������� ���� � �������, ���������������� � &get_main_config()
eval{ &get_main_config() };		# �������� �����-������� ������� �� ������������, ���������� �������������

$Session_live		= 300;		# ������ ����� ������, ���� �� ����� ����������
$Session_trusted_live	= 14400;	# ������ ����� ������ � ����������� PC, ���� �� ����� ����������
$Max_byte_upload	= 40000;	# ������������ ���������� ����, ������� �� ����� ������� �� ������ post

$script=$ENV{SCRIPT_NAME};
$script=~s/'/&#39;/g;			# �������� ������ � ������� NoDeny

$VER_chk=$VER;
$VER=0;
$VER_script=$0;				# ������ ��� �������� �������

(-e $Main_config) or &Hard_exit(100);
eval{require $Main_config};
$@ && &Hard_exit(101);

$Html_title="$Title_net (ver $VER_chk)";

$Nodeny_dir_web="$Nodeny_dir/web";
$call_pl="$Nodeny_dir_web/calls.pl";
(-e $call_pl) or &Hard_exit(102);
eval{require $call_pl};
$@ && &Hard_exit(103);
$VER_chk==$VER or &Hard_exit(104);

&LoadMod("$Nodeny_dir_web/nSql.pl",'������ nSql');

%F=('a'=>'');

$Debug='';

{
 if( $ENV{REQUEST_METHOD} ne 'POST' )
 {
    $QueryString=$ENV{QUERY_STRING};
    $Debug='������, ��������� ������� get:';
    last;
 }

 if( exists($ENV{CONTENT_TYPE}) && $ENV{CONTENT_TYPE}=~m|^\s*multipart/form-data|i )
 {  # multipart/form-data ��������� ������� cgi (�������, ������� ��� �� ����� � ������� �������)
    # ��� �������, ������� ��������������� ������ � multipart/form-data ������ ����� ���� ��������
    # ��������� �� CGI, �� ���� �������� �� �������� ������: a,uu,pp,act
    use CGI;
    $cgi=new CGI;
    $F{a}=$cgi->param('a');
    $F{uu}=$cgi->param('uu');
    $F{pp}=$cgi->param('pp');
    $F{act}=$cgi->param('act');
    $F{set_new_admin}=$cgi->param('set_new_admin');
    $QueryString='';
    $Debug='������ �������� ��� multipart/form-data';
    last;
 }

 $t=$ENV{CONTENT_LENGTH};
 $t>$Max_byte_upload && &Error("���������� ���������� ����� �������: $t > $Max_byte_upload (����)".$go_back);

 $Debug='������, ��������� ������� post:';  
 read(STDIN,$QueryString,$t)
} 

foreach $t (split(/&/,$QueryString))
{
   ($name,$value)=split(/=/,$t);
   $name=~tr/+/ /;
   $name=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $value=~tr/+/ /;
   $value=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $F{$name}=$value;
   $Debug.=&Printf('[br][filtr|bold] = [filtr]',$name,substr $value,0,200);
}

%Command_list=(
 'adduser'	=> '�������� ������� ������ ��������',
 'admin'	=> '���������� �������� �������� ���������������',
 'cards'	=> '���������� ���������� ������',
 'chanal'	=> '���������� � �������� ������',
 'check'	=> '��������',
 'deluser'	=> '�������� ������� ������ ��������',
 'dopdata'	=> '�������������� ������',
 'equip'	=> '������������',
 'job'		=> '���������',
 'listuser'	=> '������ ���������',
 'main'		=> '������',
 'map'		=> '�����',
 'monitoring'	=> '���������� �������',
 'mytune'	=> '������ ���������',
 'operations'	=> '��������',
 'oper'		=> '�������� ��������������',
 'pays'		=> '������������� ��������',
 'payshow'	=> '�������, ������, �������',
 'report'	=> '�����',
 'restart'	=> '����������/����/�������',
 'setpaket'	=> '���������������� ����� �������',
 'superoper'	=> '�������� �����������',
 'tarif'	=> '�������� �����',
 'title'	=> '��������� ��������',
 'tune'		=> '���������',
 'user'		=> '������ �������',
);

foreach (values %PluginsAdm) {$Command_list{$1}=$2 if /^(.+?)\-(.+)$/} # ������� �������

$Fa=$F{a};
$start=int $F{start};

%PR=();
%FormHash=();
$UU=$Display_admin='';
$Adm_pic="$img_dir/title_left.gif";
$Passwd_Key=&Filtr_mysql($Passwd_Key);
$AdminTrust=1; # ���� �������, ��� ����� ������ ���� ����������

if( $F{rand_login} )
{
   $t=int $F{rand_login};
   $F{uu}=$F{"uu$t"};
   undef $F{rand_login};
   undef $F{"uu$t"};
   undef $F{"pp$t"};
}

$t=time;
if( $F{uu} eq 'admin' && defined($sadmin) )
{ # ������� ������ �� ��������� (�����������) ������ ��� ������������ ��������� ������
  $hash=Digest::MD5->new;
  $hash=$hash->add($F{salt}.' '.$sadmin);
  $hash=$hash->hexdigest;
  if( $hash eq $F{pp} )
  {
     $UU=$Display_admin=$F{uu};
     $Aname='���������� NoDeny';
     $PP=$hash;
     $Admin_id=0;
     $scrpt0="$script?salt=".&URLEncode($F{salt})."&uu=admin&pp=$hash";
     $scrpt="$scrpt0&a=$Fa";
     %FormHash=('salt'=>$F{salt},'pp'=>$hash,'uu'=>'admin');
     # ����� ����� �� ������ � �������, �������� � ��������� ��������, ���������� �������, ����
     foreach (1,2,3,5,97) { $PR{$_}=1; ${"pr_$pr_def{$_}"}=1; }
     $pr_SuperAdmin=1;
  }
   elsif( $F{pp} eq 'error' )
  {
     &ErrorMess('��������! ��������, ����������� �� ������ �� ������� ����, ��� ��� ������� �� �������� '.
        '������ md5.js ��� � ��� �������� javascript.');
  }
}

$DSN="DBI:mysql:database=$db_name;host=$db_server;mysql_connect_timeout=$db_conn_timeout";
$DSS="DBI:mysql:database=$db_name;host=$db_server2;mysql_connect_timeout=$db_conn_timeout2";
 
$dbh=DBI->connect($DSN,$user,$pw,{PrintError=>1});
if( !$dbh )
{
   $file='nErrConnect.pl';
   eval{require "$Nodeny_dir_web/$file"};
   &Error("�� ������ ������ $file");
}

&SetCharSet($dbh);

($Fa eq 'login') && &Login;

$Ashowsql=1; # ��������. ���� ����������� �� ����� �������� - ��� �� - � &Login() $DOC->{admin_area}='';

&sql_do($dbh,"DELETE FROM admin_session WHERE time_expire<unix_timestamp()",0); # ������ ���������� ������ �������� �� �����������

{
 $UU && next;
 # �� ��������� �����
 $UU=&Filtr_mysql($ENV{REMOTE_USER});		# �����, ���������� �����������
 $PP=&Filtr_mysql($F{pp});			# ��� ������, ��� ��� id ������

 $Fa=$PP='' if $Fa eq 'enter' && !$F{uu};	# ����� ������������ � ���-����������� 

 if( $Fa eq 'enter' )
 {  # ������� ����������� ���������� NoDeny
    $Fuu=&Filtr_mysql($F{uu});	# �����, ���������� ����� �����
    &Login if !$Fuu || !$PP;	# ����� ��� � ������������ ��������� ��� �� ������� ��� - �������� ����������
    $where="admin='$Fuu'";
 }
  elsif( $PP )
 {  # ����� ������� id ������, ���� ����� ������? act=2 - �������, ��� ��� ������ ������, � �� ������ �� �����������
    $p=&sql_select_line($dbh,"SELECT * FROM admin_session WHERE act=2 AND salt='$PP' AND system_id='$system_id' LIMIT 1",0);
    $p or &Login; # ����� ������ ��� - ���� ������ ���� �� ����� ������� � ��� ���� ������� ���� ����� ��������/ip

    if( substr($PP,0,1) eq 'T' )
    {  # ������������� ������� ����, � �������� �����, ����������
       $Session_live=$Session_trusted_live;
    }else
    {
       $AdminTrust=0;
    }
    # ������� ������
    &sql_do($dbh,"UPDATE admin_session SET time_expire=unix_timestamp()+$Session_live WHERE salt='$PP' AND system_id='$system_id' LIMIT 1",0);
    $Display_admin="$UU &rarr; " if $UU; # ���������, ��� ��� ��������������
    $where="id=$p->{admin_id}";
 }
  elsif( $UU )
 {  # ������������ ���������� ����������
    $where="admin='$UU'";
 }
  else
 {
    &Login; # ��� ������� NoDeny ��������� ���-����������� (���� ����) - ����������� ������ ���������� NoDeny
 }
 $p_adm=&sql_select_line($dbh,"SELECT *,unix_timestamp(),AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE $where LIMIT 1",0,
    "SELECT *,unix_timestamp(),AES_DECRYPT(passwd,'...') FROM admin WHERE $where");
 unless ($p_adm)
 {  # ��� ������ ������
    &Login if $UU && !$PP; # ���� ������������� ����������� � �� ������� �������������� ����� ����� - ������ ��������� ������������������
    &Error_Login;
 }

 $privil=$p_adm->{privil};
 $PR{$_}=1 foreach (split /,/,$privil);
 $pr_SuperAdmin=$PR{2} && $PR{3};

 $Ashowsql=$pr_SuperAdmin && $AdminTrust && $p_adm->{tunes}=~/,showsql,1/;
 $DOC->{admin_area}=$Ashowsql? &MessX($Debug).$DOC->{admin_area} : '';
 $Debug='';

 # ������� ������ �������, �� ������, ����� �� ���� sql-�������� �� �������� ������������� ������
 %Offices=();
 $sth=&sql($dbh,"SELECT * FROM offices",0);
 $Offices{$p->{of_id}}=$p->{of_name} while ($p=$sth->fetchrow_hashref); # ����������� �� ����

 $t=$p_adm->{'unix_timestamp()'};			# ����� �� ������� �������� ��
 $Admin_id=$p_adm->{id};				# id ������
 $UU=$p_adm->{admin};					# ��� �����
 $pp=$p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"};	# ��� ������
 $Admin_office=$p_adm->{office};			# ��� �����
 $Admin_UU="���. $UU (id=$Admin_id, ip=$ip).";

 if( $Fa eq 'enter' )
 {  # ������� NoDeny-�����������
    require "$Nodeny_dir_web/nLogin.pl";
    &Enter;
 }
  elsif( $Fa eq 'logout' )
 {
    &sql_do($dbh,"DELETE FROM admin_session WHERE act=2 AND admin_id=$Admin_id");
    &OkMess("���������� ����� �� �������.");
    &Login;
 }
  elsif( !$PP && $pp ne '-' )
 {  # ����� ������������� �����������, ��� ���� ������� ������ ������� ����������� ����������� ����������
    &Login;
 } 

 require "$Nodeny_dir_web/nChngCom.pl" if $Fa eq 'sv'; # ������� sv - ���������������� �������, ���������� �������������

 $scrpt0="$script?pp=$PP";
 $scrpt="$scrpt0&a=$Fa";
 $FormHash{pp}=$PP if $PP;
 $Display_admin.=$UU;

 if( ($PR{30}||$PR{31}) && $F{set_new_admin} )
 {  # ������������ �� ����� ������� ��������������
    $Admin_id=int $F{set_new_admin};
    $Real_Admin_office=$Admin_office;
    $p_adm=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE id=$Admin_id",0,
       "SELECT *,AES_DECRYPT(passwd,'...') FROM admin WHERE id=$Admin_id");
    &Login unless $p_adm;
    $Admin_office=$p_adm->{office};
    !$PR{31} && $Admin_office!=$Real_Admin_office && &Error("��� ���� ����� ������������� ������ �� ��������������� ������ ������.");
    $UU=$p_adm->{admin};
    $Admin_UU.=" ������������ �� ������ $UU (id=$Admin_id).";
    $FormHash{set_new_admin}=$Admin_id;
    $scrpt.="&set_new_admin=$Admin_id";
    $scrpt0.="&set_new_admin=$Admin_id";
    $Display_admin.=" &rarr; $UU";
    $privil=$p_adm->{privil};
    %PR=(); # !
    $PR{$_}=1 foreach (split /,/,$privil);
    $pr_RealSuperAdmin=$pr_SuperAdmin;
    $pr_SuperAdmin=$PR{2} && $PR{3};
    $OUT.=&error('��������.','�� ������������� �� �������������� '.&bold($UU).(!!$Admin_office && ' ������ '.&bold($Offices{$Admin_office}))); 
 }

 $Aname=$p_adm->{name};				# ��� ������
 $Aext=$p_adm->{ext};				# ���������� � ������� ������
 $Admin_regions=','.$p_adm->{regions}.',';	# ������������ �������������� ������
 $Atemp_block_grp=$p_adm->{temp_block_grp};	# ����� �������� ���� ��������� ����������� � ���� ������ �� ������ � ������� �������� ����� ��������
 %Atunes=split ',',$p_adm->{tunes};		# ������ ���������
 $Adm_pic="$Adm_img_dir/Adm_$Admin_id.$Aext" if $Aext;
}

${"pr_$pr_def{$_}"}=$PR{$_} foreach %pr_def;	# ��������� ������������� ����������

$tt=localtime($t);
$day_now=$tt->mday;
$mon_now=$tt->mon+1;
$year_now=$tt->year;
$time_now=&the_time($t);

# === ����� ===

{
 $F{notitle} && last;

 $h=!!$Admin_id;
 $h=&Table('table2 title2',
     &RRow('navtitle','llllllcllll',
       &ahref("$scrpt0&a=title",'&sect;'),
       $h && &ahref("$scrpt0&a=listuser",'�������'),
       &ahref("$scrpt0&a=main",'��������'),
       $h && $pr_pays && &ahref("$scrpt0&a=payshow&nodeny=admin&year=$year_now&mon=$mon_now&admin=$Admin_id",'�������'),
       $h && &ahref("$scrpt0&a=chanal&class=1",'����������'),
       $h && $pr_edt_main_tunes && &ahref("$scrpt0&a=restart",'����������'),
       $h && &form('#'=>1,'a'=>'sv',
         &Table('table1',&RRow('row2','ll',
            &input_t('name','',12,60,qq{style='width:16px' id='txtTopFind' onClick='document.getElementById("txtTopFind").style.width="80px"; document.getElementById("divTopFind").style.display="";'}),
            &tag('div',&submit('�����'),"id='divTopFind' style='display:none'")
         ))
       ),
       &ahref("$script?a=login",'�����������'),
       &ahref("$scrpt0&a=logout",'�����'),
       !!$Ashowsql && &ahref('javascript:show_x("adm")','Debug&darr;'),
     )
 );

 $out=&Table('table0 title2',
   &tag('tr',
     &tag('td','&nbsp;','class=title1l width=8').
     &tag('td',  &tag('span','NoDeny - '.($Command_list{$Fa}||'Hello'),'class=title3'),"class='title1 cntr'").
     &tag('td','&nbsp;','class=title1r width=8'),
   'height=23').
   &RRow('',' l ','',$h,'').
   &RRow('title4','3',"<img height=5 src='$spc_pic'>")
 );

 $OUT.=&Table('width100',
   &tag('tr',
      &tag('td',&ahref("$scrpt0&a=mytune","<img src='$Adm_pic'>")).
      &tag('td','&nbsp;',"width='16%'").
      &tag('td',$out,"align=center valign=top").
      &tag('td','&nbsp;',"width='16%'").
      &tag('td','���:'.$br.$Display_admin)
   ).
   &tag('tr',&tag('td',"<img height=10 src='$spc_pic'>","colspan=5 class=row2"))
 );
}
$out='';

$pr_on or &Error(&Printf('������ � ������� ��� ������ [bold] ������������.',$UU));

# � ����� ������� �������� ������
$Allow_grp=$Allow_grp_less='';
%UGrp_name=%UGrp=%UGrp_allow=%UGrp_allow_less=();
$sth=&sql($dbh,"SELECT * FROM user_grp",0);
while ($p=$sth->fetchrow_hashref)
{
   $h=$p->{grp_id};
   if( $p->{grp_admins}=~/,$Admin_id,/ )
   {  # ����� ����� ������ � ������
      $Allow_grp.="$h,";
      $UGrp_allow{$h}=1;
      if( $Atemp_block_grp!~/,$h,/ )
      {  # �� �� ��������� ���� � ������� � ���� ������
         $Allow_grp_less.="$h,";
         $UGrp_allow_less{$h}=1;
      } 
   }
   if( $p->{grp_admins2}=~/,$Admin_id,/ )
   {
      $UGrp_allow{$h}++;
      $UGrp_allow_less{$h}++ if $Atemp_block_grp!~/,$h,/;
   }
   $UGrp{$h}=$p->{grp_property};
   $UGrp_name{$h}=&Filtr($p->{grp_name});
}

$Allow_grp.='0';	# ������ � ������� ������ ����� ���, ����� ���� ��������� �������
$UGrp_allow{0}=2;	# ���� � ������ ����
$Allow_grp_less.='0';
$UGrp_allow_less{0}=2;
$UGrp_name{0}='��� ������';

&DEBUG("<small>����� ���������� adm.pl: $T_sql ���</small>".$br);
if( $VER_cfg!=$VER_chk )
{
   $pr_SuperAdmin or &Error('���������������� ��������� �������� �� ����������� ��������. ���������� � �������� ��������������.');
   $Fa='tune';
}
 elsif( !$Fa or !$Command_list{$Fa} )
{
   $F{a}=$Fa='title';
}

# �� ��������� ����������� ������� � ������ ��������? ������� �� �������
if( !join '',grep{ /^cols-/ } keys %Atunes )
{
  foreach $_ qw(
    0-2 0-3 0-4 0-8 0-9 0-10 0-11 0-12 0-13 0-14 0-16 0-21 0-50 0-51 0-52 0-53 0-54
    1-1 1-2 1-3 1-5 1-6 1-8 1-14 1-15 1-16 1-17 1-18 1-22 1-50 1-51 1-52 1-53 1-54
    2-1 2-2 2-3 2-4 2-9 2-14 2-16 2-17 2-18 2-19 2-20 2-21 2-22
  )
  {
    $Atunes{"cols-$_"}=1;
  }
}

$FormHash{a}=$Fa;
$Apay_sql="admin_id=$Admin_id,admin_ip=INET_ATON('$ip'),office=$Admin_office";

$fileFa="$Nodeny_dir_web/$Fa.pl";
(-e $fileFa) or &Error($pr_SuperAdmin? "������ $fileFa �� ������!" : '������ �� ������. ���������� � �������� ��������������.');
require $fileFa;
&Exit;


sub Login
{
 eval{require "$Nodeny_dir_web/nLogin.pl"};
 $@ && &Error("�� ���� ��������� ������ ����������� nLogin.pl.");
 &Login_now;
}

sub Error_Login
{
 &Message(&div('big','�������� ����� ��� ������'),$err_pic,'������','','infomess');
 &Login;
}

sub Hard_exit
{
 print "Content-type: text/html\n\n<html><body><br><div align=center>��������! ������ $_[0]. ���������� � �������� ��������������.</div></body></html>\n";
 exit;
}

# -- � ���� ����� ����� �������� ������������ &get_main_config --
