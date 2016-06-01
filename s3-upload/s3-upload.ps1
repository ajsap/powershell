# ============================================================
# Will upload local source folder to the target S3 bucket.
# Please refer to script documentation for ways to configure.
# ============================================================
# This script REQUIRES AWS Tools for Windows PowerShell
# installed on default location, or specify Import-Module.
# Official download link: https://aws.amazon.com/powershell/
# ============================================================
# This is main part of the script, not really much to do here.
# To configure it, edit the configuration file: s3-upload.conf
# ============================================================

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

# SPECIFY PATH TO CONFIG FILE:
$configfile="C:\Scripts\s3-upload.conf"

# TYPES HOW WE RETRIEVE PRIVATE IP OF THE SERVER, ESPECIALLY ON AWS INSTANCES:
# http://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/using-instance-addressing.html

#$iphtml = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/local-ipv4"
#$privateip = $iphtml.Content
#$privateip = "172.16.1.2"
#$ipaddress = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName .
$namahost = hostname

# LOAD CONFIGS FROM CONFIG FILE:
function ConvertFrom-Json20([object] $item){ 
	add-type -assembly system.web.extensions
	$ps_js=new-object system.web.script.serialization.javascriptSerializer
	return ,$ps_js.DeserializeObject($item)
}
$content = ConvertFrom-Json20(Get-Content -Path $configfile -Delimiter "`0")
$content = $content[0]
$SMTPServer = $content | Select-Object -Property mail.host
$SMTPServer=$content.'mail.host'
$SMTPSecurity = $content.'mail.security'
$SMTPPort = $content | Select-Object -Property mail.port
$SMTPPort=$content.'mail.port'
$username = $content | Select-Object -Property mail.username
$username=$content.'mail.username'
$password = $content | Select-Object -Property mail.password
$password=$content.'mail.password'
$from = $content | Select-Object -Property mail.from
$from=$content.'mail.from'
$tolist = $content | Select-Object -Property mail.to
$tolist=$content.'mail.to'

$tolist = $tolist.Split(",")

# INITIALISE MAIL OBJECT:
$SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort) 
if($SMTPSecurity.contains('none')){
$SMTPClient.EnableSsl = $false 
}else{
$SMTPClient.EnableSsl = $true 
}

$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($username, $password); 

$objects=$content | Select-Object -Property objects
$objects=$content.'objects'
foreach ($object in $objects){

# INITIALISE OBJECTS:
$location = $object.Get_Item('file.location')
$age = $object.Get_Item('file.age')
$bucket = $object.Get_Item('aws.bucket')
$accesskey = $object.Get_Item('aws.accesskey')
$secretkey = $object.Get_Item('aws.secretkey')
$region = $object.Get_Item('aws.region')
$awsfolder = $object.Get_Item('aws.folder')
$isdelete = $object.Get_Item('file.delete')
$iszip = $object.Get_Item('file.zip')

# FIND FILES USING THE GIVEN FILTER:
if($age.contains('M')){
$age = $age -replace "M", ""
$files = Get-ChildItem $location -Filter $object.'file.match' | Where{$_.LastWriteTime -gt (Get-Date).AddMonths(-$age)}
}
elseif($age.contains('d')){
$age = $age -replace "d", ""
$files = Get-ChildItem $location -Filter $object.'file.match' | Where{$_.LastWriteTime -gt (Get-Date).AddDays(-$age)}
}elseif($age.contains('m')){
$age = $age -replace "m", ""
$files = Get-ChildItem $location -Filter $object.'file.match' | Where{$_.LastWriteTime -gt (Get-Date).AddMinutes(-$age)}
}elseif($age.contains('h')){
$age = $age -replace "h", ""
$files = Get-ChildItem $location -Filter $object.'file.match' | Where{$_.LastWriteTime -gt (Get-Date).AddHours(-$age)}
} 

# ITERATE OVER ALL THE FILES FOUND AFTER FILTERS ARE APPLIED:
foreach ($file in $files){
Try{

$fullname = $file.FullName
$name = $file.Name

# UPLOAD FILE TO AWS S3:
$fullname

if($iszip){

$zipfilename = $name+".zip"
$zipfile = $fullname+".zip"
# INITIALIZE THE ZIP FILE:
if(-not (test-path($zipFile))) {
    set-content $zipFile ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
    (dir $zipFile).IsReadOnly = $false  
}

# CREATE ZIP PACKAGE:
$shellApplication = new-object -com shell.application
$zipPackage = $shellApplication.NameSpace($zipFile)
$zipPackage.CopyHere($fullname)
# THIS 'WHILE' LOOP CHECKS EACH FILE IS ADDED BEFORE CONTINUING:
while($zipPackage.Items().Item($name) -eq $null){
   Start-Sleep -milliseconds 500
}
Write-S3Object -BucketName $bucket -Key $awsfolder$zipfilename -File $zipfile -AccessKey $accesskey -SecretKey $secretkey -Region $region

}else{
# IF EXCEPTION ON THE BELOW LINE:
Write-S3Object -BucketName $bucket -Key $awsfolder$name -File $fullname -AccessKey $accesskey -SecretKey $secretkey -Region $region
# CODE STOPS ON THE ABOVE LINE, IF EXCEPTION OCCURS, CODE EXITS ON THE ABOVE LINE, SO THE FILE WILL NOT BE DELETED.
}
if($isdelete){
	Remove-Item $fullname -Recurse
}
}

# CATCH IF ANY ERRORS ARE OCCURRED:
Catch{
# FINDS THE ERROR:
 $line = $_.InvocationInfo.ScriptLineNumber
 $ErrorMessage = $_.Exception.Message
 $ErrorMessage
 $line
 if($ErrorMessage.Contains("Cannot bind argument to parameter")){
 ''
 }else{
 foreach($to in $tolist){

 $Subject = "Exception in uploading file on "+$namahost
 $Body = "Error while uploading file: "+$fullname+". "+$ErrorMessage+" Check at line "+$line

# SENDMAIL:
 $SMTPClient.Send($from, $to, $Subject, $Body)

 }
 }

}
# REMOVE THE TEMPORARY ZIP FILE THAT IS CREATED:
if($iszip){
if(Test-Path $zipfile){
Remove-Item $zipfile -Recurse
}
}
}
}
