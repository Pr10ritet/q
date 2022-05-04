#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nLogin.pl');

$Session_auth_time=120;		# сек отведено на авторизацию

sub Rand_str
{# формирование случайной строки
 $_=Digest::MD5->new;
 $_=$_->add(rand(1000000000));
 $_=$_->b64digest;
 tr/+/!/;
 $_=(int rand(10**$_[0])).$_;
}

sub Login_now
{
 $DOC->{admin_area}=''; # ни каких логов в окне логина
 $Ashowsql=0;
 my $salt=&Rand_str(5); # случайная соль, по которой браузер сообразит нам хеш от пароля
 my $r=int rand(10000000);
 $DOC->{cookie}="Set-Cookie: uid=".int(rand(10000000000)).";" if !$got_cookie; # установим куки только если их нет, иначе параллельные сессии похерятся
 &Message(qq{<div id=divsubmit><form method=get action='$script' onsubmit='pp.value=hex_md5(salt.value+" "+pp$r.value); pp$r.value=""; return true'>}.
    &input_h('a'=>'enter','salt'=>$salt,'rand_login'=>$r,'pp'=>'error').
    "<table cellpadding=8 cellspacing=1>".
      &RRow('','C',&tag('div','Включите javascript','id=countdiv')).
      &RRow('row2','rl','Логин:',&input_t("uu$r",'',30,32,"id=uu$r")). # id= для фокуса
      &RRow('row2','rl','Пароль:',"<input type=password name=pp$r size=30>").
      &RRow('','C',"<input type=checkbox name=trusted value=1 style='border:1px;' checked> доверенный компьютер").
      &RRow('','C',"<input type=submit value='&nbsp;&nbsp;&nbsp;Вход&nbsp;&nbsp;&nbsp;'>").
    "</table></form></div>","$img_dir/keyb.gif",'Авторизация'.$br.$Title_net,'','infomess',2);
 # $Session_auth_time секунд на ввод пароля, потом сессия считается недействительной
 $dbh->do("INSERT INTO admin_session SET act=1,salt='$salt',system_id='',time_expire=unix_timestamp()+$Session_auth_time") if $dbh;
 $Session_auth_time-=5; # на случай если будет небольшая разница во времени
 $DOC->{header}.=<<HEAD;
<script type='text/javascript'>
var x=$Session_auth_time;
function a()
{
 x-=1;
 document.getElementById('countdiv').innerHTML="Осталось <b>"+x+"</b> секунд";
 if(x==0)
 {
   document.getElementById('divsubmit').innerHTML="Время, отведенное под авторизацию, истекло.<br><br><div class='nav'><a href='#' onclick='window.location.reload(); return false'>Авторизоваться</a></div>";
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
 &Error_Login if $pp eq '-'; # данная учетная запись не предусматривает NoDeny-авторизацию. Для нее включена авторизация средствами вебсервера
 $salt=&Filtr_mysql($F{salt}); # уникальный id авторизации
 $sth=$dbh->prepare("SELECT * FROM admin_session WHERE salt='$salt' AND act=1 LIMIT 1");
 $sth->execute;
 &Login unless $p=$sth->fetchrow_hashref; # мухлеж либо истекло время выделенное на авторизацию
 $hash=Digest::MD5->new;
 $hash=$hash->add($F{salt}.' '.$pp); # по этой же формуле браузер преобразовал пароль в форме
 $hash=$hash->hexdigest;
 $dbh->do("DELETE FROM admin_session WHERE salt='$salt' AND act=1 LIMIT 1");
 if( $PP ne $hash )
 {
    &ToLog("! Неудачная попытка залогиниться в админке. Ip: $ip, введенный логин: ".$F{uu});
    &Error_Login;
 }
 # $F{trusted} установлен если админ поставил галку что зашел с доверенного компа
 $PP=($F{trusted}? 'T':'S').$Admin_id.'-'.&Rand_str(9);
 $Session_live=$Session_trusted_live if $F{trusted};
 $dbh->do("INSERT INTO admin_session SET act=2,salt='$PP',admin_id=$Admin_id,system_id='$system_id',time_expire=unix_timestamp()+$Session_live");
}

1;

