#!/bin/bash
# install_mqtt_control_full.sh
# Instalación y desinstalación guiada del servicio MQTT Control para Raspberry Pi
# Con colores ANSI en terminal, banners ASCII y mejor interactividad

# 🎨 Colores
RED='\033[0;31m'      # Rojo - errores
GREEN='\033[0;32m'    # Verde - éxito/confirmación
YELLOW='\033[1;33m'   # Amarillo - títulos/advertencias
BLUE='\033[1;34m'     # Azul - preguntas/prompts
CYAN='\033[0;36m'     # Cian - información
NC='\033[0m'          # Sin color (reset)

# Variables
BROKER="localhost"
MQTT_USER="solar"
MQTT_PASS="123456"
TOPIC="raspberry/control/#"
SCRIPT_PATH="/usr/local/bin/mqtt_control.sh"
LOGFILE="/var/log/mqtt_control.log"
SERVICE_PATH="/etc/systemd/system/mqtt-control.service"
XUSER="kiosk"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# === Funciones de banner ===
banner_install() {
    clear
    echo -e "${YELLOW}"
    echo "┌───────────────────────────────────────────┐"
    echo "│       INSTALACIÓN / ACTUALIZACIÓN         │"
    echo "│          MQTT CONTROL RASPBERRY           │"
    echo "└───────────────────────────────────────────┘"
    echo -e "${NC}"
}

banner_uninstall() {
    clear
    echo -e "${RED}"
    echo "┌───────────────────────────────────────────┐"
    echo "│               DESINSTALACIÓN              │"
    echo "│          MQTT CONTROL RASPBERRY           │"
    echo "└───────────────────────────────────────────┘"
    echo -e "${NC}"
}

separator() {
    echo -e "${CYAN}───────────────────────────────────────────${NC}"
}

# === Menú principal ===
clear
echo -e "${YELLOW}"
echo -e "┌───────────────────┐"
echo -e "│   MENÚ PRINCIPAL  │"
echo -e "│   MQTT CONTROL    │"
echo -e "│         X         │"
echo -e "│ Gente del Condado │"
echo -e "└───────────────────┘"
echo -e "${NC}"
echo -e "${GREEN}1) Instalar/Actualizar${NC}"
echo -e "${RED}2) Desinstalar${NC}"
echo -ne "${BLUE}Seleccione opción [1/2]: ${NC}"
read OPTION

if [[ "$OPTION" == "1" ]]; then
    banner_install
    separator
    echo -e "${YELLOW}Preparando instalación / actualización...${NC}"
    separator

    # 1️⃣ Comprobar mosquitto_sub
    if ! command -v mosquitto_sub &> /dev/null; then
        separator
        echo -ne "${BLUE}mosquitto_sub no está instalado. ¿Desea instalarlo? [y/N]: ${NC}"
        read ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt update
            sudo apt install -y mosquitto-clients
        else
            echo -e "${RED}mosquitto_sub necesario. Saliendo.${NC}"
            exit 1
        fi
    fi

    # 2️⃣ Preguntar usuario MQTT
    separator
    echo -ne "${BLUE}¿Desea usar el usuario MQTT por defecto '$MQTT_USER'? [Y/n]: ${NC}"
    read ans_default
    if [[ "$ans_default" =~ ^[Nn]$ ]]; then
        echo -ne "${BLUE}Ingrese el nuevo usuario MQTT: ${NC}"
        read MQTT_USER
        echo -ne "${BLUE}Ingrese la contraseña para $MQTT_USER: ${NC}"
        read -s MQTT_PASS
        echo
    else
        echo -e "${GREEN}Usando usuario por defecto: $MQTT_USER${NC}"
    fi

    # 3️⃣ Comprobar/crear usuario MQTT
    MOSQ_PASSWD_FILE="/etc/mosquitto/passwd"
    if [ ! -f "$MOSQ_PASSWD_FILE" ] || ! grep -q "^$MQTT_USER:" "$MOSQ_PASSWD_FILE"; then
        separator
        echo -ne "${BLUE}El usuario MQTT '$MQTT_USER' no existe. ¿Desea crearlo? [y/N]: ${NC}"
        read ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo touch "$MOSQ_PASSWD_FILE"
            sudo mosquitto_passwd -b "$MOSQ_PASSWD_FILE" "$MQTT_USER" "$MQTT_PASS"
            echo -e "${GREEN}Usuario MQTT '$MQTT_USER' creado.${NC}"
        else
            echo -e "${RED}Se requiere un usuario MQTT. Saliendo.${NC}"
            exit 1
        fi
    fi

    # 4️⃣ Crear log si no existe
    if [ ! -f "$LOGFILE" ]; then
        sudo touch $LOGFILE
        sudo chmod 644 $LOGFILE
        echo -e "${GREEN}Log creado en $LOGFILE${NC}"
    fi

    # 5️⃣ Crear script MQTT
    separator
    if [ -f "$SCRIPT_PATH" ]; then
        echo -e "${YELLOW}Se detectó script existente en $SCRIPT_PATH${NC}"
        sudo cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup_$TIMESTAMP"
        echo -e "${GREEN}Backup creado: ${SCRIPT_PATH}.backup_$TIMESTAMP${NC}"
    fi
    echo -ne "${BLUE}¿Desea crear/actualizar el script MQTT? [y/N]: ${NC}"
    read ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo tee $SCRIPT_PATH > /dev/null << EOF
#!/bin/bash
BROKER="$BROKER"
TOPIC="$TOPIC"
LOGFILE="$LOGFILE"
mosquitto_sub -h \$BROKER -u $MQTT_USER -P $MQTT_PASS -t \$TOPIC | while read -r PAYLOAD
do
    CMD=\$(echo "\$PAYLOAD" | tr -d '\r' | tr '[:lower:]' '[:upper:]')
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - Recibido: '\$CMD'" >> \$LOGFILE
    case \$CMD in
        RESTART)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Reiniciando Raspberry..." >> \$LOGFILE
            sudo reboot ;;
        SHUTDOWN)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Apagando Raspberry..." >> \$LOGFILE
            sudo shutdown now ;;
        UPDATE)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Actualizando sistema..." >> \$LOGFILE
            sudo apt update && sudo apt upgrade -y ;;
        ON)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Encendiendo pantalla..." >> \$LOGFILE
            export DISPLAY=:0
            export XAUTHORITY=/home/$XUSER/.Xauthority
            xset dpms force on
            xset s reset ;;
        OFF)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Apagando pantalla..." >> \$LOGFILE
            export DISPLAY=:0
            export XAUTHORITY=/home/$XUSER/.Xauthority
            xset dpms force off ;;
        *)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Comando no reconocido: \$CMD" >> \$LOGFILE ;;
    esac
done
EOF
        sudo chmod +x $SCRIPT_PATH
        echo -e "${GREEN}Script creado/actualizado.${NC}"
    fi

    # 6️⃣ Crear service systemd
    separator
    if [ -f "$SERVICE_PATH" ]; then
        echo -e "${YELLOW}Se detectó service existente${NC}"
        sudo cp "$SERVICE_PATH" "${SERVICE_PATH}.backup_$TIMESTAMP"
        echo -e "${GREEN}Backup creado: ${SERVICE_PATH}.backup_$TIMESTAMP${NC}"
    fi
    echo -ne "${BLUE}¿Desea crear/actualizar el service systemd? [y/N]: ${NC}"
    read ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        sudo tee $SERVICE_PATH > /dev/null << EOF
[Unit]
Description=MQTT Control Service for Raspberry Pi
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
User=root
Environment="PATH=/usr/bin:/bin:/usr/sbin:/sbin"
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/$XUSER/.Xauthority"

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable mqtt-control.service
        sudo systemctl restart mqtt-control.service
        echo -e "${GREEN}Service creado y arrancado.${NC}"
        echo -e "${YELLOW}Recargando Mosquitto...${NC}"
        sudo systemctl restart mosquitto
    fi

    separator
    echo -e "${GREEN}Instalación/actualización finalizada. Ver logs en $LOGFILE${NC}"
	echo -e "${CYAN}Puede ver el estado del servicio con. systemctl status mqtt-control.service{NC}"

elif [[ "$OPTION" == "2" ]]; then
    banner_uninstall
    separator
    echo -e "${RED}Preparando desinstalación...${NC}"
    separator

    # Detener servicio
    if systemctl is-active --quiet mqtt-control.service; then
        sudo systemctl stop mqtt-control.service
    fi

    # Deshabilitar y eliminar service
    if [ -f "$SERVICE_PATH" ]; then
        sudo systemctl disable mqtt-control.service
        sudo rm -f "$SERVICE_PATH"
        sudo systemctl daemon-reload
        echo -e "${GREEN}Service eliminado.${NC}"
    fi

    # Eliminar usuario MQTT
    MOSQ_PASSWD_FILE="/etc/mosquitto/passwd"
    if [ -f "$MOSQ_PASSWD_FILE" ]; then
        USERS=$(cut -d: -f1 "$MOSQ_PASSWD_FILE")
        if [ -n "$USERS" ]; then
            echo -e "${BLUE}Usuarios MQTT existentes:${NC}"
            echo "$USERS"
            echo -ne "${BLUE}Ingrese el usuario que desea eliminar (o enter para saltar): ${NC}"
            read del_user
            if [ -n "$del_user" ]; then
                sudo mosquitto_passwd -D "$MOSQ_PASSWD_FILE" "$del_user"
                echo -e "${GREEN}Usuario MQTT '$del_user' eliminado.${NC}"
                echo -e "${YELLOW}Recargando Mosquitto...${NC}"
                sudo systemctl restart mosquitto
            fi
        fi
    fi

    # Borrar script MQTT
    if [ -f "$SCRIPT_PATH" ]; then
        separator
        echo -ne "${BLUE}¿Desea hacer backup del script antes de borrarlo? [y/N]: ${NC}"
        read ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup_$TIMESTAMP"
            echo -e "${GREEN}Backup creado.${NC}"
        fi
        sudo rm -f "$SCRIPT_PATH"
        echo -e "${GREEN}Script eliminado.${NC}"
    fi

    # Borrar log
    if [ -f "$LOGFILE" ]; then
        echo -ne "${BLUE}¿Desea borrar el log $LOGFILE? [y/N]: ${NC}"
        read ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo rm -f "$LOGFILE"
            echo -e "${GREEN}Log eliminado.${NC}"
        fi
    fi

    separator
    echo -e "${GREEN}Desinstalación finalizada.${NC}"

else
    echo -e "${RED}Opción no válida. Saliendo.${NC}"
    exit 1
fi
