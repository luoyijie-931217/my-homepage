# ==============================================================================
# TheShampooFactory Local Standalone Mirror & Link Rewriter
# Target Directory: D:\my-homepage
# ==============================================================================

$ErrorActionPreference = "Continue"
$TargetDir = "D:\my-homepage"
$BaseUrl = "https://theshampoofactory.com"

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
$wc.Encoding = [System.Text.Encoding]::UTF8

Write-Host ">>> [1/5] Fetching Sitemaps to Discover All Pages..." -ForegroundColor Cyan

$sitemaps = @(
    "$BaseUrl/page-sitemap.xml",
    "$BaseUrl/post-sitemap.xml",
    "$BaseUrl/category-sitemap.xml"
)

$pageUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$pageUrls.Add("$BaseUrl/") | Out-Null

# Core pages guarantee
$corePages = @(
    "$BaseUrl/products/",
    "$BaseUrl/products/shampoo/",
    "$BaseUrl/products/conditioner/",
    "$BaseUrl/products/hair-oil/",
    "$BaseUrl/products/hair-mask/",
    "$BaseUrl/products/hair-spray/",
    "$BaseUrl/oem-service/",
    "$BaseUrl/about/",
    "$BaseUrl/blog/",
    "$BaseUrl/faqs/",
    "$BaseUrl/contact/",
    "$BaseUrl/privacy-policy/",
    "$BaseUrl/terms-and-conditions/"
)
foreach ($cp in $corePages) {
    $pageUrls.Add($cp) | Out-Null
}

foreach ($sm in $sitemaps) {
    try {
        $xmlContent = $wc.DownloadString($sm)
        $matches = [regex]::Matches($xmlContent, '<loc>(https://theshampoofactory\.com/[^<]+)</loc>')
        foreach ($m in $matches) {
            $u = $m.Groups[1].Value.Trim()
            $pageUrls.Add($u) | Out-Null
        }
    } catch {
        Write-Warning "Could not fetch sitemap $($sm) - $_"
    }
}

# Add pagination for blog and category
for ($i = 2; $i -le 17; $i++) {
    $pageUrls.Add("$BaseUrl/blog/page/$i/") | Out-Null
}
$pageUrls.Add("$BaseUrl/products/shampoo/page/2/") | Out-Null

Write-Host "Discovered $($pageUrls.Count) total pages to process." -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 2: Download HTML Pages & Record Redirects
# ------------------------------------------------------------------------------
Write-Host ">>> [2/5] Downloading HTML Pages..." -ForegroundColor Cyan

function Get-LocalPathForUrl ($url) {
    $uri = [System.Uri]$url
    $path = $uri.AbsolutePath.Trim('/')
    if ([string]::IsNullOrEmpty($path)) {
        return "$TargetDir\index.html"
    }
    $folder = Join-Path $TargetDir ($path -replace '/', '\')
    return (Join-Path $folder "index.html")
}

$redirectMap = @{}
$count = 0
$totalPages = $pageUrls.Count

foreach ($url in $pageUrls) {
    $count++
    $localFile = Get-LocalPathForUrl $url
    $localFolder = Split-Path $localFile -Parent

    if (-not (Test-Path $localFolder)) {
        New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
    }

    try {
        $finalUrl = (& curl.exe -s -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -w "%{url_effective}" -o $localFile $url).Trim()
        if ($finalUrl -and $finalUrl.TrimEnd('/') -ne $url.TrimEnd('/')) {
            $redirectMap[$url] = $finalUrl
        }
        if ($count % 10 -eq 0 -or $count -eq $totalPages) {
            Write-Host "[$count/$totalPages] Downloaded: $url"
        }
    } catch {
        Write-Warning "[$count/$totalPages] Error downloading $($url) - $_"
    }
}

# Create redirect shims for redirected URLs
foreach ($origUrl in $redirectMap.Keys) {
    $shimFile = Get-LocalPathForUrl $origUrl
    $destUrl = $redirectMap[$origUrl]
    $destPath = [System.Uri]$destUrl
    $destRel = $destPath.AbsolutePath.Trim('/')

    # Calculate depth of shim
    $relDir = (Split-Path $shimFile -Parent).Substring($TargetDir.Length).TrimStart('\')
    $depth = 0
    if ($relDir.Length -gt 0) {
        $depth = ($relDir -split '\\').Length
    }
    $pfx = ""
    for ($d = 0; $d -lt $depth; $d++) { $pfx += "../" }

    $targetHtml = if ([string]::IsNullOrEmpty($destRel)) { "${pfx}index.html" } else { "${pfx}$destRel/index.html" }
    $shimContent = "<!DOCTYPE html><html><head><meta http-equiv=""refresh"" content=""0; url=$targetHtml""><script>window.location.replace('$targetHtml');</script></head><body>Redirecting to <a href=""$targetHtml"">$targetHtml</a>...</body></html>"
    [System.IO.File]::WriteAllText($shimFile, $shimContent, [System.Text.Encoding]::UTF8)
}

# ------------------------------------------------------------------------------
# Step 3: Extract and Download Static Assets
# ------------------------------------------------------------------------------
Write-Host ">>> [3/5] Extracting & Downloading Static Assets..." -ForegroundColor Cyan

$assetUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$allHtmlFiles = Get-ChildItem -Path $TargetDir -Filter "index.html" -Recurse
foreach ($hf in $allHtmlFiles) {
    $content = [System.IO.File]::ReadAllText($hf.FullName, [System.Text.Encoding]::UTF8)

    $patterns = @(
        'href="(https://theshampoofactory\.com/wp-[^"]+)"',
        'src="(https://theshampoofactory\.com/wp-[^"]+)"',
        'background_video_link":"(https?:\\?/\\?/theshampoofactory\.com\\?/wp-[^"]+)"',
        'content="(https://theshampoofactory\.com/wp-[^"]+)"'
    )
    foreach ($p in $patterns) {
        $m = [regex]::Matches($content, $p)
        foreach ($match in $m) {
            $cleaned = $match.Groups[1].Value -replace '\\/', '/'
            $assetUrls.Add($cleaned) | Out-Null
        }
    }

    $srcsetMatches = [regex]::Matches($content, 'srcset="([^"]+)"')
    foreach ($sm in $srcsetMatches) {
        $entries = $sm.Groups[1].Value -split ','
        foreach ($e in $entries) {
            $parts = $e.Trim() -split '\s+'
            if ($parts[0] -match '^https://theshampoofactory\.com/wp-') {
                $assetUrls.Add($parts[0]) | Out-Null
            }
        }
    }
}

# Additional known essential assets
$assetUrls.Add("$BaseUrl/wp-content/themes/blocksy/static/bundle/main.min.css?ver=2.1.57") | Out-Null
$assetUrls.Add("$BaseUrl/wp-content/themes/blocksy/static/bundle/main.js?ver=2.1.57") | Out-Null
$assetUrls.Add("$BaseUrl/wp-content/plugins/elementor/assets/lib/eicons/fonts/eicons.woff2") | Out-Null
$assetUrls.Add("$BaseUrl/wp-content/uploads/2025/12/shampoo-factory-banner.mp4") | Out-Null

Write-Host "Identified $($assetUrls.Count) unique static assets to download." -ForegroundColor Green

$aIdx = 0
$totalAssets = $assetUrls.Count
foreach ($asset in $assetUrls) {
    $aIdx++
    $cleanUri = [System.Uri]($asset -replace '\?.*$', '')
    $relPath = $cleanUri.AbsolutePath.TrimStart('/')
    $destPath = Join-Path $TargetDir ($relPath -replace '/', '\')
    $destFolder = Split-Path $destPath -Parent

    if (-not (Test-Path $destPath)) {
        if (-not (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        }
        & curl.exe -s -L --create-dirs -o $destPath $asset
        if ($aIdx % 10 -eq 0 -or $aIdx -eq $totalAssets) {
            Write-Host "[$aIdx/$totalAssets] Downloaded: $relPath"
        }
    }
}

# ------------------------------------------------------------------------------
# Step 4: Dual-Mode Link & Asset Rewriting across All HTML Files
# ------------------------------------------------------------------------------
Write-Host ">>> [4/5] Rewriting Links & Injecting Local Fixes in all HTML files..." -ForegroundColor Cyan

foreach ($hf in (Get-ChildItem -Path $TargetDir -Filter "index.html" -Recurse)) {
    # Skip redirect shim files (keep them lightweight)
    $raw = [System.IO.File]::ReadAllText($hf.FullName, [System.Text.Encoding]::UTF8)
    if ($raw -match '<meta http-equiv="refresh"') {
        continue
    }

    $relDir = $hf.DirectoryName.Substring($TargetDir.Length).TrimStart('\')
    $depth = 0
    if ($relDir.Length -gt 0) {
        $depth = ($relDir -split '\\').Length
    }

    $prefix = ""
    for ($d = 0; $d -lt $depth; $d++) { $prefix += "../" }

    # 1. Strip blocking / tracking scripts
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*googletagmanager[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script id="google_gtagjs-js-after"[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*googlesitekit-events[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '<script[^>]*email-decode\.min\.js[^>]*></script>', '')
    $raw = [regex]::Replace($raw, '<script[^>]*challenges\.cloudflare\.com/turnstile[^>]*></script>', '')

    # 2. Rewrite internal page links: href="https://theshampoofactory.com/<path>"
    $raw = [regex]::Replace($raw, 'href="https://theshampoofactory\.com/([^"#\?]*)/?([#\?][^"]*)?"', {
        param($m)
        $sub = $m.Groups[1].Value.Trim('/')
        $frag = $m.Groups[2].Value

        # Check redirect
        $cand = "https://theshampoofactory.com/$sub/"
        if ($redirectMap.ContainsKey($cand)) {
            $targetUri = [System.Uri]$redirectMap[$cand]
            $sub = $targetUri.AbsolutePath.Trim('/')
        }

        if ([string]::IsNullOrEmpty($sub)) {
            return "href=""${prefix}index.html$frag"""
        } else {
            return "href=""${prefix}$sub/index.html$frag"""
        }
    })

    # 3. Rewrite relative page links like href="/terms-and-conditions", href="/privacy-policy"
    $raw = [regex]::Replace($raw, 'href="/([a-zA-Z0-9\-_]+)/?"', {
        param($m)
        $sub = $m.Groups[1].Value.Trim('/')
        return "href=""${prefix}$sub/index.html"""
    })

    # 4. Rewrite static assets: https://theshampoofactory.com/wp-...
    $raw = [regex]::Replace($raw, '((?:href|src|content)="?)https://theshampoofactory\.com/(wp-[^"''\s\?]+)(?:\?[^"''\s]*)?', {
        param($m)
        return $m.Groups[1].Value + $prefix + $m.Groups[2].Value
    })

    # 5. Rewrite srcset
    $raw = [regex]::Replace($raw, 'srcset="([^"]+)"', {
        param($sm)
        $entries = $sm.Groups[1].Value -split ','
        $newEntries = foreach ($e in $entries) {
            $eClean = $e.Trim()
            [regex]::Replace($eClean, 'https://theshampoofactory\.com/(wp-[^\s\?]+)(?:\?[^\s]*)?', "${prefix}`$1")
        }
        return 'srcset="' + ($newEntries -join ', ') + '"'
    })

    # 6. Rewrite background video in data-settings
    $raw = $raw -replace 'https?:\\/\\/theshampoofactory\.com\\/wp-content', ($prefix.Replace('/', '\/') + 'wp-content')

    # 7. Inject local-fixes.css before </head>
    if ($raw -notmatch 'local-fixes\.css') {
        $raw = $raw -replace '</head>', "<link rel=""stylesheet"" href=""${prefix}local-fixes.css"">`n</head>"
    }

    # 8. Inject local-fixes.js before </body>
    if ($raw -notmatch 'local-fixes\.js') {
        $raw = $raw -replace '</body>', "<script src=""${prefix}local-fixes.js""></script>`n</body>"
    }

    [System.IO.File]::WriteAllText($hf.FullName, $raw, [System.Text.Encoding]::UTF8)
}

Write-Host ">>> [5/5] Success! All pages, assets, and interactions mirrored locally." -ForegroundColor Green
