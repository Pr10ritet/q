#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

&LoadDopdataMod();

$Fact		= &Filtr($F{act});
$Fid		= int $F{id};
$Ftmpl		= int $F{tmpl};
$Fparent_type	= int $F{parent_type};
$Fcopy		= int $F{copy};
$Fowner_type	= int $F{owner_type};
$Fowner_id	= int $F{owner_id};


# 0 - �������������� ������ �������, 1 - ������ ������� ������������
$Fparent_type=0 if $Fparent_type>1 || $Fparent_type<0;

$url="$scrpt&parent_type=$Fparent_type";
      
if( $Fparent_type )
{
   $PR{103} or &Error('� ��� ��� ���� �� ������ � ������� ������������');
   $pr_can_edit=$PR{96};

   $menu='';
   foreach $tmpl ( sort{ $Dopfields_tmpl{$a} cmp $Dopfields_tmpl{$b} } grep{ $_>=100 } keys %Dopfields_tmpl )
   {
      $menu.=&div('bordergrey cntr',&bold(&Filtr($Dopfields_tmpl_name{$tmpl}) || "� $Ftmpl").$br.
          &Table('table0 width100',
            &RRow('','ccc',
              &ahref("$url&tmpl=$tmpl&act=edit",'��������'),
              &ahref("$url&tmpl=$tmpl&act=search",'�����'),
              &ahref("$scrpt0&a=equip&tmpl=$tmpl&act=find",'������')
            )
         )
      ).$br;
   }

   $menu or &Error("�� ���������� �� ������ ���� ������������. ������� � ������ `���������` � ��������, ��������, `�����`, `������� �����`. ".
     "����� ����� ������� � ��������� �������������� ����� � �������� ��������������� ���� ��� ������� ���� ������������.".$go_back);
   $menu.=$br.&div('bordergrey cntr',&ahref("$scrpt0&a=equip",'�������������'));

   if( $Fid )
   {
      $p=&sql_select_line($dbh,"SELECT template_num FROM dopdata WHERE parent_type=1 AND parent_id=$Fid LIMIT 1",'������� ����� ������� � �������� ������� ������������');
      $p or &Error(&Printf('������� ������������ � ���������� ������� [bold] �� ����������',$Fid).$go_back);
      $Ftmpl=$p->{template_num};
   }

   $url.="&tmpl=$Ftmpl";
   $tmpl_name=&commas(&Filtr($Dopfields_tmpl_name{$Ftmpl}) || "� $Ftmpl");

   if( !defined $Dopfields_tmpl{$Ftmpl} || $Ftmpl<100 )
   {
      $OUT.=&Mess3('row2 nav3',$menu);
      &Exit;
   }

   &LoadEquipMod();
   $menu.=$br.&div('bordergrey cntr',&ahref("$url&act=revisions&id=0",'�������')."&nbsp;��������� ������ ��� ���� ��������� ���� $tmpl_name");
   $menu.=$br.&div('bordergrey cntr',&ahref("$url&act=revisions&id=$Fid",'�������')."&nbsp;��������� ������ ��������� ������� ������������") if $Fid;

   {
      last if $Fact || $Fid;
      if( !$pr_can_edit )
      {
          $Fact='search';
          last;
      }
      $OUT.=&Mess3('row2 nav2',&ahref("$url&act=search",'�����').&ahref("$url&act=edit",'��������').$br.&Center("������� ������������ ���� $tmpl_name")).&Mess3('row2',&div('nav2',$menu));
      &Exit;
   }

   $menu=(!!$Fid && '������� ������� ������������ ���������� ������� '.&ahref("$url&act=edit&id=$Fid",$Fid))." ��� ������������ $tmpl_name.".$br2.$menu;
   $menu=&Mess3('row2 nav3',$menu);
}
 else
{
   $url.="&id=$Fid";
   $menu=join '',map{ &ahref("$url&act=$Fact&tmpl=$_",$Dopfields_tmpl_name{$_}) } sort{ $Dopfields_tmpl{$a} cmp $Dopfields_tmpl{$b} } grep{ int($_/100)==$Fparent_type } keys %Dopfields_tmpl;
   $url.="&tmpl=$Ftmpl";
   $tmpl_name=&commas(&Filtr($Dopfields_tmpl_name{$Ftmpl}) || "� $Ftmpl");
   if( $Fact eq 'search' )
   {
      $menu='����� �������� �� ������ � �������:'.$menu;
   }
    else
   {
      $U=&Get_users($Fid);
      defined($U->{$Fid}{name}) or &Error("������ ��������� ������ ������� � id=$Fid.");
      $UGrp_allow{$U->{$Fid}{grp}} or &Error('��� ������� � ������ �������.');
      $pr_can_edit=$pr_edt_usr && $PR{82} && $UGrp_allow{$U->{$Fid}{grp}}>1;
      $url_client=&ahref("$scrpt0&a=user&id=$Fid",'������: '.$U->{$Fid}{name});

      $menu or &Error("��� �� ������ ������� (�������) �������������� �����.".$go_back);

      $Ftmpl=0 if $Ftmpl>=100;
      $menu=$url_client.$menu.$br.&div('bordergrey cntr',&ahref("$url&act=revisions",'�������')."&nbsp;��������� ������");
      
   }
   $menu=&Mess3('row2 nav2',$menu);
}

$OUT.="<table class='width100 pddng'><tr><td valign=top width=16%>".$br.$menu."</td><$tc valign=top>".$br;
$tend='</td></tr></table>';

$Fact||='edit';

# === ������� ��������� ===
{
 ($Fact eq 'revisions') or last;
 ($A,@Asort)=&Get_adms();
 $out='';
 $rev_previos=0;
 $p=1;
 $sth=&sql($dbh,"SELECT * FROM dopfields f LEFT JOIN dop_oldvalues v ON f.id=v.dopfield_id WHERE parent_type=$Fparent_type AND parent_id=$Fid ORDER BY revision DESC,field_name LIMIT 100");
 while( $p )
 {
    $rev_previos or next;
    $name=&Filtr_out($field_name);
    $name=~s|^\[\d+\]\s*||; # ������ ������������� �������
    $value=&Filtr_out(
        &nDopdata_print_value
           ({
              type	=> $field_type,
              alias	=> $field_alias,
              value	=> $field_value
           })
        );
 }
  continue
 {
    $revision=($p=$sth->fetchrow_hashref)? $p->{revision} : -1;

    if( $rev_previos )
    {
       push @names,$name;
       push @values,$value;
       if( $rev_previos!=$revision )
       {
          $out.=&RRow('*','clcl',
             &ahref("$url&revision=$rev_previos&id=$parent_id",$Fparent_type? $parent_id:'&rArr;'),
             &the_short_time($time,$t,1),
             $A->{$admin_id}{admin},
             &Table('width100 tbg1',
                &RRow('row1','c' x ($#names + 2),&Printf('[div tablebg]','����:'),@names).
                &RRow('row1','c' x ($#names + 2),&Printf('[div tablebg]','��������:'),@values)
             )
           );
          @names=@values=();
       }
    }
    if( $p )
    {
      ($time,$parent_id,$admin_id,$field_name,$field_type,$field_alias,$field_value)=&Get_fields qw(
        time  parent_id  admin_id  field_name  field_type  field_alias  field_value);
    }
    $rev_previos=$revision;
 }

 $out or &Error("������ ������� �� �����������, ������������� ��� ������� �� ��������������.",$tend);
 $OUT.=&Table('width100 tbg1 nav2',&RRow('tablebg','cccc',$Fparent_type? '�����. �':'��������','�����','�������������','������').$out);
 &Exit;
}



# ===============================================
#        ����������� ������/����� ��� ������
# ===============================================

{
 ($Fact eq 'edit') or ($Fact eq 'search') or last;
 $act_edit=$Fact eq 'edit';

 if( $F{error} )
 {  # ��� ���������� ������ ��������� ������. ��� ������ � $F{error}, ����������� � $F{descr}
    # ���� ������ ���� �������������, �� ��� ����� ��������� �� dop_oldvalues �� $F{revision}
    my $err=('',
      '���� �� ����������, ������� �� ��������, ������ ���� ����������. ������ � ������ ���������� ������ ����������, ��� ���� ���� ������ � ����� �� ���������.'
    )[int $F{error}] || '������ ������������ ���������.';
    &ErrorMess("��������� �� ���������, �������:".$br2.$err.$br2."�� ������ ��������� �������� � ������� ������ ��������.");
 }
  else
 {
    $F{updated} && &Message('��������� ���������');
 }

#my $where=$Ftmpl? "WHERE template_num=$Ftmpl" : '';
my $where="WHERE parent_type=$Fparent_type AND template_num".($Ftmpl? "=$Ftmpl" : ">0"); 
my $Frevision=int $F{revision};
 my $sql=$Frevision? "SELECT * FROM dop_oldvalues WHERE revision=$Frevision" :
         $Fid? "SELECT * FROM dopvalues WHERE parent_id=$Fid" : "SELECT * FROM dopvalues WHERE 0=1" ;
$sql="SELECT * FROM dopfields f LEFT JOIN ($sql) v ON f.id=v.dopfield_id $where ORDER BY template_num,field_name";
$sth=&sql($dbh,$sql);
 my $out='';
 my $last_tmpl=-1;
 while($p=$sth->fetchrow_hashref)
 {
   ($did,$field_name,$field_alias,$field_type,$field_flags,$field_value,$template_num)=&Get_fields qw(
      id  field_name  field_alias  field_type  field_flags  field_value  template_num );

   $Dopfields_tmpl_name{$template_num} ne '' or next;

   if( $last_tmpl!=$template_num )
   {
      $last_tmpl=$template_num;
      $out.=&RRow('head','3','������: '.&commas( &Filtr($Dopfields_tmpl_name{$template_num}) || "� $Ftmpl") );
   }

   $comment='';
   $val=$field_value;
   $h="dopfield_$did";

   if ($field_type<=3)
   {  # �����
      $val=($field_flags=~/a/ && ($val eq '') || !$act_edit)? '' : $field_type<=1? int $val : $val+0;
      $h=&input_t($h,$val,56,30);
      $comment='�������'.($field_type<=1 && ' �����').(($field_type==1 || $field_type==3) && ' �������������').' �����.';
   }
    elsif ($field_type==4)
   {  # ��������� ������������
      $val=~s|\n| |g;
      $h=&input_t($h,$val,56,9999);
   }
    elsif ($field_type==6)
   {  # ��/���
      $h="<select name=$h size=1>".
        "<option value=''".(!$act_edit && ' selected').'>&nbsp;</option>'.
        '<option value=1'.($act_edit && !!$val && ' selected').'>��</option>'.
        '<option value=0'.($act_edit && !$val && ' selected').'>���</option>'.
         '</select>';
   }
    elsif ($field_type==7)
   {  # �������� � �������
#      $act_edit or next;
      (!$act_edit or !$Fparent_type) && next;
      ($owner_type,$owner_id)=split/:/,$val;
      if ($owner_id && !$Fcopy)
      {
         $owner_str=&nEq_owner($owner_type,$owner_id).'. ';
      }
       else
      {  # �������� � �������� ������
         $owner_id=$Admin_id;
         $owner_type=1;
         $owner_str='';
      }
      $owner_type=$Fowner_type if defined $F{owner_type};
      $owner_id=$Fowner_id if defined $F{owner_id};
      $h="<select name=$h size=1>";
      $h.=join '', map{ "<option value=$_".($_==$owner_type && ' selected').">$Owner_types[$_]</option>" } (0..$#Owner_types);
      $h=$owner_str.'���������� ���������:'.$br2.$h.'</select> id: '.&input_t("dopfield_owner_$did",$owner_id,10,10);
   }
    elsif ($field_type==8)
   {  # ���������� ������. ������ ������� �� ��, ��������� � ������ ����
      $val=int $val;
      $field_alias=~s/ //g;
      if ($field_alias=~/^([^:]+):([^:]+):([^:]+)$/)
      {
         ($h_tbl,$h_num,$h_descr)=($1,$2,$3);
         $h_tbl=&Filtr($h_tbl);
         $h_num=&Filtr($h_num);
         $h_descr=&Filtr($h_descr);
         $h_sel=$field_flags=~/a/ || !$act_edit? "<option value=''>&nbsp;</option>" : '';
         $sth2=&sql($dbh,"SELECT $h_num,$h_descr FROM $h_tbl ORDER BY $h_descr");
         while ($p2=$sth2->fetchrow_hashref)
         {
            $num=$p2->{$h_num};
            $h_sel.="<option value=$num".($val==$num && ' selected').">$p2->{$h_descr}</option>"; 
         }
         $h="<select name=$h size=1>$h_sel</select>";
      }else
      {
         $h=&input_h($h,$val).&Printf('[span error]','���������� � �������� �������������� - ������ � �������� �������� ����');
      }
   }
    elsif ($field_type==9)
   {  # ������
      $val=~s|\n| |g;
      # �����������. �����:
      $len=7+int(rand 3);
      for ($i=0, $pass=''; $i<$len; $i++) {$pass.=(0..9,'A'..'Z','a'..'z','@','.',',','-','=','%','$','(',')',':','_','?','+','#')[rand 76]}
      $comment.=&ahref('#','�������� �������',qq{OnClick="javascript:document.getElementById('$h').value='$val'"}).$br if $val;
      $comment.=&ahref('#','�������� ���������������',qq{OnClick="javascript:document.getElementById('$h').value='$pass'"}) if $act_edit;
      $h=&input_t($h,'',56,9999,"id='$h'");
   }
    else
   {  # ��������� �������������
      $h=&input_ta($h,$val,40,4);
   }
   
   if (!$act_edit)
   {   # ���� ����� � ���� �� (���������� ������ | yes/no) - ������� ����� `������ ������������`.
       # ���� ���� � ������� `�����` (����� ���������� � `_adr_`) - �������� ����� `������ ������������`
       $h.=$field_type==6 || $field_type==8? &input_h("dopfield_full_$did",1) :
           $br."<input type=checkbox name=dopfield_full_$did value=1".($field_alias=~/^_adr_/ && ' checked')."> ������ ������������";
   }
   $comment.=($comment ne '' && $br).'�������� ������ ���� ����������' if $field_flags=~/h/;
   $comment.=($comment ne '' && $br2).&Show_all($p->{comment}) if $p->{comment};
   $field_name=~s/^\[(\d+)\]\s*//;
   $out.=&RRow('*','lll',$field_name,$h,$comment);
 }

 $out or &Error("� ������� $tmpl_name ��� �������� �� ������ ����. ".($pr_SuperAdmin? &ahref("$scrpt0&a=oper&act=dopfields",'������� &rarr;') : '���������� � �������� ��������������'),$tend);

 if ($Fparent_type)
 {
    $Fid=0 if $Fcopy;
    $OUT.=&div('message',&Printf('����� ������� �� ������ `���������` ����� ������� ����� ������� ������������ ���� []',$tmpl_name)) if $act_edit && !$Fid;
    $out.=&RRow('*','lll',"<input type=checkbox name=copy value=1".(!!$Fcopy && ' checked').'>',
       '����� ���������� ������, ������� � �������� ����� ������� ������������, � ���� ��������� ��� � ������� ������','') if $Fact eq 'edit';
    $out=&RRow('row3','lll',
       '���������� �����',
       qq{<span onClick='window.clipboardData.setData("Text","$Fid")' class=data2 style='cursor:pointer;border:0;'>$Fid</span><br>},
       '���� ����� ������������ ������ ������ NoDeny ��� ������������� ����� ���������').$out if $Fid;
 }

 %f=$act_edit? ('!'=>1,'act'=>'save','tmpl'=>$Ftmpl,'parent_type'=>$Fparent_type,'id'=>$Fid,'time'=>$t) :
    $Fparent_type? ('!'=>1,'a'=>'equip','act'=>'find','tmpl'=>$Ftmpl) : 
               ('!'=>1,'a'=>'listuser','f'=>'q','tmpl'=>$Ftmpl);

 $OUT.=&div('message cntr',$br.&Center(
   &form(%f,
     &Table('tbg3',$out).$br.
     (!$act_edit? &submit_a('�����') : $pr_can_edit? &submit_a('���������') : &Center(&MessX('�������������� ������ �� ���������'))).$br
   )
 ));
 &Exit;
}

# ===============================================
#              ���������� ������
# ===============================================

$pr_can_edit or &Error("��� ���� �� ��������� �������������� ������.".$go_back,$tend);

$OUT.=&MessX('���������� ������.');

# ���������� ����� ������� ����� ������� ������ ��������� ������ (parent_id=0). ����� ������� ������� �� ����������������� ���� line_id.
$sql="INSERT INTO dop_oldvalues (parent_id,time) (SELECT 0,MAX(parent_id)+1 FROM dopdata WHERE parent_type=1)";
$sth=$dbh->prepare($sql);
$sth->execute;
$revision=$sth->{mysql_insertid} || $sth->{insertid};
&DEBUGX(&Printf('[][br][span data2][]',$sql,'�������������� ����� �������:'," insertid = $revision"));
$revision or &Error("������ ��� ��������� ������ $url_client.".$go_back,$tend);

if ($Fparent_type && !$Fid)
{# �������� ����� ������� ������������. id ����� ����� �������� ���� time (� ������ ������ ��� �� �����)
   $p=&sql_select_line($dbh,"SELECT time FROM dop_oldvalues WHERE line_id=$revision");
   $p or &Error("������ ��� ��������� ������ ������� ������������.".$go_back,$tend);
   $Fid=$p->{time} || 1; # ! �.�. select null+1 (������� MAX(parent_id) � ������ �������) ���� null
   $created=1;
}else
{
   $created=0;
}

$stop=0;
$sql='';
my $where=$Ftmpl? "WHERE template_num=$Ftmpl" : '';
$sth=&sql($dbh,"SELECT * FROM dopfields $where ORDER BY template_num,field_name",'�������� ����� ��������� �������');
while($p=$sth->fetchrow_hashref)
{
   ($did,$field_name,$field_type,$field_flags,$template_num)=&Get_fields qw(
      id  field_name  field_type  field_flags  template_num);
   $field_name=~s/^\[(\d+)\]\s*//;
   $val=$F{"dopfield_$did"};
   defined $val or next;

   $val=~s|^\s+|| if $field_flags=~/b/;
   $val=~s|\s+$|| if $field_flags=~/c/;
   $val=&lc_rus($val) if $field_flags=~/d/;
   $val=&translit($val) if $field_flags=~/e/;
   $val=~s|\s+||g if $field_flags=~/f/;

   if ($field_type<=1)
   {  # ����� �����
      $val=$field_flags=~/a/ && ($val eq '')? '' : int $val; # �������� ������������� �� ����� �����
   }
    elsif ($field_type<=3)
   {  # ������������
      $val=~s|,|.|;
      $val=$field_flags=~/a/ && ($val eq '')? '' : $val+0;
   }
    elsif ($field_type==6)
   {  # ��/���
      $val=$val? 1:0;
   }
    elsif ($field_type==7)
   {  # �������� � �������
      $owner_id=int $F{"dopfield_owner_$did"};
      $error=0;
      if (!defined($Owner_types[$val]))
      {
         $error=1;
         $OUT.=&div('message lft','�������� ������������ ������ � ���������, �� ���������������� ���������� ������������� ������.');
         $stop++;
      }
       elsif ($owner_id<=0)
      {
         $error=1;
         $OUT.=&div('message lft','Id ��������� �� ������, �� ���������������� ���������� ������������� ������.');
         $stop++;
      }
       else
      {
         $owner=&nEq_owner($val,$owner_id);
         if (!$owner)
         {
            $error=1;
            $OUT.=&div('message lft','��������� � ��������� id �� ����������, �� ���������������� ���������� ������������� ������.');
            $stop++;
         }
      }

      if ($error)
      {
         $val="1:$Admin_id";
      }
       else
      {
         $val="$val:$owner_id";
      }
   }
    elsif ($field_type==8)
   {  # ���������� ������
      $val=int $val;
   }
    else
   {  # ���������
      $val=~s|\n||g if $field_type==4 || $field_type==9; # ������������ ���� ������
   }

   # �������� ��������������� �����
   if ($val<0 && ($field_type==1 || $field_type==3 || $field_type==8))
   {
      $val=-$val;
      $OUT.=&div('message lft',&Printf('[bold] � ��������� [commas] ����������� ������ ������������� �����. '.
         '������������� � ��������������[br]','��������������:',$field_name));
      $stop++;
   }

   # �������� ���������� ����������
   $h=$p->{field_template};
   if ($h ne '' && $val!~/$h/m && ($val || $field_flags!~/a/))
   {
       $OUT.=&div('message lft',&Printf('[bold] �� ������� ������ �������� [commas] - �� �� ������������� �������. '.
          '�������� �� ����������.[br]','��������������:',$field_name));
       &DEBUGX(&Printf('������ ��� `[filtr]`: [filtr][br]������: [filtr]',$field_name,$h,$val));
       $stop++;
       next;
   }
   $val=&Filtr_mysql($val);
   $sql.="($Admin_id,$Fid,$did,'$val',$t,$revision),"; # ! �� $ut - ������������� ������� ����� �� ������� � ���� �������
}
$sql or &Error('������ �� ��������.',$tend);
chop $sql;

$Ftime=int $F{time};


$rows=&sql_do($dbh,"INSERT INTO dop_oldvalues (admin_id,parent_id,dopfield_id,field_value,time,revision) VALUES $sql");
$rows<1 && &Error('������ ��� ���������� ������.',$tend);

$url.="&amp;copy=$Fcopy&id=$Fid&updated=1"; # ! id=$Fid

$sql=nSql->new({
       dbh     => $dbh,
       sql     => "CALL set_dopvalues($revision)",
       show    => 'line',
       comment => "������ ��������� ������ ������� $revision",
});
%h=%{ $sql->get_line };
# ��������� ������� ������
$url.="&error=$h{error}&descr=$h{descr}&revision=$revision" if $h{error};

$DOC->{header}.=qq{<meta http-equiv="refresh" content="0; url='$url'">} if !$stop;
&OkMess('��������� � ������ �������'.$br2.&CenterA($url,'����� &rarr;'));

1;
