# properties that is used by the script
properties {
    $dateLabel = ([DateTime]::Now.ToString("yyyy-MM-dd_HH-mm-ss"))
    $baseDir = 'C:\Sites\'
    $toolsDir = "C:\JenkinsBuilds\"
    $deployBaseDir = "$baseDir\Deploy\"
    $deployPkgDir = "$deployBaseDir\Package\"
    $backupDir = "$deployBaseDir\Backup\"
    $config = 'debug'
    $environment = 'debug'
    $ftpProductionHost = 'http://ftp.ord1-1.websitesettings.com'
    $ftpProductionUsername = 'catfrontroadtrip'
    $ftpProductionPassword = 'I9rouybKb1hhrfq8NoN2'
    $ftpProductionWebRootFolder = "www.frankandfrontier.com/web/content/test"
    $ftpProductionBackupFolder = "www.frankandfrontier.com/web/content/test/backup"
    $deployToFtp = $true
}

# task that is used when building for production, depending on the deploy task
task production -depends deploy
 
# task that is setting up needed stuff for the build process
task setup {
    # remove the ftp module if it's imported
    remove-module [f]tp
    # importing the ftp module from the tools dir
    import-module "$toolsDir\ftp.psm1"
 
    # removing and creating folders needed for the build, deploy package dir and a backup dir with a date
    Remove-ThenAddFolder $deployPkgDir
    Remove-ThenAddFolder $backupDir
    Remove-ThenAddFolder "$backupDir\$dateLabel"
 
    <#
        checking if any episerver dlls is existing in the Libraries folder. This requires that the build server has episerver 7 installed
        for this application the episerver dlls is not pushed to the source control if we had done that this would not be necessary
    #>

}
 
# copying the deployment package
task copyPkg -depends setup {
    # robocopy has some issue with a trailing slash in the path (or it's by design, don't know), lets remove that slash
    $deployPath = Remove-LastChar "$deployPkgDir"
    # copying the required files for the deloy package to the deploy folder created at setup
    robocopy "$sourceDir" "$deployPath" /MIR /XD obj bundler Configurations Properties /XF *.bundle *.coffee *.less *.pdb *.cs *.csproj *.csproj.user *.sln .gitignore README.txt packages.config
    # checking so that last exit code is ok else break the build (robocopy returning greater that 1 if fail)
    if($LASTEXITCODE -gt 1) {
        throw "robocopy commande failed"
        exit 1
    }
}

 
# deploying the package
task deploy -depends mergeConfig {
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
		echo "Hey hey hey"
	}
}
 
#helper methods
function Remove-IfExists([string]$name) {
    if ((Test-Path -path $name)) {
        dir $name -recurse | where {!@(dir -force $_.fullname)} | rm
        Remove-Item $name -Recurse
    }
}
 
function Remove-ThenAddFolder([string]$name) {
    Remove-IfExists $name
    New-Item -Path $name -ItemType "directory"
}
 
function Remove-LastChar([string]$str) {
    $str.Remove(($str.Length-1),1)
}