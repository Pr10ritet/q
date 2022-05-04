#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('tune');

$pr_main_tunes or &Error('��� �� �������� ������ � ���������� �������.');
$AdminTrust or &Error('�� �������� ������ � ����������, ��������� ��� ����������� �� �� �������, ��� ��������� �� ���������� �����������.');

$list_cfg="$Nodeny_dir_web/list.cfg";

# ����� ���������� ���������
sub ErrorPar 
{
 my $h=$_[2];
 $h=~s|\\n|<br>|g;
 $OUT.=$br.&div('message nav lft',"<span class=$_[0]>$_[1]</span> $h$_[3]");
}

sub filtr_param
{
 local $_=shift;
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|\r||g;
 return $_;
}

open(FL,"<$list_cfg") or &Error("������ �������� ����� �������� $list_cfg");
@list=<FL>;
close(FL);

foreach (reverse @list)
{
   /^#(\d\d.\d\d)/ or next;
   $1==$VER_chk or &Error("�������� ������ $1 �����".$br2.$list_cfg);
   last;
}

$Fact=$F{act};

if( $Fact eq 'save' )
{
 $pr_edt_main_tunes or &Error("� ��� ��� ���� �� ��������� ��������.");
 $need_restart=0;
 $F{iamshure} or &Error("�� �� ��������� �������, �������������� ���� ���������.$go_back");
 $new_Passwd_Key=&Filtr_mysql($F{Passwd_Key});
 $i=0;
 $remake='';
 $OUT.="<div align=left>";
 $show_config=$config="#NoDeny Config File\n\n"."\$VER_cfg = $VER_chk;\n";
 foreach $parm (@list)
 {
    $parm=~/^\s*#/ && next; # �����������
    $parm=~/^\s*$/ && next; # ������ ������

    if( $parm!~/\s*(.)\s+(.+?)\s+(.+?)\s+'(.*)'\s*$/ )
    {
       &ErrorPar('error',"������ � ����� $list_cfg.",' ������:'.$br2.&Filtr_out($parm),'');
       next;
    }
    ($S1,$S2,$S3,$S4)=($1,$2,$3,$4);

    if( $S1 eq 'R' )
    {
       $remake=&CenterA("$scrpt&i=$i",'���������');
       $i++;
    }

    if( $S1=~/[sfnb]/ )
    {  # �������� - ����������
       $old=${$S2};

       if( defined $F{$S2} )
       {
          $new=$F{$S2};
          $new=~s|\s+$||;	 		# ������ ����������� ������� � ���������� ����� ����� ������
          $new=$old if $S3=~/=/ && $new eq '';	# ������� �������� � ������ �� ������� - �� ������
          if( $new ne $old )
          {
             &ErrorPar( 'data1','������� ��������:',$S4,&Printf('[br][span data1] [filtr|commas] &rarr; [filtr|commas]','��������:',$old,$new) );
             $need_restart=1 if $S3!~/0/;
          }
       }
        else
       {
          $new=$old;
       }

       if( $S1 eq 'f' && $new && !(-e $new) )
       {
          &ErrorPar('error','���� �� ����������.', '��� �����: '.&Filtr_out($new),$br.$S4.$remake);
       }

       if( $S1 eq 's' || $S1 eq 'f' )
       {  # ��������� ��������
          $new=~s|\n| |g;
          $new="'".&filtr_param($new)."'";
       }

       if( $S1 eq 'n' )
       {  # ����� �����
          $new=~/^-?\d*\.?\d*$/ or &ErrorPar('error','�������� ������ ���� ������:',&Filtr_out($new),$br.$S4.$remake);
          $new+=0;
       }

       $new=int($new) if $S1 eq 'b';

       $add="\$$S2 = $new;\n";
       $config.=$add;
       $show_config.=$add if $S3!~/=/; # ������� ��������
       next;
    }

    if( $S1 eq '@' )
    {  # �������� - ������. ��������! ��������������� ������ "������� �������" (\r)
       if (defined $F{$S2})
       {
          $F{$S2}=~s/\n+|(\r\n)+/\n/g;
          @massiv=split /\n/,$F{$S2};
          $c="@massiv";
          $d="@{$S2}";
          if( $c ne $d )
          {
             $need_restart=1;
             &ErrorPar('data1','������� ��������:',$S4,"&nbsp;");
          }
       }
        else
       {
          @massiv=@{$S2}
       }

       $add='@'.$S2." = (\n '".join("',\n '",map{ &filtr_param($_) } @massiv)."'\n);\n";
       $config.=$add;
       $show_config.=$add;
       next;
    }

    if( $S1 eq 'g' )
    {  # �������� - ���2
       if( defined($F{"${S2}_1"}) )
       {
          $S3+=0;
          $S3=99 if $S3>99;
          %massiv=();
          for ($x=1;$x<=$S3;$x++)
          {
             $a=$F{"${S2}_$x"};
             $b=$F{"${S2}.$x"};
             $a=~s|\s+$||;
             $b=~s|\s+$||;
             $a=~s|-| |; # � ��� '-' �������� ������������
             $b=~s|-| |;
             ($a eq '') && next;
             $massiv{$x}="$a-$b";
          }
          # ��������� �� ������? (����� �� ������� �������)
          $c=''; $d='';
          foreach $a (sort keys %massiv) {$c.="$a$massiv{$a}"}
          foreach $a (sort keys %{$S2}) {$d.="$a${$S2}{$a}"}
          if ($c ne $d)
          {
             $need_restart=1;
             &ErrorPar('data1','������� ��������:',$S4,"&nbsp;");
          }
       }
        else
       {  # ����� ����� ������ �� ������� - ������� ������������
          %massiv=%{$S2};
       }
       $add='';
       while( ($key,$val)=each(%massiv) )
       {
          $val=&filtr_param($val);
          $key=&filtr_param($key);
          $add.=" '$key' => '$val',\n";
       }
       $add="\%$S2 = (\n$add);\n";
       $config.=$add;
       $show_config.=$add;
       next;
    }

    if( $S1 eq 'm' )
    {  # �������� - ���1
       if( defined($F{"${S2}_1"}) )
       {
          $S3=int $S3;
          $S3=99 if $S3>99;
          %massiv=();
          for ($x=1;$x<=$S3;$x++)
          {
            $a=$F{"${S2}_$x"};
            $a=~s|\s+$||;
            ($a eq '') && next;
            $massiv{$x}=$a;
          }
          # ��������� �� ������? (����� �� ������� �������)
          $c=''; $d='';
          foreach $a (sort keys %massiv) {$c.="$a$massiv{$a}"}
          foreach $a (sort keys %{$S2}) {$d.="$a${$S2}{$a}"}
          if( $c ne $d )
          {
             $need_restart=1;
             &ErrorPar('data1','������� ��������:',$S4,"&nbsp;");
          }
       }
        else
       { # ����� ����� ������ �� ������� - ������� ������������
          %massiv=%{$S2}
       }
       $add='';
       while( ($key,$val)=each(%massiv) )
       {
          $val=&filtr_param($val);
          $add.=" $key => '$val',\n";
       }
       $add="\%$S2 = (\n$add);\n";
       $config.=$add;
       $show_config.=$add;
    }    
 }


 if( !$Admin_id && $sadmin )
 {
   $sadmin=&filtr_param($sadmin);
   $config.="\$sadmin='$sadmin';\n";
 }

 $config.="\n1;\n";

 open(FL,">$Main_config") or &Error('�� ���� �������� ��������������� ���� '.&bold($Main_config).$br.'�������� ��� ����.');

 print FL $config;
 close(FL);

 $h=&div('big','���������������� ���� ������� �������.');
 $h.=$br.($need_restart? '��� ���������� ��������� ���������� �������'.$br2.&CenterA("$scrpt0&a=restart&act=send&s=7",'������� ���� NoDeny') : 
    '�� �������� ��������� �� �������� �� ������ ���� NoDeny. ������� �� �����.').$br if $Admin_id;
 &OkMess($h);

 $config=~s/\\/\\\\/g;
 $config=~s/"/\\"/g;

 # ������� ���� � ���� ������, ���������� ����� � �� ����, ���� ��� ������ �������
 if( $dbh )
 {
    $rows=$dbh->do("INSERT INTO config SET time=$ut,data=\"$config\"");
    $OUT.=$br.&error('������ ������ ������� � ���� ������',$br2.'��������� ����� �� ������� ����� ������!') if $rows<1;

    if( $new_Passwd_Key && $new_Passwd_Key ne $Passwd_Key )
    {  # ��������� ���� �����������, &sql_do �� ��������� - �� ������ ������
       $sql="UPDATE users SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,'$Passwd_Key'),'$new_Passwd_Key')";
       $rows=$dbh->do($sql);
       $OUT.="<div class='message lft'>��� ������� ���� ����������� �������. ���������� ���������� ��������������� �������. �������� ������$br2$sql$br2 ��������� $rows �����".$br2;
       $sql="UPDATE admin SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,'$Passwd_Key'),'$new_Passwd_Key')";
       $rows=$dbh->do($sql);
       $OUT.="��� ��������� �������:".$br2.$sql.$br2."��������� $rows �����</div>";
       $sql="UPDATE conf_sat SET Passwd_Key='$new_Passwd_Key'";
       $rows=$dbh->do($sql);
    }
 }

 $show_config=&Filtr_out($show_config);
 $show_config=~s/\n/<br>/g;

 $OUT.='</div>'.$go_back.$br2.($Admin_id? &div('message lft',$show_config) : &ahref("$scrpt0&a=admin",'������� ������� ������ �������������� &rarr;'));

 &Exit;  
}

if( $VER_cfg!=$VER_chk && $Admin_id )
{
   $VER_cfg||='?';
   &Message("������ ����������������� ����� ($VER_cfg) �� ������������� ������ ����������������� ���������� ($VER_chk). ".
     '�������� �� ��������� NoDeny. ������ ��������� ��������� � ���� ����. '.
     '���� ������ ���������� - �������� ���������� ������ �����������.',$err_pic,'��������','','infomess');
   &Message('����� ���������� �������� �� �������� ���������� ���� �������� ��� ������� ������� ���������!',$err_pic,'��������','','infomess');
}

# =======       ����������� ����������      ===========

%menu=();
$body='';
$Fi=int $F{i}+1;
$i=0;
$size=28;			# ������ ���� ����� �� ���������
foreach $parm (@list)
{
  $parm=~/^\s*#/ && next;	# �����������
  $parm=~/^\s*$/ && next;	# ������ ������
  if( $parm!~/\s*(.)\s+(.+?)\s+(.+?)\s+'(.*)'\s*$/ )
  {
     $body.=&RRow('*','^T',"<span class=error>������ � �����</span> $list_cfg",'������ � �������:'.$br.&div('lft',&Filtr_out($parm)));
     next;
  }
  ($S1,$S2,$S3,$S4)=($1,$2,$3,$4);

  if( $S1 eq 'R' )
  {  # ������ ����
     $menu{$S4}= ($i+1)==$Fi? &div('head',&ahref("$scrpt&i=$i",$S4)) : &ahref("$scrpt&i=$i",$S4);
     $body.=&RRow('head','3','������: '.&bold_br($S4)) if ++$i==$Fi;
     next;
  }

  $i==$Fi or next;

  $S4=~s|\\n|<br>|g;
  #$S4=&Show_all($S4);

  if ($S1 eq 'm' || $S1 eq 'g')
  {
   # ������ ��� �������������� ������
   $body.=&RRow('row3','E',$S4);
   $S3=int $S3;
   $S3=99 if $S3>99;
   if( $S1 eq 'g' )
   {
      for ($x=1;$x<=$S3;$x++)
      {
        $y=${$S2}{$x};
        if ($y=~/^(.+)-(.+)$/) {$p1=$1; $p2=$2} else {$p1=$y; $p1=~s|-||; $p2=''}
        $body.=&RRow('*','rrl','� '.&bold($x),&input_t("${S2}_$x",$p1,30,128),&input_t("${S2}.$x",$p2,30,128));
      }
      next;
   }
   for ($x=1;$x<=$S3;$x++)
   {
      $body.=&RRow('*','rl ','� '.&bold($x),&input_t("${S2}_$x",${$S2}{$x},30,128),'');
   }
   next;
  }
        
  $x='';
  if( $S1=~/[sfn]/ )
  {  # �������� - ����������
     $x=$S3!~/=/? &Filtr_out(${$S2}) : '';
     $rsize=$S3=~/3/? 66 : $S3=~/1/? 56 : $size;
     $x=$S3=~/4/? "<textarea name=$S2 type=text cols=$rsize rows=4>$x</textarea>" : &input_t($S2,$x,$rsize,255);
  }

  if( $S1 eq 'b' )
  {  # ��/���
     $x="<select name=$S2 size=1>".
         (${$S2}? "<option value=1 selected>��<option value=0>���</option>" : "<option value=1>��<option value=0 selected>���</option>").
        '</select>';
  }

  if( $S1 eq '@' )
  {
     $cols=$S3=~/3/? 66 : $S3=~/1/? 46 : 25;
     $rows=$S3=~/2/? 17 : 10;
     $x="<textarea name=$S2 rows=$rows cols=$cols>".&Filtr_out(join("\n", @{$S2}))."</textarea>";
  }

  if( $S1 eq 'C' )
  {
     $body.=&RRow('head','E',$S4);
     next;
  }
  
  $body.=$x? &RRow('*',$S3=~/[13]/? 'Ll':'lL',$x,$S4) :
    &RRow('head error','E','����������� ��� ��������� '.&Filtr_out($S1));
}

$body="<table class='tbg3'>$body<tr class=tablebg><td width='10%'>$spc</td><td>$spc</td><td width='69%'>$spc</td></tr></table>";

$body=$pr_edt_main_tunes? &form('!'=>1,'act'=>'save','i'=>$Fi-1,$body.
  &div('cntr',$br."<input type=checkbox name=iamshure value=1 style='border:1;'> ".
      "<span class=data2>������������� ��������� ��������</span>".$br2.&submit_a('���������'))) :
  &div('message','��� �������� ������ �������� �������').$body;

{
 $dbh or last;
 $str=nSql->new({
   dbh		=> $dbh,
   sql		=> "SELECT field_name FROM dopfields WHERE field_alias='p_street:street:name_street'",
   show		=> 'full',
   hash		=> \%h,
   comment	=> '�������� ���� `�����`'
 })? &Del_Sort_Prefix($h{field_name}) : '�����';
 
 
 foreach ( 
  '������ ��������������|plans3',
  '�����������|nets',
  '������ ��������|usr_grp',
  '����������������� �����������|newuser',
  "$str|str",
  '������|of',
  '���������|sat',
  '�������������� ����|dopfields'
 )
 {
    /^(.+)\|(.+)$/;
    $h=$1; # ! ���� ����� � &ahref � ������� ����� ���������� ���������
    $menu{$h}=&ahref("$scrpt0&a=oper&act=$2",$1);
 }
 $menu{'���������� ���������������'}=&ahref("$scrpt0&a=admin",'���������� ���������������');
 $menu{'������'}=&ahref("$scrpt0&a=tarif",'������');
}

$menu=join '',map {$menu{$_}} sort {$a cmp $b} keys %menu;
$OUT.=&div('lft',"<table cellpadding=1 cellspacing=8>".&RRow('','^^',&Mess3('row2 nav2',$menu),$body).'</table>');

1;
