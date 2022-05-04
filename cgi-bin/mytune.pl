#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

# $F{act} �� ������ - �������� � adm.pl ��� ������, ���������� ��� multipart/form-data

$Admin_id or &Error("�������� ������� ������ ��� ������ � NoDeny. ������ admin ������ ��� �������������� ���������.");
$PR{108} && !$pr_RealSuperAdmin && &Error("��� ���� �� ��������� ������ �������� ������ ������� ������. ������������� �� ����.");

%UsrList_cols=(
 1 => 'Id',
 2 => '���',
 3 => '�����',
 4 => '������',
 5 => '������',
 6 => '��������',
 7 => '���� ���������',
 8 => 'Ip',
 9 => '����� ������',
10 => '�������',
11 => '�����',
12 => '���',
13 => '��������',
14 => '������ � ��������',
15 => '������� ����������',
16 => '�����',
17 => '������ ����������� 1',
18 => '������ ����������� 2',
19 => '������ ����������� 3',
20 => '������ ����������� 4',
21 => '������ ���������',
22 => '��������� �����',
30 => '������� � ������ `���������`',
50 => '���_������ `��������� ����`',
51 => '���_������ `����������`',
52 => '���_������ `�����`',
53 => '���_������ `��� �� �����`',
54 => '���_������ `��� �� ����`',
);

$return=$br2.&CenterA("$scrpt0&a=mytune",'���������� ���������');

if ($F{act} eq 'save_str')
{
   $r=join '', map{ "$_," } grep{ $F{"a$_"} } sort keys %Regions;
   chop $r;
   &sql_do($dbh,"UPDATE admin SET regions='$r' WHERE id=$Admin_id LIMIT 1");
   &OkMess("������ ������������ ������� �������.$return");
   &Exit;
}

if ($F{act} eq 'save_pass')
{
   $pp=$p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
   ($pp ne  '-') or &Error("�� �� ������ �������� ���� ������, ��������� �� ������������� �� ����� �������, � �����������.");
   ($pp eq $F{old_man}) or &Error('������� ������ ������ �������.'.$br2.'������ �� �������.');

   $Fpasswd1=&Filtr_mysql($F{new_man1});
   $Fpasswd2=&Filtr_mysql($F{new_man2});
   ($F{new_man1} eq $F{new_man2}) or &Error("����� ������ �� ��������� � ��� ��������� ������. ������ �� �������.".$return);
   &Error("������ �� ����� ���� ������ 6 ��������, � ����� ���������� ��� ������������� ��������.".$br2.
      "������ �� �������.".$return) if length($Fpasswd1)<6 || $Fpasswd1=~/^\s+/ || $Fpasswd1=~/\s+$/; # ������, ������ '-' �� �������� �� �����

   $rows=&sql_do($dbh,"UPDATE admin SET passwd=AES_ENCRYPT('$Fpasswd1','$Passwd_Key') WHERE id=$Admin_id LIMIT 1",'','�����');
   $rows<1 && &Error("������ �� �������. ���������� ����� ��� ���������� � �������� ��������������.");
   # ������ ��� �������� ������ ������� ������
   &sql_do($dbh,"DELETE FROM admin_session WHERE admin_id=$Admin_id");
   &OkMess('��� ������ ��� ������� � ���������������� ��������� ������� �������.'.$br2.&CenterA($scrpt0,'��������������'));
   &Exit;
}

if ($F{act} eq 'save')
{
   $email=$F{email};
   if ($email=~/^[a-zA-Z_\.-][a-zA-Z0-9_\.-\d]*\@[a-zA-Z\.-\d]+\.[a-zA-Z]{2,4}$/)
   {
      $set_email=",email='$email'";
   }
    elsif ($email=~/^\s*$/)
   {
      $set_email=",email=''";
   }
    else
   {
      &ErrorMess("Email ����� �������, ������� �� �������");
      $set_email='';
   }  

   # ��������� �� �������� � ����� ������� ����� ���������� �� email ������. ���� � ������� ������� ����� �������� -
   # ��� �� �������� �� ������������ �.� ����� ��������� ��������� ����� �������������� ��������
   $email_grp='';
   foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
   {
      next if $UGrp_allow{$g}<2;
      $email_grp.="$g," if $F{"g$g"};
   }
   $email_grp=~s|,$||;
   $email_grp=",email_grp='$email_grp'";

   $tunes='1,1';
   $tunes.=',showsql,1' if $F{showsql};
   $tunes.=',ShowIpInPays,1' if $F{ShowIpInPays};

   foreach $g (keys %UsrList_cols)
   {
      map{ $tunes.=",cols-$_-$g,1" } grep{ $F{"cols-$_-$g"} } (0..($UsrList_cols_template_max-1))
   }

   $rows=&sql_do($dbh,"UPDATE admin SET pay_mess='".&Filtr_mysql($F{pay_mess})."',tunes='$tunes' $set_email $email_grp WHERE id=$Admin_id LIMIT 1");
   &OkMess('������ ���������'.$return);
   &Exit;
}

if ($F{act} eq 'save_pic')
{
   $pic=$cgi->param('pic');
   if ($pic)
   {
      $pic!~/\.(jpg|jpeg|gif|png|tif|tiff)$/i && &Error("�������� ������ ����� ���� �� ��������� ����������: jpg, jpeg, gif, png, tif, tiff");
      $ext=lc($1);
      $ffile.="$Adm_img_f_dir/Adm_$Admin_id.$ext";
      $FileOut='';
      while (read($pic,$b,1024)) {$FileOut.=$b}
      open(FL,">$ffile") or &Error("������ �������� ������� <b>$ffile</b>. �������� ����� �� ���������� ���� ���������� �� ������. ���������� � �������� ��������������");
      binmode(FL);
      print FL $FileOut;
      close(FL);
      &OkMess("<img src='$Adm_img_dir/Adm_$Admin_id.$ext'>".$br3.&bold("������ ��������").$return);
   }
    else
   {
      $ext='';
      &Message(&bold('������ ������'));
   } 
   $rows=&sql_do($dbh,"UPDATE admin SET ext='$ext' WHERE id=$Admin_id LIMIT 1");
   &Exit;
}

# === ����������� ���������� ===

$row_id=5;
$out=&RRow('head','3','�������� ������, ����� ������� ��� ����� �������� � ������ �������');
foreach $i (sort {$Regions{$a} cmp $Regions{$b}} keys %Regions)
{
   chop($Regions{$i});
   $out.=&PRow."<td><input type=checkbox name=a$i value=1".($Admin_regions=~/,$i,/? ' checked':" style='border:0px;'")."></td><td>$Regions{$i}</td><td class=nav><a href='javascript:show_x($row_id)'>&darr;</a></td></tr>";
   $out.="<tr class=$r1 id=my_x_$row_id style='display:none'><td colspan=3>";
   $sth=&sql($dbh,"SELECT * FROM p_street WHERE region=$i ORDER BY name_street");
   $out.=&Filtr($p->{name_street}).$br while ($p=$sth->fetchrow_hashref);
   $out.='</td></tr>';
   $row_id++;
}
$out.=&RRow('head','3',$br.&submit_a('���������').$br);

$OUT.="<div class=message>".$br.&div('big','���� ���������').$br.
  "<table><tr><$tc valign=top>".
    &form('!'=>1,'act'=>'save_str',&Table('width100 tbg1',$out)).
  "</td><$tc valign=top>";

$Admin_pay_mess=$p_adm->{pay_mess};

# ��������� �� �������� � ����� ������� ����� ���������� �� email ������
$Aemail_grp=','.$p_adm->{email_grp}.',';
$email_grp='';
foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} grep {$UGrp_allow{$_}>1} keys %UGrp_name)
{
   $email_grp.="<input type=checkbox value=1 name=g$g".($Aemail_grp=~/,$g,/ && ' checked')."> $UGrp_name{$g}".$br;
}

$usrlist_cols='';
foreach $g (sort {$UsrList_cols{$a} cmp $UsrList_cols{$b}} keys %UsrList_cols)
{
   @usrlist_cols=@usrlist_header=();
   foreach (0..($UsrList_cols_template_max-1))
   {
       push @usrlist_header,'&nbsp;&nbsp;��� '.($_+1).'&nbsp;&nbsp;';
       push @usrlist_cols,"<input type=checkbox value=1 name='cols-$_-$g'".(defined($Atunes{"cols-$_-$g"}) && ' checked').'>';
   }
   $h=$UsrList_cols{$g};
   $h=~s|^���_||;
   $usrlist_cols.=&RRow('*','l'.('c' x $UsrList_cols_template_max),$h,@usrlist_cols);
}

$usrlist_cols=&Table('tbg',
   &RRow('* head','c' x ($UsrList_cols_template_max+1),'�������� ����',@usrlist_header).
   $usrlist_cols
);

$out=&form('!'=>1,'act'=>'save',
  &div('story','����������� ���������, ������� �� ���� ����� ��������� ��������. ��� ����� ��������� ����� � ����� ����� ���������, '.
    '��� ����, ������� �� ������ �� ���, ��������� ����� ��������� � ���� �����.'.$br2.
    '���� � ������ ��������� ����� #�����, �� ���� ����� �������� ����� ����� ����������� � ��� ����� (����� ��������� � �������).').$br.
  &input_ta('pay_mess',$Admin_pay_mess,56,12).$br2.
  "����������:".$br2.
  &Table('tbg3',
    &RRow('*','ll','��� email',&input_t('email',$p_adm->{email},30,34)).
    &RRow('*','ll','�������� ip ������� � ������ ��������',"<input type=checkbox value=1 name=ShowIpInPays".(!!$Atunes{ShowIpInPays} && ' checked').'>').
    ($pr_SuperAdmin && &RRow('*','ll','����� ������ ���������� ���������',"<input type=checkbox value=1 name=showsql".(!!$Atunes{showsql} && ' checked').'>'))
  ).$br2.
  &MessX("�������� ������, ��������� �� �������� �������, �� ������ �������� �� email:".$br2.$email_grp).$br.
  &div('story',"�������� ��������� �� �������, ������� �� ������ ������ � ������ ������ ��������. ������������� ��������� ����� �����������, ".
     "� ������ �� ������ ������������� ����� ����, ������ ��� ������� ���� ������������� ������ ����� ����������� ����, � ��� ������� - ���.").$br.
     $usrlist_cols
  .$br.
  &submit_a('���������').$br
);

$OUT.=&div('message lft',$out);

# ������ ��� �������� �������� �������� ������� get �.�. �� ��������� ������ adm, ���� �������� ���������� post-��
$OUT.=$br3.&Center_Mess("�� ������ ��������� ������ (�������), ������� ����� ���������� � ����� ������� ���� �������.".$br.
    "���� �� ������� ������� ����, �� ������ ����� ������ � ����� ����������� ������ �� ��������� (������� ����)".$br2.
    "<form method=post action='$script' enctype='multipart/form-data' ".&FormSubmitEvent.">".&input_h(%FormHash).&input_h('act','save_pic').
    "<input type=file name=pic size=50 value=''>$br2<div id=savediv$SaveDiv><input type=submit value='���������'></div></form>",1);

$OUT.=$br3.&Center_Mess("���� ������� �������� ������ ��� ����� ������� ������,".$br2.
   &form('!'=>1,'act'=>'save_pass',
     &Center(
       &Table('tbg1',
         &RRow('*','rl','������� ������� ������','<input type=password name=old_man size=30>').
         &RRow('*','rl','����� ������','<input type=password name=new_man1 size=30>').
         &RRow('*','rl','����� ������','<input type=password name=new_man2 size=30>').
         &RRow('*','C',&submit_a('��������'))
       )
     )
   ),1
) if $p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"} ne '-';

$OUT.='</td></tr></table></div>';

1;

