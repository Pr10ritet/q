#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
our $VER=50.33;

# ���������� ����������, ��������� nofire.pl:
#   %NET	- ������ ����� ��� ������������� ������� � �����������
#   %Tables	- ����� ������� ipfw, ���� ��� ���� �������� � ���
#   %NetsTbl	- ������ ����� ��� ������������� ������� � �����������
# ������ � �������� ��������: preset-�����_�����������, ��������:
#   $NET{1-2}='10.0.0.0/8,100.200.200.200' - ������ ����� ������� 1, ����������� 2
#   $Tables{3-4}=50 - ���� ������� 3 ����������� 4 ����� �������� � ������� 50 ipfw
#   $NetsTbl{1-2}{10.1.1.0/24} - ���� '10.1.1.0/24' ������������ � ������� ipfw: $Tables{1-2}

use Time::HiRes qw( gettimeofday );
use Time::localtime;
use IO::Socket;
use DBI;
use nosat qw( 
  &Nosat_init &Debug &Log &Exit &Error &TimeNow &Sql &SaveSatStateInDb
  $v %c $Exit_reason $Exit_cod $ReStat $Program_dir $SQL_BUF $FiltrDb_user $Config_time $Err_connect
);

&Nosat_init($VER,'noserver',2); #(������, ��� ������, id ������);

our $Start_num_ipfw=$c{Start_num_ipfw};
our $End_num_ipfw=$c{End_num_ipfw};
our $Start_num2_ipfw=$c{Start_num2_ipfw};
our $End_num2_ipfw=$c{End_num2_ipfw};

my $nofire="$Program_dir/nofire.pl";
( -e $nofire ) or &Error("Script $nofire is not found!");
eval{require $nofire};
$@ && &Error("Check $nofire!");

# ������� ���������
our $Where_auth='';
$Where_auth.=" AND auth<>'off'" if !$c{Allow_auth_off};
$Where_auth.=" AND (auth<>'no' OR lstate<>0)" if !$c{Allow_unauth};
$c{Usr_nosrvr_groups}=~s|\s||g;
our $Where_grp=$c{Usr_nosrvr_groups}? " AND grp IN($c{Usr_nosrvr_groups})" : '';
our $Dopdata_tmpl=int $c{Noserver_dopdata_tmpl};
our $Where_tmpl='WHERE parent_type=0'.(!!$Dopdata_tmpl && " AND template_num=$Dopdata_tmpl");

our $t=&TimeNow();

our %ON=();			# ������ ���� ip ������������� �����, ���� �������� ������
our %All=();			# ������ ���� ������������ ip � NoDeny (�� ������ ������������� �����)
our %AllOn=();			# ������ ���� ip � NoDeny (�� ������ ������������� �����), ���� �������� ������
our %Uday_traf=();
our %U=();
our %Num_id=();
our %Now_revision=();
our %Revision=();
our %Udop=();
our %Utraf=();
our %Opt=();
our %id_to_ip=();

our %NET=();
our %Tables=();
our %NetsTbl=();

our @Plan_flags=();
our @Plan_speed=();
our @Plan_speed_out=();
our @Plan_speed2=();
our @Plan_preset=();
our @Plan_script=();

our $No_activity=0;
our $Err_get_uinfo=0;
our $LastTrafDay=0;
our $When_load_user_info=0;	# ����� �������� ������ � ��������, ����� ��
our $Reload_period=0;
our $num_i=0;			# � ����� ����� ����� ���� ������ ��������� ������������������ ������ ������� ip-������
our $t_stat=0;			# ����� ����� ���������� �������� � ���� ���������� � ���� ������ ������, ������ ��
our $nRules=0;
our $sql_time=0;		# ����� ����� ���������� �������� sql-��������
our $sql_count=0;		# �� ����������
our $report='';

our $t_db_error=0;
our $dbh;

&Log('Starting noserver');

while( !&Load_Tarif )
{
   &Log('Cannot load tarifs!');
   $dbh && &SaveSatStateInDb('������ ��� �������� �������. ��������� ������� ����� 60 ���',1);
   sleep 60;
}

my ($p,$sth);
$p=localtime();
my($mon,$year,$day)=($p->mon,$p->year,$p->mday);
my $tbl_traf='x'.($year+1900).'x'.($mon+1).'x'.$day; 
&Debug("��� ������� ������� ������� ��� ������ �� ������� ����.");
%Uday_traf=();
$sth=&Sql("SELECT mid, SUM(`in`) as tin, SUM(`out`) as tout FROM $tbl_traf WHERE class=1 GROUP BY mid");
if( $sth )
{
   while( $p=$sth->fetchrow_hashref )
   {
      $Uday_traf{$p->{mid}}=$p->{tin}+$p->{tout};
      $v && &Debug(sprintf("id: %d in: %d out: %d sum: %d",$p->{mid},$p->{tin},$p->{tout},$Uday_traf{$p->{mid}}));
   }
}

&Flush(); # ��������� ��������

while(1)
{
  sleep 1;
  &Run_Ipfw_Rules;
  $t=&TimeNow();
  &LoadClientInfo if $t>$When_load_user_info;
  &SendAgentStat if $t>$t_stat; # ���� �������� ���������� � ���� ������
  $Exit_reason && last;
}

&Exit;

# ����������� � �� �� ���� 5 ���
sub SoftConnectToDB
{
 tv_interval($t_db_error)<5 && return;
 $t_db_error=[gettimeofday];
 &ConnectToDB;
}

sub Load_Tarif
{
 &Debug('��������� ������');
 my ($hour,$i,$id,$p,$speed,$speed_out,$speed2,$sth,$t1,$t2);
 $hour=localtime()->hour;
 $sth=&Sql("$SQL_BUF * FROM plans2");
 $sth or return(0);
 $i=6;
 &Debug("�������� ������ $i �����:");
 while( $p=$sth->fetchrow_hashref )
 {
    $id=$p->{id};
    $Plan_flags[$id]=$p->{flags};
    $speed=$p->{speed};
    $speed_out=$p->{speed_out};
    $speed2=$p->{speed2};
    $t1=$p->{start_hour};
    $t2=$p->{end_hour};

    if(
        $Plan_flags[$id]=~/n/ && (
          ($t1<$t2 && ($hour>=$t1 && $hour<$t2)) ||
          ($t1>$t2 && ($hour>=$t1 || $hour<$t2))
        )
      )
    {  # � ������ ������� � $t1 �� $t2 �������� ��������
       $speed*=2;
       $speed_out*=2;
    }

    $Plan_speed[$id]=$speed;
    $Plan_speed_out[$id]=$speed_out;
    $Plan_speed2[$id]=$speed2;
    $Plan_preset[$id]=$p->{preset};
    $Plan_script[$id]=$p->{script};

    $v && (--$i>=0) && print "\tid: $id\tpreset: $Plan_preset[$id]\tspeed: $speed\tspeed_out: $speed_out\tspeed2: $speed2\tflags: $Plan_flags[$id]\n";
 }
 return(1);
}

# ������� ����������� ������ ��� �������� id 
sub Num
{
 my $id=shift;
 $Num_id{$id} && return($Num_id{$id});
 $Num_id{$id}=++$num_i;
 return($num_i);
}

# --- ��������� ������ ---
sub Deny_inet
{
 my $id=shift;
 $ON{$id} or return;
 $ON{$id}='';
 &Debug("$U{$id}{ip} ����� &Deny �� nofire.pl");
 &Deny({
    paket	=> $U{$id}{paket},
    num		=> &Num($id),
    ip		=> $U{$id}{ip},
    options	=> $U{$id}{options},
    main_num	=> &Num($U{$id}{mid}),
    plan_flags	=> $Plan_flags[$U{$id}{paket}],
 });
}

# ---  ��������� ������  ---
sub Allow_inet
{
 my ($id)=@_;
 my ($auth,$data,$hash,$ip,$mid,$options,$p,$paket,$plan_flags,$speed_in,$speed_out,$speed2,$sth,$time,$traf);

 $ip=$U{$id}{ip};
 $mid=$U{$id}{mid};
 $auth=$U{$id}{auth};
 $paket=$U{$id}{paket};
 $options=$U{$id}{options};
 $speed2=$Plan_speed2[$paket];
 $speed_in=$Plan_speed[$paket];
 $speed_out=$Plan_speed_out[$paket];
 $plan_flags=$Plan_flags[$paket];

 &Debug("ip: $ip Userid: $id. ������������� �������� ���������");
 
 if( $Now_revision{$id} != $Revision{$id} )
 {  # ���������� �������������� ������ �������
    &Debug("���������� ��������� ������� �������������� ������:\n".
           "\told: ".($Now_revision{$id}||'�����������')."\n".
           "\tnow: $Revision{$id}");
    $sth=&Sql("$SQL_BUF field_alias,field_value,field_name FROM dopdata $Where_tmpl AND parent_id=$id");
    $data='';
    if( $sth )
    {
       $Udop{$id}={};
       while( $p=$sth->fetchrow_hashref )
       {
          $Udop{$id}{$p->{field_alias}}=$p->{field_value};
          $data.="\n\t\talias: ".$p->{field_alias}.
                 "\n\t\t name: ".$p->{field_name}.
                 "\n\t\tvalue: ".$p->{field_value}.
                 "\n\t\t------";
       }
       &Debug($data);
       $Now_revision{$id}=$Revision{$id};
    }
 }

 # === Start ��������� ������� ===

 {
    $plan_flags=~/p/ or last; # ������� ���������
    $Plan_script[$paket] or last;
    &Debug('��������� ��������');
    $time=localtime()->hour;
    foreach $p (split /\n/,$Plan_script[$paket])
    {
       $v && &Debug("����������� ������: $p");
       if( $p=~s/^<time *([^>]+)>// )
       {  # � ������� ���� ����� ������
          $data=",$1,";
          if( $data!~/,$time,/ )
          {
             &Debug('�� ������� �� ��������');
             next; 
          }
       }
 # ===  ������������ ���������� ���������� ===
       if(  $p=~/^(0|1):(.+)$/o )
       {  
          $data=$2;
          $traf=int( ($1? $Uday_traf{$mid} : $Utraf{$mid})/1000000 );
          &Debug("$ip traf=$traf Mb [script: $data]");
          foreach( split /:/,$data )
          {
             /^(\d+)\-(\d+)$/o or next;
             $traf<$1 && last;
             $speed_out=int($2*$speed_out/($speed_in||1));
             $speed_in=$2;
          }
       }
    }
    &Debug('��������� �������� ���������');
 }

 # === End ��������� ������� ===

 # ���������� ������, ���������� ��� ���������
 $hash="$auth $paket si:$speed_in so:$speed_out s2:$speed2 sf:$plan_flags [$Now_revision{$id}][$options]";
 &Debug("������� ��� ���� ���������� ������ �������:\n\t\t$hash");
 if( $ON{$id} )
 {
    if( $ON{$id} eq $hash )
    {
       &Debug('C�������� � ����������. ������ �������� ������������');
       return;
    }
    &Debug("��� ������ ��������� - �������� � �������. ���������� ���:\n\t\t$ON{$id}");
    &Deny_inet($id);			# ���������������� ������
    
 }
 $ON{$id}=$hash;

 &Debug("����� &Allow �� nofire.pl");
 &Allow({
    num		=> &Num($id),
    main_num	=> &Num($mid),
    id		=> $id,
    mid		=> $mid,
    ip		=> $ip,
    auth	=> $auth,
    paket	=> $paket,
    speed2	=> $speed2,   
    speed_in	=> $speed_in,
    speed_out	=> $speed_out,
    dop_param	=> $Udop{$id},
    plan_flags	=> $plan_flags,
    options	=> $options
 });
}

# ==========================
# ���������� ���� � ��������
# ==========================
sub LoadClientInfo
{
 my ($auth,$fname,$h,$id,$ip,$lstate,$mess,$mid,$msql,$net,$now_getting_all_info,$paket,$sql,$sth,$sth2,$traf);
 &Debug('��������� ������ ��������');
 
 $When_load_user_info=&TimeNow()+$c{Period_load_user_info};

 $h=localtime()->mday;
 %Uday_traf=() if $LastTrafDay && $LastTrafDay!=$h; # �������� ����� �����, ������� �������� ������
 $LastTrafDay=$h;

 $msql="$SQL_BUF id,mid,ip,auth,lstate,paket FROM $c{Db_usr_table} WHERE state<>'off'$Where_grp";
 if( $Reload_period-- <= 0 )
 {  # ������ ����� �������� ������ ������ ip
    $mess='$Reload_period <= 0 - ������� ������ ������ ��������.';
    $Reload_period=$c{Period_load_all_info};
    $now_getting_all_info=1;
 }
  else
 {
    $mess='������� ������ ��������, ��������������� ������� ���������';
    $msql.=$Where_auth;
    $now_getting_all_info=0;
 }

 # �������� ������������ ��������� (���������� ��������� ��������)
 &Debug('������� ��� ������������ ��������� (�����).');
 $sth=&Sql("$SQL_BUF uid,options FROM users_trf WHERE options<>''");
 if( $sth )
 {
    %Opt=();
    $Opt{$_->{uid}}=$_->{options} while ($_=$sth->fetchrow_hashref);
 }
  else
 {
    &Debug('����� ������������ ���������� �������, ���� ����');
 }

 my %NowAll=(); # ������ ��������� ���� ip NoDeny. � ���� �����:
 # %All   - ������ ���� ip �� ������� ����
 # %AllOn - ��������� ���������, 1 - ip �������
 $sql="$SQL_BUF uid,uip,now_on,in1,out1 FROM users_trf";
 $sth=&Sql($sql);
 if( !$sth )
 {
    $Err_get_uinfo++<3 && &Log("Error: $sql");
    $v && &Debug('���������� ���������� ������������. ��������� ������ ����� '.int($When_load_user_info-&TimeNow()).' ���');
    return;
 }

 while( $p=$sth->fetchrow_hashref )
 {
    $ip=$p->{uip} or next; # ������ ��� ��������� �������
    $id=$p->{uid};
    $NowAll{$ip}=1;
    $traf=$p->{in1}+$p->{out1};
    if( defined($Utraf{$id}) && $traf>$Utraf{$id})
    {
       $Uday_traf{$id}+=$traf-$Utraf{$id};
       $v && &Debug(sprintf("���������� ���������� ������� �� %d",$traf-$Utraf{$id}));
    }
    $Utraf{$id}=$traf;
    if( !$All{$ip} )
    {  # ����� ip � ����
       &Debug("$ip ����� ��� ���. �������� � %All. ������ �� nofire.pl: &Add_To_All_Ip($ip)");
       &Add_To_All_Ip($ip);
       $All{$ip}=1;
       $AllOn{$ip}=0;
    }
    $h=$p->{now_on};
    $v && &Debug(sprintf("%s ������: %d �� �����: %d ��������� now_on: %d",$ip,$Utraf{$id},$Uday_traf{$id},$h));
    $AllOn{$ip}!=$h or next;
    $AllOn{$ip}=$h;
    $h? &Add_To_Allow_Ip($ip) : &Delete_From_Allow_Ip($ip);
 }

 # ��� ip, ������� �������������� � ������� ����, � � ���� ����������� - ������
 foreach $ip (grep !$NowAll{$_}, keys %All)
 {
    &Debug("����������, ��� $ip ������ �� ��");
    &Delete_From_All_Ip($ip);
 }
 %All=%NowAll;

 sub SaveNet
 {
   my ($net,$id)=@_;
   $NET{$id}.=$NET{$id}? ",$net" : $net;
   $Tables{$id} or return;
   # ������� ���� ���������� �������� � ������� ipfw
   $id=$Tables{$id}; # ����� ������� ipfw
   if( !$NetsTbl{$id}{$net} )
   {  # � ������� $id ��� ��� ���� $net
      &Debug("� ������� $id ��� ��� ���� $net, ���������");
      &Add_To_Table($net,$id);
   }
   # 2 - �������, ��� ���� � _�������_ ����� ������������ � �������� �����  
   $NetsTbl{$id}{$net}=2;
 }

 {
  $now_getting_all_info or last;
  # ������� ������� �������������� ���������� ��������
  &Debug("������� ���������� ������� ��������� ���� ��������.");
  $sth=&Sql("$SQL_BUF parent_id,MAX(revision) AS r FROM dop_oldvalues GROUP BY parent_id");
  $sth or last;
  $Revision{$_->{parent_id}}=int($_->{r}) while( $_=$sth->fetchrow_hashref );

  $sth=&Sql("$SQL_BUF * FROM nets ORDER BY priority");
  $sth or last;

  %U=();		# ������� ������ �������� �.� �� ����� ������������� � ���� ����� ��������� ��������� �� ����
  &Load_Tarif;		# ������� ������ �.� � ������� ����� ���������� ��������
  %NET=();
  %Tables=();		# ���������� - ������ ���� �������� � nofire.pl
  # �������� ���� ��� �����������
  while( $p=$sth->fetchrow_hashref )
  {
     $net=$p->{net};
     $id=$p->{preset}.'-'.$p->{class};
     unless ($p->{priority})
     {  # ������� ������ - �������� �����������. ��� ����, ���� port!=0, �� �� ��������� �� ����� ������� ipfw,
        # ���� ����� �������� ��� ���� ��������� ������ � �������
        $h=$p->{port};
        next if $h<30 || $h>126; # �� 30� ������� ���������������, 126 - ������ ��� +1 ��� ������� � ���������
        &Debug('��� ����������� `'.$p->{comment}."` ��� ���� ����� ��������� � ������� $h");
        $Tables{$id}=$h;
        next;
     }

     $net or next;
     if( $net!~/^\s*file:\s*(.+)$/i )
     {
        &SaveNet($net,$id);
        next;
     }

     $fname=$1;
     &Debug("������ ����� ������������ � ��������� � ������� files � ������ $fname");
     $fname=~s|\\|\\\\|g;
     $fname=~s|'|\\'|g;
     $sql="$SQL_BUF data FROM files WHERE name='$fname'";
     $h=&Sql($sql);
     if( !$h || !($h=$h->fetchrow_hashref) )
     {
        next;
     }
     foreach $net (split /\n/,$h->{data})
     {
        next if $net!~/^\d/o || $net!~/^([^\s]+)\s*(.*)$/o;
        &SaveNet($1,$id);
     }
  }

  # ������ �� ipfw-������ ����, ������� ������� �� ��
  foreach $id (keys %NetsTbl)
  {
     for $net (keys %{$NetsTbl{$id}})
     {
        if( $NetsTbl{$id}{$net}>1 )
        {
           $NetsTbl{$id}{$net}=1;
           next;
        }
        delete $NetsTbl{$id}{$net};
        &Debug("������� ���� $net �� ������� $id �.�. ���� ������� �� ��");
        &Delete_From_Table($net,$id);
     }
  }
 }

 $t=&TimeNow();
 &Debug($mess);
 $sth=&Sql($msql);
 if( !$sth )
 {
    $Err_get_uinfo++<3 && &Log("Error: $msql");
    return;
 }

 $h=&TimeNow()-$t;
 $sql_time+=$h;
 $sql_count++;

 if( $sth->rows )
 {
    $No_activity=0;
 }
  elsif( $No_activity++>4 )
 {
    &Debug(">4 ������� �������� ������ �������������� �������� ��� ������ ���������. ���� ����� �� �����������, ���� ������. �������� ������� ���������������� � ��");
    $dbh='';
 }

 my %NowOn=(); # ���� �� �������� ������ � ������� ����
 while( $p=$sth->fetchrow_hashref )
 {
    $ip=$p->{ip};
    $id=$p->{id};
    # ��������� ����� ip � ��� ���� ������ ip �� ��������� ��������� - �������� ������ ip
    $id_to_ip{$id} && ($id_to_ip{$id} ne $ip) && $ON{$id} && &Deny_inet($id);
    $id_to_ip{$id}=$ip;
    $mid=$p->{mid} || $id;
    $auth=$p->{auth};
    $paket=$p->{paket};
    $lstate=$p->{lstate};

    $U{$id}{ip}=$ip;
    $U{$id}{mid}=$mid;
    $U{$id}{auth}=$auth;
    $U{$id}{paket}=$paket;
    $U{$id}{options}=$Opt{$mid};

    &Debug("ip: $ip auth: $auth".(!!$lstate && ' (������ ������)'));
    # ��������� ������ �� ��������� ������ ������ ��������, �� �������� �����������
    if( !$c{Allow_unauth} && ($auth eq 'no') && !$lstate )
    {
       &Debug('�� ������������� �������� ���������');
       next;
    }
    # ����������� � ������ `��������` � ��� ���� ����� "��������� ������ ��� ����������� `����`" �� ��������
    ($auth eq 'off') && !$c{Allow_auth_off} && next;
    # ���� ������ �������� ������ - ������ �� ���������
    $auth>0 && !$c{Allow_overlimits} && next;
    &Allow_inet($id);
    $NowOn{$id}=1;
 }
 # �������� ���, ��� ������� � � ����� ������ �� ������������
 foreach $id (grep $ON{$_} && !$NowOn{$_}, keys %ON)
 { 
    &Debug("$ip � ������� ���� ������������ �������� ���������, ������ ��� - ���������");
    &Deny_inet($id);
 }

 &Debug('��������� �� �������� ���������� � ����� ���� �������');
 $sth=&Sql("SELECT uid,test FROM users_trf WHERE test>0");
 if( $sth )
 {
    while( $p=$sth->fetchrow_hashref )
    {
       $id=$p->{uid};
       $U{$id}{test}!=$p->{test} or next;
       $ip=$U{$id}{ip};
       $report.="��������� ������� id=$id. ";
       if( !$ip )
       {
          $report.='��� ������. �������� ������ � ������, ������� �� ����������� ������ ��������. '.
             '���� ������ ������� ���� ������ ��� ������� - ��������� ������ �������� ����� '.
             $c{Period_load_user_info}*$c{Period_load_all_info}." ���\n";
          next;
       }
       $U{$id}{test}=$p->{test};
       $h=$U{$id}{auth};
       $report.="ip=$ip. ���� auth: $h (".($h eq 'no'? '�� �����������': $h>0? '�����������, �� ������������ �� �����������' : '�����������').'). '.
         ($NowOn{$id}? '������ � �������� ��������' : '������ � �������� ������������').". ����� �����������: $U{$id}{paket}.\n";
    }
 }

 if( $now_getting_all_info )
 {
    &Debug('��������� �� ������?');
    $sth=&Sql("SELECT time FROM conf_sat WHERE login='$FiltrDb_user' AND time<>$Config_time LIMIT 1");
    if( $sth && $sth->fetchrow_hashref )
    {
       &Log("I found new config! Reloading...");
       $Exit_reason='����������, ��� ������ ���������. ������������ �������� � ������������� �������.';
       $Exit_cod=0;
       &Exit; # �������� �������� ������ �����
    }
 }
 $v && &Debug('���������� ���������� ������ ������������. ��������� ������ ����� '.int ($When_load_user_info-&TimeNow()).
   " ���. �������� �� ���������� ������� �������������: $Reload_period");
}

# =========================================
#      ������ ���������� � ���� ������
# =========================================
sub SendAgentStat
{
 $t_stat=$t+$ReStat; # ����� ��������� ����������
 $report.="�������� ipfw: $nRules";
 $report.="\n������� ����� ���������� sql-�������� ".sprintf("%.3f",$sql_time/$sql_count).' ���' if $sql_count;
 $report.="\n������ ���������� � ��: $Err_connect" if $Err_connect;
 $report.="������ ��������� info ��������: $Err_get_uinfo\n" if $Err_get_uinfo;
 &SaveSatStateInDb($report||'ok',($Err_get_uinfo+$Err_connect)>3? 1:0);
 $Err_connect=$Err_get_uinfo=0;
 $report='';
 $nRules=0;
}
