#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2009
# Read license http://nodeny.com.ua/license.txt
# Author: Nastenko Valentin, versus.ua@gmail.com
# History
# 18.02.2009 Created 
# 17.09.2009 Add dopdata support
# 18.10.2009 sbv: require mod -> &LoadDopdataMod
#		month names -> the language file
# ---------------------------------------------

sub DG_main
{
 &LoadDopdataMod;

 $f="$Nodeny_dir_web/dogovor.html";
 open(FL,"<$f") or &Error($V? "$V $Lang_cannot_load_file ".&Filtr_out($f):$Er_Mess_for_Client,$EOUT);
 $out='';
 $out.=$_ while(<FL>);
 close(FL);

 $year_dog=$year_now + 1900;

 %Dog = (
    day			=> $day_now,		# ������� ����
    mon			=> $Lang_month_names_for_day[$mon_now],	# ������� �����
    year		=> $year_dog,		# ������� ��� (�� 1970!)
    fio_clienta		=> $U{$Mid}{o_fio},
    login		=> $U{$Mid}{o_name},
    ip			=> $U{$Mid}{ip},
    contract		=> $pm->{contract},
 );

 $h=nSql->new({
     dbh		=> $dbh,
     sql		=> "SELECT * FROM dopdata WHERE parent_type=0 AND parent_id=$Mid",
     show		=> 'full',
     comment		=> '��� ������ ������� �� ��������� ��������',
 });

 while( $h->get_line( {field_alias => \$field_alias, field_value => \$field_value, field_type => \$field_type} ) )
 {
     $field_value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $field_type,
          alias	=> $field_alias,
          value	=> $field_value
       })
     );
     $Dog{$field_alias}=$field_value;
     $Dog{_adr_street}=$field_value if $field_alias eq 'p_street:street:name_street';
  }

 $out=~s/{{(\w+)}}/$Dog{$1}/g;
 print "Content-type: text/html\n\n$out";
 exit;
}

1;
