#NoDeny Config File
$VER_cfg=$VER_chk;

$sadmin='hardpass';
$pw = 'hardpass2';

$Nodeny_dir = '/usr/local/nodeny';
$Log_file = '/usr/local/nodeny/nodeny.log';
$Script_adm = '/cgi-bin/adm/adm.pl';
$Script_stat = '/cgi-bin/stat.pl';
$img_dir = '/i';
$Adm_img_f_dir = '/usr/local/www/apache22/data/i/upload';
$Adm_img_dir = '/i/upload';
$db_server = 'localhost';
$db_server2 = 'localhost';
$db_auth_server = 'localhost';
$db_conn_timeout = 4;
$db_conn_timeout2 = 4;
$db_name = 'bill';
$user = 'bill_www';
$Passwd_Key = 'hardpass3';
@cl_nets = ();
%Collectors = ('1' => '127.0.0.1-Local ipcad');
%l_nets = ('1' => '0.0.0.0/0-*_*');
$MaxSqlLen = 5000;
$Kern_t_to_deny = 150;
$Kern_t_chk_auth = 5;
$Kern_t_traf = 30;
$Kern_t_usr_reload = 60;
$Kern_Dtraf_days_keep = 31;
$Kern_login_days_keep = 31;
$gr = 'грн.';
$kb = 1000;
$m_tarif = 100;
$Plan2_Title = 'Тарифы';
$Plan3_Title = '';
$Plan_got_money_day = 1;
$over_cmp = 1;
$Traf_zero_flush = 0;
%srvs = ();
$Title_net = 'Test Network';
$email_admin = 'bill@microsoft.com';
$smtp_server = '127.0.0.1';
$auto_on = 2;
$Max_list_users = 50;
$Max_list_pays = 40;
$Max_line_chanal = 40;
$Bold_out_traf = 1;
$MakeMailMess = 'Пароль можете получить/изменить ~url(http://xx.xx.xx.xx/cgi-bin/stat.pl?a=110~)(здесь~). Установка и настройка почты описана ~url(http://xx.xx.xx.xx/index.php?showtopic=123~)(здесь~)';
$Block_bonus_pay = 1;
$Show_reload_trf = 0;
$Show_detail_traf = 0;
$How_show_balance = 0;
$Show_limit_balance = 0;
$mess_max_times = 5;
$mess_day = 15;
$MaxSqlLen = 5000;
$MaxCashIp = 1000000;
@Plugins = (
'Spays',
'SSeance',
'Sdaytraf',
'Sdetailtraf',
'Stestnet',
'Smessadm',
'Smail',
'Ssetpacket',
'Scards',
'Slogin',
);
$Block_space_login = 0;
$Auto_ip = 0;
$Multipays_id = 0;
$Multipays_fio = 0;
$Multipays_contract = 0;
$Multipays_street = 0;
$Multipays_house = 0;
$Multipays_room = 0;
$Multipays_telefon = 0;
$Show_PPC = 0;
$Max_paket_sets = 3;
$Sat_t_monitor = 24;
$Sat_t_no_ping = 11;
$card_login = 0;
$card_synbl = 14;
$card_slogin = 8;
$card_abc = 0;
$mail_enable = 0;
$mail_host = 'localhost';
$mail_db = 'mail';
$mail_user = 'mail_nodeny';
$mail_pass = 'hardpass4';
$mail_table = 'users';
$mail_p_email = 'email';
$mail_p_pass = 'passwd';
$mail_p_user = 'name';
$mail_p_dir = 'maildir';
$mail_p_enable = 'enabled';
$mail_check_dir = 1;
$Block_rus_lat = 1;
@jobs = (
 'Подключение',
 'Первоначальная настройка',
 'Ремонт',
 'Настройка'
);
$MPfont = '/usr/local/www/apache22/data/maps/arial.ttf';
$MP_dir = '/maps/';
$MP_Cbox0 = '#000000';
$MP_Cbox1 = '#008000';
$MP_Cbox2 = '#00d000';
$MP_Cbox3 = '#999999';
$MP_Cline = '#0000ff';
$MP_Coffline = '#f0f080';
$MP_graf_clr = '#0088ff';
%Regions = (
 '1' => 'Центр-',
);
%Presets = (
 '1' => 'Основной пресет',
);

%Dopfields_tmpl = (
 '1' => 'Технические данные-',
 '2' => 'Адрес-',
);

$UsrList_cols_template_max = 3;

1;

