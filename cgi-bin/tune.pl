#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong('tune');

$pr_main_tunes or &Error('Вам не разрешен доступ к настройкам системы.');
$AdminTrust or &Error('Не разрешен доступ к настройкам, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.');

$list_cfg="$Nodeny_dir_web/list.cfg";

# Вывод ошибочного параметра
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

open(FL,"<$list_cfg") or &Error("Ошибка загрузки файла настроек $list_cfg");
@list=<FL>;
close(FL);

foreach (reverse @list)
{
   /^#(\d\d.\d\d)/ or next;
   $1==$VER_chk or &Error("Неверная версия $1 файла".$br2.$list_cfg);
   last;
}

$Fact=$F{act};

if( $Fact eq 'save' )
{
 $pr_edt_main_tunes or &Error("У вас нет прав на изменение настроек.");
 $need_restart=0;
 $F{iamshure} or &Error("Вы не поставили галочку, подтверждающую ваши намерения.$go_back");
 $new_Passwd_Key=&Filtr_mysql($F{Passwd_Key});
 $i=0;
 $remake='';
 $OUT.="<div align=left>";
 $show_config=$config="#NoDeny Config File\n\n"."\$VER_cfg = $VER_chk;\n";
 foreach $parm (@list)
 {
    $parm=~/^\s*#/ && next; # комментарий
    $parm=~/^\s*$/ && next; # пустая строка

    if( $parm!~/\s*(.)\s+(.+?)\s+(.+?)\s+'(.*)'\s*$/ )
    {
       &ErrorPar('error',"ошибка в файле $list_cfg.",' Строка:'.$br2.&Filtr_out($parm),'');
       next;
    }
    ($S1,$S2,$S3,$S4)=($1,$2,$3,$4);

    if( $S1 eq 'R' )
    {
       $remake=&CenterA("$scrpt&i=$i",'Исправить');
       $i++;
    }

    if( $S1=~/[sfnb]/ )
    {  # параметр - переменная
       $old=${$S2};

       if( defined $F{$S2} )
       {
          $new=$F{$S2};
          $new=~s|\s+$||;	 		# уберем завершающие пробелы в переданных через форму данных
          $new=$old if $S3=~/=/ && $new eq '';	# скрытый параметр и ничего не введено - не меняем
          if( $new ne $old )
          {
             &ErrorPar( 'data1','Изменен параметр:',$S4,&Printf('[br][span data1] [filtr|commas] &rarr; [filtr|commas]','Значение:',$old,$new) );
             $need_restart=1 if $S3!~/0/;
          }
       }
        else
       {
          $new=$old;
       }

       if( $S1 eq 'f' && $new && !(-e $new) )
       {
          &ErrorPar('error','Файл не существует.', 'Имя файла: '.&Filtr_out($new),$br.$S4.$remake);
       }

       if( $S1 eq 's' || $S1 eq 'f' )
       {  # строковой параметр
          $new=~s|\n| |g;
          $new="'".&filtr_param($new)."'";
       }

       if( $S1 eq 'n' )
       {  # целое число
          $new=~/^-?\d*\.?\d*$/ or &ErrorPar('error','Параметр должен быть числом:',&Filtr_out($new),$br.$S4.$remake);
          $new+=0;
       }

       $new=int($new) if $S1 eq 'b';

       $add="\$$S2 = $new;\n";
       $config.=$add;
       $show_config.=$add if $S3!~/=/; # скрытый параметр
       next;
    }

    if( $S1 eq '@' )
    {  # параметр - массив. Внимание! Отфильтровываем символ "возврат каретки" (\r)
       if (defined $F{$S2})
       {
          $F{$S2}=~s/\n+|(\r\n)+/\n/g;
          @massiv=split /\n/,$F{$S2};
          $c="@massiv";
          $d="@{$S2}";
          if( $c ne $d )
          {
             $need_restart=1;
             &ErrorPar('data1','Изменен параметр:',$S4,"&nbsp;");
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
    {  # параметр - хеш2
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
             $a=~s|-| |; # у нас '-' является разделителем
             $b=~s|-| |;
             ($a eq '') && next;
             $massiv{$x}="$a-$b";
          }
          # изменился ли массив? (нужен ли рестарт сервера)
          $c=''; $d='';
          foreach $a (sort keys %massiv) {$c.="$a$massiv{$a}"}
          foreach $a (sort keys %{$S2}) {$d.="$a${$S2}{$a}"}
          if ($c ne $d)
          {
             $need_restart=1;
             &ErrorPar('data1','Изменен параметр:',$S4,"&nbsp;");
          }
       }
        else
       {  # через форму массив не передан - возьмем оригинальный
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
    {  # параметр - хеш1
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
          # изменился ли массив? (нужен ли рестарт сервера)
          $c=''; $d='';
          foreach $a (sort keys %massiv) {$c.="$a$massiv{$a}"}
          foreach $a (sort keys %{$S2}) {$d.="$a${$S2}{$a}"}
          if( $c ne $d )
          {
             $need_restart=1;
             &ErrorPar('data1','Изменен параметр:',$S4,"&nbsp;");
          }
       }
        else
       { # через форму массив не передан - возьмем оригинальный
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

 open(FL,">$Main_config") or &Error('Не могу записать конфигурационый файл '.&bold($Main_config).$br.'Возможно нет прав.');

 print FL $config;
 close(FL);

 $h=&div('big','Конфигурационный файл записан успешно.');
 $h.=$br.($need_restart? 'Для применения изменений необходимо сделать'.$br2.&CenterA("$scrpt0&a=restart&act=send&s=7",'Рестарт ядра NoDeny') : 
    'Вы изменили параметры не влияющие на работу ядра NoDeny. Рестарт не нужен.').$br if $Admin_id;
 &OkMess($h);

 $config=~s/\\/\\\\/g;
 $config=~s/"/\\"/g;

 # запишем файл в базу данных, соединения может и не быть, если его данные деверны
 if( $dbh )
 {
    $rows=$dbh->do("INSERT INTO config SET time=$ut,data=\"$config\"");
    $OUT.=$br.&error('Ошибка записи конфига в базу данных',$br2.'Серверная часть не получит новый конфиг!') if $rows<1;

    if( $new_Passwd_Key && $new_Passwd_Key ne $Passwd_Key )
    {  # изменился ключ кодирования, &sql_do не применять - не светим пароль
       $sql="UPDATE users SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,'$Passwd_Key'),'$new_Passwd_Key')";
       $rows=$dbh->do($sql);
       $OUT.="<div class='message lft'>Был изменен ключ кодирования паролей. Произведем глобальное перекодирование паролей. Выполяем запрос$br2$sql$br2 Результат $rows рядов".$br2;
       $sql="UPDATE admin SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,'$Passwd_Key'),'$new_Passwd_Key')";
       $rows=$dbh->do($sql);
       $OUT.="Для админских паролей:".$br2.$sql.$br2."Результат $rows рядов</div>";
       $sql="UPDATE conf_sat SET Passwd_Key='$new_Passwd_Key'";
       $rows=$dbh->do($sql);
    }
 }

 $show_config=&Filtr_out($show_config);
 $show_config=~s/\n/<br>/g;

 $OUT.='</div>'.$go_back.$br2.($Admin_id? &div('message lft',$show_config) : &ahref("$scrpt0&a=admin",'Создать учетную запись администратора &rarr;'));

 &Exit;  
}

if( $VER_cfg!=$VER_chk && $Admin_id )
{
   $VER_cfg||='?';
   &Message("Версия конфигурационного файла ($VER_cfg) не соответствует версии административного интерфейса ($VER_chk). ".
     'Вероятно вы обновляли NoDeny. Просто сохраните настройки в окне ниже. '.
     'Если ошибка устойчивая - вероятно обновление прошло неполностью.',$err_pic,'Внимание','','infomess');
   &Message('После сохранения настроек не забудьте произвести туже операцию для конфига каждого сателлита!',$err_pic,'Внимание','','infomess');
}

# =======       Отображение параметров      ===========

%menu=();
$body='';
$Fi=int $F{i}+1;
$i=0;
$size=28;			# ширина поля ввода по умолчанию
foreach $parm (@list)
{
  $parm=~/^\s*#/ && next;	# комментарий
  $parm=~/^\s*$/ && next;	# пустая строка
  if( $parm!~/\s*(.)\s+(.+?)\s+(.+?)\s+'(.*)'\s*$/ )
  {
     $body.=&RRow('*','^T',"<span class=error>Ошибка в файле</span> $list_cfg",'Строка с ошибкой:'.$br.&div('lft',&Filtr_out($parm)));
     next;
  }
  ($S1,$S2,$S3,$S4)=($1,$2,$3,$4);

  if( $S1 eq 'R' )
  {  # раздел меню
     $menu{$S4}= ($i+1)==$Fi? &div('head',&ahref("$scrpt&i=$i",$S4)) : &ahref("$scrpt&i=$i",$S4);
     $body.=&RRow('head','3','Раздел: '.&bold_br($S4)) if ++$i==$Fi;
     next;
  }

  $i==$Fi or next;

  $S4=~s|\\n|<br>|g;
  #$S4=&Show_all($S4);

  if ($S1 eq 'm' || $S1 eq 'g')
  {
   # массив или трехэлементный массив
   $body.=&RRow('row3','E',$S4);
   $S3=int $S3;
   $S3=99 if $S3>99;
   if( $S1 eq 'g' )
   {
      for ($x=1;$x<=$S3;$x++)
      {
        $y=${$S2}{$x};
        if ($y=~/^(.+)-(.+)$/) {$p1=$1; $p2=$2} else {$p1=$y; $p1=~s|-||; $p2=''}
        $body.=&RRow('*','rrl','№ '.&bold($x),&input_t("${S2}_$x",$p1,30,128),&input_t("${S2}.$x",$p2,30,128));
      }
      next;
   }
   for ($x=1;$x<=$S3;$x++)
   {
      $body.=&RRow('*','rl ','№ '.&bold($x),&input_t("${S2}_$x",${$S2}{$x},30,128),'');
   }
   next;
  }
        
  $x='';
  if( $S1=~/[sfn]/ )
  {  # параметр - переменная
     $x=$S3!~/=/? &Filtr_out(${$S2}) : '';
     $rsize=$S3=~/3/? 66 : $S3=~/1/? 56 : $size;
     $x=$S3=~/4/? "<textarea name=$S2 type=text cols=$rsize rows=4>$x</textarea>" : &input_t($S2,$x,$rsize,255);
  }

  if( $S1 eq 'b' )
  {  # да/нет
     $x="<select name=$S2 size=1>".
         (${$S2}? "<option value=1 selected>Да<option value=0>Нет</option>" : "<option value=1>Да<option value=0 selected>Нет</option>").
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
    &RRow('head error','E','Неизвестный код параметра '.&Filtr_out($S1));
}

$body="<table class='tbg3'>$body<tr class=tablebg><td width='10%'>$spc</td><td>$spc</td><td width='69%'>$spc</td></tr></table>";

$body=$pr_edt_main_tunes? &form('!'=>1,'act'=>'save','i'=>$Fi-1,$body.
  &div('cntr',$br."<input type=checkbox name=iamshure value=1 style='border:1;'> ".
      "<span class=data2>Подтверждение изменения настроек</span>".$br2.&submit_a('Сохранить'))) :
  &div('message','Вам доступен только просмотр конфига').$body;

{
 $dbh or last;
 $str=nSql->new({
   dbh		=> $dbh,
   sql		=> "SELECT field_name FROM dopfields WHERE field_alias='p_street:street:name_street'",
   show		=> 'full',
   hash		=> \%h,
   comment	=> 'Название поля `Улицы`'
 })? &Del_Sort_Prefix($h{field_name}) : 'Улицы';
 
 
 foreach ( 
  'Тарифы дополнительные|plans3',
  'Направления|nets',
  'Группы клиентов|usr_grp',
  'Предустановленные подключения|newuser',
  "$str|str",
  'Отделы|of',
  'Сателлиты|sat',
  'Дополнительные поля|dopfields'
 )
 {
    /^(.+)\|(.+)$/;
    $h=$1; # ! если вдруг в &ahref в будущем будут регулярные выражения
    $menu{$h}=&ahref("$scrpt0&a=oper&act=$2",$1);
 }
 $menu{'Привилегии администраторов'}=&ahref("$scrpt0&a=admin",'Привилегии администраторов');
 $menu{'Тарифы'}=&ahref("$scrpt0&a=tarif",'Тарифы');
}

$menu=join '',map {$menu{$_}} sort {$a cmp $b} keys %menu;
$OUT.=&div('lft',"<table cellpadding=1 cellspacing=8>".&RRow('','^^',&Mess3('row2 nav2',$menu),$body).'</table>');

1;
