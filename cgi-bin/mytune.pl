#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

# $F{act} не менять - привязка в adm.pl для данных, переданных как multipart/form-data

$Admin_id or &Error("Создайте учетную запись для работы с NoDeny. Запись admin только для первоначальной настройки.");
$PR{108} && !$pr_RealSuperAdmin && &Error("Нет прав на изменение личных настроек данной учетной записи. Переключитесь на свою.");

%UsrList_cols=(
 1 => 'Id',
 2 => 'ФИО',
 3 => 'Логин',
 4 => 'Баланс',
 5 => 'Группа',
 6 => 'Контракт',
 7 => 'Дата контракта',
 8 => 'Ip',
 9 => 'Сумма снятия',
10 => 'Телефон',
11 => 'Улица',
12 => 'Дом',
13 => 'Квартира',
14 => 'Баланс с услугами',
15 => 'Граница отключения',
16 => 'Пакет',
17 => 'Трафик направления 1',
18 => 'Трафик направления 2',
19 => 'Трафик направления 3',
20 => 'Трафик направления 4',
21 => 'Трафик суммарный',
22 => 'Следующий пакет',
30 => 'Допполя с флагом `титульные`',
50 => 'яяя_Кнопка `Пополнить счет`',
51 => 'яяя_Кнопка `Статистика`',
52 => 'яяя_Кнопка `Карта`',
53 => 'яяя_Кнопка `Все на точке`',
54 => 'яяя_Кнопка `Все на доме`',
);

$return=$br2.&CenterA("$scrpt0&a=mytune",'Посмотреть настройки');

if ($F{act} eq 'save_str')
{
   $r=join '', map{ "$_," } grep{ $F{"a$_"} } sort keys %Regions;
   chop $r;
   &sql_do($dbh,"UPDATE admin SET regions='$r' WHERE id=$Admin_id LIMIT 1");
   &OkMess("Список приоритетных районов изменен.$return");
   &Exit;
}

if ($F{act} eq 'save_pass')
{
   $pp=$p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"};
   ($pp ne  '-') or &Error("Вы не можете изменить свой пароль, поскольку вы авторизуетесь не через биллинг, а вебсервером.");
   ($pp eq $F{old_man}) or &Error('Текущий пароль указан неверно.'.$br2.'Пароль не изменен.');

   $Fpasswd1=&Filtr_mysql($F{new_man1});
   $Fpasswd2=&Filtr_mysql($F{new_man2});
   ($F{new_man1} eq $F{new_man2}) or &Error("Новый пароль не совпадает с его повторным вводом. Пароль не изменен.".$return);
   &Error("Пароль не может быть меньше 6 символов, а также начинаться или заканчиваться пробелом.".$br2.
      "Пароль не изменен.".$return) if length($Fpasswd1)<6 || $Fpasswd1=~/^\s+/ || $Fpasswd1=~/\s+$/; # походу, пароль '-' не прокатит по длине

   $rows=&sql_do($dbh,"UPDATE admin SET passwd=AES_ENCRYPT('$Fpasswd1','$Passwd_Key') WHERE id=$Admin_id LIMIT 1",'','Скрыт');
   $rows<1 && &Error("Пароль не изменен. Попробуйте снова или обратитесь к главному администратору.");
   # Удалим все активные сессии данного админа
   &sql_do($dbh,"DELETE FROM admin_session WHERE admin_id=$Admin_id");
   &OkMess('Ваш пароль для доступа в административный интерфейс успешно изменен.'.$br2.&CenterA($scrpt0,'Авторизоваться'));
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
      &ErrorMess("Email задан неверно, поэтому не изменен");
      $set_email='';
   }  

   # сообщения от клиентов в каких группах будут отсылаться на email админа. Если в будущем доступы будут изменены -
   # это не скажется на безопасности т.к перед отправкой сообщений будут дополнительные проверки
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
   &OkMess('Данные обновлены'.$return);
   &Exit;
}

if ($F{act} eq 'save_pic')
{
   $pic=$cgi->param('pic');
   if ($pic)
   {
      $pic!~/\.(jpg|jpeg|gif|png|tif|tiff)$/i && &Error("Картинка должна иметь одно из следующих расширений: jpg, jpeg, gif, png, tif, tiff");
      $ext=lc($1);
      $ffile.="$Adm_img_f_dir/Adm_$Admin_id.$ext";
      $FileOut='';
      while (read($pic,$b,1024)) {$FileOut.=$b}
      open(FL,">$ffile") or &Error("Ошибка загрузки аватара <b>$ffile</b>. Возможно папка не существует либо недоступна на запись. Обратитесь к главному администратору");
      binmode(FL);
      print FL $FileOut;
      close(FL);
      &OkMess("<img src='$Adm_img_dir/Adm_$Admin_id.$ext'>".$br3.&bold("Аватар загружен").$return);
   }
    else
   {
      $ext='';
      &Message(&bold('Аватар удален'));
   } 
   $rows=&sql_do($dbh,"UPDATE admin SET ext='$ext' WHERE id=$Admin_id LIMIT 1");
   &Exit;
}

# === Отображение параметров ===

$row_id=5;
$out=&RRow('head','3','Отметьте районы, улицы которых вам будут доступны в первую очередь');
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
$out.=&RRow('head','3',$br.&submit_a('Сохранить').$br);

$OUT.="<div class=message>".$br.&div('big','Ваши настройки').$br.
  "<table><tr><$tc valign=top>".
    &form('!'=>1,'act'=>'save_str',&Table('width100 tbg1',$out)).
  "</td><$tc valign=top>";

$Admin_pay_mess=$p_adm->{pay_mess};

# сообщения от клиентов в каких группах будут отсылаться на email админа
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
       push @usrlist_header,'&nbsp;&nbsp;Вид '.($_+1).'&nbsp;&nbsp;';
       push @usrlist_cols,"<input type=checkbox value=1 name='cols-$_-$g'".(defined($Atunes{"cols-$_-$g"}) && ' checked').'>';
   }
   $h=$UsrList_cols{$g};
   $h=~s|^яяя_||;
   $usrlist_cols.=&RRow('*','l'.('c' x $UsrList_cols_template_max),$h,@usrlist_cols);
}

$usrlist_cols=&Table('tbg',
   &RRow('* head','c' x ($UsrList_cols_template_max+1),'Название поля',@usrlist_header).
   $usrlist_cols
);

$out=&form('!'=>1,'act'=>'save',
  &div('story','Перечислите сообщения, которые вы чаще всего посылаете клиентам. Они будут выводится рядом с полем ввода сообщения, '.
    'при этом, кликнув по одному из них, выбранная фраза занесется в поле ввода.'.$br2.
    'Если в начале сообщение стоит #число, то поле ввода наличных также будет установлено в это число (можно указывать с минусом).').$br.
  &input_ta('pay_mess',$Admin_pay_mess,56,12).$br2.
  "Оформление:".$br2.
  &Table('tbg3',
    &RRow('*','ll','Ваш email',&input_t('email',$p_adm->{email},30,34)).
    &RRow('*','ll','Выводить ip клиента в списке платежей',"<input type=checkbox value=1 name=ShowIpInPays".(!!$Atunes{ShowIpInPays} && ' checked').'>').
    ($pr_SuperAdmin && &RRow('*','ll','Режим вывода отладочных сообщений',"<input type=checkbox value=1 name=showsql".(!!$Atunes{showsql} && ' checked').'>'))
  ).$br2.
  &MessX("Выберите группы, сообщения от клиентов которых, вы будете получать на email:".$br2.$email_grp).$br.
  &div('story',"Отметьте галочками те колонки, которые вы хотите видеть в выводе списка клиентов. Предусмотрено несколько видов отображений, ".
     "в работе вы можете переключаться между ними, скажем для первого вида предусмотреть только самые необходимые поля, а для второго - все.").$br.
     $usrlist_cols
  .$br.
  &submit_a('Сохранить').$br
);

$OUT.=&div('message lft',$out);

# данные при передаче картинки передаем методом get т.к. не переварит скрипт adm, сама картинка передается post-ом
$OUT.=$br3.&Center_Mess("Вы можете загрузить аватар (эмблему), которая будет выводиться в левом верхнем углу админки.".$br.
    "Если не выбрать никакой файл, то аватар будет удален и будет использован аватар по умолчанию (эмблема сети)".$br2.
    "<form method=post action='$script' enctype='multipart/form-data' ".&FormSubmitEvent.">".&input_h(%FormHash).&input_h('act','save_pic').
    "<input type=file name=pic size=50 value=''>$br2<div id=savediv$SaveDiv><input type=submit value='Загрузить'></div></form>",1);

$OUT.=$br3.&Center_Mess("Если желаете изменить пароль для вашей учетной записи,".$br2.
   &form('!'=>1,'act'=>'save_pass',
     &Center(
       &Table('tbg1',
         &RRow('*','rl','введите текущий пароль','<input type=password name=old_man size=30>').
         &RRow('*','rl','новый пароль','<input type=password name=new_man1 size=30>').
         &RRow('*','rl','новый пароль','<input type=password name=new_man2 size=30>').
         &RRow('*','C',&submit_a('Изменить'))
       )
     )
   ),1
) if $p_adm->{"AES_DECRYPT(passwd,'$Passwd_Key')"} ne '-';

$OUT.='</td></tr></table></div>';

1;

