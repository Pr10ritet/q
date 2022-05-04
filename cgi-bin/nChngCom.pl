#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

# Переопределение команды. Вызывается из adm.pl

if ($F{name}=~s/^([\-=+])//)
  {
   if ($1 eq '-') {$Fa='oper'; $F{act}='points'; $F{op}='edit'; $F{id}=$F{name}}
   if ($1 eq '=') {$Fa='points'; $F{action}='editsw'; $F{sw}=$F{name}}
   if ($1 eq '+') {$Fa='contacts'; $F{text}=$F{name}}
   $F{name}='';
  }else
  {
   $Fa='listuser';
   $F{f}='n';
  }

1;
