# Backup

This is my DIY solution for creating incremental backups. You are free to use it, however it is not a one-click solution, you will need to personalize the script to match your own needs.

# Main features

 * Incremental backups
 * Encryption of backups symmetrically or asymmetrically
 * Filtering of files in .gitignore
 * Flexible file list generation via custom `find` arguments
 * Enumeration of project folders and treatment of each project as a separate backup
 * Flexible upload destinations (Google Drive, OneDrive, Mega, FTP, SFTP)

# Structure

* arch/: Backups ready to be uploaded.
* data/: Data regarding the backups, such as date of last backup and miscellaneous states.
* temp/: Temporary files, will be cleared at each run, if not empty.
* backup.sh: Contains functions to aid the creation of backups. Backup calls may be placed on the end of the file, or in a separate file, if this script is included with the functions exposed: `. backup.sh`.
* upload.sh: Enumerates the directory of backups ready to upload, and initiates parallel upload onto each configured service.
* start.sh: Clears temporary files from previous runs, if any, starts the incremental backup and uploads the generated archives at the end.

# Customization

## Backup process

The destinations to be backed up are listed towards the end of the `backup.sh` file. There are two functions that may be of interest when initiating a backup, such as:

* **backup** *name* *dir* *[filter]* -- Backup a directory.
  * *name*: Name of the backup. `..` will be translated to `/` during upload, so the final storage may be nicely structured. E.g. `Servers..ncc1701e..home` will be stored on GDrive as `Servers/ncc1701e/home/date.tar.xz.gpg`.
  * *dir*: Directory to be backed up. Before the backup process, the directory will be traversed and any `.gitignore` files will be respected, so your project folders will be cleanly backed up, assuming you have a proper ignore list in each.
  * *filter*: Optional. You may specify additional arguments for `find`, such as the exclusion of specific files/directories. E.g. `-size -50M` will exclude files bigger than 50 MB. Currently, if you use this parameter, `.gitignore` will NOT be respected, as it is assumed you will exclude manually.
* **backup_dev** *name* *dir* *[filter]* -- Backup subdirectories within a directory as separate backups.
  * *name*: Name of the backup, subdirectories will be appended with `..`, as such, you will end up with `Dir/Subdir/date.tar.xz.gpg` style backups.
  * *dir*: Directory whose direct descendants to be treated as individual backups, as if they were each listed in the script as a call to `backup()`.
  * *filter*: Regular expression to be matched with Bash's `=~` operator on the directory names to be backed up. E.g. `(ATL)?Project[0-9]+|(WindowsForms|Console|Wpf|Silverlight|Web)Application[0-9]+` would skip "generic" (where the name was left to the default during creation) Visual Studio projects to be backed up. In order to prevent false-positives, the regex has to match the full directory name, not just parts of it. Unlike with `backup()`'s `filter` argument, this one will not prevent `.gitignore` to be parsed.

The purpose of the last function is to allow differential treatment for directories such as `Visual Studio 20../Projects` and `IdeaProjects`. Instead of the directories themselves being backed up as a whole, its subdirectories, the projects themselves, will be treated as different backups automatically. The backups will also be named accordingly.

## Upload process

In the `upload.sh` file, there is a loop which goes through the archives to be uploaded. You will have to call your own uploader scripts/commands here. Preferably, call them each in a `(...)&`, so they fork off and run the upload command in a subshell in the background. This way, you may run multiple uploads of the same file to different services in the same time. The `wait` command at the end of the loop will wait for all background processes to finish.

The current file contains commands to call `rclone` (which supports various cloud providers, such as Google Drive, OneDrive, etc) `megatools` (for mega.nz) and `ftp`. It is recommended that you don't put your login credentials into the script, instead use the proper way to persist logins via the recommended way for the tool being used. `rclone` uses a session store by default, `megatools` supports `~/.megarc` and `ftp` can be made to auto-login via `~/.netrc`:

    machine storage.rcs-rds.ro
        login name
        password pass

If you're running the uploader script from within Cygwin, make sure to install the `inetutils` package, otherwise Cygwin will use the Windows implementation of the `ftp` command, which has slight implementation differences, and may break the script.

# Usage

After customization the script may be run with different parameters in order to modify run-time behaviour.

`backup.sh [-f] [-s] [-v] [-t f|i] [-e n|g|o] [-g recipient] [-o password]`

* `-f`: Forces a backup, even if no files changed since the last one backup. (Not to be used with incremental backups, since it'd just create a bunch of empty archives.)
* `-s`: Performs a dry run, only prints if any files changed since the last backup.
* `-v`: Verbose mode, currently only useful with `-s`, where it prints a list of the actual files that have changed.
* `-t f|i`: Specifies backup type, can be:
  * `f`: Full backup, archive will contain all the files.
  * `i`: Incremental backup, archive will only contain the files that have changed since the last backup.
* `-e n|g|o`: Specifies encryption type, can be:
  * `n`: None, no encryption will be performed. (Not recommended if your backups will be uploaded to public cloud platforms.)
  * `g`: GPG, files will be encrypted for recipient specified in global variable `gpg_keyid` or argument `-g`.
  * `o`: OpenSSL, files will be encrypted using AES-256 in CBC mode with the password specified in the global variable `openssl_pass` or argument `-o`.
* `-g ...`: Specifies the public key which will be used to encrypt the archive. The value of the argument can be an email address, a key ID, or a full fingerprint. You should specify a full fingerprint, in order to avoid collisions with short key IDs or collision-based attacks. For more information, consult GPG's documentation, namely the "[Encrypting and decrypting documents](https://www.gnupg.org/gph/en/manual/x110.html)" section. [Note: It is possible to specify multiple public keys when encrypting with GPG, however the script does not support this at this time through this argument. It should be trivial to implement this functionality for anyone who needs it, though.]
* `-o ...`: Specifies a password which will be used to encrypt the archive. The value of this argument is NOT the password directly, rather a modifier for the password source followed by a value. To specify a password, use `pass:` followed by the actual password. As specifying a password like this will make the password visible to anyone requesting a process list, you should use a more secure mode, such as `env:` for an environmental variable or `file:` for a file. For more information, consult OpenSSL's documentation, namely the "[Pass phrase arguments](https://www.openssl.org/docs/manmaster/apps/openssl.html#PASS-PHRASE-ARGUMENTS)" section.