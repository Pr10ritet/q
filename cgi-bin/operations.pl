#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$Fact=$F{act};

%subs=(
 'help'			=> \&sub_zero,	# ����� ������ �� �����
 'searchmail'		=> \&sub_zero,	# ����� �� email
 'print'		=> \&sub_zero,	# ������ ������ � ������� �������
 'resolv'		=> \&sub_zero,	# �������� ������
 'payagree'		=> \&sub_zero,	# ��������/���������� ��������� ��������
 'set_temp_block'	=> \&sub_zero,	# ���������� ��������� ����������� � ��������� �����
 'setmess'		=> \&check_adm,	# ���������� ��������� ��� ��������������
 'setmessnow'		=> \&check_adm,	# ��������������� ���������� ��������� ��� ��������������
 'dontshowmess'		=> \&sub_zero,	# ������� ��������� ��� ������ �� �����������
 'cardsail'		=> \&sub_zero,	# ������� �������� ���������� ����� (�� ��������)
 'cards_oper'		=> \&sub_zero,	# �������� � ���������� ������
 'cards_move_sel'	=> \&sub_zero,	# ����� �������������� ��� ��������
 'cards_move_go'	=> \&sub_zero,	# ���������������� �������� ��������
 'cards_move_agree'	=> \&sub_zero,	# ������������� �������� �������� ����������� �������
 'cards_move_dont_agree' => \&sub_zero,	# ����� �� ������ ��������
 'cards_set_good'	=> \&sub_zero,	# ������� �������� � ��������� "����� ������������ ��� �������"
);

&Exit unless defined $subs{$Fact};

&{ $subs{$Fact} };
&{$Fact}; 
&Exit;



# ==================================================
#	���������� ��������� ��� ��������������
# ==================================================
sub check_adm
{# 30 � 31 - ����� �� ������������ �� ������ ������� ������
 &Error("� ��� ��� ���� ��������� ������������� ��������� ��� ��������������.") if !$PR{30} && !$PR{31};
 $Fid=int $F{id};
 ($A,$Asort)=&Get_adms();
 &Error("� ��� ��� ���� ��������� ������������� ��������� ��� �������������� (id=$Fid) � ������ �������� �� ������.") if !$PR{31} && $A->{$Fid}{office}!=$Admin_office;
 $A->{$Fid}{login} or &Error("������������� � id=$Fid �� ����������.");
}

sub setmess
{
 $OUT.=$br.&MessX(
   &form('!'=>1,'act'=>'setmessnow','id'=>$Fid,
     "���������� ������������ ��������� ��� �������������� $A->{$Fid}{admin}:".$br2.
     &div('cntr','<textarea rows=6 cols=40 name=mess>'.$A->{$Fid}{mess}.'</textarea>'.$br2).
     &submit_a('����������').$br2.
     "������������� ����� ������������ � ����������, ����� ��� �������������� �������."
   )
 );
}

sub setmessnow
{
 $Fmess=&Filtr_mysql(&trim($F{mess}));
 $rows=&sql_do($dbh,"UPDATE admin SET mess='$Fmess' WHERE id=$Fid LIMIT 1");
 $rows<1 && &Error("��������� ������ sql-������� ��� ��������� ������������� ��������� ��� ��������������.");
 &OkMess("������������ ��������� ��� �������������� $A->{$Fid}{admin} �����������.");
}

sub dontshowmess
{
 $rows=&sql_do($dbh,"UPDATE admin SET mess='' WHERE id=$Admin_id LIMIT 1",'�������� ��������� �� ������� ��������������');
 $rows<1 && &Error("��������� ������. ��������� ������ �����.$go_back");
 &OkMess("���������, ����������� ���, �������. ����� 10 ������ ���������� ������� �� ��������� �������� �������.");
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="10; url='$scrpt0&a='">};
}

# ==================================================
# ��������� ���������� ����������� � ��������� �����
# ==================================================
sub set_temp_block
{
 $temp_block=',';
 foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
   {
    $temp_block.="$g," if $F{"g$g"}; # ��������� ���� �� ������ � ������ �� ���� - ����� ������������ ������ � ����������� ������
   }
 $temp_block='' if $temp_block eq ',';
 &sql_do($dbh,"UPDATE admin SET temp_block_grp='$temp_block' WHERE id=$Admin_id LIMIT 1");
 &OkMess("����������� �� �������� ����� �����������.".$br2.&CenterA("$scrpt0&a=main",'����� &rarr;'));
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="10; url='$scrpt0&a=listuser'">};
}

# =========================
#	����� �� email
# =========================
sub searchmail
{
 $mail_enable or &Error('������ � ��������� ������� ���������.');
 $PR{93} or &Error('������ � ��������� ������� ��� ���������.');
 $OUT.=&div('message','��������������: ����� �������� ������ �� email, ������� ����������� �������� � ��������� ��� �������.') unless $pr_SuperAdmin;
 
 $sth=&sql($dbh,"SELECT * FROM users");
 while ($p=$sth->fetchrow_hashref)
   {
    $id=$p->{id};
    $U{$id}{name}=$p->{name};
    $U{$id}{grp}=$p->{grp};
   }
 
 $dbh2=DBI->connect("DBI:mysql:database=$mail_db;host=$mail_host;mysql_connect_timeout=3",$mail_user,$mail_pass);
 $dbh2 or &Error('������ ���������� � �������� ����� ������.');
 &SetCharSet($dbh2);

 $out='';
 $sth2=&sql($dbh2,"SELECT * FROM `$mail_table` WHERE `$mail_p_email` LIKE '%".&Filtr_mysql($F{email})."%' ORDER BY `$mail_p_user`");
 while ($p=$sth2->fetchrow_hashref)
   {
    $id=int $p->{$mail_p_user};
    next if !$UGrp_allow{$U{$id}{grp}} && !$pr_SuperAdmin; # ����������� ����� ���������� � ������������� � ���� ������ (���������������� $UGrp_allow{})
    $out.=&RRow('*','ll',
      defined($U{$id}{name}) && &ahref("$scrpt0&a=user&act=showmail&id=$id",&Filtr_out($U{$id}{name})),
      &Filtr_out($p->{$mail_p_email})
    )
   }
 $out or &Error('�� �������� �������� ������ �� ������� �� ������ email.');
 
 $OUT.=&Table('tbg3',
   &RRow('head','C',&bold_br('����� �� email')).
   &RRow('*','cc','������','Email').
   $out);
}

# ===============================
#     �������� ������ ip
# ===============================
sub resolv
{
 $host=gethostbyaddr(inet_aton($F{ip}),AF_INET);
 $host=$host || '����� ����������';
 $Fip_id=int $F{ip_id};
 $out="Content-type: text/html\n\n".
   "<html><head><title>$Title_net - �������� ������</title>".
    "<meta http-equiv='Cache-Control' content='no-cache'><meta http-equiv='Pragma' content='no-cache'>".
    "<body>�������� ������ $F{ip}".$br2."���������: <b>$host</b>".
      "<script language='JavaScript'>\n".
        "opener.document.all['f$Fip_id'].innerHTML='$host ($F{ip})';\n".
        "self.close()\n".
      "</script>".
   "</body></html>";
 print $out;
 exit;
}  

# ===============================
# ������ ������ � ������� �������
# ===============================
sub print
{
 $PR{61} or &Error("��� ����."); # �������� �������
 $Fid=int $F{id};
 $p=&sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM fullusers WHERE id=$Fid LIMIT 1");
 $p or &Error("������ ��������� ������ ������� � id=$Fid.");
 $grp=$p->{grp};
 $grp_allow=$UGrp_allow{$grp};
 $grp_allow or &Error("������ ��������� � ������, ������ � ������� ��� ��������. ����� �������� ����������.");
 ($fio,$comment,$contract,$contract_date)=&Get_filtr_fields qw(
   fio  comment  contract  contract_date);

 &LoadDopdataMod();
 $out_adr='';
 $sth=&sql($dbh,"SELECT * FROM dopdata WHERE parent_id=$Fid AND template_num=(SELECT template_num FROM dopfields WHERE parent_type=0 AND field_alias LIKE '_adr%' LIMIT 1) ORDER BY field_name");
 while( $h=$sth->fetchrow_hashref )
 {
    $name=$h->{field_name};
    $name=~s|^\[\d+\]\s*||;
    $value=&Filtr_out(
       &nDopdata_print_value
       ({
          type	=> $h->{field_type},
          alias	=> $h->{field_alias},
          value	=> $h->{field_value}
       })
     );
   $value=~s|\n|<br>|g if $h->{field_type}==5; # ��������� �������������
   $out_adr.=&RRow('*','ll',&Filtr_out($name),&bold($value));
 }

 $out='';
 $out.=&RRow('','ll',$br.'���'.$br2,$fio ne ''? &bold($fio) : '�� �������') if $pr_show_fio;
 $out.=&RRow('','ll','�������',($contract ne ''? &bold($contract) : '�� ������').(!!$contract_date && ' ('.&the_date($contract_date).')'));
 $out.=$out_adr && &RRow('','C','����� �����������:').$out_adr;

 $ipp=&Filtr_out($p->{ip});
 $ipp=~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
 $ip_raw=pack('CCCC',$1,$2,$3,$4);

 $gate=$dns=$mask='';
 foreach $i (@cl_nets)
 {
    ($net,$tgate,@dns)=split /\s+/,$i;
    $net=~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ or next;
    $net_mask=$5;
    $net_raw=pack('CCCC',$1,$2,$3,$4);
    $net_mask_raw=pack('B32',1 x $net_mask,0 x (32-$net_mask));
    $net_raw&=$net_mask_raw;
    next if ($ip_raw & $net_mask_raw) ne $net_raw;
    # ����� ������. �������� ����
    if ($tgate=~/^\d+$/ && $tgate>0 && $tgate<32)
    {
       $net_mask_raw=pack('B32',1 x $tgate,0 x (32-$tgate));
       $gate_raw=($ip_raw & $net_mask_raw) | pack('CCCC',0,0,0,1);
       $tgate=join(".",unpack("C4",$gate_raw));
    }
    $mask=join(".",unpack("C4",$net_mask_raw));
    $gate=$tgate;
    $dns.=$_.$br foreach (@dns);
    last;
 }

 $pass=&Filtr_out($p->{"AES_DECRYPT(passwd,'$Passwd_Key')"});
 $name=&Filtr_out($p->{name}) || '&nbsp';

 $h2.=&RRow('','L','');
 $p=&sql_select_line($dbh,"SELECT * FROM user_grp WHERE grp_id=$grp");
 if ($p && $pr_show_fio && $grp_allow>1)
 {
    $grp_blank_mess=$p->{grp_blank_mess};
    $grp_blank_mess="��������� �����������:\n�����|\$l\n������|\$p" if $grp_blank_mess=~/^\s*$/;
    foreach $i (split/\n/,$grp_blank_mess)
    {
       $i=~s|\$p|$pass|;
       $i=~s|\$l|$name|;
       $i=~s|\$i|$ipp|;
       $i=~s|\$d|$dns|;
       $i=~s|\$g|$gate|;
       $i=~s|\$m|$mask|;
       $h2.=($i=~/(.*)\|(.*)/)? &RRow('','ll',$1,&bold($2)) : &RRow('','C',$i);
    }
 }

 $body="<div align=center><br><table width=528>$out$h2</table>$br2$br3<div id=nav>".
    &ahref("javascript:history.go(-1)",'�����').'&nbsp;&nbsp;&nbsp;'.
    &ahref(qq{javascript:document.getElementById("nav").style.display="none"; document.execCommand("Print"); history.go(-1)},'������').
    "</div>";   

 $OUT="Content-type: text/html\n\n<html><head><title>$Title_net</title>".
    "<meta http-equiv='cache-control' content='no-cache'><meta http-equiv='pragma' content='no-cache'>".
    "<meta http-equiv='Content-Type' content='text/html; charset=windows-1251'>\n".
    "<style type='text/css'>\n".
    "body {background:#fff; margin:0px; padding:0px;}\n".
    "table {border:double black; padding:5px; border-collapse:collapse}\n".
    "table td {border:1px solid #a0a0a0; padding:4px}\n".
    "</style>\n".
   "<body>$body</body></html>";
 print $OUT;
 exit;
}  

# =======================================================
# �������������/����� �� �������� �������� ����� ��������
# =======================================================
sub payagree
{
 # ����������� ��������� ��� ����! 
 $Fid=int $F{id};
 $Fcash=$F{cash}+0;
 $h=(!$F{yes} && '������ �� ')."������������� �������� ����� $Fcash $gr";
 $url=&ahref("$scrpt0&a=payshow&nodeny=admin&bonus=y&year=$year_now&mon=$mon_now&admin=$Admin_id",'�������');
 $yes=$F{yes}? 408 : 409; # ��������� �������� �������������� ��� �������������� � ���

 $rows=&sql_do($dbh,"UPDATE pays SET category=$yes WHERE id=$Fid AND mid=0 AND type=40 AND category=470 AND coment='$Admin_id' AND cash=$Fcash LIMIT 1");
 &Error("�������� $h �� ���������. ��������� �������:$br2<ul>".
   "<li>�� ��� ��������� ������ �������� � �������� ������� ������.</li>".
   "<li>���� �� �������� ������, ������ ������������� ������� �������� ���� ������� ����� ��������.</li>".
   "</ul>��� ��������� �������� ������� � ������ $url") if $rows<1;
 &OkMess("�������� $h ��������� �������. ���� $url");
 &ToLog("$Admin_UU �������� $h ��������� �������. Id ������ � ������� ��������: $Fid");
}

# ===============================================
# ������� �������� ���������� ����� (�� ��������)
# ===============================================
sub cardsail
{
 $main_href=$br2.&ahref("$scrpt0&a=main",'������� �� �������� '.&commas('��������'));
 $FcardId=int $F{cardid};
 $F{cardid}=&Filtr_out($F{cardid});
 $copy_to_buf=qq{ <span onClick='window.clipboardData.setData("Text","$F{cardid}")' class=data2 style='cursor:pointer;border:0;'>(����������� � ����� ������)</span>};
 $sn='�������� ���������� � �������� ������� '.&bold($FcardId).$copy_to_buf;
 $your_pays=&ahref("$scrpt0&a=payshow&nodeny=admin&admin=$Admin_id",'�������� ���� �������');
 &Error("�������� ���������� �� ������� �.� �� ������� �������� �������� ����� ".&bold($F{cardid})."$copy_to_buf, ������� ������ ���� ������ 0.$main_href") if $FcardId<=0;

 $p=&sql_select_line($dbh,"SELECT * FROM cards WHERE cid=$FcardId LIMIT 1");
 &Error("$sn �� ����������. �������� �� �������� ��� ����� ������.$main_href") unless $p;

 ($admin_sell,$time_sell,$r,$alive,$cash)=&Get_fields('admin_sell','time_sell','r','alive','money');

 &Error("$sn �� ����� ���� ������� �.� ��� �������� �� ������. ���������� � ��������������, ������� ��������� �������� ��������.$main_href") unless $r;
 &Error("$sn �� ����� ���� ������� �.�. � ���� ������ ���������� ��������������: �������� �������� � ��� �� �����, ��� ���� ��� �� �������� ���������. ".
   "���������� � �������� �������������� ��� ���������� ������ ��������.$main_href") if $r==$Admin_id && $admin_sell>0;
 &Error("$sn ���� ������� ".&the_short_time($time_sell,$t).". $your_pays, �������� �� �������������� ������.$main_href") if $admin_sell==$Admin_id;
 &Error("$sn �� ����� ���� ������� �.� ��� ��������� � ���� �������.$main_href") if $r<0 && !$admin_sell;
 &Error("$sn ���� �������� �� ���������� �� ���!$main_href") if $r!=$Admin_id;
 &Error("$sn �������� ���������������. ���������� ������� �� �����. $main_href") if $alive eq 'bad';
 &Error("$sn �������� ��� �������� ������� ��������������. ������� �������� �� ����� ���� ������������ ���� ����������� ����� �� ��������� �� ������������� ������ ��������. $main_href") if $alive eq 'move';
 &Error("$sn �������� ��������������! ������� �������������. $main_href") if $alive ne 'good' && $alive ne 'stock';

 $sth=$dbh->prepare("INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
     "VALUES(0,$cash,10,$Admin_id,INET_ATON('$ip'),$Admin_office,'','�������� ���������� $FcardId','',299,unix_timestamp())");
 if (!$sth->execute || !($pay_id=$sth->{mysql_insertid}) || !$pay_id)
   {
    &Error("������ ��� �������� ������� ���������� ����� ���������� �����. $your_pays � ���������, ��� ��� ������ � ���������� �������� � �������� ������� $FcardId. ".
     " ���� ������ ����� �������������� - �������� ������ �������� � ���������� � �������� �������������� ��� ���������� ���� ��������.$main_href");
   } 
 $rows=&sql_do($dbh,"UPDATE cards SET id_sell=$pay_id,admin_sell=$Admin_id,r=-2,alive='good',time_sell=unix_timestamp() WHERE cid=$FcardId AND r=$Admin_id LIMIT 1");
 &Error("��������� ������ �������. �������� �� �������, ������ �������� � �� ������� ���������. ���������� � �������� �������������� ��� �������� ���� ��������, ".
   "� ��������� ������ �� ������ ������ �����, ������ �������� ��������.$main_href") if $rows!=1;
 &OkMess("$sn ��������� ".&bold($cash)." ������� �������.$main_href");
}

# ===============================================
#    �������� � ���������� ���������� �����
# ===============================================

sub cards_chk_free
{
 $p=&sql_select_line($dbh,"SELECT COUNT(*) FROM cards WHERE r=$Admin_id");
 &Error('� ��� '.&commas('�� �����').' ��� �� ����� ��������. ���� ��� �� ��� - �������� ��� ���� �������� �������� ��� ���������� ����� ��������. '.
    '���������� � ��������������, ������� ������� ��� ��������, ���� �� ������� ��� � ��������.') if !$p || !$p->{'COUNT(*)'};
}

sub show_cid
{
 my ($start_cid,$len,$money,$alive)=@_;
 my $end_cid=$start_cid+$len-1;
 my $comment=$alives{$alive}? $alives{$alive}.'. '.&ahref("$scrpt&act=help&theme=cards_$alive",'[?]') : '������������';
 return &RRow('*','llllcc',$money,"$start_cid .. $end_cid",$len,$comment,
     $alive=~/^(good|stock|bad)$/? &div('nav3',&ahref("$scrpt&act=cards_move_sel&n1=$start_cid&n2=$end_cid",'��')) : '&nbsp;',
     $PR{111} && $alive eq 'stock'? &div('nav3',&ahref("$scrpt&act=cards_set_good&n1=$start_cid&n2=$end_cid",'��')) : '&nbsp;');
}


sub cards_oper
{
 &cards_chk_free;
 %alives=(
  'move' => '���������� ������� ������, ��������� �������������',
  'bad' => '<span class=error>�������������</span>',
  'stock' => '����� ������������ ����� �������',
  'good' =>  '����� ������������',
 );

 $i=$last_alive=$last_money=$start_cid=0;
 $out='';
 $sth=&sql($dbh,"SELECT cid,money,alive FROM cards WHERE r=$Admin_id ORDER BY cid");
 while ($p=$sth->fetchrow_hashref)
   {
    ($cid,$money,$alive)=&Get_fields('cid','money','alive');
     $start_cid||=$cid;
     $last_money||=$money;
     $alive=1 if int($alive)>0;
     $last_alive||=$alive;
     next if $cid==($start_cid+$i) && $money==$last_money && $last_alive eq $alive;
     $out.=&show_cid($start_cid,$i,$last_money,$last_alive);
     $last_money=$money;
     $last_alive=$alive;
     $start_cid=$cid;
     $i=0;
    }
     continue
    {
     $i++;
    }
     
 $out.=&show_cid($start_cid,$i,$money,$last_alive) if $start_cid;
 $out=&MessX('�������� ���������� �����, ������� �������� �� ����:').'<br>'.
     &Table('tbg3',&RRow('head','cccccc',"�������, $gr",'��������','����','�����������','��������',$PR{111}?'���������<br>���������':'&nbsp;').$out) if $out;

 $OUT.=&div('message',$out.
   &form('!'=>1,'act'=>'cards_move_sel','<br>'.
     &Table('tbg3 nav2',&RRow('head','C',&bold('�������� �������� ���������� ����� ������� ��������������')).
     &RRow('*','ll','��������� ����� ���������',&input_t('n1','',20,22)).
     &RRow('*','ll','�������� ����� ���������',&input_t('n2','',20,22)).
     &RRow('*','C','<br>'.&submit_a('����� &rarr;').'<br>'))
   )
 );
}


sub cards_get_info
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $n1>$n2 && &Error("��������� ����� �������� $n1 ������ ��������� $n2. �������� �������� �� ���������.");
 $err_mess='�������� �������� �� ��������� - ��������� ������. ���������� �����.';
 $mess1="� ��������� ��������� �������� ������� $n1 .. $n2";
 $mess2='';
 $n=$n2-$n1+1;
 $out='';
 $out.=&RRow('*','ll','��������� �����',$n1);
 $out.=&RRow('*','ll','�������� �����',$n2);

 $sql="SELECT COUNT(*) FROM cards WHERE cid>=$n1 AND cid<=$n2";

 $p=&sql_select_line($dbh,$sql);
 $p or &Error($err_mess);
 $all_cards=$p->{'COUNT(*)'};
 $all_cards or &Error("$mess1 ��� �� ����� ��������. ��������� ��������� �� �� ������� ��������.");

 # �� ��������� ������� ������ ���� ���������� ������ �� ����� ��������� ������� �������� ����� � ��������
 $mess2.="<li>$mess1 ����� �������� $n ��������, ������ ������� ������������ ������.</li>" if $all_cards!=$n; 

 $sql.=" AND r=$Admin_id";
 $p=&sql_select_line($dbh,$sql);
 $p or &Error($err_mess);
 $your_cards=$p->{'COUNT(*)'};
 $your_cards or &Error("$mess1 ��� �� ����� ��������, ������� ��������� �� �� ����. �������� �� ��� �� ���� ��������� �������� ���� �� �������� ��� ����� ��������� �������� �������.");

 $p=&sql_select_line($dbh,"$sql AND admin_sell<>0");
 $p or &Error($err_mess);
 &Error('�������� �������� �� ��������� �.� ������� ���������� �������������� � ���� ������: '.$p->{'COUNT(*)'}.
   " �������� �������� � ��� �� ����� � ��� ���� ��� �� �������� ��� ���������. ���� ������ ����� ��������� ������ ������� �������������.") if $p->{'COUNT(*)'}>0;

 $i=0;
 $sth=&sql($dbh,"SELECT COUNT(*),money FROM cards WHERE cid>=$n1 AND cid<=$n2 AND r=$Admin_id GROUP BY money");
 while ($p=$sth->fetchrow_hashref)
  {# +0 ������� �����-�����������, ���� ������� ����� �����
   $out.=&RRow('*','rl',($p->{money}+0)." $gr",$p->{'COUNT(*)'}.' ��');
   $i++;
  }
 $mess2.='<li>� ��������� ��������� ������ ������ �������� ��������</li>' if $i>1;
 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive='move'");
 $p or &Error($err_mess);
 $move_cards=$p->{'COUNT(*)'};
 $out.=&RRow('*','ll','��� �������� ��� �������� ������� ��������������',$move_cards) if $move_cards>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive='bad'");
 $p or &Error($err_mess);
 $out.=&RRow('*','ll','� ��������������� ���������',$p->{'COUNT(*)'}) if $p->{'COUNT(*)'}>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive NOT IN ('good','stock','move','bad')");
 $p or &Error($err_mess);
 $out.=&RRow('*','ll','������������ ���������',$p->{'COUNT(*)'}) if $p->{'COUNT(*)'}>0;

 $p=&sql_select_line($dbh,"$sql AND r=$Admin_id AND alive IN ('good','bad','stock')");
 $p or &Error($err_mess);

 $moveable_cards=$p->{'COUNT(*)'};
 $out.=&RRow('*','ll','����� �������� ������� ��������������, ��',&bold($moveable_cards));

 $mess2.="<li>� ��������� ��������� ���� ��������, ������� �� ����� �������� ������� ��������������.</li>" if $moveable_cards!=$all_cards;
 
 $mess2 && &ErrorMess("<ul>$mess2</ul>");

 $OUT.=&Table('tbg3',&RRow('head','C',&bold('���������� �� ������������� ��������� ��������')).$out).$br;
 ($A,$Asort)=&Get_adms();
}

sub cards_move_sel
{
 &cards_chk_free;
 &cards_get_info;
 $office=-1;
 $out='';
 foreach $id (@$Asort)
   {
    next if !$PR{26} && $A->{$id}{office}!=$Admin_office;
    $apriv=$A->{$id}{privil};
    next if $apriv!~/,116,/; # �� ����� ������ ������ ������������ ��������
    $o=$A->{$id}{office};
    $out.=&RRow('tablebg','3','����� '.&bold($Offices{$o}||"� $o")) if $o!=$office;
    $office=$o;
    $comment=$apriv=~/,300,/? '' : '<span class=disabled>������ ����� ����������� �����</span><br>';
    $comment.='�������� ����� ���������� � ��������� '.&commas('����� ������������') if $apriv=~/,301,/;
    $out.=&RRow('*','lll',&ahref("$scrpt&act=cards_move_go&n1=$n1&n2=$n2&id=$id",$A->{$id}{login}),$A->{$id}{name},$comment);
   }
 $OUT.=$out? &Table('tbg3 nav3',&RRow('head','3','�������� ��������������, �������� ����������� �������� �������� ���������� �����').$out):
   &error('��������.','��� �� ������ ��������������, �� �������� �� ������ �������� �������� ��������.');
 $OUT.=$go_back;
}

sub cards_move_go
{
 &cards_get_info;
 $Fid=int $F{id};
 $Fid<=0 && &Error("�������� �������� �� ��������� �.�. ������ �������� id �������������� �� �������� ���� ��������� ��������.");
 &Error("�������� �������� �� ��������� �.�. �������������, �������� �� ��������� ��������, �������� � ������ ������. ".
   "� ��� ��� ������� � ������ �������.") if !$PR{26} && $A->{$Fid}{office}!=$Admin_office;
 $apriv=$A->{$Fid}{privil};
 $apriv=~/,116,/ or &Error("�������� �������� �� ��������� �.�. �������������, �������� �� ��������� ��������, �� ����� ���� �� �� �����.");
 $where="WHERE r=$Admin_id AND cid>=$n1 AND cid<=$n2";

 if ($apriv=~/,300,/)
   {# �� ��������� ������������� ��������. ���������� ������� "����� ������������"?
    $alive=$apriv=~/,301,/? 'good':'stock';
    $sql="UPDATE cards SET alive='$alive',r=$Fid $where AND alive IN ('good','stock')";
    $rows=&sql_do($dbh,$sql);
    $rows=0 if $rows<0;
    $sql="UPDATE cards SET r=$Fid $where AND alive='bad')"; 
    $rows+=&sql_do($dbh,$sql);
    $mess1='. ������������� �� ���������';
    $mess2='������������� ����������� ������� �� ���������.';
   }else
   {
    $sql="UPDATE cards SET alive='move',rand_id=$Fid $where AND alive IN ('good','bad','stock')"; 
    $rows=&sql_do($dbh,$sql);
    $mess1='';
    $mess2='��������. ������������� �������� �������� ����� ������������ ������ ����� ������������� �������� ����������� ���������������';
   } 
 $rows<1 && &Error("�������� �������� �� ���������. ���������� ������ �����.");

 # ��������� 415 - "����������� �������� ������"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
          "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','�������� $rows �������� $n1 .. $n2 �� ������ id=$Fid$mess1','',415,unix_timestamp())");
 &OkMess("�� �������������� $A->{$Fid}{admin} �������� $rows ��������. $mess2");
}

sub cards_move_agree
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $n1>$n2 && &Error("��������� ����� �������� $n1 ������ ��������� $n2. ������������� �������� �������� �� ���������.");
 $rows=&sql_do($dbh,"UPDATE cards SET r=$Admin_id,rand_id=0,alive='stock' WHERE rand_id='$Admin_id' AND alive='move' AND cid>=$n1 AND cid<=$n2");
 $rows<1 && &Error("������������� �������� �������� �� ���������. ���������� ������ �����.");
 # ��������� 415 - "����������� �������� ������"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
    "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','����������� ����� $rows �������� $n1 .. $n2','',415,$ut)");
 &OkMess("�� ����������� ����� �������� � ���������� $rows ���� ��������� $n1 .. $n2.");
}

sub cards_move_dont_agree
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 &Error("��������� ����� �������� $n1 ������ ��������� $n2. �������� ��������.") if $n1>$n2;
 $rows=&sql_do($dbh,"UPDATE cards SET rand_id=r WHERE rand_id='$Admin_id' AND alive='move' AND cid>=$n1 AND cid<=$n2");
 &Error('����� �� ������ �������� �� ��������. ���������� ������ �����.') if $rows<1;
 # ��������� 415 - "����������� �������� ������"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
          "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','����� �� ������ $rows �������� $n1 .. $n2','',415,unix_timestamp())");
 &OkMess("�� ���������� ��������� �������� � ���������� $rows ���� ��������� $n1 .. $n2.");
}

sub cards_set_good
{
 $n1=int $F{n1};
 $n2=int $F{n2};
 $n2||=$n1;
 $s=&commas('��������� ��������� ��� �������');
 &Error("��������� ����� �������� $n1 ������ ��������� $n2. ������� ��������� �� �����������.") if $n1>$n2;
 $rows=&sql_do($dbh,"UPDATE cards SET r=$Admin_id,alive='good' WHERE r='$Admin_id' AND alive='stock' AND cid>=$n1 AND cid<=$n2");
 &Error("������� �������� � ��������� $s �� ��������, �������� � ��������� �������� ������� $n1 .. $n2 ��� �� ����� �������� � ��������� ".&commas('����� ������������ ��� �������')) if $rows<1;
 # ��������� 415 - "����������� �������� ������"
 &sql_do($dbh,"INSERT INTO pays (mid,cash,type,admin_id,admin_ip,office,bonus,reason,coment,category,time) ".
    "VALUES(0,0,50,$Admin_id,INET_ATON('$ip'),$Admin_office,'x','���������� $rows �������� $n1 .. $n2 � ��������� \"��������� ��������� ��� �������\"','',415,unix_timestamp())");
 &OkMess("�������� � ���������� $rows ���� ��������� $n1 .. $n2 ���������� � ��������� $s.");
}

# ========================
sub help
{
 $go_back=&Center(&div('nav',$go_back));
 $theme=$F{theme};
 &Error("������� ���������� - ������� ������� ����.$go_back") if $theme=~/[^A-Za-z0-9_]/ || !$theme;
 $fname="$Nodeny_dir_web/help.txt";
 open(FL,$fname) or &Error(($pr_SuperAdmin? "������� ���������� - �� ���� ������� ���� $fname." : '��� ������� �� �������� ����').$go_back);
 @list=<FL>;
 close(FL);
 "@list"=~/~$theme([^~]+)/ or &Error("������� �� ��������� ���� �����������.$go_back");
 &OkMess('<span class=big>�������:</span>'.$br2.$1.$go_back);
}

1;
