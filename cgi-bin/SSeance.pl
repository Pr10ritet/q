#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub SS_main
{
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list("SELECT * FROM login WHERE mid IN ($Sel_id) ORDER BY time DESC",$start,24,$scrpt);
 if( !$rows )
 {
    &Message("Нет данных по авторизациям ".($For_U || 'ни по одной вашей учетной записи'));
    return;
 }
 $i=0;
 $out='';
 while( $p=$sth->fetchrow_hashref )
 {
    ($time,$act,$mid)=&Get_fields('time','act','mid');
    $tt=&the_short_time($time,$t).sprintf(":%02d",localtime($time)->sec);
    $tt=~s/ /&nbsp;&nbsp;&nbsp;/;
    $auth_src=('&nbsp;','Авторизатор','На порту','Web-авторизация','PPPoE','','','','')[int($act/10)];
    $act=(0,1,2,3,4,5,6,'on' ,'ong','off')[$act % 10];
    $out.=&RRow('*','rccc',
      $Falias? "$U{$mid}{o_name} <span class=disabled>($U{$mid}{ip})</span>&nbsp;&nbsp;&nbsp;" : ++$i.'&nbsp;&nbsp;',
      $tt,
      $act? &ShowModeAuth($act) : 'отключен',
      $auth_src
    );
 }

 $page_buttons&&=&RRow('head',4,$page_buttons);
 $OUT.=&Table('tbg3',
   &RRow('head',4,&bold_br("Сеансы авторизаций $For_U")).
   $page_buttons.
   &RRow('head','cccc',!!$Falias && 'Учетная запись','Время','Состояние','Источник авторизации').
   $out.
   $page_buttons
 );
}

1;      
