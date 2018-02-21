
 # Git Manager

 Este es un script interactivo que permite gestionar repositorios Git en un servidor privado desde la terminal, entre las características que posee estan las siguientes:

 - Autenticar el cliente con el servidor mediante:
 			-  pem (default)
 			 - rsa

- Generación de llaves y registro de
	credenciales

 - Crear repositorio Git en el servidor

 - Clonar uno o varios repositorios a la vez, incluidas
 	todas sus ramas remotas y seteando upstreams para cada una
 
 - Eliminar uno o varios repositorios a la vez

 - Autoinstalación del script

 -	Autoinstalación de paquetes necesarios, manejadores de
 	paquetes soportados por ahora:
			- dpkg
			- pacman
			- yum

	Para el resto se permite la instalación manual desde el
	script
 
 - Servicio de logs en tiempo real e historico descriptivos
 	de uso
 
 - Ampliamente validado y flexible

## Personalizando

Sólamente debemos modificar las siguientes líneas, segun sea necesario, para hacer funcionar el script:

```bash
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
```
## Instalando

```bash
$ chmod +x git-manager.sh
$ sh git-manager.sh
```

## Listo
Ahora puedes ejecutarlo desde cualquier directorio usando el nombre que colocaste en ```SCRIPT_NAME``` en la configuración del script

```bash
$ git-admin
```