# ============================================================
# CSC KeepAliveVPN v1.0 - andy@csc.co.nz
# Will checks whether the IP mentioned is up on the system.
# ============================================================
# Schedule this script in Windows Task Scheduler every 5 mins.
# ============================================================

$ip = "1.2.3.4"
$result = gwmi -query "SELECT * FROM Win32_PingStatus WHERE Address = '$ip'"
if ($result.StatusCode -eq 0) {
    Write-Host "$ip is up."
}
else{
    Write-Host "$ip is down."
    Write-Host "Disconnecting..."
    rasdial.exe VPNconn /DISCONNECT
    Write-Host "Connecting..."
    rasdial.exe VPNconn username password
}
