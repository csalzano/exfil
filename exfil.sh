#!/usr/local/bin/bash
#
#
#		    .-''-.   _____     __   ________ .-./`)   .---.
#		  .'_ _   \  \   _\   /  / |        |\ .-.')  | ,_|
#		 / ( ` )   ' .-./ ). /  '  |   .----'/ `-' \,-./  )
#		. (_ o _)  | \ '_ .') .'   |  _|____  `-'`"`\  '_ '`)
#		|  (_,_)___|(_ (_) _) '    |_( )_   | .---.  > (_)  )
#		'  \   .---.  /    \   \   (_ o._)__| |   | (  .  .-'
#		 \  `-'    /  `-'`-'    \  |(_,_)     |   |  `-'`-'|___
#		  \       /  /  /   \    \ |   |      |   |   |        \
#		   `'-..-'  '--'     '----''---'      '---'   `--------`
#
#		exfil
#
#       is a program that extracts production WordPress databases and updates
#       their local versions in my computer
#
#		version 1.2.1
#



# Requires bash 5
echo "Requires bash 5. Bash version = $BASH_VERSION"

# Changes the admin email address so your local sites don't email anyone else
development_email="corey.salzano@gmail.com"


echo "exfil replaces the local copy of a WordPress database with fresh production data. Enter q at any prompt to quit."

# perhaps a site name was passed as the first argument
if [ -z "$1" ]
then
	# ask the user to type in a site name
	echo "Which site would you like to sync?"
	# TODO the available sites are...
	read site_name
else
	site_name=$1
fi

# check if the user wants to quit
if [ "q" == "$site_name" ]
then
	exit
fi

# do we even have a .conf file for the site name provided?
if [ ! -f "${site_name}.conf" ]
then
    echo "$site_name.conf not found, please check the spelling. Use the instructions in README.md to construct a conf file."
	exit
fi


echo "Loading ${site_name}.conf..."
source "${site_name}.conf"

# Would you like to download any files?
# n = No
# t = Themes
# p = Plugins
# o = Themes & Plugins
# u = Uploads
# a = All of wp-content
printf "Would you like to download any files?\nn = No\nt = Themes\np = Plugins\no = Themes & Plugins\nu = Uploads\na = All of wp-content\n"
read download_wp_content

# check if the user wants to quit
if [ "q" == "$download_wp_content" ]
then
	exit
fi

echo "Delete local .sql file after importing? (y/n)"
read delete_sql_files

# check if the user wants to quit
if [ "q" == "$delete_sql_files" ]
then
	exit
fi

# CREATE & DOWNLOAD BACKUP

# create the database backup on the server
FILE="${SITE[local_mysql_database]}.sql"
if [ -z "${SITE[ssh_remote_key_file]}" ] # Test if the length of STRING is zero (ie it is empty).
then
	echo "Exporting database..."

	# -o delivers option StrictHostKeyChecking=no to avoid a yes/no question and blindly trust the host's ssh key
	# -q suppresses the server welcome message
	# -p specifies the port number
	sshpass -e ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" << EOF
		mysqldump --user="${SITE[production_mysql_user]}" --password="${SITE[production_mysql_password]}" "${SITE[production_mysql_database]}" > "${SITE[production_root_path]}${FILE}"
EOF

	# download the .sql payload
	echo "Downloading .sql file..."
	sshpass -p "${SITE[ssh_password]}" scp -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_root_path]}${FILE}" "${SITE[local_path]}"

	# delete the .sql payload from the server
	echo "Deleting .sql file from server..."
	sshpass -e ssh -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "rm -f ${SITE[production_root_path]}${FILE}"

	# maybe download files
	case $download_wp_content in
		t)
			echo "Downloading the wp-content/themes folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
		;;
		
		p) # Plugins
			echo "Downloading the wp-content/plugins folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		o) # Themes & Plugins
			echo "Downloading the wp-content/themes folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
			echo "Downloading the wp-content/plugins folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		u) # Uploads
			echo "Downloading the wp-content/uploads folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/uploads" "${SITE[local_path]}wp-content"
		;;

		a) # All of wp-content
			echo "Downloading the wp-content folder..."
			sshpass -p "${SITE[ssh_password]}" scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content" "${SITE[local_path]}"
		;;
	esac

else
	# can't automate this unless we track the password on the key
	# ssh-add /Users/{user-name}/{...}/"${SITE[ssh_remote_key_file]}"

	echo "Exporting database..."

	ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" << EEOF
		mysqldump --user="${SITE[production_mysql_user]}" --password="${SITE[production_mysql_password]}" "${SITE[production_mysql_database]}" > "${SITE[production_root_path]}${FILE}"
EEOF

	# download the .sql payload
	echo "Downloading .sql file..."
	scp -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_root_path]}${FILE}" "${SITE[local_path]}"

	# delete the .sql payload from the server
	echo "Deleting .sql file from server..."
	ssh -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "rm -f ${SITE[production_root_path]}${FILE}"

	# maybe download files
	case $download_wp_content in
		t)
			echo "Downloading the wp-content/themes folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
		;;
		
		p) # Plugins
			echo "Downloading the wp-content/plugins folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		o) # Themes & Plugins
			echo "Downloading the wp-content/themes folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
			echo "Downloading the wp-content/plugins folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		u) # Uploads
			echo "Downloading the wp-content/uploads folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/uploads" "${SITE[local_path]}wp-content"
		;;

		a) # All of wp-content
			echo "Downloading the wp-content folder..."
			scp -r -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content" "${SITE[local_path]}"
		;;
	esac
fi

# if local file does not exist, do not continue
if [ ! -f "${SITE[local_path]}${FILE}" ]; then
	echo "Local .sql file not found, aborting"
	exit
fi



# ALTER FILE AND EXECUTE

# Move to the site folder
cd "${SITE[local_path]}"

# Start the MySQL monitor
# Drop all tables in the local database
# Run the file we've downloaded and modified
# If the database has no tables, this will output a few errors. No big deal.
mysql --host=localhost --user="${SITE[local_mysql_user]}" --password="${SITE[local_mysql_password]}" -f --database="${SITE[local_mysql_database]}" <<EOFMYSQL
SET SESSION group_concat_max_len = 1000000;
SET @tables = NULL;
SELECT GROUP_CONCAT('\`', table_schema, '\`.', table_name) INTO @tables FROM information_schema.tables WHERE table_schema = '"${SITE[local_mysql_database]}"';
SET @tables = IF( @tables IS NOT NULL, CONCAT( 'DROP TABLE ', @tables ), '' );
PREPARE stmt1 FROM @tables;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;
SET autocommit=0;
source ${SITE[local_path]}$FILE;
COMMIT;
EOFMYSQL

# wp-cli, the WordPress Command Line Interface

# Change admin email to me
# Do not load plugins or themes to avoid debug message output
wp option update admin_email "${development_email}" --skip-plugins --skip-themes
wp option update new_admin_email "${development_email}" --skip-plugins --skip-themes

# Replace site URLs from production to development
wp search-replace "${SITE[production_domain]}" "${SITE[local_domain]}"
# and file paths
wp search-replace "${SITE[production_path]}" "${SITE[local_path]}"



# Move to the site folder before deletes
cd "${SITE[local_path]}"

# Delete the local .sql files
if [ "y" == "$delete_sql_files" ]
then
	rm -f "${SITE[local_path]}${FILE}"
	rm -f "${SITE[local_path]}${FILE}.backup.txt"
fi

# Is the Gravity Forms plugin active?
wp plugin is-active gravityforms
if [ 0 == "$?" ]
then
	# Yes

	# Is the Power Boost for Gravity Forms plugin installed?
	wp plugin is-installed power-boost-for-gravity-forms
	if [ 1 == "$?" ]
	then
		# No
		wp plugin install power-boost-for-gravity-forms --activate
	else
		wp plugin activate power-boost-for-gravity-forms
	fi

	#TODO disable all gravity forms notifications & feeds
fi

# Is the SiteGround Optimizer plugin active?
wp plugin is-active sg-cachepress
if [ 0 == "$?" ]
then
	# Yes. Deactivate it, we do not want to run it locally
	wp plugin deactivate sg-cachepress
fi

# Is the Stop Emails plugin active?
wp plugin is-installed stop-emails
if [ 1 == "$?" ]
then
	# No.
	wp plugin install stop-emails --activate
else
	# Yes. Activate it.
	wp plugin activate stop-emails
fi