function px_custom_add_theme()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-issabel-theme"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    # Específicos
    local PATH_MAINSTYLECSS="/var/www/html/modules/pbxadmin/themes/default/css"
    local PATH_FAVICON="/var/www/html"
    local PATH_THEMES="/var/www/html/themes"
    
    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    log "$TRACE [${FUNCNAME[0]}] Movendo mainstyle.css"
    rm -rfv $PATH_MAINSTYLECSS/mainstyle.css # Removo o MS atual
    mv -fv $BASE_PATH/mainstyle.css $PATH_MAINSTYLECSS # Movo o MS
    
    log "$TRACE [${FUNCNAME[0]}] Movendo favicon.ico"
    rm -rfv $PATH_FAVICON/favicon.ico # Removo o FAVICON do Issabel
    mv -fv $BASE_PATH/favicon.ico $PATH_FAVICON # Movo o favicon

    log "$TRACE [${FUNCNAME[0]}] Movendo theme/falevox"
    mv -fv $BASE_PATH/falevox $PATH_THEMES # Movo o tema

    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\""
    rm -rf $BASE_PATH # Por limpeza, removo a pasta de tema.
}

function px_custom_add_user_rating()
{
    # Requer setting: LOGIN_MOD_AVALIACAO

    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-avaliacao-atendimento"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    # Específicos
    local DIR_AST_EXTENSIONS="/etc/asterisk"
    local DIR_AST_SOUNDS="/var/lib/asterisk/sounds"
    local DIR_AST_AGI="/var/lib/asterisk/agi-bin"
    local DIR_HTML="/var/www/html"

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    log "$TRACE [${FUNCNAME[0]}] Extensions..."
    mv -fv $BASE_PATH/files/extensions/* $DIR_AST_EXTENSIONS

    log "$TRACE [${FUNCNAME[0]}] Sounds..."
    mv -fv $BASE_PATH/files/sounds/* $DIR_AST_SOUNDS    

    log "$TRACE [${FUNCNAME[0]}] PHP..."
    mv -fv $BASE_PATH/files/php/* $DIR_HTML

    log "$TRACE [${FUNCNAME[0]}] AGI..."
    if [ ${settings[LOGIN_MOD_AVALIACAO]} ]; then
        log "$TRACE [${FUNCNAME[0]}] - COM LOGIN -"
        mv -fv $BASE_PATH/files/agi-login/* $DIR_AST_AGI
    else
        log "$TRACE [${FUNCNAME[0]}] - SEM LOGIN -"
        mv -fv $BASE_PATH/files/agi-nologin/* $DIR_AST_AGI
    fi
    
    # Atualizando a senha pra conexão do db
    sed -i "s/SENHA_DO_DATABASE/$MYSQL_ROOT_PASSWORD/g" $DIR_AST_AGI/phonevox-customs/insert_note.php # agi
    sed -i "s/SENHA_DO_DATABASE/$MYSQL_ROOT_PASSWORD/g" $DIR_HTML/voxura/recording.php # voxura
    sed -i "s/SENHA_DO_DATABASE/$MYSQL_ROOT_PASSWORD/g" $DIR_HTML/voxura/conn.inc.php # voxura
    sed -i "s/SENHA_DO_DATABASE/$MYSQL_ROOT_PASSWORD/g" $DIR_HTML/voxura/config.php # voxura

    # "Registrando" a existência do módulo
    log "$TRACE [${FUNCNAME[0]}] Registrando o módulo..."
    echo -e 'mod-avaliacao-atendimento' | sudo tee -a $DIR_AST_EXTENSIONS/phonevox-customs/modules.conf > /dev/null 2>&1
    
    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\"..."
    rm -rf $BASE_PATH # Por limpeza, removo a pasta do módulo

}

function px_custom_add_backupengine()
{
    # TODO:
    # Mover os ".bkp" para outro lugar, já que estou salvando na pasta que está sendo deletada.

    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-edit-issabel-backup-engine"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    # Específicos
    local ISSABEL_PRIVILEGED="/usr/share/issabel/privileged"
    local BACKUP_MODULE="/var/www/html/modules/backup_restore"

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    log "$TRACE [${FUNCNAME[0]}] backup.tpl"
    cp $BACKUP_MODULE/themes/default/backup.tpl $BASE_PATH/files/backup.tpl.bkp
    mv -fv $BASE_PATH/files/backup.tpl $BACKUP_MODULE/themes/default/backup.tpl

    log "$TRACE [${FUNCNAME[0]}] index.php"
    cp $BACKUP_MODULE/index.php $BASE_PATH/files/index.php.bkp
    mv -fv $BASE_PATH/files/index.php $BACKUP_MODULE/index.php

    log "$TRACE [${FUNCNAME[0]}] backupengine"
    cp $ISSABEL_PRIVILEGED/backupengine $BASE_PATH/files/backupengine.bkp
    chmod 755 $BASE_PATH/files/backupengine
    mv -fv $BASE_PATH/files/backupengine $ISSABEL_PRIVILEGED/backupengine

    log "$TRACE [${FUNCNAME[0]}] pvx-backupengine-extras"
    chmod 755 $BASE_PATH/files/pvx-backupengine-extras
    mv -fv $BASE_PATH/files/pvx-backupengine-extras $ISSABEL_PRIVILEGED/pvx-backupengine-extras

    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\"..."
    rm -rf $BASE_PATH # Por limpeza, removo a pasta do módulo

}

function px_custom_add_siptracer()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-siptracer"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    # Verifica se o script está sendo executado como root
    if [ "$(id -u)" -ne 0 ]; then
        log "$FATAL [${FUNCNAME[0]}] Este script deve ser executado como root."
        return 1
    fi

    # Verifica se o diretório e o arquivo existem
    if [ ! -f "$BASE_PATH/files/siptracer.sh" ]; then
        log "$FATAL [${FUNCNAME[0]}] Arquivo siptracer.sh não encontrado em $BASE_PATH/files."
        return 1
    fi

    # Verifica se /usr/sbin é acessível e permite escrita
    if [ ! -w "/usr/sbin" ]; then
        log "$FATAL [${FUNCNAME[0]}] Sem permissão de escrita em /usr/sbin."
        return 1
    fi

    # Move o arquivo
    mv "$BASE_PATH/files/siptracer.sh" "/usr/sbin/siptracer"
    if [ $? -ne 0 ]; then
        log "$FATAL [${FUNCNAME[0]}] Falha ao mover o arquivo."
        return 1
    fi

    # Define as permissões do arquivo
    chmod 755 "/usr/sbin/siptracer"
    if [ $? -ne 0 ]; then
        log "$FATAL [${FUNCNAME[0]}] Falha ao definir as permissões do arquivo."
        return 1
    fi

    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\"..."
    rm -rf $BASE_PATH # Por limpeza, removo a pasta do módulo

}

function px_custom_add_zabbix()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    warn "Este módulo (add_zabbix) está DESATUALIZADO. Não recomendamos sua utilização!"

    if [ -z ${settings[ZABBIX_SERVER_IP]}]; then
        log "$CRITICAL [${FUNCNAME[0]}] Não há um servidor zabbix configurado. Abortando a instalação do módulo add_zabbix."
        return 1
    fi
    
    (
        # Instalando o Zabbix Agent
        echo "- Baixando repositório..."
        sudo rpm --quiet -Uvhq https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-agent-5.0.22-1.el7.x86_64.rpm

        echo "- Instalando o zabbix-agent..."
        sudo yum -yq install zabbix-agent

        echo "- Iniciando o zabbix-agent"
        sudo systemctl start zabbix-agent

        # Editando as configurações do Zabbix Agent
        echo "<@> Editando as configurações do Zabbix Agent."
        echo "- Server        : ${settings[ZABBIX_SERVER_IP]}"
        sudo sed -i "s/Server=127.0.0.1/Server=${settings[ZABBIX_SERVER_IP]}/g" /etc/zabbix/zabbix_agentd.conf

        echo "- ServerActive  : ${settings[ZABBIX_SERVER_IP]}"
        sudo sed -i "s/ServerActive=127.0.0.1/ServerActive=${settings[ZABBIX_SERVER_IP]}/g" /etc/zabbix/zabbix_agentd.conf

        echo "- Hostname      : ${args[zabbix_hostname]}"
        sudo sed -i "s/Hostname=Zabbix server/Hostname=${args[zabbix_hostname]}/g" /etc/zabbix/zabbix_agentd.conf

        echo "- Metadata      : release (*hardcoded)"
        sudo sed -i "s,# HostMetadataItem=,HostMetadataItem=release,g" /etc/zabbix/zabbix_agentd.conf

        echo "- UserParameter : release,cat /etc/redhat-release (*hardcoded)"
        sudo sed -i "s@# UserParameter=@UserParameter=release,cat /etc/redhat-release@g" /etc/zabbix/zabbix_agentd.conf

        # Ajustes finais
        if ! text_in_file "%zabbix ALL=(ALL) NOPASSWD: ALL" "/etc/sudoers"; then
            echo "<> Adicionado ao grupo sudoer..."
            echo '%zabbix ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers > /dev/null 2>&1 # Adicionando ZABBIX à lista de sudoers
        fi

        echo "<> Reiniciando..."
        sudo systemctl restart zabbix-agent
        echo "<> Ativando..."
        sudo systemctl enable zabbix-agent
    ) &> /dev/null
}

function px_custom_add_firewall()
{
    # Requer setting: FIREWALL_WHITELIST_IPS

    log "$INFO ${FUNCNAME[0]}: starting..."

    if ! grep -q "bash /etc/firewall.sh" "/etc/rc.d/rc.local"; then

        log "$TRACE [${FUNCNAME[0]}] Criando o script do firewall"
        sudo tee /etc/firewall.sh > /dev/null << 'EOF'
#!/bin/bash

iptables -F

while IFS= read -r i; do
    iptables -A INPUT -s "$i" -j ACCEPT
done < /etc/firewall.txt

iptables -A INPUT -p udp --destination-port 4569 -j DROP
iptables -A INPUT -p udp --destination-port 5353 -j DROP
iptables -A INPUT -p tcp --destination-port 20:23 -j DROP
iptables -A INPUT -p tcp --destination-port 80 -j DROP
iptables -A INPUT -p tcp --destination-port 443 -j DROP
iptables -A INPUT -p tcp --destination-port 3306 -j DROP
iptables -A INPUT -p tcp --destination-port 5038 -j DROP
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

service fail2ban restart
EOF

        log "$TRACE [${FUNCNAME[0]}] Inserindo os IPs"
        echo -e "${settings[FIREWALL_WHITELIST_IPS]}" | sudo tee /etc/firewall.txt > /dev/null

        log "$TRACE [${FUNCNAME[0]}] Setando para inicializar com a máquina"
        echo -e "bash /etc/firewall.sh" | sudo tee -a /etc/rc.d/rc.local > /dev/null
    fi
}

function px_custom_add_zoxide()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    log "$TRACE [${FUNCNAME[0]}] Instalando git"
    run sudo yum install -y git 

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório"
    run sudo curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

    log "$TRACE [${FUNCNAME[0]}] Alterando "~/.bashrc"..."
    run sudo echo -e "eval \"\$(zoxide init bash)\"" >> ~/.bashrc
    run sudo echo 'export PATH="$PATH:/root/.local/bin"' >> ~/.bashrc
    run sudo echo 'alias cd="z"' >> ~/.bashrc
    
    log "$TRACE [${FUNCNAME[0]}] Instalando fzf"
    run sudo git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    run sudo ~/.fzf/install --all

    log "$TRACE [${FUNCNAME[0]}] Linkando binários do zoxide e do fzf"
    run sudo ln -s ~/.fzf/bin/fzf /root/.local/bin
    run sudo ln -s /root/.local/bin/zoxide /sbin/zoxide
    run source ~/.bashrc
}

function px_fix_monitoring_class()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-fix-monitoring-class"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    # copiar a monitoring class atual pra {monitoring_class_atual}.bkp-{datetime(Ymd)}
    # mover a monitoring class nova pro local da atual

    if [[ -f "/var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php" ]]; then
        log "$TRACE [${FUNCNAME[0]}] Salvando e substituindo \"paloSantoMonitoring.class.php\""
        cp -v "/var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php" "/var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php.backup-$(date +%Y%m%d%H%M%S%3N)"
        rm -rfv /var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php
        mv -fv $BASE_PATH/files/paloSantoMonitoring.class.php /var/www/html/modules/monitoring/libs/
        chmod 755 /var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php
    else
        # Confirmando se é o .php que não existe, ou se a pasta de libs nem foi gerada. 
        # Se for apenas a ausência do .php, movo sem problemas.
        log "$WARN [${FUNCNAME[0]}] Não foi localizado um \"paloSantoMonitoring.class.php\""
        if [ -d "/var/www/html/modules/monitoring/libs" ]; then
            log "$WARN [${FUNCNAME[0]}] Parece que \"paloSantoMonitoring.class.php\" foi deletado? Movendo o novo ao destino."
            mv -fv $BASE_PATH/files/paloSantoMonitoring.class.php /var/www/html/modules/monitoring/libs/
            chmod 755 /var/www/html/modules/monitoring/libs/paloSantoMonitoring.class.php
        else
            log "$CRITICAL [${FUNCNAME[0]}] \"paloSantoMonitoring.class.php\" não existe!"
        fi
    fi

    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\"..."
    rm -rf $BASE_PATH # Por limpeza, removo a pasta do módulo

}

function px_fix_set_php_timezone()
{
    # Requer setting: PHP_INI_PATH

    log "$INFO ${FUNCNAME[0]}: starting..."

    if [ ${settings[PHP_INI_PATH]} ]; then
        log "$TRACE [${FUNCNAME[0]}] Caminho até \"php.ini\": ${settings[PHP_INI_PATH]}"
        sed -i "/^\[Date\]/a date.timezone = ${args[php_timezone]}" "${settings[PHP_INI_PATH]}" # Adiciono "datetime.timezone = {TIMZONE}" à baixo de [Date]
        sed -i '/^;datetime.timezone =/d' "${settings[PHP_INI_PATH]}" # Removo ";datetime.timezone ="
        apachectl restart
        echo "- Timezone alterada para ${args[php_timezone]}"
    else
        log "$WARN [${FUNCNAME[0]}] Não há conteúdo em settings:PHP_INI_PATH. A timezone do \"php.ini\" não foi alterada!"
    fi

}

function px_fix_dialpattern_wizard()
{
    log "$INFO ${FUNCNAME[0]}: starting..."

    # Repositório
    local REPOSITORY_OWNER="PhonevoxGroupTechnology"
    local REPOSITORY_NAME="px-edit-dialpattern-wizard"
    local REPOSITORY_URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/archive/refs/heads/main.tar.gz"
    local BASE_PATH="$CURRDIR/$REPOSITORY_NAME"

    log "$TRACE [${FUNCNAME[0]}] Puxando o repositório para $BASE_PATH..."
    curl -sL $REPOSITORY_URL | tar xz --transform="s,^[^/]*,$REPOSITORY_NAME,"

    log "$TRACE [${FUNCNAME[0]}] $(colorir "amarelo" "Iniciando o instalador do dp-fix")"
    ./$BASE_PATH/install.sh

    log "$TRACE [${FUNCNAME[0]}] Limpando \"$BASE_PATH\"..."
    rm -rf $BASE_PATH # Por limpeza, removo a pasta do módulo

}
