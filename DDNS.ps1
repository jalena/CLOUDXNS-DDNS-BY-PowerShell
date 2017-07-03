# set-executionpolicy remotesigned

#[必填]请在上方填写你的CLoudXNS的API KEY和SECRET KEY.
$API_KEY = "da675f3814d7c8d24dbb6d9a4678e5a4"
$SECRET_KEY = "b14780eb9d31e815"

#[必填]请在上方填写你的域名，比如myhome.xxx.com
#请确保所填域名在账号内存在，否则会返回40x错误
$DOMAIN = "test.bcsytv.com"

#[可选]检查更新的时间间隔（秒）
#API调用有频率限制，不建议设置过短间隔
#如果不需要循环检查更新（比如手动添加计划任务），请注释或填-1
$UPTIME = 300

#[可选]用于检查外网ip是否更新过的网址，减少API调用频率
#注释或填-1将不检查是否已经更新，直接提交ip更新请求
$CHECKURL = "http://ifconfig.co/json"

#[可选]用于记录日志的文件路径*.log,注释掉将不保存日志
#$LOGFILE="./ddns.log"

# 全局信息
$URL = "https://www.cloudxns.net/api2/ddns"
$JSON = ConvertTo-Json(@{"domain" = "$DOMAIN"})

##############################
#.DESCRIPTION
# 获取MD5值
############################## 
Function Get-StringHash([String] $String, $HashName = "MD5") { 
    $StringBuilder = New-Object System.Text.StringBuilder 

    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | ForEach-Object { 
        [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 

    $StringBuilder.ToString() 
}

##############################
#.DESCRIPTION
# 获取外网IP
############################## 
Function Get-Ip() {

    [OutputType([String])]
    param()

    try {
        $resp = Invoke-RestMethod -Uri $CHECKURL
        Write-host $resp
        return $resp.ip
    } catch {
        Write-Error $Error[0].Exception.Message
    }
}

##############################
#.DESCRIPTION
# 获取本地DNS解析结果
##############################
Function Get-DNSresult() {
    
    [OutputType([String])]
    param()

    $DNSresult = Resolve-DnsName $DOMAIN
    return $DNSresult.IPAddress
}

Function UPDDNS() {
    $DATE = get-Date -format r
    $HMAC = Get-StringHash($API_KEY + $URL + $JSON + $DATE + $SECRET_KEY)
    $headers = @{"API-KEY" = $API_KEY; "API-REQUEST-DATE" = $DATE; "API-HMAC" = $HMAC; }

    try {
        $Respond = Invoke-RestMethod -Method POST -Uri $URL -Headers $headers -Body $JSON
        if ($Respond -match "success") {
            Write-Host "调用API更新DNS成功...`r"
        }
    } catch {
        Write-Error $Error[0].Exception.Message
    }

}

if ($LOGFILE -match "\.log$") {
    $null = stop-transcript;
    Clear-Host
    start-transcript -append -path $LOGFILE
}

if (-not(
        -join ($API_KEY, $API_KEY.Length) -match "^[0-9a-z]{32}32$" -and `
            -join ($SECRET_KEY, $SECRET_KEY.Length) -match "^[0-9a-z]{16}16$"
    )) {Write-Warning "你的API KEY配置可能有误，请检查你的配置。"; read-host; exit}

do {

    $ip = Get-Ip
    $dns = Get-DNSresult

    if ($ip -eq $dns) {
        Write-Host "结果一致，跳过更新，下次检查将在$UPTIME<秒>之后`r"
        Start-Sleep $UPTIME
        continue
    } elseif ($ip -ne $dns) {
        UPDDNS
        Start-Sleep 300
    }
    
}while ($UPTIME -gt 0)
