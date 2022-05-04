#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nDopdataAPI');
$nDopdata_loaded=1;

use strict;

# ======================================================
# ����� �� ��������� ����� � �������������� ������
#  parent_type	 0 - ������ �������, 1 - ������������
#  template_num  0 - ����� ������ ������
#  data		 ������ �� ���: 'id ����'=>'��� ����'
# �������:
#  sql ������ (��� SELECT *)
# ------------------------------------------------------
# ������: � ������� 105, ����� ������������, � �������� �������� ����� ����� ��������='123456'
# �������������� ����������� �������� id ���� `�������� �����` � ������� �������� ����� dopfields
# ��������, ��� = 3
#  $sql='SELECT * '.&nDopdata_search({
#    parent_type	=> 1,
#    template_num	=> 105,
#    data		=> {3 => '123456'}
# });
# ======================================================
sub nDopdata_search
{
 my $p=shift @_;
 my $parent_type=int $p->{parent_type};
 my $template_num=int $p->{template_num};
 my $sort_id=abs int $p->{sort_id};
 $p=$p->{data};
 my $where="SELECT parent_id AS id FROM dopdata WHERE parent_type=$parent_type";
 $where.=" AND template_num=$template_num" if $template_num;
 foreach my $id( sort{ ($a==$sort_id) <=> ($b==$sort_id) } map{ int $_ } keys %$p )
 {
    my $value=&Filtr_mysql($p->{$id});
    $where="SELECT parent_id AS id FROM dopdata WHERE parent_id IN ($where) AND id=$id AND field_value LIKE '$value'";
 }
 return $where;
}


sub nDopdata_print_value
{
  my ($alias,$h,$h_tbl,$h_num,$h_descr,$p,$type,$value);
  our @Owner_types;
  our $dbh;
  $h=shift @_;
  $type=$h->{type};
  $alias=$h->{alias};
  $value=$h->{value};
  $type<=5 && return $value;
  $type==6 && return $value? '��' : '���';
  $type==7 && return '�������� � ������� '.($Owner_types[int $value] || '???');
  if( $type==8 )
  {# ���������� ������
     $alias=~/^([^:]+):([^:]+):([^:]+)$/ or return '������ � ���������� ����!';
     ($h_tbl,$h_num,$h_descr)=($1,$2,$3);
     $h_tbl=&Filtr($h_tbl);
     $h_num=&Filtr($h_num);
     $h_descr=&Filtr($h_descr);
     $alias='';
     $p=nSql->new({
       dbh	=> $dbh,
       sql	=> "SELECT $h_descr FROM $h_tbl WHERE $h_num='$value' LIMIT 1",
       show	=> 'line',
       comment	=> 'nDopdataAPI.pl',
       ret	=> { $h_descr => \$alias}
     });
     return $p->{ok}? $alias : '';
  }
  $type==9 && return '***';
  return '???';
}

1;      
