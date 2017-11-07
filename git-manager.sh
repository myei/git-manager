#!/bin/bash
##############################################################
#
# 										Creado por: Manuel Gil
#
# Este script interactivo permite:
#
# - Autenticar el cliente con el servidor mediante:
# 			> pem (default)
# 			> rsa
# 
# 	Incluyendo generación de llaves y registro de
#	credenciales
#
# - Crear repositorio Git en el servidor permitiendo
# 	el uso compartido
#
# - Enlazar el proyecto con el repositorio y sincronizar 
# 	el estado del mismo automáticamente al servidor
#
# - Clonar uno o varios repositorios a la vez, incluidas
# 	todas sus ramas remotas y seteando upstreams para cada una
# 
# - Eliminar uno o varios repositorios a la vez
#
# - Autoinstalación del script
#
# -	Autoinstalación de paquetes necesarios, manejadores de
# 	paquetes soportados por ahora:
#			> dpkg
#			> pacman
#			> yum
#
#	Para el resto se permite la instalación manual desde el
#	script
# 
# - Servicio de logs en tiempo real e historico descriptivos
# 	de uso
# 
# - Ampliamente validado y flexible
# 
# 														v3.1
#
##############################################################

##############################################################
#					G L O B A L E S
##############################################################

# C O L O R S
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\e[95m'
WHITE='\e[97m'
YELLOW='\e[93m'
NC='\033[0m'

# F O N T S
BOLD='\e[1m'
NF='\e[0m'
BLINK='\e[5m'
I='\e[3m'
S='\e[4m'

# S Í M B O L O S
GOOD='\u2714'
BAD='\u2718'
ARROW='\u27a1'
HAND="\u261b"

repoSelected=""

# S T A T I C
isNumber="^-?[0-9]+([.][0-9]+)?$"
USERIP=$(hostname --ip-address)
USER=$(whoami)
USERHOME=$(ls -m /home)

# C O N F I G U R A C I Ó N
SERVER_NAME="DEMO SERVER"		# name of server
SERVER='demo@demo.com'			# user@server
PORT='5050'						# ssh port
REPOS_PATH='/path/to/repos/'	# path to repos in server
REMOTE_NAME='demo'				# git default remote name
SCRIPT_NAME='git-admin'			# name to call this script
AUTHENTICATION='pem' 			# pem or rsa (default rsa)
CREDENCIAL='GIT.pem'			# if $AUTHENTICATION is pem
PASSWORD='' 					# if $AUTHENTICATION is rsa

clearForReal() { printf "\ec"; }

##############################################################
#						M E N Ú
##############################################################
clearForReal
printf "\n 	  :: Bienvenido al ${BOLD}${PURPLE}${SCRIPT_NAME}${NF} ::\n\n"
printf " ${CYAN}${BOLD}Que acción desea realizar?${NF} \n\n${NC}"
printf "  [${CYAN}${BOLD}1${NC}] Autenticarme con el Servidor [${RED}${BOLD}root${NC}] (${BLUE}${BOLD}Sólo la primera vez${NC})\n"
printf "  [${CYAN}${BOLD}2${NC}] Crear repositorio y enlazar \n"
printf "  [${CYAN}${BOLD}3${NC}] Clonar repositorio \n"
printf "  [${CYAN}${BOLD}4${NC}] Eliminar repositorio \n"
printf "  [${CYAN}${BOLD}5${NC}] Histórico \n"
printf "  [${CYAN}${BOLD}6${NC}] Log \n"

if [[ $(echo $(readlink -f $0) | grep '/usr/bin/') = '' ]]; then
	printf "  [${CYAN}${BOLD}7${NC}] Registrar script (${BLUE}${BOLD}Sólo la primera vez${NC})\n"
fi

printf "  [${CYAN}${BOLD}x${NC}] Salir \n"

printf "\n${CYAN}${BOLD} Opción: ${NC}${BOLD}"
read -n 1 option
# clearForReal

sendMsg() {
	if [[ $1 = "ERROR" ]]; then
		color=$RED
	elif [[ $1 = "INFO" ]]; then
		color=$CYAN
	elif [[ $1 = "WARN" ]]; then
		color=$YELLOW
	elif [[ $1 = "GOOD" ]]; then
		color=$GREEN
	else
		color=$WHITE
	fi

	printf "\n${color}${BOLD} $2${NC}\n\n"

	if [[ $1 = "ERROR" ]]; then
		exit 1
	fi
}

validateCertificate() {
	printf "\n\n${CYAN} ${BOLD}Validando credenciales...${NC}"

	if [[ $AUTHENTICATION = "pem" ]]; then
		if [[ $(grep -lir $CREDENCIAL /etc/ssh/ssh_config) = "" ]]; then
			printf "${RED}${BOLD} ${BAD}\n"
			sendMsg ERROR "No estas autenticado con el servidor, debes ejecutar la primera opción y autenticarte correctamente"
		fi
		printf "${GREEN}${BOLD} ${GOOD}${NC}\n"
	else
		if [ ! -f ~/.ssh/id_rsa ]; then
			sendMsg INFO "Autenticando con el $SERVER_NAME..."
			sendMsg INFO "Generando clave..."
			ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q -N "" &>/dev/null
			$(ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "$(declare -f); logger AUTHENTICATE $USERIP $USER $USERHOME");
		fi

		validatePackage sshpass
		sshpass -p $PASSWORD ssh-copy-id -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT &>/dev/null
		validateConnection $?
		printf "${GREEN}${BOLD} ${GOOD}${NC}\n"
	fi
}

validateConnection() {
	if [[ $1 != 0 ]]; then
		sendMsg ERROR "No se pudo conectar con el servidor $SERVER_NAME, verifique su conexión a internet"
	fi
}

saveScript() {
	if [[ $(echo $(readlink -f $0) | grep '/usr/bin/') = '' ]]; then
		if [[ -f /usr/bin/$SCRIPT_NAME || -L /usr/bin/$SCRIPT_NAME ]]; then
			printf "\n\n"
			sudo rm /usr/bin/$SCRIPT_NAME
		fi
		
		sudo cp $(readlink -f $0) /usr/bin/$SCRIPT_NAME
	fi
}

confirm() {
	printf " $1${BOLD}$2$1${BOLD}? [Y/n]: ${WHITE}"
	read -n 1 confirm
	printf "${NC}\n"

	if [[ $confirm != "Y" && $confirm != "y" && $confirm != "" ]]; then
		sendMsg ERROR "\n Operación abortada..."
	fi
}

whereDoICLone() {
	printf "\n ${CYAN}${BOLD}Dime donde lo clono? [$(pwd)"/"${repository:0:-4}]: ${WHITE}"
	read -p "" -e choice
	printf "${NC}\n"

	if [[ $choice = "" ]]; then
		direc=$(pwd)"/"${repository:0:-4}
	else
		direc=$choice
	fi
}

pressEnter() {
	printf "\n${CYAN}${BOLD} Presiona Enter para $1...${NC}"
	read -p ""
}

validatePackage() {
	if [[ $(ls /usr/bin/ | grep $1) = '' ]]; then
		sendMsg INFO "\n Instalando paquete necesario..."

		if [[ -f /usr/bin/dpkg ]]; then
			sudo apt-get install $1 -y
		elif [[ -f /usr/bin/pacman ]]; then
			sudo pacman -S $1 --noconfirm
		elif [[ -f /usr/bin/yum ]]; then
			sudo yum -y install $1
		else
			sendMsg WARN "\n Disculpa, no conozco tu manejador de paquetes, por favor ingresa el equivalente al siguiente comando en tu sistema: '${CYAN}${BOLD}apt-get install $1${YELLOW}${BOLD}' ${NC}${BOLD}"
			read -p " " comando
			sudo $comando
		fi
	fi

	if [[ $(ls /usr/bin/ | grep $1) = '' ]]; then
		sendMsg ERROR "El paquete ${WHITE}${BOLD}$1${RED}${BOLD} no se ha instalado y es ${WHITE}${BOLD}necesario${RED}${BOLD} para poder continuar"
		# validatePackage $1
	fi
}

logger() {
	logPath='/home/git/.log'

	if [[ ! -f $logPath ]]; then
		touch $logPath
	fi
	
	echo -e "\n -- $1 $2 $(date)" >> $logPath
	echo "    " $3 >> $logPath
	echo "    " $4 $5 >> $logPath
	echo " --" >> $logPath
}

if [[ ($(echo $(readlink -f $0) | grep '/usr/bin/') != '' && $option = "7")]]; then
	sendMsg ERROR "Ha salido del programa"
elif [[ $option != "1" && $option != "2" && $option != "3" && $option != "4" && $option != "5" && $option != "6" && $option != "7" ]]; then
	sendMsg ERROR "Ha salido del programa"
elif [[ $option = "1" ]]; then
	validatePackage git
	
	##############################################################
	#		V A L I D A C I O N E S   G E N E R A L E S
	##############################################################

	printf "\n"
	if [ $EUID -ne 0 ]; then
		sendMsg ERROR "Para acceder a esta opción debes ejecutar el script como root"
	fi

	if [[ $(grep -lir $CREDENCIAL /etc/ssh/ssh_config) != "" ]]; then
		confirm $YELLOW "\n Parece que ya te autenticaste... Quieres volver a hacerlo para solucionar algún problema"
	fi

	foundIt=false
	while [[ $foundIt = false ]]; do
		if [[ ! -f $certPath$CREDENCIAL ]]; then
			printf "${YELLOW}${BOLD} No encontré el certificado $CREDENCIAL, dime donde está?: ${NC}"
			read -p "" -e certPath
			certPath=$certPath"/"
			printf "\n"
		else
			foundIt=true
		fi
	done

	printf "${CYAN}${BOLD} Ingrese su usuario de linux:${NC} "
	read -p "" user
	if [[ ! -d /home/$user || $user = "" ]]; then
		sendMsg ERROR "Ese no es tu usuario, por favor ingresa el correcto"
	fi
	
	saveScript

	sendMsg INFO "Autenticando..."

	if [ ! -d /home/$user/.certs ]; then
		mkdir /home/$user/.certs
	fi

	if [ ! -f /etc/ssh/ssh_config ]; then
		touch /etc/ssh/ssh_config
	fi

	cp $certPath$CREDENCIAL /home/$user/.certs/
	chmod 600 /home/$user/.certs/$CREDENCIAL

	if [[ -f /usr/bin/dpkg ]]; then
		chown -R $user:$user /home/$user/.certs
	elif [[ -f /usr/bin/pacman ]]; then
		chown -R $user:users /home/$user/.certs
	fi


	echo -e "\n IdentityFile /home/$user/.certs/$CREDENCIAL" >> /etc/ssh/ssh_config

	$(ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "$(declare -f); logger AUTHENTICATE ${repository} $USERIP $USER $USERHOME");

	sendMsg GOOD "Autenticación exitosa, ahora puedes ejecutarme donde quieras como: '$SCRIPT_NAME'"

	pressEnter "salir"
	# exec $(readlink -f "$0")
	clearForReal
	exit

elif [[ $option = "3" || $option = "4" ]]; then
	validatePackage git
	validateCertificate

	##############################################################
	#	  L I S T A D O   D E   R E P O S I T O R I O S
	##############################################################

	printf "${CYAN}\n ${BOLD}Buscando repositorios...${NF}\n\n${NC}"

	array=($(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT ls $REPOS_PATH))

	validateConnection $?

	cont=0
	for item in ${array[*]}
	do
		printf "     [${CYAN}${BOLD}$cont${NC}] %s\n" $item
		let cont+=1
	done

	printf "\n ${CYAN}${BOLD}Seleccione repositorio(s) [0 1 ... n]:${WHITE} "
	read -p "" -a repoSelec
	printf "\n"
 
   	repository="clone"
fi

##############################################################
#		N O M B R E   D E L   R E P O S I T O R I O
##############################################################

if [[ $repository = "" && $option = "2" ]]; then
	validatePackage git
	validateCertificate
	
	printf "\n${CYAN}${BOLD} Nombre del respositorio a crear (${RED}${BOLD}sin .git${CYAN}${BOLD}) [$(basename $(pwd))]:${NC} "
	read -p "" newRepo
	printf "\n"
	if [[ $newRepo = "" ]]; then
	    newRepo=$(basename $(pwd))
	fi
	repository=$newRepo".git"

	##############################################################
	#		C O N F I G U R A C I Ó N   D E L   S E R V I D O R
	##############################################################

	confirm "${YELLOW}" "Está seguro de crear el repositorio ${I}'$repository'${NF}"

	sendMsg INFO "Creando repositorio remoto..."

	creatingRepo=$(ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "
										if [ ! -d $REPOS_PATH$repository ]; then
											cd $REPOS_PATH
											mkdir '$repository'

											cd '$repository'
											git --bare init
											git config core.sharedRepository true
											
											$(declare -f); logger ADD ${repository} $USERIP $USER $USERHOME
											echo 1
										else
											echo 0
										fi	
									")
	##############################################################
	#		C O N F I G U R A C I Ó N   D E L   C L I E N T E
	##############################################################

	if [[ $(grep "0" <<< $creatingRepo) ]]; then
		sendMsg ERROR "Ese nombre de repositorio ya esta utilizado"
	elif [[ $(grep "0" <<< $creatingRepo) = "" && $(grep "1" <<< $creatingRepo) = "" ]]; then
		sendMsg ERROR "No se pudo conectar con el servidor $SERVER_NAME, verifique su conexión a internet"
	fi

	sendMsg GOOD "Repositorio creado..."
	sendMsg INFO "Creando repositorio local si no estaba creado..."
	git init

	sendMsg INFO "Agregando archivos..."
	git add --all

	sendMsg INFO "Creando el commit..."
	git commit -m "Saving in: $SERVER_NAME "
	git remote remove $REMOTE_NAME
	git remote add $REMOTE_NAME git+ssh://$SERVER:$PORT$REPOS_PATH$repository

	sendMsg INFO "Cargando el estado del proyecto al: $SERVER_NAME..."
	git push $REMOTE_NAME --mirror
	
	notify-send $SCRIPT_NAME "$repository creeado exitosamente"

elif [[ $option = "3" ]]; then

	if [[ ${repoSelec[@]} = "" ]]; then
		sendMsg ERROR "Debe especificar al menos un repositorio"
	fi

	for repo in ${repoSelec[@]}; do

		if [[ !($repo =~ $isNumber) || $repo -ge ${#array[*]} || $repo < 0 || $repo = "" ]]; then
			sendMsg ERROR "El repositorio número: '$repo' no existe"
		fi

		repository=${array[$repo]}

		direc=$(pwd)"/"${repository:0:-4}
		printf " ${BOLD}${YELLOW}Está seguro de clonar ${I}'${array[$repo]}' ${NF}${YELLOW}${BOLD}en ${I}'$direc'${BOLD}? [Y/n/o]: ${WHITE}"
		read -n 1 choice
		printf "${NC}\n"

		if [[ $choice = "o" || $choice = "O" ]]; then
			whereDoICLone
		elif [[ $choice != "Y" && $choice != "y" && $choice != "" ]]; then
			sendMsg GOOD "Operación abortada"
		else 
			choice=""
		fi

		allClear=false
		while [[ $allClear = false ]]; do
			if [[ -d $direc ]]; then
				confirm "${YELLOW}" "Ya existe el directorio ${I}'$direc'... Clonar en uno distinto"
				whereDoICLone
			else
				allClear=true
			fi
		done

		sendMsg INFO "Clonando repositorio..."

		git clone git+ssh://$SERVER:$PORT$REPOS_PATH$repository $choice
		$(ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "$(declare -f); logger CLONE ${repository} $USERIP $USER $USERHOME");
		cd $direc
		git remote rename origin $REMOTE_NAME

		# C R E A N D O   Y   A C T U A L I Z A N D O   
		# T O D A S   L A S   R A M A S   R E M O T A S
		branches=$(git branch -a | grep remotes/$REMOTE_NAME | grep -v HEAD | grep -v master)

		cont=0
		for remote in ${branches[*]}; do
			IFS='/' read -r -a branch <<< "$remote"
			sendMsg INFO "Creando y actualizando rama remota: ${YELLOW}${branch[2]}"
			git branch ${branch[2]} $remote

			let cont+=1
		done

		printf "\n\n"
		cd ..
	done

elif [[ $option = "4" ]]; then

	if [[ ${repoSelec[@]} = "" ]]; then
		sendMsg ERROR "Debe especificar al menos un repositorio"
	fi

	for repo in ${repoSelec[@]}; do

		if [[ !($repo =~ $isNumber) || $repo -ge ${#array[*]} || $repo < 0 || $repo = "" ]]; then
			sendMsg ERROR "El repositorio número: '$repo' no existe"
		fi

		repository=${array[$repo]}

		confirm ${RED} "Está seguro de eliminar ${I}'${repository}'${NF}"

		ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "
			if [ -d $REPOS_PATH${repository} ]; then
				sudo rm -r $REPOS_PATH${repository}

				$(declare -f); logger DELETE ${repository} $userip  $user $userHome
			fi	
		" &>/dev/null
		notify-send $SCRIPT_NAME "${repository} eliminado"
		sendMsg GOOD "${repository} eliminado..."

	done
	
	pressEnter "salir"
	clearForReal
	exit

elif [[ $option = "5" ]]; then
	validateCertificate
	sendMsg INFO "Cargando log..."
	ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "cat $REPOS_PATH.log"
	exit
elif [[ $option = "6" ]]; then
	validateCertificate
	sendMsg INFO "Cargando log..."
	notify-send $SCRIPT_NAME "Presione Ctrl + c para salir..."
	sendMsg WARN "Presione Ctrl + c para salir..."
	ssh -t -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER -p $PORT "tail -f $REPOS_PATH.log"
	exit
elif [[ $option = "7" ]]; then
	saveScript

	if [[ $? != "0" ]]; then
		notify-send $SCRIPT_NAME "Debe autenticarse correctamente!"
		sendMsg ERROR "Debe autenticarse correctamente..."
	else
		sendMsg GOOD "Ahora puedes ejecutarme donde quieras como: ${I}${PURPLE}${SCRIPT_NAME}"
		pressEnter "volver al menú principal"
		exec $(readlink -f "$0")
	fi

fi

	sendMsg GOOD "Listo, ahora puedes seguir trabajando en tu proyecto"
	sendMsg INFO "NOTA: tus pushs deben estar dirigidos a '$REMOTE_NAME' (git push $REMOTE_NAME <branch>)"

	pressEnter "salir"
	clearForReal
exit

