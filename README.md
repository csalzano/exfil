# exfil

Bash scripting that extracts production WordPress websites and updates their local versions in my computer. Designed to run on a MacBook.

## How to Use

### Dependencies

1. Requires bash 5
1. Requires sshpass if you choose to use ssh passwords instead of key files.

### Instructions

1. [Download](https://github.com/csalzano/exfil/archive/master.zip) exfil.sh and this README.md file
1. Create a configuration file `example.conf` for each local and production website pair. Use the sample file contents below.
1. Change the email address on [line 28](https://github.com/csalzano/exfil/blob/master/exfil.sh#L28) to your email address
1. Navigate to the directory that contains `exfil.sh` and your configuration files in Terminal
1. Type `bash exfil.sh` or `bash exfil.sh example` to skip the prompt asking which configuration file should be loaded

## Sample Configuration File

Create a file in the same directory as `exfil.sh` named `example.conf` and change all the example values to match your local and production environments.

```
declare -A SITE=(

	[ssh_user_at_host]="user@host.tld"
	[ssh_port]=12345
	[ssh_password]=""
	[ssh_remote_key_file]="privatekeyfilename"

	[production_mysql_database]="database_name"
	[production_mysql_user]="user"
	[production_mysql_password]="password"

	[local_mysql_database]="database_name"
	[local_mysql_user]="user"
	[local_mysql_password]="password"

	[production_domain]="://example.xyz"
	[local_domain]="://example.test"

	[production_path]="/path/public_html/example.xyz/"
	[local_path]="/Users/user/Sites/example/"

	[production_root_path]="/path/"
)
export SSHPASS="${SITE[ssh_password]}"
```

### SSH Authentication

This script supports both password and public key SSH authentication. To use a password, provide it in `ssh_password`. Register an SSH private key file using a command like `ssh-add /Users/{user-name}/{...}/privatekeyfilename` before running exfil, and provide the private key file name in `ssh_remote_key_file`.

## changelog

### 1.2.1

- __Fixed__ Now checks that the specified .conf file exists before trying to load it. If the file does not exist, delivers an error message and aborts the program.

### 1.2.0

- __Added__ Adds the GPL 2 license file
- __Added__ Adds instructions to change the email address used to overwrite the admin email
- __Changed__ Changes the file download feature to present a menu with five choices instead of just yes/no on the whole wp-content folder

### 1.1.1

- __Changed__ Now suppresses the server's welcome message during ssh connections for cleaner output
- __Changed__ Skips loading plugins and themes when running [WP CLI](https://wp-cli.org/) commands for cleaner output
- __Changed__ Downloading the wp-content folder is now optional
- __Fixed__ The delete local .sql files feature now works

### 1.1.0

- __Added__ Now downloads the `wp-content` directory

### 1.0.1

- __Fixed__ Edits all `ssh` commands to add option `-o StrictHostKeyChecking=no`. This prevents the prompt `Are you sure you want to continue connecting (yes/no)?` from disrupting the first call to `ssh`. I had been manually connecting with `ssh` prior to using this script to answer yes to the prompt, and this version eliminates that step by always trusting the host keys.

### 1.0.0

First version that supports both SSH password and public key authentication methods.

- __Added__ Adds this change log to README.md
- __Removed__ Removes duplicate credentials in configuration files