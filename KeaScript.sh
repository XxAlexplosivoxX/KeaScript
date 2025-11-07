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

select eleccion in salir continuar; do
	case $eleccion in
		salir)
			echo -e "${verde}vale bro, adiós...${reset}"
			exit 0
			;;
		continuar)
			break
			;;
		*)
			errorMsj "colocá algo válido pibe, no seas así..."
	esac
done
