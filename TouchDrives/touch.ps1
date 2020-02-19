<# TouchDrives v1.0 by Andy Saputra
andy@saputra.org / https://saputra.org

This PowerShell script will create a file
and modify that file with a time stamp to
keep alive the drives, so they will not sleep
even when idling.

Define the drives you want to keep alive
and the file name on the included touch.conf #>

$configfile="C:/Scripts/touch.conf"
function ConvertFrom-Json20([object] $item){ 
	add-type -assembly system.web.extensions
	$ps_js=new-object system.web.script.serialization.javascriptSerializer
	return ,$ps_js.DeserializeObject($item)
}

$content = ConvertFrom-Json20(Get-Content -Path $configfile -Delimiter "`0")

$cur_date = $(get-date).ToString("yyyy/MM/dd hh:mm:ss tt")

foreach($object in $content){
$file = $object.Get_Item('dir') + $object.Get_Item('filename')
New-Item $file -type file -force
$cur_date | Add-Content $file
}
