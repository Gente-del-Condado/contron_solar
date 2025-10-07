# MQTT Control para Raspberry Pi / Solar-Assistant

Este proyecto proporciona un **script de instalación y desinstalación guiada** para un servicio de control de Raspberry Pi mediante MQTT. Permite ejecutar comandos remotos como reiniciar, apagar, actualizar el sistema o controlar la pantalla a través de mensajes MQTT.

El script crea:

- Un **usuario MQTT** (configurable).
- Un **script de escucha MQTT** (`mqtt_control.sh`).
- Un **servicio systemd** (`mqtt-control.service`) para ejecución automática.
- Archivos de **log** para registrar los comandos recibidos.

---

## Requisitos

- Raspberry Pi con **Raspberry OS / Debian /Solar-Assistant**.
- Broker MQTT instalado (Mosquitto recomendado).
- Acceso a `sudo`.

---

## Instalación
1. **Descargar el script de instalación**:

```bash
wget https://raw.githubusercontent.com/Gente-del-Condado/contron_solar/main/install-mqtt-control.sh -O install_mqtt_control.sh
```
2. **Dar permisos de ejecución**:
```
chmod +x install_mqtt_control.sh
```
2. **Ejecutar el instalador**:
```bash
./install_mqtt_control.sh
```
4. **Seguir las instrucciones en pantalla:**

Seleccionar 1) Instalar/Actualizar.

Elegir si se desea usar el usuario MQTT por defecto (solar / 123456) o crear uno nuevo.

Confirmar la creación del script de escucha y del servicio systemd.

El servicio se activará automáticamente y Mosquitto se recargará.

## Desinstalación
```bash
./install_mqtt_control.sh
```
Seleccionar 2) Desinstalar.

Confirmar la eliminación del servicio, script y logs.

Si se desea, eliminar usuarios MQTT existentes. El broker Mosquitto se recargará automáticamente para que los cambios tengan efecto inmediato.

## Comandos MQTT soportados

El script de escucha permite los siguientes comandos mediante mensajes MQTT:

| Comando    | Acción                                         |
| ---------- | ---------------------------------------------- |
| `RESTART`  | Reinicia la Raspberry Pi                       |
| `SHUTDOWN` | Apaga la Raspberry Pi                          |
| `UPDATE`   | Actualiza el sistema (`apt update && upgrade`) |
| `ON`       | Enciende la pantalla conectada                 |
| `OFF`      | Apaga la pantalla conectada                    |

Todos los comandos se registran en el archivo de log definido en la instalación (/var/log/mqtt_control.log por defecto).

## Archivos creados
| Archivo/Servicio                           | Descripción                                              |
| ------------------------------------------ | -------------------------------------------------------- |
| `/usr/local/bin/mqtt_control.sh`           | Script de escucha MQTT y ejecución de comandos           |
| `/etc/systemd/system/mqtt-control.service` | Servicio systemd para arrancar automáticamente el script |
| `/var/log/mqtt_control.log`                | Archivo de log de los comandos recibidos                 |
| `/etc/mosquitto/passwd`                    | Archivo de usuarios MQTT (modificado según elección)     |


## Personalización
Cambiar usuario/contraseña MQTT predeterminados:
```bash
MQTT_USER="nuevo_usuario"
MQTT_PASS="nueva_contraseña"
```
Cambiar topic de escucha MQTT:
```bash
TOPIC="raspberry/control/#"
```
Cambiar usuario X para control de pantalla (si se usa ON/OFF)
```bash
XUSER="nombre_usuario"
```
## Notas

Después de eliminar usuarios MQTT, Mosquitto se recarga automáticamente para que los cambios tomen efecto sin reiniciar la Raspberry Pi.

El script realiza backups automáticos de los archivos existentes antes de sobrescribirlos.

Puede usar el programa:
MQTT Explorer (windows) para comprobar su funcionamiento.
[Descargar MQTT Explorer](https://mqtt-explorer.com/)

## Licencia

Este proyecto está bajo la licencia MIT.

