#!/bin/bash
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
#       extracts WordPress databases and files
#
#		version 2.1.0
#



# Changes the admin email address so your local sites don't email anyone else
development_email="938411+csalzano@users.noreply.github.com"
# Change the email address with sed:
# sed -i '' -e "s|938411+csalzano@users.noreply.github.com|youremail@example.com|g" exfil.sh


echo "exfil updates local WordPress sites with fresh production data. Enter q at any prompt to quit."

# Was a site name was passed as the first argument?
if [ -z "$1" ]
then
	# No. Ask the user to provide a site name.
	echo "Which site would you like to sync?"
	# TODO the available sites are...
	read site_name
else
	site_name=$1
fi

# Process parameters passed to the script.
for ARG in "$@"; do
	case $ARG in
		# Should we delete any local files before we start?
		--no-deletes)
			delete_wp_content="n"
		;;

		# Should we download any files?
		--no-downloads)
			download_wp_content="n"
		;;
		--download-plugins)
			download_wp_content="p"
		;;
		--download-themes)
			download_wp_content="t"
		;;

		# Keep local .sql file after importing? (y/n).
		--no-keep-sql)
			keep_sql_file="n"
		;;
	esac
done

# Colors for red text.
RED='\033[0;31m'
NO_COLOR='\033[0m' # No Color

# Do we have a .conf file for the name provided? Check the current directory and
# one level above.
if [ ! -f "${site_name}.conf" ]
then
	if [ ! -f "../${site_name}.conf" ]
	then
		printf "${RED}$site_name.conf not found, please check the spelling.${NO_COLOR} Use the instructions at in README.md to construct a conf file."
		exit
	else
		source "../${site_name}.conf"
	fi
else
	source "${site_name}.conf"
fi
echo "Loaded ${site_name}.conf"

if [ -z "$delete_wp_content" ]
then
	# Should we delete any local files before we start?
	# n = No
	# t = Themes
	# p = Plugins
	# o = Themes & Plugins
	# u = Uploads
	# ugf = Gravity Forms uploads
	# a = Themes, Plugins, Must-Use Plugins, and Uploads
	printf "Would you like to ${RED}delete${NO_COLOR} any local files before we start?\nn = No\nt = Themes\np = Plugins\no = Themes & Plugins\nu = Uploads\nugf = Gravity Forms uploads\na = Themes, Plugins, Must-Use Plugins, and Uploads\n"
	read delete_wp_content

	# check if the user wants to quit
	if [ "q" == "$delete_wp_content" ]
	then
		exit
	fi
fi

# Delete local files
case $delete_wp_content in
	t)
		rm -rf "${SITE[local_path]}wp-content/themes/*"
	;;

	p) # Plugins
		rm -rf "${SITE[local_path]}wp-content/plugins/*"
	;;

	o) # Themes & Plugins
		rm -rf "${SITE[local_path]}wp-content/themes/*"
		rm -rf "${SITE[local_path]}wp-content/plugins/*"
	;;

	u) # Uploads
		rm -rf "${SITE[local_path]}wp-content/uploads/*"
	;;

	ugf) # Gravity Forms uploads
		rm -rf "${SITE[local_path]}wp-content/uploads/gravity_forms/*"
	;;

	a) # Themes, Plugins, Must-Use Plugins, and Uploads
		rm -rf "${SITE[local_path]}wp-content/themes/*"
		rm -rf "${SITE[local_path]}wp-content/plugins/*"
		rm -rf "${SITE[local_path]}wp-content/mu-plugins/*"
		rm -rf "${SITE[local_path]}wp-content/uploads/*"
	;;
esac


if [ -z "$download_wp_content" ]
then
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
fi

if [ -z "$keep_sql_file" ]
then
	# Keep local .sql file after importing? (y/n)
	echo "Keep local .sql file after importing? (y/n)"
	read keep_sql_file

	# check if the user wants to quit
	if [ "q" == "$keep_sql_file" ]
	then
		exit
	fi
fi

# CREATE & DOWNLOAD BACKUP

# create the database backup on the server
FILE="${SITE[local_mysql_database]}.sql"
if [ -z "${SITE[ssh_remote_key_file]}" ] && [ -n "${SITE[ssh_password]}" ]; # Remote key file is empty and password is not empty.
then
	echo "Using sshpass...";
	echo "Exporting database..."

	# -o delivers option StrictHostKeyChecking=no to avoid a yes/no question and blindly trust the host's ssh key
	# -q suppresses the server welcome message
	# -p specifies the port number
	sshpass -e ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" << EOF
		mysqldump --user="${SITE[production_mysql_user]}" --password="${SITE[production_mysql_password]}" "${SITE[production_mysql_database]}" > "${SITE[production_root_path]}${FILE}" --no-tablespaces
EOF
	# $? is the exit status of the most recently-executed command; by convention
	# 0 means success and anything else indicates failure.
	if [ "$?" -ne 0 ]; then
		echo "mysqldump failed, looking for WP Engine file..."

		sshpass -p "${SITE[ssh_password]}" scp -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/mysql.sql" "${SITE[local_path]}"
		# did we get the WP Engine file?
		if [ "$?" -eq 0 ]; then
			# yes, rename it from mysql.sql to the file name we will use later
			mv "${SITE[local_path]}mysql.sql" "${SITE[local_path]}${FILE}"
		fi
	else
		echo "mysqldump success"

		# download the .sql payload
		echo "Downloading .sql file..."
		sshpass -p "${SITE[ssh_password]}" scp -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_root_path]}${FILE}" "${SITE[local_path]}"

		# delete the .sql payload from the server
		echo "Deleting .sql file from server..."
		sshpass -e ssh -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "rm -f ${SITE[production_root_path]}${FILE}"
	fi

	# maybe download files
	case $download_wp_content in
		t)
			# rsync params
			# -a archive mode; equals -rlptgoD (no -H,-A,-X)
			# -z compress file data during the transfer
			# -v increase verbosity
			echo "Downloading the wp-content/themes folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
		;;
		
		p) # Plugins
			echo "Downloading the wp-content/plugins folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		o) # Themes & Plugins
			echo "Downloading the wp-content/themes folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
			echo "Downloading the wp-content/plugins folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		u) # Uploads
			echo "Downloading the wp-content/uploads folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/uploads" "${SITE[local_path]}wp-content"
		;;

		a) # All of wp-content
			echo "Downloading the wp-content folder..."
			sshpass -p "${SITE[ssh_password]}" rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content" "${SITE[local_path]}"
		;;
	esac

	# Store $table_prefix for later
	echo "Downloading \$table_prefix..."
	TABLE_PREFIX=$(sshpass -e ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "
		cd "${SITE[production_path]}";
		wp db prefix
	")
	echo "\$table_prefix = '${TABLE_PREFIX}'"

else
	# can't automate this unless we track the password on the key
	# ssh-add /Users/{user-name}/{...}/"${SITE[ssh_remote_key_file]}"

	echo "Exporting database..."

	ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" << EEOF
		mysqldump --user="${SITE[production_mysql_user]}" --password="${SITE[production_mysql_password]}" "${SITE[production_mysql_database]}" > "${SITE[production_root_path]}${FILE}" --no-tablespaces
EEOF
	# $? is the exit status of the most recently-executed command; by convention
	# 0 means success and anything else indicates failure.
	if [ "$?" -ne 0 ]; then
		echo "mysqldump failed, looking for WP Engine file..."

		scp -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/mysql.sql" "${SITE[local_path]}"
		# did we get the WP Engine file?
		if [ "$?" -eq 0 ]; then
			# yes, rename it from mysql.sql to the file name we will use later
			mv "${SITE[local_path]}mysql.sql" "${SITE[local_path]}${FILE}"
		fi
	else
		echo "mysqldump success"

		# download the .sql payload
		echo "Downloading .sql file..."
		scp -O -P "${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_root_path]}${FILE}" "${SITE[local_path]}"

		# delete the .sql payload from the server
		echo "Deleting .sql file from server..."
		ssh -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "rm -f ${SITE[production_root_path]}${FILE}"
	fi

	# maybe download files
	case $download_wp_content in
		t)
			echo "Downloading the wp-content/themes folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
		;;

		p) # Plugins
			echo "Downloading the wp-content/plugins folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		o) # Themes & Plugins
			echo "Downloading the wp-content/themes folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/themes" "${SITE[local_path]}wp-content"
			echo "Downloading the wp-content/plugins folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/plugins" "${SITE[local_path]}wp-content"
		;;

		u) # Uploads
			echo "Downloading the wp-content/uploads folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content/uploads" "${SITE[local_path]}wp-content"
		;;

		a) # All of wp-content
			echo "Downloading the wp-content folder..."
			rsync -azv -e 'ssh -p '"${SITE[ssh_port]}" "${SITE[ssh_user_at_host]}":"${SITE[production_path]}wp-content" "${SITE[local_path]}"
		;;
	esac

	# Store $table_prefix for later
	echo "Downloading \$table_prefix..."
	TABLE_PREFIX=$(ssh -q -o StrictHostKeyChecking=no "${SITE[ssh_user_at_host]}" -p "${SITE[ssh_port]}" "
		cd "${SITE[production_path]}";
		wp db prefix
	")
	echo "\$table_prefix = '${TABLE_PREFIX}'"
fi

# if local file does not exist, do not continue
if [ ! -f "${SITE[local_path]}${FILE}" ]; then
	echo "Local .sql file not found, aborting"
	exit
fi



# ALTER FILE AND EXECUTE

# Move to the site folder
cd "${SITE[local_path]}"

# Stash the local $table_prefix before we wipe the database
TABLE_PREFIX_LOCAL=$(wp db prefix)

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

# Make sure the $table_prefix variable in wp-config.php is accurate
if [ "${TABLE_PREFIX}" != "${TABLE_PREFIX_LOCAL}" ]
then
	echo "Changing \$table_prefix from '${TABLE_PREFIX_LOCAL}' to '${TABLE_PREFIX}'"
	# Looks like $table_prefix = 'hif_';
	sed -i '' "s/$table_prefix = '${TABLE_PREFIX_LOCAL}'/$table_prefix = '${TABLE_PREFIX}'/" wp-config.php
	sed -i '' "s/$table_prefix = \"${TABLE_PREFIX_LOCAL}\"/$table_prefix = \"${TABLE_PREFIX}\"/" wp-config.php
fi

# Replace site URLs from production to development
echo "Replacing ${SITE[production_domain]} with ${SITE[local_domain]}..."
wp search-replace "${SITE[production_domain]}" "${SITE[local_domain]}" --all-tables-with-prefix --report-changed-only
# Gravity Forms stores URLs in JSON in the wp_gf_form_meta table with https:\/\/.breakfastco.xyz
echo "Replacing ${SITE[production_domain]//\//\\\/} with ${SITE[local_domain]//\//\\\/}..."
wp search-replace "${SITE[production_domain]//\//\\\/}" "${SITE[local_domain]//\//\\\/}" --all-tables-with-prefix --report-changed-only

# Also replace www versions of the domains if production_domain is not already www
# The == comparison operator behaves differently within a double-brackets
# [[ $a == z* ]]   # True if $a starts with a "z" (wildcard matching).
if [[ "${SITE[production_domain]}" != ://www* ]]
then
	WWWPROD=${SITE[production_domain]//:\/\//:\/\/www.}
	WWWLOCAL=${SITE[local_domain]//:\/\//:\/\/www.}
	echo "Replacing ${WWWPROD} with ${WWWLOCAL}..."
	wp search-replace "${WWWPROD}" "${WWWLOCAL}" --all-tables-with-prefix --report-changed-only
fi

# and file paths
echo "Replacing ${SITE[production_path]} with ${SITE[local_path]}..."
wp search-replace "${SITE[production_path]}" "${SITE[local_path]}" --all-tables-with-prefix --report-changed-only

# Delete the local .sql files
if [ "n" == "$keep_sql_file" ]
then
	rm -f "${SITE[local_path]}${FILE}"
fi

# Are we loading plugins?
if [ "o" == "$download_wp_content" ] || [ "p" == "$download_wp_content" ]
then
	# install all active plugins basd on the `active_plugins` option value
	# that was just written to the database
	wp option get active_plugins --format=json | php -r "foreach( json_decode( fgets(STDIN) ) as \$value ) { \$p=explode('/',\$value);fwrite(STDOUT, (is_array( \$p ) ? \$p[0] : \$p).PHP_EOL); }" | xargs -n1 bash -c '
	VERSION=$(wp plugin get $0 --field=version --quiet)
	echo "Trying to install ${0}"
	if [ ${#VERSION} -gt 0 ]
	then
		echo "Specifying version ${VERSION}"
		wp plugin install $0 --version=${VERSION}
	else
		echo "No version number found"
		wp plugin install $0
	fi'
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

	# Is the Gravity Forms Cloudflare Turnstile add-on active?
	wp plugin is-active gravityformsturnstile
	if [ 0 == "$?" ]
	then
		# Yes.
		# Replace the key and secret with always-pass dummy values.
		# https://developers.cloudflare.com/turnstile/troubleshooting/testing/
		wp option get gravityformsaddon_gravityformsturnstile_settings --format=json | php -r "
\$option = json_decode( fgets(STDIN) );
\$option->site_key = \"1x00000000000000000000AA\";
\$option->site_secret = \"1x0000000000000000000000000000000AA\";
print json_encode(\$option);
" | wp option set gravityformsaddon_gravityformsturnstile_settings --format=json
	fi
fi

# Is the SiteGround Optimizer plugin active?
wp plugin is-active sg-cachepress
if [ 0 == "$?" ]
then
	# Yes. Deactivate it, we do not want to run it locally
	wp plugin deactivate sg-cachepress
fi

# Is the Use MailHog plugin active?
wp plugin is-installed use-mailhog
if [ 1 == "$?" ]
then
	# No.
	wp plugin install https://github.com/csalzano/use-mailhog/archive/refs/heads/main.zip
	# Remove the github branch name from the folder.
	mv wp-content/plugins/use-mailhog-main wp-content/plugins/use-mailhog
fi
wp plugin activate use-mailhog

# Does the site config have a script_after we need to run?
if [ -v SITE[script_after] ]
then
	echo "Running script_after: ${SITE[script_after]}"
	eval ${SITE[script_after]}
fi

# Change admin email to me
# Do not load plugins or themes to avoid debug message output
# Waited to do this until after the stop-emails plugin is active
wp option update admin_email "${development_email}" --skip-plugins --skip-themes
wp option update new_admin_email "${development_email}" --skip-plugins --skip-themes