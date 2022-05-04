#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$PR{103} or &Error("� ��� ��� ���� �� ������ � ������� ������������");

$Fact=$F{act};

%subs=(
 'main'		=> \&eq_main,
 'find'		=> \&eq_find,
);

$Fact||='main';

exists($subs{$Fact}) or &Error(&Printf('����������� ������� act=[filtr]',$Fact).$go_back);

&LoadEquipMod;
&LoadDopdataMod();

$menu=&ahref("$scrpt",'����������');
$menu.=$br.'�������� ������������:'.$br2;

$menu.=join '',
   map{ &ahref("$scrpt&act=find&tmpl=$_",(split /-/,$Dopfields_tmpl{$_})[0]) } 
   sort{ $Dopfields_tmpl{$a} cmp $Dopfields_tmpl{$b} }
   grep{ int($_/100)==1 }
   keys %Dopfields_tmpl;

$menu.=$br.&ahref("$scrpt&act=find&owner_type=1&owner_id=$Admin_id",'�������� �� ����');


$OUT.="<table class='width100 pddng'><tr>".
  "<td valign=top class=nav2 width=16%><br>".&Mess3('row2',$menu)."</td><$tc valign=top>".$br;
$tend='</td></tr></table>';

&{ $subs{$Fact} };
$OUT.=$tend;
&Exit;

sub eq_main
{
   $out='';
   foreach $owner_type (0..$#Owner_types)
   {
      $p=nSql->new({
        dbh	=> $dbh,
        sql	=> "SELECT COUNT(parent_id) AS n FROM dopdata WHERE field_type=7 AND field_value LIKE '$owner_type:%'",
        ret	=> { n => \$n }
      });
      $p->{ok} or next;
      $out.=&RRow('*','lrc',$Owner_types[$owner_type],$n,&ahref("$scrpt&act=find&owner_type=$owner_type",'&rarr;'));
   }
   $out=&Table('width100 tbg3 nav3',&RRow('tablebg','ccc','���������','������ ������������','�����').$out);
   $OUT.=&div('message',$out);
}

sub eq_find
{
    $url="$scrpt&act=$Fact";
    $err='������� ������ ������� ������';
    if (defined $F{owner_type})
    {  # ����� �� ���������
       $Fowner_type=int $F{owner_type};
       defined $Owner_types[$Fowner_type] or &Error("$err: ��� ��������� ($Fowner_type) �������",$tend);
       $Fowner_id=int $F{owner_id};
       $owner_id_str=$Fowner_id || '%';
       $url.="&owner_type=$Fowner_type&owner_id=$Fowner_id";
       $OUT.=&MessX("����� �� ���������: ".&nEq_owner($Fowner_type,$Fowner_id),0,1);
       $sql="SELECT * FROM dopdata WHERE field_type=7 AND field_value LIKE '$Fowner_type:$owner_id_str'";
    }
     elsif (defined $F{tmpl})
    {  # ����� �� ���� ������������
       $Ftmpl=int $F{tmpl};
       $url.="&tmpl=$Ftmpl";
       $OUT.=&MessX("����� �� ����: ".&ahref("$scrpt0&a=dopdata&parent_type=1&tmpl=$Ftmpl&act=search",(split /-/,$Dopfields_tmpl{$Ftmpl})[0]),0,1);
       %search_data=();
       foreach (keys %F)
       {
          /^dopfield_(\d+)$/ or next;
          ($F{$_} ne '') or next;
          $url.="&$_=$F{$_}";
          $search_data{$1}=$F{"dopfield_full_$1"}? $F{$_} : "%$F{$_}%";
       }
       $sql=&nDopdata_search
       ({
            parent_type		=> 1,		# ����� ������������
            template_num	=> $Ftmpl,	# � ������� � $Ftmpl
            sort_id		=> $sort,	# ����������� �� ����
            data		=> \%search_data
       });
    }
     else
    {
       &Error("�� ������ ������� ������",$tend);
    }

    %fields=(
       field_name	=> \$field_name,
       field_value	=> \$field_value,
       field_alias	=> \$field_alias,
       field_type	=> \$field_type
    );
    $out='';
    ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,30,$url,$dbh);
    $page_buttons&&=&RRow('tablebg',4,$page_buttons);
    while( $p=$sth->fetchrow_hashref )
    {
       ($id)=&Get_fields qw(id);

       $nsql=nSql->new({
          dbh		=> $dbh,
          sql		=> "SELECT field_value FROM dopdata WHERE field_type=7",
          show		=> 'line',
          comment	=> '��������',
          ret		=> { field_value => \$field_value }
       });
       if( $nsql->{ok} )
       {
          ($owner_type,$owner_id)=split /:/,$field_value;
          $owner=&nEq_owner($owner_type,$owner_id) || &Printf('[span error]',"�������� ������ (type=$owner_type, id=$owner_id)");
       }
        else
       {
          $owner=&Printf('[span disabled]','�����������');
       }

       $out2=''; # ��������� ����
       $nsql=nSql->new({
          dbh		=> $dbh,
          sql		=> "SELECT field_name,field_value,field_alias,field_type FROM dopdata WHERE field_flags LIKE '%q%' ORDER BY field_name",
          show		=> 'line',
          comment	=> '��������� ����'
       });
       while( $nsql->get_line(\%fields) )
       {
          $field_name=~s|^\[\d+\]||;
          $field_name=&Printf('[span disabled]',$field_name);
          $field_value=&Filtr_out(
            &nDopdata_print_value
            ({
               type	=> $field_type,
               alias	=> $field_alias,
               value	=> $field_value,
            })
          );
          $out2.=&RRow('','lr',$field_name,$field_value);
       }
       $out2=&Table('table2 width100',$out2) if $out2;

       $out.=&RRow('*','rlll',
          &ahref("$scrpt0&a=dopdata&parent_type=1&id=$id",$id.'&nbsp;&nbsp;'),
          $owner,
          '',
          $out2
      );
    }

    $out or &Error('�� �������� ��������� ������ ������ �� �������.',$tend);

    $OUT.=&Table('tbg1 nav3 width100',
       &RRow('head','cccc','����������'.$br.'�����','��������','��������� ���������','��������� ����').
       $page_buttons.
       $out.
       $page_buttons
    );
}

1;
