# properties that is used by the script
properties {
    $dateLabel = ([DateTime]::Now.ToString("yyyy-MM-dd_HH-mm-ss"))
    $baseDir = ''
	$projectName = ''
	$deployBaseDir = "C:\Deploy\"
    $deployPkgDir = "$deployBaseDir\Package\"
    $backupDir = "$deployBaseDir\Backup\"
    $toolsDir = "C:\JenkinsBuilds\"
    $config = 'debug'
    $environment = 'debug'
    $ftpProductionHost = 'ftp://ftp.ord1-1.websitesettings.com'
    $ftpProductionUsername = 'catfrontroadtrip'
    $ftpProductionPassword = 'I9rouybKb1hhrfq8NoN2'
    $ftpProductionWebRootFolder = "www.frankandfrontier.com/web/content/test"
    $ftpProductionBackupFolder = "www.frankandfrontier.com/web/content/test/backup"
    $deployToFtp = $true
}

Task default -Depends deploy

Task Setup { 

	Write-Host "Starting Setup"
	
	$deployBaseDir = "C:\Deploy\$projectName\"
    $deployPkgDir = "$deployBaseDir\Package\"
    $backupDir = "$deployBaseDir\Backup\"
	
	# remove the ftp module if it's imported
    remove-module [f]tp
    # importing the ftp module from the tools dir
    import-module "$toolsDir\ftp.psm1"
 
	Write-Host "Pre Add"
 
	Add-Content C:\Deploy\GitTest\test.txt "The End"
 
	Write-Host "Post Add"
 
	$acl = Get-Acl $deployPkgDir
	$acl.access
	Write-Host Get-Acl $deployPkgDir | Format-List
 
	Write-Host "Post Permissions"
 
    # removing and creating folders needed for the build, deploy package dir and a backup dir with a date
    Remove-ThenAddFolder $deployPkgDir
    Remove-ThenAddFolder $backupDir
    Remove-ThenAddFolder "$backupDir\$dateLabel"
	Write-Host $deployPkgDir
	Write-Host $backupDir
	Write-Host "Ending Setup" 
}

# copying the deployment package
Task copyPkg -Depends Setup {
    Write-Host "Starting copy task"
	
	$deployBaseDir = "C:\Deploy\$projectName\"
    $deployPkgDir = "$deployBaseDir\Package\"
    $backupDir = "$deployBaseDir\Backup\"
	
	# robocopy has some issue with a trailing slash in the path (or it's by design, don't know), lets remove that slash
    $deployPath = Remove-LastChar "$deployPkgDir"
    # copying the required files for the deloy package to the deploy folder created at setup
    robocopy "$baseDir" "$deployPath" /MIR /XD obj bundler Configurations Properties /XF *.bundle *.coffee *.less *.pdb *.cs *.csproj *.csproj.user *.sln .gitignore README.txt packages.config
    # checking so that last exit code is ok else break the build (robocopy returning greater that 1 if fail)
    if($LASTEXITCODE -gt 1) {
        throw "robocopy commande failed"
        exit 1
    }
	Write-Host "Ending copy task"
}
 
# deploying the package
Task deploy -Depends Setup, copyPkg {
	Write-Host "Starting deploy task"
	
	$deployBaseDir = "C:\Deploy\$projectName\"
    $deployPkgDir = "$deployBaseDir\Package\"
    $backupDir = "$deployBaseDir\Backup\"
	
    # only if production and deployToFtp property is set to true
    if($environment -ieq "production" -and $deployToFtp -eq $true) {
        # Setting the connection to the production ftp
        Set-FtpConnection $ftpProductionHost $ftpProductionUsername $ftpProductionPassword
 
        # backing up before deploy => by downloading and uploading the current webapplication at production enviorment
        $localBackupDir = Remove-LastChar "$backupDir"
        Get-FromFtp "$backupDir\$dateLabel" "$ftpProductionWebRootFolder"
        Send-ToFtp "$localBackupDir" "$ftpProductionBackupFolder"
 
        # redeploying the application => by removing the existing application and upload the new one
        Remove-FromFtp "$ftpProductionWebRootFolder"
        $localDeployPkgDir = Remove-LastChar "$deployPkgDir"
        Send-ToFtp "$localDeployPkgDir" "$ftpProductionWebRootFolder"
    } else {
		Write-Host "Non production - no deploy"
		Write-Host $environment
		Write-Host $deployToFtp
	}
	
	Write-Host "Ending deploy task"
}
 
#helper methods
function Remove-IfExists([string]$name) {
    if ((Test-Path -path $name)) {
        #dir $name -recurse | where {!@(dir -force $_.fullname)} | rm
        Remove-Item $name -Recurse -Force
    }
}
 
function Remove-ThenAddFolder([string]$name) {
    Remove-IfExists $name
    New-Item -Path $name -ItemType "directory"
}
 
function Remove-LastChar([string]$str) {
    $str.Remove(($str.Length-1),1)
}