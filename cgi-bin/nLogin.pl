#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (�) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nLogin.pl');

$Session_auth_time=120;		# ��� �������� �� �����������

sub Rand_str
{# ������������ ��������� ������
 $_=Digest::MD5->new;
 $_=$_->add(rand(1000000000));
 $_=$_->b64digest;
 tr/+/!/;
 $_=(int rand(10**$_[0])).$_;
}

sub Login_now
{
 $DOC->{admin_area}=''; # �� ����� ����� � ���� ������
 $Ashowsql=0;
 my $salt=&Rand_str(5); # ��������� ����, �� ������� ������� ��������� ��� ��� �� ������
 my $r=int rand(10000000);
 $DOC->{cookie}="Set-Cookie: uid=".int(rand(10000000000)).";" if !$got_cookie; # ��������� ���� ������ ���� �� ���, ����� ������������ ������ ���������
 &Message(qq{<div id=divsubmit><form method=get action='$script' onsubmit='pp.value=hex_md5(salt.value+" "+pp$r.value); pp$r.value=""; return true'>}.
    &input_h('a'=>'enter','salt'=>$salt,'rand_login'=>$r,'pp'=>'error').
    "<table cellpadding=8 cellspacing=1>".
      &RRow('','C',&tag('div','�������� javascript','id=countdiv')).
      &RRow('row2','rl','�����:',&input_t("uu$r",'',30,32,"id=uu$r")). # id= ��� ������
      &RRow('row2','rl','������:',"<input type=password name=pp$r size=30>").
      &RRow('','C',"<input type=checkbox name=trusted value=1 style='border:1px;' checked> ���������� ���������").
      &RRow('','C',"<input type=submit value='&nbsp;&nbsp;&nbsp;����&nbsp;&nbsp;&nbsp;'>").
    "</table></form></div>","$img_dir/keyb.gif",'�����������'.$br.$Title_net,'','infomess',2);
 # $Session_auth_time ������ �� ���� ������, ����� ������ ��������� ����������������
 $dbh->do("INSERT INTO admin_session SET act=1,salt='$salt',system_id='',time_expire=unix_timestamp()+$Session_auth_time") if $dbh;
 $Session_auth_time-=5; # �� ������ ���� ����� ��������� ������� �� �������
 $DOC->{header}.=<<HEAD;
<script type='text/javascript'>
var x=$Session_auth_time;
function a()
{
 x-=1;
 document.getElementById('countdiv').innerHTML="�������� <b>"+x+"</b> ������";
 if(x==0)
 {
   document.getElementById('divsubmit').innerHTML="�����, ���������� ��� �����������, �������.<br><br><div class='nav'><a href='#' onclick='window.location.reload(); return false'>��������������</a></div>";
   window.clearInterval(timer);
 }
}
</script>
HEAD
  $DOC->{body_tag}.=qq{ onload="javascript: timer=setInterval('a()',1000); document.getElementById('uu$r').focus();"};
  &Exit;
}

sub Enter
{
 &Error_Login if $pp eq '-'; # ������ ������� ������ �� ��������������� NoDeny-�����������. ��� ��� �������� ����������� ���������� ����������
 $salt=&Filtr_mysql($F{salt}); # ���������� id �����������
 $sth=$dbh->prepare("SELECT * FROM admin_session WHERE salt='$salt' AND act=1 LIMIT 1");
 $sth->execute;
 &Login unless $p=$sth->fetchrow_hashref; # ������ ���� ������� ����� ���������� �� �����������
 $hash=Digest::MD5->new;
 $hash=$hash->add($F{salt}.' '.$pp); # �� ���� �� ������� ������� ������������ ������ � �����
 $hash=$hash->hexdigest;
 $dbh->do("DELETE FROM admin_session WHERE salt='$salt' AND act=1 LIMIT 1");
 if( $PP ne $hash )
 {
    &ToLog("! ��������� ������� ������������ � �������. Ip: $ip, ��������� �����: ".$F{uu});
    &Error_Login;
 }
 # $F{trusted} ���������� ���� ����� �������� ����� ��� ����� � ����������� �����
 $PP=($F{trusted}? 'T':'S').$Admin_id.'-'.&Rand_str(9);
 $Session_live=$Session_trusted_live if $F{trusted};
 $dbh->do("INSERT INTO admin_session SET act=2,salt='$PP',admin_id=$Admin_id,system_id='$system_id',time_expire=unix_timestamp()+$Session_live");
}

1;

