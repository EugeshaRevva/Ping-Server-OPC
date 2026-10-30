#LEGACY - Bad code
$list = @(
    @{IP = "172.16.2.1"; Name = "DataBase OLTP"; SID = "OPS2PRI2"},
    @{IP = "172.16.2.6"; Name = "Kerio VPN, Web-servers"; SID = "N/A"},
    @{IP = "172.16.2.3"; Name = "Web-server AutomaticWorkplace, JIRA"; SID = "N/A"},
    @{IP = "172.16.2.5"; Name = "Standby Database OLTP"; SID = "OPS2SB3"},
    @{IP = "172.16.2.7"; Name = "DataBase Warehouse"; SID = "OPSWH2"},
    @{IP = "172.16.2.13"; Name = "DataBase Warehouse"; SID = "OPSWH2"},
    @{IP = "172.16.2.15"; Name = "Standby Database OLTP"; SID = "OPS2SB3"},
    @{IP = "172.16.2.25"; Name = "Test Stand"; SID = "N/A"}
)

Write-Host "[`n"
foreach ($item in $list) {
    Write-Host "`t{`n
    `t`"IP`": `"$($item.IP)`",`n"
    Write-Host "`t`"Name`": `"$($item.Name)`",`n"
    Write-Host "`t`"SID`": `"$($item.SID)`",`n
    `t},"  #TODO - fix "}," on end of congf
}

Write-Host "`n]"