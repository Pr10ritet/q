#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$pr_SuperAdmin or &Error('Доступ только суперадину');


$out='';
($sql,$page_buttons,$rows,$sth)=&Show_navigate_list("SELECT * FROM radlog ORDER BY time DESC",$start,50,$scrpt);
$page_buttons&&=&RRow('tablebg',2,$page_buttons);

while ($p=$sth->fetchrow_hashref)
  {
   $out.=&RRow('*','ll',$p->{time},&Filtr_out($p->{mess}))
  }

$OUT.=&Table('tbg3 nav3 width100',
   &RRow('head',2,&bold_br('История неудачных логинов')).
   $page_buttons.
   &RRow('tablebg','cc','Время','Комментарий').
   $out.
   $page_buttons
 );
1;
