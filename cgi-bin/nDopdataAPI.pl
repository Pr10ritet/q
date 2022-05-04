#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nDopdataAPI');
$nDopdata_loaded=1;

use strict;

# ======================================================
# Поиск по значениям полей в дополнительных данных
#  parent_type	 0 - данные клиента, 1 - оборудование
#  template_num  0 - любая группа данных
#  data		 ссылка на хеш: 'id поля'=>'что ищем'
# Возврат:
#  sql запрос (без SELECT *)
# ------------------------------------------------------
# Пример: в шаблоне 105, найти оборудование, у которого серийный номер имеет значение='123456'
# Предварительно необъходимо выяснить id поля `серийный номер` в таблице описания полей dopfields
# Допустим, оно = 3
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
  $type==6 && return $value? 'да' : 'нет';
  $type==7 && return 'привязка к объекту '.($Owner_types[int $value] || '???');
  if( $type==8 )
  {# выпадающий список
     $alias=~/^([^:]+):([^:]+):([^:]+)$/ or return 'ошибка в настройках поля!';
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
