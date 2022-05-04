#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# �������� ������������ ��������� ������� ���������

use DBI;
use FindBin;

$Config='sat.cfg'; # ������

sub Stop
{
 print "\n$_[0]\n\n";
 exit;
}

$Program_dir=$FindBin::Bin;
$Config="$Program_dir/$Config";

(-e $Config) or &Stop("�� ������ ���������������� ���� ���������: $Config");
require $Config;

$DSN="DBI:mysql:database=$Db_name;host=$Db_server;mysql_connect_timeout=$Db_mysql_connect_timeout";

$dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
unless ($dbh)
  {
   &Stop("���������� ����������� � ����� ������ NoDeny!\n\n".
     "���������� ����������� � �������:\n\nmysql -u$Db_user -p$Db_pw $Db_name\n\n".
     "���� ���������� �� ���������� ��� ������ ������, ��:\n\n".
     "1) ���������, ��� �� ������� $Db_server � mysql ������� ������� ������ � ������ $Db_user � ".
      "�� ��������� ������������ � mysql � ������ �������� ������� - ������� �� ������ � �� � ".
      "� ������� ���������:\n\nmysql -p\n\n[������� root-������ � mysql]\n\n".
      "use mysql;\n".
      "select User,Host from user where User='$Db_user';\n\n".
      "���� ������� ������ �� ����� ������� ���� ����� ������� �� ������������� ������ ��������� - ".
      "���������� ������� ������� ������ � ���� ��������������� �����, �������� ������������.\n\n".
     "2) �������� ������ �������� ������");
  }

$FiltrDb_user=$Db_user;
$FiltrDb_user=~s|\\|\\\\|g;
$FiltrDb_user=~s|'|\\'|g;
$sql="SELECT SQL_BUFFER_RESULT * FROM conf_sat WHERE login='$FiltrDb_user' LIMIT 1";
$sth=$dbh->prepare($sql);
(!($sth->execute) || !($p=$sth->fetchrow_hashref)) && &Stop("���������� � ����� ������ ���������, ������ �� ������ ".
  "���������������� ���� �������� ���������. � ������� � ���������� ���������� ���������, ��� ������������ ������ ".
  "��� ������: $Db_user. ���� ������ ����������, �������� � ������� ������ $Db_user ��� ���� �� ������ ������� conf_sat");


foreach (split /\n/,$p->{config}) {$c{$1}=$2 if /^([^ ]+) (.*)$/}
$config_time=$p->{time};
$name_server=$p->{name};
$sat_id=$p->{id};

print "�������� ���� �� ������ ������:\n\n";

$i=1;
foreach $tbl( $c{Db_usr_table},'files','nets','plans2','users_trf','dopdata','dop_oldvalues' )
  {
   $sql="SELECT COUNT(*) FROM $tbl";
   $sth=$dbh->prepare($sql);
   print $i++.". $sql...";
   if (!$sth->execute || !($p=$sth->fetchrow_hashref)) {print "������\n".$dbh->errstr."\n"; exit}
   print "OK\n\n";
  } 

&Stop("�������� ���������. ��� ��.");

