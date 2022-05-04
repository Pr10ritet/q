#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

if ($F{mess})
  {
   $url="$scrpt0&a=payshow&nodeny=event";
   $OUT.=$br3.&MessX('Сигнал послан ядру. Через 10 секунд произойдет переход на страницу просмотра событий.'.$br3.&CenterA($url,'Перейти &rarr;'),1,0);
   $DOC->{header}.=qq{<meta http-equiv="refresh" content="10; url='$url'">};
   &Exit;
  }

$Fact=$F{act};

if ($Fact eq 'send')
  {# Послать сигнал серверной части
   $PR{16} or &Error('Для доступа недостаточно привилегий.');
   $AdminTrust or &Error('Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.');
   $s=int $F{s};
   $rows=&sql_do($dbh,"INSERT INTO dblogin SET mid=0,act=$s,time=$ut");
   $rows<1 && &Error('Ошибка sql. '.&ahref("$scrpt&act=$Fact&s=$s",'Послать сигнал повторно'));
   $DOC->{header}.=qq(<meta http-equiv="refresh" content="0; url='$scrpt&mess=1'">);
   &Exit;
  }

$OUT.=&div('message nav2 lft',&Table('tbg3',
  &RRow('','C','Послать ядру NoDeny сигнал:').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=7",'Рестарт'),'Рестарт только после окончания записи трафика, т.е. может пройти несколько минут до реального рестарта').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=1",'Жесткий рестарт'),'Быстрый, но менее корректный рестарт. Рекомендовано выполнять обычный рестарт').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=10",'Остановить ядро'),'').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=4",'Обновить список клиентов'),"Список клиентов обновляется ядром каждые $interval_oprosa_state секунд, поэтому обычно нет необходимости использовать данный сигнал").
  &RRow('*','ll',&ahref("$scrpt&act=send&s=2",'Перечитать тарифы'),'Следует посылать сигнал после изменения тарифов').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=3",'Перечитать список направлений'),'Следует посылать сигнал после редактирования в разделе &#171;настройки&#187; &rarr; &#171;направления&#187;').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=5",'Ping'),'Послать ping, в ответ должно прийти событие pong').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=6",'Письмо админу'),'При получении данного сигнала ядро пошлет админу тестовое письмо, получение этого письма говорит о том, что в критических ситуациях админ будет информирован').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=8",'Тюнинг sql'),'').
  &RRow('*','ll',&ahref("$scrpt&act=send&s=9",'Отключить тюнинг sql'),'')
 )).$br if $AdminTrust;

unless ($pr_logs)
  {
   $OUT.=$br.&div('message','Лог файл не отображается т.к у вас нет привилегий на его просмотр.');
   &Exit;
  }
   
unless (open(LOG,"<$Log_file"))
  {
   $OUT.=$br.&div('message','Лог файл '.&bold($Log_file).(-e $Log_file? ' не доступен для чтения. Проверьте владельца и права доступа.' : ' отсутствует.'));
   &Exit;
  }

$ahref='';
if ($Fact ne 'fulllog')
  {
   seek(LOG,-32000,2);
   $ahref=&CenterA("$scrpt&act=fulllog",'Полный лог');
  }

@lg=reverse <LOG>;
grep {s/^(.+?) !! (.+?)\n/$1 <span class=error>$2<\/span>\n/} @lg;
grep {s/^(.+?) ! (.+?)\n/$1 <span style='color:#c22020'>$2<\/span>\n/} @lg;
$lg=join('',@lg);
$lg=~s/\n/<br>/g;
close (LOG);

$OUT.=&div('message cntr',&bold('Лог-файл админки биллинга:').
   "<div class='row1 lft' style='overflow:scroll; width:100%; height:350px'>$lg</div>$ahref");

1;
