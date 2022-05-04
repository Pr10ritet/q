#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_cards or &Error('��� ���� �� ���������� ���������� ���������� �����.');

$cards_max_generate=12000;	# �� ��� ����� ������������� ������� ����

%subs=(
 'cards_show'	=> \&menu,	# ������ ��������
 'cards_list'	=> \&menu,	# ������ ��������, ��������������� �� ��������� � �.�
 'cards_new'	=> \&menu,	# ���� � �������� �� ��������� ��������
 'cards_generate' => \&menu,	# ���������������� ��������� ��������
 'cards_info'	=> \&menu,
 'cards_del'	=> \&menu,
 'cards_delete'	=> \&menu,
 'cards_admin'	=> \&menu,	# ����� ������, �� �������� ��������� �����
 'cards_report'	=> \&menu,
 'cards_report2' => \&menu,
 'cards_help'	=> \&menu,
);

$Fact=$F{act};

$url_list=$br2.&CenterA("$scrpt&act=cards_list",'����� &rarr;');

$OUT.="<table class='width100 pddng'><tr><td valign=top width=16%>";
$tend='</td></tr></table>';
$fend="$go_back$tend";

$Fact='cards_help' unless defined $subs{$Fact};

&{ $subs{$Fact} };
&{$Fact};
$OUT.=$tend;
&Exit;

sub menu
{
 $U=&Get_users();
 ($A,$Asort)=&Get_adms();
 
 $out='';
 $out.=&ahref("$scrpt&act=cards_new",'��������� ��������') if $pr_cards_create;
 $out.=&ahref("$scrpt&act=cards_list",'������ ��������').
	&ahref("$scrpt&act=cards_show",'�������� ��������').
	&ahref("$scrpt&act=cards_report",'�����').
	&ahref("$scrpt&act=cards_report2",'����� �� ������� ���������').
	&ahref("$scrpt&act=cards_report2&mod=1",'����� �� ������� �������').
	&ahref("$scrpt&act=cards_report2&full=1",'����� �� ���������').
	&ahref("$scrpt&act=cards_admin",'����� �� ������');
 $out.=&div('tablebg',&Center(&form('#'=>1,'act'=>'cards_show',
   "&nbsp;&nbsp;&nbsp;� �����: ".&input_t('n',int($F{n})|| '',11,15).' '.&submit('�����'))));
 $OUT.=&Mess2('row2 nav2',$out)."</td><$tc valign=top>";
}

sub cards_admin
{
 $office=-1;
 $out='';
 foreach $id (@$Asort)
   {
    $o=$A->{$id}{office};
    $out.=&RRow('head','C',"����� ".&bold(($Offices{$o}||"� $o"))) if $o!=$office;
    $office=$o;
    $out.=&RRow('*','ll',&ahref("$scrpt&act=cards_report&filtr=r&id=$id",$A->{$id}{login}),$A->{$id}{name});
   }
 $OUT.=&Table('tbg1 width100',&RRow('tablebg','C','����� �� ������ (�����������)').$out);
}

# ������� ��������� `��� �����`
# ����: $p
sub card_where
{
 my ($p)=@_;
 my $r=$p->{r};
 my $admin_sell=$p->{admin_sell};
 my $id_sell=$p->{id_sell};
 my $h=$admin_sell || $r;
 my $href_adm=&ahref("$scrpt0&a=payshow&nodeny=admin&admin=$h",$A->{$h}{login});

 $r>0 && $admin_sell && return("<span class=error>������ � ��!</span> ���������� ��������������: �������� �������� ��� ��������� ����� NoDeny ��� � �� ����� � ��������������!");
 $admin_sell && return(&ahref("$scrpt0&a=pays&act=show&id=$id_sell",'�������').($r==-1 && ' ��� ������')." $href_adm");
 !$r && return('������������� ������ ������� NoDeny,<br>��������� `�� ������`)');
 $r==-1 && return('����� ���� ������� ��� ������');
 $r==-2 && return('<span class=error>�������������� �� ����������</span>.<br>��� alive=-2, ����� ��� �������� ������ ���� �������� �������.');
 $r>0 && return("�&nbsp;$href_adm");
 return('������������� ������ ������� NoDeny,<br>�������������� ������������.');
}

sub cards_new
{
 !$pr_cards_create && &Error("������������� �������� ���������� ����� ��� �� ���������.",$fend);
 $p=&sql_select_line($dbh,"SELECT MAX(cid) FROM cards");
 &Error("������������� �������� �� ������������ - ������ ��������� ������������� ��������� ������ �������� � ��.",$fend) unless $p;

 &GoodC_Exit($br.&form('!'=>1,'act'=>'cards_generate','max_cid'=>$p->{'MAX(cid)'},
   &Table('tbg',
     &RRow('head','C',&bold_br('��������� �������� ���������� �����')).
     &RRow('*','ll',"���������� �������� (�������� $cards_max_generate)",&input_t('n','',20,10)).
     &RRow('*','ll',"������� ��������, $gr",&input_t('m','',20,20)).
     &RRow('*','ll','���� ��������, ����',&input_t('days',365,20,20))
   ).$br.&submit_a('�������������')
 ));
}

sub cards_generate
{
 !$pr_cards_create && &Error("������������� �������� ���������� ����� ��� �� ���������.",$fend);
 $card_synbl||=15;	# �� ��������� 15 �������� � ����
 $card_slogin||=7;	# �� ��� 7 �� �����, ���� ����
 &Error('��������� ��������� �������� (����� ����) ��������� ���� ������ �������. '.
        '�������� �� �������������.',$fend) if $card_synbl>20 || $card_synbl<8 || $card_slogin<4 || ($card_synbl-$card_slogin)<4;
 $n=int $F{n};
 &Error("����� �������� ��� ��������� ������ ���� � �������� 1..$cards_max_generate.<br><br>�������� �� �������������.",$fend) if $n<1 || $n>$cards_max_generate;
 $m=$F{m}+0;
 $m<=0 && &Error('�������� ����� �� �������� ������ ���� ������ ����.'.$br2.'�������� �� �������������.',$fend);
 $days=int $F{days};
 $days<1 && &Error('���� �������� ������ ���� &gt;0 ����.'.$br2.'�������� �� �������������.',$fend);

 $p=&sql_select_line($dbh,"SELECT MAX(cid) FROM cards");
 !$p && &Error("������������� �������� �� ������������ - ������ ��������� ������������� ��������� ������ �������� � ��.",$fend);

 &Error("������������� �������� �� ������������ - ������������ ��������� ����� �������� � �� ���������. ".
    "��� ������, ��� ���� ����������� ���-�� ������������ �������� ���� �� �������� ��������, �.�. ������� ����������� ������. ".
    "�������� ������� ����� �������� ��� �������� ��������� ��������.",$fend) if $p->{'MAX(cid)'}!=$F{max_cid};

 $days=$days*60*60*24 + $t;
 $abc=$card_abc? 64 : 10;
 $x=$card_synbl-$card_slogin;
 $rez_mess='';
 $cards=0;
 # �� ���� �������� ������ ��� ��������� ������ ���� ���������������, ������ ����� ���������� �������������, �� ���������� -  ����������� ������ �����
 # ����� ��������� ���������. ������� ���� ������������������ ����� �������� - �����������, ����� ����� �������� ���������� � ����
 $first_cid=$last_cid;
 while ($cards<$n)
   {
    $s='';
    for ($i=0; $i<$card_synbl; $i++) {$s.=(0..9,'A'..'Z','a'..'z','@','*')[rand $abc]}
    # ���="�����-������"
    $s=(substr $s,0,$card_slogin).'-'.(substr $s,-$x,$x) if $card_login;

    $sql="INSERT INTO cards (cod,money,stime,etime,admin,r,alive) VALUES ('$s',$m,$t,$days,$Admin_id,$Admin_id,'stock')";
    $sth=$dbh->prepare($sql);
    $sth->execute;
    $cid=$sth->{mysql_insertid} || $sth->{insertid};
    unless ($cid)
      {
       $rez_mess=" ��������� �������� ��-�� ������ ���������� sql-�������.";
       last;
      }
    $cards++;
    $first_cid||=$cid;
    if ($last_cid && $cid!=($last_cid+1))
      {
       $rez_mess=$cards<$n? " ��������� ���� ��������, ��������� �������� ��������: �������� ������ ��������� ���� �� �������. � ��������� ��������������� �������� ".
         "�������� ����� $cid ����� �� ���������. ��������� �������� ����� ���� ����������� ���, ��� ����������� ������ ��������������� ���� �������� ".
         "��������� �������� ���� �� � ���� ������ ����������� ������ � ��. ��������: �������� $cid �� �������." :
         "�������� ��������: ������������� �������� � �������� ������� $cid ��� ��������������� ���������.";
       last;
      }
    $last_cid=$cid;
   }
   
 !$cards && &Error("�� ������������� �� ����� ��������!$rez_mess");

 $last_cid||=$first_cid;
 $rez_mess="������������� $cards �������� ��������� $m $gr c ��������� �������� $first_cid .. $last_cid.$rez_mess";

 &ToLog("!! $Admin_UU $rez_mess");
 &sql_do($dbh,"INSERT INTO pays $Apay_sql,mid=0,cash=0,type=50,category=414,reason='$rez_mess',time=unix_timestamp()");

 &OkMess($rez_mess.$br2.&CenterA("$scrpt&act=cards_list",'����� &rarr;'));
} 

# =====================================
#    ������ ���� ���������� �����
# =====================================

sub cards_show
{
 $sort=int $F{sort};
 $a="$scrpt&act=$Fact&sort=$sort";
 $order='';
 $n=int $F{n};
 $sql="SELECT * FROM cards ";
 if ($n>0)
   {
    $a.="&n=$n";
    $OUT.=&MessX("����� �� ������ ��������: $n").$br;
    $sql.="WHERE cid>=$n";
    $order='cid' unless $sort;
   }
    elsif (defined $F{r})
   {
    $r=int $F{r};
    $r=0 if $r<0;
    $a.="&r=$r";
    $OUT.=&bold('����� �������� '.($r? '�������������� '.$A->{$r}{admin} : '����������� �� ������')).$br2; 
    $sql.="WHERE r=$r";
   }
 $order||=$sort==1? 'money DESC': $sort==2? 'money' : $sort==3? 'etime DESC' : $sort==4? 'atime DESC' : 'stime DESC';
 $sql.=" ORDER BY $order";

 $out='';
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,50,$a);
 while ($p=$sth->fetchrow_hashref)
   {
    ($cid,$cod,$money,$time_sell,$admin_sell,$r,$admin_id,$atime,$alive,$stime,$etime,$id_sell)=
       &Get_fields('cid','cod','money','time_sell','admin_sell','r','admin','atime','alive','stime','etime','id_sell');

    $h=$alive eq 'good'? ($t>$etime? '<span class=rowoff>���� �������� �����</span>': &bold('����� ������������')):
       $alive eq 'move'? '� ��������� �����������' :
       $alive eq 'stock'? "<span class=data1>����� ������������ ����� �������</span>" :
       $alive eq 'bad'? "<span class=error>�������������</span>" :
       int($alive)>0? '<span class=disabled>������������:</span> '.&ahref("$scrpt0&a=user&id=$alive",$U->{$alive}{name}) :
       '<span class=error>����������� ��������� '.&commas(&Filtr_out($alive)).'. ��������� ������������� �������� ��������������</span>';

    $out.=&RRow('*','cllllllll',
      $cid,
      $money,
      &the_time($stime),
      &the_time($etime),
      !!$atime && &the_time($atime),
      &card_where($p),
      $h,
      &ahref("$scrpt0&a=payshow&nodeny=admin&admin=$admin_id",$A->{$admin_id}{login}),
      ($pr_cards_create && &CenterA("$scrpt&act=cards_info&cid=$cid",'&rarr;'))
    );
   }

 $page_buttons&&=&RRow('tablebg','9',$page_buttons);
 $OUT.=&Table('tbg3 width100',
   &RRow('head','9','�������� ���������� �����').
   $page_buttons.
   &RRow('tablebg','ccccccccc','�',
      $sort==1? &ahref("$a&sort=2","&darr; �������, $gr") : &ahref("$a&sort=1","&uarr; �������, $gr"),
      &ahref("$a&sort=5",'����� ��������'),
      &ahref("$a&sort=3",'��������� ��������'),
      &ahref("$a&sort=4",'����� ���������'),
      '���',
      '������',
      '�����, ������. ��������',
      '����.').
   $out.
   $page_buttons
 );
 &Exit;
}

sub cards_getdata
{
 $cid=int $F{cid};
 $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='cards' AND act=2 AND fid=$cid",'������� �� �������� ����������');
 $p && &Error(&the_short_time($p->{time},$t)." �������� ���������� � $cid ���� �������.$url_list",$tend);
 $p=&sql_select_line($dbh,"SELECT * FROM cards WHERE cid=$cid LIMIT 1");
 !$p && &Error("�������� ���������� ����� � ������� $cid ����������� � ���� ������!$url_list",$tend);
}

sub cards_info
{
 !$pr_cards_create && &Error("������������ ����������.",$fend);
 &cards_getdata;
 &GoodC_Exit("���������� �� �������� ���������� ����� � $cid:".$br2.
       '��� ����������: '.($pr_cards_show_cod? &bold($p->{cod}) : '��� �� ����� ���� �������').$br.
       "�������: ".&bold($p->{money})." $gr".$br2.
       &CenterA("$scrpt&act=cards_del&cid=$cid",'�������').$br2.
       &Center($go_back)
 );
}

sub cards_del
{
 !$pr_cards_create && &Error("������������ ����������.",$fend);
 &cards_getdata;
 &Error(&CenterA("$scrpt&act=cards_delete&cid=$cid","������� �������� � $cid").$br2.'������������� �������������!',$fend);
}

sub cards_delete
{
 !$pr_cards_create && &Error("�������� �������� ���������� ����� ��� �� ���������.",$fend);
 &cards_getdata;
 $cod=$p->{cod};
 $m=$p->{money};
 $rows=&sql_do($dbh,"DELETE FROM cards WHERE cid=$cid LIMIT 1");
 $rows<1 && &Error("<span class=error>������:</span> �������� ���������� ����� � ������� $cid �� �������!",$fend);
 &ToLog("!! $Admin_UU ������� �������� ���������� ����� � $cid, �������: $m $gr");
 &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=0,cash=0,type=50,category=520,reason='$cid:$m',time=unix_timestamp()");
 &sql_do($dbh,"INSERT INTO changes SET tbl='cards',act=2,time=unix_timestamp(),fid=$cid,adm=$Admin_id","� ������� ��������� �����������, ��� �������� ���������� �������");
 &OkMess(&div('big',"������� �������� ���������� ����� � ������� $cid, ��������� $m $gr$url_list"));
 $OUT.=$tend;
 &Exit;
}

sub ssql
{
 $sth=$dbh->prepare("$sql $_[0]");
 $sth->execute;
 $OUT.=&RRow('*','lrr',$_[1],($p=$sth->fetchrow_hashref)? (int $p->{'count(*)'},int $p->{'sum(money)'}):('?','?'));
}


sub cards_report
{
 $Fyear=int $F{year};
 $Fmon=int $F{mon};
 $Fmon=$mon_now if $Fmon<1 || $Fmon>12;
 $Fyear=$year_now if $Fyear<100 || $Fyear>200;
 
 ($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
 $year_list=&Set_year_in_list($Fyear);
 
 $a="$scrpt&act=$Fact&mon=$Fmon&year=$Fyear";
 $Ff=$F{filtr};
 $Fid=int $F{id};
 $OUT.=&form('act'=>'cards_report','filtr'=>$Ff,'id'=>$Fid,"$mon_list $year_list ".&submit('��������')).$br;
 
 $Fmon--;
 $time1=timelocal(0,0,0,1,$Fmon,$Fyear); # ������ ������
 if ($Fmon<11) {$Fmon++} else {$Fmon=0; $Fyear++}
 $time2=timelocal(0,0,0,1,$Fmon,$Fyear); # ������ ��������� ������


 unless ($Ff)
   {
    $and=$F{n}>1? "AND c.r>0" : '';
    $out='';
    $sth=&sql($dbh,"SELECT SUM(c.money),u.grp FROM cards c LEFT JOIN users u ON c.alive=u.id WHERE c.atime>=$time1 AND c.atime<$time2 $and GROUP BY u.grp");
    while ($p=$sth->fetchrow_hashref)
      {
       $m=$p->{'SUM(c.money)'};
       $grp=$p->{grp};
       next unless defined $grp;
       $out.=&RRow('head','lC r',&bold($UGrp_name{$grp}),'&nbsp;','',&bold($m));
       unless ($F{n})
         {
          $sth2=&sql($dbh,"SELECT SUM(c.money),r FROM cards c LEFT JOIN users u ON c.alive=u.id WHERE u.grp=$grp AND atime>=$time1 AND atime<$time2 GROUP BY c.r");
          while ($p2=$sth2->fetchrow_hashref)
            {
             $m=$p2->{'SUM(c.money)'};
             $id=$p2->{r};
             $adm=$id==-1?'����������� � ���� ��������':
                  $id==-2?'�������� ������� ����� �������':
                  defined $A->{$id}{login}? &ahref("$a&filtr=r&id=$id",$A->{$id}{login}).' ('.$A->{$id}{name}.')':
                  "<span class=error>����� ����������� � ���� id=$id</span>";
             $out.=&RRow('*',' Lr ','',$adm,$m);
             if ($F{full_show})
               {
                $sth3=$dbh->prepare("SELECT COUNT(c.money),c.money FROM cards c LEFT JOIN users u ON c.alive=u.id WHERE u.grp=$grp AND atime>=$time1 AND atime<$time2 AND r=$id GROUP BY c.money");
                $sth3->execute;
                while ($p3=$sth3->fetchrow_hashref) {$out.=&RRow($r1,' rr  ','',$p3->{'money'}." $gr",$p3->{'COUNT(c.money)'}.' ��.','','')}
               }
            }
         }else
         {   
          $sth2=$dbh->prepare("SELECT COUNT(c.money),c.money FROM cards c LEFT JOIN users u ON c.alive=u.id WHERE u.grp=$grp AND atime>=$time1 AND atime<$time2 $and GROUP BY c.money");
          $sth2->execute;
          while ($p2=$sth2->fetchrow_hashref)
            {
             $out.=&RRow('*',' Rr ','',$p2->{'COUNT(c.money)'},$p2->{'money'});
            }
         }   
      }
    $OUT.='['.&ahref($a,'�� ������������').']&nbsp;&nbsp;['.&ahref("$a&full_show=1",'�� ������������ � ���������').']&nbsp;&nbsp;['.&ahref("$a&n=1",'�� ���������').']&nbsp;&nbsp;['.&ahref("$a&n=2",'�� ���������, �������� �������').']';
    $OUT.=&Table('tbg1',
       &RRow('tablebg','cCC',&bold_br('������ ��������'),$F{n}? '���������� ��������':'����������',"������������ �������� �� �����, $gr").
      ($out|| &RRow('row2','2',&bold_br('��� ������')))
    );
    return;
   }

 if ($Ff eq 'r')
   {
    $OUT.="<table class=tbg3 width=92%>".&RRow('head','ccc',&bold($A->{$Fid}{admin}),'<br>����������<br><br>',"�����, $gr");

    $sql="SELECT count(*),sum(money) FROM cards WHERE r=$Fid AND";
    &ssql("alive='good'",'�� �������������� �������� <span class=disabled>(�������� ����� ���� ��� �����������, �� �� ������������)</span>');
    &ssql("alive='bad'",'��������������� �������� <span class=disabled>(��� �������� �� ������������ � �� ����� ���� ������������)</span>');
    &ssql("alive<>'good' AND alive<>'bad'",'�������������� �������� <span class=disabled>(�� ���� ������ ������������ �����������)</span>');
    &ssql("alive<>'good' AND alive<>'bad' AND atime>=$time1 AND atime<$time2",'�������������� � ��������� ������');
    
    $OUT.='</table>';
    return;
   }
}

sub cards_report2
{
 $Ffull=int $F{full};	# ����� �� ���������?
 $Fmod=int $F{mod};	# 0 - �� ������� ���������, 1 - �������

 $Fyear=int $F{year};
 $Fmon=int $F{mon};
 $Fmon=$mon_now if $Fmon<1 || $Fmon>12;
 $Fyear=$year_now if $Fyear<100 || $Fyear>200;
 
 ($mon_list,$mon_name)=&Set_mon_in_list($Fmon);
 $year_list=&Set_year_in_list($Fyear);
 
 $a="$scrpt&act=$Fact&mon=$Fmon&year=$Fyear";
 $Ff=$F{filtr};
 $Fid=int $F{id};
 $OUT.=&form('act'=>'cards_report2','id'=>$Fid,'full'=>$Ffull,'mod'=>$Fmod,"$mon_list $year_list ".&submit('��������')).'<br>';
 
 $Fmon--;
 $time1=timelocal(0,0,0,1,$Fmon,$Fyear); # ������ ������
 if ($Fmon<11) {$Fmon++} else {$Fmon=0; $Fyear++}
 $time2=timelocal(0,0,0,1,$Fmon,$Fyear); # ������ ��������� ������

 %Grp_map=();
 $i=1;
 $header="<$tc>�����</td><$tc>�����</td><td style='writing-mode:tb-rl;'>&nbsp;��� ������</td>";
 $sth=&sql($dbh,"SELECT u.grp,g.grp_name FROM cards c LEFT JOIN users u ON c.alive=u.id LEFT JOIN user_grp g ON u.grp=g.grp_id WHERE c.atime>=$time1 AND c.atime<$time2 GROUP BY u.grp",'������� ��� ������ ��������, ������� ������� ������������ �������� (�������)');
 while ($p=$sth->fetchrow_hashref)
   {
    ($grp,$grp_name)=&Get_fields('grp','grp_name');
    $grp=int $grp;		# ���� ������ � �������������� ������, �� ����� ���� ������� � ������ "��� ������" ($grp=0)
    next unless $grp;		# ������� "��� ������ �� ��� ������������ ����� ������
    $Grp_map{$grp}=$i++;	# ������ $grp ����� � ������� $Grp_map{$grp}
    $header.="<td style='writing-mode:tb-rl;' nowrap>&nbsp;$grp_name</td>";
   }
 $i--;

 @f=(
   '��������, ������� ����',
   'r',
   'FROM cards c LEFT JOIN users u ON c.alive=u.id LEFT JOIN admin a ON c.r=a.id ',
   'c.r>0 GROUP BY c.r,u.grp',

   '��������, ������� ���� ������� ����� ������� �',
   'admin_sell',
   'FROM cards c LEFT JOIN users u ON c.alive=u.id LEFT JOIN admin a ON c.admin_sell=a.id ',
   'c.admin_sell>0 AND r=-2 GROUP BY c.admin_sell,u.grp',

   '�������, ������� ���� ������� ����� ������� �',
   'admin_sell',
   'FROM cards c LEFT JOIN users u ON c.alive=u.id LEFT JOIN admin a ON c.admin_sell=a.id ',
   'c.admin_sell>0 AND r=-1 GROUP BY c.admin_sell,u.grp'
 );
 
 $cell=$Ffull? "$td valign=top" : $td;
 while ($mess=shift @f)
  {
   $mess.=$Fmod? ' ������� � ��������� �����' : ' ������������ � ��������� �����';
   $mess.='. � ������� ��������� �������� � ���� '.&commas('�������:����������') if $Ffull;
   $OUT.=&bold($mess).'<br><br>';
   $f=shift @f;
   $out='';
   %sum_cells=();
   $last_r=0;

   $sql=shift @f;
   $sql.=$Fmod? "WHERE c.time_sell>=$time1 AND c.time_sell<$time2 AND " : "WHERE c.atime>=$time1 AND c.atime<$time2 AND ";
   $sql.=shift @f;
   $sql=$Ffull? "SELECT COUNT(c.money),c.$f,u.grp,a.admin,a.office,c.money $sql,c.money" : "SELECT SUM(c.money),c.$f,u.grp,a.admin,a.office $sql";

   $sth=&sql($dbh,$sql);
   while ($p=$sth->fetchrow_hashref)
     {
      ($r,$grp,$m)=&Get_fields($f,'grp',);
      if ($r!=$last_r)
        {
         if ($last_r)
           {
            $out.=&PRow('*')."<td>$admin</td><$td class=disabled>$noffice</td>";
            for (0..$i) {$out.="<$cell>".($cells[$_]||'&nbsp;').'</td>'};
            $out.='</tr>';
           }  
         $last_r=$r;
         $admin=$p->{admin};
         $office=$p->{office};
         $noffice=$Offices{$p->{office}};
         @cells=();
        }
      $n=int $Grp_map{$grp};
      $cells[$n]=$Ffull? $cells[$n].($p->{money}+0).':'.$p->{'COUNT(c.money)'}.'<br>' : $cells[$n]+$p->{'SUM(c.money)'};
      $sum_cells{$office}[$n]+=$p->{'SUM(c.money)'} unless $Ffull;
     }
  
   if ($last_r)
     {
      $out.=&PRow('*')."<td>$admin</td><$td class=disabled>$noffice</td>";
      for (0..$i) {$out.="<$td>".($cells[$_]||'&nbsp;').'</td>'};
      $out.='</tr>';
     }
   
   foreach $o (keys %sum_cells)
     {
      $out.="<tr class=title><td>&nbsp;</td><$td>$Offices{$o}</td>";
      $out.="<$td>".($sum_cells{$o}[$_]||'&nbsp;').'</td>' foreach (0..$i);
      $out.='</tr>';
     }

   foreach $o (keys %sum_cells)
     {
      $s=0;
      $s+=$sum_cells{$o}[$_] foreach (0..$i);
      $out.="<tr class=head><$td colspan=2><b>����� $Offices{$o}</b></td><td colspan=".($i+1)."><b>$s</b></td></tr>";
     }

   $OUT.=$out? &Table('tbg1 width100',"<tr class=head>$header</tr>$out").'<br>' : &div('message','��� ������');
  }
}

sub cards_help
{
}

sub show_cid
{
 my ($start_cid,$len,$money,$r,$i1,$i2,$i3)=@_;
 my $end_cid=$start_cid+$len-1;
 my $admin=$r==-1? '������� � ���� �������' : $A->{$r}{admin} || "<span class=error>����������� ������ � id=$r</span>";
 return &RRow('*','llll',$money,"$start_cid .. $end_cid",$len,$admin);
}

sub cards_list
{
 $i=$last_alive=$last_money=$start_cid=$last_r=0;
 $out='';
 $sth=&sql($dbh,"SELECT * FROM cards ORDER BY cid");
 while ($p=$sth->fetchrow_hashref)
   {
    ($cid,$money,$alive,$r,$admin_sell)=&Get_fields('cid','money','alive','r','admin_sell');
     $r=$admin_sell if $r!=-1 && $admin_sell;
     $start_cid||=$cid;
     $last_money||=$money;
     $last_r||=$r;
     $alive=1 if int($alive)>0;
     $last_alive||=$alive;
     next if $cid==($start_cid+$i) && $money==$last_money && $r==$last_r;
     $out.=&show_cid($start_cid,$i,$last_money,$last_r);
     $last_r=$r;
     $last_money=$money;
     $last_alive=$alive;
     $start_cid=$cid;
     $i=0;
    }
     continue
    {
     $i++;
    }

 $out.=&show_cid($start_cid,$i,$money,$last_r) if $start_cid;
 $OUT.=&Table('tbg3',&RRow('head','cccc',"�������, $gr",'��������','����','� ������').$out) if $out;
}

1;
