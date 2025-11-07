#!/usr/bin/env bash

rline="\e[0m\r\033[K"
reset='\e[0m'
cyan='\e[38:2:1:190:192m'
rojo='\e[38:2:254:61:67m'
verde='\e[38:2:51:253:78m'

[[ $EUID -ne 0 ]] && { echo -e "${rojo}Debes ser superusuario pibe, deja de cagar!!"; exit 0; }
