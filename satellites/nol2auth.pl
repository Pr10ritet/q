#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Агент L2 авторизации
# ---------------------------------------------
$VER=50.33;

use Time::localtime;
use Fcntl qw(:flock);
use Crypt::Rijndael;
use IO::Socket;
use FindBin;
use DBI;

#$ipfw		= '/sbin/ipfw -q ';

$AgentName	= 'nol2auth';
$Mod_id		= 1;	# id агента, 1 - `агент L2 авторизации`

$Slap_level=10;		# уровень "наказаний" ip, после которого ip будет заблокирован. Рекомендуется 10
$Slap_noip=5;		# наказаний за попытку авторизации с несуществующего ip либо с ip, не предусматривающего авторизацию
			# если сделать $Slap_level/2, то ответ "неверный ip" будет послан 2 раза (для надежности), после чего ip попадет в игнор лист

$MaxBlockIpToStat=100;	# в статистику будет записываться такое максимальное количество забаненых ip

$sql_set_character_set="SET character_set_results=cp1251";

# === Start загрузчика nosat.pl ====
# После изменения, скопировать в другие агенты

$Program_dir=$FindBin::Bin;
$satmod="$Program_dir/nosat.pl";
eval{require $satmod};
if( $@ )
{
   print "Need $satmod!\n";
   exit 1;
}

# === End загрузчика nosat.pl ====

$Ip=$c{V_auth_Ip};	# verbose Ip

&Log("====== -  NoDeny L2-auth starting - ======");

$My_server_ip=$c{My_server_ip};
$Server_ip=$My_server_ip? inet_aton($My_server_ip) : INADDR_ANY;
$My_port=$c{My_port};

$proto=getprotobyname('udp');
unless( socket(SOCKET,PF_INET,SOCK_DGRAM,$proto) && bind(SOCKET,sockaddr_in($My_port,$Server_ip)) )
{
   $Exit_reason="Ошибка создания udp сокета. Возможно кем-то занят";
   $Exit_cod=1;
   &Exit;
}

&Debug("Удачно забиндили сокет на udp порт $My_port");

$Ver_client=$c{Ver_client};

$DSNA="DBI:mysql:database=$Db_name;host=$c{Db_server_a};mysql_connect_timeout=$c{Db_mysql_connect_timeouta};";
$dbha='';

# Возможна ситуация база авторизации будет недоступна, тогда авторизации будут записываться в основную базу.
# Однако, периодически будут производится попытки соединения с базой авторизации.
# Следующий параметр хранит время до которого нельзя пытаться соединиться с БД авторизации,
# это защита от чрезмерных реконнектов. Ставим 0 - сейчас можно соединяться с БД авторизации
$t_dbauth_connect=0; 


$t_allowping=0;		# показывает время, когда нужно прекратить посылку клиентам разрешения пинговать друг-друга, 0 - уже нельзя
$t_stat=0;		# время когда необходимо записать в базу статистику о ходе работы агента, сейчас же
$t_tarif_load=0;	# время когда загружать тарифы - они нам нужны чтоб получить названия направлений, 0 - сейчас же
$need_random=0;		# флаг "авторизоваться через случайный промежуток времени", секунды

$Where_grp=$c{Usr_auth_groups}? "AND grp IN($c{Usr_auth_groups})" : '';

# Данные для отчетности (мониторинга)
$t_last_stat=&TimeNow();
%StatUniqueIp=();	# очистим таблицу уникальных ip
$StatPackets=0;		# количество обработанных пакетов
$StatFloodPackets=0;	# общее количество пакетов определенных как флуд

# уберем все блокировки авторизации
#system("$ipfw table 127 flush"); 

while(1)
{
  select(undef,undef,undef,0.05); # пауза в столько секунд

  &TarifReload if &TimeNow()>$t_tarif_load;

  # авторизация
  &AUTH;

  $t=&TimeNow();
  
  &SendAgentStat if $t_stat<$t; # пора записать статистику о ходе работы

  # Проверим, может кого надо разблочить в фаере (только авторизацию!)
  foreach $ip (keys %Block)
  {
      next if $Block_ip_time{$ip}>$t;
      &Unblock_ip($ip);
  }

  $Exit_reason && last;
}

&Exit;

sub DbConnect
{
 $dbh=DBI->connect($DSN,$Db_user,$Db_pw,{PrintError=>0});
 $dbh && return;
 my $t=&TimeNow();
 # если последняя ошибка регистрировалась меньше минуты назад, то в логи не пишем
 return if $t<($When_db_error_last+60) && !$V;
 $When_db_error_last=$t; 
 &Log("Ошибка соединения с основной БД! Данные клиентов не обновляются!");
}

sub RunServerCommand
{
}

# ================================================================
# Получает данные клиента
# Вход: ip
# Выход: сформированный массив $U{ip}.{'xxx'}
# ================================================================
sub Get_user_data
{
 my $ip=shift;
 my ($sql,$sth,$p,$id,$mid,$pass,$name,$tm); 
 my $tm=int $U{$ip}{last_got_info}; 

 return if defined($U{$ip}{passwd1}) && $t<($tm+$c{T_get_new}); # слишком часто нельзя обновлять данные, будут задействованы с прошлого чтения БД

 if( $t>($tm+$c{T_get_old}) )
 {  # данные устарели, поэтому удалим признак существования клиента сейчас т.к. далее могут быть ошибки коннекта и т.д.
    # удаляем не все инфо, оставляем наказания и т.д.
    $tm && &Debug("=== Последний раз информация о клиенте (id=$id) была получена так давно, что мы ее удаляем. Если сейчас не будут получены данные клиента, то это будет воспринято, что такого ip в базе данных нет");
    delete $U{$ip}{passwd1};
    delete $U{$ip}{passwd2};
    delete $U{$ip}{passwd3};
    delete $U{$ip}{passwd4};
    delete $U{$ip}{id};   
    delete $U{$ip}{admin};
    delete $U{$ip}{state};
    delete $U{$ip}{auth};
    delete $U{$ip}{startmoney};
    delete $U{$ip}{packet};
    delete $U{$ip}{submoney};
    delete $U{$ip}{traf1};
    delete $U{$ip}{traf2};
    delete $U{$ip}{traf3};
    delete $U{$ip}{traf4};
    delete $U{$ip}{mess_time};
    delete $U{$ip}{rnd_str};
    delete $U{$ip}{id_query};
 } 

 $U{$ip}{cannot_get_info}=1; # пока поставим признак, что не можем получить инфо есть ли клиент в базе или нет вообще

 if( !$dbh )
 {
    &DbConnect;
    $dbh or return;
 }

 $sql="SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM $c{Db_usr_table} WHERE ip='$ip' $Where_grp LIMIT 1";
 $sth=$dbh->prepare($sql);
 if(! $sth->execute )
 {  # возможно потеряно соединение с mysql сервером. Переконнектимся
    &DbConnect;
    $dbh or return;
    $sth=$dbh->prepare($sql);
    $sth->execute or return; # $dbh не обнуляем - следующее невыполнение execute вызовет переконнект
 }

 $U{$ip}{cannot_get_info}=0;

 unless( $p=$sth->fetchrow_hashref )
 {
    &Debug("=== Клиента с ip $ip нет в базе данных. При этом, если клиент был в базе ранее, мы не удаляем информацию о нем в переменных - ".
      "если клиент действительно удален информация будет удалено по таймауту. Это защита от временных глюков при работе с удаленной БД");
    return;
 }

 $U{$ip}{last_got_info}=$t; # запомним когда получили инфо о клиенте

 $ip=$p->{ip};
 $id=$p->{id};

 if ($p->{lstate})
 {   # авторизация отключена
     $U{$ip}{passwd1}='';
     $U{$ip}{passwd2}='';
 }
  else
 {   # разделим пароль на 2 части: одну для посылки шифрованных собщений, другую для приема.
     # пароли должны быть длиной 16 байт (дополним символами 'Z' и '0')
     $pass=$p->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
     $U{$ip}{passwd2}=substr(substr($pass,0,3).'Z' x 16,0,16);
     $U{$ip}{passwd1}=substr($pass.'0' x 19,3,16);
     # для авторизации логин+пароль+ip
     $name=$p->{name};
     $U{$ip}{passwd4}=substr($pass.'Z' x 16,0,16);
     $U{$ip}{passwd3}=substr($name.'0' x 19,0,16);
 }

 $id_to_ip{$id}=$ip;

 $U{$ip}{id}=$id;   
 $U{$ip}{admin}=$p->{contract} eq 'adm'; # админ? 
 $U{$ip}{state}=$p->{state};
 $U{$ip}{auth}=$p->{auth};

 $mid=$p->{mid}||$id;

 # Получим данные по трафику и снятиям с таблицы users_trf
 $sth=$dbh->prepare("SELECT * FROM users_trf WHERE uid=$mid LIMIT 1");
 if ($sth->execute && ($p=$sth->fetchrow_hashref))
 {
    $U{$ip}{submoney}=$p->{submoney};
    $U{$ip}{packet}=$p->{packet};
    $U{$ip}{traf1}=$p->{traf1};
    $U{$ip}{traf2}=$p->{traf2};
    $U{$ip}{traf3}=$p->{traf3};
    $U{$ip}{traf4}=$p->{traf4};
    $U{$ip}{mess_time}=$p->{mess_time};
    $U{$ip}{startmoney}=$p->{startmoney};
 }
  else
 {
    $U{$ip}{traf1}=$U{$ip}{traf2}=$U{$ip}{traf3}=$U{$ip}{traf4}=0;
    $U{$ip}{mess_time}=$U{$ip}{startmoney}=$U{$ip}{submoney}=$U{$ip}{packet}=0;
 }
}

# ================================================================
# Блокирует доступ К АВТОРИЗАЦИИ на уровне фаервола
# Вход: ip
sub Block_ip
{
 my $ip=shift;
 return if $Block{$ip};
 #system("$ipfw table 127 add $ip");
 $Block{$ip}=1;
}

# ================================================================
# Зазблокирует доступ К АВТОРИЗАЦИИ на уровне фаервола
# Вход: ip
sub Unblock_ip
{
 my $ip=shift;
 return unless $Block{$ip};
 #system("$ipfw table 127 delete $ip");
 &Debug("Для $ip разблокирована авторизация в фаерволе");
 delete $Block{$ip};
 $Count_flood_packets{$ip}=0;
}

# ================================================================
sub Slap_Ip
# Вход: ip, уровень замечаний
# Подпрограмма добавляет к общему количеству замечаний текущие замечания
# и если уровнь замечаний больше допустимого, то ip блочится на $T_usr_block сек
{
 my ($ip,$slap)=@_;
 # $Block_ip_time{$ip} выполняет двойную функцию:
 #  - счетчик наказаний, когда содержит число меньше 1000
 #  - время, до которого нужно игнорить любые запросы от $ip
 # Если ранее данный ip уже блокировался, то обнулим счетчик наказаний
 $Block_ip_time{$ip}=0 if $Block_ip_time{$ip}>1000;
 $Block_ip_time{$ip}+=$slap;
 &Debug("$ip наказывается на $slap пунктов. В данный момент у него $Block_ip_time{$ip} пунктов. При достижении $Slap_level попадет в игнор-лист на $c{T_usr_block} сек");
 if( $Block_ip_time{$ip}>=$Slap_level )
 {
    &Debug("$ip попал в игнор-лист на время $c{T_usr_block} сек");
    $Block_ip_time{$ip}=&TimeNow()+$c{T_usr_block};
    $Error_auth_count{$ip}=0; # сбросим счетчик неудачных авторизаций
 }
}

# ================================================================
#                          АВТОРИЗАЦИЯ
# ================================================================
sub AUTH
{
 my ($hispaddr,$addr,$port,$send,$id,$txt,$i,$ver,$cipher);

 my $rin='';
 vec($rin,fileno(SOCKET),1)=1;
 while (select($txt=$rin,undef,undef,0)) # таймаут 0 секунд
 {
    $t=&TimeNow();
    $txt='';
    $hispaddr=recv(SOCKET,$txt,100,0); # игнорируем все, что в пакетах за 100м байтом
    ($port,$addr)=sockaddr_in($hispaddr);
    $ip=join(".",unpack("C4",$addr));
    if( $ip eq '127.0.0.1' || $ip eq $My_server_ip )
    {  # команда от сервера
       &RunServerCommand($txt);
       next;
    }

    $StatUniqueIp{$ip}++; # подсчет уникальности ip
    $StatPackets++; # количество обработанных пакетов

    if( $Block_ip_time{$ip}>$t )
    {  # Время бана еще не вышло
       $StatFloodPackets++; # для статистики общее количество пакетов определенных как флуд
       next if $Block{$ip}; # на случай если в фаере не заблочило, иначе логи переполнятся
       &Debug("Пакет от $ip, этот ip в игнор-листе из-за 'наказаний'. Удаление из игнор-листа через ".($Block_ip_time{$ip}-$t)." сек");
       if( $Count_flood_packets{$ip}++==50 )
       {   # Агрессивный флуд, блочим жостко в фаерволе
           &Debug("Агрессивный флуд со стороны $ip, блокируем доступ в фаерволе");
           &Block_ip($ip);
           # В будущем записать в базу nodeny что жестокий флуд, чтоб админы обратили на это внимание
       }
       next;
      }

    $Count_flood_packets{$ip}=0;

    &Debug("=== Пакет от $ip");

    # формируем адрес для ответа (это новое соединение!)
    $addr=inet_aton($ip);
    $hispaddr=sockaddr_in($My_port,$addr);

    # Проверим есть ли в базе такой ip и получим его данные, если есть
    &Get_user_data($ip);

    # Если пароль неопределен - в базе нет такого ip
    # Если пароль пустой - авторизация отключена для текущего ip
    if(! $U{$ip}{passwd1} )
    {
       next if $U{$ip}{cannot_get_info}; # об этом ip мы не смогли получить инфо (внимание: мы именно не знаем есть ли он в базе),
					   # поэтому мы не можем ему ничего ответить, игнорируем в надежде что он переключится на резервный сервер
       &Debug(defined($U{$ip}{passwd1})? "Для $ip отключена авторизация. Отсылаем сообщение 'неверный адрес'" : "$ip отсутствует в базе данных!");
       send(SOCKET,'eri',0,$hispaddr); # отошлем сообщение "у тебя не тот ip"
       &Slap_Ip($ip,$Slap_noip); # накажем
       next;
    }

    # Увеличим счетчик неудачных авторизаций, это защита от флуда, при удачной авторизации он обнулится
    if( $Error_auth_count{$ip}++>10 )
    {  # слишком много неудачных авторизаций
       &Debug("Для $ip сработала защита от неудачных авторизаций");
       &Slap_Ip($ip,$Slap_level); # накажем по максимуму т.к чтобы ip попал в игнор лист
       send(SOCKET,'erw',0,$hispaddr); # клиенту отправим просьбу не грузить сервер
       next;
    }

    # Получили запрос на формирование случайной строки?
    if( length($txt)<16 )
    {
       # Сформируем случайную строку для авторизации
       my $str=substr(rand().rand().'errorinlastline',2,16);
       # id должен содержать случайные символы, а у нас только цифры, поэтому зашифруем
       $str=new Crypt::Rijndael $str,Crypt::Rijndael::MODE_CBC;
       $str=$str->encrypt(substr(rand().rand().'qazxswedcvfrtgbn',2,16));
       $str=~s/,/-/g; # разделитель "запятая" может встретится в ключе, меняем на другой символ
       $U{$ip}{rnd_str}=$str;
       $U{$ip}{id_query}=$txt; # запомним id запроса
       # авторизация логин+пароль+ip или пароль+ip ?
       my $type_auth=substr($txt,2,1) eq 'a';
       $send=$type_auth? $U{$ip}{passwd4} : $U{$ip}{passwd2};
       $send=new Crypt::Rijndael $send,Crypt::Rijndael::MODE_CBC;
       $send='id'.($send->encrypt($str)).$txt; # зашифруем случайную строку исходящим паролем
       send(SOCKET,$send,0,$hispaddr);
       &Debug("Запрос на авторизацию. Тип авторизации: ".($type_auth?'логин+пароль+ip':'пароль+ip').". ID запроса=$txt. Зашифрованный ключ послан в ответ");
       next;
    }

    # 2я стадия авторизации - проверка ключа и выполнение команд на авторизацию

    if(! $U{$ip}{rnd_str})
    {
       &Debug("Пакет от $ip, но запроса на авторизацию не было. Игнорируем");
       &Slap_Ip($ip,2); # накажем на 2 пункта 
       next;
    }

    $ver=int(substr $U{$ip}{'id_query'},0,2); # версия авторизатора
    $ver=1 if $ver<1 || $ver>255;

    # авторизация логин+пароль+ip или пароль+ip ?
    $cipher=substr($U{$ip}{id_query},2,1) eq 'a'? $U{$ip}{passwd3} : $U{$ip}{passwd1};
    $cipher=new Crypt::Rijndael $cipher,Crypt::Rijndael::MODE_CBC;
    $decrpt=$cipher->decrypt(substr $txt,0,16);
    my $str=$U{$ip}{rnd_str};
    my $rnd=$str; # оригинальная случайная строка, а $str далее может усекаться (старые версии авторизатора)
    $ClientAnswer=''; # ответ клиента на дополнительные команды заказанные сервером
    my ($orig_com,$com);
    if( length($txt)==16 )
    {  # старый протокол (команда часть кодированного сообщения)
       $orig_com=substr $decrpt,0,1;
       $com=$orig_com;
       $decrpt=substr $decrpt,1,15; # т.к. первый символ был заменен на команду
       $str=substr $str,1,15;
       $id='';
    }else
    {
       $orig_com=substr $txt,16,1;  # выделим команду
       $com=lc($orig_com);
       $id=length($txt)<18 ? '' : substr $txt,17,length($txt)-17; # id сессии
       ($id,$ClientAnswer)=($1,$2) if $id=~/^(.+?)\|(.+)$/;
    }

    if( $id ne $U{$ip}{id_query} )
    {  # id не от нужной сессии
       &Slap_Ip($ip,1); # накажем на 1 пункт
       next;
    }

    $U{$ip}{rnd_str}=''; # больше по этой строке авторизоваться будет нельзя

    if( $decrpt ne $str )
    {   # неудачная авторизация
        send(SOCKET,"no$U{$ip}{'id_query'}",0,$hispaddr); # т.к. длина 'no'+$zapros2 <>16, то старые клиенты не будут воспринимать это как строку для шифрования
        &Debug("2й шаг авторизации. Неудачная авторизация");
        &Slap_Ip($ip,5); # накажем на 5 пунктов
        next;
    }

    # --- авторизация прошла успешно ---
    &Debug("2й шаг авторизации. Авторизация успешна. Режим авторизации: $com");

    # Мысль интересная

    #if( $Error_auth_count{$ip}>10 )
    #{   # неудачная авторизация либо удачная, но до этого было много неудачных попыток
    #    send(SOCKET,"no$U{$ip}{'id_query'}",0,$hispaddr); # т.к. длина 'no'+$zapros2 <>16, то старые клиенты не будут воспринимать это как строку для шифрования
    #    if( $decrpt ne $str )
    #    {
    #       &Debug("2й шаг авторизации. Авторизация удачная, но т.к до этого было много неудачных попыток мы один раз сделаем вид, ".
    #              "что авторизация не удалась. Если $ip не перебирает пароли, то в следующую попытку авторизуется") if $V;
    #       $Error_auth_count{$ip}=0;
    #       next;
    #    }

    # Обнуляем счетчик некорректных пакетов
    $Error_auth_count{$ip}=0;

    # здесь $com =
    # a - запрос на включение полного доступа
    # b - запрос на блокирование доступа
    # c - запрос на включение доступа к сетям 2 направления
    # e - запрос на включение полного доступа с просьбой разрешить пингование

    # Если клиент передал запрос в верхнем регистре - значит он запросил команду у сервера (в новых авторизаторах всегда первая сессия авторизации)
    if( $com ne $orig_com )
    {
       $send='go';
       $str=$U{$ip}{id_query}.'|';
       $str.=' ' x 16;
       if( $U{$ip}{ask_com} )
       {  # Сюда мы попадаем тогда, когда предыдущий запрос ТОЖЕ был запросом команды. На запросы команды никаких таймаутов не накладывалось, поэтому
          # в этот раз установим блокировку чтобы нельзя было задосить
          $Block_ip_time{$ip}=&TimeNow()+8;
       }
        else
       {
          $Block_ip_time{$ip}=0; # обнулим список наказаний
          $U{$ip}{ask_com}=1; # флаг 'была запрошена команда у сервера'
       } 
    }
     else
    {     
       # Внимание. Т.к. удачная авторизация обнуляет список некорректных пакетов, злоумышленник может ДОСить напором КОРРЕКТНЫХ авторизаций 
       #(эффективность атаки слабая из-за процедуры диалога), либо чередуя корректные авторизации с потоком левых пакетов (эффективность атаки выше),
       # Поэтому на небольшой промежуток времени отправим $ip в игнор лист :) т.к нам незачем частые авторизации.
       # Может возникнуть соблазн для пущей защищенности время игнора сделать чуть меньшим периоду авторизации, однако так поступать нельзя т.к
       # мы не знаем получил ли клиент последний пакет (условно считаем что работаем на канале с потерями). Если же клиент не получит финальный пакет,
       # то он будет пытаться авторизовываться каждые 5 секунд, и уйдет на резервный сервер.
       # Значением берем из такого допущения: если в канале и есть потери, то они небольшие

       $Block_ip_time{$ip}=&TimeNow()+8;

       $U{$ip}{ask_com}=0;

       # 2 минуты будем отсылать всем команду "пинг разрешен"
       $t_allowping=$t+120 if $com eq 'e' && $U{$ip}{admin};

       # $cod - пересылаемое состояние авторизатору
       # 5 - если доступ закрыт в базе жостко
       my $cod=$U{$ip}{state} eq 'off'? 5 : $com;
       # Если сервер уже знает об авторизации клиента и у него есть причины не давать доступ, то сообщим авторизатору
       $cod=int $U{$ip}{auth} if $U{$ip}{auth}>0 && $U{$ip}{auth}<10;

       if( $v )
       {
          &Debug("Доступ $ip закрыт по причине превынения трафика") if $cod==1;
          &Debug("Доступ $ip закрыт по причине денежной задолженности") if $cod==2;
          &Debug("Доступ $ip закрыт по причине ограничения доступа по времени суток") if $cod==4;
          &Debug("Доступ $ip заблокирован в базе данных") if $cod==5;
          &Debug("Сервер еще не отреагировал на авторизацию $ip и пока считает неавторизованным. Поэтому клиенту ПОКА ответим, что режим авторизации соответствуем им заказанному") if $U{$ip}{'auth'} eq 'no';
       }

       $cod=3 if $Ver_client>$ver; # Код "версия авторизатора устарела" приоритетней остальных состояний
       # cod2 = 2 - указание клиенту переавторизоваться через случайный промежуток времени
       my $cod2=$t_allowping>$t? '1' : $need_random? '2' : '0';
       $mess_time=int $U{$ip}{'mess_time'};
       $send=$U{$ip}{admin}? 'sv' : 'ok'; # 'sv' разрешает закладку "админ" в авторизаторе

       if( $ver<25 )
       {# старая версия авторизатора
          $str="$U{$ip}{id_query},$cod$cod2,$U{$ip}{traf1},$U{$ip}{traf2},$U{$ip}{submoney},$U{$ip}{startmoney},0.-999999!$mess_time#";
       }else
       {
          $i=$U{$ip}{packet};
          $str="$U{$ip}{id_query},$cod,$cod2,$U{$ip}{traf1},$U{$ip}{traf2},$U{$ip}{traf3},$U{$ip}{traf4},$U{$ip}{submoney},$U{$ip}{startmoney},$mess_time";
          $str.=",$Tarif{$i}{1}";
          $str.=",$Tarif{$i}{2}";
          $str.=",$Tarif{$i}{3}";
          $str.=",$Tarif{$i}{4},";
       }
       $str.='.'.' ' x 15;
    }

    $cipher=new Crypt::Rijndael $rnd,Crypt::Rijndael::MODE_CBC;
    while( length($str)>15 )
    {
       $send.=$cipher->encrypt(substr $str,0,16);
       $str=substr $str,16,length($str)-16;
    }
    send(SOCKET,$send,0,$hispaddr);

    # запишем в базу, что клиент авторизовался
    my $act=$com eq 'a'? 10 : $com eq 'c'? 11 : 12; # код авторизации

    my $sql="INSERT INTO dblogin set mid=$U{$ip}{id},act=$act,time=unix_timestamp()";

    my $rows;
    if( $dbha )
    {  # есть соединение с базой авторизации
       $rows=$dbha->do($sql);
       $rows==1 && &Debug("Авторизация записана в базу авторизаций");
       $rows==1 && next;
    }

    # вероятно нет соединения с базой авторизацией
    if( $t_dbauth_connect>&TimeNow() )
    {  # пока нельзя иннициировать соединение с базой авторизаций - защита от частых коннектов
       # поэтому запишем в основную базу
       $dbh->do($sql) if $dbh;
       next;
    }

    # пробуем соединиться с базой авторизации
    $dbha=DBI->connect($DSNA,$Db_user,$Db_pw,{PrintError=>0});
    next if $dbha && ($rows=$dbha->do($sql)) && $rows==1;
    # не получилось записать, запишем в основную базу
    $dbh->do($sql) if $dbh;
    $t_dbauth_connect=&TimeNow()+15; # 15 секунд не будем пытаться соединиться с базой авторизации
    &Debug("Авторизацию записали в основную базу т.к. не получилось записать в базу авторизаций");
 }
}


# ========================================================================
#             Загрузка названий направлений в тарифах
# Возврат:
#  массив $Tarif{$id}{$class} = 'название направления',
#         где $id - id тарифа, $class - номер направления (1..4)
# ========================================================================
sub TarifReload
{
 my ($sth,$sql,$p,$id,$preset);
 $t_tarif_load=&TimeNow()+600; # следующая перечитка через 10 минут 

 $V=$v; # verbose
 if( $dbh )
 {
    &DbConnect;
    $dbh or return;
 }

 $dbh->do($sql_set_character_set);

 # Получим названия направлений в пресетах
 $sql="SELECT * FROM nets WHERE priority=0 AND class IN (1,2,3,4)";
 $sth=$dbh->prepare($sql);
 if(! $sth->execute )
 {  # возможно потеряно соединение с mysql сервером. Переконнектимся
    &DbConnect;
    $dbh or return;
    
    $dbh->do($sql_set_character_set);
    $sth=$dbh->prepare($sql);
    $sth->execute or return;
 }
   
 while( $p=$sth->fetchrow_hashref )
 {
    $PresetName{$p->{preset}}{$p->{class}}=$p->{comment};
 }
 
 $sth=$dbh->prepare("SELECT id,preset FROM plans2");
 $sth->execute or return;
 while( $p=$sth->fetchrow_hashref )
 {
    $id=$p->{id};
    $preset=$p->{preset};
    $Tarif{$id}{1}=$PresetName{$preset}{1}||'';
    $Tarif{$id}{2}=$PresetName{$preset}{2}||'';
    $Tarif{$id}{3}=$PresetName{$preset}{3}||'';
    $Tarif{$id}{4}=$PresetName{$preset}{4}||'';
    $Tarif{$id}{1}=~s/,//g; # т.к. в финальном пакете запятая - разделитель
    $Tarif{$id}{2}=~s/,//g;
    $Tarif{$id}{3}=~s/,//g;
    $Tarif{$id}{4}=~s/,//g;
    &Debug("Для тарифа $id названия направлений:\n".
      "   1: $Tarif{$id}{1}".
      "   2: $Tarif{$id}{2}".
      "   3: $Tarif{$id}{3}".
      "   4: $Tarif{$id}{4}");
 }
}

# =========================================
#      Запись статистики о ходе работы
# =========================================
sub SendAgentStat
{
 $t_stat=$t+$ReStat; # когда следующая статистика
 
 my ($ip,$ip_list,$n);
 my $set='';
 $set.=($t-$t_last_stat).'|'; # продолжительность среза мониторинга
 $t_last_stat=$t;
 $set.=scalar(keys %StatUniqueIp).'|'; # уникальных ip за срез мониторинга
 %StatUniqueIp=();
 $set.="$StatPackets|$StatFloodPackets|";
 $StatPackets=0;
 $StatFloodPackets=0;
 # Определим ip, которые забанены больше чем на 10 секунд (не меньше т.к. после удачной авторизации ip банится на несколько секунд)
 $n=0;
 foreach $ip (%Block_ip_time)
 {
    next if $Block_ip_time{$ip}<($t+10);
    $ip_list.="$ip," if $n<$MaxBlockIpToStat;
    $n++;
 }
 $ip_list=~s/,$//;
 $set.="$n\n";
 $set.="$ip_list\n";
 &SaveSatStateInDb($set,0);
}




