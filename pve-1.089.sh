#!/bin/bash

# tested: centOS7, centOS8, centOS9, debian10, debian11,
# debian12, Ubuntu 20.04, Ubuntu 22.04, AstraLinux 1.74,
# RedOS 7.3.2, AltLinux 8.2, AltLinux 9.0, AltLinux 10.1

##########################
# общее описание скрипта #
##########################
# скрипт устанавливает pve (python virtual enviroment), набор модулей питона для работы других сервисов

############################################
# критические переменные для быстрой смены #
############################################
# версия питона для установки
# CentOS 7
python_ver_centos="3.9.16"
# Debian дистрибутивы
python_ver_debian="3.9.16"
# Red Hat дистрибутивы
python_ver_rhel="3.9.16"
# AltLinux
python_ver_altlinux="3.9.16"
# адрес pip репозитория DevPI
python_devpi="repo.connect2ai.net"
# заголовок установщика, хеш врутреннего архива, версия и релиз, меняются при сборки пакета
int_service_name="pve"
int_pve_install_dir="/opt/pve"
int_ups_install_dir="/opt/ups/pve"
int_urs_install_dir="/opt/urs/pve"
int_ses_install_dir="/opt/ses/pve"
int_repo_url="https://repo.connect2ai.net/api"
# каталог куда распакуется внутренний архив
int_arch_dir="/tmp/archive"
# каталог системных пакетов созданных через --build
int_arch_pack_dir="$int_arch_dir/packages"

##############
# переменные #
##############

# статус доступа в интернет
internetstatus=0
# тип установки, для оффлайн установки
build_type="install"
# расположение скрипта
actual_path=$(readlink -f "${BASH_SOURCE[0]}")
script_dir=$(dirname "$actual_path")
script_name=$(basename "$actual_path")
# временная папка
temp_dir="$script_dir/temp"
# внешний файл списка модулей pip3
list_pip3_modules_ext="$script_dir/freeze.txt"
# NVIDIA CUDA Toolkit
install_nvcc=()


# список пакетов для скачивания
# CentOS 7
# минимально необходимый набор системных пакетов
packages_system_centos7=("python3" "cmake" "gcc" "gcc-c++" "curl" "wget" "ca-certificates" "git" "patch" "lsyncd" "bzip2" "unzip" "dmidecode")

# остальные пакеты
packages_main_centos7=("python3-pip" "python3-devel" "libsndfile" "python3-wheel" "python3-virtualenv" \
                      "mariadb-devel.x86_64" "python3*-mysql.x86_64" "rustc" "cargo" "openssl" "openssl11" "openssl-devel" "openssl11-devel" "libffi" \
                      "libffi-devel" "zlib" "zlib-devel" "bzip2" "bzip2-devel" "libxml2" "libxml2-devel" \
                      "xmlsec1-openssl" "xmlsec1" "readline" "readline-devel" "sqlite" "sqlite-devel" \
                      "xz" "xz-devel" "ffmpeg" "ffmpeg-devel" "sox" "jq" "checkpolicy" "policycoreutils-python")

# Debian дистрибутивы
# минимально необходимый набор системных пакетов
packages_system_debian=("curl" "wget" "ca-certificates" "git" "patch" "cmake" "build-essential" "apt-transport-https" "gnupg2" "lsyncd" "unzip" "dmidecode")
# остальные пакеты
packages_main_debian=("python3-pip" "python3-dev" "libsndfile1" "python3-wheel" "python3-venv" \
                      "libmariadb-dev" "python3-mysqldb" "rustc" "cargo" "openssl" "libssl-dev" "libncurses-dev" \
                      "libffi-dev" "zlib1g" "zlib1g-dev" "bzip2" "libbz2-dev" "libxml2" "libxml2-dev" \
                      "xmlsec1" "libxmlsec1-dev" "libreadline-dev" "sqlite3" \
                      "libsqlite3-dev" "xz-utils" "lzma" "liblzma-dev" "ffmpeg" "sox" "jq")

# Red Hat дистрибутивы
# минимально необходимый набор системных пакетов
packages_system_rhel=("python3" "cmake" "gcc" "gcc-c++" "curl" "wget" "ca-certificates" "git" "patch" "lsyncd" "unzip" "dmidecode")

# остальные пакеты
packages_main_rhel=("python3-pip" "python3-devel" "libsndfile" "python3-wheel" "python3-virtualenv" \
                    "mariadb-devel.x86_64" "python3*-mysql.x86_64" "rustc" "cargo" "openssl" "openssl-devel" "libffi" \
                    "libffi-devel" "zlib" "zlib-devel" "bzip2" "bzip2-devel" "libxml2" "libxml2-devel" \
                    "xmlsec1-openssl" "xmlsec1" "readline" "readline-devel" "sqlite" "sqlite-devel" \
                    "xz" "xz-devel" "ffmpeg" "ffmpeg-devel" "sox" "jq")

# Altlinux
# минимально необходимый набор системных пакетов
packages_system_altlinux=("python3" "openssl" "curl" "wget" "ca-certificates" "git" "patch" "cmake" "boost-devel" "apt-https" "gnupg2" "lsyncd" "unzip" "dmidecode")

# остальные пакеты
packages_main_altlinux=("rpm-build-python3" "python3-module-pip" "python3-dev" "libsndfile" "python3-module-wheel" \
                        "libmariadb-devel" "python3-module-mysql" "rust" "rust-cargo" "openssl" "libssl-devel" \
                        "libffi-devel" "zlib" "zlib-devel" "bzip2" "bzip2-devel" "libxml2" "libxml2-devel" \
                        "libxmlsec1" "libxmlsec1-devel" "libreadline-devel" "sqlite3" \
                        "libsqlite3-devel" "xz" "liblzma" "liblzma-devel" "glibc-devel-static" "bzip2-devel" \
                        "ffmpeg" "ffprobe" "sox" "jq")

# в массивах модулей используется |, это нужно для фиксации версий зависимостей модулей
# базовый набор модулей для всех установок
modules_pip3_base=("pip" "wheel" "scikit-build|packaging==23.2|setuptools==65.5.1" "setuptools==65.5.1|setuptools_rust|ctranslate2==4.4.0|numpy==1.23.5" "cython" "tomli" "gunicorn|packaging==23.2" \
                   "Flask==2.2.5|flask-restx==1.3.0|Werkzeug==2.3.3" "pydub==0.25.1" "PyJWT" "gevent|youtokentome==1.0.3|setuptools==65.5.1" "requests")

# набор модулей для всех сервисов
modules_pip3_back=(${modules_pip3_base[@]} \
                   "librosa==0.10.0|braceexpand==0.1.7|transformers==4.38.2|faster-whisper|tokenizers==0.15.2|huggingface-hub==0.23.3|numpy==1.23.5|onnxruntime==1.18.1|ctranslate2==4.4.0|hydra-core==1.3.2|packaging==23.2|setuptools==65.5.1" \
                   "inflect==6.0.4|pydantic==1.10.2" "webdataset==0.1.62|pyannote.core==5.0.0|pyannote.database==5.1.0|pyannote.metrics==3.2.1|faiss_cpu==1.8.0|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" \
                   "editdistance==0.6.2" "jiwer==3.0.1" "ipython==8.13.2" "seaborn|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "einops" "wandb==0.18.7|setuptools==65.5.1" "pymorphy2|natasha==1.6.0|razdel" "progressbar2" \
                   "webrtcvad" "h5py|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "ijson" "sacrebleu|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "rouge_score|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "opencc==1.1.5" "pangu" "ipadic" "mecab-python3" \
                   "pybind11" "fasttext==0.9.1|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "sacremoses" "watchdog" "deepfilternet==0.5.6|numpy==1.23.5|packaging==23.2|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" "aiohttp" "python-crfsuite" "elasticsearch" "mysqlclient==2.1.1" "vk_api" \
                   "websockets==11.0.3" "mitmproxy" "bcrypt==4.0.1" "swig==3.0.10" "python-ESL==1.4.18" "websocket==0.2.1" "websocket-client==1.8.0" "typing_extensions==4.4.0")

# дополненый набор модулей для сервисов под CPU
modules_pip3_cpu=(${modules_pip3_back[@]} \
                    "torch==2.3.1+cpu|torchaudio==2.3.1+cpu|torchvision==0.18.1+cpu|torchmetrics==1.0.3|pytorch-lightning==1.9.5|nemo-toolkit==1.20.0|sentence-transformers==2.3.0|triton==2.3.1|Werkzeug==2.3.3|sentencepiece==0.1.99|transformers==4.38.2|huggingface-hub==0.23.3|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1" \
                    "llama-cpp-python==0.3.6|numpy==1.23.5")

# дополненый набор модулей для сервисов под GPU CU11
modules_pip3_cu11=(${modules_pip3_back[@]} \
                    "torch==2.3.1+cu118|torchaudio==2.3.1+cu118|torchvision==0.18.1+cu118|torchmetrics==1.0.3|pytorch-lightning==1.9.5|nemo-toolkit==1.20.0|sentence-transformers==2.3.0|triton==2.3.1|Werkzeug==2.3.3|sentencepiece==0.1.99|transformers==4.38.2|huggingface-hub==0.23.3|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1|onnxruntime-gpu==1.19.2" \
                    "llama-cpp-python-cu==0.3.6|numpy==1.23.5")

# дополненый набор модулей для сервисов под GPU CU12
modules_pip3_cu12=(${modules_pip3_back[@]} \
                    "torch==2.3.1+cu121|torchaudio==2.3.1+cu121|torchvision==0.18.1+cu121|torchmetrics==1.0.3|pytorch-lightning==1.9.5|nemo-toolkit==1.20.0|sentence-transformers==2.3.0|triton==2.3.1|Werkzeug==2.3.3|sentencepiece==0.1.99|transformers==4.38.2|huggingface-hub==0.23.3|numpy==1.23.5|ctranslate2==4.4.0|packaging==23.2|setuptools==65.5.1|onnxruntime-gpu==1.19.2" \
                    "llama-cpp-python-cu==0.3.6|numpy==1.23.5")

# набор модулей индивидуально под сервис
# UPS и RES
modules_pip3_ups=(${modules_pip3_base[@]} "jiwer==3.0.1" "elasticsearch" "mitmproxy" "bcrypt==4.0.1" "typing_extensions==4.4.0")
# URS
modules_pip3_urs=(${modules_pip3_base[@]} "mysqlclient==2.1.1")
# SES
modules_pip3_ses=(${modules_pip3_base[@]} "pymorphy2" "vk_api" "websockets==11.0.3" "swig==3.0.10" "python-ESL==1.4.18" "websocket==0.2.1" "websocket-client==1.8.0")

# все модули, для сборки полного оффлайн инсталятора
modules_pip3_full=("")
for i in ${modules_pip3_cu12[*]} ${modules_pip3_cu11[*]} ${modules_pip3_cpu[*]} ${modules_pip3_ups[*]} ${modules_pip3_urs[*]} ${modules_pip3_ses[*]}; do
  [ $(echo ${modules_pip3_full[@]} | grep -c "$i") -eq 0 ] && modules_pip3_full+=("$i")
done

######################
## функции-процедуры #
######################

#обработчик ошибок, поток ошибок
function echo_error {
  if [ ! -z "$1" ]; then
    deactivate > /dev/null 2>&1
    echo -e "\e[31m> "$1"\e[0m\n" >&2
    clear_temp 2> /dev/null; proxy_configuration unset
    install_repo remlocal > /dev/null; exit 1
  fi
}

#обработчик предупреждений, поток ошибок
function echo_warning {
  if [ ! -z "$1" ]; then
    echo -e "\e[33m> "$1"\e[0m" >&2
  fi
}

#процесс выполнения, стандартный поток
function echo_info {
  if [ ! -z "$1" ]; then
    echo -e "\e[32m> "$1"\e[0m ..."
  fi
}

# определяем версию текущей OS
$(grep -oEi '^(ID|ID_LIKE|VERSION_CODENAME|VERSION_ID)=["A-z0-9.]+' /etc/os-release | sed -e 's/^ID_LIKE/os_like/i' -e 's/^ID/os_id/i' -e 's/^VERSION_CODENAME/os_codename/i' -e 's/^VERSION_ID/os_version/i' | awk '{gsub("\"","",$0);print "export "tolower($0)}')
if [[ $os_codename == "" ]]; then $(grep -oEi '^(NAME|PRETTY_NAME)=[^$]+' /etc/os-release | sed -e 's/\s/_/g' | awk '{gsub("\"","",$0);print "export "tolower($0)}'); os_codename=$(echo $pretty_name | sed "s/$name//" | grep -oE "[a-z]+"); unset name pretty_name; fi
if [[ $os_codename == "" ]]; then os_codename=$os_version; fi
if [[ $os_id == 'centos' && $os_version == '7' ]]; then  os_install=$os_id$os_version; elif [[ -z $os_like || $os_like == "" ]]; then os_install=$os_id; elif [[ ! -z $os_like ]]; then os_install=$(echo $os_like | grep -oEi '^[a-z]+'); unset os_like; fi
# если возникли проблемы с определением параметров
if [[ $os_id == "" || $os_codename == "" || $os_version == "" || $os_install == "" ]]; then echo_error "Ошибка детектирования OS"; fi

# конфигурация подключения к прокси серверу, для онлайн установки
function proxy_configuration {
  # установка если интернет, если не доступен
  if [[ $1 == "set" && $internetstatus -eq 0 ]]; then
    echo_info "Проверка подключения к интернету"
    if [[ -z $(for i in {1..3}; do ping -i 1 -c 5 $python_devpi &> /dev/null || curl -s -o /dev/null -m 5 --connect-timeout 5 "$int_repo_url" 2>/dev/null && echo 1 && break || sleep 0.5; done) ]]; then
      # подгружаем конфигурацию прокси из файла
      setproxy=($(cat $int_install_dir/.proxy 2>/dev/null|head -1|tr "" "\r\n"))
      [ -z $setproxy ] && setproxy=($(cat $int_pve_install_dir/.proxy 2>/dev/null|head -1|tr "" "\r\n"))
      # если не удалось получить данные конфигурации
      if [[ -z $setproxy || ${#setproxy[@]} -eq 2 || ${#setproxy[@]} -gt 3 ]]; then
        echo -e "\e[32m> Настройка HTTP/HTTPS/SOCKS proxy (\e[0mпример: http://example.com:3128; socks5://example.com:1080\e[32m):\e[0m\n"
        read -p "Адрес proxy: " -r iaddress
        read -p "Пользователь: " -r iuser
        read -p "Пароль: " -r ipass; echo
        setproxy=("$iaddress $iuser $ipass")
      fi
      if [[ $(echo ${setproxy[0]} | grep -ciE "^(http|https|socks[4-5]):\/\/([0-9a-zа-я-]+\.){1,}[0-9a-zа-я-]+:[0-9]{2,5}$") -ne 0 ]]; then
        iprotocol=$(echo ${setproxy[0]} | grep -Eo "(http|https|socks[4-5])")
        iaddress=$(echo ${setproxy[0]} | sed -r "s/^[^:]+:\/\///")
        iuserpass=""; [[ ! -z "${setproxy[1]}" && ! -z "${setproxy[2]}" ]] && iuserpass="${setproxy[1]}:${setproxy[2]}@"
        export {http,https,ftp,all}_proxy="${iprotocol}://${iuserpass}${iaddress}"
        export {HTTP,HTTPS,FTP,ALL}_PROXY="${iprotocol}://${iuserpass}${iaddress}"
      else
        echo_error "Некорректный адрес прокси сервера"
      fi
      # что не проксиреуем
      export no_proxy="localhost,*.local,127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
      export NO_PROXY="localhost,*.local,127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

      # проверка, подключение через прокси
      [[ -z $(for i in {1..3}; do curl -s -o /dev/null -m 5 --connect-timeout 5 "$int_repo_url" 2>/dev/null && echo 1 && break || sleep 0.5; done) ]] && echo_error "Не удалось подключится к интернету"
      internetstatus=1
    fi
  # удаляем proxy переменные среды
  elif [ $1 == "unset" ]; then
    unset {http,https,ftp,all}_proxy
    unset {HTTP,HTTPS,FTP,ALL}_PROXY
    unset no_proxy; unset NO_PROXY
  fi
}

# получаем последнию версию библиотеки gcc, cpp, ... доступных в репозитории для пакетного менеджера apt-get
function apt_get_lib {
  # ищем пакеты в базе apt-cache для установки
  for p in "^gcc([-.1-9]+)*(-c\+\+)*$" "^cpp([-.1-9]+)*$" "^libreadline[-.1-9]+$" "^g\+\+$" "^libstdc\+\+[-.1-9]+(dev|devel)(-static)*$"; do
    for i in $(apt-cache search $p | grep -Eo "^[^ ]+"); do
      ver=$(echo $i | grep -Eo "[.0-9]+")
       # добавляем в установку пакеты без версии
      [ -z "$ver" ] && out_nv="$out_nv $i" && continue
      # вычистяем версию текущего пакета
      tmp_ver=$ver; ver=$(echo $ver | sed "s/\.//"); [ "$ver" == "$tmp_ver" ] && ver="${ver}0"
      # если версия новее, начинаем с нуля. если версия совпадает то дописываем
      if [[ -z $old_ver || $ver -gt $old_ver ]]; then tmp_out=$i; elif [[ $ver -eq $old_ver ]]; then tmp_out="$tmp_out $i"; fi; old_ver=$ver
    done
	  # дописываем пакеты по маске к выводу
    unset old_ver; out="$out $tmp_out"
  done
  # выводим список всех пакетов для установки
  echo "$out $out_nv" | sed -e "s/  / /g" -e "s/^ //" -e "s/ $//"
}

# установка репозиториев
function install_repo {
  # онлайн режим установки
  if [[ $1 == "online" || $build_type == "update" || ($build_type == "install" && "$build_os" != "${os_id}-${os_version}") ]]; then
    proxy_configuration set
    echo_info "Настройка репозиториев и фиксация версий пакетов"
    case $os_install in
      centos7)
        # решение проблемы поддержки centOS7 с 01.07.2024
        sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo 2> /dev/null
        sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo 2> /dev/null
        sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
        yum install -y epel-release || echo_error "Ошибка подлючения repo с Epel"
        # пакет основных утилит ставится заранее перед скачиванием пакетов через repotrack
        yum install -y yum-utils || echo_error "Ошибка установки основных утилит"
        # ffmpeg репозиторий, содержащий ffmpeg 3,2 версии.
        yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm 2>&1 || echo_error "Ошибка подлючения repo с FFmpeg"
        # обновление списка пакетов после добавления репы
        yum makecache > /dev/null 2>&1
      ;;
      debian)
        # подключаем репозитория base и external для AstraLinux и обновления списка пакетов
        if [ $os_id == "astra" ]; then
          repo="/etc/apt/sources.list"
          i=$(grep -iEo "^#[ ]*deb.*astralinux.*-base.+" $repo -m1); o=$(echo $i | grep -Eo "[^#]+"); [[ ! -z $i && ! -z $o ]] && sed -i "s|$i|$o|" $repo > /dev/null 2>&1
          i=$(grep -iEo "^#[ ]*deb.*astralinux.*-extended.+" $repo -m1); o=$(echo $i | grep -Eo "[^#]+"); [[ ! -z $i && ! -z $o ]] && sed -i "s|$i|$o|" $repo > /dev/null 2>&1
        fi
        # очищаем локальный кеш пакетов
        rm -rf /var/cache/apt/archives/*.deb &> /dev/null
        # обновление списка пакетов
        apt-get update > /dev/null 2>&1
      ;;
      rhel)
        # пакет основных утилит ставится заранее перед скачиванием пакетов через repotrack
        yum install -y yum-utils || echo_error "Ошибка установки основных утилит"
        # подключения репозирория ffmpeg для CentOS 8 и ContOS 9
        if [ $os_id == "centos" ]; then
          yum install -y epel-release || echo_error "Ошибка подлючения repo с Epel"
          dnf config-manager --set-enabled powertools > /dev/null 2>&1 || dnf config-manager --set-enabled crb > /dev/null 2>&1 || echo_error "Ошибка подлючения repo с FFmpeg"
          dnf install --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$os_version.noarch.rpm -y 2>&1 || echo_error "Ошибка подлючения repo с FFmpeg"
          dnf install --nogpgcheck https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$os_version.noarch.rpm -y 2>&1 || echo_error "Ошибка подлючения repo с FFmpeg"
        fi
        # обновление списка пакетов после добавления репы
        yum makecache > /dev/null 2>&1
      ;;
      altlinux)
        # очищаем локальный кеш пакетов
        rm -rf /var/cache/apt/archives/*.rpm &> /dev/null
        # обновление списка пакетов
        apt-get update > /dev/null 2>&1
      ;;
    esac
  # оффлайн режим установки
  elif [ $1 == "offline" ]; then
    case $os_install in
      centos7)
        # отключаем все репозитории и включаем локальный
        echo_info "Отключаем все репозитории и подключаем локальный $int_arch_pack_dir"
        repo=$(grep -rliE "^[ #]*baseurl.+" /etc/yum.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^|###pve###|g" $o > /dev/null 2>&1; done
        repo=$(grep -rliE "^[ #]*baseurl.+" /etc/distro.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^|###pve###|g" $o > /dev/null 2>&1; done
        echo "[PVE]
name = PVE
baseurl = file://$int_arch_pack_dir/$os_codename
enabled = 1
gpgcheck = 0" > /etc/yum.repos.d/pve.repo
        # обновление списка пакетов
        yum makecache > /dev/null 2>&1
      ;;
      debian)
        # отключаем все репозитории и включаем локальный
        echo_info "Отключаем все репозитории и подключаем локальный $int_arch_pack_dir"
        repo=$(grep -rliE "^[ ]*deb.+" /etc/apt/sources.list* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^[ ]*deb|###pve###deb|" $o > /dev/null 2>&1; done
        echo "deb [arch=$(dpkg --print-architecture) trusted=yes] file://$int_arch_pack_dir $os_codename pve" > /etc/apt/sources.list.d/pve.list || echo_error "Ошибка настройки репозитория"
        # очищаем локальный кеш пакетов
        rm -rf /var/cache/apt/archives/*.deb &> /dev/null
        # обновление списка пакетов
        apt-get update > /dev/null 2>&1
      ;;
      rhel)
        # отключаем все репозитории и включаем локальный
        echo_info "Отключаем все репозитории и подключаем локальный $int_arch_pack_dir"
        repo=$(grep -rliE "^[ #]*baseurl.+" /etc/yum.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^|###pve###|g" $o > /dev/null 2>&1; done
        repo=$(grep -rliE "^[ #]*baseurl.+" /etc/distro.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^|###pve###|g" $o > /dev/null 2>&1; done
        echo "[PVE]
name = PVE
baseurl = file://$int_arch_pack_dir/$os_codename
enabled = 1
gpgcheck = 0" > /etc/yum.repos.d/pve.repo
        # обновление списка пакетов
        yum makecache > /dev/null 2>&1
      ;;
      altlinux)
        # отключаем все репозитории и включаем локальный
        echo_info "Отключаем все репозитории и подключаем локальный $int_arch_pack_dir"
        repo=$(grep -rliE "^[ ]*rpm.+" /etc/apt/sources.list* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^[ ]*rpm|###pve###rpm|" $o > /dev/null 2>&1; done
        echo "rpm file://$int_arch_pack_dir $os_codename pve" > /etc/apt/sources.list.d/pve.list || echo_error "Ошибка настройки репозитория"
        # очищаем локальный кеш пакетов
        rm -rf /var/cache/apt/archives/*.rpm &> /dev/null
        # обновление списка пакетов
        apt-get update > /dev/null 2>&1
      ;;
    esac
  # удаление локального
  elif [ $1 == "remlocal" ]; then
    case $os_install in
      centos7)
        echo_info "Настройка списка репозиториев в исходное состояние"
        repo=$(grep -rliE "^###pve###$" /etc/yum.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i -r "s|^(###pve###)+||" $o > /dev/null 2>&1; done
        repo=$(grep -rliE "^###pve###$" /etc/distro.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i -r "s|^(###pve###)+||" $o > /dev/null 2>&1; done
        rm -f /etc/yum.repos.d/pve.repo &> /dev/null
      ;;
      debian)
        # включаем все репозитории и отключаем локальный
        echo_info "Настройка списка репозиториев в исходное состояние"
        repo=$(grep -rliE "^###pve###deb.+" /etc/apt/sources.list* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^###pve###deb|deb|" $o > /dev/null 2>&1; done
        rm -f /etc/apt/sources.list.d/pve.list &> /dev/null
      ;;
      rhel)
        echo_info "Настройка списка репозиториев в исходное состояние"
        repo=$(grep -rliE "^###pve###$" /etc/yum.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i -r "s|^(###pve###)+||" $o > /dev/null 2>&1; done
        repo=$(grep -rliE "^###pve###$" /etc/distro.repos.d/* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i -r "s|^(###pve###)+||" $o > /dev/null 2>&1; done
        rm -f /etc/yum.repos.d/pve.repo &> /dev/null
      ;;
      altlinux)
        # включаем все репозитории и отключаем локальный
        echo_info "Настройка списка репозиториев в исходное состояние"
        repo=$(grep -rliE "^###pve###rpm.+" /etc/apt/sources.list* 2>/dev/null); [[ ! -z $repo ]] && for o in $repo; do sed -i "s|^###pve###rpm|rpm|" $o > /dev/null 2>&1; done
        rm -f /etc/apt/sources.list.d/pve.list &> /dev/null
      ;;
    esac
  fi
}

# проверка драйвера на GPU
function check_installed_gpu {
  if [ ! -z "$1" ]; then
    # проверка наличия карты в системе
    echo_info "Проверка наличия видеокарт(ы) NVIDIA в системе"
    lGPU=$(lspci 2> /dev/null | grep -iEo ".+(3d|vga).+controller.+nvidia.+")
    [[ -z "$lGPU" ]] && echo_error "Не найдено ни одной видеокарты NVIDIA в системе" || echo $lGPU
    # проверка корректности установленного драйвера
    echo_info "Проверка корректности установленного драйвера NVIDIA"
    [[ $(lsmod 2> /dev/null | grep -ic nvidia) -eq 0 ]] && echo_error "Модуль ядра видео драйвера NVIDIA не загружен"
    cat /proc/driver/nvidia/version 2>/dev/null
    echo_info "Проверка корректности инициализации видеокарт(ы) драйвером"
    dGPU=$(ls /proc/driver/nvidia/gpus 2> /dev/null)
    [[ -z "$dGPU" ]] && echo_error "Драйвер NVIDIA не инициализировал ни одной видеокарты"
    for d in $dGPU; do cat "/proc/driver/nvidia/gpus/$d/information" 2> /dev/null && echo; done
    # проверка версии CUDA Toolkit
    echo_info "Проверка установки CUDA Toolkit"
    iCU=$(echo $1 | tr -d cu 2>/dev/null)
    mapfile -t install_nvcc < <(find /usr -path '*cuda*' -regex '.*/cuda-[0-9.]*' -type d 2>/dev/null)
    # проверка корректности установки CUDA Toolkit
    [[ ${#install_nvcc[@]} -gt 1 ]] && for s in "${install_nvcc[@]}"; do tree -L 1 --noreport 2>/dev/null $s && echo || echo $s; done && echo_error "Найдено несколько версий CUDA Toolkit. Необходимо оставить одну"
    [[ ${#install_nvcc[@]} -eq 0 || -z "$(${install_nvcc[0]}/bin/nvcc --version 2>/dev/null)" ]] && echo_error "CUDA Toolkit не установлен"
    basename ${install_nvcc[0]} 2>/dev/null | awk -F'-' '{print "CUDA Toolkit: v"$NF}' 2>/dev/null
    # определяем версию CUDA Toolkit (должен быть <= версии CUDA, поддерживаемой драйвером)
    vCUDAt=$(grep -iEo "CUDA_VERSION[ ]*[0-9.]+" -m1 $(find ${install_nvcc[0]} -iname cuda.h -type f 2>/dev/null | head -1 2>/dev/null) 2>/dev/null | sed -e 's/CUDA_VERSION\s*//i' -e 's/\.//g' 2>/dev/null)
    # сравнение версии CUDA Toolkit с ключем установки
    [[ -z "$iCU" || (! -z "$vCUDAt" && $iCU -ne $(($vCUDAt / 1000))) ]] && echo_error "Версия CUDA Toolkit, в системе, не совпадает с ключом установки $1"
    # сравнение версии CUDA Toolkit с версией, поддерживаемой драйвером
    vCUDAd=($(awk 'BEGIN {IGNORECASE=1} {if (FILENAME != "") {if (match($0, /release[ ]*[0-9.]+/)) {ver=substr($0, RSTART, RLENGTH); gsub(/release[ ]*/, "", ver); gsub(/\./, " ", ver); print ver }}}' $(find /usr -iname libnvidia-ptxjitcompiler.so.? 2>/dev/null) 2>/dev/null))
    if [[ ! -z "$vCUDAd" && ${#vCUDAd[@]} -gt 0 ]]; then
      [ ${#vCUDAd[@]} -eq 1 ] && vCUDAd=(${vCUDAd[@]} 0)
      echo "CUDA Driver: v"$(echo ${vCUDAd[@]} | tr ' ' '.')
      [[ ! -z "$vCUDAt" && $vCUDAt -gt $(($((${vCUDAd[0]} * 1000)) + $((${vCUDAd[1]} * 10)))) ]] && echo_error "Версия CUDA Toolkit должна быть меньше или равна версии, поддерживаемой драйвером"
    fi
    echo_info "Проверка установки CUDnn"
    # определяем установлен ли CUDnn
    [[ -z "$(find /usr -iname cudnn*.h)" ]] && echo_warning "CUDnn не установлен" || echo "ОК"
  fi
}

# установка системных пакетов
function install_pac {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  case $os_install in
    centos7)
      # проверка на "битые" и прерванные установки
      yum-complete-transaction --cleanup-only 2> /dev/null
      # создаем деррикторию репозитория, куда будем выгружать пакеты
      if [ ! -z $2 ]; then
        mkdir -p $int_arch_pack_dir/$os_codename/Packages &> /dev/null
        [ ! -d "$int_arch_pack_dir/$os_codename/Packages" ] && echo_error "$int_arch_pack_dir/$os_codename/Packages нет такой директории"
      fi
      # установка основных системных пакетов
      # if [ "$1" == "system" ]; then
      #   for (( i=0; i<"${#packages_system_centos7[@]}"; i++ )); do
      #     echo_info "Установка ${packages_system_centos7[i]}"
      #     if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_centos7[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_centos7[i]} || echo_error "Ошибка загрузки  ${packages_system_centos7[i]}"; fi
      #     if [ ! -z $2 ]; then for p in $(repoquery --suggests ${packages_system_centos7[i]} |xargs -r); do yumdownloader --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" $p || echo_error "Ошибка загрузки ${packages_system_centos7[i]}"; done; fi
      #     yum install -y ${packages_system_centos7[i]} || yum update -y ${packages_system_centos7[i]} || echo_error "Ошибка установки ${packages_system_centos7[i]}"
      #   done
      if [ "$1" == "system" ]; then
        for (( i=0; i<"${#packages_system_centos7[@]}"; i++ )); do
          echo_info "Установка ${packages_system_centos7[i]}"
          if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --alldeps --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_centos7[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_centos7[i]} || echo_error "Ошибка загрузки ${packages_system_centos7[i]}"; fi
          yum install -y ${packages_system_centos7[i]} || yum reinstall -y ${packages_system_centos7[i]} || echo_error "Ошибка установки ${packages_system_centos7[i]}"
        done
      # установка остальных пакетов
      # elif [ "$1" == "main" ]; then
      #   for (( i=0; i<"${#packages_main_centos7[@]}"; i++ )); do
      #     echo_info "Установка ${packages_main_centos7[i]}"
      #     if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_centos7[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_centos7[i]} || echo_error "Ошибка загрузки  ${packages_main_centos7[i]}"; fi
      #     if [ ! -z $2 ]; then for p in $(repoquery --suggests ${packages_main_centos7[i]} |xargs -r); do yumdownloader --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" $p || echo_error "Ошибка загрузки ${packages_main_centos7[i]}"; done; fi
      #     yum install -y ${packages_main_centos7[i]} || yum update -y ${packages_main_centos7[i]} || echo_error "Ошибка установки ${packages_main_centos7[i]}"
      #   done
      # fi
      elif [ "$1" == "main" ]; then
        for (( i=0; i<"${#packages_main_centos7[@]}"; i++ )); do
          echo_info "Установка ${packages_main_centos7[i]}"
          if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --alldeps --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_centos7[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_centos7[i]} || echo_error "Ошибка загрузки ${packages_main_centos7[i]}"; fi
          yum install -y ${packages_main_centos7[i]} || yum reinstall -y ${packages_main_centos7[i]} || echo_error "Ошибка установки ${packages_main_centos7[i]}"
        done
      fi
    ;;
    debian)
      # установка основных системных пакетов
      if [ "$1" == "system" ]; then
        # ставим последнию версию c/c++ компилятора
        app_get_lib_tmp=$(apt_get_lib)
        echo_info "Установка последней версии c/c++ компилятора"
        if [ ! -z $2 ]; then DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef --reinstall -d -y $app_get_lib_tmp || echo_error "Ошибка загрузки $app_get_lib_tmp"; fi
        DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef -y $app_get_lib_tmp || echo_error "Ошибка установки $app_get_lib_tmp"
        for (( i=0; i<"${#packages_system_debian[@]}"; i++ )); do
          echo_info "Установка ${packages_system_debian[i]}"
          if [ ! -z $2 ]; then DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef --reinstall -d -y ${packages_system_debian[i]} || echo_error "Ошибка загрузки ${packages_system_debian[i]}"; fi
          DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef -y ${packages_system_debian[i]} || \
          DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef -y ${packages_system_debian[i]} --reinstall || echo_error "Ошибка установки ${packages_system_debian[i]}"
        done
      # установка остальных пакетов
      elif [ "$1" == "main" ]; then
        for (( i=0; i<"${#packages_main_debian[@]}"; i++ )); do
          echo_info "Установка ${packages_main_debian[i]}"
          if [ ! -z $2 ]; then DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef --reinstall -d -y ${packages_main_debian[i]} || echo_error "Ошибка загрузки ${packages_main_debian[i]}"; fi
          DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef -y ${packages_main_debian[i]} || \
          DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Options::=--force-confdef -y ${packages_main_debian[i]} --reinstall || echo_error "Ошибка установки ${packages_main_debian[i]}"
        done
      fi
    ;;
    rhel)
      # проверка на "битые" и прерванные установки
      yum-complete-transaction --cleanup-only 2> /dev/null
      # создаем деррикторию репозитория, куда будем выгружать пакеты
      if [ ! -z $2 ]; then
        mkdir -p $int_arch_pack_dir/$os_codename/Packages &> /dev/null
        [ ! -d "$int_arch_pack_dir/$os_codename/Packages" ] && echo_error "$int_arch_pack_dir/$os_codename/Packages нет такой директории"
      fi
      # установка основных системных пакетов
      # if [ "$1" == "system" ]; then
      #   for (( i=0; i<"${#packages_system_rhel[@]}"; i++ )); do
      #     echo_info "Установка ${packages_system_rhel[i]}"
      #     if [ ! -z $2 ]; then yumdownloader --downloadonly --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_rhel[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_rhel[i]} || echo_error "Ошибка загрузки ${packages_system_rhel[i]}"; fi
      #     if [ ! -z $2 ]; then for p in $(repoquery -R ${packages_system_rhel[i]} |xargs -r); do yumdownloader --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" $p || echo_error "Ошибка загрузки ${packages_system_rhel[i]}"; done; fi
      #     yum install -y ${packages_system_rhel[i]} || yum update -y ${packages_system_rhel[i]} || echo_error "Ошибка установки ${packages_system_rhel[i]}"
      #   done
      if [ "$1" == "system" ]; then
        for (( i=0; i<"${#packages_system_rhel[@]}"; i++ )); do
          echo_info "Установка ${packages_system_rhel[i]}"
          if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --alldeps --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_rhel[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_system_rhel[i]} || echo_error "Ошибка загрузки ${packages_system_rhel[i]}"; fi
          yum install --allowerasing -y ${packages_system_rhel[i]} || yum reinstall --allowerasing -y ${packages_system_rhel[i]} || echo_error "Ошибка установки ${packages_system_rhel[i]}"
        done
      # установка остальных пакетов
      # elif [ "$1" == "main" ]; then
      #   for (( i=0; i<"${#packages_main_rhel[@]}"; i++ )); do
      #     echo_info "Установка ${packages_main_rhel[i]}"
      #     if [ ! -z $2 ]; then yumdownloader --downloadonly --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_rhel[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_rhel[i]} || echo_error "Ошибка загрузки ${packages_main_rhel[i]}"; fi
      #     if [ ! -z $2 ]; then for p in $(repoquery -R ${packages_main_rhel[i]} |xargs -r); do yumdownloader --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" --destdir "$int_arch_pack_dir/$os_codename/Packages/" $p || echo_error "Ошибка загрузки ${packages_main_rhel[i]}"; done; fi
      #     # --allowerasing
      #     yum install -y ${packages_main_rhel[i]} || yum update -y ${packages_main_rhel[i]} || echo_error "Ошибка установки  ${packages_main_rhel[i]}"
      #   done
      # fi
      elif [ "$1" == "main" ]; then
        for (( i=0; i<"${#packages_main_rhel[@]}"; i++ )); do
          echo_info "Установка ${packages_main_rhel[i]}"
          if [ ! -z $2 ]; then yumdownloader --downloadonly --resolve --alldeps --downloaddir "$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_rhel[i]} || yum install -y --downloadonly --downloaddir="$int_arch_pack_dir/$os_codename/Packages/" ${packages_main_rhel[i]} || echo_error "Ошибка загрузки ${packages_main_rhel[i]}"; fi
          yum install --allowerasing -y ${packages_main_rhel[i]} || yum reinstall --allowerasing -y ${packages_main_rhel[i]} || echo_error "Ошибка установки  ${packages_main_rhel[i]}"
        done
      fi
    ;;
    altlinux)
      # установка основных системных пакетов
      if [ "$1" == "system" ]; then
        # ставим последнию версию c/c++ компилятора
        app_get_lib_tmp=$(apt_get_lib)
        echo_info "Установка последней версии c/c++ компилятора"
        if [ ! -z $2 ]; then apt-get install --reinstall -d -y $app_get_lib_tmp || echo_error "Ошибка загрузки $app_get_lib_tmp"; fi
        apt-get install -y $app_get_lib_tmp || echo_error "Ошибка установки $app_get_lib_tmp"
        for (( i=0; i<"${#packages_system_altlinux[@]}"; i++ )); do
          echo_info "Установка ${packages_system_altlinux[i]}"
          if [ ! -z $2 ]; then apt-get install --reinstall -d -y ${packages_system_altlinux[i]} || echo_error "Ошибка загрузки ${packages_system_altlinux[i]}"; fi
          apt-get install -y ${packages_system_altlinux[i]} || apt-get install -y ${packages_system_altlinux[i]} --reinstall || echo_error "Ошибка установки ${packages_system_altlinux[i]}"
        done
      # установка остальных пакетов
      elif [ "$1" == "main" ]; then
        for (( i=0; i<"${#packages_main_altlinux[@]}"; i++ )); do
          echo_info "Установка ${packages_main_altlinux[i]}"
          if [ ! -z $2 ]; then apt-get install --reinstall -d -y ${packages_main_altlinux[i]} || echo_error "Ошибка загрузки ${packages_main_altlinux[i]}"; fi
          apt-get install -y ${packages_main_altlinux[i]} || apt-get install -y ${packages_main_altlinux[i]} --reinstall || echo_error "Ошибка установки ${packages_main_altlinux[i]}"
        done
      fi
    ;;
  esac
}

# создание временных директорий
function create_temp_dirs {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  if [ ! -d $int_arch_dir ]; then mkdir $int_arch_dir; fi
  if [ ! -d $int_arch_dir/packages ]; then mkdir $int_arch_dir/packages; fi
}

# работа с файлом переменных для офлайн установки
function offline_env {
  cd $int_arch_dir 2> /dev/null || echo_error "$int_arch_dir нет такой директории"
  # если файл с переменными не сущетвует
  # сохраняем
  if [ ! -f $int_arch_dir/env ]; then
    echo_info "Создание внешнего файла конфигурации установки"
    for i in $@; do
      echo $i >> $int_arch_dir/env 2> /dev/null || echo_error "Ошибка создания внешнего файла конфигурации установки"
    done
  # иначе подгружаем
  else
    echo_info "Подключение внешнего файла конфигурации установки"
    . $int_arch_dir/env 2> /dev/null || echo_error "Ошибка подключения внешнего файла конфигурации установки"
    [[ -z $int_pve_install_dir || -z $build_modules || -z $build_type ]] && echo_error "Ошибка конфигурации установки"
  fi
}

# загрузка ffmpeg 5.1 для установки поверх 3.2. Актуально только для центос7
function download_ffmpeg {
  if [ $1 == "online" ]; then
    # в онлайн режиме загружаем архив просто рядом со скриптом
    cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
    case $os_install in
      centos7)
        echo_info "Загрузка bin FFmpeg 5.1.2"
        if ! $(for i in {1..5}; do curl -C - -L --connect-timeout 15 -# --output $script_dir/ffmpeg-5.1.2.tar.bz2 https://github.com/q3aql/ffmpeg-builds/releases/download/v5.1.2/ffmpeg-5.1.2-linux-gnu-64bit-build.tar.bz2 && echo true && break || echo false; done | tail -1); then
          echo_error "Ошибка загрузки bin FFmpeg 5.1.2"
        fi
      ;;
      debian)
      ;;
      rhel)
      ;;
      altlinux)
      ;;
    esac
  elif [ $1 == "offline" ]; then
    # для сборки оффлайн инсталлера загружаем архив в папку archive
    cd $int_arch_dir 2> /dev/null || echo_error "$int_arch_dir нет такой директории"
    echo_info "Загрузка bin FFmpeg 5.1.2"
    if ! $(for i in {1..5}; do curl -C - -L --connect-timeout 15 -# --output $int_arch_dir/ffmpeg-5.1.2.tar.bz2 https://github.com/q3aql/ffmpeg-builds/releases/download/v5.1.2/ffmpeg-5.1.2-linux-gnu-64bit-build.tar.bz2 && echo true && break || echo false; done | tail -1); then
      echo_error "Ошибка загрузки bin FFmpeg 5.1.2"
    fi
  fi
}

# установка ffmpeg 5.1
function install_ffmpeg {
  if [ $1 == "online" ]; then
    # в онлайн режиме устанавливает из директории скрипта
    cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
    case $os_install in
      centos7)
        # установка происходит просто рахорхивированием архива в корень
        echo_info "Копирование bin FFmpeg 5.1.2 из архива"
        tar jxvf $script_dir/ffmpeg-5.1.2.tar.bz2 -C / 2>/dev/null || echo_error "Ошибка копирования bin FFmpeg 5.1.2 из архива"
      ;;
      debian)
      ;;
      rhel)
      ;;
      altlinux)
      ;;
    esac
  elif [ $1 == "offline" ]; then
    # в оффлайн ставим из папки archive
    cd $int_arch_dir 2> /dev/null || echo_error "$int_arch_dir нет такой директории"
    case $os_install in
      centos7)
        # установка происходит просто рахорхивированием архива в корень
        echo_info "Копирование bin FFmpeg 5.1.2 из архива"
        tar jxvf $int_arch_dir/ffmpeg-5.1.2.tar.bz2 -C / 2>/dev/null || echo_error "Ошибка копирования bin FFmpeg 5.1.2 из архива"
      ;;
      debian)
      ;;
      rhel)
      ;;
      altlinux)
      ;;
    esac
  fi
}

# скачать пакеты
function download_pac {
  # ставим пакеты, с выгрузкой бинарных файлов
  install_pac system d; install_pac main d;
  cd $int_arch_pack_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  case $os_install in
    centos7)
      # ставим пакеты для работы с репозиторием
      echo_info "Установка createrepo"
      yum install -y createrepo || echo_error "Ошибка установки createrepo"
      # обновляем метаинформации о пакетах
      echo_info "Обновление метаинформации о пакетах"
      createrepo -v $PWD/$os_codename || echo_error "Ошибка обновления метаинформации о пакетах"
    ;;
    debian)
      # создаем структуру каталогов репозитория и перемещаем пакеты
      architecture=$(dpkg --print-architecture)
      mkdir -p $PWD/dists/$os_codename/pve &> /dev/null
      mkdir -p $PWD/dists/$os_codename/pve/binary-$architecture &> /dev/null
      cp -p /var/cache/apt/archives/*.deb $PWD/dists/$os_codename/pve 2> /dev/null || echo_error "Ошибка копирование cache(а) пакетов apt-get"
      # ставим пакеты для работы с репозиторием
      echo_info "Установка dpkg-dev apt-utils"
      apt-get install -y dpkg-dev apt-utils || echo_error "Ошибка установки dpkg-dev apt-utils"
      # обновляем метаинформации о пакетах
      echo_info "Обновление метаинформации о пакетах"
      #dpkg-scanpackages -t deb $PWD/dists/$os_codename/pve | gzip -c9 > $PWD/dists/$os_codename/pve/Packages.gz || echo_error "Ошибка обновления метаинформации о пакетах"
      dpkg-scanpackages -a $architecture dists/$os_codename/pve > $PWD/dists/$os_codename/pve/binary-$architecture/Packages 2>/dev/null && \
      dpkg-scanpackages -a $architecture dists/$os_codename/pve | gzip -c9 > $PWD/dists/$os_codename/pve/binary-$architecture/Packages.gz 2>/dev/null && \
      dpkg-scanpackages -a $architecture dists/$os_codename/pve | bzip2 -c9 > $PWD/dists/$os_codename/pve/binary-$architecture/Packages.bz2 2>/dev/null || \
      echo_error "Ошибка обновления метаинформации о пакетах"
      echo_info "Генерации файла Release"
      echo -n "Origin: Unknown
Label: Unknown
Suite: Unknown
Codename: $os_codename
Architectures: $architecture
Components: pve
Description: Not Available
" > $PWD/dists/$os_codename/Release && apt-ftparchive release $PWD/dists/$os_codename >> $PWD/dists/$os_codename/Release || echo_error "Ошибка генерации файла Release"
    ;;
    rhel)
      # ставим пакеты для работы с репозиторием
      echo_info "Установка createrepo"
      yum install -y createrepo || echo_error "Ошибка установки createrepo"
      # обновляем метаинформации о пакетах
      echo_info "Обновление метаинформации о пакетах"
      createrepo -v $PWD/$os_codename || echo_error "Ошибка обновления метаинформации о пакетах"
    ;;
    altlinux)
      # создаем структуру каталогов репозитория и перемещаем пакеты
      mkdir -p $PWD/$os_codename/base &> /dev/null
      mkdir -p $PWD/$os_codename/RPMS.pve &> /dev/null
      cp -p /var/cache/apt/archives/*.rpm $PWD/$os_codename/RPMS.pve 2> /dev/null || echo_error "Ошибка копирование cache(а) пакетов apt-get"
      # ставим пакеты для работы с репозиторием
      echo_info "Установка apt-repo-tools"
      apt-get install -y apt-repo-tools || echo_error "Ошибка установки apt-repo-tools"
      # обновляем метаинформации о пакетах
      echo_info "Обновление метаинформации о пакетах"
      genbasedir --bloat --progress --topdir=$PWD $os_codename pve || echo_error "Ошибка обновления метаинформации о пакетах"
    ;;
  esac
}

function set_devpi_repo {
  # если доступен локальный репозиторий pip, подключаем его
  echo_info "Подключение \"$python_devpi\" репозитория DevPI"
  python_pip_repo=https://pypi.org/simple/
  [[ $(for i in {1..3}; do curl -s -o /dev/null -m 5 --connect-timeout 5 -w "%{http_code}" https://$python_devpi/devpi/root/pypi/+simple/ 2>/dev/null && break || sleep 0.5; done | tail -1 | rev | cut -c 1-3 | rev) -eq 200 ]] && python_pip_repo="--index-url https://$python_devpi/devpi/root/pypi/+simple/ --trusted-host $python_devpi" || \
  echo_warning "Ошибка подключения, репозиторий $python_devpi недоступен"
}

# определяем набор модулей python для установки
function list_pip3_modules {
  if [ -z $1 ]; then echo_error "Ошибка определения набора модулей Python"; fi
  # установка модулей питона из списка в массиве или из внешнего файла модулей
  if [[ -f $list_pip3_modules_ext && -z "$build_modules" ]]; then
    echo_info "Существует внешний файл списока модулей pip3"
    mapfile -t not_install < $list_pip3_modules_ext
  elif [[ $1 == "full" || $1 == "cpu" || $1 == "cu11" || $1 == "cu12" || $1 == "ups" || $1 == "urs" || $1 == "ses" || $1 == "online" || $1 == "offline" ]]; then
    # набор модулей
    eval not_install=("\${modules_pip3_$1[@]}")
    # проверка версии компилятора, исключаем
    if [[ $(echo ${not_install[@]}) == *"llama-cpp-python"* && ($(g++ -std="c++17" /dev/null 2>&1) != *"collect2"* || $(g++ -dumpversion 2>/dev/null| cut -c1) -le 8) ]]; then
      [ $1 == "qas" ] && echo_error "Ваш C++ компилятор устарел. Можорная версия должна быть >=9 с поддержкой стандарта >=C++17. Окружение для OAS не поддерживается"
      echo_warning "Ваш C++ компилятор устарел. Можорная версия должна быть >=9 с поддержкой стандарта >=C++17. Окружение без поддержки QAS"
      not_install=($(echo ${not_install[@]} | sed -r 's#(^| )llama-cpp-python[^ ]*##g'))
    fi
    # 2 набора модулей
    if [[ $2 == "full" || $2 == "cpu" || $2 == "cu11" || $2 == "cu12" || $2 == "ups" || $2 == "urs" || $2 == "ses" ]]; then
      echo_info "Определение типа установки"
      echo "Установка: $1; собрано: $2"
      modules_pip3_offline="${not_install[@]}"; modules_pip3_online="";
      eval not_install_tmp="\${modules_pip3_$2[@]}"
      for c in ${not_install[@]}; do
        if [ $(echo $not_install_tmp | grep -c "$c" -m1) -eq 0 ]; then
          modules_pip3_offline=$(echo $modules_pip3_offline | sed "s/$c//")
          modules_pip3_online="$modules_pip3_online $c"
        fi
      done
      unset not_install
      unset not_install_tmp
      # настраиваем прокси
      if [ ! -z "$modules_pip3_online" ]; then
        echo_warning "Требуется загрузить недостающие модули"
        echo $modules_pip3_online
        proxy_configuration set
      fi
      modules_pip3_offline=($modules_pip3_offline)
      modules_pip3_online=($modules_pip3_online)
    fi
  fi
}

# перенос pyenv из root директории
function download_pyenv {
 cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
 # удаление всех версий питона из папки pyenv
 rm -rf $HOME/.pyenv/versions/*
 # перенос системного pyenv в папку формируемого архива
 cp -rp $HOME/.pyenv $int_arch_dir/ && rm -rf $HOME/.pyenv
 # создание папки кэш куда будет скачан архив для оффлайн установки версии питона
 mkdir $int_arch_dir/.pyenv/cache
 # перенос архива установки питона в папку кэш(установщик там ищет архив)
 case $os_install in
  centos7)
    mv $int_arch_dir/.pyenv/sources/$python_ver_centos/Python-$python_ver_centos.tar.xz $int_arch_dir/.pyenv/cache
    ;;
  debian)
    mv $int_arch_dir/.pyenv/sources/$python_ver_debian/Python-$python_ver_debian.tar.xz $int_arch_dir/.pyenv/cache
    ;;
  rhel)
    mv $int_arch_dir/.pyenv/sources/$python_ver_rhel/Python-$python_ver_rhel.tar.xz $int_arch_dir/.pyenv/cache
    ;;
  altlinux)
    mv $int_arch_dir/.pyenv/sources/$python_ver_altlinux/Python-$python_ver_altlinux.tar.xz $int_arch_dir/.pyenv/cache
    ;;
 esac
}

# скачивание модулей python
function download_modules {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  # подключаем локальный pip репозиторий
  set_devpi_repo
  # переход локально на $python_ver_дистрибутив
  case $os_install in
    centos7)
      pyenv local $python_ver_centos
    ;;
    debian)
      pyenv local $python_ver_debian
    ;;
    rhel)
      pyenv local $python_ver_rhel
    ;;
    altlinux)
      pyenv local $python_ver_altlinux
    ;;
  esac
  # удаляем старый кеш pip
  rm -rf $HOME/.cache/pip &> /dev/null
  # временные папки
  echo_info "Создание временной дерриктории $temp_dir"
  mkdir $temp_dir 2>&1 >/dev/null || echo_error "Ошибка создание временной дерриктории $temp_dir"
  echo_info "Создание временной дерриктории $temp_dir/modules"
  mkdir $temp_dir/modules 2>&1 >/dev/null || echo_error "Ошибка создание временной дерриктории $temp_dir/modules"
  # создание окружения на базе питона
  echo_info "Создание временного PVE окружения в $temp_dir"
  TMPDIR=/var/tmp python3 -m venv $temp_dir
  # установка всех модулей
   if $(source $temp_dir/bin/activate >/dev/null 2>&1 && deactivate && echo false || echo true); then
    echo_error "Ошибка создания временного PVE окружения"
   fi
   source $temp_dir/bin/activate
    # обновление pip3 и других модулей, без их установки не загрузятся модули
    for i in "pip" "wheel" "scikit-build" "setuptools_rust" "setuptools" "cython" "tomli"; do
      TMPDIR=/var/tmp python3 -m pip install --no-cache-dir $python_pip_repo --upgrade $i --retries 60 --timeout 60 2>&1 >/dev/null
    done
    # создаем файл типа устаноки, для детектирования офлайн установки
    list_pip3_modules $1;
    cd $temp_dir/modules; f_done=0
    # предпринемаем 3 попытки на установку модулей
    while [[ ! -z $not_install && $f_done -lt 3 ]]; do
      for (( i=0; i<"${#not_install[@]}"; i++ )); do
        pip_modules=$(echo ${not_install[i]} | tr '|' ' ')
        echo_info "Загрузка модуля(ей) Python $pip_modules"
        # загрузка torch
        if [ $(echo $pip_modules | grep -cE "(^| )torch.*\+(cpu|cu[0-9]+)") -ne 0 ]; then
          TMPDIR=/var/tmp python3 -m pip download --index-url https://download.pytorch.org/whl/$(echo $pip_modules | grep -Eo "(cpu|cu[0-9]+) -m1") \
          $(echo $python_pip_repo | sed "s#--index-url#--extra-index-url#") $pip_modules --timeout 60 || \
          (echo_warning "Ошибка загрузки модуля(ей) Python $pip_modules" && not_install_tmp="$not_install_tmp ${not_install[i]}")
        elif [ $(echo $pip_modules | grep -cE "(^| )llama-cpp-python-cu") -ne 0 ]; then
            not_install[i]=$(echo ${not_install[i]} | sed 's/llama-cpp-python-cu/llama-cpp-python/')
            TMPDIR=/var/tmp python3 -m pip download $python_pip_repo $(echo $pip_modules | sed 's/llama-cpp-python-cu/llama-cpp-python/') --timeout 60 || (echo_warning "Ошибка загрузки модуля(ей) Python $pip_modules" && not_install_tmp="$not_install_tmp ${not_install[i]}")
        else
          TMPDIR=/var/tmp python3 -m pip download $python_pip_repo $pip_modules --timeout 60 || (echo_warning "Ошибка загрузки модуля(ей) Python $pip_modules" && not_install_tmp="$not_install_tmp ${not_install[i]}")
        fi
      done
      not_install=($not_install_tmp); f_done=$(($f_done + 1)); unset not_install_tmp
    done
    # если за 3 попытки не удалось загрузить нужные модули
    [[ -z $not_install && $f_done -ge 3 ]] && echo_error "Ошибка загрузки модуля(ей) Python ${not_install[@]}"
  deactivate
  # переход локально на системную версию чтобы не сломать то что уже работает на системной
  pyenv local system
  rm -rf .python-version
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  # перемещение с временной папки в основную папку архива
  cp -rp $temp_dir/modules $int_arch_dir/
  # удаление временной папки
  rm -rf $temp_dir
}

function export_pyenv_enviroment {
  export PYENV_ROOT="$HOME/.pyenv" &&  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
}

function install_pyenv {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  # удаляем старый кеш pip
  rm -rf $HOME/.cache/pip &> /dev/null
  # онлайн установка
  if [ $1 == "online" ]; then
    echo_info "Загрузка и установка Pyenv"
    rm -rf $HOME/.pyenv && export_pyenv_enviroment >/dev/null 2>&1 && for i in {1..3}; do curl --connect-timeout 15 https://pyenv.run 2>/dev/null && break || sleep 0.5; done | bash 2>&1 && export_pyenv_enviroment >/dev/null 2>&1 && sleep 0.5 || echo_error "Ошибка загрузки и установки Pyenv"
    # установка питона с сохранением исходников ключ -k
    case $os_install in
      centos7)
        # создание дерриктории
        mkdir -p "/root/.pyenv/versions/$python_ver_centos/bin"
        echo_info "Pyenv: загрузка и установка версии Python$python_ver_centos"
        # проверка наличия нужной версии питона в репозитории pyenv
        if [ "`pyenv install --list 2> /dev/null | sed 's/^ *//g' | grep ^$python_ver_centos`" == "$python_ver_centos" ]; then
          CPPFLAGS="-I/usr/include/openssl11" LDFLAGS="-L/usr/lib64/openssl11 -lssl -lcrypto" pyenv install -k -f $python_ver_centos 2>&1
         else
          echo_error "Pyenv: нет такой версии Python$python_ver_centos"
        fi
      ;;
      debian)
        # создание дерриктории
        mkdir -p "/root/.pyenv/versions/$python_ver_debian/bin"
        echo_info "Pyenv: загрузка и установка версии Python$python_ver_debian"
        if [ "`pyenv install --list 2> /dev/null | sed 's/^ *//g' | grep ^$python_ver_debian`" == "$python_ver_debian" ]; then
          pyenv install -k -f $python_ver_debian 2>&1
         else
          echo_error "Pyenv: нет такой версии Python$python_ver_debian"
        fi
      ;;
      rhel)
        # создание дерриктории
        mkdir -p "/root/.pyenv/versions/$python_ver_rhel/bin"
        echo_info "Pyenv: загрузка и установка версии Python$python_ver_rhel"
        if [ "`pyenv install --list 2> /dev/null | sed 's/^ *//g' | grep ^$python_ver_rhel`" == "$python_ver_rhel" ]; then
          pyenv install -k -f $python_ver_rhel 2>&1
         else
          echo_error "Pyenv: нет такой версии Python$python_ver_rhel"
        fi
      ;;
      altlinux)
        # создание дерриктории
        mkdir -p "/root/.pyenv/versions/$python_ver_altlinux/bin"
        echo_info "Pyenv: загрузка и установка версии Python$python_ver_altlinux"
        if [ "`pyenv install --list 2> /dev/null | sed 's/^ *//g' | grep ^$python_ver_altlinux`" == "$python_ver_altlinux" ]; then
          pyenv install -k -f $python_ver_altlinux 2>&1
         else
          echo_error "Pyenv: нет такой версии Python$python_ver_altlinux"
        fi
      ;;
    esac
    # оффлайн установка
    elif [ $1 == "offline" ]; then
      # перенести установленную версию pyenv в хом рута
      cp -rp $int_arch_dir/.pyenv /root && rm -rf $int_arch_dir/.pyenv
      # прописывание pyenv окружения (действует до первой перезагрузки)
      export_pyenv_enviroment
      # установка питона
      case $os_install in
        centos7)
          echo_info "Pyenv: установка версии Python$python_ver_centos"
          # проверка наличия нужной версии питона в репозитории pyenv
          if [ "`pyenv install --list | sed 's/^ *//g' | grep ^$python_ver_centos`" == "$python_ver_centos" ]; then
            CPPFLAGS="-I/usr/include/openssl11" LDFLAGS="-L/usr/lib64/openssl11 -lssl -lcrypto" pyenv install -s -f $python_ver_centos 2>&1
          else
            echo_error "Pyenv: нет такой версии Python$python_ver_centos"
          fi
        ;;
        debian)
          echo_info "Pyenv: установка версии Python$python_ver_debian"
          if [ "`pyenv install --list | sed 's/^ *//g' | grep ^$python_ver_debian`" == "$python_ver_debian" ]; then
            pyenv install -s -f $python_ver_debian 2>&1
          else
            echo_error "Pyenv: нет такой версии Python$python_ver_debian"
          fi
        ;;
        rhel)
          echo_info "Pyenv: установка версии Python$python_ver_rhel"
          if [ "`pyenv install --list | sed 's/^ *//g' | grep ^$python_ver_rhel`" == "$python_ver_rhel" ]; then
            pyenv install -s -f $python_ver_rhel 2>&1
          else
            echo_error "Pyenv: нет такой версии Python$python_ver_rhel"
          fi
        ;;
        altlinux)
          echo_info "Pyenv: установка версии Python$python_ver_altlinux"
          if [ "`pyenv install --list | sed 's/^ *//g' | grep ^$python_ver_altlinux`" == "$python_ver_altlinux" ]; then
            pyenv install -s -f $python_ver_altlinux 2>&1
          else
            echo_error "Pyenv: нет такой версии Python$python_ver_altlinux"
          fi
        ;;
      esac
  fi
}

# установка pve окружения
function install_pve {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  # удаляем старый кеш pip
  rm -rf $HOME/.cache/pip &> /dev/null
  list_pip3_modules $3;
  # оффлайн установка
  if [ $1 == "offline" ]; then
    # переход локально
    case $os_install in
      centos7)
        pyenv local $python_ver_centos
      ;;
      debian)
        pyenv local $python_ver_debian
      ;;
      rhel)
        pyenv local $python_ver_rhel
      ;;
      altlinux)
        pyenv local $python_ver_altlinux
      ;;
        esac
    # создание окружения на базе питона
    if $(source $2/bin/activate >/dev/null 2>&1 && deactivate && echo false || echo true); then
      echo_info "Создание виртуального PVE окружения в $2"
      TMPDIR=/var/tmp python3 -m venv $2 && sleep 0.5
      # установка модулей
      if $(source $2/bin/activate >/dev/null 2>&1 && deactivate && echo false || echo true); then
        echo_error "Ошибка создания виртуального PVE окружения"
      fi
    fi
    source $2/bin/activate
      f_done=0
      cd $int_arch_dir/modules 2> /dev/null || echo_error "$script_dir нет такой директории"
      # обновление pip3
      TMPDIR=/var/tmp python3 -m pip install --no-cache-dir --upgrade pip --no-index --find-links '.' --retries 60 --timeout 60 2>&1 >/dev/null
      # предпринемаем 3 попытки на установку модулей
      while [[ ! -z $not_install && $f_done -lt 3 ]]; do
        for (( i=0; i<"${#not_install[@]}"; i++ )); do
          pip_modules=$(echo ${not_install[i]} | tr '|' ' ')
          echo_info "Установка модуля(ей) Python $pip_modules"
          if [ $(echo $pip_modules | grep -cE "(^| )llama-cpp-python-cu") -ne 0 ]; then
            TMPDIR=/var/tmp CUDACXX=${install_nvcc[0]} CMAKE_ARGS="-DGGML_CUDA=on" FORCE_CMAKE=1 python3 -m pip install --no-cache-dir $(echo $pip_modules | sed 's/llama-cpp-python-cu/llama-cpp-python/') --no-index --find-links '.' --retries 60 --timeout 60 || echo_warning "Ошибка установкимодуля(ей) Python $pip_modules"
          else
            TMPDIR=/var/tmp python3 -m pip install --no-cache-dir $pip_modules --no-index --find-links '.' --retries 60 --timeout 60 || echo_warning "Ошибка установкимодуля(ей) Python $pip_modules"
          fi
        done
        # контроль установки
        module_install=$(pip3 list | tr -s '\r\n' ' ')
        for i in ${not_install[@]}; do
          for j in $(echo $i | tr '|' ' '); do
            s=$(echo $j | sed 's/==/ /'); ss=($s)
            if [[ $module_install != *"$s"* && $module_install != *"$(echo $s | tr '-' '_')"* && $module_install != *"$(echo $s | sed 's/llama-cpp-python-cu/llama_cpp_python/')"* ]]; then [ -z "$(find "$2/lib" -maxdepth 3 -name "${ss[0]}*" 2>/dev/null)" ]  && not_install_tmp="$not_install_tmp $i"; break; fi
          done
        done
        not_install=($not_install_tmp); f_done=$(($f_done + 1)); unset not_install_tmp
      done
      # если за 3 попытки не удалось поставить нужные модули
      [[ -z $not_install && $f_done -ge 3 ]] && echo_error "Ошибка установки модуля(ей) Python ${not_install[@]}"
    deactivate
    # переход локально на системную версию чтобы не сломать то что уже работает на системной
    pyenv local system
   # онлайн установка pve
  elif [[ ($1 == "online" && -z $modules_pip3_online && -z $modules_pip3_offline) || ($1 == "online" && ! -z $modules_pip3_online && ! -z $modules_pip3_offline) ]]; then
    # подключаем локальный pip репозиторий
    set_devpi_repo
    # переход локально на версию питона установленную через pyenv
    # указывает системе работать с версией питона установленного в pyenv
    case $os_install in
      centos7)
        pyenv local $python_ver_centos
        python_ver_check=$python_ver_centos
      ;;
      debian)
        pyenv local $python_ver_debian
        python_ver_check=$python_ver_debian
      ;;
      rhel)
        pyenv local $python_ver_rhel
        python_ver_check=$python_ver_rhel
      ;;
      altlinux)
        pyenv local $python_ver_altlinux
        python_ver_check=$python_ver_altlinux
      ;;
    esac
    # создание виртуального питон окружения в папке
    if $(source $2/bin/activate >/dev/null 2>&1 && deactivate && echo false || echo true); then
      echo_info "Создание виртуального PVE окружения в $2"
      TMPDIR=/var/tmp python3 -m venv $2 && sleep 0.5
      # установка модулей
      if $(source $2/bin/activate >/dev/null 2>&1 && deactivate && echo false || echo true); then
        echo_error "Ошибка создания виртуального PVE окружения"
      fi
    fi
    source $2/bin/activate
      f_done=0
      # проверка на правельную версию Python в окружение, нет смысла выкачивать модули если не совпадает
      [ $(python3 --version | grep -c "$python_ver_check") -eq 0 ] && echo_error "Ошибка, установленная версия Python, окружения, не совпадает с $python_ver_check"
      for i in {1..3}; do curl -sS --connect-timeout 15 https://bootstrap.pypa.io/pip/get-pip.py 2>/dev/null && break || sleep 0.5; done | python3
      # обновление pip3
      TMPDIR=/var/tmp python3 -m pip install --no-cache-dir $python_pip_repo --upgrade pip --retries 60 --timeout 60 2>&1 >/dev/null
      # предпринемаем 3 попытки на установку модулей
      while [[ ! -z $not_install && $f_done -lt 3 ]]; do
        for (( i=0; i<${#not_install[@]}; i++ )); do
          pip_modules=$(echo ${not_install[i]} | tr '|' ' ')
          echo_info "Установка модуля(ей) Python $pip_modules"
          # загрузка torch
          if [ $(echo $pip_modules | grep -cE "(^| )torch.*\+(cpu|cu[0-9]+)") -ne 0 ]; then
            TMPDIR=/var/tmp python3 -m pip install --no-cache-dir --index-url https://download.pytorch.org/whl/$(echo $pip_modules | grep -Eo "(cpu|cu[0-9]+) -m1") \
            $(echo $python_pip_repo | sed "s#--index-url#--extra-index-url#") $pip_modules --retries 60 --timeout 60 || \
            echo_warning "Ошибка установки модуля(ей) Python $pip_modules"
          elif [ $(echo $pip_modules | grep -cE "(^| )llama-cpp-python-cu") -ne 0 ]; then
            TMPDIR=/var/tmp CUDACXX=${install_nvcc[0]} CMAKE_ARGS="-DGGML_CUDA=on" FORCE_CMAKE=1 python3 -m pip install --no-cache-dir $python_pip_repo $(echo $pip_modules | sed 's/llama-cpp-python-cu/llama-cpp-python/') --retries 60 --timeout 60 || echo_warning "Ошибка установки модуля(ей) Python $pip_modules"
          else
            TMPDIR=/var/tmp python3 -m pip install --no-cache-dir $python_pip_repo $pip_modules --retries 60 --timeout 60 || echo_warning "Ошибка установки модуля(ей) Python $pip_modules"
          fi
        done
        # контроль установки
        module_install=$(pip3 list | tr -s '\r\n' ' ')
        for i in ${not_install[@]}; do
          for j in $(echo $i | tr '|' ' '); do
            s=$(echo $j | sed 's/==/ /'); ss=($s)
            if [[ $module_install != *"$s"* && $module_install != *"$(echo $s | tr '-' '_')"* && $module_install != *"$(echo $s | sed 's/llama-cpp-python-cu/llama_cpp_python/')"* ]]; then [ -z "$(find "$2/lib" -maxdepth 3 -name "${ss[0]}*" 2>/dev/null)" ]  && not_install_tmp="$not_install_tmp $i"; break; fi
          done
        done
        not_install=("$not_install_tmp"); f_done=$(($f_done + 1)); unset not_install_tmp
      done
      # если за 3 попытки не удалось поставить нужные модули
      [ $f_done -ge 3 ] && echo_error "Ошибка установки модуля(ей) Python ${not_install[@]}"
    deactivate
    # переход локально на системную версию чтобы не сломать то что уже работает на системной
    pyenv local system
    # правим пути, актуально для оффлайн сборки
    to_install_dir=$(echo $2 | sed "s#$int_arch_dir##")
    if [ $to_install_dir != $2 ]; then sed -i "s#$2#$to_install_dir#g" $2/bin/*; fi
  fi
}

# создание архива для включения в скрипт оффлайн установки
function create_arсhive {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  echo_info "Создание архива $int_service_name-${int_version}-${int_release}.tar.gz"
  tar -vzcf "$script_dir/$int_service_name-${int_version}-${int_release}.tar.gz" -C $1 $(ls -A $1) --remove-files 2> /dev/null | grep -Gv "/$" || echo_error "Ошибка создания архива $int_service_name-${int_version}-${int_release}.tar.gz"
  rm -rf $1 2> /dev/null
}

# распаковка внутреннего архива
function extract_archive {
  # смещение в байтах до архива
  PAYLOAD_LINE=$(awk '{print $0}/^__PAYLOAD_BEGINS__/{exit 0}' $actual_path | wc -c)
  # сверка хеш суммы архива
  # [[ $(dd if="$actual_path" bs=1M skip=${PAYLOAD_LINE} iflag=skip_bytes 2> /dev/null | md5sum | cut -d' ' -f1) != $int_arch_md5 ]] && echo_error "Ошибка, не соотвествие хеш суммы внутреннего архива"
  # распаковать в каталог
  if [[ ! -z "$1" && "$1" == "dir" ]]; then
    echo_info "Распаковка внутреннего архива в $2"
    mkdir -p $2 2> /dev/null
    dd if="$actual_path" bs=1M skip=${PAYLOAD_LINE} iflag=skip_bytes 2> /dev/null | tar -vxz --directory="$2" 2> /dev/null | grep -Gv "/$" || echo_error "Ошибка распаковки внутреннего архива в $2"
  else
    # скопировать архив рядом со скриптом не распаковывая его
    echo_info "Копирование внутреннего архива в каталог со скриптом"
    dd if="$actual_path" of="$script_dir/$int_service_name-${int_version}-${int_release}.tar.gz" bs=1M skip=${PAYLOAD_LINE} iflag=skip_bytes status=progress || echo_error "Ошибка копирования внутреннего архива в каталог со скриптом"
  fi
}

# врезать в скрипт внешний архив
function pack_archive {
  # обновляем значение хеш суммы архива в скрипте
  if [ ! -z $2 ]; then
    script_name="$int_service_name-${int_version}-${int_release}$2.sh"
    out_file="$script_dir/$script_name"
    cat $actual_path | sed 's/^int_arch_md5=.*$/int_arch_md5="'$(md5sum $script_dir/$1 2> /dev/null | cut -d' ' -f1)'"/' > $out_file && chmod +x $out_file
  else
    out_file="$actual_path"
    sed -i 's/^int_arch_md5=.*$/int_arch_md5="'$(md5sum $script_dir/$1 2> /dev/null | cut -d' ' -f1)'"/' $out_file
  fi
  echo_info "Врезаем архив в скрипт $script_name"
  # удалить всё что после payload
  sed -i '/^__PAYLOAD_BEGINS__$/q' $out_file 2> /dev/null || echo_error "Ошибка врезки архива $1 в скрипт"
  # вставить архив в скрипт
  dd if="$script_dir/$1" of="$out_file" bs=1024 conv=notrunc oflag=append status=progress || echo_error "Ошибка врезки архива $1 в скрипт"
}

function null_archive {
  # удалить всё что после payload
  echo_info "Удаляем внутренний архив из скрипта $script_name"
  sed -i '/^__PAYLOAD_BEGINS__$/q' $actual_path 2> /dev/null || echo_error "Ошибка удаления внутреннего архива из скрипта $script_name"
}

# назначение прав на файлы сервиса
function assign_rights {
  # смена владельца на папку сервиса
  echo_info "Смена владельца для $1"
  chown -R $USER:$USER $1 >/dev/null 2>&1 || echo_error "Ошибка смены владельца для $1"
  # для систем с SELinux
  if [ $(sestatus 2> /dev/null | head -1 | grep -ic enabled) -eq 1 ]; then
    echo_info "Настройка политик SELinux"
    # изменение контекста на папки сервиса
    chcon -u system_u -R $HOME/.pyenv >/dev/null 2>&1 && chcon -u system_u -R $1 >/dev/null 2>&1 || echo_error "Ошибка изменения политик, для папок сервиса"
    # создание модуля политики
    echo "module pve 1.0;

require {
	type var_lib_t;
        type admin_home_t;
        type setroubleshootd_t;
        type init_t;
        class file { execute lock open read };
}

#============= init_t ==============
allow init_t admin_home_t:file { execute open read };

#============= setroubleshootd_t ==============
allow setroubleshootd_t var_lib_t:file { lock open read };
" > pve.te
    # компиляция политики
    checkmodule -M -m -o pve.mod pve.te >/dev/null 2>&1 || echo_error "Ошибка компиляции политик"
    # создание пакета
    semodule_package -o pve.pp -m pve.mod >/dev/null 2>&1 || echo_error "Ошибка создания пакета политик"
    # загрузка пакета политики в ядро
    semodule -i pve.pp >/dev/null 2>&1 || echo_error "Ошибка загрузки пакета политик в ядро"
    # удаляем исходники, файлы работы
    rm -f pve.mod pve.pp pve.te &> /dev/null
  fi
}

# функция получения тела функции, для переноса функционала в отдельный файл
function show_body_function {
  fcount=$(type $1 | sed -e 's#\\#\\\\#g' -e '1d')
  for v in $(echo $fcount | grep -Eo "\\\$(([a-z]+_)+[a-z]+)" | sort -u); do
    to=$(eval echo "$v")
    fcount=$(sed "s#\\$v#$to#g" <<< $fcount)
  done
  echo $fcount
}

# удаление старой версии
function uninstall_service {
  if [ ! -z "$2" ]; then
      echo_info "Удаление старой версии окружения $int_service_name"
      # удаляем файлы и подкаталоги сервиса
      for fl in $(ls --ignore="." --ignore=".." -a $1 2>/dev/null); do
        [[ $fl != ".userapi" && $fl != ".proxy" ]] && rm -rf "$1/$fl" &> /dev/null && echo "remove $1/$fl"
      done
  elif [ -d $1 ]; then
    echo_warning "Окружение PVE будет полностью удалено."
    # ввод на подтверждение
    read -p "yes(y)/no(n): " -r confirm
    if [[ "$confirm" != "yes" && "$confirm" != "y" ]]; then
      echo_error "Отменено"
    fi
    echo_info "Удаление старой версии окружения $int_service_name"
    # удаляем файлы и подкаталоги сервиса
    for fl in $(ls --ignore="." --ignore=".." -a $1 2>/dev/null); do
      rm -rf "$1/$fl" &> /dev/null && echo "remove $1/$fl"
    done
    # удаляем корневую папку сервиса
    rm -rf $1 &> /dev/null || echo_error "Ошибка удаления папки сервиса $1"
  else
    description_keys; exit
  fi
}

# авторизация в репозитории
# для функций ниже
function authuser_api {
    authuserapi=$(cat $1/.userapi 2>/dev/null|head -1|tr "" "\r\n")
    [ -z $authuserapi ] && authuserapi=$(cat $int_pve_install_dir/.userapi 2>/dev/null|head -1|tr "" "\r\n")
    if [[ -z $authuserapi ]]; then
      echo_info "Авторизация"
      read -p "User: " updateuser;
      read -p "Pass: " updatepass;
      echo; authuserapi=$updateuser":"$updatepass
    fi
    # проверка пары логина и пароля
    if [ $(echo $authuserapi | grep -Ec "^[^ :]+:[^ :]+$") -eq 0 ]; then echo_error "Пустое или не корректное сочитание логина и пароля"; fi
}

# обновление сервиса
function update_service {
  if [ -d $1 ]; then
    if [ -z $3 ]; then
      echo -e "\n  ключи -b(--beta)|-r(--release)|-n(--new)\n\n  -b/--beta - обновить до последней beta версии\n  -r/--release - обновить до последней release версии\n  -n/--new - обновить до последней версии (не важно beta или release)\n\n  в папке окружения можно положить файл $1/.userapi с данными аутентификации: [user]:[password]\n  или общий в папке с общим окружением $int_pve_install_dir/.userapi\n"
      echo -e "  в папке окружения можно положить файл $1/.proxy с конфигурацией proxy сервера: http://example.com:3128 [user] [password]; socks5://example.com:1080 [user] [password]\n  или общий в папке с общим окружением $int_pve_install_dir/.proxy\n"
    fi
    proxy_configuration set
    cnum=1;
    cversion=($(cat $1/.version 2>/dev/null|tr "" "\r\n"))
    nversion=($(for i in {1..3}; do curl -s -m 5 --connect-timeout 5 "$int_repo_url/$int_service_name/version" 2>/dev/null && break || sleep 0.5; done))

    # проверяем корректность полученного значения версии из repo
    [[ -z $nversion || $(echo ${nversion[@]} | grep -Ec "^([0-9.]+[ ](release|beta)[ ]*){1,2}$") -eq 0 ]] && echo_error "Не удалось получить версию из репозитория"

    # запуск без аргумента
    if [ -z $3 ]; then
      echo_info "Выберите версию для обновления"; echo
      # список версий для загрузок
      for (( a = 0; a < ${#nversion[@]}; a=$(($a+2)) )); do
        nversiondownload[$cnum]="$int_repo_url/$int_service_name/"${nversion[$(($a+1))]}
        echo "    "$cnum. ${nversion[$a]} ${nversion[$(($a+1))]}
        cnum=$(($cnum+1))
      done
      echo; read -p "Номер: " cnum; echo;
      # ошибка если ввели не номер от 1 до N
      [[ ! $cnum =~ ^[0-9]+$ || $cnum -gt $((${#nversion[@]}/2)) || $cnum -lt 1 ]] && echo_error "Не верное значение"
      # проверяем на актуальность текущую версию
      if [[ ! -z $cversion && $(echo $nversion | sed "s/\.//g") -le $(echo $cversion | sed "s/\.//g") ]]; then
        echo_warning "Обновление не требуется"; echo; exit
      fi
    else
      # определяем ключ вызова
      [[ "$3" == "-r" || "$3" == "--release" ]] && nversiondownload[$cnum]="$int_repo_url/$int_service_name/release"
      [[ "$3" == "-b" || "$3" == "--beta" ]] && nversiondownload[$cnum]="$int_repo_url/$int_service_name/beta"
      [[ "$3" == "-n" || "$3" == "--new" ]] && nversiondownload[$cnum]="$int_repo_url/$int_service_name/new"

      [ -z ${nversiondownload[@]} ] && echo_error "Не верное значение ключа"
      # проверяем на актуальность текущую версию
      if [[ ! -z $cversion && $(echo $nversion | sed "s/\.//g") -le $(echo $cversion | sed "s/\.//g") ]]; then
        echo_warning "Обновление не требуется"; echo; exit
      fi
    fi
    # авторизация в репозитории
    authuser_api $1
    # загружаем инсталятор
    downloadscript=$(for i in {1..3}; do curl -s --connect-timeout 15 ${nversiondownload[$cnum]} --user $authuserapi 2>/dev/null && break || sleep 0.5; done)
    if [[ ! -z "$downloadscript"  && $(echo "$downloadscript" | grep -c '"error":1') -eq 0 ]]; then
      installscript=$(echo "$downloadscript" | grep -Eo "$int_service_name[^: ]+" -m1)
      echo_info "Загрузка $installscript" && `bash -c "$downloadscript"` 2>/dev/null
      bash -c "$PWD/$installscript -u -on --$2" && rm -rf "$PWD/$installscript" &> /dev/null
    else
      echo_error "Неверный логин или пароль"
    fi
    proxy_configuration unset
  fi
}

# функция создания скриптов в папке установки
# uninstall - для удаления сервиса
# update - для обновления сервиса
function create_bash_script {
  echo_info "Создание файлов и bash скриптов автоматизации"
  # uninstall
  echo -e "#!/bin/bash\n$(show_body_function echo_info)\n$(show_body_function echo_warning)\n$(show_body_function echo_error)\n$(show_body_function uninstall_service)\nuninstall_service \"$1\"" > $1/uninstall && \
    (chmod +x $1/uninstall || echo_error "Ошибка создания скрипта $1/uninstall")
  # inupdate
  echo -e "#!/bin/bash\n$(show_body_function echo_info)\n$(show_body_function echo_warning)\n$(show_body_function echo_error)\n$(show_body_function proxy_configuration)\n$(show_body_function authuser_api)\n$(show_body_function update_service)\nupdate_service \"$1\" \"$2\" \$1" > $1/inupdate && \
    (chmod +x $1/inupdate || echo_error "Ошибка создания скрипта $1/inupdate")
  # .version
  echo -n "$int_version $int_release" > $1/.version
}

# удаление временных каталогов
function clear_temp {
  cd $script_dir 2> /dev/null || echo_error "$script_dir нет такой директории"
  rm -rf $int_arch_dir &> /dev/null
  rm -rf .python-version &> /dev/null
  rm -rf "$int_service_name-${int_version}-${int_release}.tar.gz" &> /dev/null
  rm -rf $HOME/.cache/pip &> /dev/null
  rm -rf $int_arch_pack_dir/offline.sig &> /dev/null
  rm -rf $temp_dir &> /dev/null
  proxy_configuration unset
}

# описание режимов работы скрипта, выводит при "пустом" запуске
function description_keys {
  echo -e "  ключи -e(--extract) -p(--pack) -b(--build) -u(--update) -n(--null) -i(--install) -ups(--ups) -urs(--urs) -ses(--ses) -off(--offline) -on(--online) -f(--full) -cu11(--cu11) -cu12(--cu12) -cpu(--cpu) -u(--uninstall)
  ""
  --------установка--------
  "-i/--install"                       - установить окружение в online/offline режиме
                                         второй обязательный ключ:
                                           "-on/--online"   - установка онлайн
                                           "-off/--offline" - утановка оффлайн (необходимо собрать скрипт с ключем -b/--build)
                                         третий обязательный ключ:
                                           "-cpu/--cpu"     - полный набор pip3 модулей под CPU
                                           "-cu11/--cu11"   - полный набор pip3 модулей под GPU CU11.8 (необходима установка CUDA Toolkit)
                                           "-cu12/--cu12"   - полный набор pip3 модулей под GPU CU12.1 (необходима установка CUDA Toolkit)
                                           "-ups/--ups"     - набор модулей pip3 для ups/res
                                           "-urs/--urs"     - набор модулей pip3 для urs
                                           "-ses/--ses"     - набор модулей pip3 для ses
  -------обновление--------
  "-u/--update"                        - обновить окружение в online/offline режиме
                                         второй обязательный ключ:
                                           "-on/--online"   - обновление онлайн
                                           "-off/--offline" - обновление оффлайн (необходимо собрать скрипт с ключем -b/--build)
                                         третий обязательный ключ:
                                           "-cpu/--cpu"     - полный набор pip3 модулей под CPU
                                           "-cu11/--cu11"   - полный набор pip3 модулей под GPU CU11.8 (необходима установка CUDA Toolkit)
                                           "-cu12/--cu12"   - полный набор pip3 модулей под GPU CU12.1 (необходима установка CUDA Toolkit)
                                           "-ups/--ups"     - набор модулей pip3 для ups/res
                                           "-urs/--urs"     - набор модулей pip3 для urs
                                           "-ses/--ses"     - набор модулей pip3 для ses
  "./inupdate"                         - скрипт интерактивного обновления окружение (в папки $int_pve_install_dir с установленным окружением)
                                         !!! требуется наличие интернет соединения
  ---------сборка----------
  "-b/--build"                         - скачать все пакеты, и модули, и упаковать в скрипт для оффлайн установки
                                         второй обязательный ключ:
                                           "-i/--install"   - сборка с системными пакетами (полная)
                                           "-u/--update"    - только окружение, для обновления (без системных пакетов)
                                         третий обязательный ключ:
                                           "-f/--full"      - полный набор pip3 модулей под все типы установки/обновления
                                           "-cpu/--cpu"     - полный набор pip3 модулей под CPU
                                           "-cu11/--cu11"   - полный набор pip3 модулей под GPU CU11.8 (необходима установка CUDA Toolkit)
                                           "-cu12/--cu12"   - полный набор pip3 модулей под GPU CU12.1 (необходима установка CUDA Toolkit)
                                           "-ups/--ups"     - набор модулей pip3 для ups/res
                                           "-urs/--urs"     - набор модулей pip3 для urs
                                           "-ses/--ses"     - набор модулей pip3 для ses
  --------удаление---------
  "-u/--uninstall"                     - удалить окружение
  "./uninstall"                        - скрипт интерактивного удаления окружение (в папки $int_pve_install_dir с установленным окружением)
  -------------------------
  "-e/--extract"                       - скопировать внутренний архив рядом со скриптом
  "-p/--pack имя_архива"               - запаковать архив в скрипт - архив создавать без абсолютных каталогов:
                                         tar -czvf $int_service_name-install.tgz -C archive \$(ls -A archive)
  "-d/--dir путь/имя_каталога"         - совместно с -p/--pack или -e/--extract, сжать\распаковать каталог в\из архива
  "-n/--null"                          - удалить внутренний архив из скрипта
  ""
  ""
  -- Установить окружение с полным набором модулей под CPU
  Пример использования: ./$script_name -i -cpu -on
  -- Установить окружение из заранее собранного инсталлера с полным набором модулей под CPU
  Пример использования: ./$script_name -i -cpu -off
  -- Собрать все пакеты для установки оффлайн окружения с полным набором модулей под CPU
  Пример использования: ./$script_name -b -i -cpu
  -- Собрать все пакеты для обновления оффлайн окружения с полным набором модулей под CPU
  Пример использования: ./$script_name -b -u -cpu
  -- Скопировать внутренний архив рядом со скриптом не распаковывая в папку
  Пример использования: ./$script_name -e
  -- Запаковать архив в скрипт
  Пример использования: ./$script_name -p <service>-offline.tgz
  -- Сжать каталог и запаковать архив в скрипт
  Пример использования: ./$script_name -p -d <имя каталога>
  -- Распаковать внутренний архив рядом со скриптом в каталог
  Пример использования: ./$script_name -e -d archive
  -- Удалить внутренний архив из скрипта
  Пример использования: ./$script_name --null
  -- Удалить окружение
  Пример использования: ./$script_name --uninstall
"
}

########
# main #
########

# заголовок инсталятора
echo -e $installer_head
echo_info "Установка, как $os_install"

# пустой запуск
if [ "$1" == "" ]; then description_keys; exit; fi

# перебор ключей запуска
while (($#)); do
 arg=$1
  shift
   case $arg in
     # для двойных ключей с --
     --*) case ${arg:2} in
          # установка
          install)   key_i="i";;
          # обновление
          update)    key_u="up";;
          # онлайн установка
          online)    key_on="on";;
          # оффлайн установка
          offline)   key_off="off";;
          # сборка внутреннего архива для оффлайн установки
          build)     key_b="b";;
          # полный набор pip3 под все типы установок
          full)      key_f="f";;
          # полный набор pip3 модулей под CPU
          cpu)       key_cpu="cpu";;
          # полный набор pip3 модулей под GPU CU11.8
          cu11)      key_cu11="cu11";;
          # полный набор pip3 модулей под GPU CU12.1
          cu12)      key_cu12="cu12";;
          # установка под ups
          ups)       key_ups="ups";;
          # установка под urs
          urs)       key_ups="urs";;
          # установка под ses
          ses)       key_ses="ses";;
          # удалить внутренний архив (слишком большой для редактирования скрипта)
          null)      key_n="n";;
          # скопировать архив рядом со скриптом не распаковывая его
          extract)   key_e="e";;
          # запаковать внешний архив в скрипт
          pack)      key_p="p"; key_p_arg=$1;;
          # сделать архив и запаковать в скрипт из директории
          dir)       key_d="d"; key_d_arg=$1;;
          # удалить окружение
          uninstall) key_u="u";;
          # все остальные ключи
          *)         description_keys; exit 1;;
        esac;;

     # для одинарных ключей с -
     -*) case ${arg:1} in
          # установка
          i)         key_i="i";;
          # обновление/удалить окружение
          u)         key_u="u";;
          # онлайн установка
          on)        key_on="on";;
          # оффлайн установка
          off)       key_off="off";;
          # сборка внутреннего архива для оффлайн установки
          b)         key_b="b";;
          # полный набор pip3 под все типы установок
          f)         key_f="f";;
          # полный набор pip3 модулей под CPU
          cpu)       key_cpu="cpu";;
          # полный набор pip3 модулей под GPU CU11.8
          cu11)       key_cu11="cu11";;
          # полный набор pip3 модулей под GPU CU12.1
          cu12)       key_cu12="cu12";;
          # установка под ups
          ups)       key_ups="ups";;
          # установка под urs
          urs)       key_urs="urs";;
          # установка под ses
          ses)       key_ses="ses";;
          # удалить внутренний архив (слишком большой для редактирования скрипта)
          n)         key_n="n";;
          # скопировать архив рядом со скриптом не распаковывая его
          e)         key_e="e";;
          # запаковать внешний архив в скрипт
          p)         key_p="p"; key_p_arg=$1;;
          # сделать архив и запаковать в скрипт из директории
          d)         key_d="d"; key_d_arg=$1;;
          # все остальные ключи
          *)         description_keys; exit 1;;
         esac;;
    esac
done

# массив ключей установки, все варианты ключей, при добалении нового ключа - дописать его СЮДА!
key_all=($key_i \
         $key_u \
         $key_on \
         $key_off \
         $key_b \
         $key_f \
         $key_cpu \
         $key_cu11 \
         $key_cu12 \
         $key_ups \
         $key_urs \
         $key_ses \
         $key_n \
         $key_e \
         $key_p \
         $key_d \
         )

# выборка вариантов совместных ключей
case $(echo ${key_all[@]} | tr -d ' ') in
  # онлайн установка с полным набором pip3 модулей под CPU
  ioncpu             ) install_repo online; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main; download_ffmpeg online;
                     install_ffmpeg online; install_pyenv online; install_pve online $int_pve_install_dir cpu; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir cpu; echo_info "Успех";;
  # онлайн обновление с полным набором pip3 модулей под CPU
  uoncpu|uponcpu     ) proxy_configuration set; uninstall_service $int_pve_install_dir clear; install_pyenv online; install_pve online $int_pve_install_dir cpu;
                     assign_rights $int_pve_install_dir; clear_temp; create_bash_script $int_pve_install_dir cpu; echo_info "Успех";;
  # онлайн установка с полным набором pip3 модулей под GPU CU11.8
  ioncu11            ) check_installed_gpu cu11; install_repo online; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main; download_ffmpeg online;
                     install_ffmpeg online; install_pyenv online; install_pve online $int_pve_install_dir cu11; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir cu11; echo_info "Успех";;
  # онлайн обновление с полным набором pip3 модулей под GPU CU11.8
  uoncu11|uponcu11   ) check_installed_gpu cu11; proxy_configuration set; uninstall_service $int_pve_install_dir clear; install_pyenv online; install_pve online $int_pve_install_dir cu11;
                     assign_rights $int_pve_install_dir; clear_temp; create_bash_script $int_pve_install_dir cu11; echo_info "Успех";;
  # онлайн установка с полным набором pip3 модулей под GPU CU12.1
  ioncu12            ) check_installed_gpu cu12; install_repo online; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main; download_ffmpeg online;
                     install_ffmpeg online; install_pyenv online; install_pve online $int_pve_install_dir cu12; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir cu12; echo_info "Успех";;
  # онлайн обновление с полным набором pip3 модулей под GPU CU12.1
  uoncu12|uponcu12   ) check_installed_gpu cu12; proxy_configuration set; uninstall_service $int_pve_install_dir clear; install_pyenv online; install_pve online $int_pve_install_dir cu12;
                     assign_rights $int_pve_install_dir; clear_temp; create_bash_script $int_pve_install_dir cu12; echo_info "Успех";;
  # онлайн установка PVE для UPS
  ionups             ) install_repo online; uninstall_service $int_ups_install_dir clear; install_pac system; install_pac main;
                     install_pyenv online; install_pve online $int_ups_install_dir ups; assign_rights $int_ups_install_dir; clear_temp;
                     create_bash_script $int_ups_install_dir ups; echo_info "Успех";;
  # онлайн обновление PVE для UPS
  uonups|uponups     ) proxy_configuration set; uninstall_service $int_ups_install_dir clear; install_pyenv online; install_pve online $int_ups_install_dir ups;
                     assign_rights $int_ups_install_dir; clear_temp; create_bash_script $int_ups_install_dir ups; echo_info "Успех";;
  # онлайн установка PVE для URS
  ionurs             ) install_repo online; uninstall_service $int_urs_install_dir clear; install_pac system; install_pac main;
                     install_pyenv online; install_pve online $int_urs_install_dir urs; assign_rights $int_urs_install_dir; clear_temp;
                     create_bash_script $int_urs_install_dir urs; echo_info "Успех";;
  # онлайн обновление PVE для URS
  uonurs|uponurs     ) proxy_configuration set; uninstall_service $int_urs_install_dir clear; install_pyenv online; install_pve online $int_urs_install_dir urs;
                     assign_rights $int_urs_install_dir; clear_temp; create_bash_script $int_urs_install_dir urs; echo_info "Успех";;
  # онлайн установка PVE для SES
  ionses             ) install_repo online; uninstall_service $int_ses_install_dir clear; install_pac system; install_pac main;
                     install_pyenv online; install_pve online $int_ses_install_dir ses; assign_rights $int_ses_install_dir; clear_temp;
                     create_bash_script $int_ses_install_dir ses; echo_info "Успех";;
  # онлайн обновление PVE для SES
  uonses|uponses     ) proxy_configuration set; uninstall_service $int_ses_install_dir clear; install_pyenv online; install_pve online $int_ses_install_dir ses;
                     assign_rights $int_ses_install_dir; clear_temp; create_bash_script $int_ses_install_dir ses; echo_info "Успех";;
  # оффлайн установка с полным набором pip3 модулей под CPU
  ioffcpu            ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cpu $build_modules; install_repo offline; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main;
                     install_ffmpeg offline; install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление с полным набором pip3 модулей под CPU
  uoffcpu|upoffcpu   ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cpu $build_modules; uninstall_service $int_pve_install_dir clear;
                     install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; echo_info "Успех";;
  # оффлайн установка с полным набором pip3 модулей под GPU CU11.8
  ioffcu11           ) check_installed_gpu cu11; extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cu11 $build_modules; install_repo offline; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main;
                     install_ffmpeg offline; install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление с полным набором pip3 модулей под GPU CU11.8
  uoffcu11|upoffcu11 ) check_installed_gpu cu11; extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cu11 $build_modules; uninstall_service $int_pve_install_dir clear;
                     install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; echo_info "Успех";;
  # оффлайн установка с полным набором pip3 модулей под GPU CU12.1
  ioffcu12           ) check_installed_gpu cu12; extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cu12 $build_modules; install_repo offline; uninstall_service $int_pve_install_dir clear; install_pac system; install_pac main;
                     install_ffmpeg offline; install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; assign_rights $int_pve_install_dir; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление с полным набором pip3 модулей под GPU CU12.1
  uoffcu12|upoffcu12 ) check_installed_gpu cu12; extract_archive dir $int_arch_dir; offline_env; list_pip3_modules cu12 $build_modules; uninstall_service $int_pve_install_dir clear;
                     install_pyenv offline; install_pve offline $int_pve_install_dir offline; install_pve online $int_pve_install_dir online; clear_temp;
                     create_bash_script $int_pve_install_dir $build_modules; echo_info "Успех";;
  # оффлайн установка PVE для UPS
  ioffups            ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules ups $build_modules; install_repo offline; uninstall_service $int_ups_install_dir clear; install_pac system; install_pac main;
                     install_pyenv offline; install_pve offline $int_ups_install_dir offline; install_pve online $int_ups_install_dir online; assign_rights $int_ups_install_dir; clear_temp;
                     create_bash_script $int_ups_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление PVE для UPS
  uoffups|upoffups   ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules ups $build_modules; uninstall_service $int_ups_install_dir clear;
                     install_pyenv offline; install_pve offline $int_ups_install_dir offline; install_pve online $int_ups_install_dir online; assign_rights $int_ups_install_dir; clear_temp;
                     create_bash_script $int_ups_install_dir $build_modules; echo_info "Успех";;
  # оффлайн установка PVE для URS
  ioffurs            ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules urs $build_modules; install_repo offline; uninstall_service $int_urs_install_dir clear; install_pac system; install_pac main;
                     install_pyenv offline; install_pve offline $int_urs_install_dir offline; install_pve online $int_urs_install_dir online; assign_rights $int_urs_install_dir; clear_temp;
                     create_bash_script $int_urs_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление PVE для URS
  uoffurs|upoffurs   ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules urs $build_modules; uninstall_service $int_urs_install_dir clear;
                     install_pyenv offline; install_pve offline $int_urs_install_dir offline; install_pve online $int_urs_install_dir online; assign_rights $int_urs_install_dir; clear_temp;
                     create_bash_script $int_urs_install_dir $build_modules; echo_info "Успех";;
  # оффлайн установка PVE для SES
  ioffses            ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules ses $build_modules; install_repo offline; uninstall_service $int_ses_install_dir clear; install_pac system; install_pac main;
                     install_pyenv offline; install_pve offline $int_ses_install_dir offline; install_pve online $int_ses_install_dir online; assign_rights $int_ses_install_dir; clear_temp;
                     create_bash_script $int_ses_install_dir $build_modules; install_repo remlocal; echo_info "Успех";;
  # оффлайн обновление PVE для SES
  uoffses|upoffses   ) extract_archive dir $int_arch_dir; offline_env; list_pip3_modules ses $build_modules; uninstall_service $int_ses_install_dir clear;
                     install_pyenv offline; install_pve offline $int_ses_install_dir offline; install_pve online $int_ses_install_dir online; assign_rights $int_ses_install_dir; clear_temp;
                     create_bash_script $int_ses_install_dir $build_modules; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки с полным набором pip3 модулей под CPU
  ibf                ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules full; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"full\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_full-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления с полным набором pip3 модулей под CPU, без системных пакетов для обновления
  ubf|upbf           ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules full; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"full\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_full-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки с полным набором pip3 модулей под CPU
  ibcpu              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules cpu; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cpu\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cpu-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления с полным набором pip3 модулей под CPU, без системных пакетов для обновления
  ubcpu|upbcpu       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules cpu; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cpu\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cpu-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки с полным набором pip3 модулей под GPU CU11.8
  ibcu11              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules cu11; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cu11\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cu11-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления с полным набором pip3 модулей под GPU CU11.8, без системных пакетов для обновления
  ubcu11|upbcu11       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules cu11; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cu11\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cu11-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки с полным набором pip3 модулей под GPU CU12.1
  ibcu12              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules cu12; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cu12\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cu12-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления с полным набором pip3 модулей под GPU CU12.1, без системных пакетов для обновления
  ubcu12|upbcu12       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules cu12; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_pve_install_dir\"" "build_modules=\"cu12\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_cu12-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки для UPS
  ibups              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules ups; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_ups_install_dir\"" "build_modules=\"ups\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_ups-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления для UPS, без системных пакетов для обновления
  ubups|upbups       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules ups; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_ups_install_dir\"" "build_modules=\"ups\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_ups-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки для URS
  iburs              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules urs; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_urs_install_dir\"" "build_modules=\"urs\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_urs-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления для URS, без системных пакетов для обновления
  uburs|upburs       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules urs; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_urs_install_dir\"" "build_modules=\"urs\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_urs-update";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн установки для SES
  ibses              ) create_temp_dirs; install_repo online; install_pac system; download_pac; download_ffmpeg offline; install_pyenv online; download_modules ses; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_ses_install_dir\"" "build_modules=\"ses\"" "build_type=\"install\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_ses-${os_id}-${os_version}";
                     clear_temp; echo_info "Успех";;
  # сборка внутреннего архива для оффлайн обновления для SES, без системных пакетов для обновления
  ubses|upbses       ) create_temp_dirs; install_repo online; install_pac system; download_ffmpeg offline; install_pyenv online; download_modules ses; download_pyenv;
                     offline_env "int_pve_install_dir=\"$int_ses_install_dir\"" "build_modules=\"ses\"" "build_type=\"update\"" "build_os=\"${os_id}-${os_version}\""; create_arсhive $int_arch_dir; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz" "_ses-update";
                     clear_temp; echo_info "Успех";;
  # удалить внутренний архив (слишком большой для редактирования скрипта)
  n                  ) null_archive; echo_info "Успех";;
  # скопировать архив рядом со скриптом не распаковывая его
  e                  ) extract_archive; echo_info "Успех";;
  # распаковать архив в папку
  ed                 ) extract_archive dir $key_d_arg; echo_info "Успех";;
  # запаковать архив в скрипт
  p                  ) pack_archive $key_p_arg; clear_temp; echo_info "Успех";;
  # запаковать папку в архив и включить в скрипт
  pd                 ) create_arсhive $key_d_arg; pack_archive "$int_service_name-${int_version}-${int_release}.tar.gz"; clear_temp; echo_info "Успех";;
  # удалить окружение
  u                  ) uninstall_service $int_pve_install_dir; echo_info "Успех";;
  # все остальные ключи
  *           ) description_keys; exit 1;;
esac

echo -e ""; exit 0
__PAYLOAD_BEGINS__