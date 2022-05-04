#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('nErrConnect');

# «десь если $UU установлена, то уже произошла авторизаци€ под системным логином

$out=&bold_br("$Title_net - NoDeny system").'ќшибка (110) подключени€ к основной базе данных.';
unless ($UU)
  {
   &ErrorMess($out.' ≈сли вам посто€нно отображаетс€ эта ошибка - обратитесь к главному администратору. '.
      '≈сли вы главный администратор - залогиньтесь под системным логином ниже.');
   &Login;
  }

$out.=$br2.&div('borderblue',&Printf('[span disabled] [filtr][br][span disabled] [filtr][br][span disabled] [filtr][br][span disabled] [filtr]',
 'логин:',$user,'пароль:',$pw,'сервер:',$db_server,'база:',$db_name));
$out.=($DBI::errstr);

map{ $out.=$br2.&div('borderblue',&bold($_).$br.'<pre>'.`$_`.'</pre>') } ('ps ax | grep mysql','df -H');
&ErrorMess($out);

$Fa='tune'; # принудительно переходим в раздел настроек
$scrpt="$scrpt0&a=tune";
$FormHash{a}='tune';

$file="$Nodeny_dir_web/tune.pl";
eval{require $file};
$@ && &Error("ћодуль $file не найден либо нет прав на его загрузку вебсервером."); # суперадмину полный путь

&Exit;

1;      
