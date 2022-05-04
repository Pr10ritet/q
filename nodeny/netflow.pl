#!/usr/bin/perl

# Вход:
# 0 - порт
# 1 - название файла

$flow_base='/var/db/flows/';
$nodeny_base='/usr/local/nodeny/';
$flow_capture_pid='/var/run/flow-capture/flow-capture.pid';

$flow_print=`which flow-print` || '/usr/local/bin/flow-print';
$flow_export=`which flow-export` || '/usr/local/bin/flow-export';
$cat=`which cat` || '/bin/cat';

chomp $flow_print;
chomp $flow_export;
chomp $cat;

$flow_base=~s/\/$//;
$nodeny_base=~s/\/$//;

($port,$file_name)=@ARGV;
$port=~s/\s+//g;

if ($port=~/(\d+):(.+)$/)
  {# для данного сенсора известен номер внешнего интерфейса
   $out_int=",$2,";
   $port=$1;
  }else
  {
   undef $out_int;
   $port=int $port;
  }

$flow_file=$flow_base.'/$ARGV[0]';
$file_pl="$nodeny_base/netflow_$port.pl";


exit unless open(F,">$file_pl");

{
 $n="\n";
 unless (defined $out_int)
   {
    print F qq{#!/usr/bin/perl$n}.
      qq{ system("$flow_print -f6 < $flow_file >$file_name 2>/dev/null");$n}.
      qq{ unlink "$flow_file";$n};
    last;
   }

 $script="#!/usr/bin/perl".$n.
   "\$lines=`$flow_export -f2 -mdoctets,srcaddr,dstaddr,input,output,srcport,dstport,prot < $flow_file 2>/dev/null`;".$n.
   "\$out_int='$out_int';".$n.
   '$out="";'.$n.
   'foreach $line (split /\n/,$lines)'.$n.
   ' {'.$n.
   '  ($bytes,$src,$dst,$src_if,$dst_if,$src_port,$dst_port,$prot)=split /,/,$line;'.$n.
   '  next if $prot<1;'.$n.
   '  $h="$src\t$dst\t1\t$bytes\t$src_port\t$dst_port\t$prot\t";'.$n.
   '  $out.=$h."2\n" if $out_int=~/,$src_if,/;'.$n.
   '  $out.=$h."1\n" if $out_int=~/,$dst_if,/;'.$n.
   ' }'.$n.
   "exit unless open (F,'>${file_name}_temp');".$n.
   'print F $out;'.$n.
   'close(F);'.$n.
   "rename '${file_name}_temp','$file_name';".$n.
   "unlink \"$flow_file\";".$n;
 print F $script;
}

close (F);
chmod 0700,$file_pl;

kill 1,`$cat $flow_capture_pid.$port`;

exit;

