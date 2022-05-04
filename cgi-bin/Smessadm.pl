#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

sub MS_mess
{
 $h=($Lang_smsadm_1_msg,$Lang_smsadm_2_msg,$Lang_smsadm_3_msg,$Lang_smsadm_4_msg)[$count_mess-1] || "$count_mess $Lang_smsadm_x_msg";

 $OUT.=$no_mess ||
   &Center_Mess(
     "<span class=data2>$Lang_smsadm_msg_to_adm</span>".$br2.
     &Center(
       &form('!'=>1,&input_ta('mess',$_[0],60,10).$br2.&submit_a($Lang_smsadm_send))).
       $br2.
       ($count_mess>0 && &div('message lft', &Printf('&nbsp;&nbsp;'.$Lang_smsadm_sent_count,$h))
     )
   );

 $out='';
 $sql="SELECT * FROM pays WHERE mid=$Mid AND type=30 AND category IN (490,491,492,493) ORDER BY time DESC";
 ($sql,$page_buttons,undef,$sth)=&Show_navigate_list($sql,$start,10,$scrpt);
 $out.=&RRow('head',4,$page_buttons) if $page_buttons;
 while ($p=$sth->fetchrow_hashref)
 {
    $tt=&the_short_time($p->{time},$t);
    $h=$p->{category};
    $h=$h==490 || $h==493;
    $reason=$p->{reason};
    $mess='';
    if( $h && $reason=~/^\d+$/ )
    {# сообщение клиенту, если в поле reason число, то оно - id цитируемой записи
       $i=&sql_select_line($dbh,"SELECT reason FROM pays WHERE id=$reason AND mid=$Mid AND type=30 AND category IN (491,492)",'Текст цитируемого сообщения');
       $mess.=$Lang_smsadm_your_msg_quote.&div('message',&Show_all($i->{reason})) if $i;
    }
    $mess.=$h? &Show_all($p->{coment}) : &Show_all($reason);
    next if $mess eq '';
    $h=$h? &bold($Lang_smsadm_from_adm) : $Lang_smsadm_from_u;
    $out.=&RRow('*','lclc',$tt,$h,$mess,!!$Adm{id} && &div('nav3',&ahref("$Script_adm&a=pays&act=show&id=$p->{id}","$Lang_smsadm_btn_more &rarr;")));
 }
 $out.=&RRow('head',4,$page_buttons) if $page_buttons;

 $out or return;

 $OUT.=$br.&Table('tbg3 width100',&RRow('head','cccc',$Lang_lbl_time,$Lang_lbl_author,$Lang_lbl_msg,'').$out);
}

sub MS_main
{
 $no_mess=0;
 $p=&sql_select_line($dbh,"SELECT coment FROM pays WHERE mid=$Mid AND type=50 AND category=451 LIMIT 1","$Lang_smsadm_msg_not_allowed?");
 $no_mess=&div('message',&bold_br($Lang_smsadm_msg_not_allowed).&Show_all($p->{coment})) if $p;
 # принимаем во внимание только неотвеченные вопросы
 $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE mid=$Mid AND type=30 AND category=491 AND time>($ut-24*3600)",'Количество сообщений за последние сутки от клиента, на которые администрация не дала ответ');
 $count_mess=$p? $p->{n} : 0;
 $no_mess=&error($Lang_smsadm_msg_overlimits,&Printf(" $Lang_smsadm_n_msg_allowed",$mess_max_times),1) if $count_mess>=$mess_max_times;

 $mess=$F{mess};
 # разрешим то, что можно, остальное запретим
 $mess=~s/[^A-Za-z0-9А-Яа-яёЁіІїЇєЄ().,+=!?:;*_№&#'"`\-\s\@\$\/\^\[\]\|\\	]//g;
 $mess=~s/\r//g;
 if( length($mess)>1500 )
 {
    $OUT.=&error($Lang_smsadm_long_mess_1,". $Lang_smsadm_long_mess_1");
    &MS_mess($mess);
    return;
 } 

 if( !$mess || $no_mess )
 {  # пусть !$mess, а не eq '' - посылка одного нуля нам не нужна
    &MS_mess();
    return;
 }

 $mess_ok=$Lang_smsadm_sent.$br2.&CenterA($scrpt,"$Lang_smsadm_btn_go_next &rarr;");

 $mess=~s/([^\s]{64})/$1\n/g;	# последовательности символов длиной больше 64 разорвем переводом строки
 $mess=~s/( *\n){3,}/\n\n/g;	# больше двух подряд идущих переводов строк заменяем на 2 перевода строки
 $set_mess=&Filtr_mysql($mess);

 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE mid=$Mid AND type=30 AND category=491 AND reason='$set_mess' LIMIT 1",'Не продублировал ли вопрос?');
 if( $p )
 {
    &OkMess($mess_ok);
    return;
 } 

 $server_name=$ENV{SERVER_NAME};
 $sth=$dbh->prepare("INSERT INTO pays SET mid=$Mid,type=30,category=491,reason='$set_mess',admin_id=$Adm{id},admin_ip=INET_ATON('$RealIp'),time=$ut");
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid};

 $h="ФИО: $U{$Mid}{fio}\nТелефон: ".$pm->{telefon};
 $h="ФИО: $U{$id}{fio}\nТелефон: ".$p->{telefon}."\n Данные основной записи:\n$h" if $Mid!=$id;

 # Отправим сообщение на email-ы администраторов
 $mess=" Здравствуйте, администратор биллинговой системы NoDeny!\n\n".
    "Это сообщение отправлено через веб-форму со страницы статистики клиента:\n$h\n".
    "Ip с которого было отправлено сообщение: $RealIp\nСообщение:\n\n$mess\n\n".('=' x 50)."\n\n".
    "Ответить клиенту можете по ссылке: https://${server_name}$Script_adm?a=pays&q=$iid&mid=$Mid\n\n".
    "Данные клиента: https://${server_name}$Script_adm?a=user&id=$Mid\n\n";

 # узнаем каким админам можно, потому как в настройках админов могут быть устаревшие данные
 $sth=&sql($dbh,"SELECT grp_admins,grp_admins2 FROM user_grp WHERE grp_id=$grp");
 if( $h=$sth->fetchrow_hashref )
 {
    $grp_admins=$h->{grp_admins};
    $grp_admins2=$h->{grp_admins2};
    $j=&sql($dbh,"SELECT id,email FROM admin WHERE email<>'' AND (email_grp LIKE '$grp,%' OR email_grp LIKE '%,$grp,%' OR email_grp LIKE '%,$grp') OR email_grp='$grp'");
    while ($i=$j->fetchrow_hashref)
    {
       $id_admin=$i->{id};
       next if $grp_admins!~/,$id_admin,/ || $grp_admins2!~/,$id_admin,/;
       &Smtp($mess,$i->{email},'nodeny@nodeny.com.ua');
    }
 }   

 &OkMess($mess_ok);
}

1;      
