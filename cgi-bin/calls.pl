#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

use Time::HiRes qw( gettimeofday tv_interval );
use Time::Local;
use Digest::MD5;
use IO::Socket;
use FindBin;

sub sub_zero {}

sub Go_out
{
 my $out.=!!$Ashowsql && &tag('div',
     &tag('div',&ahref('javascript:show_x("adm")',"������ &uarr;"),"class='nav cntr' style='float:right'").
     "$DOC->{admin_area} ����� ����� ���������� sql-��������: $T_sql ���",
 "id=my_x_adm style='display:none' class=message"
 );
 $OUT="Content-type: text/html\n".
   ($DOC->{cookie} && $DOC->{cookie}."\n")."\n".
   &tag('html',
      &tag('head',
         &tag('title',$Html_title).
         $DOC->{header}
      ).
      &tag('body',
        $out.
        &tag('div',$OUT,'align=center id=maindiv'),
      $DOC->{body_tag})
   );
}

sub DEBUG
{
 $DOC->{admin_area}.=$_[0] if $Ashowsql;
}

sub DEBUGX
{
 $DOC->{admin_area}.=&MessX(@_) if $Ashowsql;
}

sub DebugError
{
  &DEBUGX(shift @_);
  &Error(@_);
}

sub Exit
{
 &DEBUGX($Debug) if $Ashowsql && $Debug;
 &Go_out;
 print $OUT;
 exit;
}

# �� ������ �������� � ������� ������� �.�. �����. ������� ��� �������� ������
sub VerWrong
{
 $_=$_[0]||'����������';
 s|^.+/||;
 $VER_script=~s|^.+/||;
 $VER_script eq 'stat.pl' && &Error('VerWrong: ������� �������� ����������');
 &Error("�������������� ������ �������� ($_: $VER, $VER_script: $VER_chk)! ���������� � �������� ��������������.");
}

# &div('error row1','text',1)	-> <div class='error row1'>text</div><br>
# &div('','text')		-> <div>text</div>
sub div
{
 return('<div'.($_[0] && " class='$_[0]'").">$_[1]</div>".(!!$_[2] && '<br>'));
}

sub Good_Exit
{
 $OUT.=&div('infomess nav lft',$_[0]);
 &Exit;
}

sub GoodC_Exit
{
 $OUT.=&div('infomess nav cntr',$_[0]);
 &Exit;
}

sub Filtr
{
 local $_=shift;
 s|\n| |g;
 s|'|`|g;
 s|[^ \-A-Za-z0-9�-��-���������()"`.,+=!?:;*~_\@\$�\/#\^\[\]\|]||g;
 return($_);
}

sub Filtr_all
{
 local $_=shift;
 tr|\x00-\x1f||;
 s|[&<>'\\]||g;
 s|<|&lt;|g;
 s|>|&gt;|g;
 s|'|&#39;|g;
 return($_);
}

sub Filtr_out
{
 local $_=shift;
 tr|\x00-\x09| |;
 tr|\x0e-\x1f| |;
 s|&|&amp;|g;
 s|<|&lt;|g;
 s|>|&gt;|g;
 s|'|&#39;|g;
 return($_);
}

sub Filtr_sql
{
 local $_=shift;
 tr|\x00-\x1f||;
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|\r||g;
 return($_);
}

sub Filtr_mysql
{
 local $_=shift;
 tr|\x00-\x1f||;
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|\r||g;
 s|~||g;	# ����������� ������ nodeny, ��. &Show_all
 return($_);
}

# ������������� ��� html, ������ \n �� <br>, ��������������:
# ~url(�����1~)(�����2~)	-> <a href='�����1'>�����2</a>
# ~frame(�����~)		-> <div class=borderblue>�����</div>
# ~img(���~)			-> <img src='���'>
# ~bold(�����~)
# ���� ~ �� ������ ����������� � ������!
sub Show_all
{
 local $_=&Filtr_out($_[0]);
 s|~url\(([^~]+)~\)\(([^~]+)~\)|<a href='$1'>$2<\/a>|g;
 s|~bold\(([^~]+)~\)|<b>$1<\/b>|g;
 s|~frame\(([^~]+)~\)|<div class=borderblue>$1<\/div>|g;
 s|~\(([^~]+)~\)|<div class='bordergrey row3'>$1<\/div>|g;
 s|~img\(([^~]+)~\)|<img src='$1'>|g;
 s|\n|<br>|g;
 s|^ ||;
 s| $||;
 return($_);
}

# ����������� ������������ � �������� � ��� %xx ��������� ��� url
sub URLEncode
{
 my $url=shift;
 $url=~s/([^a-zA-z0-9])/sprintf('%%%02X',ord($1))/eg;
 return $url;
}

sub Get_fields
{
 return map {$p->{$_}} (@_);
}

sub Get_filtr_fields
{
 my @f=@_;
 return map {&Filtr_out($p->{$_})} (@f);
}

# ����������� ����� � ���� '12 345 678'
sub split_n
{
 local $_=shift;
 1 while s/^([-+]?\d+)(\d{3})/$1 $2/;
 return($_);
}

sub lc_rus
{
 local $_=shift;
 tr/�������������������������������ި���/������������������������������������/;
 return($_);
}

sub translit
{
 local $_;
 my %tr=(
  '�'=>'a', '�'=>'b', '�'=>'v', '�'=>'g', '�'=>'d', '�'=>'e', '�'=>'yo', '�'=>'zh', '�'=>'z', '�'=>'i',
  '�'=>'y', '�'=>'k', '�'=>'l', '�'=>'m', '�'=>'n', '�'=>'o', '�'=>'p', '�'=>'r', '�'=>'s', '�'=>'t',
  '�'=>'u', '�'=>'f', '�'=>'h', '�'=>'c', '�'=>'ch', '�'=>'sh', '�'=>'sh', '�'=>'j', '�'=>'i', '�'=>'j',
  '�'=>'e', '�'=>'yu', '�'=>'ya',
 );
 my $s='';
 $s.=$tr{$_}||$_ foreach (split //, &lc_rus(shift));
 return $s;
}

sub trim
{
 local $_=shift;
 s|^\s+||;
 s|\s+$||;
 return($_);
}

# --- ����� ��������� � ����� ---
# ����: 
#  0 - ���������
#  1 - [��������]
#  2 - [��������� ��� ���������]
#  3 - [����� ����� ��������� � �����]
#  4 - [����� ����� ���������], ���� �� �����, �� 'message'
#  5 - [���������� ��������� ����� ����� ���������], ���� �� �������,
#      �� ����������� = ���������� ��������� ����� � ������ ����� 5
sub Message
{
 my ($soob,$pic,$header,$end,$cls,$n)=@_;
 $n=($soob=~s/<br>/<br>/g)-5 unless defined $n;
 $OUT.="<div class=".($cls||'message')."><table class=table10><tr><$tc valign=top>";
 $OUT.="<br>" x $n if $n>0;
 $OUT.="<img src='$pic'><br>" if $pic;
 $OUT.="<span class=error>".($header||'&nbsp;')."</span></td><td width=6>&nbsp;</td><td valign=middle align=left>$soob</td></tr></table></div>$end";
}

# --- ����� ���������, ���������� �������� � ����� ---
# ����: ��� ��������� ���������� ������������ Message
sub Message_Exit
{
 &Message(@_);
 &Exit;
}

# --- ����� ���� � ������� ---
# ����: 
#  0 - �����
#  1 - [����� ����� ��������� � ����]
sub ErrorMess
{
 &Message($_[0],$err_pic,'��������',$_[1]);
}

# --- ����� ���� � ������� � ����� ---
# ����: 
#  0 - �����
#  1 - [����� ����� ��������� � ����]
sub Error
{
 &Message(&div('big',$_[0]),$err_pic,'��������',$_[1]||'','infomess');
 &Exit;
}

# --- ����� ���� OK ---
# ����: 
#  0 - �����
#  1 - [����� ����� ��������� � ����]
#  2 - [��������], ���� �� �������, �� ��������� ok.gif. ���� ������� 'nopic' - �� ��������� ������
sub OkMess
{
 &Message($_[0],!$_[2]? "$img_dir/ok.gif" : $_[2] ne 'nopic' && "$img_dir/$_[2]",'',$_[1]).'<br>';
}

sub MessX
{
 my $br=!!$_[1] && '<br>';
 my $spc="<img src='$spc_pic' width=1 height=1>";
 return(qq{<table class=table0 style="background:url('$img_dir/box_tl.gif')">}.
   qq{<tr style="height:6px"><td colspan=2>$spc</td><td style="background:url('$img_dir/box_tr.gif') top right no-repeat; width:5px;">$spc</td></tr>}.
   qq{<tr><td style="width:5px">$spc</td><td>$br$_[0]$br$br</td><td style="background:url('$img_dir/box_r.gif') top right">$spc</td></tr>}.
   qq{<tr style="height:6px"><td colspan=2 style="background:url('$img_dir/box_bl.gif') bottom left no-repeat; width:5px;">$spc</td><td style="background:url('$img_dir/box_br.gif') top right no-repeat; width:5px;">$spc</td></tr>}.
   qq{</table>}.(!!$_[2]&&'<br>'))
}

sub Mess0
{
 my $tbl_width=270;
 my $img="img src='$img_dir/";
 my $spc="<${img}spacer.gif' width=1 height=2>";
 my $width=$tbl_width-$_[2]-$_[3]-6;
 return("<table class=table0>".
   "<tr><td><$img$_[8]' width=$tbl_width height=$_[4]></td></tr>".
   "<tr><td background='$img_dir/$_[6]' class='$_[0]'><table>".
     "<tr><td>$spc</td><td colspan=3 class=$_[0]>$spc</td><td>$spc</td></tr>".
     "<tr><td width=$_[2]>&nbsp;</td><td class=$_[0] width=2>&nbsp;</td><td width=$width class=$_[0] style='word-wrap:break-word;'>$_[1]</td><td class=$_[0] width=2>&nbsp;</td><td width=$_[3]>&nbsp;</td></tr>".
     "<tr><td>$spc</td><td colspan=3 class=$_[0]>$spc</td><td>$spc</td></tr>".
    "</table></td></tr>".
   "<tr><td><$img$_[9]' width=$tbl_width height=$_[5]></td></tr>".
   "<tr><td>$spc</td></tr>".
 "</table>");
}

sub Mess2
{
 return(&Mess0(@_,19,14,20,20,'cntr_m2.gif','rght_m2.jpg','top_m2.jpg','btm_m2.jpg'));
}

sub Mess3
{
 return(&Mess0(@_,19,19,20,20,'cntr_m1.gif','rght_m1.gif','top_m1.gif','btm_m1.gif'));
}

sub T_Head
{
 return("<table cellpadding=0 cellspacing=0><tr><td><img src='$spc_pic'</td></tr>");
}

sub error	{ &MessX("<span class=error>$_[0]</span> $_[1]",'',$_[2]) }
sub bold	{ "<b>$_[0]</b>" }
sub bold_br	{ "<br><b>$_[0]</b><br><br>" }
sub commas	{ "&#171;$_[0]&#187;" }
sub tag		{ "<$_[0]".(!!$_[2] && " $_[2]").">$_[1]</$_[0]>" }

sub Start_Row
{
 $r1='row2';
 $r2='row1';
}

sub PRow
{
 ($r1,$r2)=($r2,$r1);
 return "<tr class=$r1>";
}

sub RRow
{
 local $_=shift;
 my %f=(
   'c' => "<$tc>",
   'l' => "<td>",
   'r' => "<$td>",
   'C' => "<$tc colspan=2>",
   'L' => "<td colspan=2>",
   'R' => "<$td colspan=2>",
   '2' => "<$tc colspan=2>",
   '3' => "<$tc colspan=3>",
   '4' => "<$tc colspan=4>",
   '5' => "<$tc colspan=5>",
   '6' => "<$tc colspan=6>",
   '7' => "<$tc colspan=7>",
   '8' => "<$tc colspan=8>",
   '9' => "<$tc colspan=9>",
   '0' => "<$tc colspan=10>",
   't' => "<$tc valign=top>",
   'T' => "<$tc colspan=2 valign=top>",
   '^' => "<td valign=top>",
   'E' => "<td colspan=3>",
   ' ' => "<td>&nbsp;"
 );
 my $out=s|^\*||? ($_? &PRow && "<tr class='$r1 $_'>" : &PRow) :
    /^</? $_ :
    $_ eq 'tablebg'? &Start_Row && "<tr class=$_>" :
    $_? "<tr class='$_'>" : '<tr>';
 $out.=($f{$_}||'<td>').(shift(@_)||'&nbsp').'</td>' foreach (split //,shift);
 return ($out.'</tr>');
}

sub Table { return("<table class='$_[0]'>$_[1]</table>") }
sub table { return('<table class=table0><tr>'.(join '',map "<td>$_</td>",@_).'</tr></table>') }

sub Center
{
 return ("<div class=align_center><div class=align_center_to_left><div class=align_center_to_right>$_[0]</div></div></div>");
 #return ("<table class='table1 width100'><tr><td>&nbsp;</td><td width=1% nowrap>$_[0]</td><td>&nbsp;</td></tr></table>");
}

sub Center_Mess
{
 my $h=$_[1]? '<br>':'';
 return ("<div class='message cntr'>".$h.($_[2]? "<span class=$_[2]>$_[0]</span>" : $_[0]).$h.$h.'</div>');
}

sub ahref	{ return "<a href='$_[0]'".($_[2]? " $_[2]":'').">$_[1]</a>" }
sub CenterA	{ return &Center(&div('nav',&ahref(@_))) }

sub Printf
{
 local $_;
 my ($a,$f);
 my @f;
 my @b=split /\[/,shift @_;
 my $out=shift @b;
 while ($a=shift @b)
 {
    $f='';
    next if $a!~s|^(.*)]||;
    if ($1 eq 'br') {$f.='<br>'; next}
    if ($1 eq 'br2') {$f.='<br><br>'; next}
    if ($1 eq 'br3') {$f.='<br><br><br>'; next}
    @f=split /\|/,$1;
    $f=shift @_;
    foreach (@f)
    {
       if ($_ eq 'bold') {$f="<b>$f</b>"; next}
       if ($_ eq 'commas') {$f="&#171;$f&#187;"; next}
       if ($_ eq 'trim') {$f=&trim($f); next}
       if (/div (.+)/) {$f="<div class='$1'>$f</div>"; next}
       if (/span (.+)/) {$f="<span class='$1'>$f</span>"; next}
       if ($_ eq 'filtr') {$f=&Filtr_out($f); next}
       if ($_ eq 'filtrfull') {$f=&Filtr($f); next}
    }
 }
  continue
 {
    $out.=$f.$a;
 }
 return $out;
}

# ������������ �������� <input> ���� hidden
# ����: ��� ��������, ��������.   �������� ����������� �� &Filtr_out
sub input_h
{
 my ($name,$value)=('','');
 if( $#_<2 )
 {
    ($name,$value)=@_;
    return("<input type=hidden name=$name value='".&Filtr_out($value)."'>");
 }
 my %h=@_;
 foreach $name (keys %h)
 {
    $value.="<input type=hidden name=$name value='".&Filtr_out($h{$name})."'>";
 }
 return $value;  
}

# ������������ �������� <input> ���� text
# ����: ��� ��������, ��������, ������, ������������ �����, ���.������
sub input_t
{
 my ($name,$value,$size,$maxlength,$dop)=@_;
 return "<input type=text name=$name size=$size maxlength=$maxlength value='".&Filtr_out($value).
   "' autocomplete='off'".($dop && " $dop").'>';
}

# ���, ��������, �������, �����
sub input_ta
{
 my ($name,$value,$cols,$rows,$dop)=@_;
 $dop=$dop && " $dop";
 return "<textarea name=$name cols=$cols rows=$rows$dop>".&Filtr_out($value).'</textarea>';
}

sub FormSubmitEvent
{
 return qq{onsubmit="javascript:document.getElementById('savediv}.(++$SaveDiv).
        qq{').innerHTML='<div class=message>������ �������. �����...</div>';"};
} 

sub form_a
{
 my ($form,$name,$get_or_post)=('','','post');
 my %h=@_;
 my %f=%FormHash;
 foreach $name (keys %h)
 {
    if ($name eq '!') {$form.=' '.&FormSubmitEvent; next}
    if ($name eq '#') {$get_or_post='get'; next}
    $f{$name}=$h{$name};
 }
 $form="<form method=$get_or_post action='$script'$form>".&input_h(%f);
 return $form;
}

sub form
{
 my $h=pop @_;
 return &form_a(@_).$h.'</form>';
}

sub submit_a
{
 return "<div id=savediv".($SaveDiv+1)." class=cntr><input type=submit value='$_[0]' class=button></div>";
}

sub submit
{
 return "<input type=submit value='$_[0]' class=button>";
}

# ����������� ���� (��� => ��������) � "&���=��������&���=��������". �������� ����������� &Filtr_out
# ����: ������ �� ���
sub Post_To_Get
{
 my ($a,$b,$c)=($_[0],'','');
 $b.='&'.&Filtr_out($c) while ($c=join '=',each(%$a));
 return $b;
}

sub Del_Sort_Prefix
{
  local $_ = shift;
  s|^\[\d+\]||;
  $_;
}

sub SetCharSet
{# --- ��������� ��������� �� � cp1251 ---
 #my $dbh=$_[0];
 #$dbh->do("SET character_set_client=cp1251");
 #$dbh->do("SET character_set_connection=cp1251");
 #$dbh->do("SET character_set_results=cp1251");
}

# ������� ����� ������ �� ������� ��
#  0 - ������ dbh
#  1 - sql-������
#  2 - [�����������]
#  3 - [������� ������]
# ������������ ������ ��������� 0 � 1. ����������� ����� ������� �������� ��������������
# � ����������� ������� ��� ������������ ��� ������������� sql-�������. ���� � ��������������
# ��� ���� �� �������� sql-�������� ���� �� �������� �� �����, �� ����������� ������������.
# ���� ����������� ���������, �� ����� sql-��������. ���� �������� 3 ����������, �� ������
# ��������� sql-������� ��������� ���� (3�) ��������. ������������� ��� ������� ��������, 
# � ������� ��������� ������. ���� ����������� ����� 0 (������ '����'), �� ��� ������ �� �������
# ����� �������� ������ ������� � ���� ������.
# 
# �������:
#  0 - ������ fetchrow_hashref ���� false, ���� ������ ���� ������ �������
#
# ������:
#  $p=&sql_select_line($dbh,"SELECT unix_timestamp()",'������� ����� �� ������� ��');
#  &Error("�� ������� �������� ����� �� ��!") unless $p;
#  $t=$p->{'unix_timestamp()'};
sub sql_select_line
{
 my ($d,$sql,$comment,$hidden)=@_;
 my $t_sql=[gettimeofday];
 $d=$d->prepare($sql);
 $sql=$hidden || &Filtr_out($sql);
 $hidden=$hidden? ' ' : '<br>';
 $sql="<span class=data2>$comment</span><br>$sql" if $comment;
 unless( $d->execute )
 {
    $DOC->{admin_area}.=&MessX("$sql<br><b>������ �� ��������!</b>",0,0) if $Ashowsql;
    return 0;
 }
 $t_sql=tv_interval($t_sql);
 $d=$d->fetchrow_hashref;
 if( $Ashowsql )
 {
    $DOC->{admin_area}.=$comment eq '0'? "<small>$sql <span class=disabled>(".($d? 1:0)." �����, $t_sql ���)</span></small><br>" :
       &MessX("$sql$hidden<span class=disabled>�����:</span> ".($d? 1:0)."<span class=disabled>. ����� ���������� sql:</span> $t_sql ���.",0,0);
 }
 $T_sql+=$t_sql;
 return $d;
}

sub sql
{
 my ($d,$sql,$comment,$hidden)=@_;
 my ($t_sql,$rows);
 $t_sql=[gettimeofday];
 $d=$d->prepare($sql);
 $d->execute;
 $rows=$d->rows;
 $t_sql=tv_interval($t_sql);
 if( $Ashowsql )
 {
    $sql=$hidden || &Filtr_out($sql);
    $hidden=$hidden? ' ' : '<br>';
    $sql="<span class=data2>$comment</span><br>$sql" if $comment;
    $DOC->{admin_area}.=$comment eq '0'? "<small>$sql <span class=disabled>($rows �����, $t_sql ���)</span></small><br>" :
       &MessX("$sql$hidden<span class=disabled>�����:</span> $rows. <span class=disabled>����� ���������� sql:</span> $t_sql ���",0,0);
 }
 $T_sql+=$t_sql;
 return $d;
}

sub sql_do
{
 my ($d,$sql,$comment,$hidden)=@_;
 my $t_sql=[gettimeofday];
 $d=$d->do($sql)+0;
 $t_sql=tv_interval($t_sql);
 if( $Ashowsql )
 {
    $comment="<span class=data2>$comment</span><br>" if $comment;
    $DOC->{admin_area}.=$comment eq '0'? '<small>'.($hidden||&Filtr_out($sql))." <span class=disabled>($d �����, $t_sql ���)</span></small><br>" :
        &MessX($comment.($hidden||&Filtr_out($sql).'<br>')."<span class=disabled>��������� �����:</span> $d. <span class=disabled>����� ���������� sql:</span> $t_sql ���",0,0);
 }
 $T_sql+=$t_sql;
 return $d;
}

# ����� � ���� dd.mm.gg hh:mm
sub the_time
{
 my $t=localtime(shift);
 return sprintf("%02d.%02d.%02d %02d:%02d",$t->mday,$t->mon+1,$t->year-100,$t->hour,$t->min);
}

# ����� � ���� hh:mm
sub the_hour
{
 my $t=localtime(shift);
 return sprintf("%02d:%02d",$t->hour,$t->min);
}

# ����� � ���� dd.mm.gg hh:mm ��� hh:mm ���� ���� ����� ��������
# ����:
#  0 - �����
#  1 - ������� �����
#  2 - ���� ���������� (XXX) � ���� = ��������, �� �������:
#      XXX=1 :  ������� � hh:mm		
#      XXX!=1:  <span class='XXX'>hh:mm</span>
sub the_short_time
{
 my ($t1,$t2,$span_class)=@_;
 my $t=localtime($t1);
 $t2=localtime($t2);
 return(&the_time($t1)) unless $t->mday==$t2->mday && $t->mon==$t2->mon && $t->year==$t2->year;
 $t1=&the_hour($t1);
 $span_class or return($t1);
 $span_class eq '1' && return("������� � $t1");
 return("<span class='$span_class'>$t1</span>");
}

# ����� � ���� dd.mm.gggg
sub the_date
{
 my $t=localtime(shift);
 return sprintf("%02d.%02d.%02d",$t->mday,$t->mon+1,$t->year-100);
}

# ��������� ������ � ���� � ������
sub the_hh_mm
{
 return(($_[0]>=60? int($_[0]/60).' ��� ':'').sprintf("%02d",$_[0] % 60).' ���');
}

# ������ ��������� � ���
# ����: ���������
sub ToLog
{
 return unless open(LOG,">>$Log_file");
 flock(LOG,2);
 my $t=&the_time(time);
 $t.=" $_[0]\n";
 print LOG $t;
 flock(LOG,8);
 close(LOG);
}

# ������������ ����������� ������ � �������� � �������� �������� �������
# ����: � ������ (1-12)
# �������:
#  1 - ���������� ������
#  2 - �������� ������
sub Set_mon_in_list
{
 my $mon_list='<select name=mon size=1>'.
  '<option value=1>������<option value=2>�������<option value=3>����'.
  '<option value=4>������<option value=5>���<option value=6>����'.
  '<option value=7>����<option value=8>������<option value=9>��������'.
  '<option value=10>�������<option value=11>������<option value=12>�������'.
  '</select>';
 my $mon=int $_[0];
 $mon=1 if $mon<1 || $mon>12;
 $mon_list=~s/=$mon>(.+?)</=$mon selected>$1</;
 return ($mon_list,$1);
}

# ������������ ����������� ������ � ������ � selected �������� ����������� ���
# ����: ��� (������ �� ����!)
# �������: ���������� ������
sub Set_year_in_list
{
 my $hyear="<select size=1 name=year>";
 #$hyear.="<option value=$_>".($_+1900)."</option>" for (104..110);
 $hyear.="<option value=$_>".($_+1900)."</option>" for ($year_now-5..$year_now);
 $hyear.="</select>";
 my $year=int $_[0]; 
 $hyear=~s/=$year>/=$year selected>/;
 return $hyear;
}

# ���������� ������������ ����� ���� � ����������� ������
# ����: ����� (1..12), ��� (0..���)
sub GetMaxDayInMonth
{
 return(eval{timelocal(0,0,0,31,$_[0]-1,$_[1])}?31:30) if $_[0]!=2; # ��� �� �������
 return(eval{timelocal(0,0,0,29,$_[0]-1,$_[1])}?29:28);
}

# ������������ �������� � ������� �� �������� ���� ��������� sql-������� ��
# ��������� �� ��������
# ����:
#  0 - sql-������ ��� ������� LIMIT � ����������� ������������ � SELECT
#  1 - ����� ��������, ������� ������ ���� ��������
#  2 - ������������ ���������� ������� �� ��������
#  3 - ���, ������� ����� ������ � �������� (� ��� ����� ��������� ������ &start=xx)
#  4 - [$dbh], �� ��������� ����� ������� $dbh
#  5 - [�����] - ���� �������, �� �������� ����� ���������� ����� ������� �����
# �����:
#  0 - sql-������ � �������������� LIMIT
#  1 - html � ����������
#  2 - ����� ���������� ����� � ������ �������
#  3 - ��������� �� $sth c �������������� �����������, �.� ��� �������� ����� ������� $sth->fetchrow_hashref
sub Show_navigate_list
{
 my ($sql,$n_page,$max_in_list,$url,$d,$rows,$a)=@_;
 my ($n_rows,$td_cls,$len,$temp_sql,$temp_sth,$t0_sql);
 $d||=$dbh;
 $max_in_list=1 if $max_in_list<1;
 # ������� ����� ���-�� ����� �� �������
 $temp_sql="$sql LIMIT ".($n_page*$max_in_list).",$max_in_list";
 $temp_sql=~s/^\s*SELECT\s+/SELECT SQL_CALC_FOUND_ROWS /i unless $rows;
 $t0_sql=[gettimeofday];
 $temp_sth=$d->prepare($temp_sql);  
 unless( $temp_sth->execute )
 {
    $DOC->{admin_area}.=&MessX("$temp_sql<br><b>������ �� ��������</b>",0,0) if $Ashowsql;
    return($sql,'',0,$temp_sth);
 }
 $t0_sql=tv_interval($t0_sql);
 $T_sql+=$t0_sql;
 $rows=$d->selectrow_array("SELECT FOUND_ROWS()") unless $rows;
# $temp_sql=$sql;
 $temp_sql=~s/\n/<br><br>/g;
 $DOC->{admin_area}.=&MessX("$temp_sql<br><span class=disabled>�����:</span> $rows. <span class=disabled>����� ���������� sql:</span> $t0_sql ���",0,0) if $Ashowsql;
 $rows or return($sql,'',0,$temp_sth);
 $temp_sth->rows or return($sql,&ahref("$url&start=0",'���������� ��������� �� �������� 1'),$rows,$temp_sth);

 $n_rows=$rows;   
 my $out='';
 # ���� ���-�� ����� ������ ���-�� ������� ����� �������� �� ���, �� ���������� ���������
 if( $n_rows > $max_in_list )
 {
    $url.='&start';
    # ���� ������� ������� - �������� ������� ��������
    my $h=$n_rows/$max_in_list>8? '' : '&nbsp;&nbsp;&nbsp;';
    # ���� �������� ����� �����, �� ������� �� ���
    my $j=$n_rows/$max_in_list>20;
    $out.="<div align=left><table class=table0><tr>";
    $out.="<td class=".($n_page? 'nav':'head')."> <a href='$url=0'>${h}1$h</a></td>";
    $n_rows-=$max_in_list;
    my $i=1;
    # � ����������� �� ������ ��������� �������� ��������� ���������� �������� ������, ������� ����� ��������� � ����� nav
    my $steps=$n_page<89? 9: $n_page<995? 5 : 2;
    while( $n_rows>0 )
    {
       $len=abs($i-$n_page);
       $a="a href='$url=$i'";
       if( $len<30 )
       {
          $td_cls=$i==$n_page? ' class=rowoff2' : $len<$steps? ' class=nav':''; # ���� ������ � �������� $step ����� �� ��������, �� ������� ������ nav
          $i++;
          $out.="<td$td_cls><$a>$h".($td_cls || $i%10==1? $i : '.')."$h</a></td>";
          $n_rows-=$max_in_list;
       }
        elsif ($len<106)
       {
          $i++;
          $out.="<td><$a title=$i>".($i? ':' : $i).'</a></td>' unless $i % 10;
          $n_rows-=$max_in_list;
       } 
        elsif ($len<2000)
       {
          $i++;
          $out.="<td><$a title='$i'>X</a></td>";
          $n_rows-=$max_in_list*100;
          $i+=99;
       }
        else
       {
          $i++;
          $out.="<td><$a title='$i'>#</a></td>";
          $n_rows-=$max_in_list*1000;
          $i+=999; 
       }
    }
    $out.='</tr></table></div>';
 }
 return("$sql LIMIT ".($n_page*$max_in_list).",$max_in_list",$out,$rows,$temp_sth);
}


# ������������ ����������� ������ �������
# ����: � ������, ������� ���������� �������� � ������
# �����: ������ �������
sub Get_Office_List
{
 my $office=int $_[0];
 my $offices='<select name=office><option value=0>-</option>';
 foreach (sort keys %Offices) {$offices.="<option value=$_".($office==$_?' selected':'').">$Offices{$_}</option>"}
 return "$offices</select>";
}

# ������������ ������ �������
# �������:
#  0 - ������ �� ��� �� ������� ������� (����� &Filtr)
#  1 - ������ �� ��������������� ������ �� ������� id �������
sub Get_adms
{
 my($id,$nsql,$p,$A);
 my @Asort=();
 $A={};
 $nsql=nSql->new({
    dbh		=> $dbh,
    sql		=> "SELECT id,office,admin,name,privil,mess FROM admin ORDER BY office,admin",
    show	=> 'short',
    comment	=> '������ ���� ���������������'
 });
 while( %p=%{ $nsql->get_line } )
 {
    $id=$p{id};
    push @Asort,$id;
    $A->{$id}{office}=$p{office};
    $A->{$id}{privil}=','.$p{privil}.',';
    $A->{$id}{login}=&Filtr($p{admin});
    $A->{$id}{name}=&Filtr($p{name});
    $A->{$id}{mess}=&Filtr_out($p{mess});
    $A->{$id}{admin}=$A->{$id}{login}.(!!$A->{$id}{name} && " ($A->{$id}{name})");
 }
 return ($A,\@Asort);
}

# ����:
#  0 - ���� ����������, �� ����������� ������ ������ ����� ������� (�������� ������)
sub Get_users
{
 my ($id,$nsql,$p,$where_id,$U);
 $where_id=int $_[0];
 $where_id=$where_id? "WHERE id=$where_id OR mid=$where_id" : '';
 $U={};
 $nsql=nSql->new({
    dbh		=> $dbh,
    sql		=> "SELECT * FROM users $where_id",
    show	=> 'short',
    comment	=> 'calls.pl:',
 });
 while( %p=%{ $nsql->get_line } )
 {
    $id=$p{id};
    $U->{$id}{name}=&Filtr($p{name});
    $U->{$id}{fio}=$p{fio};
    $U->{$id}{fio_o}=&Filtr_out($p{fio});
    $U->{$id}{fio_m}=&Filtr_mysql($p{fio});
    $U->{$id}{grp}=$p{grp};
    $U->{$id}{mid}=$p{mid};
    $where_id or next;
    $U->{$id}{ip}=$p{ip};
    $U->{$id}{paket}=$p{paket};
    $U->{$id}{cstate}=$p{cstate};
    $U->{$id}{comment}=$p{comment};
    $U->{$id}{contract}=$p{contract};
 }
 return $U;
}

# ����:
#  0 - ���� ����������, �� ����������� ������ ������ ����� ���������
# �������:
#  0 - ������ �� ��� �� ������� ���������� (&Filtr ��������)
sub Get_workers
{
 my($id,$nsql,$p,$where_id,$W);
 $where_id=int $_[0];
 $where_id=$where_id? "WHERE worker=$where_id" : '';
 $W={};
 $nsql=nSql->new({
    dbh		=> $dbh,
    sql		=> "SELECT * FROM j_workers $where_id",
    show	=> 'short',
    comment	=> 'calls.pl:',
 });
 while( %p=%{ $nsql->get_line } )
 {
    $id=$p{worker};
    $W->{$id}{office}=$p{office};
    $W->{$id}{state}=$p{state};
    $W->{$id}{post}=$p{post};
    $W->{$id}{name}=&Filtr($p{name_worker});
    $W->{$id}{url}=&ahref("$scrpt0&a=oper&act=workers&op=edit&id=$id",$W->{$id}{name})
 }
 return $W;
}

# ���������� ����� ����������� � ���� ������� ������������� �����
sub ShowModeAuth
{
 my ($mod)=@_;
 local $_="<img src='$img_dir";
 return ("$_/spacer.gif' width=16>") if $mod eq 'no';
 return ("$_/on.gif' title='�����������. ������ ��������'>") if $mod eq 'on';
 return ("$_/off.gif' title='����������� � ������ \"����\"'>") if $mod eq 'off';
 return ("$_/on2.gif' title='�����������. �������� ������ $c2 ������'>") if $mod eq 'ong';
 return ("$_/block.gif' title='�����������. ������ ������������: �������� ����� �������''>") if $mod eq '1';
 return ("$_/block.gif' title='�����������. ������ ������������: �������� ����� �������� �������������'>") if $mod eq '2';
 return ("$_/block.gif' title='�����������. ������ ������������: � ������ ����� ����� �� ������� ������'>") if $mod eq '4';
 return ("$_/block.gif' title='�����������. ������ ������������.'>") if $mod eq '5';
 return ("$_/spacer.gif'>");
}

# ������������ url-� �� ������ �������
# ����:
#  1 - id
#  2 - ������������ � ������ ������, �������� �����
#  3 - [��� ����� �������� � ������ ���� ��� ���� �� �������� ���], ���� �������� �� �����, �� ��������� ������: id=�����
sub ShowClient
{
 return ("<a href='$scrpt0&a=user&id=$_[0]'>".($PR{50}? &Filtr_out($_[1]) : $_[2] || "id: $_[0]").'</a>');
}

# ����:
#  1 - id �������
# �������:
#  0 - html-������� � ������� �������
#  1 - ������ �������
#  2 - id �������� ������
#  3 - ip
sub ShowUserInfo
{
 my ($id,$h,$name,$out,$p,$sth,$value);
 my %f;
 &LoadDopdataMod();
 ($id)=@_;
 $out='';
 $p=&sql_select_line($dbh,"SELECT * FROM fullusers WHERE id=$id LIMIT 1");
 $p or return(&bold("������ ������� id=$id  �� ��������"),0,0,'');
 foreach $id ('fio','name','ip','contract','state','grp','mid','id') {$f{$id}=&Filtr_out($p->{$id})}
 $f{name}=~s/([^\s]{17})/$1&shy;/g;
 $f{fio}=~s/([^\s]{17})/$1&shy;/g;
 
 $out.=&RRow('*','l l','&nbsp;���','',$PR{50}? $f{fio} : '<span class=disabled>������</span>').
       &RRow('*','l l','&nbsp;�����','',$PR{50}? $f{name} : '<span class=disabled>�����</span>').
       &RRow('*','l l','&nbsp;ip','',$f{ip});
 
 $sth=&sql($dbh,"SELECT * FROM dopdata WHERE parent_id=$id AND template_num=(SELECT template_num FROM dopfields WHERE parent_type=0 AND field_alias LIKE '_adr%' LIMIT 1) ORDER BY field_name");
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
   $out.=&RRow('*','l l','&nbsp;'.&Filtr_out($name),'',$value);
 }

 $out="<table class=table1 width='100%'>".$out.
   &RRow('*','l l','&nbsp;��������','',$f{contract}).
   &RRow('*','l l','&nbsp;������','',($f{state} eq 'off'? '<span class=disabled>��������</span>':'��������')).
 '</table>'.&div('cntr',&ahref("$scrpt0&a=user&id=$f{id}",'�������� ������'));
 return (&div('bordergrey',$out),$f{grp},$f{mid}||$f{id},$f{ip});
}

sub GetClientTraf
{
 my($sth,$p);
 $sth=$dbh->prepare("SELECT * FROM users_trf WHERE uid=$_[0] LIMIT 1");
 $sth->execute;
 return(0,0,0,0,0,0,0,0) unless $p=$sth->fetchrow_hashref;
 return($p->{in1},$p->{out1},$p->{in2},$p->{out2},$p->{in3},$p->{out3},$p->{in4},$p->{out4});
}

# ��������� ����� ��������� �� ��� ������
# ����:
#  1 - ����� ���������
#  2 - ���� ��� ����� icmp
# �����:
#  1 - ������ � ��������� ���������, �������������� � ������ ����
#  2 - ������ ������ ���� ' class=xxxx' - css ��� ������������� ������
sub GetProto
{
 my($proto,$port)=@_;
 my $class_row='';
 if( $proto==1 )
 {  # icmp
    $port=('pong','��� 1','��� 2','<span class=error>dst unreach</span>','source quench','<b>redirect</b>',
      '��� 6','��� 7','ping','router advertisement','router solicitation','<b>time exceeded</b>','parameter problem',
      'timestamp request','timestamp reply','information request','information reply','address mask request','address mask reply')[$port] || "��� $port";
    $class_row=' class=rowsv';
 }else
 {
    $port||='';
 } 
 $proto=!$proto?'':$proto==1?'ICMP':$proto==6?'TCP':$proto==17?'<span class=data1>UDP</span>':"<b>$proto</b>";
 return ("$proto $port",$class_row);
}

# �������� ��������� ip � ���� �� �������� ��������
# ����: 
#  1 - ip,
#  2 - ������ �������� � ���� xx.xx.xx.xx/yy, ���� ������� ����, �� ��� ����� ���������� ��� ������ �� ������ ��������
# �������: 1 - �����, 0 - ���
sub Check_Ip_in_Nets
{
 my($ip,@nets)=@_;
 my($ok,$net,$ip_raw,$net_mask,$net_raw,$net_mask_raw);
 return(0) if $ip!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
 $ip_raw=pack('CCCC',$1,$2,$3,$4);
 $ok=1;
 foreach $net (@nets)
 {
    $net=~s|\s+||g;
    next if $net!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ || $5>32 || $1>255 || $2>255 || $3>255 || $4>255;
    $ok=0;
    $net_mask=$5;
    $net_raw=pack('CCCC',$1,$2,$3,$4);
    $net_mask_raw=pack('B32',1 x $net_mask,0 x (32-$net_mask));
    $net_raw&=$net_mask_raw;
    return(1) if ($ip_raw & $net_mask_raw) eq $net_raw;
 }
 return $ok;
}   

# ������������ ������ ���� �� ������� ���� ���������� �������
# ����:
#  1 - $dbh
#  2 - ��� �������: 'x','y' ��� 'z'
#  3 - url ��� �����
#  4 - [����� time ���, �� ������� �������� ����������, ����� �������]
sub Get_list_of_stat_days
{
 my($dbs,$lname,$url,$bold_time)=@_;
 my($sth,$p,$h,$list_of_days,$t1,$t2,$day,$mon,$year);
 my %days;
 $sth=$dbs->prepare("SHOW TABLES");
 return '' unless $sth->execute;
 $h=localtime($bold_time);
 $bold_time=($h->mday).'.'.($h->mon).'.'.($h->year); # ��� ������ ��� ��������� � ����, ������� ���������� ��������
 $DOC->{admin_area}.=&MessX("SHOW TABLES <span class=disabled>(������: ".$sth->rows.")</span>",0,0) if $Ashowsql;
 while( $p=$sth->fetchrow_arrayref )
 {
    $p->[0]=~/^$lname(\d\d\d\d)x(\d+)x(\d+)$/ or next;
    $h=timelocal(59,59,23,$3,$2-1,$1-1900); # ����� ���
    $days{$h}=substr('0'.$3,-2,2).'.'.substr('0'.$2,-2,2).'.'.$1;
 }
 $list_of_days='';
 $t1=$t2=0;
 foreach $h (sort {$b <=> $a} keys %days) 
 {
    $p=localtime($h);
    $mon=$p->mon;
    $year=$p->year;
    if( $t1!=$mon || $t2!=$year )
    {
       $t1=$mon;
       $t2=$year;
       $list_of_days.='<br><b>'.('������','�������','����','������','���','����','����','������','��������','�������','������','�������')[$t1].' '.($t2+1900).'</b>:<br>&nbsp;';
    }
    $day=$p->mday;
    $p=$bold_time ne "$day.$mon.$year"? $day : "<span class=big>$day</span>";
    $list_of_days.="<a href='$url$h'>$p</a>".($day==11||$day==21? '<br>&nbsp;' : ' ');
 }
 $list_of_days or return '';
 return &Mess3('row2',"<b>���������� �� ���</b>:<br><div class=lft>$list_of_days</div>");
}

sub Get_list_of_login_days
{
 my($url,$bold_time)=@_;
 my($sth,$p,$h,$list_of_days,$t1,$t2,$tmin,$tmax,$day,$mon,$year);
 $sth=$dbh->prepare("SELECT MIN(time),MAX(time) FROM login");
 $sth->execute;
 $p=$sth->fetchrow_hashref;
 $tmin=$p->{'MIN(time)'}-23*3600+1;
 $tmax=$p->{'MAX(time)'};
 $p=localtime($bold_time);
 $bold_time=($p->mday).'.'.($p->mon).'.'.($p->year); # ��� ������ ��� ��������� � ����, ������� ���������� ��������
 $list_of_days='';
 $t1=$t2=0;
 while( $tmax>$tmin )
 {
    $p=localtime($tmax);
    ($mon,$year,$day)=($p->mon,$p->year,$p->mday);
    if( $t1!=$mon || $t2!=$year )
    {
       $t1=$mon;
       $t2=$year;
       $list_of_days.='<br><b>'.('������','�������','����','������','���','����','����','������','��������','�������','������','�������')[$t1].' '.($t2+1900).'</b>:<br>&nbsp;';
    }
    $p=$bold_time ne "$day.$mon.$year"? $day : "<span class=big>$day</span>";
    $list_of_days.=&ahref("$url$tmax","$p ");
    $list_of_days.='<br>&nbsp;' if $day==11 || $day==21;
    $tmax-=24*3600; # - �����
 }
 $list_of_days or return '';

 $list_of_days=&Mess3('row2',"<b>���������� �� ���</b>:<br><div class=lft>$list_of_days</div>");
 return($list_of_days);
}

# ������������ ������ �����, ������� ����������� �����, � ������������ �������� ��������� ������ �������
# ����, ��������, $F{g5} �����������, �� ����� � id=g5 �������� ��������
# �������:
#  0 - html-������
#  1 - ������ ��������� �����, ����������� ��������

sub List_select_grp
{
 my($c,$id,$g,$grp_sel,$h,$out,$p,$pack_name,$pack_grps,$sth);
 $grp_sel='';	# ������, ������� ������ �����
 $out='';
 $sth=&sql($dbh,'SELECT * FROM user_grppack','������ ����������� �����');
 while( $p=$sth->fetchrow_hashref )
 {
    ($id,$pack_name,$pack_grps)=map{ &Filtr_out($p->{$_}) } ('id','pack_name','pack_grps');
    $h='';
    foreach (split /,/,$pack_grps)
    {
       next unless /^\d+$/;
       next if $UGrp_allow{$_}<2; # ������ � ���� ������ ������������ ��� ���������
       $h.=qq{ document.getElementById('g$_').checked=true;};
    }
    next if $h eq ''; # ��� �� ����� ��������� ������ � ������ ��������
    $out.=qq{<a href='#' onclick="SetAllCheckbox('grp',0);$h return false;">$pack_name</a><br>};
 }
 $out.='<br>' if $out;
 foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
 {
    next if $UGrp_allow{$g}<2;
    $h="g$g";
    if( $F{$h} )
    {
       $c=' checked';
       $grp_sel.="$g,";
    }else
    {
       $c='';
    }
    $out.="<input type=checkbox value=1 id=$h name=$h$c> $UGrp_name{$g}<br>";
 }
 chop $grp_sel;	# ������ ��������� �������

 $out=qq{<a href='#' onclick="SetAllCheckbox('grp',1); return false;">�������� ���</a><br>}.
      qq{<a href='#' onclick="SetAllCheckbox('grp',0); return false;">������ �����</a><br>}.
      "<br><div id=grp>$out</div>";
 return($out,$grp_sel);
}

# ���������� ������ � ��������� �������� ���������
# ����:
#  0  - ������
#  1  - ������� ���������
# [2] - ������ �������
# ��.���:
# 7 �����/���
# 6 ����/���
# 5 �����/���
# 4 ����
# 3 ����� �����
# 2 �����
# 1 ����� �����
# 0 �����
sub Print_traf
{
 my($traf,$ed,$time)=@_;
 $ed==7 && return($time<=0? '?' : $traf? sprintf("%.3f",$traf/$time/$mb) : 0);
 $ed==6 && return($time<=0? '?' : $traf? sprintf("%.3f",$traf/$time/125) : 0);
 $ed==5 && return($time<=0? '?' : $traf? sprintf("%.3f",$traf/$time/$kb) : 0);
 $ed==4 && return &split_n($traf);
 $ed==3 && return &split_n(int $traf/$kb);
 $ed==2 && return sprintf("%.3f",$traf/$kb);
 $ed==1 && return($traf && $traf<$mb? '&lt;1' : &split_n(int $traf/$mb));
 return sprintf("%.3f",$traf/$mb);
}

# =============================================
# �������� ��������� �� ���� ������(��)
# ����: ���������, [email], [email �� ����]
sub Smtp
{
 my $CRLF="\015\012";
 my $to_emails=$_[1] || $email_admin;
 $to_emails=~s| ||g;
 $email_admin or return(0);
 my $emails=0;
 my $message='Subject:NoDeny Billing System'.$CRLF.$CRLF.$_[0];
 my ($first_email)=split /,/,$email_admin;
 my $from_email=$_[2] || $first_email;
 $smtp_server||='127.0.0.1';
 $SMTP=new IO::Socket::INET (PeerAddr=>$smtp_server,PeerPort=>'25',Proto=>'tcp') or return(0);
 sysread($SMTP,$_,1024);
 return(0) if &Send_smtp('MAIL FROM:'.$from_email.$CRLF);
 map{ $emails+=!&Send_smtp('RCPT TO:'.$_.$CRLF) } split /,/,$email_admin;
 return(0) if !$emails ||
   &Send_smtp('DATA'.$CRLF) ||
   &Send_smtp($message.$CRLF.'.'.$CRLF) ||
   &Send_smtp('QUIT'.$CRLF);
 close($SMTP);
 return(1);
}
sub Send_smtp {print $SMTP $_[0]; sysread($SMTP,$_,1024); return(/^5/)}

sub DB2_Connect
{
 $dbs=DBI->connect($DSS,$user,$pw,{PrintError=>1});
 $dbs or &Error("������ ���������� � mysql �� ������� $db_server2!");
}

sub LoadMod
{
 my($modfile,$modname)=@_;
 $VER=0; 
 eval{require $modfile};
 $@ && &Error("�� ������� ��������� $modname.".$br.($pr_SuperAdmin? '����: '.&Filtr_out($modfile) : '���������� � �������� ��������������.'));
 ($VER==$VER_chk) or &VerWrong($modname);
}

sub LoadMoneyMod
{
 &LoadMod("$Nodeny_dir/nomoney.pl",'������ �������� ��������');
 &TarifReload;
}

sub LoadPaysTypeMod
{
 &LoadMod("$Nodeny_dir_web/paystype.pl",'������ ����� ��������');
}

sub LoadJobMod
{
 &LoadMod("$Nodeny_dir_web/nJob.pl",'������ �����');
}

sub LoadNetMod
{
 &LoadMod("$Nodeny_dir_web/nNet.pl",'������ nNnet');
}

sub LoadEquipMod
{
 &LoadMod("$Nodeny_dir_web/nEquip.pl",'������ nEquip');
}

sub LoadDopdataMod
{
 $nDopdata_loaded or &LoadMod("$Nodeny_dir_web/nDopdataAPI.pl",'������ nDopdataAPI');
}

# === START ===

$ip=$ENV{REMOTE_ADDR};
$ip=~s|[^\d\.]||g;

$Title_net=&Filtr($Title_net);
$img_dir=~s|/$||; # ������ �� ��������� �.�. ������ ������ ����������, ��� ���� ������� ��������
$err_pic="$img_dir/err.gif";
$more_pic="$img_dir/more_d.gif";
$spc_pic="$img_dir/spacer.gif";
$img_more="<img src='$more_pic' style='vertical-align:middle;'>";
$spc="<img src='$spc_pic' width=1 height=2>";
&Start_Row;
$td='td align=right';
$tc='td align=center';
$tcc='td align=center colspan=2';
$br='<br />';
$br2='<br /><br />';
$br3='<br /><br /><br />';
$go_back=$br2.&ahref('javascript: if (history.length==0) self.close(); else history.back();','&larr; ��������� �� ���������� ��������');
$ut='unix_timestamp()';

$unlim_mb=999000000; # ���������� ��, ������� � ������� �������, ��� ��� �����
$kb||=1000;
$mb=$kb*$kb;
$db_conn_timeout||=4;
$db_conn_timeout2||=4;
$db_server||='localhost';
$db_server2||='localhost';
$T_sql=0;

$Max_list_users=50 if $Max_list_users<1;
$Max_list_pays=40 if $Max_list_pays<1;
$UsrList_cols_template_max||=3;

# ������ �� ������, ��� ��������
%cstates=(
  0  => '��� OK',
  1  => '��������� ������',
  2  => '������ �� ������',
  3  => '� �������',
  4  => '������',
  5  => '���������',
  6  => '�������� ���������',
  7  => '����� �����������',
  8  => '��������� ���������',
  9  => '�� �����������',
  10 => '�� �����, ���������',
  11 => '��������� ����������',
  12 => '������',
  13 => '����������',
  14 => '����� �� �����������',
);

@joblevel=(
  '�������',
  '� ����� �������, ���� ���������',
  '������������������� �� ���� ����������',
  '������������������� �� �� ���� ����������',
  '����������� (������������� ������������ ����������)',
  '������� ��������',
  '������� ��������� ��������',
  '��������� ����������',
);

# ��������� �������� ����������, ��������, $PR{2} = $pr_main_tunes. ��� �� ��� ����������!
# ���������� �����������: pr_SuperAdmin = main_tunes && edt_main_tunes
%pr_def=(
  1 => 'on',
  2 => 'main_tunes',
  3 => 'edt_main_tunes',
  5 => 'edt_adm',
 10 => 'edt_tarifs',
 11 => 'edt_old_pays',
 12 => 'edt_foreign_pays',
 14 => 'events',
 15 => 'del_usr',
 17 => 'fin_report',
 18 => 'no_event_create',
 19 => 'transfer_money',
 21 => 'cards',
 22 => 'cards_create',
 23 => 'workers',
 24 => 'workers_edit',
 25 => 'workers_work',
 26 => 'oo',
 27 => 'edt_category_pays',
 28 => 'edt_events',
 29 => 'worker_come',
 30 => 'turn_office_adm',
 31 => 'turn_any_adm',
 33 => 'cards_show_cod',
 34 => 'mess_all_usr',
 50 => 'show_fio',
 51 => 'pays',
 52 => 'other_adm_pays',
 54 => 'pays_create',
 55 => 'mess_create',
 56 => 'tmp_pays_create',
 57 => 'old_pays_create',
 58 => 'net_pays_create',
 59 => 'worker_pays_create',
 60 => 'edt_pays',
 61 => 'show_usr_pass',
 62 => 'get_cash_from_adm',
 70 => 'edt_usr',
 89 => 'show_traf',
 91 => 'tarifs',
 92 => 'allnet_traffic',
 93 => 'mail',
 94 => 'topology',
 95 => 'edt_topology',
 97 => 'logs',
 98 => 'contacts',
100 => 'usr_stat_page',
101 => 'edt_traf',
102 => 'edt_streets',
106 => 'monitoring',
110 => 'worker_pays_show',
112 => 'detail_traf',
115 => 'get_chng_ask',
117 => 'block_chng_pkt',
);

map{ $Dopfields_tmpl{$_+100}=$Eq_types{$_} } keys %Eq_types;

@Owner_types=(
  '������',
  '�������������',
  '��������',
  '���� � ���������',
  '����� ���������',
);


# $system_id - id ��������� ������� ��� �������� ����������
# ������������� �������� ��� ����������� � ������������ � ����
if( $ENV{HTTP_COOKIE}=~/uid=(.+)/ )
{
   $system_id=&Filtr_mysql($1);
   $got_cookie=1;
}else
{  # ���� � ����� ��� ���� ��� �� ��������������, �� id ����� ��� �� ���������� ����������
   $system_id=Digest::MD5->new;
   $system_id=$system_id->add($ENV{HTTP_USER_AGENT}."-$ip");
   $system_id=&Filtr_mysql($system_id->b64digest);
   $got_cookie=0;
} 

$header=<<HEAD;
<meta http-equiv='Cache-Control' content='no-cache'>
<meta http-equiv='Pragma' content='no-cache'>
<meta http-equiv='Content-Type' content='text/html; charset=windows-1251'>
<meta name='Copyright' content='� nodeny.com.ua'>
<link rel='stylesheet' href='$img_dir/nody.css' type='text/css'>
<script type='text/javascript' src='$img_dir/md5.js'></script>
HEAD

$DOC={
  body_tag	=> '',		# ���������� ���� body, <body $DOC->{body_tag}>
  admin_area	=> '',
  header	=> $header,
  cookie	=> '',
};

$OUT='';


map{ $Dopfields_tmpl_name{$_}=(split /-/,$Dopfields_tmpl{$_})[0] } keys %Dopfields_tmpl;

1;
