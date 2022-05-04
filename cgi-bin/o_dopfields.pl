#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$VER=50.33;

$d={
	'name'		=> 'дополнительного поля',
	'tbl'		=> 'dopfields',
	'field_id'	=> 'id',
	'priv_show'	=> $pr_main_tunes,
	'priv_edit'	=> $pr_edt_main_tunes,
};

@Parent_types=(
 'клиента',
 'оборудования',
);

@Field_types=(
 'целое',			# 0
 'целое положительное',		# 1
 'вещественное',		# 2
 'вещественное положительное',	# 3
 'строковое однострочное',	# 4
 'строковое многострочное',	# 5
 'да/нет',			# 6
 'привязка к объекту',		# 7
 'выпадающий список',		# 8
 'пароль',			# 9
);

%Fields_flags=(
 'a' => 'допускается пустое значение',
 'b' => 'убирать пробелы в начале',
 'c' => 'убирать пробелы в конце',
 'd' => 'преобразовать к нижнему регистру',
 'e' => 'транслировать в латинские символы',
 'f' => 'убирать все пробелы',
 'q' => 'титульное поле (выводится при поиске)',
 'h' => 'уникальное',
);

sub o_menu
{
 my $menu=&ahref($scrpt,'Список доп.полей');
 $menu.=&ahref("$scrpt&op=new",'Создать новое') if $pr_edt_main_tunes;
 my $tmpls=join '',map{ &ahref("$scrpt&tmpl=$_", (split /-/,$Dopfields_tmpl{$_})[0]) } sort{$a <=> $b} keys %Dopfields_tmpl;
 $menu.=$br.'Шаблоны:'.$br.$tmpls if $tmpls;
 $menu.=$br.&ahref("$scrpt0&a=operations&act=help&theme=dopfields",'Справка');
 return	$menu;
}

sub o_list
{
 $out='';
 $Ftmpl=int $F{tmpl};
 $where=$Ftmpl? "WHERE template_num=$Ftmpl" : '';
 $sth=&sql($dbh,"SELECT * FROM dopfields $where ORDER BY parent_type,template_num,field_name");
 while ($p=$sth->fetchrow_hashref)
 {
    ($id,$template_num,$parent_type,$field_type,$field_name,$comment,$field_flags)=&Get_fields qw(
      id  template_num  parent_type  field_type  field_name  comment  field_flags );
    $h=&Filtr_out($Dopfields_tmpl_name{$template_num});
    $h||=!!$template_num && "<span class=error>$template_num</span>";
    $out.=&RRow('*','ccclcccc',
       $id,
       &Printf('&nbsp;&nbsp;[span disabled]',$Parent_types[$parent_type]||'?'),
       '&nbsp;&nbsp;'.$h,
       &Printf('&nbsp;&nbsp;[filtrfull]',$field_name),
       $Field_types[$field_type] || '<span class=error>неверный тип</span>',
       $field_flags=~/q/? 'Да' : '',
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       ($pr_edt_main_tunes && &ahref("$scrpt&op=del&id=$id",'X'))
    );
 }

 $out or &Error(($Ftmpl? 'В выбранном разделе' : 'В базе данных').' пока не созданы дополнительные поля.'.$br2.&CenterA("$scrpt&op=new&tmpl=$Ftmpl",'Создать &rarr;'),$tend);

 $OUT.=&Table('tbg3 nav3 width100',
   &RRow('head','8',&bold_br('Список дополнительных полей')).
   &RRow('tablebg','cccccccc','id','Данные','Шаблон','Название поля','Тип','Титульное','','Удалить').$out);
}

sub o_new
{
 $template_num=int $F{tmpl};
 $parent_type=$field_type=0;
 $field_name=$field_alias=$comment=$field_flags=$field_template='';
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM dopfields WHERE id=$Fid");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных дополнительного поля номер $Fid",$tend);
 ($template_num,$parent_type,$field_type,$field_name,$field_alias,$comment,$field_flags,$field_template)=&Get_fields qw(
   template_num  parent_type  field_type  field_name  field_alias  comment  field_flags  field_template );
 $field_name=&Filtr($field_name);
 $d->{name}='дополнительного поля '.&commas($field_name);
}

sub o_show
{
 $i=0;
 $parent_types=join '',map {"<option value=$i".($parent_type==$i++ && ' selected').">$_</option>"} @Parent_types;
 $i=0;
 $field_types=join '',map {"<option value=$i".($field_type==$i++ && ' selected').">$_</option>"} @Field_types;
 $tmpl_list=join '',map {"<option value=$_".($template_num==$_ && ' selected').'>'.
    ( (split /-/,$Dopfields_tmpl{$_})[0] ||$Dopfields_tmpl{$_}).'</option>'}  sort {$a <=> $b} keys %Dopfields_tmpl;

 $flags=join $br,map{ "<input type=checkbox name=flag$_ value=1".($field_flags=~/$_/ && ' checked').'> '.$Fields_flags{$_} } sort {$a cmp $b} keys %Fields_flags;
 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     #&RRow('*','ll','Для кого создается',"<select name=parent_type size=1>$parent_types</select>").
     &RRow('*','ll','Шаблон',"<select name=template_num size=1><option value=0>&nbsp;</option>$tmpl_list</select>").
     &RRow('*','ll','Название поля',&input_t('field_name',$field_name,48,127)).
     &RRow('*','ll','Алиас',&input_t('field_alias',$field_alias,48,127)).
     &RRow('*','ll','Тип поля',"<select name=field_type size=1>$field_types</select>").
     &RRow('*','ll','Параметры',$flags).
     &RRow('*','ll','Регулярное выражение',&input_t('field_template',$field_template,48,127)).
     &RRow('*','ll','Комментарий',&input_ta('comment',$comment,30,5)).
     ($pr_edt_main_tunes && &RRow('head','C',&submit_a('Сохранить')))
   )
 );
 $h=0;
 $OUT.=$br2.&MessX(&bold('Внимание!').' устанавливайте регулярное выражение только если разбираетесь в регулярных выражениях.'.$br.
  'В NoDeny не включена проверка в доп.полях регулярных выражениый, поэтому они потенциально опасны.'.$br2.
  'Вы можете использовать предложенные автором:'.$br2.'<ul>'.
  '<li>'.&input_t($h++,'^.+$',15,100).' - разрешены данные длинной не менее одного символа. Т.е. пустое значение вводить не разрешается</li>'.
  '<li>'.&input_t($h++,'^.{5,100}$',15,100).' - разрешены данные длинной от 5 до 100 символов</li>'.
  '<li>'.&input_t($h++,'^\d$',15,100).' - разрешены данные в виде одной цифры, т.е разрешается ввести число от 0 до 9</li>'.
  '<li>'.&input_t($h++,'^-?\d{1,3}$',15,100).' - разрешается ввести число от -999 до 999</li>'.
  '<li>'.&input_t($h++,'^[^!]+$',15,100).' - запрещается вводить восклицательный знак</li>'.
  '<li>'.&input_t($h++,'^[^ ,.]+$',15,100).' - не разрешается использовать пробелы, запятые, точки</li>'.
  '<li>'.&input_t($h++,'!$',15,100).' - значение параметра должно оканчиваться восклицательным знаком</li>'.
  '<li>'.&input_t($h++,'^\d+\.\d+\.\d+\.\d+$',15,100).' - шаблон для ip, не проверяет больше ли 255 октет!</li>'.
  '<li>'.&input_t($h++,'^[A-Za-z]+$',15,100).' - разрешается вводить слово только латинскими буквами, любые другие символы, включая пробелы запрещены</li>'.
  '</ul>',1);
}

sub o_save
{
 $Ffield_name=&Printf('[filtr|trim]',$F{field_name});
 if( $Ffield_name eq '' )
 {
    $OUT.=&MessX(&Printf('[bold] []','Внимание!','Не задано название поля. Устанавливаю в значение `дополнительное поле`'),0,1);
    $Ffield_name='дополнительное поле';
 }
 $Ffield_alias=&Printf('[filtr|trim]',$F{field_alias});
 $Ffield_type=int $F{field_type};
 $Ffield_type=0 if $Ffield_type<0 || !$Field_types[$Ffield_type];
 $Ffield_template=&Filtr_mysql($F{field_template});
 $Ftemplate_num=int $F{template_num};
 $Ftemplate_num=0 if $Ftemplate_num<0 || !defined($Dopfields_tmpl{$Ftemplate_num});
 $Fparent_type=int($Ftemplate_num/100);
 # сортировка нужна для будущего сравнения всей строки!
 $Ffield_flags=join '',map{ $F{"flag$_"} && $_} sort {$a cmp $b} keys %Fields_flags;
 $Fcomment=&Filtr_mysql($F{comment});

 $d->{sql}="field_name='$Ffield_name',field_alias='$Ffield_alias',comment='$Fcomment',field_template='$Ffield_template',".
    "field_flags='$Ffield_flags',parent_type=$Fparent_type,field_type=$Ffield_type,template_num=$Ftemplate_num";

 $h=split /-/,$Dopfields_tmpl{$Ftemplate_num}[0] || $Dopfields_tmpl{$Ftemplate_num} || 'не указан';
 $_=&commas($Ffield_name);
 if( $Fid )
 {  # изменение, а не создание тарифа
    $new_data=$Ffield_name ne $field_name && "Новое название $_";
    $new_data.=($new_data && ', ').($Ffield_alias ne ''? 'алиас: '.&commas($Ffield_alias) : 'алиас удален') if $Ffield_alias ne $field_alias;
    $new_data.=($new_data && ', ')."для кого создан: $Parent_types[$Fparent_type]" if $Fparent_type != $parent_type;
    $new_data.=($new_data && ', ')."шаблон: $h" if $Ftemplate_num != $template_num;
    $new_data.=($new_data && ', ')."тип поля: $Field_types[$Ffield_type]" if $Ffield_type != $field_type;
    $new_data.=($new_data && ', ').'изменено рег.выражение' if &Filtr_mysql($field_template) ne $Ffield_template;
    $new_data.=($new_data && ', ').'изменен комментарий' if &Filtr_mysql($comment) ne $Fcomment;
    $new_data.=($new_data && ', ')."флаги: ".($Ffield_flags || '-') if $Ffield_flags ne $field_flags;
 }else
 {
    $new_data="Название $_, алиас: $Ffield_alias, для $Parent_types[$Fparent_type], тип: $Field_types[$Ffield_type], рег.выражение: $h, флаги: ".($Ffield_flags || '-');
 }
 $d->{new_data}=$new_data;
}

1;
