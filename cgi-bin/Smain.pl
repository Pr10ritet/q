#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub SMain
{
 &LoadDopdataMod;

 $paket=$U{$Mid}{paket};
 $block_if_limit=$pm->{block_if_limit};
 $limit_balance=$pm->{limit_balance};
 $next_paket=$pm->{next_paket};
 $next_paket_name=$next_paket<=0 || $next_paket>$m_tarif? '' : $Plan_name_short[$next_paket] || $Lang_smain_err_pkt;

 $out='';
 $sth=&sql($dbh,"SELECT time,coment FROM pays WHERE category=496 AND mid=0 AND type=30 AND reason LIKE '%,$grp,%' ORDER BY time DESC LIMIT 3",'Сообщения, адресованные всей группе');
 while( $h=$sth->fetchrow_hashref )
 {
    $out.=&tag('li',"$Lang_smain_msg_from_adm (".&the_short_time($h->{time},$t,1).')'.$br2.&div('message',&Show_all($h->{coment}),1));
 }

 $h=&sql_select_line($dbh,"SELECT cash,time FROM pays WHERE mid=$Mid AND type=20 LIMIT 1",$Lang_smain_sql_tmp_pays);
 if ($h)
 {
    $out.=&tag('li',$Lang_smain_tmp_pay.&ahref("$scrpt&a=115",$Lang_smain_btn_paymod).$br2);
    $vcash=$h->{cash};
    $vtime=int(($h->{time}-$t)/(3600*24));	# количество дней до удаления платежа
    $vtime=0 if $vtime<0;			# если не успел удалиться
 }
  else
 {
    $vcash=0;
 }

 if( !$U{$Mid}{state_off} && $block_if_limit )
 {  # запись в разрешенном состоянии и установлен лимит отключения
    if ($day_now<$Plan_got_money_day && $U{$Mid}{final_balance}<$limit_balance)
    {  # Если еще не наступило время отключения и результирующий баланс ниже лимита
       $out.=&tag('li',&tag('span',&Printf($Lang_smain_day_to_block,$Plan_got_money_day-$day_now),'class=error').$br2);
    }
     elsif ($U{$Mid}{final_balance}<$limit_balance)
    {  # уже наступил день отключения, баланс ниже границы, а доступ еще не успело заблокировать
       $out.=&tag('li',&tag('span',$Lang_smain_wait_block,'class=error').$br2);
    }
     elsif (($U{$Mid}{final_balance}-$vcash)<$limit_balance) 
    {  # результирующий баланс НЕ меньше лимита, однако есть временный платеж, причем без учета врем. платежа результирующий баланс будет ниже лимита
       # Кстати, отрицательный временный платеж и его отсутствие ($vcash=0) не попадут в это условие из-за предыдущего, так что все ок
       $out.=&tag('li',&tag('span',$vtime? &Printf($Lang_smain_day_to_block,$vtime) : $Lang_smain_wait_block,'class=error').$br2);
    }
 }

 # Выведем сообщения для клиента
 $coment='';
 $mess_day=$t-3600*24*($mess_day||15); # 15 суток по умолчанию, иначе запись устарела
 $sth=&sql($dbh,"SELECT * FROM pays WHERE mid=$Mid AND type=30 AND category IN (490,493) AND time>$mess_day ORDER BY time DESC LIMIT 3",$Lang_smain_sql_msg_to_u);
 while( $h=$sth->fetchrow_hashref )
 {
    ($coment ne '') && $h->{category}==493 && next; # не выводим 2-е и 3-е сообщение если клиент уже нажимал `ознакомлен`
    $coment=&Show_all($h->{coment});
    ($coment eq '') && next;
    $reason=$h->{reason};
    if ($reason=~/^\d+$/)
    {  # сообщение клиенту, если в поле reason число, то оно - id цитируемой записи
       $i=&sql_select_line($dbh,"SELECT reason FROM pays WHERE id=$reason AND mid=$Mid AND type=30 AND category IN (491,492)",$Lang_smain_sql_quote_of_msg);
       $reason=!!$i && &Printf( $Lang_smain_reply_msg, &div('message',&Show_all($i->{reason})) );
    }else
    {
       $reason='';
    }
      
    $out.="<li>$Lang_smain_msg_from_adm (".&the_short_time($h->{time},$t,1).')'.$br2.$reason.&div('message',$coment,'',1);
    $out.=&CenterA("$scrpt&a=2&idz=".$h->{id},$Lang_smain_msg_accepted).$br2 if $h->{category}==490;
    $out.='</li>';
 }

 $h=&sql_select_line($dbh,"SELECT time,cash FROM pays WHERE mid=$Mid AND type=10 AND time>$mess_day ORDER BY time DESC LIMIT 1",$Lang_smain_sql_last_pay);
 if( $h )
 {
    $cash=$h->{cash};
    $cash=$cash<0? $Lang_smain_negative_pay.&bold(-$cash) : $Lang_smain_positive_pay.&bold($cash);
    $out.=&tag('li',&the_time($h->{time})."&nbsp;&nbsp;&nbsp;$cash ".$gr.$br2);
 }

 # автоплатежи
 $sth=&sql($dbh,"SELECT time,reason,coment FROM pays WHERE mid=$Mid AND category=112 AND type=50 AND time>unix_timestamp()",$Lang_smain_sql_autopays);
 while( $h=$sth->fetchrow_hashref )
 {
    $h->{reason}=~/^(.+):(\d+)$/ or next; # деньги:время
    ($cash,$tm)=($1,$2);
    $cash+=0;
    $cash or next;
    $cash=sprintf("%.2f",$cash);
    $out.=&tag('li',&tag('span',&the_time($h->{time}+$tm),'class=data1').' '.
      ( $cash<0? &Printf($Lang_smain_autopay_sub,-$cash) : &Printf($Lang_smain_autopay_add,$cash) ).
      $br2.&Filtr_out($h->{coment}).$br2);
 }

 $out.=&tag('li',&Printf($Lang_smain_next_pkt_set,$next_paket_name).&ahref("$scrpt&a=113",$Lang_smain_btn_setpkt_mod).$br2) if $next_paket_name;

 if( $U{$Mid}{money_over} && $Plan_flags[$paket]=~/m/ )
 {# Есть переработка пакета и разрешено в текущем месяце доказать дополнительный пакет
    $out.=&tag('li',&Printf($Lang_smain_ask_for_add_pkt,sprintf("%.2f",$U{$Mid}{money_over})).$br2.&CenterA("$scrpt&a=113&act=10",$Lang_smain_btn_more).$br2);
 } 

 $OUT.=&MessX("<img height=1 width=560 src='$spc_pic'>".&tag('ul',$out),0,1) if $out;

 $out=&tag('thead',&RRow('','3',&bold($Lang_smain_block_states))).
    &RRow('tablebg','ccc',&bold($Lang_smain_lbl_login),&bold('ip'),&bold($Lang_smain_lbl_access));

 $close_reason=$block_cod? "<span class=data2>&nbsp;&nbsp;$Lang_smain_access_closed&nbsp;&nbsp;</span> (".&Get_text_block_cod($block_cod).")" :
       "<span class=data1>&nbsp;&nbsp;$Lang_smain_access_openned&nbsp;&nbsp;</span>";
 $block_reason="<span class=error>&nbsp;&nbsp;$Lang_smain_access_blocked&nbsp;&nbsp;</span>";

 ($r1 eq 'row1') && &PRow;

 foreach (keys %U)
 {
    $out.=&RRow('*','llr',$U{$_}{o_name},$U{$_}{ip},$U{$_}{state_off}? $block_reason : $close_reason);
 }

 $show_balance=!$How_show_balance? $U{$Mid}{final_balance} : $How_show_balance==1? $U{$Mid}{balance} : $U{$Mid}{balance}-$U{$Mid}{money_over};

 $end=$show_balance<-1? "<span class=error>$Lang_smain_overmoney</span>" :
    $show_balance<0? "<span class=error>$Lang_smain_small_overmoney.</span>" :
    "<span class=data1>$Lang_smain_no_overmoney.</span>";

 $show_balance="<span class='row1 ".($show_balance<0? 'error':'data1')."'>&nbsp;".sprintf("%.2f",$show_balance)."&nbsp;</span>&nbsp;$gr";
 $show_gotmoney=!$How_show_balance? $U{$Mid}{money} : $How_show_balance==1? 0 : $U{$Mid}{money_over};

 if( $How_show_balance!=1 )
 {
    $out.=&RRow('row3','Lr',$Lang_smain_balance_is,$show_balance);
    $out.=&RRow('*','Lr',$Lang_smain_credit_is,"$limit_balance $gr") if $Show_limit_balance && $block_if_limit;
 }
  else
 {
    $out.=&RRow('head','Lr',$Lang_smain_balance_is,$show_balance);
 }

 $OUT.=&Table('usrlist width100',$out).$br2;

 $out=&RRow('','L',&bold($Lang_smain_traf_is.(!!$nAlias && " ($Lang_smain_sum_traf)")));
 
 foreach $i (1..4)
 {
    $out.=&RRow('*','lr',
       &bold("$c[$i] $Lang_lbl_traf").' ('.&Get_name_traf(${"InOrOut$i"}[$paket]).')',
       &tag('span',&split_n(sprintf("%.2f",${"Traf$i"})),'class=data2')." $Lang_lbl_mb."
    ) if $i==1 || ${"Plan_over$i"}[$paket]!=0;
 }

 $OUT.=&Table('usrlist width100',$out).$br2; 

 $OUT.=$Adm{id} && !$Plan_allow_show[$paket]? &MessX($Lang_smain_no_tarif_priv,1,1) : $str_money;
 $OUT.=$br2;

 sub SM_show_addr
 {
  $sth=&sql($dbh,"SELECT * FROM dopdata WHERE parent_id=$_[0] AND template_num=(SELECT template_num FROM dopfields WHERE field_alias LIKE '_adr_%' LIMIT 1)");
  while( $h=$sth->fetchrow_hashref )
  {
     $field_name=&Del_Sort_Prefix($h->{field_name});
     $field_alias=$h->{field_alias};
     $dopf_name{$field_alias}=$field_name;
     $dopf_val{$field_alias}=$h->{field_value};
     $dopf_type{$field_alias}=$h->{field_type};
  }

  foreach $alias (
    'p_street:street:name_street',
    '_adr_house',
    '_adr_block',
    '_adr_front_door',
    '_adr_floor',
    '_adr_room',
    '_adr_telefon'
  )
  {
     ($dopf_val{$alias} ne '') or next;
     $field_value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $dopf_type{$alias},
          alias	=> $alias,
          value	=> $dopf_val{$alias}
       })
     );
     $out.=&RRow('*','lr',&Filtr_out($dopf_name{$alias}),$field_value);
  }
 }

 $out=&RRow('*','lr',$Lang_fio,$U{$id}{o_fio});
 &SM_show_addr($id);

 if( $Mid!=$id )
 {
    $out.=&RRow('head','C',$Lang_smain_main_login_data).
          &RRow('*','lr',$Lang_fio,$U{$Mid}{o_fio});
    &SM_show_addr($Mid);
 }   

 $OUT.=&Table('usrlist width100',
    &RRow('','C',ahref('javascript:show_x(20)',"$Lang_smain_private_data &darr;")).
    &tag('tr',
       &tag('td',&Table('tbg1 width100',$out)),
       "class=row2 id=my_x_20 style='display:none'"
    )
 ).$br2;

 # Персональный платежный код
 $csum=0;
 $csum+=$_ foreach split //,$Mid;
 $csum%=10; # контрольная сумма посчитанная по переданному номеру аккаунта
 $account="$Mid$csum";

 $OUT.=&MessX(&Printf('[span big][span big|bold] &nbsp;&nbsp;&nbsp;[span big]',$Lang_smain_your_PPC_is,$account,&ahref("$scrpt&a=3",$Lang_help)),1,1) if $Show_PPC;

 $OUT.=&Center(&MessX($end));
}

1;
