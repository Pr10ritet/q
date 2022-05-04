#!/usr/bin/perl
# ¬ход:
# 0 - сервер
# 1 - название файла

$ipacctctl="/usr/local/sbin/ipacctctl";

my ($dserver,$file_name,undef,$V)=@ARGV;

# перемещение текущих данных в checkpoint
system("$ipacctctl nod1:traf clear 2>/dev/null");
system("$ipacctctl nod2:traf clear 2>/dev/null");
system("$ipacctctl nod1:traf checkpoint 2>/dev/null");
system("$ipacctctl nod2:traf checkpoint 2>/dev/null");

$rez=$log='';
my @f=(
  'i','nod1',1,
  'o','nod1',2,
  'i','nod2',0,
);
while ($i=shift @f)
 {
  $nod=shift @f;
  $j=shift @f;
  foreach $line (split /\n/,`$ipacctctl -$i $nod:traf show`)
    {
     $log.="[$i $nod] $line\n" if $V;
     ($src,$src_port,$dst,$dst_port,$prot,$pkts,$bytes)=split /\s+/,$line;
      $s="$src\t$dst\t$pkts\t$bytes\t$src_port\t$dst_port\t$prot\t";
      $rez.="$s\t1\n" if $j<2;
      $rez.="$s\t2\n" if $j!=1;
     }
 }

$temp_name=$file_name.'_temp';
if (open F,">$temp_name")
  {
   print F $rez;
   close(F);
  }
rename $temp_name,$file_name;

# повторно обнулим буфер, чтобы гарантированно не посчитать трафик дважды - вдруг не сработает clear в след. раз
system("$ipacctctl nod1:traf clear 2>/dev/null");
system("$ipacctctl nod2:traf clear 2>/dev/null");

if ($V && open (F,">${file_name}_log"))
  {
   print F $log;
   close(F);
  }

exit;

