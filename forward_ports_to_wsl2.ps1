# Forward ports to WSL2 and enable firewall rules
#
# Requires elevation for setting firewall rules and port proxy. As the WSL is
# not installed for the administrator, parts of this script are run as normal
# user.
# Based on: https://github.com/microsoft/WSL/issues/4150#issuecomment-504209723
$ports=@(5000,8080);
$ip_local = "0.0.0.0";
$ip_wsl = "";

# Get the local ip address of WSL 2. It seems, that the return value of `wsl`
# is an array of lines. Unfortunately, I did not find a way to parse this array
# with regular expressions without iterating.
$ifconfig = wsl ifconfig;
foreach ($l in $ifconfig) {
    $m = $l -match "inet (?<ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})";
    if($m) {
        $ip_found = $Matches.ip;
        if($ip_found -notmatch "^127") {
            $ip_wsl = $ip_found;
            Write-Output "Found WSL IP '$ip_wsl'";
            break;
        }
    }
}

if( -Not $ip_wsl ){
    Write-Output "ERROR: The ip address of WSL 2 cannot be found";
    exit;
}

$ports_array = $ports -join ",";
Write-Output "Forwarding Ports '$ports_array' from '$ip_local' to '$ip_wsl'";

function RunAsAdmin($commands) {
    # This function runs all $commands as administrator. Expecting an array as
    # $commands.
    $snippet = $commands -join " ; ";
    $snippet = "cd '$pwd'; Invoke-Expression '" + $snippet + "' ; ";
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $snippet += "read-host Press ENTER to continue... ;";
        Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command $snippet";
    } else {
        Invoke-Expression $snippet;
    }
}

$commands=@();
# Adding Exception Rules for inbound and outbound Rules
# For escaping `"` characters, see:
# https://stackoverflow.com/questions/6714165/powershell-stripping-double-quotes-from-command-line-arguments
$date = Get-Date;
$commands +=  "Remove-NetFireWallRule -DisplayName \""WSL 2\""";
$commands +=  "New-NetFireWallRule -DisplayName \""WSL 2\"" -Direction Outbound -LocalPort $ports_array -Action Allow -Protocol TCP -Description \""Created by script - $date\""";
$commands +=  "New-NetFireWallRule -DisplayName \""WSL 2\"" -Direction Inbound -LocalPort $ports_array -Action Allow -Protocol TCP -Description \""Created by script - $date\""";

foreach($port in $ports) {
    # Adding port proxy
    $commands += "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$ip_local";
    $commands += "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$ip_local connectport=$port connectaddress=$ip_wsl";
}

Write-Output "Running the following commands as Admin now:`n";
$commands;
Write-Output "`nPress any key to continue or ctrl+c to abort...";
$null = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown');
RunAsAdmin($commands);
