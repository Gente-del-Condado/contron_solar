#!/bin/bash
# install_mqtt_control_full.sh
# Instalación y desinstalación guiada del servicio MQTT Control para Raspberry Pi

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

echo "=== Instalador / Desinstalador MQTT Control ==="
echo "1) Instalar/Actualizar"
echo "2) Desinstalar"
read -p "Seleccione opción [1/2]: " OPTION

if [[ "$OPTION" == "1" ]]; then
    echo "=== Instalación / Actualización ==="

    # 1️⃣ Comprobar mosquitto_sub
    if ! command -v mosquitto_sub &> /dev/null; then
        read -p "mosquitto_sub no está instalado. ¿Desea instalarlo? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt update
            sudo apt install -y mosquitto-clients
        else
            echo "mosquitto_sub necesario. Saliendo."
            exit 1
        fi
    fi

    # 2️⃣ Preguntar si usar usuario por defecto o crear uno nuevo
    read -p "¿Desea usar el usuario MQTT por defecto '$MQTT_USER' con contraseña '$MQTT_PASS'? [Y/n]: " ans_default
    if [[ "$ans_default" =~ ^[Nn]$ ]]; then
        read -p "Ingrese el nuevo usuario MQTT: " MQTT_USER
        read -s -p "Ingrese la contraseña para $MQTT_USER: " MQTT_PASS
        echo
    else
        echo "Usando usuario por defecto: $MQTT_USER"
    fi

    # 3️⃣ Comprobar usuario MQTT en Mosquitto
    MOSQ_PASSWD_FILE="/etc/mosquitto/passwd"
    if [ ! -f "$MOSQ_PASSWD_FILE" ] || ! grep -q "^$MQTT_USER:" "$MOSQ_PASSWD_FILE"; then
        read -p "El usuario MQTT '$MQTT_USER' no existe en Mosquitto. ¿Desea crearlo? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo touch "$MOSQ_PASSWD_FILE"
            sudo mosquitto_passwd -b "$MOSQ_PASSWD_FILE" "$MQTT_USER" "$MQTT_PASS"
            echo "Usuario MQTT '$MQTT_USER' creado en $MOSQ_PASSWD_FILE"
        else
            echo "Se requiere un usuario MQTT. Saliendo."
            exit 1
        fi
    fi

    # 4️⃣ Crear log si no existe
    if [ ! -f "$LOGFILE" ]; then
        sudo touch $LOGFILE
        sudo chmod 644 $LOGFILE
        echo "Log creado en $LOGFILE"
    fi

    # 5️⃣ Crear script MQTT
    if [ -f "$SCRIPT_PATH" ]; then
        echo "Se detectó script existente en $SCRIPT_PATH"
        sudo cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup_$TIMESTAMP"
        echo "Backup creado: ${SCRIPT_PATH}.backup_$TIMESTAMP"
    fi

    read -p "¿Desea crear/actualizar el script MQTT en $SCRIPT_PATH? [y/N]: " ans
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
            sudo reboot
            ;;
        SHUTDOWN)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Apagando Raspberry..." >> \$LOGFILE
            sudo shutdown now
            ;;
        UPDATE)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Actualizando sistema..." >> \$LOGFILE
            sudo apt update && sudo apt upgrade -y
            ;;
        ON)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Encendiendo pantalla..." >> \$LOGFILE
            export DISPLAY=:0
            export XAUTHORITY=/home/$XUSER/.Xauthority
            xset dpms force on
            xset s reset
            ;;
        OFF)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Apagando pantalla..." >> \$LOGFILE
            export DISPLAY=:0
            export XAUTHORITY=/home/$XUSER/.Xauthority
            xset dpms force off
            ;;
        *)
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - Comando no reconocido: \$CMD" >> \$LOGFILE
            ;;
    esac
done
EOF
        sudo chmod +x $SCRIPT_PATH
        echo "Script creado/actualizado en $SCRIPT_PATH"
    fi

    # 6️⃣ Crear service systemd
    if [ -f "$SERVICE_PATH" ]; then
        echo "Se detectó service existente en $SERVICE_PATH"
        sudo cp "$SERVICE_PATH" "${SERVICE_PATH}.backup_$TIMESTAMP"
        echo "Backup creado: ${SERVICE_PATH}.backup_$TIMESTAMP"
    fi

    read -p "¿Desea crear/actualizar el service systemd en $SERVICE_PATH? [y/N]: " ans
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
        echo "Service creado y arrancado."
    fi

    echo "Instalación/actualización finalizada. Ver logs en $LOGFILE"

elif [[ "$OPTION" == "2" ]]; then
    echo "=== Desinstalación ==="

    # Detener servicio
    if systemctl is-active --quiet mqtt-control.service; then
        sudo systemctl stop mqtt-control.service
    fi

    # Deshabilitar y eliminar service
    if [ -f "$SERVICE_PATH" ]; then
        sudo systemctl disable mqtt-control.service
        sudo rm -f "$SERVICE_PATH"
        sudo systemctl daemon-reload
        echo "Service eliminado."
    fi

    # Eliminar usuario MQTT (lista y preguntar)
    MOSQ_PASSWD_FILE="/etc/mosquitto/passwd"
    if [ -f "$MOSQ_PASSWD_FILE" ]; then
        USERS=$(cut -d: -f1 "$MOSQ_PASSWD_FILE")
        if [ -n "$USERS" ]; then
            echo "Usuarios MQTT existentes:"
            echo "$USERS"
            read -p "Ingrese el usuario que desea eliminar (o enter para saltar): " del_user
            if [ -n "$del_user" ]; then
                sudo mosquitto_passwd -D "$MOSQ_PASSWD_FILE" "$del_user"
                echo "Usuario MQTT '$del_user' eliminado."
            fi
        fi
    fi

    # Borrar script MQTT
    if [ -f "$SCRIPT_PATH" ]; then
        read -p "¿Desea hacer backup del script antes de borrarlo? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup_$TIMESTAMP"
            echo "Backup creado: ${SCRIPT_PATH}.backup_$TIMESTAMP"
        fi
        sudo rm -f "$SCRIPT_PATH"
        echo "Script eliminado."
    fi

    # Borrar log
    if [ -f "$LOGFILE" ]; then
        read -p "¿Desea borrar el log $LOGFILE? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo rm -f "$LOGFILE"
            echo "Log eliminado."
        fi
    fi

    echo "Desinstalación finalizada."

else
    echo "Opción no válida. Saliendo."
    exit 1
fi
