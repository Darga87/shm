BEGIN;

INSERT INTO `users` VALUES
(1,0,'admin','0df78fa86a30eca0a918fdd21a94e238133ce7ab',0,NOW(),NULL,0,0,0.00,NULL,NULL,0,1,0,'Admin',0,0.00,NULL,NULL,NULL,NULL)
;

INSERT INTO `servers_groups` VALUES
(1,'Email уведомления','mail','random',NULL),
(2,'VPN','ssh','random',NULL),
(3,'Telegram уведомления','telegram','random',NULL)
;

INSERT INTO `services` VALUES
(1,'VPN (Россия)',0.00,1.00,'vpn-russia','[]',NULL,0,NULL,NULL,1,0,NULL,0,NULL,0)
;

INSERT INTO `events` VALUES
(default,'UserService','User password reset','user_password_reset',1,'{\"category\": \"%\", \"template_id\": \"user_password_reset\"}'),
(default,'UserService','vpn create','create',2,'{\"category\": \"vpn-%\"}'),
(default,'UserService','vpn remove','remove',0,'{\"category\": \"vpn-%\"}'),
(default,'UserService','vpn block','block',0,'{\"category\": \"vpn-%\"}'),
(default,'UserService','vpn activate','activate',0,'{\"category\": \"vpn-%\"}')
;

INSERT INTO `templates` VALUES
('vpn_created','Здравствуйте.\n\nВаш VPN ключ создан.\n\nПосмотреть QR код для подключения можно здесь: \n{{ config.cli.url }}/shm/v1/storage/manage/vpn{{ us.id }}?format=qrcode\n\nСкачать файл ключа можно здесь: \n{{ config.cli.url }}/shm/v1/storage/manage/vpn{{ us.id }}?filename=vpn{{ us.id }}&format=other\n\nУслуга оплачена до: {{ us.expire }}',NULL),
('forecast','Уважаемый {{ user.full_name }}\n\nУведомляем Вас о сроках действия услуг:\n\n{{ FOR item IN user.pays.forecast.items }}\n- Услуга: {{ item.name }}\n  Стоимость: {{ item.total }} руб.\n  Истекает: {{ item.expire }}\n{{ END }}\n\n{{ IF user.pays.forecast.dept }}\nПогашение задолженности: {{ user.pays.forecast.dept }} руб.\n{{ END }}\n\nИтого к оплате: {{ user.pays.forecast.total }} руб.\n\nУслуги, которые не будут оплачены до срока их истечения, будут приостановлены.\n\nПодробную информацию по Вашим услугам Вы можете посмотреть в вашем личном кабинете: {{ config.api.url }}\n\nЭто письмо сформировано автоматически. Если оно попало к Вам по ошибке,\nпожалуйста, сообщите об этом нам: {{ config.mail.from }}',NULL),
('user_password_reset','Уважаемый клиент.\n\nВаш новый пароль: {{ user.set_new_passwd }}\n\nАдрес кабинета: {{ config.cli.url }}','{\"subject\": \"SHM - Восстановление пароля\"}'),
('wg_manager','#!/bin/bash\n\nset -e\n\nEVENT=\"{{ event_name }}\"\nWG_MANAGER=\"/etc/wireguard/wg-manager.sh\"\nSESSION_ID=\"{{ user.gen_session.id }}\"\nAPI_URL=\"{{ config.api.url }}\"\n\n# We need the --fail-with-body option for curl.\n# It has been added since curl 7.76.0, but almost all Linux distributions do not support it yet.\n# If your distribution has an older version of curl, you can use it (just comment CURL_REPO)\nCURL_REPO=\"https://github.com/moparisthebest/static-curl/releases/download/v7.86.0/curl-amd64\"\nCURL=\"/opt/curl/curl-amd64\"\n#CURL=\"curl\"\n\necho \"EVENT=$EVENT\"\n\ncase $EVENT in\n    INIT)\n        SERVER_HOST=\"{{ server.settings.host_name }}\"\n        SERVER_INTERFACE=\"{{ server.settings.host_interface }}\"\n        if [ -z $SERVER_HOST ]; then\n            echo \"ERROR: set variable \'host_name\' to server settings\"\n            exit 1\n        fi\n\n        echo \"Check domain: $API_URL\"\n        HTTP_CODE=$(curl -s -o /dev/null -w \"%{http_code}\" $API_URL/shm/v1/test)\n        if [ $HTTP_CODE -ne \'200\' ]; then\n            echo \"ERROR: incorrect API URL: $API_URL\"\n            echo \"Got status: $HTTP_CODE\"\n            exit 1\n        fi\n\n        echo \"Install required packages\"\n        apt update\n        apt install -y \\\n            iproute2 \\\n            iptables \\\n            wireguard \\\n            wireguard-tools \\\n            qrencode \\\n            wget\n\n        if [[ $CURL_REPO && ! -f $CURL ]]; then\n            echo \"Install modern curl\"\n            mkdir -p /opt/curl\n            cd /opt/curl\n            wget $CURL_REPO\n            chmod 755 $CURL\n        fi\n\n        echo \"Download wg-manager.sh\"\n        cd /etc/wireguard\n        $CURL -s --fail-with-body https://danuk.github.io/wg-manager/wg-manager.sh > $WG_MANAGER\n\n        echo \"Init server\"\n        chmod 700 $WG_MANAGER\n        if [ $SERVER_INTERFACE ]; then\n            $WG_MANAGER -i -s $SERVER_HOST -I $SERVER_INTERFACE\n        else\n            $WG_MANAGER -i -s $SERVER_HOST\n        fi\n        ;;\n    CREATE)\n        echo \"Create new user\"\n        USER_CFG=$($WG_MANAGER -u \"{{ us.id }}\" -c -p)\n\n        echo \"Upload user key to SHM\"\n        $CURL -s --fail-with-body -XPUT \\\n            -H \"session-id: $SESSION_ID\" \\\n            -H \"Content-Type: text/plain\" \\\n            $API_URL/shm/v1/storage/manage/vpn{{ us.id }} \\\n            --data-binary \"$USER_CFG\"\n        echo \"done\"\n        ;;\n    ACTIVATE)\n        echo \"Activate user\"\n        $WG_MANAGER -u \"{{ us.id }}\" -U\n        echo \"done\"\n        ;;\n    BLOCK)\n        echo \"Block user\"\n        $WG_MANAGER -u \"{{ us.id }}\" -L\n        echo \"done\"\n        ;;\n    REMOVE)\n        echo \"Remove user\"\n        $WG_MANAGER -u \"{{ us.id }}\" -d\n\n        echo \"Remove user key from SHM\"\n        $CURL -s --fail-with-body -XDELETE \\\n            -H \"session-id: $SESSION_ID\" \\\n            $API_URL/shm/v1/storage/manage/vpn{{ us.id }}\n        echo \"done\"\n        ;;\n    *)\n        echo \"Unknown event: $EVENT. Exit.\"\n        exit 0\n        ;;\nesac\n\n\n',NULL),
('telegram_bot','<% SWITCH cmd %>\n<% CASE \'USER_NOT_FOUND\' %>\n{\n    \"sendMessage\": {\n        \"text\": \"Для работы с Telegram ботом укажите _Telegram логин_ в профиле личного кабинета.\\n\\n*Telegram логин*: {{ message.chat.username }}\\n\\n*Кабинет пользователя*: {{ config.cli.url }}\"\n    }\n}\n<% CASE [\'/start\', \'/menu\'] %>\n{{ IF cmd == \'/menu\' }}\n{\n    \"deleteMessage\": { \"message_id\": {{ message.message_id }} }\n},\n{{ END }}\n{\n    \"sendMessage\": {\n        \"text\": \"Создавайте и управляйте своими VPN ключами\",\n        \"reply_markup\": {\n            \"inline_keyboard\": [\n                [\n                    {\n                        \"text\": \"💰 Баланс\",\n                        \"callback_data\": \"/balance\"\n                    }\n                ],\n                [\n                    {\n                        \"text\": \"🗝  Ключи\",\n                        \"callback_data\": \"/list\"\n                    }\n                ]\n            ]\n        }\n    }\n}\n<% CASE \'/balance\' %>\n{\n    \"deleteMessage\": { \"message_id\": {{ message.message_id }} }\n},\n{\n    \"sendMessage\": {\n        \"text\": \"💰 *Баланс*: {{ user.balance }}\\n\\nНеобходимо оплатить: * {{ user.pays.forecast.total }}*\",\n        \"reply_markup\" : {\n            \"inline_keyboard\": [\n                [\n                    {\n                        \"text\": \"⇦ Назад\",\n                        \"callback_data\": \"/menu\"\n                    }\n                ]\n            ]\n        }\n    }\n}\n<% CASE \'/list\' %>\n{\n    \"deleteMessage\": { \"message_id\": {{ message.message_id }} }\n},\n{\n    \"sendMessage\": {\n        \"text\": \"🗝  Ключи\",\n        \"reply_markup\" : {\n            \"inline_keyboard\": [\n                {{ FOR item IN ref(user.services.list_for_api( \'category\', \'%\' )) }}\n                {{ SWITCH item.status }}\n                  {{ CASE \'ACTIVE\' }}\n                  {{ status = \'✅\' }}\n                  {{ CASE \'BLOCK\' }}\n                  {{ status = \'❌\' }}\n                  {{ CASE \'NOT PAID\' }}\n                  {{ status = \'💰\' }}\n                  {{ CASE }}\n                  {{ status = \'⏳\' }}\n                {{ END }}\n                [\n                    {\n                        \"text\": \"{{ status }} - {{ item.name }}\",\n                        \"callback_data\": \"/service {{ item.user_service_id }}\"\n                    }\n                ],\n                {{ END }}\n                [\n                    {\n                        \"text\": \"⇦ Назад\",\n                        \"callback_data\": \"/menu\"\n                    }\n                ]\n            ]\n        }\n    }\n}\n<% CASE \'/service\' %>\n{{ us = user.services.list_for_api( \'usi\', args.0 ) }}\n{\n    \"deleteMessage\": { \"message_id\": {{ message.message_id }} }\n},\n{\n    \"sendMessage\": {\n        \"text\": \"*Ключ*: {{ us.name }}\\n\\n*Оплачен до*: {{ us.expire }}\\n\\n*Статус*: {{ us.status }}\",\n        \"reply_markup\" : {\n            \"inline_keyboard\": [\n                {{ IF us.status == \'ACTIVE\' }}\n                [\n                    {\n                        \"text\": \"🗝  Скачать ключ\",\n                        \"callback_data\": \"/download_qr {{ args.0 }}\"\n                    },\n                    {\n                        \"text\": \"👀 Показать QR код\",\n                        \"callback_data\": \"/show_qr {{ args.0 }}\"\n                    }\n                ],\n                {{ END }}\n                [\n                    {\n                        \"text\": \"⇦ Назад\",\n                        \"callback_data\": \"/list\"\n                    }\n                ]\n            ]\n        }\n    }\n}\n<% CASE \'/download_qr\' %>\n{\n    \"uploadDocumentFromStorage\": {\n        \"name\": \"vpn{{ args.0 }}\",\n        \"filename\": \"vpn{{ args.0 }}.txt\"\n    }\n}\n<% CASE \'/show_qr\' %>\n{\n    \"uploadPhotoFromStorage\": {\n        \"name\": \"vpn{{ args.0 }}\",\n        \"format\": \"qr_code_png\"\n    }\n}\n<% END %>\n\n',NULL),
('yoomoney_template','<iframe src=\"https://yoomoney.ru/quickpay/shop-widget?writer=seller&targets=%D0%9E%D0%BF%D0%BB%D0%B0%D1%82%D0%B0%20%D0%BF%D0%BE%20%D0%B4%D0%BE%D0%B3%D0%BE%D0%B2%D0%BE%D1%80%D1%83%20{{ user.id }}&targets-hint=&default-sum=100&label={{ user.id }}&button-text=12&payment-type-choice=on&hint=&successURL=&quickpay=shop&account={{ config.pay_systems.yoomoney.account }}\" width=\"100%\" height=\"198\" frameborder=\"0\" allowtransparency=\"true\" scrolling=\"no\"></iframe>',NULL)
;

INSERT INTO `config` VALUES
("_shm", '{"version":"0.0.3"}'),
('billing','{"type": "Simpler", "partner": {"income_percent": 0}}'),
("company", '{"name":"My Company LTD"}'),
("telegram", '{"token":""}'),
("api",     '{"url":"https://bill.domain.ru"}'),
("cli",     '{"url":"https://bill.domain.ru"}'),
("pay_systems",'{"manual":{"name":"Платеж","show_for_client":false},"yoomoney":{"name":"ЮMoney","account":"000000000000000","secret":"","template_id":"yoomoney_template","show_for_client":true}}'),
("mail",    '{"from":"mail@domain.ru"}')
;

INSERT INTO `spool` (id,status,user_id,event) VALUES
(default,'NEW',1,'{"title":"prolongate services","kind":"Jobs","method":"job_prolongate","period":"600"}'),
(default,'PAUSED',1,'{"title":"cleanup services","kind":"Jobs","method":"job_cleanup","period":"86400","settings":{"days":10}}'),
(default,'PAUSED',1,'{"title":"send forecasts","kind":"Jobs","method":"job_make_forecasts","period":"86400","settings":{"server_gid":1,"template_id": "forecast"}}')
;

COMMIT;

