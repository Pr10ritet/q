#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub KV_main
{
 &LoadDopdataMod;

 $f="$Nodeny_dir_web/kvit.html";
 open(FL,"<$f") or &Error($V? "$V Не найден шаблон для квитанций ".&Filtr_out($f) : $Er_Mess_for_Client, $EOUT);
 $out='';
 $out.=$_ while(<FL>);
 close(FL);

 # Персональный платежный код
 $csum=0;
 $csum+=$_ foreach split //,$Mid;
 $csum%=10;
 $account="$Mid$csum";

 %f=(
   1 => $U{$Mid}{o_fio},
   2 => $account,
   4 => $pm->{contract},
 );

 $out=~s/<(\d+)>/$f{$1}/g;

 $sth=&sql($dbh,"SELECT * FROM dopdata WHERE parent_type=0 AND parent_id=$Mid");
 while( $h=$sth->fetchrow_hashref )
 {
    $field_alias=$h->{field_alias};
    $field_value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $h->{field_type},
          alias	=> $field_alias,
          value	=> $h->{field_value}
       })
    );
    $field_alias='_adr_street' if $field_alias eq 'p_street:street:name_street';
    $out=~s/<dopdata-$field_alias>/$field_value/g;
 }

 print "Content-type: text/html\n\n".$out;
 exit;
}

1;      
