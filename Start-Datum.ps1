$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Join-Path $here "app"
if (-not (Test-Path (Join-Path $root "index.html"))) {
    throw "app\index.html missing. Unzip the whole Datum folder first."
}

function Find-Port {
    foreach ($p in 18765, 18766, 18767, 18768) {
        $ok = $true
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $c.Connect("127.0.0.1", $p)
            $c.Close()
            $ok = $false
        } catch { $ok = $true }
        if ($ok) { return $p }
    }
    return 18765
}

$port = Find-Port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "text/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
}

$edgeCandidates = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
)
$edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$url = "http://127.0.0.1:$port/"
if ($edge) {
    Start-Process $edge -ArgumentList @("--app=$url", "--window-size=1440,920")
} else {
    Start-Process $url
}

$rootFull = [IO.Path]::GetFullPath($root)
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($rel -eq "/") { $rel = "/index.html" }
    $file = [IO.Path]::GetFullPath((Join-Path $rootFull $rel.TrimStart("/").Replace("/", [IO.Path]::DirectorySeparatorChar)))
    if (-not $file.StartsWith($rootFull)) {
        $ctx.Response.StatusCode = 403
        $ctx.Response.Close()
        continue
    }
    if (-not (Test-Path -LiteralPath $file)) {
        $file = Join-Path $rootFull "index.html"
    }
    $bytes = [IO.File]::ReadAllBytes($file)
    $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
    $ctx.Response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" })
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}
