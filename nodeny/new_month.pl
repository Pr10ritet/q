#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

#==========================================================================#
#                                                                          #
#                         ������� �� ����� �����                           #
#                                                                          #
#==========================================================================#

# -----------------------------------------------------------------------
# ��������� ������ ����������������� ������ ��� ������ � ��������� ������
#$TEST=1;
$V=0;
# ���������� $V>0 ����� �� ����������� ������� ��������, � sql �������
# ���������� �� �����. ��� ���� ����� ����� ��������� �� ���������� �������
# ��������������� ��� �������� �� ����� �����. ��������, $V=10; 

$Main_config='nodeny.cfg.pl';

# -----------------------------------------------------------------------

use DBI;
use Time::localtime;
use Time::Local;
use FindBin;

#==========================================================================

sub ToLog
{
 unless (open(LOG,">>$_[0]"))
 {
    print STDERR "ERROR SAVING LOG $_[0]! Data: $_[1]\n";
    return;
 }
 print LOG "$_[1]\n\n";
 close(LOG);
}

# ����� � ��������� ���� ������ �������� �������
sub Exit 
{
  &ToLog($LogFile,$Alog) if $Alog;
  unlink $ErrFile if (stat($ErrFile))[7]==0;
  exit;
} 

sub DB_Connect
{
 $dbh=DBI->connect($DSN,$user,$pw,{PrintError=>1});
 if( !$dbh )
 {
    print "Error connecting to BD. Reconnect ...\n" if $V;
    sleep 1;
    $dbh=DBI->connect($DSN,$user,$pw,{PrintError=>1});
    if( !$dbh )
    {
       print "Error connecting to BD\n" if $V;
       &ToLog($ErrFile,$err_connect);
       &Exit;
    }
 }
 print "OK\n" if $V;
 $dbh->do("SET character_set_client=cp1251");
 $dbh->do("SET character_set_connection=cp1251");
 $dbh->do("SET character_set_results=cp1251");
}

sub Filtr_mysql
{
 $_=shift;
 tr/\x00-\x1f//;
 s/\\/\\\\/g;
 s/'/\\'/g;
 return ($_);
}

# -------- ������ ������� � ������� ������� ----------
# ����: ��� �������, ����� �������
sub SaveEventToDb
{
 $dbh or return;
 $_=$_[1];
 s/\\/\\\\/g;
 s/'/\\'/g;
 # 404 - ��� '��������� �������'
 $_="INSERT INTO pays SET mid=0,cash=0,bonus='',admin_id=0,admin_ip=0,office=0,type=50,reason='$_',coment='',category=404,time=$ut"; 
 if ($V) {print "$_\n"} else {$dbh->do($_)}
}

sub sql
{
 my $sql=$_[0];
 print "$sql\n" if $V;
 my $sth=$dbh->prepare($sql);
 return($sth) if $sth->execute;

 &DB_Connect;
 $sth=$dbh->prepare($sql);
 return($sth) if $sth->execute;

 &ToLog($ErrFile,$err_connect);
 &Exit;
}

sub sql_do
{
 my ($rows);
 if( $V )
 {
    print "$_[0]\n";
    return(1);
 }
 $rows=$dbh->do($_[0]);
 return $rows if $rows;
 &DB_Connect;
 return($dbh->do($_[0]));
}

# ============ ����� ============

$Program_dir=$FindBin::Bin;
$Main_config="$Program_dir/$Main_config" if $Main_config!~m|^/|;

$t=localtime();
$mon=$t->mon;
$year=$t->year;
$day=$t->mday;
$mon_now=$mon+1;
$year_now=$year+1900;

$Alog='';
$LogFile="$Program_dir/NEW_MONTH_LOG_$mon_now.$year_now";
$ErrFile="$Program_dir/NEW_MONTH_ERROR_$mon_now.$year_now";
open(STDERR,">>$ErrFile");

$err_mess="$0: ������� �� ����� ����� �� �����������!";

unless (-e $Main_config)
{
   &ToLog($ErrFile,qq{$err_mess �������������� ���� $0, ������ "\$Main_config = ..." - ���� � ����������������� �����\n});
   exit;
}

require $Main_config;
$kb||=1000;
$mb=$kb*$kb;
$ut='unix_timestamp()';

$db_name='del' if $TEST;

$db_server||='localhost';
$db_server2||='localhost';
$DSN="DBI:mysql:database=$db_name;host=$db_server;mysql_connect_timeout=10";

$err_connect="$err_mess ��������� ������ ���������� � ����� ������ $db_name, ������: $db_server, �����: $user\n";

&DB_Connect;

$nomoney_pl="$Nodeny_dir/nomoney.pl";
unless (-e $nomoney_pl) {&SaveEventToDb('',"$err_mess ������ �������� �������� �� ������."); &Exit}
$VER_chk=$VER;
$VER=0;
require $nomoney_pl;
if( $VER!=$VER_chk )
{
   &SaveEventToDb('',"$err_mess ������ �������� �������� �� ������������� ������ ������� �������� �� ����� �����.");
   &Exit;
}

unless (&TarifReload) {&SaveEventToDb('',"$err_mess ������ � �������."); &Exit}

$err_connect="$0: �������� � ����� ������ (�������� ���������� ����������). �� ������� ������ ������� �� ��������� �� ���� ������. ".
    "��������� ������ � ��������� ������ �������� ��������.\n";

$arg=lc($ARGV[0]);
if( $day>1 && $arg ne 't' && $arg ne '-t' )
{
   $mess="$err_mess �������: ������� ����� ������ 1. ������� �������� ������ 1-�� �����. ".
      "��� ��������������� �������� ��������� ������ � ������ '-t'. �.�.\nshell# ./$0 -t\n";
   &ToLog($ErrFile,$mess);
   &SaveEventToDb('',$mess);
   &Exit;
}

# ������� ��������� ���������� �����
$sth=&sql("SELECT * FROM user_grp");
while ($p=$sth->fetchrow_hashref)
{
   $grp_id=$p->{grp_id};
   $UGrp{$grp_id}=$p->{grp_property};
   $UGrp_name{$grp_id}=$p->{grp_name};
}

$time2=timelocal(0,0,0,1,$mon,$year)-1;		# ����� ����������� ������
$time_last=$time2-5;				# ����� ����������� ������ -5 ������ ��� �����
$h=localtime($time_last);
$mon_last=$h->mon;
$year_last=$h->year;
$time1=timelocal(0,0,0,1,$mon_last,$year_last);	# ������ �������� ������
$mon_last++;
$year_last+=1900;

# ������� ������ � ���, ��� ���� �� ��� ������������� � ������� ������
%Auth=();
$sql="SELECT DISTINCT mid FROM login WHERE time>=$time1 AND time<=$time2 AND act>0";
$sth=&sql("SELECT DISTINCT id FROM users WHERE id IN($sql) OR mid IN ($sql)");
$Auth{$_->{id}}=1 while ($_=$sth->fetchrow_hashref);

# ������ �������� ��� ������� ��� ��� ����������� �������
%Already=();
$sth=&sql("SELECT uid FROM arch_users WHERE mon=$mon_last AND year=$year_last");
$Already{$_->{uid}}=1 while ($_=$sth->fetchrow_hashref);

$sth=&sql("SELECT uid,in1,out1,in2,out2,in3,out3,in4,out4 FROM users_trf");
while ($p=$sth->fetchrow_hashref)
{
   $uid=$p->{uid};
   push @{$TRAF{$uid}},$p->{$_} foreach('in1','out1','in2','out2','in3','out3','in4','out4');
}

# � arch_trafnames �������� �������� ���� ����������� ��� ���� ��������
$sth=&sql("SELECT * FROM nets WHERE priority=0");
&sql_do("DELETE FROM arch_trafnames WHERE mon=$mon_last AND year=$year_last"); # ����� � ����� ������������������: ������� ��������, ��� select ��������, ����� ��������
while ($p=$sth->fetchrow_hashref)
{
   $class=$p->{class};
   next if $class<1 || $class>8;
   $preset=$p->{preset};
   $trafname=&Filtr_mysql($p->{comment});
   $h="arch_trafnames SET traf$class='$trafname'";
   $rows=&sql_do("UPDATE $h WHERE mon=$mon_last AND year=$year_last AND preset=$preset");
   next if $rows==1;
   if ($rows)
   {  # sql ��������, �� 0 ����� (0E0)
      $rows=&sql_do("INSERT INTO $h,mon=$mon_last,year=$year_last,preset=$preset");
      next if $rows==1;
   }
   &ToLog($ErrFile,"$err_mess ������ ������ ������ � ������� arch_trafnames");
   &Exit;
}

# ������ ...
$err_connect="$0: ����� ���������� � ����� ������. ��������, ������� �� ����� ����� �� ��������. ��������� ������ �������� ��������.\n";

$sql="SELECT * FROM users WHERE mid=0";
$sql.=' LIMIT '.(int $V ||5) if $V;
$sth=&sql($sql);

%s=();

while ($p=$sth->fetchrow_hashref)
{
 $id=$p->{id};
 $ipp=$p->{ip};
 $grp=$p->{grp};
 $paket=$p->{paket};
 $paket3=$p->{paket3};
 $srvs=$p->{srvs};
 $start_money=$p->{balance};
 $start_day=$p->{start_day};
 $discount=$p->{discount};
 $cstate=$p->{cstate};
 $next_paket=$p->{next_paket};
 $next_paket3=$p->{next_paket3};

 print "===== id=$id ip=$ipp =========================\n" if $V;

 $Alog.="id: $id, ip: $ipp, ������: $grp, �����: $paket, ������: $start_money, ���� ������ ����.�����: $start_day.";

 if( $Already{$id} )
 {
    $Alog.=" � ������� arch_users ��� ���� ������ � uid=$id,mon=$mon_last,year=$year_last - ������� ������ ��� ��� ��������� �� ����� �����.\n";
    print "��� ��������� �� ����� ����� �.�. ���� ��������������� ������ � ������� arch_users.\n" if $V;
    $s{already}++;
    next;
 }

 $sql_arch="INSERT INTO arch_users SET uid=$id,mon=$mon_last,year=$year_last,uip='$ipp',grp=$grp,paket=$paket,preset=$Plan_preset[$paket],auth=".($Auth{$id}?1:0);

 # ��� ���� ������ �� ����� ����������� ������ �����
 if( $UGrp{$grp}=~/1/ )
 {
    $Alog.=" ������ ��������� ������� ������� �� ����� �����, �� ���������.\n";
    print "�� ��������� � ����� ����� - ������ ���������.\n" if $V;
    $s{noneed}++; 
    $rows=&sql_do("$sql_arch,no_submoney=1");
    if( $rows<1 )
    {
       $s{no}++;
       &ToLog($ErrFile,"$0: ������ �������� ������� � id=$id �� ����� �����! Sql: $sql");
    }
    next;
 }

 @T=defined $TRAF{$id}? @{$TRAF{$id}} : (0,0,0,0,0,0,0,0);

 # ����� ��� ������� ����� ���������� � ������: ��������/��������� ��� ���������
 $traf1=&Get_need_traf($T[0],$T[1],$InOrOut1[$paket])/$mb;
 $traf2=&Get_need_traf($T[2],$T[3],$InOrOut2[$paket])/$mb;
 $traf3=&Get_need_traf($T[4],$T[5],$InOrOut3[$paket])/$mb;
 $traf4=&Get_need_traf($T[6],$T[7],$InOrOut4[$paket])/$mb;

 # ���� ������ �� ����� ���������� ������ - ������ � ������ �� ����������
 # � ��� �� �������� ����� ���� �������, ��� � �������� ��� � ����
 if( $start_day<0 )
 {
    $s{new}++;
    $Alog.=" ������ ��� �� ����� ������������ ��������. �� ����� ����� �� ���������.";
    if( $traf1+$traf2+$traf3+$traf4 )
    {
       $Alog.=" ������ �� ������� ������-��. ��������."; 
       &sql_do("UPDATE users_trf SET in1=0,in2=0,in3=0,in4=0,out1=0,out2=0,out3=0,out4=0 WHERE uid=$id LIMIT 1");
    } 
    $Alog.="\n";
    $rows=&sql_do("$sql_arch,no_submoney=2");
    if( $rows<1 )
    {
       $s{no}++;
       &ToLog($ErrFile,"$0: ������ �������� ������� � id=$id �� ����� �����! Sql: $sql");
    }
    next;  
 }

 # ����� ������=0 - ��������� ��� ������������ $service_list
 $money_param={
   paket=>$paket,
   paket3=>$paket3,
   traf1=>$traf1,
   traf2=>$traf2,
   traf3=>$traf3,
   traf4=>$traf4,
   service=>$srvs,
   start_day=>$start_day,
   discount=>$discount,
   mode_report=>0
 };
 $h=&Money($money_param);
 $got_money=sprintf("%.2f",$h->{money});
 $money_over=$h->{money_over};
 $service_list=$h->{service_list};
 chomp $service_list;
 ($Traf1,$Traf2,$Traf3,$Traf4)=($h->{traf1},$h->{traf2},$h->{traf3},$h->{traf4});

 $rows=&sql_do("$sql_arch,no_submoney=0");
 if( $rows<1 )
 {
    $s{no}++;
    &ToLog($ErrFile,"$0: ������ �������� ������� � id=$id �� ����� �����! Sql: $sql");
    next;
 }

 $Alog.=" ����� ������: $got_money.";

 $sql="UPDATE users SET next_paket=0,next_paket3=0,start_day=0,balance=balance-$got_money";
 if( $next_paket )
 {
    $sql.=",paket=$next_paket"; 
    $Alog.=" ������������ �����: $next_paket.";
 } 
 if( $next_paket3 )
 {
    $sql.=",paket3=$next_paket3"; 
    $Alog.=" ������������ �������������� �����: $next_paket3.";
 } 
 $sql.=",srvs=2147483648" if $AbonPay_day && ($srvs & 0x80000000); # ������� ��������� �� �����
 $sql.=" WHERE id=$id LIMIT 1";

 $rows=&sql_do($sql);
 if( $rows<1 )
 {
    $s{no}++;
    &ToLog($ErrFile,"$0: ������ �������� ������� � id=$id �� ����� �����! Sql: $sql");
    next;
 } 

 $sql="UPDATE users_trf SET ".
   "in1=in1-$T[0],".
   "out1=out1-$T[1],".
   "in2=in2-$T[2],".
   "out2=out2-$T[3],".
   "in3=in3-$T[4],".
   "out3=out3-$T[5],".
   "in4=in4-$T[6],".
   "out4=out4-$T[7] ".
  "WHERE uid=$id LIMIT 1";

 $rows=&sql_do($sql);
 if( $rows<1 )
 {
    $s{error}++;
    &ToLog($ErrFile,"$0: ��� �������� ������� id=$id �� ����� ����� �� ������� ������� ������! ���������� ������� ��������� sql: $sql");
 }


 # ������� ����� � � �������
 $next_paket && &sql_do("UPDATE users SET paket=$next_paket WHERE mid=$id"); 
 $next_paket3 && &sql_do("UPDATE users SET paket3=$next_paket3 WHERE mid=$id"); 

 $traf1=$Traf1*$mb;
 $traf2=$Traf2*$mb;
 $traf3=$Traf3*$mb;
 $traf4=$Traf4*$mb;

 @c=&Get_Name_Class($Plan_preset[$paket]);

 @f=(1,$Plan_over2[$paket]!=0,$Plan_over3[$paket]!=0,$Plan_over4[$paket]!=0);

 $coment="�� ������ ������� � ��������";
 $coment.=", ������� ������:\n$service_list" if $service_list;
 $coment.="\n�����: ".(&Filtr_mysql($Plan_name_short[$paket])||'-');

 $reason="������ �� ������������. ����-�����:\n";
 @traf=($Traf1,$Traf2,$Traf3,$Traf4);
 foreach $i (0..3)
 {
    $coment.="\n".&Filtr_mysql($c[$i]).': '.(shift @traf).' ��' if $f[$i];
    ($t1,$t2)=($T[$i*2],$T[$i*2+1]); # �������� � ��������� ������ �����������
    next if !$f[$i] && !$t1 && !$t2; # ���� ����������� ��� ����������������� � � ��� ��� �������
    $reason.=($i+1).': '.sprintf("%.6f",$t1/$mb).' - '.sprintf("%.6f",$t2/$mb)."\n";
 }
 $coment.="\n���� ������ ����������� �����: $start_day. ������ ������ ��������� ��������������� ���������� ���������� ���� � ������" if $start_day;

 if( $Plan_flags[$paket]=~/f/ )
 {  # ����� ��������������� ������� ��������������� ������� �� ������� �����
    $set_sql='';
    $h='';
    foreach $i (1..4)
    {
       next if ${"Plan_mb$i"}[$paket]>=$unlim_mb; # ����������� ������ �� �����������
       $j=${"Traf$i"} - ${"Plan_mb$i"}[$paket];
       next if $j>=0;
       $set_sql.=",in$i=".int($j*$mb);
       $h.="\n".$c[$i-1].": ".sprintf("%.3f",($j*-1)).' ��';
    }
    if( $set_sql )
    {
       $set_sql=~s/^,//;
       $coment.="\n������������ �� ����� ����� ������: $h";
       $sql="UPDATE users_trf SET $set_sql WHERE uid=$id LIMIT 1";
       $rows=&sql_do($sql);
       if( $rows<1 )
       {
          $s{error}++;
          &ToLog($ErrFile,"$0: ��� �������� ������� id=$id �� ����� ����� �� ��������� ������ �� ����� �����! ���������� ������� ��������� sql: $sql");
       }
    }  
 }

 chomp $reason;    
 $sql="INSERT INTO pays ".
    "(mid,cash,time,admin_id,admin_ip,bonus,reason,coment,type,category) VALUES".
    "($id,-$got_money,$time_last,0,0,'y','$reason','$coment',10,110)";
 $rows=&sql_do($sql);
 if( $rows<1 )
 {
    $s{error}++;
    &ToLog($ErrFile,"$0: ������ �������� ������� � ������ �� ������, sql: $sql. ����� ���������� �� �������. ��������� sql �������.");
    &SaveEventToDb('',"������ �������� ������� � ������ �� ������. ������ id: $id. ����������� ������ $got_money $gr �������");
    next;
 }
 $s{ok}++;
 $Alog.=" ���������.\n";  
}

$mess=$s{no}? "������� �� ����� ����� ����������� ��������: �� ���������� $s{no} ��������. �������� ���� � ����� � $0" : '������� �� ����� ����� ����������� �������';
$mess.="\n$s{ok} �������� ���� ���������� �� ����� �����.";
$mess.="\n$s{error} �������� ���� ���������� �� ����� ����� � ��������. �������� ���� � ����� � $0." if $s{error};
$mess.="\n$s{noneed} �������� ��������� � ������, � ������� �� ����������� ������ �������� �������." if $s{noneed};
$mess.="\n$s{already} �������� ��� ���� ���������� �� ����� ����� �� �������� �������. ��������, ��� �� ������ ������ �������." if $s{already};
$mess.="\n$s{new} �������� �� ������ ������������ ��������, ������ ������� �� �������������." if $s{new};
&SaveEventToDb('q',"$mess");

&Exit;
