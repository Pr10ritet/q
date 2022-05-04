#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (ñ) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
#		NoDeny Installer
# =============================================
$VER=50.33;

use DBI;
use FindBin;
use File::Path;
use File::Copy;
use Time::localtime;

$dir=$FindBin::Bin;

$dir_nodeny	= '/usr/local/nodeny';
$dir_www	= '/usr/local/www/apache22/data';
$dir_cgi	= '/usr/local/www/apache22/cgi-bin';

$sql_root_pass	= 'hardpass';
$sql_server	= 'localhost';
$sql_database	= 'bill';
$sql_u_www	= 'bill_www';
$sql_p_www	= 'hardpass2';
$sql_u_www_ip	= 'localhost';
$sql_u_kern	= 'bill_kernel';
$sql_p_kern	= 'hardpass4';
$sql_u_kern_ip	= 'localhost';

$www_u		= 'www';
$file_history	= 'history.nod';
$make_backup	= 1;

# === start test ===
if( `printenv | grep NODENY`=~/NODENY=test/ )
{
  $dir_nodeny	= '/usr/local/test';
  $dir_www	= '/usr/local/test/data';
  $dir_cgi	= '/usr/local/test/cgi-bin';
  $sql_database = 'test';
  $sql_u_www	= 'test_www';
  $sql_u_kern	= 'test_kernel';
  $make_backup	= 0;
}
# === end test ===

map{ s|/$|| } ($dir_nodeny,$dir_www,$dir_cgi);
$installer_str="[ND Installer] ";

# === subs ===

sub LogOnly
{
 print LOG $_[0];
}

sub Log
{
 print LOG $_[0];
 print $_[0];
}

sub Exit
{
 $_[0] && &Log("$_[0]\n\n");
 $status or &Log("\nNO CHANGES MADE\n\n");
 exit;
}

sub Debug
{
 &Log("$installer_str$_[0]\n");
}

sub System
{
 &Log("[SYSCALL] $_[0]\n");
 my $ret=system($_[0]);
 &LogOnly("[SYSCALL REZ=$ret]\n");
 return $ret;
}

sub sql
{
 &Log("[SQL] $_[0]\n");
 return ($dbh->prepare($_[0]));
}

sub sql_do
{
 &Log("[SQL] $_[0]\n");
 return ($dbh->do($_[0]));
}

sub Ask
{
 my($ask,$type,$p)=@_;
 my $s;
 if( $type==1 )
 {
    $ask=$installer_str.$ask.' [y/n]: ';
 }
  elsif( $type<=3 )
 {
    $ask=$installer_str.$ask.' '.(!!$p && "[$p]").': ';
 }

 while(1)
 {
    &Log($ask);
    $s=<STDIN>;
    print LOG $s;
    chomp $s;
    $s=~s|^ +||;
    $s=~s| +s||;
    $type or return($s||$p);
    if( $type==1 )
    {
       $s=~/^(1|y|yes)$/i && return 1;
       $s=~/^(0|n|no)$/i && return 0;
       &Log("Please enter `y` for yes or `n` for no.\n");
       next;
    }
    if( $type<=3 )
    {
       $s=~s|/$||;
       ($s eq '') && return $p;
       if ($s=~/^(y|yes|n|no)$/i) {&Log("No `yes` or `no`, need path\n"); next}
       ($type!=3 || (-d $s)) && return $s;
       &Log("Directory `$s` does not exist.\n");
       next;
    }
 }
}

sub history
{
 $_=$_[1];
 s|'|\\'|g;
 s|\\|\\\\|g;
 $history.='$'.$_[0]."='$_';\n";
}
# === start ===

$status=0;
$history="# DO NOT EDIT\n# DO NOT DELETE\n";

$t=localtime();
$logfile=sprintf("$dir/UPDATE_LOG_%02d.%02d.%04d_%02d.%02d.%02d.txt",$t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min,$t->sec);
unless(open(LOG,">$logfile"))
{
   print "Error creating a log file `$logfile`!\nNO CHANGES MADE\n\n";
   exit;
}

print "\n\nNoDeny Installer. Ver $VER.\n\n";
$s=&Ask("Select the action:".
   "\n\t"."  1) Install".
   "\n\t"."  2) Upgrade".
   "\n\t"."any) Exit".
   "\n"."Your choice",0,'');
$s=~/^[1|2]$/ or &Exit("\nBye");
$do_install=2-$s;

$dir_nodeny=&Ask("nodeny dir",$do_install? 2:3,$dir_nodeny);
($dir_nodeny eq $dir) && &Exit("If you want to install into `$dir` you need to move the installation to another directory");

$file_history="$dir_nodeny/$file_history";

%deny_files=(# don't copy:
  'install.pl'	=> 1,
  'bill.sql'	=> 1,
);

$is_dir_nodeny=(-d $dir_nodeny);

if( $do_install )
{
   if( $is_dir_nodeny )
   {
      &Ask("$dir_nodeny exists. Probably you need to upgrade it. Are you sure NoDeny need to be installed?",1)
         or &Exit("Run install again");
   }
}# upgrade
 elsif( !$is_dir_nodeny )
{
   &Exit("Directory `$dir_nodeny` does not exist.");
}
 else
{  # upgrade. Don't copy:
   $deny_files{$_}=1 foreach('nodeny.cfg.pl','nodeny.cfg','sat.cfg','netflow.txt');
   $sql_database=$1 if `grep Db_name $dir_nodeny/nodeny.cfg`=~/^\s*\$Db_name\s*=\s*'([^']+)'\s*;/;
   if( -e $file_history )
   {
      eval{require $file_history};
   }
    else
   {
     &Debug("$file_history is not found. Norm)\n");
   }
}

$dir_www=&Ask('www dir',3,$dir_www);
&history('dir_www',$dir_www);
$dir_www.='/i';
$dir_cgi=&Ask('cgi-bin dir',3,$dir_cgi);
&history('dir_cgi',$dir_cgi);
$dir_cgi_adm="$dir_cgi/adm";
if( !$do_install && !(-e "$dir_cgi_adm/adm.pl") )
{
   &Ask("`$dir_cgi_adm` does not look like NoDeny cgi-bin directory. Continue?",1) or &Exit("\nBye");
}

while(1)
{
   $sql_server=&Ask('mysql server',0,$sql_server);
   $sql_root_pass=&Ask('mysql root password',0,$sql_root_pass);
   $DSN="DBI:mysql:database=mysql;host=$sql_server;mysql_connect_timeout=3;";
   $dbh=DBI->connect($DSN,'root',$sql_root_pass,{PrintError=>1});
   $dbh && last;
   &Debug("\n\nError connecting to DB\n");
}

$dbh->do("SET character_set_client=cp1251");
$dbh->do("SET character_set_connection=cp1251");
$dbh->do("SET character_set_results=cp1251");

&history('sql_server',$sql_server);
&history('sql_root_pass',$sql_root_pass);

if( $is_dir_nodeny && $make_backup )
{
   &Debug("Making a files backup");
   $file=sprintf("BACKUP_ND_%02d.%02d.%04d_%02d.%02d.%02d.tar",$t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min,$t->sec);
   &System("tar -c -f $file $dir_nodeny");
   if( -e $file )
   {
      &System("tar -r -f $file $dir_cgi_adm") if -e $dir_cgi_adm;
      &System("tar -r -f $file $dir_www") if -e $dir_www;
   }
    else
   {
      &Ask("Error creating backup. Continue?",1) or &Exit("\nBye");
   }
}

$file='nodeny/bill.sql';
open(F,"<$file") or &Exit("Error openning `$file`!");
@lines=<F>;
close(F);

$sql_database=&Ask('NoDeny database',0,$sql_database);
&history('sql_database',$sql_database);

if( $do_install )
{
   $DSN="DBI:mysql:database=$sql_database;host=$sql_server;mysql_connect_timeout=3;";
   $dbh2=DBI->connect($DSN,'root',$sql_root_pass,{PrintError=>0});
   if( $dbh2 )
   {
      &Ask("Database `$sql_database` exists. Continue?",1) or &Exit("\nBye");
      $dbh2->do("SET character_set_client=cp1251");
      $dbh2->do("SET character_set_connection=cp1251");
      $dbh2->do("SET character_set_results=cp1251");
   }
    else
   {
      $dbh->do("CREATE DATABASE $sql_database") or &Exit("Error creating database `$sql_database`");
   }
   $status=1;
   @f=(
     [$sql_u_www,$sql_p_www, $sql_u_www_ip, 'nodeny www user in mysql', ''],
     [$sql_u_kern, $sql_p_kern, $sql_u_kern_ip, 'nodeny kernel user in mysql', ',CREATE,DROP,INDEX']
   );
   $mess_err="SQL ERROR.";
   while( $f=shift @f )
   {
      ($u,$p,$i,$m,$d)=@$f;
      $u=&Ask("$m (`no` - do not create)",0,$u);
      next if $u=~/^ *no *$/;
      $p=&Ask("Password for $m",0,$p);
      $i=&Ask("Ip of $m",0,$i);
      $u=~s/\\/\\\\/;
      $u=~s/'/\\'/;
      $p=~s/\\/\\\\/;
      $p=~s/'/\\'/;
      $i=~s/\\/\\\\/;
      $i=~s/'/\\'/;
      $sth=&sql("SELECT * FROM user WHERE User='$u' AND Host='$i'");
      if( $sth->execute && $sth->fetchrow_hashref )
      {
         &Ask("User exists in mysql. Continue?",1) or &Exit("\nBye");
      }
       else
      {
         &sql_do("CREATE USER '$u'\@'$i' IDENTIFIED BY '$p'") or &Exit($mess_err);
      }
      &sql_do("GRANT USAGE ON *.* TO '$u'\@'$i' IDENTIFIED BY '$p'") or &Exit($mess_err);
      &sql_do("GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE$d ON `$sql_database`.* TO '$u'\@'$i'") or &Exit($mess_err);
   }
}

$DSN="DBI:mysql:database=$sql_database;host=$sql_server;mysql_connect_timeout=3;";
$dbh=DBI->connect($DSN,'root',$sql_root_pass,{PrintError=>1});
$dbh or &Exit("\n\nError connecting to DB $sql_database\n");
$dbh->do("SET character_set_client=cp1251");
$dbh->do("SET character_set_connection=cp1251");
$dbh->do("SET character_set_results=cp1251");

$tbl_version=0;
if( !$do_install )
{
   $sth=&sql("SELECT data FROM files WHERE name='tbl_version'");
   if( $sth->execute && ($p=$sth->fetchrow_hashref) )
   {
       $tbl_version=$p->{data};
       $tbl_version=~/^(\d+)$/ or &Exit("\n\nIcorrect table version `$tbl_version`!\n");
   }
    else
   {
       $sth=&sql("SHOW TABLE STATUS LIKE 'admin'");
       ($sth->execute && ($p=$sth->fetchrow_hashref)) or &Exit("Sql Error!");
       $p->{Comment}=~/^rev_(\d+)$/ or &Exit("\n\nYou have very old version NoDeny. Upgrade it to >= 49.03 (50.03)\n");
       $tbl_version=49;
   }
   &Log("tbl_version=$tbl_version");
}

&Log("\nCreating/Updating tables...\n\n");

push @lines,'#0';
$cod='';
$type='sql';
$ver=0;
foreach $line (grep {!/^\s*$/} @lines)
{
   if( $line=~/^#([^\d\s]+)/ )
   {
       $type=$1;
       next;
   }
   if( $line!~/^#\s*(\d+)/ )
   {
       $cod.=$line;
       next;
   }
   $new_ver=$1;

   if( $tbl_version < $ver )
   {
      $status=1;
      if( $type eq 'sql' )
      {
         &sql_do($cod) or &Exit("Sql Error!");
      }
       elsif( $type eq 'perl' )
      {
         $cod.="\n1;\n";
         $f="$dir/tmp_$ver.pl";
         open(F,">$f") or &Exit("Error creating gile `$f`");
         print F $cod;
         close(F);
         require $f;
      }
       else
      {
         &Exit("Error a code type `$type` in $file")
      }

      &sql_do("UPDATE files SET data='$ver' WHERE name='tbl_version'")>0 or
         &sql_do("INSERT INTO files SET data='$ver', name='tbl_version'")>0 or
         &Exit("Sql Error!");
      &Log("\n");
   }
   $ver=$new_ver;
   $cod='';
   $type='sql';
}
&Log("\n");

$status=1;

if( !$do_install )
{
   $file="$dir/updates/update_config.pl";
   if( open(F,"<$file") )
   {
      $add_lines=join '',<F>;
      close(F);
      $file="$dir_nodeny/nodeny.cfg.pl";
      if( (-e $file) && open(F,">>$file") )
      {
         print F "$add_lines\n1;\n";
         close(F);
      }
       else
      {
         &Ask("Error openning `$file` for save. Continue?",1,'n') or &Exit("\nBye");
      }
   }
    else
   {
      &Ask("Error openning `$file`. Continue?",1,'n') or &Exit("\nBye");
   }
}

while(1)
{
   $www_u=&Ask("www user (web server user)",0,$www_u);
   &history('www_u',$www_u);
   &System("chown $www_u cgi-bin/adm.pl") or last;
   $s=&Ask("Probably no such user like `$www_u`.\n 1) Continue\t2) Enter new name\tany) Exit\t",0,'');
   $s==1 && last;
   $s==2 && next;
   &Exit("\nBye");
}

%dirs=(
  'cgi-bin'	=>	"$dir_nodeny/web",
  'data'	=>	$dir_www,
  'satellites'	=>	$dir_nodeny,
  'nodeny'	=>	$dir_nodeny,
  'satellites/rc.d' =>	"$dir_nodeny/rc.d",
);

@mk_dir=(
   $dir_cgi_adm,
   "$dir_www/upload",
   "$dir_nodeny/sql",
   "$dir_nodeny/web",
   "$dir_nodeny/rc.d",
);

# many dirs mkpath has a bug (?)
foreach $d (@mk_dir)
{
   mkpath($d, {error=>\$err, verbose=>1, mode=>0700});
   (@$err) or next;
   for $diag (@$err)
   {
      ($dir, $message) = %$diag;
      &Exit("[MKPATH] directory `$dir`: $message");
   }
}

foreach $src_dir (keys %dirs)
{
   opendir(DIR,$src_dir) or &Exit("[ERROR] can't opendir `$src_dir`: $!");
   map{ $files{"$src_dir/$_"}="$dirs{$src_dir}/$_" } grep {-f "$src_dir/$_" && !$deny_files{$_}} readdir(DIR);
   closedir DIR;
}   

$files{'cgi-bin/adm.pl'}="$dir_cgi_adm/adm.pl";
$files{'cgi-bin/stat.pl'}="$dir_cgi_adm/stat.pl";
$files{"$dir/cgi-bin/stat.pl"}="$dir_cgi/stat.pl";

foreach $src (keys %files)
{
   $dst=$files{$src};
   &Debug("Copy $src -> $dst");
   copy($src,$dst) or &Exit("[ERROR] Copy failed: $!");
}

@coms=(
  "chown $www_u:wheel $dir_nodeny",
  "chown root:wheel $dir_nodeny/sql",
  "chown root:wheel $dir_nodeny/rc.d",
  "chown -R $www_u:wheel $dir_nodeny/web",
  "chown root:wheel $dir_nodeny/sat.cfg",
  "chown $www_u:wheel $dir_nodeny/nomoney.pl",
  "chown $www_u:wheel $dir_nodeny/nodeny.cfg.pl",
  "chmod 700 $dir_nodeny/rc.d",
  "chmod 700 $dir_nodeny/sql",
  "chmod 500 $dir_nodeny/web",
  "chmod 400 $dir_nodeny/web/*",
  "chmod 500 $dir_nodeny/ipcad.pl",
  "chmod 500 $dir_nodeny/ipacct.pl",
  "chmod 500 $dir_nodeny/ipacct.sh",
  "chmod 500 $dir_nodeny/netflow.pl",
  "chmod 500 $dir_nodeny/rc.d/*",
  "chmod 500 $dir_nodeny/go.sh",
  "chmod 500 $dir_nodeny/backup_nodeny.sh",  
  "chmod 600 $dir_nodeny/nodeny.cfg.pl",
  "chmod 400 $dir_nodeny/nodeny.pl",
  "chmod 500 $dir_nodeny/nocheck.pl",
  "chmod 400 $dir_nodeny/noserver.pl",
  "chmod 400 $dir_nodeny/sat.cfg",
  "chown -R $www_u:wheel $dir_cgi_adm",
  "chmod 500 $dir_cgi_adm",
  "chmod 500 $dir_cgi_adm/adm.pl",
  "chmod 500 $dir_cgi_adm/stat.pl",
  "chown $www_u:wheel $dir_cgi/stat.pl",
  "chmod 500 $dir_cgi/stat.pl",
  "chown -R $www_u:wheel $dir_www",
  "chmod 700 $dir_www/upload",
);

(-e "$dir_nodeny/nodeny.log") && push @coms,(
  "chmod 600 $dir_nodeny/nodeny.log",
  "chown $www_u:wheel $dir_nodeny/nodeny.log"
);

foreach (@coms)
{
   &System($_);
}

$history.="1;\n";
if( open(F,">$file_history") )
{
   print F $history;
   close(F);
}

$h=time().int(rand()*10**10);
$h=qq(sub rand_num { return $h });
$do_install && &System("echo $h >> $dir_nodeny/nodeny.pl ");

$h=qq(sub get_main_config { \\\$Main_config=\\'$dir_nodeny/nodeny.cfg.pl\\' });

&System("echo $h >> $dir_cgi_adm/adm.pl");
&System("echo $h >> $dir_cgi_adm/stat.pl");
&System("echo $h >> $dir_cgi/stat.pl");

&Log("\n==============================\n".
       "NoDeny has been Installed. OK!\n\n");

