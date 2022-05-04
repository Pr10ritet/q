#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# ��������������� ���� ��� ������� ����������
# ---------------------------------------------
$VER=50.33;

# ��� ������� ������ ���� ����������������� ����������:
#  $Mod_id	- id ����������� ������� ��� id ������
#  $AgentName	- ��� ������

# exit 0 - ����� � ���������, exit 1 - ��� ��������

use Time::HiRes qw( clock_gettime CLOCK_MONOTONIC gettimeofday tv_interval );
use Time::localtime;
use IO::File;
use FindBin;
use DBI;

$Program_dir=$FindBin::Bin;

$Config		= 'sat.cfg';
$ReStat		= 300;	# ���, �������� ������ ���������� � ���� ������ ������

$Pid=0;
$v=$ARGV[0] eq '-v';
$v && shift @ARGV;

$Pid_file='/var/run/'.($ARGV[0] || $AgentName).'.pid';

$t=localtime();
$temp_errlog=sprintf("%s/%s_error_%02d.%02d.%04d.log",$Program_dir,$AgentName,$t->mday,$t->mon+1,$t->year+1900);
if( !$v )
{
  open(STDERR,">>$temp_errlog");
  open(STDOUT,">>$temp_errlog");
  open(STDIN,"</dev/null");
}

$Exit_reason='';
$Exit_cod=0;

$SIG{TERM}=$SIG{INT}=sub
{
 $Exit_reason='������� ������ ���������� ������ �������';
 $Exit_cod=1;
};

$SIG{HUP}=sub
{
 $Exit_reason='������� ������ ������������ �������';
 $Exit_cod=0;
};


$Config="$Program_dir/$Config";

(-e $Config ) or &HardExit("Start config $Config is not found!");
eval{require $Config};
$@ && &HardExit("Error loading start config $Config!");

$SQL_BUF='SELECT SQL_BUFFER_RESULT';
$DSN="DBI:mysql:database=$Db_name;host=$Db_server;mysql_connect_timeout=$Db_mysql_connect_timeout";
$dbh='';
$FiltrDb_user=$Db_user;
$FiltrDb_user=~s|\\|\\\\|g;
$FiltrDb_user=~s|'|\\'|g;
$T_db_error=[gettimeofday];

&ConnectToDB;
if( !$dbh )
{
  &Debug('5 sec...');
  sleep 5;
  &ConnectToDB;
}

$dbh or &HardExit("Error connecting to DB $Db_name");
$sth=$dbh->prepare("$SQL_BUF * FROM conf_sat WHERE login='$FiltrDb_user' LIMIT 1");
$sth->execute or &HardExit("Error getting config from DB $Db_name (connected, but sql query is fault)");
($p=$sth->fetchrow_hashref) or &HardExit("Error getting config from DB $Db_name (connected, but there is no data for login $Db_user)");
&Debug('Config from DB: OK','nosat');
foreach( split /\n/,$p->{config} )
{
   $c{$1}=$2 if /^([^ ]+) (.*)$/;
}

$Config_time=$p->{time};
$Name_server=$p->{name};
$Sat_id=$p->{id};
$Passwd_Key=$p->{Passwd_Key};
$version=$p->{version};

if( $VER!=$version )
{
   &Error("Wrong config version: $version. You need resave config");
}

$Logfile="$Program_dir/$AgentName.log";
if( $v )
{
  #*STDERR=*STDOUT; 
}
 else
{
  open(STDERR,">>$Logfile");
  open(STDOUT,">>$Logfile");
}
unlink $temp_errlog;

&Debug("Checking pid-file $Pid_file",'nosat');
if( -e $Pid_file )
{
   &Debug("$Pid_file exists. Openning...",'nosat');
   unless( $f=IO::File->new($Pid_file) )
   {
      &Error("Error openning pid-file. Am I root?");
   }
   $Pid=<$f>;
   &Debug("Sending a signal to the process $Pid...",'nosat');
   if( kill 0 => $Pid )
   {
      &Error("Script already running with pid=$Pid");
   }
   &Log("Script with pid=$Pid is a zombie. Removing pid-file");
   unlink $Pid_file;
}

$Pid=$$;
&Debug("Creating pid-file $Pid_file with pid=$Pid",'nosat');

# O_EXCL �� ��������� ���� ���� ����������! (������������ ������)
$f=IO::File->new($Pid_file,O_WRONLY|O_CREAT|O_EXCL,0644);
defined $f or &Error("Error creating pid-file. Am I root?");

print $f $Pid;
close $f;

&Debug('end','nosat');

# ===

sub HardExit
{
   $t=localtime();
   print $t->hour.':'.$t->min.' '.$_[0]."\n";
   exit 1; 
}

sub Exit
{ 
 if( $Pid==$$ )
 {  # ������ pid-���� ������ ���� �� �� ������ ��������
    &Debug("Removing pid-file $Pid_file",'nosat');
    unlink $Pid_file;
 }
 $dbh && &SaveSatStateInDb($Exit_reason,$Exit_cod);
 $Exit_reason && &Log($Exit_reason);
 exit $Exit_cod;
}

sub Error
{
 $Exit_reason=shift @_;
 $Exit_cod=1;
 &Exit;
}

sub Debug
{
 $v && print "\033[1m$AgentName: ".($_[1] || "\t")."\t#\033[0m $_[0]\n";
}

sub Log
{
 my $t=localtime();
 $t=sprintf("%02d.%02d.%04d %02d:%02d:%02d %s",$t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min,$t->sec,$_[0]);
 if( $v )
 {
    &Debug($t);
    return;
 }
 open(LOG,">>$Logfile") or return;
 print LOG $t."\n";
 close(LOG);
}

sub TimeNow
{
 return(clock_gettime(CLOCK_MONOTONIC));
}

sub ConnectToDB
{
 $dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
 $v && &Debug("���������� � �� �� ������� $Db_server: ".($dbh? 'OK' : 'ERROR'));
 $dbh or $Err_connect++;
}

# ����������� � �� �� ���� 5 ���
sub SoftConnectToDB
{
 tv_interval($T_db_error)<5 && return;
 $T_db_error=[gettimeofday];
 &ConnectToDB;
}

sub sql
{
 my ($i,$sql,$sth,$time);
 $sql=shift @_;

 if( $v )
 {
    $_=$sql;
    s/^$SQL_BUF/SELECT/;
    &Debug($_,"sql\t");
 }

 $i=2; # ������� ��������� sql-������
 while(1)
 {
    $dbh or &SoftConnectToDB;
    if( !$dbh )
    {
       &Debug('������ �� �������� - ��� ���������� � ��',"sql\t");
       return '';
    }
    $time=&TimeNow(); # �� ���� ��������
    $sth=$dbh->prepare($sql);
    if( $sth->execute )
    {
       $v && &Debug('rows: '.$sth->rows.' �����: '.sprintf("%.5f ���",&TimeNow()-$time));
       return $sth;
    }
    if( --$i<=0 )
    {
       &Debug('������ �� ��������',"sql\t");
       return '';
    } 
    &Debug('������. ������� soft-��������� � ��.',"sql\t");
    $dbh='';
 }
}


# ������ � �� ��������� ������, ����:
#  0: ����� ���������
#  1: 0 - ����������� ������ ���, 1 - ����������� ������, ��� ���� ����� ������� ��������� ����� ��������� "!\n" ��� �������, ��� ���� ����� ������� �� �����, �.� ������ ���������
sub SaveSatStateInDb
{
 $dbh or &ConnectToDB;
 $dbh or return;
 &Debug('SaveSatStateInDb');
 $dbh->do("INSERT INTO sat_log SET sat_id=$Sat_id,mod_id=$Mod_id,time=unix_timestamp(),info='".(!!$_[1] && "!\n")."$_[0]',error=$_[1]");
}



1;
