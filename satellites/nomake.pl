#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Агент создания конфигов для внешних программ
# ---------------------------------------------
$VER=50.33;

use Fcntl qw(:flock);
use FindBin;
use DBI;

$AgentName	= 'nomake';
$Mod_id		= 3; # id агента = `агент nomake`

# === Start загрузчика nosat.pl ====
# После изменения, скопировать в другие агенты

$Program_dir=$FindBin::Bin;
$satmod="$Program_dir/nosat.pl";
eval{require $satmod};
if( $@ )
{
   print "Need $satmod!\n";
   exit 1;
}

# === End загрузчика nosat.pl ====


$conditions='net|ip|mac';

$Config_in=shift @ARGV;
$Config_in or &Error("Usage:  $0 [-v] configfile\n\n");

$Config_in="$Program_dir/$Config_in" if $Config_in!~/^\//;
$Logfile="$Config_in.log";

&Log("Starting NoMake script");

$Where_grp=$c{Usr_nosrvr_groups}? " AND grp IN($c{Usr_nosrvr_groups})" : '';

open(F,"<$Config_in") or &Error("Error openning $Config_in!");
$config_in=join '',<F>;
close(F);

$err1="Ошибка в шаблон-файле $Config_in:";

$config_in=~s/\000-\003//g;
$config_in=~s/\\</\000/g;
$config_in=~s/\\>/\001/g;
$config_in=~s/\\'/\002/g;
$config_in=~s/\\(.)/$1/g;

$config_in=~s/<file>(.+)<\/file>\n?//igs or &Error("$err1 не указано имя выходного файла (тег <file>)");
$Config_out=$1;
$Config_out="$Program_dir/$Config_out" if $Config_out!~/^\//;
$Reload_com=$config_in=~s/<reload>(.+)<\/reload>\n?//igs? $1 : '';
$Template_num=$config_in=~s/<template>(\d+)<\/template>\n?//igs? $1 : 1;

# разобъем файл-шаблон на блоки, к которым применяются фильтры
($no_filtr_block,@blocks)=split /<filtr/,$config_in;

@b=();
push @b,['',$no_filtr_block] if $no_filtr_block;
foreach $i (@blocks)
{
   $i=~/^(.*)<\/filtr>(.*)$/s or &Error("$err1 нет тега </filtr>");
   ($filtr_block,$no_filtr_block)=($1,$2);
   $filtr_block=~/^([^>]*)>(.*)/s or &Error("$err1 `<filtr` не закрыт символом `>`");
   ($filtrs,$body)=($1,$2);
   %filtrs=();
   while( $filtrs=~s/^ *([^= ]+) *= *'([^']*)'// )
   {
       ($cod,$data)=($1,$2);
       if( $cod eq 'net' )
       {
           $data=~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ or &Error("$err1 некорректно задан фильтр net: $data");
           $net_mask=$5;
           $net_ip_raw=pack('CCCC',$1,$2,$3,$4);
           $net_mask_raw=pack('B32',(1 x $net_mask),(0 x (32-$net_mask)));
           (($net_ip_raw & $net_mask_raw) ne $net_ip_raw) && &Error("$err1 некорректно задана маска сети либо сеть в фильтре net: $data");
           $filtrs{net}={ 'net_ip_raw'=>$net_ip_raw, 'net_mask_raw'=>$net_mask_raw, 'net'=>$data };
       }
        else
       {
           $data=~s/\000/</g;
           $data=~s/\001/>/g;
           $data=~s/\002/'/g;
           $filtrs{$cod}=$data;
       }
   }
   $filtrs=~/^\s*$/ or &Error("$err1 некорректно оформлен тег <filtr>, формат такой: <filtr условие='данные условия' условие='данные условия'>");
   $temp={}; # нужен этот фокус чтобы каждый раз создавался новый хеш
   %$temp=%filtrs;
   push @b,[$temp,$body];
   push @b,['',$no_filtr_block] if $no_filtr_block;
}

push @b,['',''] if $#b<0;

$When_Form_Config=0;	# когда формировать конфиг, сейчас же
$t_reload_users=30;	# с каким периодом проверять стоит ли его обновлять
$t_stat=0;		# Время когда необходимо записать в базу статистику о ходе работы агента, сейчас же
$last_out='';
$Report='';

while(1)
{
   sleep 2;
   $t=&TimeNow();
   $t>$When_Form_Config && &Form_Config;
   $t>$t_stat && &SendAgentStat;
   $Exit_reason && last;
}

&Exit;

sub filtr
{
 local $_=shift;
 tr|\x00-\x1f||;
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|\r||g;
 return($_);
}

sub lc_rus
{
 local $_=shift;
 tr/ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁІЇЄ/йцукенгшщзхъфывапролджэячсмитьбюёіїє/;
 return($_);
}

sub translit
{
 local $_;
 my %tr=(
  'а'=>'a', 'б'=>'b', 'в'=>'v', 'г'=>'g', 'д'=>'d', 'е'=>'e', 'ё'=>'yo', 'ж'=>'zh', 'з'=>'z', 'и'=>'i',
  'й'=>'y', 'к'=>'k', 'л'=>'l', 'м'=>'m', 'н'=>'n', 'о'=>'o', 'п'=>'p', 'р'=>'r', 'с'=>'s', 'т'=>'t',
  'у'=>'u', 'ф'=>'f', 'х'=>'h', 'ц'=>'c', 'ч'=>'ch', 'ш'=>'sh', 'щ'=>'sh', 'ъ'=>'j', 'ы'=>'i', 'ь'=>'j',
  'э'=>'e', 'ю'=>'yu', 'я'=>'ya',
 );
 my $s='';
 $s.=$tr{$_}||$_ foreach (split //, &lc_rus(shift));
 return $s;
}

sub Form_Config
{
 $When_Form_Config=&TimeNow()+$t_reload_users;
 $sql="$SQL_BUF id,ip,name,state,auth,AES_DECRYPT(passwd,'$Passwd_Key') FROM $c{Db_usr_table} ${Where_grp}ORDER BY id";
 $sth=&sql($sql);
 $sth or return;

 @out=();
 foreach (0..$#b)
 {
    @out[$_]=$b[$_]->[1] unless $b[$_]->[0];
 }
 $ok=0;
 while( $p=$sth->fetchrow_hashref )
 {
    $ok++;
    %f=( 'id'=>$p->{id}, 'ip'=>$p->{ip}, 'state'=>$p->{state}, 'auth'=>$p->{auth} );
    $ip_raw=pack('CCCC', split /\./,$f{ip});
    $f{login}=$p->{name};
    &Debug("=== id: $f{id} === $f{ip} === $f{login} ===");
    $f{pass}=$p->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
    $f{lat_login}=&translit($f{login});

    $sql="SELECT field_alias,field_value FROM dopdata WHERE parent_type=0 AND parent_id=$f{id}";
    &Debug($sql);
    $sth2=$dbh->prepare($sql);
    if( $sth2->execute )
    {
       while( $h=$sth2->fetchrow_hashref )
       {
          $f{'dopdata-'.$h->{field_alias}}=$h->{field_value};
          &Debug('DOPDATA: '.$h->{field_alias}.' = '.$h->{field_value});
       }
    }

    foreach $i (0..$#b)
    {
       &Debug("BLOCK $i");
       $_=$b[$i]->[0];
       $_ or next;
       %filtrs=%$_;
       $catch=1;
       foreach $filtr (keys %filtrs)
       {
          if( $filtr eq 'net' )
          {
             %net=%{ $filtrs{$filtr} };
             $v && print "Condition: net=$net{net}. Now: ip=$f{ip}. Rezult: ";
             if( ($ip_raw & $net{net_mask_raw}) eq $net{net_ip_raw} )
             {
                $v && print "yes\n";
             }else
             {
                $v && print "no\n";
                $catch=0;
             }
             next;
          }

          $h=$filtrs{$filtr};
          $v && print "Condition $filtr: $h\nNow $filtr: $f{$filtr}\nResult: ";
          if( $f{$filtr}=~/$h/ )
          {
             $v && print "yes\n";
          }else
          {
             $v && print "no\n";
             $catch=0;
          }
       }

       if( !$catch )
       {
           &Debug("Does not conform to the conditions");
           next;
       }
       &Debug("Conforms to the conditions\n");

       $body=$b[$i]->[1];
       foreach (keys %f)
       {
           $f{$_}=~s/(['"!\\])/\\$1/g;
           $body=~s/<$_>/$f{$_}/isg;
       }
       $out[$i].=$body;
    }
 }
 $out=join '',@out;

 $out=~s/\000/</g;
 $out=~s/\001/>/g;
 $out=~s/\002/'/g;

 if( !$ok )
 {  # перестраховка - если выборка нулевая - переконнектимся
    $dbh='';
    return;
 }

 if( $last_out ne $out )
 {
    $last_out=$out;
    &Debug("Записываем сформированный конфиг");
    if( open(F,">$Config_out") )
    {
       print F $out;
       close(F);
       system("chmod 400 $Config_out");
       $Report.=' Конфиг сформирован и записан.';
       $Reload_com && system("$Reload_com >/dev/null 2>/dev/null");
    }else
    {
       $Report.=' Конфиг сформирован, но ошибка записи.';
       &Log("Error saving into $Config_out !");
    }
 }
  else
 {
    &Debug("Выходной файл не записываем т.к он идентичен существующему");
 }
 $out='';
}

# =========================================
#      Запись статистики о ходе работы
# =========================================
sub SendAgentStat
{
 $t_stat=$t+$ReStat; # когда следующая статистика
 &SaveSatStateInDb($Report||'ok',0);
 $Report='';
}
