# Forward ports to WSL2 and enable firewall rules
#
# Requires elevation for setting firewall rules and port proxy. As the WSL is
# not installed for the administrator, parts of this script is  run as normal
# user.
# Based on: https://github.com/microsoft/WSL/issues/4150#issuecomment-504209723
$ports=@(5000,8080);
$ip_local = "0.0.0.0";

# Get the local ip address of WSL 2
$ip_wsl = wsl -- /bin/sh -c "ifconfig | grep -o 'inet [^ ]*' | grep -v 127 | sed 's/inet //g'";
if( -Not $ip_wsl ){
    Write-Output "The Script Exited, the ip address of WSL 2 cannot be found";
    exit;
}

$ports_array = $ports -join ",";
Write-Output $ports_array;

function RunAsAdmin($commands) {
    # This function runs all $commands as administrator
    # Expecting an array as $commands
    $snippet=$commands -join " ; ";
    $snippet= "cd '$pwd'; Invoke-Expression '" + $snippet + "' ; read-host Press ENTER to continue... ;";
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command $snippet";
    }
}

$commands=@();
#adding Exception Rules for inbound and outbound Rules
$commands +=  "Remove-NetFireWallRule -DisplayName WSL2";
$commands +=  "New-NetFireWallRule -DisplayName WSL2 -Direction Outbound -LocalPort $ports_array -Action Allow -Protocol TCP";
$commands +=  "New-NetFireWallRule -DisplayName WSL2 -Direction Inbound -LocalPort $ports_array -Action Allow -Protocol TCP";

foreach($port in $ports) {
    # Adding port proxy
    $commands += "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$ip_local";
    $commands += "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$ip_local connectport=$port connectaddress=$ip_wsl";
}

RunAsAdmin($commands)
