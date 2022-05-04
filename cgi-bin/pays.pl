#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

&LoadMoneyMod;
&LoadPaysTypeMod;

$default_act='payform';

%subs=(
 'show'			=> \&pay_show,		# ����� ����� ���������/��������������
 'edit'			=> \&pay_edit,		# ��������������� ���������/��������
 'plzedit'		=> \&plz_edit,		# �������� ������� � �������� �������� ������
 'markanswer'		=> \&mark_answer,	# ���������� ��������� ��������� ��� "����� ���"
 $default_act		=> \&payform_show,	# ����� ����� ��� ������������� �������
 'pay'			=> \&pay_now,		# ���������������� ���������� �������
 'send'			=> \&send_money,	# �������� ���������� ����� ��������
 'mess2all'		=> \&mess_for_all,	# �������� �������������� ���������
 'set_block'		=> \&set_block,		# �������� ������������� ������, �������� ����.��������� �������
 'update_category'	=> \&update_category,	# ��������� ���������� ��������� ��������
);

$Fmid=int $F{mid};
$Fact= defined($subs{$F{act}})? $F{act} : $default_act;

&{ $subs{$Fact} };
&Exit;

sub get_pay_data
{
 $pr_pays or &Error('� ��� ��� ���� �� �������� ��������.');

 $Fid=int $F{id};
 $p=&sql_select_line($dbh,"SELECT p.*,INET_NTOA(p.admin_ip),a.admin,a.name,a.privil FROM pays p LEFT JOIN admin a ON a.id=p.admin_id WHERE p.id=$Fid",
    '��������� ������ �������, ������� ���� �� ������-������'); 

 if( !$p )
 {
    $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='pays' AND act=2 AND fid=$Fid","���� �� � ������� ��������� ���������� �� �������� ������� � id=$Fid");
    $p && &Error(&the_short_time($p->{time},$t,1)." ������ � id=$Fid ���� ������� ".($p->{adm}==$Admin_id? '����' : '������ ���������������'));
    &Error("������ ��������� ������ ������ c id=$Fid".$br2."�������� ��� ������ ����������� � ������� ��������.$go_back");
 }

 # ���� reason � coment �� ��������� �.� ����������� �������� �����, ����������� �����
 ($mid,$bonus,$type,$orig_reason,$orig_coment,$category,$adm_id,$office,$t_pay)=&Get_fields('mid','bonus','type','reason','coment','category','admin_id','office','time');

 $cash=sprintf("%.2f",$p->{cash});
 $adm_login=&Filtr_out($p->{admin}||'');		# �.� ����� ���� �������������� 
 $adm_name=&Filtr_out($p->{name}||'-');
 $admin_ip=$p->{'INET_NTOA(p.admin_ip)'};
 $pay_time=&the_time($t_pay);
 $display_admin=$adm_id? &bold($adm_login) : '�������';
 $display_admin.=" ($admin_ip)" if $admin_ip ne '0.0.0.0';

 $can_edit=$pr_edt_pays;
 $logm='';

 if( $Admin_id!=$adm_id )
 {  # ����� ������
    if( $pr_edt_pays && !$pr_edt_foreign_pays )
    {
       $logm.='<li>�������� ������ �������� �.�. ������ ������� �� ����.</li>';
       $can_edit=0;
    }
    $privil=$p->{privil}.',';
    if ($can_edit && $privil=~/,13,/)
    {  # ���������� 13 - ��������� �������������� ����� �������� ������� ���������������� 
       $logm.='<li>������� ������ ����������� ������, ������� ����� ����������� ����� �� �� ��������������.';
       $logm.=$pr_SuperAdmin? ' ��� ��������� �.�. �� ����������</li>' : '</li>';
       $can_edit=0 unless $pr_SuperAdmin;
    }
 }

 if( $mid>0 )
 {  # ������ ������� � ��������
    ($filtr_name_url,$grp,$mId)=&ShowUserInfo($mid);
    if( $mId )
    {
       &Error('��� �� �������� ������ � ����������� ������.') if $UGrp_allow{$grp}<2; # ��� ������������ �.� ��� �� 99% ������
    }
     elsif( $pr_SuperAdmin )
    {
       $filtr_name_url=&bold("������������� � ���� ������ (id=$mid)");
    }
     else
    {
       &Error("������ ������ ��������� �� �������������� � ���� �������. � ��� ����� ������ ������ ������������������.$go_back");
    }
 }
  elsif( $mid )
 {  # ������ ������� � ����������
    $wid=-$mid;
    $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$wid",'��������� ������ ���������');
    if( $p )
    {
       &Error("������ ������� � ����������, ������� �������� � ����������� ��� ��� ������.$go_back") if !$pr_oo && $p->{office}!=$Admin_office;
       $worker_name=$p->{name_worker};
       $filtr_name_url='�������� ';
    }
     elsif( $pr_oo )
    {
       $worker_name='�������� ����������� � ��';
       $filtr_name_url='';
    }
     else
    {
       &Error('������ ��������� ������ ��������� � ������� ������� ����������� ������. ��-�� ����� ���������� ��������� ���� �� � ��� ����� �� ��������. '.
              '��� ������ ����� �������� ����� � ������� ������ � ������ �������.');
    }
    $filtr_name_url.=&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$worker_name);
 }
  elsif( !$pr_oo && $office!=$Admin_office )
 {
    &Error('������� ������ �� ������� � ���������� �������� � ������� ������� �� ������� ������, � ��� ��� ���� �� ������ � ������� ��������.');
 }
  else
 {
    $filtr_name_url=&ahref("$scrpt0&a=payshow&act=list_categories",'����');
 }

 # area_ - ���� � ���� ��������������
 # html_ - ���� � ���� ���������

 $area_reason=' '.&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('reason',5,13);"}).
   "<br><textarea rows=5 cols=50 name=reason id=reason>".&Filtr_out($orig_reason)."</textarea>";
 $area_coment=' '.&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('coment',5,13);"}).
   "<br><textarea rows=5 cols=50 name=coment id=coment>".&Filtr_out($orig_coment)."</textarea>";
 $area_bonus='';

 $html_reason=&Show_all($orig_reason);
 $html_coment=&Show_all($orig_coment);
 $html_bonus='';

 $reason_title='�����������';

 {
  if ($type==10)
  {
     $need_money=1;
     if ($mid>0)
       {
        $nm_pay='������ �������';
        $html_bonus=' <span class=data1>������</span>' if $bonus;
        $area_bonus="<input type=checkbox name=bonus value=y style='border:1;'".(!!$bonus && ' checked')."> ������";
        $reason_title='����������� ��� ��������������';
        $coment_title='�����������, ������� ����� ������';
        last if $pr_pays_create;
        $logm.='<li>� ��� ��� ���� �� ���������� �������� ��������, ������� �������������� ������ ������ ��� ����������.</li>';
        $can_edit=0;
        last;
       }
     $coment_title='�������������� �����������';
     if ($mid)
       {
        $nm_pay='������ �������� ���������';
        last if $pr_worker_pays_create;
        $logm.='<li>� ��� ��� ���� �� ���������� ������� ����������, ������� �������������� ������ ������ ��� ����������.</li>';
       }else
       {
        $nm_pay=&commas('������� ����');
        last if $pr_net_pays_create;
        $logm.='<li>� ��� ��� ���� �� ���������� ������ ����, ������� �������������� ������ ������ ��� ����������.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==20)
  {
     $need_money=1;
     $nm_pay='��������� ������';
     $area_bonus=&input_h('bonus','y');
     $reason_title='����������� ��� ��������������';
     $coment_title='�����������, ������� ����� ������';
     last if $pr_tmp_pays_create;
     $logm.='<li>� ��� ��� ���� �� ���������� ��������� ��������, ������� �������������� ������ ������ ��� ����������.</li>';
     $can_edit=0;
     last;
  }

  if ($type==30)
  {
     $need_money=0;
     $coment_title='���������';
     if ($mid)
       {
        $nm_pay='���������';
        last if $pr_mess_create;
        $logm.='<li>� ��� ��� ���� �� �������� ��������� ��������, ������� �������������� ������ ������ ��� ����������.</li>';
       }else
       {
        $nm_pay='������������� ���������';
        last if $pr_mess_all_usr;
        $logm.='<li>� ��� ��� ���� �� �������� ������������� ���������, ������� �������������� ������ ������ ��� ����������.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==40)
  {
     $need_money=1;
     $area_bonus=&input_h('bonus','y');
     $nm_pay='�������� ��������';
     if ($can_edit)
       {
        if ($category!=470 && !$pr_SuperAdmin)
          {
           $can_edit=0;
           $logm.='<li>��������� ������� �������������, ��������� ������ ��� ������� �������� ��������� ���������� �� ������ �������������� �������. '.
              '��� ���� �����-���������� ������ ������� �� ������ (��)���������������� ������� �������. ������ ����� �������/�������� ������ ����������.</li>';
          } 
        if (!$PR{19})
          {
           $can_edit=0;
           $logm.='<li>� ��� ��� ���� �� ���������� ������� ��������, ������� �������������� ������� ������� ��� ����������.</li>';
          }
       }

     $r=int $orig_reason; # id ������
     $c=int $orig_coment; # id ������

     $reason_title='����� ���������� ��������';
     $coment_title='����� ����������� ��������';

     # ������� ���������� ���� �������
     $area_reason=$br2.'<select size=1 name=reason>';
     $area_coment=$br2.'<select size=1 name=coment>';
     $sth=&sql($dbh,"SELECT * FROM admin ORDER BY admin",'������ ���������������');
     while ($p=$sth->fetchrow_hashref)
       {
        $admin=$p->{admin};
        $id=$p->{id};
        $area_reason.="<option value=$id".($r==$id? ' selected':'').">$admin</option>";
        $area_coment.="<option value=$id".($c==$id? ' selected':'').">$admin</option>";
        $html_reason=$admin if $r==$id;
        $html_coment=$admin if $c==$id;
       }
     $area_reason.='</select>';
     $area_coment.='</select>';
     last;
  }

  if ($type==50)
  {
     $need_money=0;
     $nm_pay='�������';
     if ($can_edit && !$pr_edt_events)
       {
        $can_edit=0;
        $logm.='<li>� ��� ��� ���� �� �������������� �������.</li>';
       }
     $reason_title='������ �������';
     $coment_title='�������������� �����������';
     last;
  }

  $nm_pay="����������� ��� �������, ���: $type";
  $need_money=1;
 }

 if( $can_edit && $ct_block_edit{$category} && !$pr_SuperAdmin )
 {
    $logm.='<li>��������� ������ ��������� �������������� ������ �����������</li>';
    $can_edit=0;
 } 
}

# =======================================
#	����� ��������� �������
# =======================================

sub pay_show
{
 &get_pay_data();
 if( $can_edit && !$pr_edt_old_pays )
 {
    $t_blk=$t_pay-$t+600;
    if ($t_blk<0)
      {
       $can_edit=0;
       $logm.='<li>�� ������� �������� ������ ������ ����� 10 �����.<br>���������� ����� ������� ������ �� ��������� ������������� ������ ������ ����� �������.</li>';
      }
       elsif ($t_blk<600)
      {
       $logm.="<li>����� ".($t_blk>=60 && int($t_blk/60).' ��� ').sprintf("%02d",$t_blk % 60).' ���'.
       ' �������������� ������� ����� <span class=error>�������������</span>.</li>';
      }
 }

 $out2='';
 $out1=$logm && &RRow('*','L',"<ul>$logm</ul>");
 $out1.=&RRow('*','ll','���',$nm_pay);
 $out1.=&RRow('*','ll',"��������� <span class=disabled>($category)</span>",$ct{$category}) if $ct{$category};
 $out1.=&RRow('*','ll','� ��� ������',$filtr_name_url).
   &RRow('*','ll','����� ���������',$pay_time).
   &RRow('*','ll','�����',$display_admin).
   &RRow('*','ll','��� ������',$adm_name);
 $out1.=&RRow('*','ll','�����',$Offices{$office}) if $Offices{$office};
 $out1.=&RRow('*','ll','����� �������',&bold($cash)." $gr$html_bonus") if $need_money;

 $reason_title=$ct_name_fields{$category}[0] if $ct_name_fields{$category}[0];
 $coment_title=$ct_name_fields{$category}[1] if $ct_name_fields{$category}[1];

 if ($category_subs{$category})
   {# � ������ ��������� ���� ����������� ���� reason
    ($mess,$error_mess)=&{$category_subs{$category}}($orig_reason,$orig_coment,$t_pay,$mid);
    $html_reason=$mess && &div('message',$mess);
    $reason_title='������������� ������';
   }else
   {
    $html_reason=($html_reason ne '') && &bold($reason_title).&div('message',$html_reason);
   }

 $out1.=&RRow('*','L',$html_reason) if $html_reason ne '';
 $out1.=&RRow('*','L',&bold($coment_title).&div('message',$html_coment)) if $html_coment ne '';

 if ($can_edit)
   {
    $out=$need_money? &RRow('*','ll','����� �������',&input_t('cash',$cash,10,14,' autocomplete="off"')." $gr$area_bonus") : &input_h('cash',0);
    $h=$ct_decode_mess{$category};
    if ($h)
      {
       $h=~s|#|<br>|g;
       $h=~s|\{(.+?)\}|<span class='data1 big'>$1</span>|g;
       $area_reason.=&div('story bordergrey',$h)
      }
    $area_reason.=&div('message lft',"<span class=error>�������������� ������ ��������</span>:".$br2.$error_mess) if $error_mess;
    $out.=&RRow('*','C',&bold($reason_title).$area_reason);
    $out.=&RRow('*','C',&bold($coment_title).$area_coment);
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'edit',
      &Table('tbg3',
        $out.
        &RRow('*','ll','<span class=error>������� ������</span>',"<input type=checkbox name=del value=1 style='border:1;'>").
        (!!$PR{18} && &RRow('*','ll','�� �������������� ������� �� ��������� ������',"<input type=checkbox name=dontmark value=1 style='border:1;'>")).
        &RRow('*','C','<br>'.&submit_a('�������� ������').'<br>')
      )
    );
   }else
   {
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'plzedit',
      &Table('tbg3',
       &RRow('*','l','�� ������ ������� �������������� �������������� ��������� � �������� ���������������/������� ������ ������. ���� ������� �������:').
       &RRow('*','c','<textarea rows=7 cols=38 name=reason></textarea>').
       &RRow('*','c',&submit_a('��������'))
      )
    ).'<br>';
   }

 $OUT.=&div('message cntr',&Table('','<tr><td valign=top width=50%>'.&Table('tbg3',$out1)."</td><td valign=top>$out2</td></tr>").$go_back);
}

# ===========================================
# ���������������� ���������/�������� �������
# ===========================================

sub pay_edit
{
&get_pay_data;
$can_edit or &Error("�� �� ������ �������� ����������� ������, �������: <ul>$logm</ul>$go_back");

&Error("�� ������� �������� ������ ������ ����� 10 �����. ���������� ����� ������� ������ �� ��������� ������������� ������ ������ 10 �����.".$br2.
        &bold('������ �� ��������.')) if !$pr_edt_old_pays && $t_pay<($t-600);

$ClientPaysUrl="$scrpt0&a=payshow".($mid? "&mid=$mid" : '&nodeny='.($type==50? 'event': $type==30? 'mess': 'net'));

{
 # �� ������� ������� �� ��������� ������ ���� �������� ����� ���� ��� ��������� ���������� �����: ��������/�������������� ������� -> ������� �������
 $dont_mark=($F{dontmark} && $PR{18}) || $category==502 || $category==501; 
 last if $dont_mark;
 # �������� ������ "���������� ������", ������� ����� �������� ������ ��������� ��� ���������� ������
 $sql="INSERT INTO pays SET mid=$mid,type=50,category=501,cash=0,bonus='',".
   "admin_id=$adm_id,admin_ip=INET_ATON('$admin_ip'),office=$office,time=$t_pay,coment='".&Filtr_sql($orig_coment)."',".
   "reason='$Fid:$type:$category:$cash:$bonus:".&Filtr_sql($orig_reason)."'";
 $sth=$dbh->prepare($sql);
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid};
 &DEBUG(
     &Printf('[span data2][br][][br]������ []',
       '������� ����� ������ - ��� ����� ������ ������� ������',$sql,$iid? "��������. INSERT_ID=$iid" : &bold('�� ��������')
     )
 );
 $iid or &Error("��������� ��������� ������. ������ �� ��������.$go_back");
}

{
 $F{del} or last;
 # �������� �������
 $rows=&sql_do($dbh,"DELETE FROM pays WHERE id=$Fid LIMIT 1");
 if ($rows<1 || &sql_select_line($dbh,"SELECT * FROM pays WHERE id=$Fid LIMIT 1",'��������, ��� ������ ������������� ������'))
   {
    $dont_mark or &sql_do($dbh,"DELETE FROM pays WHERE id=$iid LIMIT 1",'������ ������ ��� ��������� "������ ������� ������"');
    &Error("���������� ������. ������ � id=$Fid �� �������.");
   }

 &ToLog("$Admin_UU ������ ������ id=$Fid �� ������� ��������. mid=$mid, bonus=$bonus, cash=$cash, time=$pay_time, type=$type, category=$category");

 unless ($dont_mark)
   {# ���������� �� unix_timestamp, � $t - ��� ���� ���� ���� ���������� � ������
    &sql_do($dbh,"INSERT INTO pays SET mid=$mid,type=50,category=502,$Apay_sql,".
       "reason='$iid:0',time=$t",'������� ������� � ���, ��� ������ ���� �������');
   }

 if ($mid>0 && $need_money && $cash!=0)
   {
    $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($cash) WHERE id=$mid LIMIT 1");
    if ($rows<1)
      {
       &ToLog("! $Admin_UU ����� �������� ������� ��������� ������ ��������� ������� �������. ���������� ������ �������������");
       &Error("������ ������� �� ������� ��������, ������ ��� ��������� ������� ������� ��������� ������! ���������� ������ ������������� ������� ���������������.");
      }
   }

 &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=2,time=$t,fid=$Fid,adm=$Admin_id","� ������� ��������� ����������� �������� ������ � ������� ��������");

 &OkMess('������ ������� �� ������� ��������.'.$br2.&ahref($ClientPaysUrl,'�������� �������'));
 return;
}

# =====================
# �������������� ������

$F{reason}=~s/(\s+|\n)$//; # ������ ��������� ������� � �������� �����
$F{coment}=~s/(\s+|\n)$//;                                           

$new_reason=&Filtr_sql($F{reason});
$new_coment=&Filtr_sql($F{coment});
$new_cash=sprintf("%.2f",$F{cash}+0);
$new_category=$category;

{
 # ��������� ��������� ��� ������� ������� �� ���/������, �������������/�������������
 # ��������� ��������� � "������ ���������������" (9 - ��� ������������� �����, 109 - ������������� �����, 609 - ������������� ���, 709 - �����. ���)
 if( $type==10 )
 {  # ������
    if( $mid>0 )
    {# �������
      $new_bonus=$F{bonus}? 'y':'';
      $new_category=$new_bonus? 9 : 609;
    }else
    {
      $new_bonus='';
      $mid && $new_cash>0 && &Error("� ������ �������� ���������� �� ����������� ������������� ����� �������!$go_back");
      $new_category=$mid? 809 : 209;
    }
    $new_category+=100 if $new_cash<=0;
    last;
 }

 if( $type==20 )
 {  # ��������� ������ ������ ��������
    $new_bonus='y';
    last;
 }

 if( $type==30 )
 {  # ���������
    $new_bonus='';
    $new_cash=0;
    $new_reason=&Filtr_mysql($orig_reason) unless $mid; # ������ ������ ������ ����� �������� � ������������� ��������� (������� � �������...)
    last;
 }

 if( $type==40 )
 {  # �������� �������� ������ ��������
    $new_bonus='y';
    $new_reason=int $new_reason;
    $new_coment=int $new_coment;
    $new_category=470; # ������ ������������� ��������, ��������� ������ ��������� ����������
    last;
 }

 # ������� ��� ����������� ��� �������
 $new_bonus='';
 $new_cash=0;
}

$sql="UPDATE pays SET cash=$new_cash,bonus='$new_bonus',reason='$new_reason',coment='$new_coment',category=$new_category WHERE id=$Fid LIMIT 1";
$rows=&sql_do($dbh,$sql);
if( $rows<1 )
{
   $dont_mark or &sql_do($dbh,"DELETE FROM pays WHERE id=$iid LIMIT 1",'������ ������ ��� ��������� "������ ������� ������"');
   &Error("���������� ������. ������ �� ��������.$go_back");
}

if( !$dont_mark )
{
   &sql_do($dbh,"INSERT INTO pays SET mid=$mid,type=50,category=502,$Apay_sql,reason='$iid:$Fid',time=$t",'������� ������� � ���, ��� ������ ���� ��������');
}

&ToLog("$Admin_UU �������� ������ id=$Fid � ������� ��������.");
  
if ($mid<=0 || !$need_money || $new_cash==$cash)
{
   &OkMess('��������� ���������.'.$br2.&ahref($ClientPaysUrl,'�������� �������')).$go_back;
   return;
}

# ������� ������ �������
$rows=&sql_do($dbh,"UPDATE users SET balance=balance+($new_cash)-($cash) WHERE id=$mid LIMIT 1");
if( $rows<1 )
{
   &ToLog("! $Admin_UU ����� ��������� ������� ��������� ������ ��������� ������� �������. ���������� ������ �������������.");
   &Error("������ ��������, ������ ��� ��������� ������� ������� ��������� ������! ���������� ������ ������������� ������� ���������������.");
}

 &OkMess('��������� ���������.'.$br2.&ahref($ClientPaysUrl,'�������� �������')).$go_back;
}

# ===========================================
#        ������� �������� ������
# ===========================================
sub plz_edit
{
 &get_pay_data;
 $reason=&Filtr_mysql($F{reason});
 $p=&sql_select_line($dbh,"SELECT FROM pays WHERE mid=$mid AND category=417 AND reason='p:$Fid' AND coment='$reason' LIMIT 1",'��� ���� ����� ����� �� ������?');
 $p && &Error("������ ��� �����������. �������� �� ������� ��� ������.");
 $sql="INSERT INTO pays (mid,cash,type,category,admin_id,admin_ip,office,reason,coment,time) ".
      "VALUES($mid,0,50,417,$Admin_id,INET_ATON('$ip'),$Admin_office,'p:$Fid','$reason',$ut)";
 $rows=&sql_do($dbh,$sql);
 $rows<1 && &Error("��������� ������. ��������� ������ �����.");
 &OkMess("������ ������ �� ��������� ������� � id=$Fid. �������� ������� �������������� ��������������.$go_back");
}

# ===========================================
#	�������� ������ ��� `����� ���`
# ===========================================
sub mark_answer
{
 &get_pay_data;
 $can_edit or &Error("�� �� ������ �������� ����������� ������.$go_back");
 $PR{18} or &Error('������������ ����������.');
 $rows=&sql_do($dbh,"UPDATE pays SET category=492 WHERE id=$Fid AND type=30 AND category=491 LIMIT 1");
 $rows=$rows==1? '��������� �������� ����� `����� ���`' : "������� �������� �� ������������� - ��������� �������� ��������� `����� ���` �� ���������";
 &OkMess($rows.$go_back);
}

# ============================================================
#
#		���������� �����/�������� ���������
#
# ============================================================

sub pay_now
{
 # �� &Filtr_mysql �.�. ��� ����� ������ ~ 
 $reason=&trim(&Filtr_sql($F{reason}));
 $coment=&trim(&Filtr_sql($F{coment}));
 $Fop=$F{op};
 $mss_log='';
 $time=$t;
 $category=0;

 if( $Fmid>0 )
 {
    ($user_info,$grp,$mId)=&ShowUserInfo($Fmid);
    !$mId && &Error("������ � id=$Fmid �� ������ � ���� ������.");
    $Fmid=$mId;
    !$UGrp_allow{$grp} && &Error("������ ��������� � ������, � ������� � ��� ��� �������."); # � ������������� ������� �����, �� �������
    $ClientPaysUrl="$scrpt0&a=payshow&mid=$Fmid";
 }

 if( $Fop eq 'mess' || $Fop eq 'cmt' )
 {
    $coment=~/^\s*$/ && &Error("��������� �� ������� �.� �� �� ����� ����� ���������.$go_back");
    $Fmid<0 && &Error("������ ���������� ��������� ����������.$go_back");
    if( $Fmid )
    {
       !$pr_mess_create && &Error('��� �� ��������� �������� ��������� �������� ���� ��������� �����������.');
       $reason='';
       if ($Fop eq 'mess')
       {
          $Fq=int $F{q}; # id ���������, ������� ������������.
          if ($Fq)
          {
             $p=&sql_select_line($dbh,"SELECT id FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)",'������ ���������, ������� ����������');
             $reason=$Fq if $p;
          }
          $pay_made_mess='��������� ���������.';
          $category=490;
       }else
       {
          $reason=$coment;
          $coment='';
          $pay_made_mess='��������� ������� ���������.';
          $category=495;
       }
    }
     else
    {
       $pr_mess_all_usr or &Error('� ��� ��� ���� �� ������������� �������� ���������.');
       $ClientPaysUrl="$scrpt0&a=payshow&nodeny=mess";
       $reason=''; # � ���� ���� ����� ������� ����� ����������� ������ ����� �������� ��� ������� ���� �������� ���������
       foreach (keys %UGrp_name)
       {
          $reason.="$_," if $_ && $UGrp_allow{$_}>1 && $F{"g$_"};
       }
       if( !$reason )
       {
          $coment=$coment!~/^\s*$/ && $br2.'��������� ���� ���������:'.$br.&input_ta('pvivetik',$F{coment},50,8);
          &Error("�� �� ������� �� ���� ������ ��������, ��� ������� ����������� ���������.".$coment.$go_back);
       }
       $reason=",$reason"; # ��� ������ �� �������, ������ ������ ���� �������� �������� �� �����
       $pay_made_mess='������������� ��������� ���������.';
       $category=496;
    }
    $type=30;		# ��� ������� - ���������
    $bonus='';
    $cash=0;
 }
  else
 {  # ������, � �� ���������
    $cash=sprintf("%.2f",$F{cash}+0);
    $cash==0 && &Error("�� ������� ����� �������! ������ �� ��������.$go_back"); # ! �� unless $cash
    if( $Fmid>0 )
    {
      if( $Fop eq 'tmp' )
      {  # ��������� ������
         !$pr_tmp_pays_create && &Error('��� �� ��������� ������������ ��������� �������.');
         $Fdays=int $F{days};
         $Fdays<=0 && &Error('�� ������ ���� ���������� �������.');
         $reason.="\n������ ������ $time_now";
         $time=$t+$Fdays*3600*24;
         $pay_made_mess="��������� ������ $cash $gr ��������.";
         $type=20;
         $bonus='y';
         $category=1000;
      }
       elsif( $Fop eq 'old' )
      {  # ������ ������ ������
         !$pr_old_pays_create && &Error("��� �� ��������� ��������� ������� `������ ������`.");
         $Fmon=int $F{mon};
         $Fyear=int $F{year};
         $Fday=int $F{day};
         ($Fday<0 || $Fmon<1 || $Fmon>12 || $Fyear<0 || $Fyear>999) && &Error('��� ���� ������� ��������������. ����������?');
         $max_day=&GetMaxDayInMonth($Fmon,$Fyear);
         ($Fday<1 || $Fday>$max_day) && &Error('���� ����� �������! ������ ������ ������ �� ��������.'.$go_back);
         $pay_made_mess="������ ������ ������ ��������.";
         $time=timelocal(15,0,12,$Fday,$Fmon-1,$Fyear); # � 12:00
         if ($time<$Tnt_timestamp)
         {  # ������������ ������
            !$PR{53} && &Error('���� ������� ���� ����������� ��������� �������! � ��� ������ ���� ����� ���������� ������������ ��������.'.$go_back);
            $bonus='y';
            $category=$cash>0? 80 : 180; # `������������ ������`
            $reason="$t:$reason";
         }
          elsif ($time>$t)
         {
            &Error('������� ������ ������� �� ��������� ���������.');
         }
          else
         {
            $bonus=$F{bonus}? 'y':'';
            !$bonus && ($category=$cash>0? 600 : 700); # `�������� ������`
            $reason="������ ������ ������ ������ $time_now".(!!$reason && "\n\n$reason");
         }
         $type=10;
      }
       else
      {
         !$pr_pays_create && &Error('��� �� ��������� ������������ ������� �������');
         &Error('�� ��������� ��������� ����������� ���������� ��� ������������. ������� �������, ��������, '.
           "`��������� ��...`, `�� ����� ��...` � �.�.$go_back") if $Block_bonus_pay && $F{bonus} && !($reason || $coment);
         $pay_made_mess="������ $cash $gr ��������.";
         $type=10;
         $bonus=$F{bonus}? 'y':'';
         !$bonus && ($category=$cash>0? 600 : 700); # `�������� ������`
      } 
    }
     elsif( $Fmid<0 )
    {
       $pr_worker_pays_create or &Error('��� �� ��������� ����������� �������� � ���������� ����������.');
       $ClientPaysUrl="$scrpt0&a=payshow&mid=$Fmid";
       $wid=-$Fmid;
       $p=&sql_select_line($dbh,"SELECT * FROM j_workers WHERE worker=$wid",'������ ���������');
       $p or &Error("�������� � id=$wid ����������� � ���� ������.");
       $name_worker=$p->{name_worker};
       $pay_made_mess='�������� (�����) ��������� '.&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$wid",$name_worker).' ���������.';
       $type=10;
       $cash=-$cash if $cash>0;	# ������ ������
       $bonus='';		# ������ �����������
    }
     elsif( $pr_net_pays_create )
    {
       $ClientPaysUrl="$scrpt0&a=payshow&nodeny=net";
       $pay_made_mess="������ $cash $gr ������ ���� ��������.";
       $type=10;
       $bonus='';
    }
     else
    {
       &Error('��� �� ��������� �������� �� ����������/������ �������� � ����.');      
    }
 }

 $sql="INSERT INTO pays (mid,cash,type,time,admin_id,admin_ip,office,bonus,reason,coment,category) ".
      "VALUES($Fmid,$cash,$type,$time,$Admin_id,INET_ATON('$ip'),$Admin_office,'$bonus','$reason','$coment',$category)";
 $DOC->{admin_area}.=&MessX($sql) if $Ashowsql;
 $sth=$dbh->prepare($sql);
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid}; # id ������ ��� ��������� ������

 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$iid",'��������, ��� ������ ������������� ������ � ��');
 if (!$iid || !$p || $cash!=sprintf("%.2f",$p->{cash}) )
 {
    &Error("��������� ������ ��� ���������� ������ � ������� ��������.".$br2.
      "����� ���������� ������� ���� ��������� ����� � ��������� �� ��� ������� ���� ����� �� �������.");
 }

 $state_off='';

 # ������� ������ �������
 if ($Fmid>0 && $cash!=0)
 {
    $rows=&sql_do($dbh,"UPDATE users SET balance=balance+$cash WHERE id=$Fmid LIMIT 1");
    if ($rows<1)
    {
       &ToLog("����� ������������� ������� ��������� ������ ��������� ������� ������� id=$Fmid. ��������� ������ �� ��������, �������� ���������� ������ �������������");
       &Error($pay_made_mess.$br2."������ ��� ��������� ������� �������!$br2<b>��������:</b> �������� ���������� ������ ������������� ������� ������� ���������������.");
    }
    $p=&sql_select_line($dbh,"SELECT * FROM users WHERE id=$Fmid LIMIT 1",'������� ������ �������');
    $p or &Error("������ ��������, ������ ��������� ������ ��� �������� ������ �������.");
    $balance=$p->{balance};
    $paket=$p->{paket};
    $srvs=$p->{srvs};
    $start_day=$p->{start_day};
    $discount=$p->{discount};
    $limit_balance=$p->{limit_balance};
    # ��������, �������� �� ���� ���� ������������� ������ ��� ������ ���� ������� ����������.
    # ���� ��, �� ��������, ��� ������� �� �������� (��� ���� ������� ���� �������� ���������)
    # �� �������� ��� ����� ���� �������� ����� �������� ������ ��������, � �������� ���������
    {
      $p->{block_if_limit} or last;
      $p=&sql_select_line($dbh,"SELECT * FROM users WHERE (id=$Fmid OR mid=$Fmid) AND state='off' LIMIT 1",'���� �� ���� �� ���� ��������������� ������ � �������?');
      $p or last;
      # ��� ������� ���� �� ������� ������� �������������. �������� ������� ����� �� ����� � ����� ������
      @T=&GetClientTraf($Fmid);
      $traf1=&Get_need_traf($T[0],$T[1],$InOrOut1[$paket])/$mb;
      $traf2=&Get_need_traf($T[2],$T[3],$InOrOut2[$paket])/$mb;
      $traf3=&Get_need_traf($T[4],$T[5],$InOrOut3[$paket])/$mb;
      $traf4=&Get_need_traf($T[6],$T[7],$InOrOut4[$paket])/$mb;
      $money_param={ paket=>$paket, traf1=>$traf1,traf2=>$traf2,traf3=>$traf3,traf4=>$traf4,
         service=>$srvs, start_day=>$start_day, discount=>$discount, mode_report=>1 };
      $h=&Money($money_param);

      $rez_balance=sprintf("%.2f",$balance - $h->{money});
      $block_balance=$day_now < $Plan_got_money_day? ($over_cmp? $balance - $h->{money_over} : $balance) : $rez_balance;
      last if $block_balance<$limit_balance;
      if( $auto_on==2 )
      {  # �������� ������
         &sql_do($dbh,"UPDATE users SET state='on' WHERE id=$Fmid OR mid=$Fmid");
         $pay_made_mess.=$br2.'������ � �������� �������� - ������ ���� �������������� ������.';
         $state_off=" ����� ������������� ������� ������ � �������� ��� ������";
      }else
      {
         $pay_made_mess.=$br2.'�� �������� ��������� ������ � �������� - ������ ���� �������������� ������.';
         $state_off=" ���������� �������� ������ � ��������";
      }
    }

    $pay_made_mess.=$br2."���������� ������� ������� ���������� �������: ".&bold($balance)." $gr";
    $mss_log="���� ������� id=$Fmid �������� �� $cash $gr ";
    $mss_log.=" (������ ���������, ���� �������� $Fdays ����)" if $type==20;
    $mss_log.=". ������� ������ ������� $balance $gr.$state_off";  
 }

 if( $cash!=0 )
 {
    if( !$Fmid )
    {
       $mss_log="��������� $cash $gr ��� ������ �� ����.";
       $mss_log.=" ����������� � ������: $reason" if $reason;
    }elsif( $Fmid<0 )
    {
       $mss_log="������ ������� (�����) ��������� � $wid � ������� �� $cash $gr.";
       $mss_log.= "����������� � ������: $reason" if $reason;
    }
 }
  elsif( $Fop eq 'mess' && $Fq )
 {
    &sql_do($dbh,"UPDATE pays SET category=492 WHERE id=$Fq AND type=30 AND mid=$Fmid AND category=491 LIMIT 1",'��������� ���������� ��������� ���� ���� ����� ��� �� ���� ��� ��������');
 }

 #&ToLog("$Admin_UU $mss_log") if $mss_log && $AllToLog;

 $OUT.=&div( 'infomess lft',$pay_made_mess.&Table('table2 nav',&RRow('','ll',$br2.&ahref($ClientPaysUrl,'�������� �������'),'')) );
 $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$ClientPaysUrl"'>};
}

# =========================================================
#	�������� �������� �� ������ ������ �������
# =========================================================
sub send_money
{
 $pr_transfer_money or &Error('��� ���� ��� �������� �������� ����� ����������������.');
 ($A)=&Get_adms();
 $cash=sprintf("%.2f",$F{cash}+0);
 if( $cash!=0 )
 {
    $cash<0 && &Error("<b>�������� ����� �� ������������</b>: ����� ���������� ������ ���� ������������� ������.");

    $from=int $F{from};
    $to=int $F{to};

    defined($A->{$from}{admin}) or &Error("�������� ����� �� ������������: ������ � id=$from ��� � ������ ���������������.");
    defined($A->{$to}{admin}) or &Error("�������� ����� �� ������������: ������ � id=$to ��� � ������ ���������������.");

    ($to==$from) && &Error("�������� ����� �� ������������: ���������� � ����������� ���� � ���� ����.$go_back");

    $sql="INSERT INTO pays SET $Apay_sql,mid=0,cash=$cash,type=40,bonus='y',category=470,reason='$from',coment='$to',time=$ut";

    $_=Digest::MD5->new;
    $param_hash=$_->add($sql)->b64digest;
    $Ftime=int $F{time};
    $Frand=int $F{rand};

    $href=$br3.&CenterA("$scrpt0&a=payshow&nodeny=transfer",'����� &rarr;');

    $p=&sql_select_line($dbh,"SELECT * FROM changes WHERE tbl='pays' AND act=1 AND time=$Ftime AND fid=$Frand AND adm=$Admin_id AND param_hash='$param_hash'");
    $p && &Error("���������� ��������� ������� ������. �������� �� �������� ��������. �������� �������� ���� ������������ �����.".$href);
    $rows=&sql_do($dbh,$sql);
    $OUT.=&div('message cntr',$br2.&bold('�������� ����� ').
        ($rows<1? '<span class=error>�� ������������</span>' : &bold('������������')).$href
    ).$br;

    $rows>0 && &sql_do($dbh,"INSERT INTO changes SET tbl='pays',act=1,time=$Ftime,fid=$Frand,param_hash='$param_hash',adm=$Admin_id");
    return;
 }
 # ����� ����� �������� ��������
 $AdminsList='';
 foreach $id (keys %$A)
 {
    next if $A->{$id}{privil}!~/,62,/; # 62 - ����� ����� ����������� � ���������
    $AdminsList.="<option value=$id>$A->{$id}{admin}</option>";
 }
 # time � rand - �������� ��������� ������� ������
 $OUT.=&form('!'=>1,'act'=>'send','time'=>$t,'rand'=>int(rand 2**32),
    &Table('',&RRow('','ttt',
      '�����, ���������� ��������'.$br."<select name=from size=20>$AdminsList</select>",
      $br.'������������ �����'.$br2.&input_t('cash','',14,14,' autocomplete="off"').' '.$gr.$br2.
      &submit_a('���������'),
      '�����, ����������� ��������'.$br."<select name=to size=20>$AdminsList</select>"
    ))
 );
}

# ------------------------------------------
#  ������������� �������� ���������
# ------------------------------------------

sub mess_for_all
{
 $PR{34} or &Error('� ��� ��� ���� �� ������������� �������� ���������.');

 $out='�������� ������ ��������,<br>��� ������� ���������� ���������<br>������������� ���������:'.$br2;
 foreach (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
 {
    next if $UGrp_allow{$_}<2 || !$_;
    $out.="<input type=checkbox value=1 name=g$_> $UGrp_name{$_}".$br;
 }
 $out2=&Table('nav2',&RRow('','ll',&ahref('#','�������� ��� ������',qq{onclick="SetAllCheckbox('grp',1); return false;"}),
    &ahref('#','����� ���������',qq{onclick="SetAllCheckbox('grp',0); return false;"}))).
    $br2.'���������:'.$br.&input_ta('coment','',44,7).$br2;

 $out=&Table('table10',&RRow('','^^',"<div id=grp>$out</div>",$out2.&submit_a('���������!')));
 $OUT.=$br.&form('!'=>1,'#'=>1,'act'=>'pay','op'=>'mess','id'=>0,&MessX($out));
}

sub set_block
{# ��������� ���������� ��� �������
 %f=(
   'mess'	=> [$PR{55},451,'��� ���� �� ��������/���������� ���������.','�� ������������� ����������� �������� �������� ��������� ������������� ����� ���������� ����������'],
   'packet'	=> [$PR{117},450,'��� ���� �� ��������� ���������� ��� ������� �� ����� ������ ����� ���������� ����������.','�� ������������� ����������� ������� �������� ����� ����� ���������� ����������'],
 );

 defined $f{$F{what_block}} or &Error('�������� �������. �������� �� ���������.');

 ($priv,$category,$mess1,$mess2)=@{$f{$F{what_block}}};

 $priv or &Error($mess1);

 (undef,$grp,$mId)=&ShowUserInfo($Fmid);
 $mId or &Error("������ � id=$Fmid �� ������ � ���� ������.");
 $UGrp_allow{$grp}<2 && &Error("� ��� ��� ���� �� ������ � ������� ������� ���������� �������.$go_back");

 $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE mid=$mId AND type=50 AND category=$category LIMIT 1",'���� �� ��� ���������� ��� �������?');
 $p && &Error("��� ������� ������� ��� ���������� ���������� ����������. �������� �� �������������� ������.$go_back");
 &sql_do($dbh,"INSERT INTO pays SET mid=$mId,cash=0,type=50,category=$category,time=$ut,$Apay_sql");
 $url="$scrpt0&a=payshow&mid=$mId";
 &OkMess("$mess2. �������� ���������� ������ ������������� � ������� �������������� ������� - �� ������ ����� ������� � �������� ������� ��������������� �������-����������.".$br2.
         &CenterA($url,'�������� �������/������� �������').$go_back);
 $DOC->{header}.=qq{<meta http-equiv="refresh" content="15; url='$url'">};
}

# ------------------------------------------
#     ����� ��� ������������� ��������
# ------------------------------------------

sub payform_show
{
 $cash=$F{cash}+0;
 $coment=&ahref('#','&darr;&uarr;',qq{onclick="javascript: show_more('coment',8,18);"}).$br.
   &input_ta('coment',$F{coment},44,7,'id=coment');

 $out='';

 if( $Fmid<0 )
 {
   $pr_worker_pays_create or &Error('��� ���� �� ������ �������/�������.');
   $wid=-$Fmid;
   $W=&Get_workers($wid);
   defined($W->{$wid}) or &Error("�������� � $wid �� ������ � ���� ������.$go_back");
   !$pr_oo && $W->{$wid}{office}!=$Admin_office && &Error("�������� � � $wid �������� � ������ �������� �� ������.");
   $user_info=&MessX("��� ���������: ".$W->{$wid}{url}.$br."���������: ".&bold(&Show_all($W->{$wid}{post})));
   $out.=&input_h('mid'=>$Fmid,'coment'=>'').
      "������� ����� ������� ���������� � ���� ��������/������ ���������".$br2.
      &input_t('cash',$cash,14,16,'id=cash autocomplete="off"')." $gr".$br2.
      &bold('�����������').$br.&input_ta('reason',$F{reason},44,7);
   $DOC->{body_tag}.=qq{ onload="javascript: document.getElementById('cash').focus();"}
 }
  elsif ($Fmid)
 {
   ($user_info,$grp,$mId)=&ShowUserInfo($Fmid);
   $mId or &Error("������ � id=$Fmid �� ������ � ���� ������.");
   $UGrp_allow{$grp} or &Error("� ��� ��� ���� �� ������ � ������� �������.");
   $UGrp_allow{$grp}>1 or ($OUT.=&MessX('<b>��������������:</b> � ��� ������������ ������ � ������ ������� �������. �� ������ �������� ������, '.
     '������ �� ������� ����� ��� ��������/�������, � ����� ����������� ������, ������� � ��������� ������� �������.',1,1));
   $user_info=&MessX($user_info,0,1);
   $out.=&input_h('mid',$mId);

   ($pr_pays_create || $pr_tmp_pays_create || $pr_old_pays_create || $pr_mess_create) or
       &Error("��� �� ��������� ��������� ������� ���� ��������/��������� ��������.");

   @f=();
   push @f,['pay',1,'������� ������'] if $pr_pays_create;
   push @f,['tmp',1,'��������� ������'] if $pr_tmp_pays_create;
   push @f,['old',1,'������ ������ ������'] if $pr_old_pays_create;
   push @f,['mess',0,'��������� �������'] if $pr_mess_create;
   push @f,['cmt',0,'����������� � ������� ������'] if $pr_mess_create;
   $Fop=$F{op}||'pay';
   $hide_cod=qq{hide_element("coment_div"); hide_element("cash_div"); };
   $hide_cod.=qq{hide_element("$_->[0]"); } foreach @f;
   $DOC->{header}.="<script>function hide_e() { $hide_cod }</script>";
   foreach (@f)
   {
      $h=qq{hide_e(); document.getElementById("$_->[0]").style.display=""; };
      $h.=qq{document.getElementById("coment_div").style.display=""; }.
          qq{document.getElementById("cash_div").style.display="";} if $_->[1];
      $out.="<input type=radio id=radio$_->[0] value=$_->[0] name=op style='border:0;' ".($Fop eq $_->[0] && 'checked ').
        qq{onClick='$h'><label for=radio$_->[0]>$_->[2]</label>}.$br;
   }

   ($mon_list)=&Set_mon_in_list($mon_now);
   ($year_list)=&Set_year_in_list($year_now);
   $day_list='<select size=1 name=day><option value=0>&nbsp;</option>'.
      (join '',map {"<option value=$_>$_</option>"}(1..31))."</select> $mon_list $year_list".$br;

   $opMess=$Fop eq 'mess';
   $out.=$br.'<div id=cash_div'.($opMess && " style='display:none'").'>'.
      &input_t('cash',$cash,14,16,'id=cash autocomplete="off"')." $gr ".
      "<input type=checkbox name=bonus value=1 style='border:0;'> ������".$br2.
   '</div>';

   if ($pr_pays_create)
   {
      $out.="<div id=pay".($opMess && " style='display:none'").'>'.&bold('����������� ��� �������').'</div>';
   }

   if ($pr_tmp_pays_create)
   {
      $out.="<div id=tmp ".($Fop ne 'tmp' && "style='display:none'").'>'."��������� ������ �� ".
        "<select size=1 name=days>".(join '',map {"<option value=$_>$_</option>"}(1..31))."</select> ����".$br3.
        &bold('����������� ��� �������').
      '</div>';
   }

   if ($pr_old_pays_create)
   {
      $out.="<div id=old style='display:none'>�������� ������ ��������� �����: ".$br2.
        $day_list.$br2.&bold('����������� ��� �������').
      '</div>';
   }

   if ($pr_mess_create)
   {
      $Fq=int $F{q}; # id ��������� �������, �� ������� ������ �����
      if ($Fq)
      {
         $p=&sql_select_line($dbh,"SELECT reason FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)",'���������� ���������');
         $Fq=0 unless $p;
      }
      $out.='<div id=mess'.(!$opMess && " style='display:none'").'>'.$br2.(!$Fq? &bold('���������') :
         &input_h('q'=>$Fq).'�� ��������� �� ��������� �������: '.&div('message',&Show_all($p->{reason}))).
      '</div>';
      $out.="<div id=cmt style='display:none'>".$br2.&bold('�����������').'</div>';
   }

   $out.='<div id=coment_div'.($opMess && " style='display:none'").'>'.
        &input_ta('reason',$F{reason},44,5).$br.
        &bold('�����������, ������� ����� ������ ������ ').
   '</div>';

   $out.=$coment;
   $pay_mess='';
   foreach $i (split /\n/,$p_adm->{pay_mess})
   {
      $_=&Filtr_out($i);
      s/"/`/g; # �� �������� ������ ������, �� �������������� &#34; ���� - javascript ������������ ��� �������
      $x=(s/^#(\-?\d+\.?\d*)\s*//)? qq{; document.getElementById("cash").value="$1"; document.getElementById("bonus").checked=true} : '';
      s/\s+$//;
      $i or next;
      $pay_mess.=&RRow('*','l',qq{<span class='data2' style='cursor:pointer;' onClick='javascript: document.getElementById("coment").value="$_"$x'>$_</span>});
   }
   $pay_mess=&Table('table0',$pay_mess).$br if $pay_mess;

   %f=('<b>�����</b>' => ' ~bold(�����~)',
       '<span class=borderblue>����� � �����</span>' => ' ~frame(�����~)',
       '<span class=data2>������</span>' => ' ~url(http://~)(�����~)');

   foreach (keys %f)
   {
      $pay_mess.=qq{<span style='cursor:pointer;' onClick='javascript: document.getElementById("coment").value+=value="$f{$_}"'>$_</span>$br2};
   }

   $user_info.=&MessX($pay_mess,0,1);
   $DOC->{body_tag}.=qq{ onload="javascript: document.getElementById('cash').focus();"};
 }
  elsif ($pr_net_pays_create)
 {
    $out.=&bold("�������� � ������� ����").$br2.
       "������ (����) � �����:".$br2.
       "<input type=text name=cash id=cash value='$cash' size=14> $gr".$br2.
       &bold('�����������').$br.
       &input_ta('reason',$F{reason},50,7);
 }
  else
 {
    &Error('�������� ������� ����� ��� ��� ����������� ������.');
 }
 $out.=$br2.&submit_a('�������� ������');
 $OUT.=$br.&form('!'=>1,'act'=>'pay',&Table('table0',&RRow('','t t',$user_info,'',&MessX($out))));
}




sub update_category
{# ���������� ��������� ��������
 $pr_edt_category_pays or &Error('��� ���� �� ��������� ��������� ��������.');
 $i=0;
 $stop=0;
 foreach $f (keys %F)
 {
    next if $f!~/^id_(\d+)/;
    $id=$1;
    $c=int $F{$f};

    $url_id=&ahref("$scrpt&act=show&id=$id",$id);
    $no_chng_mess="<div class='message lft'>��������� ������� � id=$url_id �� �������� �.�";
    $p=&sql_select_line($dbh,"SELECT * FROM pays WHERE id=$id");
    if( !$p )
    {
       $OUT.="$no_chng_mess �� ������� �������� ���������� �� ���� �������, ��� ���������� ��� �������� ���� �� ���������. ".
         "��������, ���� �� ������� ���������, ������ ������������� ������ ������.</div>";
       $stop++;
       next
    }

    $old_c=$p->{category};
    next if $old_c==$c;

    if( !$pr_edt_foreign_pays && $Admin_id!=$p->{admin_id} )
    {
       $OUT.="$no_chng_mess � ��� ��� ���� �� ��������� �������� ������ ���������������.</div>";
       $stop++;
       next
    }

    if( !$pr_oo && !($p->{mid}) && $Admin_office!=$p->{office} )
    {
       $OUT.="$no_chng_mess � ��� ��� ���� �� ������ � ��������� ������� ������</div>";
       $stop++;
       next
    }

    if( $p->{type}!=10 )
    {
       $OUT.="$no_chng_mess ��� ������ ������ �� ��������� ������ ��������� ���������.</div>";
       $stop++;
       next
    }

    if( $c && !(defined $ct{$c}) )
    {  # ��� ������
       $OUT.="$no_chng_mess �.�. �� ������� �������������� ��������� �������. ���� �� �� ����������� - �������� �������������� � ��������.</div>";
       $stop++;
       next
    }    

    $rows=&sql_do($dbh,"UPDATE pays SET category=$c WHERE id=$id AND category<>$c LIMIT 1");
    if( $rows==1 )
    {
       $i++; # �� ����� $i+=$rows, ������ ��� ����� ������� �� ������ ����� ��� ��������
    }
     else
    {
       $OUT.=&div('message error',"�� ������� �������� ��������� ������� � id=$url_id");
       $stop++;
    }
 }

 $url="$script?$QueryString&a=payshow";
 $OUT.=&div('message cntr',"��������� ��������� �������� ���������. ����� ��������� <b>$i</b>".$br2.&ahref($url,'����� &rarr;'));

 return if $stop;
 $DOC->{header}.=qq{<meta http-equiv='refresh' content='10; url="$url"'>};
}

1;
