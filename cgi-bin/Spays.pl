#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub PY_main
{
 $out='';
 $sql="SELECT * FROM pays WHERE mid=$Mid AND type IN (10,20) ORDER BY time DESC";
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,20,$scrpt);
 unless ($rows)
   {
    &Message("������� ��� ����� ������� ������ �����������.");
    return;
   }
 while ($p=$sth->fetchrow_hashref)
   {
    $coment=&Show_all($p->{coment});
    $coment=($p->{type}==20? "<span class=data1>��������� ������</span>. ���� ��������: ����� ".&the_time($p->{time}).'<br>' :
       $p->{bonus} && "<span class=data1>������".($coment!~/^\s*$/ && ': ').'</span>').$coment;
    $time=$p->{time};
    $tt=&the_short_time($time,$t);
    unless ($out)
      {# �������� ������ � ������� ������, ��� ����� ������ ��-�� ������� ���������
       $h=&sql_select_line($dbh,"SELECT SUM(cash) FROM pays WHERE mid=$Mid AND type IN (10,20) AND time<=$time",'������ � ������� ������');
       $balance=$h? $h->{'SUM(cash)'} : 0;
      }
    $cash=$p->{cash};
    $money=sprintf("%.2f",$cash)+0;
    $out.=&RRow('*','rrrrll',
      $tt,
      $money>0 && $money,
      $money<0 && -$money,
      sprintf("%.2f",$balance)+0,
      $coment,
      !!$Adm{id} && &div('nav3',&ahref("$Script_adm&a=pays&act=show&id=$p->{id}",'��������� &rarr;'))
    );
    $balance-=$cash;
   }
 $page_buttons&&=&RRow('head',6,$page_buttons);
 $OUT.=&Table('tbg3',
   &RRow('head',6,&bold_br('������� ��������')).
   $page_buttons.
   &RRow('tablebg','cccccc','�����',"������, $gr","������, $gr","������� �� �����, $gr",'�����������','').
   $out.
   $page_buttons
 );
}

1;      
