#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Проверка корректности настройки агентов сателлита

use DBI;
use FindBin;

$Config='sat.cfg'; # конфиг

sub Stop
{
 print "\n$_[0]\n\n";
 exit;
}

$Program_dir=$FindBin::Bin;
$Config="$Program_dir/$Config";

(-e $Config) or &Stop("Не найден конфигурационный файл сателлита: $Config");
require $Config;

$DSN="DBI:mysql:database=$Db_name;host=$Db_server;mysql_connect_timeout=$Db_mysql_connect_timeout";

$dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>1});
unless ($dbh)
  {
   &Stop("Невозможно соединиться с базой данный NoDeny!\n\n".
     "Попробуйте соединиться с консоли:\n\nmysql -u$Db_user -p$Db_pw $Db_name\n\n".
     "Если соединение не происходит или выдает ошибку, то:\n\n".
     "1) Проверьте, что на сервере $Db_server в mysql создана учетная запись с именем $Db_user и ".
      "ей разрешено коннектиться к mysql с адреса текущего сервера - зайдите на сервер с БД и ".
      "в консоли выполните:\n\nmysql -p\n\n[введите root-пароль в mysql]\n\n".
      "use mysql;\n".
      "select User,Host from user where User='$Db_user';\n\n".
      "Если учетная запись не будет найдена либо адрес сервера не соответствует адресу сателлита - ".
      "необходимо создать учетную запись и дать соответствующие права, смотрите документацию.\n\n".
     "2) Возможно указан неверный пароль");
  }

$FiltrDb_user=$Db_user;
$FiltrDb_user=~s|\\|\\\\|g;
$FiltrDb_user=~s|'|\\'|g;
$sql="SELECT SQL_BUFFER_RESULT * FROM conf_sat WHERE login='$FiltrDb_user' LIMIT 1";
$sth=$dbh->prepare($sql);
(!($sth->execute) || !($p=$sth->fetchrow_hashref)) && &Stop("Соединение с базой данной выполнено, однако не найден ".
  "конфигурационный файл текущего сателлита. В админке в настройках сателлитов убедитесь, что присутствует конфиг ".
  "для логина: $Db_user. Если конфиг существует, возможно у учетной записи $Db_user нет прав на чтение таблицы conf_sat");


foreach (split /\n/,$p->{config}) {$c{$1}=$2 if /^([^ ]+) (.*)$/}
$config_time=$p->{time};
$name_server=$p->{name};
$sat_id=$p->{id};

print "Проверка прав на чтение таблиц:\n\n";

$i=1;
foreach $tbl( $c{Db_usr_table},'files','nets','plans2','users_trf','dopdata','dop_oldvalues' )
  {
   $sql="SELECT COUNT(*) FROM $tbl";
   $sth=$dbh->prepare($sql);
   print $i++.". $sql...";
   if (!$sth->execute || !($p=$sth->fetchrow_hashref)) {print "ОШИБКА\n".$dbh->errstr."\n"; exit}
   print "OK\n\n";
  } 

&Stop("Проверки выполнены. Все ОК.");

