#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use Net::hostent;

sub TN_main
{
 $addr=$F{addr};
 $addr=~s|\s||g;
 $addr=$2 if $addr=~m|(.+://)?([^/]+)|; # выудим адрес из строки вида http://xxxx/
 $OUT.=&MessX(&div('cntr',
    &form( '!'=>1,'#'=>1,$Lang_stestnet_ask_addr.$br2.&input_t('addr',$addr,40,60).$br2.&submit_a($Lang_btn_go_next) )
 ),1,1);

 $addr or return;

 $iptest=gethostbyname($addr);
 $iptest or &Error(&Printf($Lang_stestnet_err_resolve,$addr),$EOUT);
 $iptest=inet_ntoa($iptest->addr);
 $addr=$addr ne $iptest? "$addr ($iptest)" : $iptest;

 $nNetfile="$Nodeny_dir_web/nNet.pl";
 eval{require $nNetfile};
 $@ && &Error($V? "$V $Lang_cannot_load_file $nNetfile" : $Er_Mess_for_Client,$EOUT);
 ($nets,$err_mess)=&nNet_NetsList; # ссылка на массив со списком сетей
 $err_mess && &Error($V? "$V $Lang_smsadm_err_nets. $err_mess" : $Er_Mess_for_Client,$EOUT);

 $preset=$U{$Mid}{preset};
 ($i1,$i2,$i3,$i4)=split(/\./,$iptest);
 $ip_raw=pack('CCCC',$i1,$i2,$i3,$i4);

 $port=0;
 $out=$rezult='';
 foreach $i (@{$nets->{$preset}})
 {
    $ok=($ip_raw & $i->{mask}) eq $i->{net};
    $name_direction=($Lang_stestnet_0_dir_traf,&Get_Name_Class($preset))[$i->{class}];
    $net='&nbsp;&nbsp;'.(join '.',unpack("C4",$i->{net}))."/$i->{masklen}";
    $out.=&RRow('*','llllc',$name_direction,&Filtr_out($i->{comment}),$net,$i->{port}||'&nbsp;',$ok && &bold('ДА'));
    $ok or next;
    $port=$i->{port};
    $rezult.='<li>'.&bold($name_direction).(!!$port && ", $Lang_stestnet_if_port $port").($i->{dynamic} && '. '.$Lang_stestnet_dynamic_net).'</li>';
    $port or last;
 }

 if( !$rezult || $port )
 {
    # если ip не сопоставлен ни с какой сетью, класс будет таким:
    $cls=($i1>223 && $i1<240) || $i1==127 || $ip eq '255.255.255.255'? 0:1;
    $rezult.='<li>'.&bold(($Lang_stestnet_0_dir_traf,&Get_Name_Class($preset))[$cls]).'</li>';
 }
 
 if( $V )
 {
    $out=$br.&ahref('javascript:show_x("addr")',$Lang_smsadm_not_for_u).$br.
       &div("message' id=my_x_addr style='display:none",
         &Printf($Lang_stestnet_use_preset,$Plan_name_short[$U{$Mid}{paket}],$preset).$br2.
         &Table('tbg1',&RRow('head','ccccc',@Lang_stestnet_tbl_header).$out)
       ).$br;
 }else
 {
    $out='';
 }

 $OUT.=&div('message lft',"$out $addr: <ul>$rezult</ul>");
}

1;      
