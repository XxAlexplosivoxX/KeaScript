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
					if [[ ! -z "$ifaceExterna" || "$ifaceExterna" -ne "$ifaceIN" ]]; then
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
				echo -e "interfaz interna: $ifaceIN\ninterfaz externa: $ifaceEX"
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
