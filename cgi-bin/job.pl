#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_workers or &Error('������ � ������� ���������� ����������� ��� ��������.');
&LoadJobMod;

# ! ����� ����� ��������� ������� ��� ��������, � ������� � ���� �������� ������
$Fact=$F{act};                                                                          
$Fid=int $F{id};
$Fidjob=int $F{idjob};

%subs=(
 'setjob'	=> \&workers_menu,	# ������ �������
 'setjobnow'	=> \&workers_menu,
 'deljob'	=> \&workers_menu,	# �������� �������
 'endjob'	=> \&workers_menu,
 'endjobnow'	=> \&workers_menu,
 'setcstate'	=> \&workers_menu,	# ��������� ��������� ��� ���������� ������
 'showjob'	=> \&workers_menu,	# ����� ������ ������� �������
 'come'		=> \&workers_menu,	# ������/��������� �������� ���� ���������
 'grafik'	=> \&grafik_menu,
 'history'	=> \&workers_menu,	# ������� �����
);

$W=&Get_workers();		# ������ ����������
&nJob_present_workers($W);	# ������� ���, ��� ����� �� ������

!defined($subs{$Fact}) && &Error('������. �������� �� ������.');

$OUT.="<table class='width100 pddng'><tr><td valign=top class=nav2 width=16%>";
$tend='</td></tr></table>';
 
&{ $subs{$Fact} };
$OUT.="</td><td valign=top>";
&{$Fact};
$OUT.=$tend;
&Exit;

sub check_access_2worker
{
 my ($id)=@_;
 defined($W->{$id}{name}) or &Error("�������� � ������� $id ����������� � ���� ������.$go_back",$tend);
 !$pr_oo && $W->{$id}{office}!=$Admin_office && &Error("�������� � ������� $id �������� � ������ �������� �� ������. ������ ��������.$go_back",$tend);
}

sub workers_menu
{
 $out=&ahref("$scrpt0&a=oper&act=workers",'������ ����������');
 $out.=&ahref("$scrpt&act=showjob&mod=-1",'������� �������');
 $out.=&ahref("$scrpt&act=showjob&mod=-2",'�������������� �������');
 $out.=&ahref("$scrpt&act=setjob",'������ �������') if $pr_workers_work;
 $out.=&ahref("$scrpt&act=grafik",'������');
 $out.=$br.&div('tablebg',&form('a'=>'oper','act'=>'workers',&input_t('text','',20,80).' '.&submit('�����'))).$br;
 $OUT.=&Mess3('row2',$out);
}

sub get_users_data
{
 my ($id)=@_;
 my $U;
 $pr_workers_work or &Error("��� ���� �� ������ ������� ����������.$go_back",$tend);
 if ($id>0)
   {# ������� ������� � ��������
    $U=&Get_users($id);
    defined($U->{$id}{grp}) or &Error("������ ��������� ������� ������� � id=$id.$go_back",$tend);
    $UGrp_allow{$U->{$id}{grp}} or &Error("������ ��������� � ������, ������ � ������� ��� ��������.",$tend);
    ($_)=&ShowUserInfo($id);
    return($_,$U->{$id}{cstate});
   }
    elsif ($id<0)
   {
    &Error("������� ����� id �������: $id.$go_back",$tend);
   }
    else
   {
    return('������ �� ����',0);
   }
}

sub setjob
{
 ($client_info,$cstate)=&get_users_data($Fid);
 
 if ($Fidjob)  
   {# ������ ����������� ��� ��������������� ������ �������
    $p=&check_del_job;
    ($job,@workers)=split /,/,$p->{reason};
    $#workers>=0 && &Error("�� �� ������ ������/������� ������� �.�. ��� ��� ������ ����������. �� ������ ������ �������� ���.$go_back",$tend);
    $title_mess='�� ������� �������������� � '.&the_time($p->{time}).' �������'.$br2.&form('!'=>1,'act'=>'deljob','idjob'=>$Fidjob,&submit_a('������� �������'));
   }else
   {
    $title_mess='������ ������� ����������';
   }

 $help=<<help;
<br><br><div class='row2 story'>&nbsp;&nbsp;��� ���������������� ������ �������, �������� ���������� ������
� ������ ����� ��������� ������� � ����� ������� �������� ����� ���������. ���� ��������(�) ������� � �������, ��
������� ���� ������� � ������� '�������������' (������) ����� �� ������ �������.<br>
<br>
&nbsp;&nbsp;������� ����� ���� ������ ������ ��� ����������, ������� ��������� ��������� �� ������.<br>
<br>
&nbsp;&nbsp;�� ������ ����������� ������� �� ������� - �������� ������ �������
</div>
help

 # ��� ����� ������� ������� ���, � ����������� �� �������� ��������� ������� ������ �������, ������� �������������� ��� �����
 $job=defined $F{job}? int $F{job} : (99,2,2,99,99,1,99,99,99,0,1)[$cstate];

 $sel_job='<select size=1 name=job><option value=99>���� ��� �����</option>';
 $sel_job.="<option value=$_".($_==$job && ' selected').">$jobs[$_]</option>" foreach (0 .. $#jobs);
 $sel_job.='</select>';

 $left_col=$br2.&submit_a('������ �������').$br2.
   $sel_job.$br2.
   '��������� �������� �������:'.$br.
   &input_ta('tjob',$F{tjob},28,10).$br2.
   $client_info.$br2.
   $help;

 $i=0;
 $cols=$pr_oo? 'll' : 'L'; # ���� ���� ������ � ������ ������� - ������� ������� `�����` ����� ��������� 2 ������� � ����
 $workers='';
 $sth=&sql($dbh,"SELECT * FROM j_workers WHERE state<2".(!$pr_oo && " AND office=$Admin_office")." ORDER BY office,state,name_worker");
 while ($p=$sth->fetchrow_hashref)
   {
    $i++;
    ($post)=&Get_filtr_fields('post');
    ($id,$office,$name_worker)=&Get_fields('worker','office','name_worker');
    next if !$W->{$id}{present};
    $href=&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$id",$name_worker);
    $href="<span style='white-space:nowrap;'>$href</span>";
    $workers.=&RRow('*',$cols.'cccc',
       $pr_oo? ( $Offices{$office},$href ) : ($href),
       $post,
       "<input type=checkbox name=w$id value=1 style='border:0'>",
       "<input type=checkbox name=j$id value=1 style='border:0'>",
       (!!$W->{$id}{has_jobs} && &ahref("$scrpt&act=showjob&id=-$id",'�� �������')).
         ($W->{$id}{has_jobs}>1 && "$br<span class=error>&gt; 1 �������</span>")
    );
   }

 if ($workers)
   {
    $workers=&Table('tbg1',&RRow('head','Ccc c','��������','���������','�','','�����������').$workers);
   }
    else
   {
    $workers=&MessX(&div('story',
      $i? '�� ���� �������� �� ��������������� �������� �� ������. ���������� �������� ������ ��������� ���.'.$br2.
             &ahref("$scrpt0&a=oper&act=workers",'���������� �������') :
          '� ��������� ������� ��� �� ������ ��������� � ��������� �� ������ � �� � �������'
    ));
   }

 $i=0;
 $out='';
 $tt=timelocal(0,0,5,$day_now,$mon_now-1,$year_now);
 @days=('<span class=error>�����������</span>','�����������','�������','�����','�������','�������','�������');
 foreach ('����','���','���','���','����','����','����')
   {
    $tt=$tt+3600*24; # + ����� ������
    $i++;
    $out.=&RRow('','llll',
        "<input type=radio name=add value=$i>",
        "+$i $_:",
        &the_date($tt),
        @days[localtime($tt)->wday]
    );
   }

 ($mon_list,$mon_name)=&Set_mon_in_list($mon_now);
 $right_col.=&div('row1 lft pddng','���� �� ������ �� ���� �������� - ����� ����������� ����� ������� �� �������. '.
    '� ����� ������ ������� ����������� ����� ������ �������:'.$br2.
    &Table('table1',&RRow('','l l',&input_t('day',$day_now,3,3),'',"$mon_list ".&Set_year_in_list($year_now))).$br.
    &input_t('hour','',3,3).' ��� '.&input_t('min','',3,3).' ���'.$br2.
    '�� ������ �� ������� �����, � ������� ���� �� ������:'.$br.
    &Table('table1',$out)
 );

 $OUT.=&Center(&MessX(&bold($title_mess),1,0)).$spc.
   &form('!'=>1,'act'=>'setjobnow','id'=>$Fid,'idjob'=>$Fidjob,
     &Table('tbg1',&RRow('row2','ttt',$left_col,$workers,$right_col))
   ).$br2;
}
  
sub setjobnow
{
 ($client_info,$cstate)=&get_users_data($Fid);
 $reason='';
 foreach $id (keys %$W)
   {
    next if !$pr_oo && $W->{$id}{office}!=$Admin_office;
    $h=$F{"w$id"}? ",-$id": $F{"j$id"}? ",$id" : '';
    next unless $h;
    $reason && $office!=$W->{$id}{office} && &Error("������� �� ����� ���� ������ ���������� �� ������ �������.$go_back",$tend);
    $office=$W->{$id}{office};
    $reason.=$h;
   }

 $office=$Admin_office unless $reason; # ���� �� ������� �� �������� �� ������ ���������, �� ������� ������������� � ������ � ������� �������� �����

 $Fjob=int $F{job};
 $Ftjob=&trim(&Filtr_mysql($F{tjob}));
 $Fjob==99 && $Ftjob eq '' && &Error("��� ������� `���� ��� �����` ���������� ��������� ���� `��������� �������� �������`.$go_back",$tend);

 if ($reason)
   {# ��������� ������� - ��� �������, � �� ������� ������� (�����)
    $tt='unix_timestamp()';
   }else
   {# ����� �������, ������� ����� ��������� �������
    $add=int $F{add};
    if ($add>0)
      {# ������� �� ����, � �������� � ����
       $day=$day_now;
       $mon=$mon_now;
       $year=$year_now;
      }else
      {
       $day=int $F{day};
       $mon=int $F{mon};
       $year=int $F{year};
       $add=0;
      }

    eval{$tt=timelocal(0,$F{min} eq ''? localtime($t)->min : int $F{min},int $F{hour}||localtime($t)->hour,$day,$mon-1,$year)};
    $@ && &Error("����� ������� �� ����������� �.�. ���� ������ �������.$go_back",$tend);
    $tt+=$add*3600*24; # ���� ���������� ����� ������
    $tt<($t-120) && &Error("����� ������� �� ����������� �.�. ��������������� ����� ������ ������� ����������� ���� ��������� � �������.$go_back",$tend);
   } 

 # � sql �� ������������ $Apay_sql �.�. ���� ����� ����������� �����
 $sql="mid=$Fid,reason='$Fjob$reason',coment='$Ftjob',time=$tt,office=$office,admin_id=$Admin_id,admin_ip=INET_ATON('$ip')";
 $rows=$Fidjob? # ������� ������ ������� � ���������� �������
    &sql_do($dbh,"UPDATE pays SET $sql WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1") :
    &sql_do($dbh,"INSERT INTO pays SET $sql,category=460,type=50,cash=0");

 $rows<1 && &Error("������� ���������� �� ������ - ���������� ������.$go_back",$tend);

 $out=&div('big',$reason? '������� ���������� ������' : '����� ������� �����������');
 $out.=!!$Fid && $br.&Center(&div('nav',&ahref("$scrpt0&a=user&id=$Fid",'������ �������').
       &ahref("$scrpt0&a=operations&act=print&id=$Fid",'����� ��������')));
 &OkMess($out);
}

sub deljob
{# �������� ������� (������ ���� ��� ����� �������)
 $pr_workers_work or &Error("��� ���� �� ������/��������/������ ������� ����������.$go_back",$tend);
 $p=&check_del_job;
 $id=$p->{mid};
 if ($id)
   {
    $U=&Get_users($id);
    $grp=$U->{$id}{grp};
    defined($grp) or &Error("������� id=$Fidjob ������� � �������������� ��������. ���������� ������������� �������� ��������������.$go_back",$tend);
    $UGrp_allow{$grp} or &Error("������ ��������� � ������, ������ � ������� ��� ��������. ������� �� ����� ���� ��������.$go_back",$tend);
   } 
 ($job,@workers)=split /,/,$p->{reason};
 $#workers>=0 && &Error("������� �� ����� ���� ������� �.�. ��� ��� ������ ����������. �� ������ ������ �������� ���.$go_back",$tend);
 $rows=&sql_do($dbh,"DELETE FROM pays WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1");
 &Error("������� �� ������� - ������ ��� ���������� sql-�������. �������� ���� �� ������� ������ ������ ����� �������� �������� � ������ ��������.$go_back",$tend) if $rows<1;
 &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=2,time=unix_timestamp(),fid=$Fidjob,adm=$Admin_id",'� ������� ��������� �����������, ��� ������� �������');
 &OkMess(&div('big','������� �������'));
}

sub check_del_job
{
 my $p=&sql_select_line($dbh,"SELECT p.*,a.admin FROM pays p LEFT JOIN admin a ON a.id=p.admin_id WHERE p.id=$Fidjob AND p.type=50 AND category=460 LIMIT 1");
 return($p) if $p;
 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$Fidjob");
 $p && &Error("������� id=$Fidjob ��� �������� ��� �����������.$go_back",$tend);
 $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='pays' AND act=2 AND fid=$Fidjob",'��������� �� �������');
 $p or &Error("������� id=$Fidjob �� ����������.$go_back",$tend);
 $tt=&the_short_time($p->{time},$t);
 &Error(($tt=~/ /? $tt : "������� � $tt")." ������� � $Fidjob ���� �������.",$tend);
}

sub endjob
{ 
 $p=&check_del_job;
 $mid=$p->{mid};
 ($job,@workers)=split /,/,$p->{reason};
 $out='';
 foreach $w (@workers)
   {
    $wid=abs int $w;
    next unless $W->{$wid}{name};
    !$pr_oo && $W->{$wid}{office}!=$Admin_office && &Error("�� �� ������ ������� �������, ��������� ��� ��������� �� ������� ���� ���� �������� �� ������ ������. ".
       "��������� ������� ����� ������������� �� ����� ������ (���� � ���� ���� ������ � ������� ������ �������) ���� ������������� � ������� ������ �� ����� ��������.",$tend);
    $out.=&RRow('*','lc',
       $W->{$wid}{url}.($w<0 && ' (�������������)'),
       "<input type=checkbox name=w$wid value=1>"
    );
   }

 $out=&Table('tbg1',&RRow('head','cc','��������','���� �� ���������').$out).$br if $out;
 $out.='����������� � ����������� ������:'.$br.
   &input_ta('coment','',40,8);

 $joblevel='������ ���������� ������:'.$br2.'<select size=1 name=level>';
 $joblevel.="<option value=$_>$joblevel[$_]</option>" foreach (0..$#joblevel);
 $joblevel.='</select>';

 if ($mid)
   {
    ($userinfo)=&ShowUserInfo($mid);
    $userinfo="������ �������, � ������� ������� �������:".$br2.$userinfo.$br2;
   }else
   {
    $userinfo='';
   }

 $OUT.=$br.&div('message cntr',&bold_br('�������� �������').$br2.
     &form('!'=>1,'act'=>'endjobnow','idjob'=>$Fidjob,
       &Center(&Table('',&RRow('','t t',$out,'',$userinfo))).
       $joblevel.$br2.
       &submit_a('��������� ���������� �������').$br2
   )
 );
}

sub endjobnow
{
 $p=&check_del_job;
 $mid=$p->{mid};
 $time=$t-$p->{time};
 $h=int $F{level};
 $h=0 if $h<0;
 # ���������, ������� ����� ����� `���������`
 $h.=(!!$F{"w$_"} && ",$id") foreach (keys %$W);

 $reason=$p->{reason};
 $h="$reason#$time,$p->{time},$h";
 $coment="�����, �������� �������: ".&Filtr($p->{admin})."\n";
 $coment.="����������� ��� ���������� �������: ".&Filtr_mysql($p->{coment})."\n\n" if $p->{coment};
 $coment.="����������� ��� �������� ������: ".&Filtr_mysql($F{coment}) if $F{coment};

 # ������ ������ ������� �� ������ ���� ����� ������� ����������� ���-�� ��� ������� ��������� �������
 $rows=&sql_do($dbh,"UPDATE pays SET category=461,admin_id=$Admin_id,admin_ip=INET_ATON('$ip'),reason='$h',coment='$coment',time=$t WHERE id=$Fidjob AND type=50 AND category=460 LIMIT 1");
 $rows<1 && &Error("������� �� �������� ��� �����������. �������� ���� �� ������� ������ ������ ����� �������� ���������� �������, ���� ������ ���.$go_back",$tend);
 &OkMess(&div('big','������� ���������� �������� ��� �����������'));

 $out='';
 {
  $mid or last;
  # ������ ������� ��� �������� ��������� �������
  ($userinfo,undef,$mId)=&ShowUserInfo($mid);
  $mId or last;
  $out.=$userinfo.$br2;
  $U=&Get_users($mid);
  defined $U->{$mid}or last;
  $cstate=$U->{$mid}{cstate};
  $comment=$U->{$mid}{comment};
  $filtr_comment=&Show_all($comment);

  $h='';
  $h.='������� ����������� � ������� ������ �������:'.$br.&div('message lft',$filtr_comment).$br if $filtr_comment;
  $h.='������� ��������� ������: '.&bold($cstates{$cstate}).$br2 if $cstates{$cstate};
  $out=&Table('',&RRow('','t t',$out,'',$h)) if $h;
  $out='������� ���� ������� � ��������:'.$out;
  # ��������� ������ �������� ��������� ������ (���� ���� �����) ������ �� ����, ����
  # $cstate=9 - ������ �� �����������, ��������� � '���������', ��� ��������� ��������� ��������� �� '��� ��'
  #  79 - ��������� �������, 86 - ��������� �����������
  if ($pr_edt_usr && $PR{79} && $PR{86})
    {
     $h=$cstate==9? 5:0;
     $cstate='<select name=cstate size=1>';
     $cstate.="<option value=$_".($_==$h && ' selected').">$cstates{$_}</option>" foreach (sort {$cstates{$a} cmp $cstates{$b}} keys %cstates);
     $cstate.='</select>';
     $out.=&form('!'=>1,'act'=>'setcstate','id'=>$mid,
        "��������� ������� ������ ������� � ��������� $cstate".$br2.
        '� ���������� �����������:'.$br2.
         &input_ta('comment',$comment,70,6).$br2.
         &submit_a('���������')
        ).$br2;
     }
  $OUT.=&div('message lft',$out);   
 }   

 # ���� ��� ������ ���� ��������� ����������� ����������� �������, �� ��� ����� ������� �������� ����� ��� ����� ��� ������ ��� ���� ����������
 $i=0;
 %changed=();
 ($job,@workers)=split /,/,$reason;
 foreach $w (@workers)
   {
    $wid=abs int $w;
    $sth=&sql($dbh,"SELECT id FROM pays WHERE type=50 AND category=460 AND (reason LIKE '%,$wid,%' OR reason LIKE '%,-$wid,%' OR reason LIKE '%,$wid' OR reason LIKE '%,-$wid')");
    while ($p=$sth->fetchrow_hashref)
      {
       $id=$p->{id};
       next if $changed{$id};
       $changed{$id}++;
       $i++;
       &sql_do($dbh,"UPDATE pays SET time=$t WHERE id=$id LIMIT 1");
      }
   }

 $OUT.=&div('message lft',$br."<span class=error>��������!</span> ���������, ������� ��������� ������� �������, ��������� ����������� ��� ".
   &bold($i)." �������. ��� ���� ���� ����� ������������ ������� ����� ���������� �������".$br2) if $i;
}

# ===========================
# ��������� ��������� �������
# ===========================
sub setcstate
{
 &Error('� ��� ��� ���� �� ��������� ��������� �������.',$tend) if !$pr_edt_usr || !$PR{79} || !$PR{86}; # 79 - ��������� ���������, 86 - �����������

 $U=&Get_users($Fid);
 defined($U->{$Fid}) or &Error("�� ������� �������� ������ ������� � id=$Fid. ��������� �� ��������. ���������� � ������ ��������� �������.",$tend);
 $UGrp_allow{$U->{$Fid}{grp}}<2 && &Error("������ ��������� � ������, ������ � ������� ��� �������� (���������). ��������� ������� �� ��������.",$tend);

 $cstate=int $F{cstate};
 $comment=&Filtr_mysql($F{comment});
 $X="������������� ������� �������� � ���������: ".&Filtr_mysql($cstates{$cstate});
 $X.="\n".($comment? "����������� ������� ��: $comment":"����������� ������");
 $rows=&sql_do($dbh,"UPDATE users SET cstate=$cstate,comment='$comment' WHERE id=$Fid LIMIT 1");
 $rows<1 && &Error("��������� ������� �� �������� - ���������� ������.�������� ��������� �������.",$tend);

 &sql_do($dbh,"INSERT INTO pays SET $Apay_sql,mid=$Fid,type=50,reason='$X',category=410,time=$ut");

 &OkMess('��������� ������� �������� � '.&bold($cstates{$cstate}).$br2.&CenterA("$scrpt0&a=user&id=$Fid",'������ �������'));
}
  
sub showjob
{
 $out=&nJob_ShowJobBlank($F{id},$F{mod}); # int ���������� �� ���� - undef ����� ��������
 if ($Fid<0)
   {
    $wid=-$Fid;
    $OUT.=&div('message',"������, ������� � ������ ������ �������� ".
      &ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",'�������� '.$nJob_W->{$wid}{name}));
   }else
   {
    $U=&Get_users($Fid) if $Fid;
    $OUT.=&div('message',(!!$Fid && '��� ������� '.&ahref("$scrpt0&a=user&id=$Fid",$U->{$Fid}{fio_o}).$br).(
      $F{mod}==-1? "��� ������, ������� ����������� � ������ ������" :
      $F{mod}==-2? "�������������� ������� �� �������" :
      defined($F{mod})? "�������������� ������� ���� ".&commas($jobs[int $F{mod}]) :
      "��� ������� � �������������� �������")
    );
   }
 $out or &Error('�� �������.',$tend);
 $OUT.=$out;
}  

# ===============================================
# ������/���� � ���� (������/����� ��������� ���)
# ===============================================

sub come
{
 $pr_worker_come or &Error("��� �� ��������� �������������� ������/��������� ��������� ��� ���������.$go_back",$tend);
 &check_access_2worker($Fid);

 $direction=int $F{direction};
 @name_direction=$direction? ('���������','���������','��������'):('������','������','�����');

 $W->{$Fid}{present} && !$direction && &Error("�������� $W->{$Fid}{url} ��� ��������������� �������� �� ������ ".&the_time($W->{$Fid}{come_time}).$go_back,$tend);
 !$W->{$Fid}{present} && $direction && &Error("�������� $W->{$Fid}{url} �� ��������������� ��� �������� �� ������, ������� �� �� ������ �������� ��������� ��������� ���.$go_back",$tend);
 $W->{$Fid}{has_jobs} && $direction && &Error("�������� $W->{$Fid}{url} � ������ ������ �� �������, ���������� ������ �������� ��������� �������, ����� ��������� ��������� ���.".$br2.
    &ahref("$scrpt0&a=job&act=showjob&id=-$Fid",'�������� ������� ���������').$go_back,$tend);

 ($office)=&Get_fields('office');

 if ($F{yes})
   {
    $category=$direction? 466:465;
    $tt=int $F{time};
    $tt=10 if $tt<0 ||$tt>10; # �� ���������
    $tt*=60;
    if (defined($W->{$Fid}{come_time}) && $W->{$Fid}{come_time}>=($t-$tt))
      {# ������� �������� ������/���� �������������� �� ����������/������ ����������� ��������
       $tt=0;
       $OUT.=&div('message',&bold('��������������:')." �� ��������� �������� $name_direction[0] �������� ��� �������� ������ ��� ��������� ����������� ������ ��� ��������� ��������� ���. ����� ����������� � ������� ��������.").$br;
      }
    $reason=&trim(&Filtr_mysql($F{comment}));
    $rows=&sql_do($dbh,"INSERT INTO pays SET mid=-$Fid,type=50,$Apay_sql,category=$category,reason='$reason',coment='',cash=0,time=unix_timestamp()-$tt");
    $rows<1 && &Error("����������� $name_direction[1] ��������� ��� ��������� $W->{$Fid}{url} �� ���������.",$tend);
    &OkMess("����������� $name_direction[1] ��������� ��� ��������� $W->{$Fid}{url} ���������.".$br2.
            "����� 10 ������ ���������� ������� �� �������� ��������� ������ ����������.",$tend);
    $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$scrpt0&a=oper&act=workers"'>};
    return;
   }

 $timelist='<select size=1 name=time><option value=0>� ������ ������</option>';
 foreach $i ('1�','2�','3�','4�','5&nbsp;&nbsp;&nbsp;','7&nbsp;&nbsp;&nbsp;','10 ') {$i=~/^(\d+)(.+)$/; $timelist.="<option value=$1>$1 �����$2&nbsp;����� (".&the_time($t-$1*60).")</option>"}
 $timelist.="</select>";

 $OUT.=&div('message cntr',$br2.&form('!'=>1,'act'=>'come','direction'=>$direction,'yes'=>1,'id'=>$Fid,
   "�������� $W->{$Fid}{url} $name_direction[2] �������� ���� $timelist".$br2.
   '�������������� �����������:'.$br.&input_ta('comment','',70,4).$br2.
   &submit_a('�����������').$br2));

 $OUT.=$br2.&div('message','�����������: '.($direction? '�������� �����':'��������� ��� �������� ��������').
       ' �������� ���� '.&bold(&the_time($W->{$Fid}{come_time}))) if defined($W->{$Fid}{come_time});
}

# ================

sub Show_time_line
{
 $out.=&RRow('*','lclrl',$wday,$last_day,$t_list,&the_hh_mm(int $t_work/60),$reason);
 $t_work=0;
 $t_list='';
 $reason='';
}

sub Add_time
{
 my $t_add=$t_end-$t_start;
 $t_work+=$t_add;
 $sum_time+=$t_add;
 $t_list.=&the_hour($t_start).' - '.&the_hour($t_end).$br;
}

# === ������� ��������� � ����� ===
sub history
{
 &check_access_2worker($Fid);

 $mon=int $F{mon} || $mon_now;
 $year=int $F{year} || $year_now;
 ($mon_list,$mon_name)=&Set_mon_in_list($mon);
 $year_list=&Set_year_in_list($year);

 $t1=timelocal(0,0,0,1,$mon-1,$year);				# ������ ������
 $t2=timelocal(0,0,0,1,$mon>11?0:$mon,$mon>11?$year+1:$year)-1;	# ����� ������

 $OUT.=&MessX(&form_a('act'=>$F{act},'id'=>$Fid)."������� ����� $W->{$Fid}{url} �� $mon_list $year_list <input type=submit value='��������'></form>").$br;

 $last_day=0;
 $t_last=0;
 $t_start=0;
 $h=0;
 $err_mess='';
 $sum_time=0;
 $work_day=0;
 $out='';
 $reason='';
 $sth=&sql($dbh,"SELECT * FROM pays WHERE mid=-$Fid AND type=50 AND category IN (465,466) AND time>$t1 AND time<$t2 ORDER BY time");
 while ($p=$sth->fetchrow_hashref)
   {
    $tt=$p->{time};
    $category=$p->{category};
    if ($category==$h)
      {
       $err_mess.="��������. ������ � ������. ".&the_time($tt).($h==465? ' ��������� ������ ��������� ��� ��� ��������� �����������':' ��������� ��������� ��������� ��� ��� ��� ������').$br;
      }

    $t1=localtime($tt);
    $day=$t1->mday;
    if ($day!=$last_day)
      {
       if ($h==3)
         {# ����� ����, � � ������� �� �������� ����. �������, ��� ������� �������� ���� ��������� �  23:59
          $t_end=timelocal(59,59,23,$last_day,$mon-1,$year);
          &Add_time;
          $t_start=timelocal(0,0,0,$day,$mon-1,$year);
         }
       &Show_time_line if $last_day;
       $last_day=$day;
      }
    $h=$category;
    $wday=('<span class=error>�����������</span>','�����������','�������','�����','�������','�������','<span class=error>�������</span>')[$t1->wday];

    if ($h==465)  
      {# ����� �� ������
       $t_start=$tt;
       next;
      }

    # ���� � ������
    unless ($t_start)
      {# ��� ������ �� ������ � ���� ��� - �������� ��� � ���������� (��� ���� �����, ���� ������ � ����). �������, ��� ���� ������� � 0 �����
       $t_start=timelocal(0,0,0,$day,$mon-1,$year);
      }
    $t_end=$tt;
    $reason.='(� '.&the_hour($tt).') '.&Show_all($p->{reason}).$br2 if $p->{reason};
    &Add_time;
   }

 if ($category==465)
   {# �������� ����� �� ������ (������� � ����� ����) � �������� �� ��� ���
    $t_list.=&the_hour($tt).' -&nbsp;&nbsp;...';
    $OUT.='�����������: � ������ ������ �������� �������� �� ������. ����� �� ��������� ����� ����� ���������� ����� ���� ��� �� �������� ��������� ��������� ���.'.$br2;
   } 
 &Show_time_line if $last_day;
 $OUT.="<table class='width100'><tr><$tc valign=top>";
 if ($out)
   {
    $OUT.="<table class='tbg3 width100'>".
      &RRow('head','ccccc','���� ������','����','������ - ���������','����� �����','�����������').$out.
      &RRow('head',' Lr ','','�����',&the_hh_mm(int $sum_time/60),'').'</table>';
   } else
   {
    $OUT.=&MessX('��� ������ ������������ �� ��������� �����',1)
   }   
 $OUT.=$err_mess;  
#    "<tr class=head><td colspan=3>����� ������� ����</td><td>$work_day</td></tr></table>"  
# $OUT.="</td><$tc valign=top>";

 push @jobs,'���� ��� �����';
 $other_job_num=$#jobs; # ������ '���� ��� �����'
 $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=461 ORDER BY time"); # ������ ����������� �������
 $sth->execute;
 while ($p=$sth->fetchrow_hashref)
   {
    ($w1,$w2)=split /#/,$p->{reason};
    $w1.=',';
    next if $w1!~/,$Fid,|,-$Fid,/;
    @workers=split /,/,$w1;
    $job=shift @workers;
    $job=$other_job_num unless $jobs[$job]; # ���� ��� ����� ����������� � ������, ������� '���� ��� �����'
    $n=$#workers; # ���������� ���������� � ������� -1
    $Job{$job}++;
    $w2=~/^(\d+),(\d+),(\d+)(.*)$/;
    $w3=$1; # ����� ���������� ������
    $w4=$2; # ����� ���������� �������
    $w5=$3; # ������ ���������� ������
    $w2="$4,";
    #  $OUT.=$p->{'id'}." === ".$p->{'reason'}."<br>w2=$w2  w3=$w3<br>";
    $Job_kill{$job}++ if $w2=~/,$Fid,/; # ��������� ���� ���������
    if ($w5==5)
       {# ������� ���� ��������
        $Job_3{$job}++;
        $Job_3time{$job}+=$w3;
       }
        elsif ($n)
       {# ������� �������� �� ����
        $Job_2{$job}++;
        $Job_2time{$job}+=$w3;
       }
        else
       {# ������� �������� �� ���
        $Job_1{$job}++;
        $Job_1time{$job}+=$w3;
       }
    $Job_rez[$w5]++;
    $Job_time[$w5]+=$w3;
   }
 $OUT.=$br."<table class='tbg3 width100'>";    
 $OUT.="<tr class=head><$tc>��� �������</td><$tc colspan=2>�������� ��������������</td><$tc colspan=2>�������� � �������</td><$tc colspan=2>���������� �������</td><$tc>���������� ���������</td></tr>";
 $OUT.="<tr class=head><td>&nbsp;</td><$tc>�������</td><$tc>����� �����</td><$tc>�������</td><$tc>����� �����</td><$tc>�������</td><$tc>����� �����</td><td>&nbsp;</td></tr>";
 $n=-1;
 foreach $job (@jobs)
   {
    $n++;
    $Job{$n} or next;
    $j1=$Job_1{$n}+0;
    $j2=$Job_2{$n}+0;
    $j3=$Job_3{$n}+0;
    $t1=$Job_1time{$n}+0;
    $t2=$Job_2time{$n}+0;
    $t3=$Job_3time{$n}+0;
    $jk=$Job_kill{$n}+0;
    $OUT.=&PRow."<td>$job</td><$tc>$j1</td><$tc>".int($t1/3600).":".($t1/60 % 60)."</td><$tc>$j2</td><$tc>".int($t2/3600).":".($t2/60 % 60)."</td><$tc>$j3</td><$tc>".int($t3/3600).":".($t3/60 % 60)."</td><$tc>$jk</td></tr>";
    $j1s+=$j1; $j2s+=$j2; $j3s+=$j3;
    $t1s+=$t1; $t2s+=$t2; $t3s+=$t3;
    $jks+=$jk;
   }
 $OUT.="<tr class=head><td>�����".
     "</td><$tc>$j1s</td><$tc>".int($t1s/3600).":".substr('0'.($t1s/60 % 60),-2,2).
     "</td><$tc>$j2s</td><$tc>".int($t2s/3600).":".substr('0'.($t2s/60 % 60),-2,2).
     "</td><$tc>$j3s</td><$tc>".int($t3s/3600).":".substr('0'.($t3s/60 % 60),-2,2).
     "</td><$tc>$jks</td></tr>";
 $OUT.="</table>";   
 $OUT.=$br."<table cellpadding=2 cellspacing=1 class=tablebg>";    
 $OUT.="<tr class=head><$tc>����� ����������� �������</td><$tc>����� ����� ����������</td><$tc>������� ����� ���������� ������ �������</td></tr>";
 $ts=$t1s+$t2s;
 $js=$j1s+$j2s;
 $OUT.="<tr class=row1><$tc>$js</td><$tc>".int($ts/3600).":".substr('0'.($ts/60 % 60),-2,2)."</td><$tc>";
 $OUT.=$js ? int($ts/$js/3600).":".substr('0'.($ts/$js/60 % 60),-2,2) : '0:00';
 $OUT.="</td></tr>";
 $OUT.="<tr class=head><td colspan=3>�����������: ���������� ������� �� ������ � ����������</td></tr>" if $t3s;
 $OUT.="</table>";   
 $OUT.=$br."<table cellpadding=2 cellspacing=1 class=tablebg>";    
 $OUT.="<tr class=head><$tc>��������� ���������� �������</td><$tc>���������� �������</td><$tc>����� ����������</td></tr>";
 $i=-1;
 foreach $w5 (@Job_rez)
   {
    $i++;
    next unless $w5;
    $OUT.=&PRow."<td>".($joblevel[$i] || '<b>����������!</b>')."</td><td>$w5</td><$tc>".int($Job_time[$i]/3600).":".($Job_time[$i]/60 % 60)."</td></tr>";
   }
 $OUT.='</table>';
 $OUT.='</td></tr><table>';  
}

# =============================================
sub grafik
{
 $t1=timelocal(0,0,0,1,$mon-1,$year); # ������ ������
 $t2=timelocal(0,0,0,1,$mon>11?0:$mon,$mon>11?$year+1:$year)-1; # ����� ������

 $OUT.="<div class=message>".($mod>1?'������� ���������� �������':$mod?'�������, ������������� � ������� ������':'������ �������������� �������').'</div>';
 $h=$mod>1?461:460;
 $sth=$dbh->prepare("SELECT * FROM pays WHERE type=50 AND category=$h AND time>=$t1 AND time<=$t2");
 $sth->execute;
 %Jobs=();
 while ($p=$sth->fetchrow_hashref)
   {
    ($mid,$workers,$tt)=Get_fields('mid','reason','time');
    ($job,@workers)=split /,/,$workers;
    next if $#workers>=0 && !$mod; # ������� ����� �������, � ��� ������������� �������
    next if $#workers<0 && $mod==1; # ������� ����� ������������� �������, � ��� ����� �������
    $tt=localtime($tt);
    $min=$tt->min;
    # ����������� ����� ������� ���, ����� ��� ���� ������ �������� ����
    $min=$min>45?45 :$min>30?30 :$min>15?15: 0;
    $tt=timelocal(0,$min,$tt->hour,$tt->mday,$tt->mon,$tt->year);
    $Jobs{$job}{$tt}++; # ���������� ������� � ������������ �������� ����
   }

 $tt=localtime($t2);
 $day=$mon==$mon_now && $year==$year_now? $day_now : $tt->mday;
 $min=localtime($t)->min;
 $min=$min>45?45 :$min>30?30 :$min>15?15: 0; # ������� ������ ������� 15
 $red_time=timelocal(0,$min,localtime($t)->hour,$day_now,$mon_now-1,$year_now); # ������� �����, ������� ���� ���� �������� ������� ������
 $max_job=$#jobs;
 $max_day=&GetMaxDayInMonth($mon,$year); # ���� � ������
 while ($day>0 && $day<=$max_day) 
   {
    $tt=timelocal(0,0,0,$day,$mon-1,$year); # ������ �����
    $wday=('<span class=error>�����������</span>','�����������','�������','�����','�������','�������','�������')[localtime($tt)->wday];
    $i=24*4; # 24 ���� �� ������ ������� � ����
    $OUT.="<table class='tbg1 width100'><tr class=tablebg><$tc colspan=".($i+1).">$wday <b>$day</b> $mon_name</td></tr><tr class=head><td>���</td>";
    $OUT.="<$tc colspan=4>$_</td>" foreach (0..23);
    $OUT.='</tr>';
    %out=();
    while ($i--)
      {
       $j=0;
       foreach (@jobs,'')
         {
          $job=$j<=$max_job? $j:99;
          $out{$job}.=($red_time!=$tt?'<td>':'<td class=rowoff2>').($Jobs{$job}{$tt}||'&nbsp;').'</td>';
          $j++;
         }
       $tt+=900; # ��� 15 �����
      }

    $j=0;    
    foreach (@jobs,'���� ��� �����')
      {
       $job=$j<=$max_job? $j:99;
       $OUT.="<tr><td><b>$_</b></td>$out{$job}</tr>";
       $j++;
      }
    $OUT.='</table>'.$br;
    $day=$mod? $day-1:$day+1;
   }  
}

sub grafik_menu
{
 &workers_menu;
 $mod=int $F{mod};
 $mon=int $F{mon} || $mon_now;
 $year=int $F{year} || $year_now;
 ($mon_list,$mon_name)=&Set_mon_in_list($mon);
 $year_list=&Set_year_in_list($year);
 $OUT.=&Mess3('row2',
   &form('act'=>'grafik','mod'=>$mod,'������ ��'.$br.$mon_list.' '.$year_list.' '.&submit('OK')).$br.
   &ahref("$scrpt&act=grafik&mod=0&mon=$mon&year=$year",'��������������').
   &ahref("$scrpt&act=grafik&mod=1&mon=$mon&year=$year",'�������������').
   &ahref("$scrpt&act=grafik&mod=2&mon=$mon&year=$year",'�����������')
 );
}

1;
