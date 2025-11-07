#!/usr/bin/env bash

rline="\e[0m\r\033[K"
reset='\e[0m'
cyan='\e[38:2:1:190:192m'
rojo='\e[38:2:254:61:67m'
verde='\e[38:2:51:253:78m'

errorMsj() { # mostrar mensaje de error con cuenta regresiva
	for i in {1..3}; do
		echo -en "${rline}${rojo}${1} ${cyan}reintentando en $((4 - $i))${reset}"
		sleep 1
		echo -en "$rline"
	done
}

genNetplan() {
	local interna="$1"
	local ip="$2"
	local prefix="$3"

	cat <<EOF >/etc/netplan/01-ipfija.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $interna:
      dhcp4: no
      addresses:
        - ${ip}/${prefix}
EOF
}

reiniciarNM() {
    echo -en "Reiniciando NetworkManager..."
    if systemctl restart NetworkManager; then
        echo -e "${rline}Reiniciando NetworkManager... ${verde}OK${reset}"
    else
        echo -e "${rline}Reiniciando NetworkManager... ${rojo}FAILED${reset}"
    fi

    echo -e "Estado actual de interfaces:${cyan}"
    nmcli device status
    echo -en "$reset"
}

habilitarNetworkd() {
    echo -en "Habilitando y arrancando systemd-networkd..."
    systemctl enable systemd-networkd > /dev/null 2>&1
    if systemctl start systemd-networkd &> /dev/null; then
        echo -e "${rline}Habilitando y arrancando systemd-networkd... ${verde}OK${reset}"
    else
        echo -e "${rline}Habilitando y arrancando systemd-networkd... ${rojo}FAILED${reset}"
    fi
}

ignorarInterfacesNM() {
	local nmConf="${@: -1}"  # último parámetro
    local ignoredInterfaces=("${@:1:$#-1}")  # todos menos último

    echo -e "${verde}Configurando NetworkManager para ignorar interfaces: ${ignoredInterfaces[*]}${reset}\n"

    # Si no existe sección [keyfile], agregarla
    if ! grep -q "^\[keyfile\]" "$nmConf"; then
        echo -e "\n[keyfile]" | tee -a "$nmConf" >/dev/null
    fi

    # Construir línea unmanaged-devices
    unmanagedLine="unmanaged-devices="
    for iface in "${ignoredInterfaces[@]}"; do
        unmanagedLine+="interface-name:${iface};"
    done
    unmanagedLine=${unmanagedLine%;} # quitar ; final

    # Reemplazar o agregar unmanaged-devices
    if grep -q "^unmanaged-devices=" "$nmConf"; then
        sed -i "s|^unmanaged-devices=.*|$unmanagedLine|" "$nmConf"
    else
        sed -i "/^\[keyfile\]/a $unmanagedLine" "$nmConf"
    fi

    echo -e "Archivo actualizado:${verde}"
    grep -A2 "^\[keyfile\]" "$nmConf"
    echo -en "$reset"
}

validarIP() {
	local ip=$1

	# Verifica patrón general: 4 grupos de 1-3 dígitos separados por puntos
	if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		# Divide en octetos y verifica cada rango
		IFS='.' read -r -r o1 o2 o3 o4 <<<"$ip"
		for octeto in $o1 $o2 $o3 $o4; do
			if ((octeto < 0 || octeto > 255)); then
				return 1
			fi
		done
		return 0
	else
		return 1
	fi
}

# verificar si es NO super usuario (Effective User ID -not equal- 0) para mostrar mensaje de alerta
[[ $EUID -ne 0 ]] && { echo -e "${rojo}Debes ser superusuario pibe, deja de cagar!!"; exit 1; }

while true; do
	echo -e "${cyan}Qué querés hacer pibe?:$reset"
	# menú interactivo
	select eleccion in salir "actualizar repositorios" "instalar dependencias" "configurar pasarela"; do
		case $eleccion in
			salir) # pa salir
				echo -e "${verde}vale bro, adiós...${reset}"
				exit 0
				;;
			configurar*) # pa configurar kea
				ifaceIN=""
				ifaceEX=""
				echo -en "listando interfaces..."
				while read eth; do
					ethernets+=("$eth")
				done < <( nmcli device status | grep "ethernet" | awk '{print $1}' )
				while read wless; do
					wireless+=("$wless")
				done < <( iw dev | grep "Interface" | awk '{ print $2 }' )
				echo -e "$rline${verde}listando interfaces... Listo :D$reset"
				while true; do
					echo -e "${cyan}elige la interfaz interna (por su número):$reset"
					select ifaceInterna in "${ethernets[@]}"; do
						if [[ ! -z "$ifaceInterna" ]]; then
							echo -e "${verde}Interfaz interna elegida: ${cyan}$ifaceInterna$reset"
							echo -en "Querés continuar con esa interfaz?(s/n): $cyan"
							read siono
							if [[ "$siono" =~ ^[Ss]$ ]]; then
								echo -e "${verde}vale...$reset"
								ifaceIN="$ifaceInterna"
								break
							elif [[ "$siono" =~ ^[Nn]$ ]]; then
								echo -e "${verde}vale, a elegir otra vez...$reset"
							fi
						else
							errorMsj "colocá algo válido pibe, no seas así..."
						fi
					done
					echo -e "${cyan}elige la interfaz externa (por su número):$reset"
					select ifaceExterna in "${ethernets[@]}" "${wireless[@]}"; do
						if [[ ! -z "$ifaceExterna" ]]; then
							echo -e "${verde}Interfaz externa elegida: ${cyan}$ifaceExterna$reset"
							echo -en "Querés continuar con esa interfaz?(s/n): $cyan"
							read siono
							if [[ "$siono" =~ ^[Ss]$ ]]; then
								echo -e "${verde}vale...$reset"
								ifaceEX="$ifaceExterna"
								break
							elif [[ "$siono" =~ ^[Nn]$ ]]; then
								echo -e "${verde}vale, a elegir otra vez...$reset"
							fi
						else
							errorMsj "colocá algo válido pibe, no seas así..."
						fi
					done
					[[ $ifaceIN == $ifaceEX ]] && { echo -e "${rojo} no podes usar la misma interfaz pa dos cosas diferentes..."; continue; }
					break
				done
				echo -e "interfaz interna: $ifaceIN\ninterfaz externa: $ifaceEX"

				while true; do
					echo -en "ip de $ifaceIN: "
					read ip
					! validarIP $ip && { errorMsj "colocá algo válido pibe, no seas así..."; continue; }
					echo -en "netmask de $infaceIN: "
					read nm
					! validarIP $nm && { errorMsj "colocá algo válido pibe, no seas así..."; continue; }
					break
				done
				[[ -f  /etc/kea/kea-dhcp4.conf ]] && cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.copia
				
				cat <<EOF >/etc/kea/kea-dhcp4.conf
{
    "Dhcp4": {
        "interfaces-config": {
            "interfaces": [ "$ifaceIN" ]
        },
        "lease-database": {
            "type": "memfile",
            "lfc-interval": 3600
        },
        "valid-lifetime": 3600,
        "max-valid-lifetime": 7200,
        "subnet4": [
            {
                "id": 1,
                "subnet": "192.168.11.0/24",
                "pools": [
                    { "pool": "192.168.11.2 - 192.168.11.100" }
                ],
                "option-data": [
                    { "name": "routers", "data": "192.168.11.1" },
                    { "name": "domain-name-servers", "data": "8.8.8.8, 192.168.11.1" }
                ]
            }
        ],
        "loggers": [
            {
                "name": "kea-dhcp4",
                "output_options": [
                    {
                        "output": "/var/log/kea-dhcp4.log",
                        "maxsize": 2048000,
                        "maxver": 4
                    }
                ],
                "severity": "INFO",
                "debuglevel": 0
            }
        ]
    }
}
EOF				
				break
				;;
			instalar*) # pa instalar dependencias de la pasarela
				echo -e "${verde}instalando dependencias...$reset"
				export DEBIAN_FRONTEND=noninteractive # desactiva interactividad (dialogos al instalar paquetes)
				for dependencia in iptables-persistent kea-dhcp4-server iw; do
					echo -en "$verde - instalando $dependencia"
					if dpkg -s $dependencia &> /dev/null; then
						echo -e "$rline$verde - $dependencia ya está instalado, no hace falta instalarlo...$reset"
					else
						echo 
						if apt install $dependencia -y &> /dev/null; then
							echo -e "$rline$verde - $dependencia instalado correctamente :D$reset"
						else
							echo -e "$rline$rojo - $dependencia falló al ser instalada :($reset"
						fi
					fi
				done
				echo -e "${verde}Listo$reset"
				break
				;;
			actualizar*) # pa actualizar repositorios y/o paquetes
				echo -en "${verde}actualizando repo...$reset"
				apt update &> /dev/null
				echo -en "${rline}${verde}actualizando repo... Listo :D$reset\n"
				echo -en "Querés también instalar actualizaciones de paquetes?(s/n): $cyan"
				read siono
				if [[ "$siono" =~ ^[Ss]$ ]]; then
					echo -e "${verde}vale, actualizando...$reset"
					export DEBIAN_FRONTEND=noninteractive
					apt upgrade -y &> /dev/null
				elif [[ "$siono" =~ ^[Nn]$ ]]; then
					echo -e "${verde}vale, no actualizo...$reset"
				fi
				break
				;;
			*)
				errorMsj "colocá algo válido pibe, no seas así..."
		esac
	done
done
