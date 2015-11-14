<?
// this script recurses the directory to be backed up and generates a list of
// files to be excluded based on vcs ignore files

// similar to tar's --exclude-vcs-files, however that is not flexible enough,
// and misses some notations

$vcs_ignores = [ '.cvsignore', '.gitignore', '.bzrignore', '.hgignore' ];

enumerate($argv[1]);

function enumerate($dir, $root = null) {
	global $vcs_ignores;
	
	if ($root === null) {
		$root = strlen($dir) + 1;
	}
	
	foreach ($vcs_ignores as $ign) {
		if (file_exists($dir."/".$ign)) {
			$ignore = file($dir."/".$ign);
			
			foreach ($ignore as $line) {
				$line = trim($line);
				
				if (empty($line) || $line[0] == '#') {
					continue;
				}
				
				$line = ltrim($line, '/');
				$line = rtrim($line, '/*');
				
				if (substr($line, 0, 2) == './') {
					$line = substr($line, 2);
				}
				
				print "./".substr($dir."/".$line, $root)."\n";
			}
		}
	}
	
	foreach (scandir($dir) as $sub) {
		if ($sub == '.' || $sub == '..') {
			continue;
		}
		
		if (is_dir($dir."/".$sub)) {
			enumerate($dir."/".$sub, $root);
		}
	}
}