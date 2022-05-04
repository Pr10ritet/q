#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$VER==$VER_chk or &VerWrong($F{a});

$pr_topology or &Error('Доступ к разделу топологии вам запрещен.');
$cc=$PR{95}; # CanChange

eval{require Imager};
$@ && &Error($pr_SuperAdmin? 'Не инсталлирован модуль Imager. Выполните:'.$br2.
   'bash# cd /usr/ports/graphics/p5-Imager && make install clean'.$go_back :
   'Раздел карт не готов к работе, обратитесь к главному администратору.');

sub mExit
{
 $OUT.=$br2.&CenterA("javascript:opener.location.reload();self.close()",'Закрыть').'</div>';
 &Go_out;
 print $OUT;
 exit;
}

sub pMapMenu
{
 $out=join '',map{ '<td class=nav2>'.&ahref("$scrpt0&a=$Fa&small=$Fsmall&i=$_",${"MP_name$_"}).'</td>' } grep {${"MP_name$_"} ne ''} (0..10);

 $out.='<td class=nav>'.&ahref("$scrpt&c=1",' Авториз ').
     &ahref("$scrpt&c=2",' Подсети ');
     &ahref("$scrpt&c=3",' Точки ');
 $out.=$Fsmall==1? "<a href='$scrpt&small=0'> 1:1 </a> <a href='$scrpt&small=2'> 1:3 </a> " :
       $Fsmall? "<a href='$scrpt&small=0'> 1:1 </a> <a href='$scrpt&small=1'> 1:2 </a> " :
                "<a href='$scrpt&small=1'> 1:2 </a> <a href='$scrpt&small=2'> 1:3 </a> ";
 $out.=&ahref("$scrpt&small=$Fsmall&notitle=1",' Refresh '," target='_blank'");
 $out.=&ahref("$scrpt&b=help",' ВСЕ ');
 $out.=&ahref("$scrpt&c=4",'24 часа '," title='обозначить точки где была авторизация за последние 24 часа'").' ';
 $out.=&ahref("$scrpt&c=5",' ТЕСТ '," title='будут выделены точки до которых логически можно проложить путь'").' ';

 $OUT.=&Table('table1 head width100',"<tr><$td>Карта: </td>$out</td></tr>");
}

sub pBoldLine
{
 my ($x1,$y1,$x2,$y2,$c)=@_;
 $img->line(color=>$c, x1=>$x1,  x2=>$x2,  y1=>$y1,  y2=>$y2,  aa=>1,endp=>0);
 $img->line(color=>$c, x1=>$x1+1,x2=>$x2+1,y1=>$y1,  y2=>$y2,  aa=>1,endp=>0);
 $img->line(color=>$c, x1=>$x1,  x2=>$x2,  y1=>$y1+1,y2=>$y2+1,aa=>1,endp=>0);
}

# ===========================

$i=int $F{i};# номер карты
$i=0 if $i<0 || $i>10;
$Fbx=int $F{bx}; # выделить на карте заданную точку
if ($Fbx)
  {# узнаем на какой карте точка
   $p=&sql_select_line($dbh,"SELECT map FROM points WHERE box=$Fbx LIMIT 1");
   $i=$p? $p->{map} : 0;
  }
$scrpt.="&i=$i";
$Fc=int $F{c}; # характеристики формирования карты (авторизованных, 24 часа и т.д)
$input_c=&input_h('notitle'=>1,'c'=>$Fc,'i'=>$i);

$Fsmall=int $F{small};				# уменьшенная копия? 
$scale=$Fsmall==1? .5 : $Fsmall? .4 : 1;	# масштаб

$MP_boxR=${"MP_boxR$i"}*$scale;			# радиус точки на карте
$MP_size=${"MP_size$i"};			# размер шрифта
#$MP_Cbox0    цвет точки подключения
#$MP_Cbox1    цвет точки подключения если авторизован 1 клиент
#$MP_Cbox2    цвет точки подключения если авторизованы клиенты
#$MP_Cbox3    цвет точки подключения если за ней авторизованы клиенты
#$MP_Cline    цвет линий соединения
#$MP_Coffline цвет отключенных линков
$MP_start=${"MP_start$i"};
$MP_map=${"MP_map$i"};				# путь к карте от корня файловой системы
$MP_dir=~s|/$||;
$MP_dir=~s|^/||;

$b=$F{b};

if ($b eq 'help')
  {
   &pMapMenu;
   $out=join '',map{ &RRow('*','ll',&ahref("$scrpt0&a=$Fa&i=$_",${"MP_name$_"}),&ahref("$scrpt0&a=$Fa&i=$_&small=1",'масштаб 1:2')) }
      grep{ ${"MP_name$_"} ne '' } (0..10);
   $OUT.=$br.&Table('nav2 tbg1',$out);
   &Exit;
  }

if (!$b)
  {# !$b - вывод карты
   &pMapMenu if !$F{notitle};
   # получим список отключенных линков
   $sth=&sql($dbh,"SELECT * FROM cable WHERE type=1 AND blue>0 AND green>0");
   while ($p=$sth->fetchrow_hashref)
     {
      $green=$p->{green};
      $blue=$p->{blue};
      $NOLINK{"$blue-$green"}=1;
      $NOLINK{"$green-$blue"}=1;
     }

   $img=Imager->new();
   $img->read(file=>$MP_map) or &Error("Не могу прочитать графический файл-карту № $i. Сообщение об ошибке модуля Imager:".$br2.$img->errstr());

   $img=$img->scale(scalefactor=>$scale) if $Fsmall;

   $Cbox0=Imager::Color->new($MP_Cbox0);
   $Cbox1=Imager::Color->new($MP_Cbox1);
   $Cbox2=Imager::Color->new($MP_Cbox2);
   $Cbox3=Imager::Color->new($MP_Cbox3);
   $Cline=Imager::Color->new($MP_Cline);
   $Coffline=Imager::Color->new($MP_Coffline);
   $font=Imager::Font->new(file=>$MPfont) or &Error(Imager->errstr.$br."Необходим шрифт для формирования номеров точек на карте. Шрифт <b>$MPfont</b> не найден (либо недоступен www-юзеру)");

   # получим авторизованных клиентов в массив %hop
   if ($Fc!~/^5|6|7$/)
     {# 5 - проверка топологии, 6,7 - потери на пингах
      # для этих функций не нужно знать количество авторизированных клиентов
      if ($Fc==4)
        {# авторизованные за последние сутки
         $u='users';
         $l='login';
         $OUT.=&Center_Mess("Показаны точки, на которых за последние 24 часа были авторизованы клиенты").$br;
         $sth=&sql($dbh,"SELECT $u.hops FROM $l,$u WHERE $u.hops>0 AND $l.mid=$u.id AND ($l.time>".($t-3600*24)." OR $u.auth<>'no') GROUP BY $l.mid");
        }else
        {
         $sth=&sql($dbh,"SELECT hops FROM users WHERE hops>0 AND auth<>'no'");
        }
      $hop{$_->{hops}}++ while ($_=$sth->fetchrow_hashref);
      if ($Fc==1)
        {# общее количество неотключенных физически абонентов
         $sth=&sql($dbh,"SELECT hops FROM users WHERE hops>0 AND cstate<>6");
         $ahop{$_->{hops}}++ while ($_=$sth->fetchrow_hashref);
        }
     }
      elsif ($Fc==6 || $Fc==7)
     {# потери 
      $lping=$Fc==6? 'best_ping' : 'worst_ping';
      $Fc=6;
      # максимальное количество потерь
      $p=&sql_select_line($dbh,"SELECT MAX($lping) AS maxping FROM points WHERE map=$i");
      $max_lost=$p? $p->{maxping} : 0;
     }
      else
     {# Fc=5
      $OUT.=&div('message lft',"Тестовый режим предназначен для проверки есть ли логическая связь с каждой точкой подключения если произвести ".
        "`хождение` от центральной точки на карте<br>Также отмечаются `недоделанные` линки, которые отмечены как идущие от точки в точку, однако не отмеченные в обратном направлении");
     }

   if ($Fc!=3)
     {# Fc=3 - Не рисовать соединения
    
      # Пройдемся по дереву по всем точкам чтоб вычислить какие точки работают как магистральные
      $sth=&sql($dbh,"SELECT * FROM points");
      while ($p=$sth->fetchrow_hashref)
        {
         $box=$p->{box};
         @{$s[$box]}=split/,/,$p->{connected};
        }

      push @m,0;
      push @n,0;
      $u=$MP_start; # стартовая точка
      $j=0;
      $h=0;
      $path='';
      while ($h<500)
        {
         $h++;
         while (defined $s[$u][$j])
           {
            if ($path=~/$s[$u][$j]/) {$j++; next}
            if ($NOLINK{"$u-$s[$u][$j]"}) {$j++; next}
            $path.=" $u ";
            push @m,$u;
            push @n,$j;
            $gg=$u;
            $u=$s[$u][$j];
            $s[$gg][$j]=0;
            $j=0;
           }
         @train=($u, reverse @m);
         #$OUT.=join(' ',@train)."<br>";
         $auth=0;
         # установим отрицательным $hop{точка} если на данной точке нет авторизованных, но ЗА ней авторизованные есть
         foreach $z (@train)
           {
            if ($hop{$z}>0) {$auth+=$hop{$z}; next}
            $hop{$z}-- if $auth && $hop{$z}<=0;
            $hop{$z}-- if $Fc==5; # функция тестирования
           }
         while (!(defined $s[$u][$j]))
           {
            $j=pop @n;
            $u=pop @m;
            last unless $u;
            $path=~s/ $u //;
            $j++;
           }
        }
      # Прорисовка магистралей
      $sth=&sql($dbh,"SELECT * FROM points WHERE map=$i AND x>0 AND y>0");
      while ($p=$sth->fetchrow_hashref)
        {
         $x=$p->{x}*$scale;
         $y=$p->{y}*$scale;
         $box=$p->{box};
         $MPx{$box}=$x;
         $MPy{$box}=$y;
         @boxes=split /,/,$p->{connected};
         foreach $bx (@boxes)
           {
            $er_link{"$box-$bx"}++;
            $er_link{"$bx-$box"}--;
            next unless defined ($MPx{$bx});
            $c=$NOLINK{"$bx-$box"} ? $Coffline : $Cline;
            &pBoldLine($x,$y,$MPx{$bx},$MPy{$bx},$c);
           }
         }
       if ($Fc==5) 
         {# Нарисуем `недоделанные` линки, которые в одном направлении есть, в обратном нет
          foreach $link (keys %er_link)
            {
             next unless $er_link{$link};
             ($bx,$box)=split /-/,$link;
             next if !($MPx{$box} || $MPy{$box}) || !($MPx{$bx} || $MPy{$bx});
             &pBoldLine($MPx{$box},$MPy{$box},$MPx{$bx},$MPy{$bx},$Cbox2);
            }
         }
     }
     
   $sth=&sql($dbh,"SELECT * FROM points WHERE map=$i AND x>0 AND y>0");
   while ($p=$sth->fetchrow_hashref)
     {
      $x=$p->{x}*$scale;
      $y=$p->{y}*$scale;
      $box=$p->{box};
      $net=$p->{net};
      if ($Fc==6)
        {
         $ping=$p->{$lping};
         $txt=$ping<0? '' : !$ping ? '+' : $ping;
         $c=$max_lost? int($ping*255/$max_lost) : 0;
         $c=sprintf "%02X",$c;
         $c=Imager::Color->new($ping<0? $MP_Cbox3 : "#${c}0000");
        }else
        {
         $net=~s|\d+$||;
         $c=$hop{$box}||0;
         $txt=$Fc==1 ? ($c<0 ? '0' : $c).'/'.($ahop{$box}||0) : $Fc==2 ? $net || "??? ($box)" : $box>1000 ? $box % 1000 : $box;
         $c=$Fc==3 ? $Cbox1 : $c>1? $Cbox2 : $c>0? $Cbox1 : $c<0? $Cbox3 : $Cbox0;
        }
      $img->circle(color=>$Cline, r=>$MP_boxR+1, x=>$x, y=>$y, filled=>0) if $box==$Fbx;
      # получим географические размеры строки
      ($left, $top, $right, $bottom)=$img->align_string(x=>$x+1,y=>$y,font=>$font,string=>$txt,color=>'white',size=>$MP_size,halign=>'center',valign=>'center',aa=>0,image=>undef);
      $img->box(color=>$Cline,xmin=>$left-3,ymin=>$top-3,xmax=>$right+1,ymax=>$bottom+1,filled=>1);
      $img->box(color=>$c,xmin=>$left-2,ymin=>$top-2,xmax=>$right,ymax=>$bottom,filled=>1);
      $img->align_string(x=>$x+1, y=>$y, font=>$font, string=>$txt, color=>'white',size=>$MP_size, halign=>'center', valign=>'center',aa=>0);
     }  
   $file.="$MP_map.$t.png"; # имя картинки не должно быть постоянным из-за кеширования браузером :(
   $dir=$file;
   $dir=~s|[^/]+$||;
   opendir(DIR,$dir);
   @files=sort(grep(/\.png$/,readdir(DIR)));
   foreach $f (@files)
     {
      next unless $f=~/\.(\d+)\.png$/;
      # удалим картинку старее 45 секунд (на случай если параллельно кто-то формирует картинку)
      unlink "$dir/$f" if $1<($t-45);
     }

   unless ($img->write(file=>$file)) {&Error("Не могу записать данные в графический файл-карту № <b>$i</b>. Сообщение об ошибке модуля Imager:".$br2.$img->errstr())}
   $file=~s|^.+/||;
   $OUT.="<img id=map ismap src='/$MP_dir/$file'".($Fsmall ? ">" : " border=0 onClick=\"clckmap(this); return false;\">");
$OUT.=<<HEAD;
<script language="JavaScript">
var IE=(document.attachEvent!=null ? true : false);
var mX; var mY; 
function checkS(e){ 
 mX = 0; mY = 0; 
 if (!e) {var e = window.event}
 if (e.pageX || e.pageY){mX = e.pageX; mY = e.pageY;}
   else if (e.clientX || e.clientY){mX = e.clientX; mY = e.clientY;}
} 
function clckmap(obj) {
 var oX = obj.offsetLeft;
 var oY = obj.offsetTop; 
 while(obj.parentNode){
   oX=oX+obj.parentNode.offsetLeft; 
   oY=oY+obj.parentNode.offsetTop; 
   if(obj==document.getElementsByTagName('body')[0]){break} 
      else{obj=obj.parentNode;} 
  }
 var x=mX-oX;//relative X 
 var y=mY-oY;//relative Y 
 if (IE) {
    x = document.body.scrollLeft + x;
    y = document.body.scrollTop + y;
   }
 popupWin = window.open('$scrpt&b=select&notitle=1&x='+x+'&y='+y, 'map', 'location,width=400,height=300,top=0')
 popupWin.focus()
}
</script>
HEAD
   if (!$Fsmall)
     {
      $DOC->{body_tag}.=qq{ onmousemove="checkS(event)"};
     }elsif ($F{notitle})
     {
      $DOC->{header}.='<meta http-equiv="refresh" content="60; url='."$scrpt&small=$Fsmall&notitle=1".'">';
     }
   $SvSign='';   
   &Exit;
  }

$SvSign=''; 
$OUT.=$br2."<div>"; 
$x=int $F{x};
$y=int $F{y};

if ($b eq 'select')
   {
    $OUT.="Координаты: x=$x, y=$y".$br2;
    $x1=$x-$MP_boxR; $x1=1 if $x1<1;
    $y1=$y-$MP_boxR; $y1=1 if $y1<1;
    $sth=&sql($dbh,"SELECT * FROM points WHERE map=$i AND x>$x1 AND x<".($x+$MP_boxR)." AND y>$y1 AND y<".($y+$MP_boxR));
    while ($p=$sth->fetchrow_hashref) 
      {
       $box=$p->{box};
       $id=$p->{id};
       $out=&ahref("$scrpt0&a=listuser&f=9&box=$box",'Клиенты на точке &rarr;'," target='_blank'").$br.
            &ahref("$scrpt0&a=oper&act=points&op=edit&id=$id",'Данные точки &rarr;'," target='_blank'").$br;
       $out.=&ahref("$scrpt&b=set&x=$x&y=$y&box=$box&notitle=1",'Переместить в текущую позицию &rarr;').$br.
             &ahref("$scrpt&b=set&x=0&y=0&box=$box&notitle=1",'Удалить с карты &rarr;') if $pr_edt_topology;
       $OUT.=&div('lft borderblue','В данной позиции находится точка подключения '.&bold($box).$br2.$out).$br2;
      }
    $OUT.="Установить в текущую позицию точку подключения?".$br.
       &form('!'=>1,'b'=>'set','x'=>$x,'y'=>$y,$input_c."Укажите номер точки: ".&input_t('box','',6,6).$br2.&submit_a('OK'));
    &mExit;
   }

if ($b eq 'set')
  {
   !$pr_edt_topology && &Error("Вносить изменения вам запрещено");
   $box=int $F{box};
   $p=&sql_select_line($dbh,"SELECT map,x,y FROM points WHERE box=$box LIMIT 1");
   if (!$p)
     {
      $OUT.=&Printf("[span error] Точка подлючения с номером [bold] не найдена в базе данных.[]",'Внимание.',$box,$go_back);
      &mExit;
     }
   if ($p->{map}!=$i && $p->{x}>0 && $p->{y}>0)
     {
      $OUT.="<span class=error>Внимание.</span> Точка подлючения с номером <b>$box</b> уже обозначена на карте № <b>".$p->{'map'}."</b>. Удалите точку с этой карты";
      &mExit;
     }

   $OUT.="Устанавливаю на карте № <b>$i</b> в координатах x=<b>$x</b>, y=<b>$y</b> точку № <b>$box</b>...".$br2;
   $rows=&sql_do($dbh,"UPDATE points SET map=$i,x=$x,y=$y WHERE box=$box");
   if ($rows==1)
     { 
      $OUT.="<span class=data1>Точка подключения установлена</span>".$br2.
           "<script language=\"JavaScript\">\n"."opener.location.reload()\n"."self.close()\n</script>";
      &mExit;   
     }
   $OUT.="<span class=error>Ошибка при установке точки подключения</span>";
   &mExit;
  }

&mExit;   

1;
