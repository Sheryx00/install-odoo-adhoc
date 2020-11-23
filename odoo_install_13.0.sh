#!/bin/bash
################################################################################
# Script for installing Odoo with Adhoc's addons on Ubuntu <= 20.4 (could be used for other version)
# 
# Fork of Yenthe Van Ginneken's repository

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# VARIABLES
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_ADDONS="$OE_HOME/custom/addons"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
INSTALL_PYAFIPWS="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 13.0
OE_VERSION="13.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="False"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Set the website name
WEBSITE_NAME="_"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="False"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/13.0/setup/install.html#debian-ubuntu
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n${GREEN}[+] Update Server ${NC}"
# universe package is for Ubuntu 18.x
# sudo add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo add-apt-repository ppa:linuxuprising/libpng12
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server & Odoo Dependencies
#--------------------------------------------------
echo -e "\n${GREEN}[+] Install PostgreSQL, Python 3 & pip3 ${NC}"
sudo apt-get -y install build-essential default-jre git gcc gdebi nodejs npm node-less libcups2-dev libjpeg-dev libldap2-dev libpng12-0 libsasl2-dev libssl-dev libxslt-dev libzip-dev postgresql-server-dev-all python3 python3-dev postgresql python3-dev python3-lxml python3-pip python3-setuptools python3-uno python3-venv python3-wheel unoconv unzip swig

echo -e "\n${GREEN}[+] Create the ODOO PostgreSQL User ${NC}"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

echo -e "\n${GREEN}[+] Install python packages ${NC}"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n${GREEN}[+] Install nodeJS NPM and rtlcss for LTR support ${NC}"
# sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n${GREEN}[+] Install wkhtml and place shortcuts on correct place for ODOO 13 ${NC}"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

#--------------------------------------------------
# Install pyafipws
#--------------------------------------------------
if [ $INSTALL_PYAFIPWS = "True" ]; then
  echo -e "\n${GREEN}[+] Install pyafipws with python3 ${NC}"
  git clone https://github.com/pyar/pyafipws.git -b py3k
  sudo python3 ./pyafipws/setup.py install
  rm -rf pyafipws
else
  echo "\n${RED}[-] pyafipws isn't installed due to the choice of the user!${NC}"

fi

echo -e "\n${GREEN}[+] Create ODOO user ${NC}"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n${GREEN}[+] Create Log directory ${NC}"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n${GREEN}[+] Install ODOO Server ${NC}"
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING--------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "---------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n${GREEN}[+] Added Enterprise code under $OE_HOME/enterprise/addons ${NC}"
    echo -e "\n${GREEN}[+] Installing Enterprise specific libraries ${NC}"
    sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n${GREEN}[+] Create custom module directory ${NC}"
sudo su $OE_USER -c "mkdir -p $OE_ADDONS"

echo -e "\n${GREEN}[+] Setting permissions on home folder ${NC}"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "\n${GREEN}[+] Create server config file ${NC}"
sudo touch /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Install ADHOC modules
#--------------------------------------------------

# Download Adhoc's modules
echo -e "\n${GREEN}[+] Download ADHOC modules ${NC}"
sudo -u $OE_USER wget https://github.com/ingadhoc/odoo-argentina/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-odoo-argentina.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/account-financial-tools/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-account-financial-tools.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/account-payment/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-account-payment.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/aeroo_reports/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-aeroo_reports.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/miscellaneous/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-miscellaneous.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/argentina-reporting/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-argentina-reporting.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/reporting-engine/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-reporting-engine.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/argentina-sale/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-argentina-sale.zip";
sudo -u $OE_USER wget https://github.com/ingadhoc/stock/archive/13.0.zip -O "$OE_ADDONS/ingadhoc-stock.zip";
sudo -u $OE_USER wget 'https://codeload.github.com/ingadhoc/odoo-argentina-ce/zip/13.0' -O "$OE_ADDONS/odoo-argentina-ce-13.0.zip";
sudo -u $OE_USER wget 'https://codeload.github.com/OCA/web/zip/13.0' -O "$OE_ADDONS/web-13.0.zip";
sudo -u $OE_USER wget 'https://codeload.github.com/OCA/web/zip/13.0' -O "$OE_ADDONS/web-13.0.zip";
sudo -u $OE_USER wget 'https://codeload.github.com/OCA/sale-workflow/zip/13.0' -O "$OE_ADDONS/sale-workflow-13.0.zip";
sudo -u $OE_USER wget 'https://codeload.github.com/OCA/partner-contact/zip/13.0' -O "$OE_ADDONS/partner-contact-13.0.zip";

# Extract the modules
echo -e "\n${GREEN}[+] Extract ADHOC modules ${NC}"
sudo -u $OE_USER unzip "$OE_ADDONS/*.zip" -d "$OE_ADDONS/";
sudo -u $OE_USER rm $OE_ADDONS/*.zip;

# Install dependencies
echo -e "\n${GREEN}[+] Install dependencies ${NC}"
cat << EOF > requeriments.txt
jsonrpc2
daemonize
EOF

find "$OE_ADDONS/" -name requirements.txt -exec grep -v '#' {} \; | sort | uniq >> requeriments.txt
sudo -u $OE_USER pip3 install -r requeriments.txt;
rm requeriments.txt;


#--------------------------------------------------
# Create server config file
#--------------------------------------------------
echo -e "\n${GREEN}[+] Create server config file ${NC}"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "\n ${GREEN} [+] Generating random admin password ${NC}"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"

if [ $OE_VERSION > "11.0" ];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,$OE_ADDONS,$OE_ADDONS/account-financial-tools-13.0,$OE_ADDONS/account-payment-13.0,$OE_ADDONS/aeroo_reports-13.0,$OE_ADDONS/argentina-reporting-13.0,$OE_ADDONS/argentina-sale-13.0,$OE_ADDONS/miscellaneous-13.0,$OE_ADDONS/odoo-argentina-13.0,$OE_ADDONS/odoo-argentina-ce-13.0,$OE_ADDONS/partner-contact-13.0,$OE_ADDONS/reporting-engine-13.0,$OE_ADDONS/sale-workflow-13.0,$OE_ADDONS/stock-13.0,$OE_ADDONS/web-13.0' >> ${OE_CONFIG}.conf"
fi


sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "\n${GREEN}[+] Create startup file ${NC}"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "\n${GREEN}[+] Create init file ${NC}"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "\n${GREEN}[+] Security Init File ${NC}"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "\n${GREEN}[+] Start ODOO on Startup ${NC}"
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n${GREEN}[+] Installing and setting up Nginx "
  sudo apt install nginx -y
  cat <<EOF > ~/odoo
  server {
  listen 80;

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
  text/less less;
  text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
  proxy_pass    http://127.0.0.1:$OE_PORT;
  # by default, do not forward anything
  proxy_redirect off;
  }

  location /longpolling {
  proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }
  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
  expires 2d;
  proxy_pass http://127.0.0.1:$OE_PORT;
  add_header Cache-Control "public, no-transform";
  }
  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
  proxy_cache_valid 200 302 60m;
  proxy_cache_valid 404      1m;
  proxy_buffering    on;
  expires 864000;
  proxy_pass    http://127.0.0.1:$OE_PORT;
  }
  }
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/odoo"
else
  echo "Nginx isn't installed due to choice of the user!"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  sudo apt-get install python-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload
  echo "SSL/HTTPS is enabled!"
else
  echo "SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration!"
fi

echo -e "\n ${GREEN} [+] Starting Odoo Service ${NC}"
sudo su root -c "/etc/init.d/$OE_CONFIG start"

#--------------------------------------------------
# BANNER
#--------------------------------------------------

echo "-------------------------------------------------------"
echo "[+] Done! The Odoo server is up and running. Specifications:"
echo "[+] Port: $OE_PORT"
echo "[+] User service: $OE_USER"
echo "[+] Configuration file location: /etc/${OE_CONFIG}.conf"
echo "[+] Logfile location: /var/log/$OE_USER"
echo "[+] User PostgreSQL: $OE_USER"
echo "[+] Code location: $OE_USER"
echo "[+] Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "[+] Password superadmin (database): $OE_SUPERADMIN"
echo "[+] Start Odoo service: sudo service $OE_CONFIG start"
echo "[+] Stop Odoo service: sudo service $OE_CONFIG stop"
echo "[+] Restart Odoo service: sudo service $OE_CONFIG restart"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/odoo"
fi
echo "-------------------------------------------------------"
