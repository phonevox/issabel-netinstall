#!/bin/bash

# Variáveis para armazenar os valores padrão
CURRDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTVER=""
MYSQL_ROOT_PASSWORD=""
WEB_ADMIN_PASSWORD=""
DEBUG_MODE=false
FORCE_DEBUG_MODE=false
DRY=false

declare -A args
args+=()

# Obtendo as configurações
source $CURRDIR/settings.sh
source $CURRDIR/utility.sh
source $CURRDIR/px-customizations.sh

# Definindo se foi inicializado no modo FORCE_DEBUG
if [ "$1" = "DEBUG" ]; then
    echo "Enabling FORCE_DEBUG!"
    FORCE_DEBUG_MODE=true
    DEBUG_MODE=true
    shift
fi

# Funções utilitárias

function show_help()
{
    echo "Usage: sudo ${BASH_SOURCE[0]} [options]"
    echo "Ex1: sudo bash ${BASH_SOURCE[0]} --asterisk=\"11\" --quicksetup"
    echo "Ex2: sudo bash ${BASH_SOURCE[0]} --a=\"16\" -s -w --callcenter --community-blocklist --wanpipe-drivers --issabel-licensed-modules --tema --avaliacao --firewall"
    echo ''
    echo 'Options: (Itens marcados com "*" são obrigatórios)'
    echo '  -h, --help                             Exibe este menu de ajuda.'
    echo '* -a, --asterisk, --astver="<11|13|16>"    Define a versão do Asterisk a ser instalada.'
    echo '  -s, --sql, --sql-password              Se presente, exibe um prompt no início para definir a senha root do MySQL desta instalação. Caso omitido, assume a senha padrão no arquivo de configurações.'
    echo '  -w, --web, --web-password              Se presente, exibe um prompt no início para definir a senha admin da interface Web do Issabel desta instalação. Caso omitido, assume a senha padrão no arquivo de configurações.'
    echo '  -z, --zabbix="<STRING>"                [?] Define o Hostname para ser enviado ao servidor Zabbix da Phonevox.'
    echo '  --beta                                 Ativa os repositórios BETA do Issabel. Não recomendado para produção.'
    echo '  -C, --callcenter                       Instala o módulo Callcenter. Recomendado apenas para Asterisk 11.'
    echo '  --community-blocklist                  Ativa a Community Realtime Block List para bloquear ataques SIP de infratores conhecidos. Padrão do Issabel.'
    echo '  --zoxide                               [?] Instala o zoxide e o fzf, altera o "cd" para o zoxide. Para desfazer a alteração do cd, altere seu ~/.bashrc'
    echo '  --wanpipe-drivers                      Instala os drivers Sangoma Wanpipe.'
    echo '  --issabel-licensed-modules             Instala os módulos licenciados da Rede Issabel. (http://issabel.guru)'
    echo '  --tema                                 Instala o tema da Falevox. Deve ser selecionado nas preferências.'
    echo '  --avaliacao                            Instala o módulo de avaliação especial VOXURA. (http://ip_pabx/voxura)'
    echo '  --firewall                             Automaticamente cria as regras de firewall da Phonevox.'
    echo '  --custom-backup-engine                 Instala a modificação/customização da backupengine pela Phonevox.'
    echo '  --fix-monitoring-class                 Instala a customização da classe do módulo de monitoramento do Issabel, para assumir "astspooldir" ao baixar as gravações.'
    echo '  --siptracer                            Instala a aplicação "siptracer", criada pela Phonevox para gerar arquivos .pcap em segundo plano.'
    echo '  --php-timezone="<STRING>"              Define a timezone do PHP.'
    echo '  --quicksetup                           Flag para configuração rápida, automaticamente instalando módulos comuns.'
    echo '  --import="<STRING>"|--no-import        [!] (QUEBRADO) Define se automaticamente faz o upload de um arquivo de backup. Têm prioridade à quicksetup. Obrigatóriamente instala a custom backup engine.'
    echo '  --minimal                              [!] (QUEBRADO) Realiza uma instalação com menos pacotes.'
    echo '  --change-yum-mirrors                   Muda os mirrors do yum de "mirror.centos" para "vault.centos".'
    echo '  --skip-art                             Pula o envio da logo da Phonevox em arte ASCII.'
    echo '  --debug                                Modo debug.'
    echo '  --dry                                  [!] (QUEBRADO) Modo "seco", sem realizar alterações no seu sistema.'
}

function add_arg() 
{
    local ARGUMENT=$1
    local VALUE=$2

    if [ ! ${args[$ARGUMENT]} ]; then
        if $DEBUG_MODE; then
            log "$DEBUG [${FUNCNAME[0]}] $ARGUMENT -> $VALUE"
        fi
        args+=( [$ARGUMENT]=$2 )
        return 0
    else
        if $DEBUG_MODE; then
            log "$WARN [${FUNCNAME[0]}] $ARGUMENT -> $VALUE (Ignoring repeating argument. Current value: ${args[$ARGUMENT]})"
        fi
        return 1
    fi
}

function process_args()
{
    log "$INFO [${FUNCNAME[0]}] Processing arguments..."
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a=*|--astver=*|--asterisk=*)
                add_arg "asterisk" ${1#*=}
            ;;
            
            -w|--set-web-password)
                add_arg "web_password" true
            ;;
            
            -s|--set-sql-password)
                add_arg "sql_password" true
            ;;
            
            -z=*|--zabbix=*)
                add_arg "zabbix" true
                add_arg "zabbix_hostname" "${1#*=}"
            ;;
            
            --zoxide)
                add_arg "zoxide" true
            ;;
            
            --siptracer)
                add_arg "siptracer" true
            ;;
            
            --beta)
                add_arg "enable_beta" true
            ;;
            
            --wanpipe-drivers)
                add_arg "wanpipe_drivers" true
            ;;
            
            --issabel-licensed-modules)
                add_arg "licensed_modules" true
            ;;
            
            --community-blocklist)
                add_arg "community_blocklist" true
            ;;
            
            -C|--callcenter)
                add_arg "callcenter_module" true
            ;;
            
            # Automaticamente aplica o tema.
            --tema)
                NEEDS_SCP=true
                add_arg "falevox_theme" true
            ;; 
            
            # Automaticamente adiciona o módulo de avaliação.
            --avaliacao)
                NEEDS_SCP=true
                add_arg "mod_avaliacao" true
            ;;

            # Automaticamente cria o arquivo de Firewall e joga algumas info basicas.
            --firewall)
                add_arg "firewall" true
            ;;
            
            --custom-backup-engine)
                NEEDS_SCP=true
                add_arg "custom_backupengine" true
            ;;
            
            --fix-monitoring-class)
                NEEDS_SCP=true
                add_arg "fix_monitoring_class" true
            ;;
            
            --php-timezone=*)
                add_arg "php_timezone" "${1#*=}"
            ;;

            # Uma forma rápida de usar o script via CLI sem ter que chamar cada flag manualmente
            --quicksetup)
                NEEDS_SCP=true
                
                # Asterisk Versão 11
                add_arg "asterisk" 11
                
                # Pedirá para digitar as senhas
                add_arg "web_password" true
                add_arg "sql_password" true
                
                # Packages
                add_arg "callcenter_module" true
                add_arg "licensed_modules" true
                add_arg "community_blocklist" true
                
                # Edits
                add_arg "falevox_theme" true
                add_arg "custom_backupengine" true
                
                # Fixs
                add_arg "yum_vault" true # Fix CentOS 7 Repository Mirrors for Yum.
                add_arg "fix_monitoring_class" true
                add_arg "php_timezone" "America/Sao_Paulo"
                #add_arg "firewall" true # Não sei como vou implementar isso sem deixar nossos IPs expostos kk
                
                # Features
                add_arg "siptracer" true

                # Backup para upload automático
                # add_arg "import" "basic"
            ;;
            
            --import=*)
                # Está quebrado e será reescrito, não utilize.
                NEEDS_SCP=true
                IMPORT_OVERWRITE=true
                add_arg "user_import" "${1#*=}"
                add_arg "custom_backupengine" true
            ;;
            
            --no-import)
                IMPORT_OVERWRITE=true
                add_arg "user_import" ""
            ;;
            
            --minimal)
                add_arg "minimal" true # Está quebrado, nao utilize.
            ;;

            --change-yum-mirrors)
                add_arg "yum_vault" true # Fix CENTOS7 repo mirrors
            ;;

            --skip-art)
                add_arg "skip_art" true
            ;;
            
            --debug)
                add_arg "debug" true
            ;;

            --dry)
                DRY=true
            ;;
            
            -h|--help)
                show_help
                exit 0
            ;;
            
            # Argumento desconhecido
            *)
                log "$CRITICAL [${FUNCNAME[0]}] Argumento inválido: $1"
                exit 1
            ;;
        esac
        shift
    done

    # TODO:
    # Dar um resumo de todas flags repassadas que serao usadas nessa instalação!
}

function settings
{
    log "$INFO [${FUNCNAME[0]}] Preparing settings..."
    if ! $DRY; then
        if [ ! "$TERM" = "xterm-256color" ]
        then 
        export NCURSES_NO_UTF8_ACS=1
        fi

        #Shut off SElinux & Disable firewall if running.
        log "$DEBUG [${FUNCNAME[0]}] Inativando SELINUX e desativando o firewall, caso esteja rodando..."
        setenforce 0
        sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config

        # Some distros may already ship with an existing asterisk group. Create it here
        # if the group does not yet exist (with the -f flag).
        log "$DEBUG [${FUNCNAME[0]}] Criando grupo \"asterisk\"..."
        /usr/sbin/groupadd -f -r asterisk

        # At this point the asterisk group must already exist
        if ! grep -q asterisk: /etc/passwd ; then
            log "$DEBUG [${FUNCNAME[0]}] Adicionando usuário \"asterisk\"..."
            /usr/sbin/useradd -r -g asterisk -c "Asterisk PBX" -s /bin/bash -d /var/lib/asterisk asterisk
        fi

        if [ ${args[yum_vault]} ]; then
            log "$DEBUG [${FUNCNAME[0]}] Alterando os mirrors do yum de \"mirror.centos.org\" para \"vault.centos.org\"..."
            sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo      # altera de mirror.centos para vault.centos
            sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo           # seta baseurl http
            sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo       # comenta mirrorlist
        fi

    fi

    # ---- Verificações para import

    # Se tiver um import passado pelo usuário, eu priorizo-o.
    # TODO:
    # Isso aqui não é mais usado, remover
    if [ $IMPORT_OVERWRITE ]; then
        args[import]=${args[user_import]}
    fi

    # Se for ter um import, eu PRECISO da backupengine
    # TODO:
    # Isso aqui não é mais usado, remover
    if [ -n "${args[import]}" ]; then 
        add_arg "custom_backupengine" true
    fi

    # ---- Verificações para senha (deixar por último pois isso prompta o cliente)
    # Verificações de segurança
    if ! [ -n "${args[sql_password]}" ]; then
        if ! [ -n "${settings[DEFAULT_MYSQL_PASSWORD]}" ]; then
            log "$CRITICAL [${FUNCNAME[0]}] A senha padrão do MySQL não está setada."
            log "$DEBUG [${FUNCNAME[0]}] args[sql_password]: ${args[sql_password]}"
            log "$DEBUG [${FUNCNAME[0]}] settings[DEFAULT_MYSQL_PASSWORD]: ${settings[DEFAULT_MYSQL_PASSWORD]}"
            exit 1
        else
            args[sql_password]="${settings[DEFAULT_MYSQL_PASSWORD]}"
        fi
    else
        log "$INFO [${FUNCNAME[0]}] Setando a senha root do MySQL..."
        read -p "Defina a senha root do MySQL: " password
        args[sql_password]="$password"
    fi

    if ! [ -n "${args[web_password]}" ]; then
        if ! [ -n "${settings[DEFAULT_WEB_PASSWORD]}" ]; then
            log "$CRITICAL [${FUNCNAME[0]}] A senha padrão da interface WEB não está setada."
            log "$DEBUG [${FUNCNAME[0]}] args[web_password]: ${args[web_password]}"
            log "$DEBUG [${FUNCNAME[0]}] settings[DEFAULT_WEB_PASSWORD]: ${settings[DEFAULT_WEB_PASSWORD]}"
            exit 1
        else
            args[web_password]="${settings[DEFAULT_WEB_PASSWORD]}"
        fi
    else
        log "$INFO [${FUNCNAME[0]}] Setando a senha admin da interface WEB..."
        read -p "Defina a senha admin da interface WEB: " webpassword
        args[web_password]="$webpassword"
    fi
}

function welcome
{  
    WELCOME_ART=${settings[WELCOME_ASCII_ART]}
    if ! [ ${args[skip_art]} ]; then
        arte "$WELCOME_ART"
    fi
}

function sel_astver
{
    ASTVER=${args[asterisk]}
    if [[ $ASTVER -ne 11 ]] && [[ $ASTVER -ne 13 ]] && [[ $ASTVER -ne 16 ]]; then
        log "$CRITICAL [${FUNCNAME[0]}] Versão inválida do Asterisk."
        exit 1
    fi
}

function additional_packages 
{
    log "$INFO [${FUNCNAME[0]}] Adicionando pacotes extras..."

    # Adicionando os packages a serem instalados, que foram repassados via CLI.
    if ${args[licensed_modules]}; then
        log "$DEBUG [${FUNCNAME[0]}] licensed_modules"
        ADDPKGS="$ADDPKGS issabel-license webconsole issabel-wizard issabel-packet_capture issabel-upnpc issabel-two_factor_auth issabel-theme_designer issabel-network-agent"
    fi

    if ${args[wanpipe_drivers]}; then
        log "$DEBUG [${FUNCNAME[0]}] wanpipe_drivers"
        ADDPKGS="$ADDPKGS wanpipe-utils wanpipe"
    fi

    if ${args[community_blocklist]}; then
        log "$DEBUG [${FUNCNAME[0]}] community_blocklist"
        ADDPKGS="$ADDPKGS issabel-packetbl"
    fi

    if ${args[callcenter_module]}; then
        log "$DEBUG [${FUNCNAME[0]}] callcenter_module"
        ADDPKGS="$ADDPKGS issabel-callcenter"
    fi

    if ${args[siptracer]}; then
        log "$DEBUG [${FUNCNAME[0]}] siptracer"
        ADDPKGS="$ADDPKGS tcpdump"
    fi
}

function add_repos
{

if ! $DRY; then
    log "$INFO [${FUNCNAME[0]}] Adicionando repositórios do Issabel..."
cat > /etc/yum.repos.d/Issabel.repo <<EOF
[issabel-base]
name=Base RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=\$basearch&repo=base
#baseurl=http://repo.issabel.org/issabel/4/base/\$basearch/
gpgcheck=0
enabled=1
gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

[issabel-updates]
name=Updates RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=\$basearch&repo=updates
#baseurl=http://repo.issabel.org/issabel/4/updates/\$basearch/
gpgcheck=0
enabled=1
gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

[issabel-updates-sources]
name=Updates RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=\$basearch&repo=updates
#baseurl=http://repo.issabel.org/issabel/4/updates/SRPMS/
gpgcheck=0
enabled=1
gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

[issabel-beta]
name=Beta RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=\$basearch&repo=beta
baseurl=http://repo.issabel.org/issabel/4/beta/\$basearch/
#gpgcheck=1
enabled=0
#gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

[issabel-extras]
name=Extras RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=\$basearch&repo=extras
#baseurl=http://repo.issabel.org/issabel/4/extras/\$basearch/
gpgcheck=1
enabled=1
gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

EOF

cat > /etc/yum.repos.d/commercial-addons.repo <<EOF
[commercial-addons]
name=Commercial-Addons RPM Repository for Issabel
mirrorlist=http://mirror.issabel.org/?release=4&arch=$basearch&repo=commercial_addons
gpgcheck=1
enabled=1
gpgkey=http://repo.issabel.org/issabel/RPM-GPG-KEY-Issabel

EOF
fi

}

function check_beta_enabled
{
    if [ ${args[enable_beta]} ]; then
        log "$WARN [${FUNCNAME[0]}] Os repositórios BETA do Issabel estão sendo ativados!"
        warn "Repositórios BETA ativados!"
        BETAREPO="--enablerepo=issabel-beta"
    fi
}

function settings_loading_bar
{
    log "$INFO [${FUNCNAME[0]}] Configurando a barra de loading..."
    # SIM EU CRIEI UMA FUNÇÃO SÓ PRA SETAR UMA VARIÁVEL POIS NÃO ENCONTREI OUTRO LUGAR QUE FARIA SENTIDO INICIALIZAR A VARIAVEL, IDAI?
    _EXTRA_PACKAGES=$(echo "$ADDPKGS" | wc -w)
    _INST1_PACKAGES=$(cat /tmp/inst1.txt | wc -l)
    _INST2_PACKAGES=$(cat /tmp/inst2.txt | wc -l)
    _YUM_UPDATES_PACKAGES=$(yum -d 0 list updates | tail -n +2 | wc -l)
    _TOTAL_PACKAGES=$(( $_INST1_PACKAGES + $_INST2_PACKAGES + $_YUM_UPDATES_PACKAGES + $_EXTRA_PACKAGES))
    _INSTALLED_PACKAGES=0

    log "$TRACE [${FUNCNAME[0]}] Inst1  : $_INST1_PACKAGES"
    log "$TRACE [${FUNCNAME[0]}] Inst2  : $_INST2_PACKAGES"
    log "$TRACE [${FUNCNAME[0]}] Update : $_YUM_UPDATES_PACKAGES"
    log "$TRACE [${FUNCNAME[0]}] Extras : $_EXTRA_PACKAGES"
    log "$TRACE [${FUNCNAME[0]}] Total  : $_TOTAL_PACKAGES"

    # Configurações do display da barra de carregamento
    _LOADING_BAR_START="["                   # Caractere delimitando o inicio da barra
    _LOADING_BAR_PROGRESS_CHARACTER="#"      # Caractere significando progresso
    _LOADING_BAR_NO_PROGRESS_CHARACTER=" "   # Caractere significando nenhum progresso
    _LOADING_BAR_END="]"                     # Caractere delimitando a finalização da barra
    _PROGRESS_LIMIT=29                       # Tamanho da barra (em específico, tamanho total do "progresso/sem progresso"
}

function update_os
{
    if ! $DRY; then
        log "$INFO [${FUNCNAME[0]}] Atualizando o sistema..."
        PACKAGES=$(yum -d 0 list updates | tail -n +2 | cut -d' ' -f1) &> /dev/null
        yum_gauge "$PACKAGES" "1/3" "update"
        FIRST_TIME=$total_time
    fi
}

function yum_gauge 
{
    PACKAGES=$1  # Lista de pacotes separada por espaço
    TITLE=$2     # Título da janela
    YUMCMD=$3    # install / update

    # Obtém o número total de pacotes
    n=$(echo $PACKAGES | wc -w)

    # Inicializa contador - aumentará a cada instalação de rpm
    i=0

    # Abre o arquivo de log para escrita (descritor de arquivo 3)
    exec 3>>/tmp/netinstall_errors.txt
    total_time=0
    # Inicia o loop for
    for p in $PACKAGES; do
        ((_INSTALLED_PACKAGES++))

        # Calcula o progresso
        PCT=$((100 * (++i) / n))

        # Obtém o tempo de início da instalação
        install_start_time=$(date +%s)

        # Definindo 
        N_PACOTES_ETAPA=$n # total de pacotes
        N_ATUAL_ETAPA=$i # pacote atual
        PCT_ETAPA=$PCT # porcentagem (relativo ao atual)

        N_PACOTES_TOTAL=$_TOTAL_PACKAGES # total de pacotes (das 3 etapas)
        N_ATUAL_TOTAL=$_INSTALLED_PACKAGES # pacote atual (das 3 etapas)
        PCT_TOTAL=$((100 * $N_ATUAL_TOTAL / $_TOTAL_PACKAGES)) # porcentagem (relativo as 3 etapas)

        # Progresso com carriage-return ( "\r\033[K" ) para não criar novas linhas, e sim atualizar a mesma.
        printf "\r\033[K%s [%d%%] [%s/%s] | %s \"%s\"... " "$(render_loading_bar "$N_ATUAL_TOTAL" "$N_PACOTES_TOTAL" "true")" "$PCT_TOTAL" "$N_ATUAL_TOTAL" "$N_PACOTES_TOTAL" "$YUMCMD" "$p"

        # Verifica se o pacote está instalado ou se é uma atualização
        if ! rpm --quiet -q $p || [ "$YUMCMD" = "update" ]; then
            # Instala o pacote usando yum
            yum $BETAREPO --nogpg -y $YUMCMD $p &>/dev/null
            # printf "OK"
        else
            if rpm --quiet -q $p; then
                log "$WARN [${FUNCNAME[0]}] $p: Já está instalado." >&3
            else
                log "$WARN [${FUNCNAME[0]}] $p: Este comando não é uma atualização." >&3
            fi
        fi

        # Analisando o tempo de download/pra avisar que nao instalou
        install_end_time=$(date +%s)
        install_elapsed_time=$((install_end_time - install_start_time))
        if [ $install_elapsed_time -gt 15 ]; then
            log "$WARN [${FUNCNAME[0]}] $p: Demorou mais de 15 segundos para baixar" >&3
        fi
        total_time=$((total_time + install_elapsed_time))

    done

    printf "\r\033[K"
    log "$INFO [${FUNCNAME[0]}] O tempo total da etapa \"$TITLE\" foi de $total_time segundos"

    # Fecha o arquivo de log ao final
    exec 3>&-
}

function install_packages
{
    if ! $DRY; then
        yum clean all &> /dev/null

        log "$INFO [${FUNCNAME[0]}] Instalando a listagem de pacotes #1..."
        PACKAGES=$(cat /tmp/inst1.txt)
        yum_gauge "$PACKAGES" "2/3" "install"
        SECOND_TIME=$total_time

        log "$INFO [${FUNCNAME[0]}] Instalando a listagem de pacotes #2..."
        PACKAGES=$(cat /tmp/inst2.txt)
        yum_gauge "$PACKAGES $ADDPKGS" "3/3" "install"
        THIRD_TIME=$total_time

        notify "UPDATE: $FIRST_TIME segundos.\nINSTALL #1: $SECOND_TIME segundos.\nINSTALL #2: $THIRD_TIME"
    fi
}

function post_install
{
    log "$INFO [${FUNCNAME[0]}] Realizando ajustes de pós-instalação do Issabel..."
    if ! $DRY; then
        (
        systemctl enable mariadb.service
        systemctl start mariadb
        mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('iSsAbEl.2o17')"
        #Shut off SElinux and Firewall. Be sure to configure it in Issabel!
        setenforce 0
        sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config
        cp -a /etc/sysconfig/iptables /etc/sysconfig/iptables.org-issabel-"$(/bin/date "+%Y-%m-%d-%H-%M-%S")"
        systemctl enable httpd
        systemctl disable firewalld
        systemctl stop firewalld
        firewall-cmd --zone=public --add-port=443/tcp --permanent
        firewall-cmd --reload
        rm -f /etc/issabel.conf
        mysql -piSsAbEl.2o17 -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('')"

        #patch config files
        echo "noload => cdr_mysql.so" >> /mnt/sysimage/etc/asterisk/modules_additional.conf # porque?
        mkdir -p /var/log/asterisk
        mkdir -p /var/log/asterisk/cdr-csv
        mv /etc/asterisk/extensions_custom.conf.sample /etc/asterisk/extensions_custom.conf
        /usr/sbin/amportal chown
        mv -f $CURRDIR/files/manager.conf.sample /etc/asterisk/manager.conf # Jogo o manager.conf "arrumado" pra prod.
        mv -f $CURRDIR/files/queues.conf.sample /etc/asterisk/queues.conf # Jogo o queues.conf "arrumado" pra prod.
        ) &> /dev/null
    fi
}

function set_passwords
{
    log "$INFO [${FUNCNAME[0]}] Setando senhas de acesso..."

    validar_senha_basic () {
        local SENHA="$1"

        # Verificar se a senha tem pelo menos 8 caracteres
        # if [ ${#senha} -lt 8 ]; then
        #     echo "A senha deve ter pelo menos 8 caracteres."
        #     return 1
        # fi

        # Verificar se a senha contém pelo menos uma letra maiúscula
        # if ! [[ "$senha" =~ [A-Z] ]]; then
        #     echo "A senha deve conter pelo menos uma letra maiúscula."
        #     return 1
        # fi

        # Verificar se a senha contém pelo menos uma letra minúscula
        # if ! [[ "$senha" =~ [a-z] ]]; then
        #     echo "A senha deve conter pelo menos uma letra minúscula."
        #     return 1
        # fi

        # Verificar se a senha contém pelo menos um número
        # if ! [[ "$senha" =~ [0-9] ]]; then
        #     echo "A senha deve conter pelo menos um número."
        #     return 1
        # fi

        # Verificar se a senha não contém caracteres inválidos (apenas letras, números e caracteres especiais permitidos)
        if [[ "$senha" =~ [^a-zA-Z0-9[:punct:]] ]]; then
            echo "A senha contém caracteres inválidos."
            return 1
        fi

        # A senha atende a todos os critérios
        return 0
    }


    if validar_senha_basic "${args[sql_password]}" || ! validar_senha_basic "${args[web_password]}"; then
        MYSQL_ROOT_PASSWORD="${args[sql_password]}"
        WEB_ADMIN_PASSWORD="${args[web_password]}"
    else
        warn "testing"
        # TODO:
        # MYSQL_ROOT_PASSWORD = settings mysql default password
        # WEB_ADMIN_PASSWORD = settings web default password
        cleanup
        exit 1
    fi

    if ! $DRY; then
        /usr/bin/issabel-admin-passwords --cli init $MYSQL_ROOT_PASSWORD $WEB_ADMIN_PASSWORD
        #/usr/bin/issabel-admin-passwords --cli change $MYSQL_ROOT_PASSWORD $WEB_ADMIN_PASSWORD # vamos ver se é necessário mesmo.
    fi
}

function phonevox_customizations
{
    #if [ ${args[ARGUMENT]}]; then FUNCTION ; fi

    # Edits / Adds
    log "$INFO [${FUNCNAME[0]}] ===> $(colorir "ciano" "ADIÇÕES") <==="
    if [ ${args[falevox_theme]}]; then px_custom_add_theme ; fi
    if [ ${args[mod_avaliacao]}]; then px_custom_add_user_rating ; fi
    if [ ${args[zabbix]}]; then px_custom_add_zabbix ; fi
    if [ ${args[firewall]}]; then px_custom_add_firewall ; fi
    if [ ${args[custom_backupengine]}]; then px_custom_add_backupengine ; fi
    if [ ${args[siptracer]}]; then px_custom_add_siptracer ; fi
    if [ ${args[zoxide]}]; then px_custom_add_zoxide ; fi

    # Fixes
    log "$INFO [${FUNCNAME[0]}] ===> $(colorir "ciano" "CORREÇÕES") <==="
    if [ ${args[fix_monitoring_class]} ]; then px_fix_monitoring_class; fi
    if [ ${args[php_timezone]} ]; then px_fix_set_php_timezone; fi
}


function install_extras
{
    # Determinando os argumentos extras que foram repassados, e instalando-os
    # if ${args[arg]}; then function; fi

    START_COLOR="rosa" # Cor que será usada para avisar que uma ADIÇÃO/FIX está iniciando

    # Adições
    log "$(colorir "ciano_claro" "# # # Alterações FALEVOX # # #")"
    if ${args[falevox_theme]}; then add_theme; fi
    if ${args[mod_avaliacao]}; then add_mod_avaliacao; fi
    if ${args[zabbix]}; then add_zabbix_host; fi
    if ${args[firewall]}; then add_firewall_script; fi
    if ${args[custom_backupengine]}; then add_custom_backupengine; fi
    if ${args[siptracer]}; then add_siptracer; fi

    if ${args[zoxide]}; then
        echo "args zoxide: ${args[zoxide]}"
        echo "zoxide será instalado"
    fi
    
    # if ${args[zoxide]}; then install_zoxide; fi
    if [ -n ${args[import]} ]; then do_issabel_import; fi                                # Sobe o backup.
    log "$(colorir "ciano_claro" "# # #")\n"

    # Fixes
    log "$(colorir "ciano" "# # # Correções FALEVOX # # #")"
    if ${args[fix_monitoring_class]}; then fix_monitoring_class; fi
    if [ ${args[php_timezone]} ]; then set_php_timezone; fi
    log "$(colorir "ciano_claro" "# # #")\n"
}

function cleanup
{
    if ! $DRY; then
        (
            rm -f /tmp/inst1.txt
            rm -f /tmp/inst2.txt
            /usr/sbin/amportal chown
        ) &> /dev/null
    fi
}

function bye
{
    log "$(colorir "verde" "Instalação finalizada")!"
    if ! $DRY; then
        echo -e "O servidor precisa ser reiniciado para completar a instalação!"
    fi
}

# ========== RUNTIME =============

log "=====> $(colorir "azul" "STARTING") <====="
log "Initializing Netinstall..."

process_args $@
settings # aqui eu tenho que arrumar os vaults do yum caso a flag tenha sido repassada
welcome
sel_astver
additional_packages
generate_files
add_repos
check_beta_enabled
settings_loading_bar

update_os
install_packages

post_install
set_passwords
phonevox_customizations
# fazer as alterações da phonevox nesta etapa:
#firewall, fixes e additions

cleanup

log "=====> $(colorir "verde" "ALL DONE") <====="

log "O servidor será reiniciado. Logue novamente em alguns minutos!"
if ! $DRY; then
    reboot
fi
