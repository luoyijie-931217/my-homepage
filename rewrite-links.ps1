# ==============================================================================
# TheShampooFactory Local Link & Asset Rewriter + Interactive Injector
# ==============================================================================

$TargetDir = "D:\my-homepage"
$BaseUrl = "https://theshampoofactory.com"

# Known 301 redirects
$redirectMap = @{
    "products/shampoo/hair-strengthening-shampoo" = "products/hair-strengthening-shampoo"
    "products/shampoo/organic-keratin-shampoo-and-hair-care-set" = "products/organic-keratin-shampoo-and-hair-care-set"
    "products/conditioner/coconut-oil-conditioner" = "products/coconut-oil-conditioner"
    "products/conditioner/red-onion-conditioner" = "products/red-onion-conditioner"
    "products/conditioner/caviar-nourishing-conditioner" = "products/caviar-nourishing-conditioner"
    "products/conditioner/caviar-sulfate-free-conditioner" = "products/caviar-sulfate-free-conditioner"
    "products/conditioner/natural-curls-conditioner" = "products/natural-curls-conditioner"
    "products/conditioner/keratin-hair-conditioner" = "products/keratin-hair-conditioner"
    "products/conditioner/botox-repairing-conditioner" = "products/botox-repairing-conditioner"
    "products/hair-oil/tea-tree-hair-oil" = "products/tea-tree-hair-oil"
    "products/hair-oil/repair-hydrating-hair-oil" = "products/repair-hydrating-hair-oil"
    "products/hair-oil/pure-natural-hair-oil" = "products/pure-natural-hair-oil"
    "products/hair-oil/moroccan-argan-essential-hair-oil" = "products/moroccan-argan-essential-hair-oil"
    "products/hair-oil/rosemary-mint-hair-serum" = "products/rosemary-mint-hair-serum"
    "products/hair-oil/thrive-hair-growth-oil" = "products/thrive-hair-growth-oil"
    "products/hair-oil/growth-hair-essential-oil" = "products/growth-hair-essential-oil"
    "products/hair-mask/keratin-deep-repair-hair-mask" = "products/keratin-deep-repair-hair-mask"
    "products/hair-mask/curly-repair-hair-mask" = "products/curly-repair-hair-mask"
    "products/hair-mask/organic-repair-hair-mask" = "products/organic-repair-hair-mask"
    "products/hair-mask/botox-repair-hair-mask" = "products/botox-repair-hair-mask"
    "products/hair-mask/gold-caviar-hair-mask" = "products/gold-caviar-hair-mask"
    "products/hair-mask/hair-mask-for-natural-curls" = "products/hair-mask-for-natural-curls"
    "hair-mask" = "products/hair-mask"
}

# 1. Create redirect shim files
Write-Host "Creating redirect shims..." -ForegroundColor Cyan
foreach ($srcKey in $redirectMap.Keys) {
    $dstKey = $redirectMap[$srcKey]
    $shimFolder = Join-Path $TargetDir ($srcKey -replace '/', '\')
    if (-not (Test-Path $shimFolder)) {
        New-Item -ItemType Directory -Path $shimFolder -Force | Out-Null
    }
    $shimFile = Join-Path $shimFolder "index.html"

    $depth = ($srcKey -split '/').Length
    $prefix = ""
    for ($d = 0; $d -lt $depth; $d++) { $prefix += "../" }
    $targetHtml = "${prefix}$dstKey/index.html"

    $shimHtml = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="0; url=$targetHtml">
<script>window.location.replace('$targetHtml');</script>
<title>Redirecting...</title>
</head>
<body>
<p>Redirecting to <a href="$targetHtml">$dstKey</a>...</p>
</body>
</html>
"@
    [System.IO.File]::WriteAllText($shimFile, $shimHtml, [System.Text.Encoding]::UTF8)
}

# 2. Iterate all index.html files and rewrite
Write-Host "Rewriting links and assets across all HTML files..." -ForegroundColor Cyan
$htmlFiles = Get-ChildItem -Path $TargetDir -Filter "index.html" -Recurse

$processed = 0
foreach ($hf in $htmlFiles) {
    $processed++
    $raw = [System.IO.File]::ReadAllText($hf.FullName, [System.Text.Encoding]::UTF8)

    # Skip shim files
    if ($raw -match 'Redirecting\.\.\.') {
        continue
    }

    $relDir = $hf.DirectoryName.Substring($TargetDir.Length).TrimStart('\')
    $depth = 0
    if ($relDir.Length -gt 0) {
        $depth = ($relDir -split '\\').Length
    }

    $prefix = ""
    for ($d = 0; $d -lt $depth; $d++) { $prefix += "../" }

    # A. Strip blocking analytics, tracking, Cloudflare Turnstile & email protection scripts
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*googletagmanager[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script id="google_gtagjs-js-after"[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*googlesitekit-events[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*email-decode\.min\.js[^>]*>.*?</script>', '')
    $raw = [regex]::Replace($raw, '(?s)<script[^>]*challenges\.cloudflare\.com/turnstile[^>]*>.*?</script>', '')

    # Fix any accidental /index.html appended to media/asset file extensions
    $raw = [regex]::Replace($raw, '\.(webp|png|jpg|jpeg|svg|ico|gif|xml|txt|php|css|js)/index\.html', '.$1')
    $raw = [regex]::Replace($raw, '\.(webp|png|jpg|jpeg|svg|ico|gif|xml|txt|php|css|js)/', '.$1')

    # B. Rewrite static assets first: https://theshampoofactory.com/(wp-...) with single or double quotes
    $raw = [regex]::Replace($raw, '((?:href|src|content)=[''"]?)https://theshampoofactory\.com/(wp-[^''"\s\?]+)(?:\?[^''"\s]*)?', {
        param($m)
        return $m.Groups[1].Value + $prefix + $m.Groups[2].Value
    })

    # C. Rewrite inline CSS url(...) pointing to wp-
    $raw = [regex]::Replace($raw, 'url\(([''"]?)https://theshampoofactory\.com/(wp-[^''"\s\)\?]+)(?:\?[^''"\s\)]*)?([''"]?)\)', {
        param($m)
        return "url(" + $m.Groups[1].Value + $prefix + $m.Groups[2].Value + $m.Groups[3].Value + ")"
    })

    # D. Rewrite absolute internal page links: https://theshampoofactory.com/<path>/
    $raw = [regex]::Replace($raw, 'href="https://theshampoofactory\.com/([^"#\?]*)/?([#\?][^"]*)?"', {
        param($m)
        $sub = $m.Groups[1].Value.Trim('/')
        $frag = $m.Groups[2].Value

        # If it's a file or asset
        if ($sub -match '\.(webp|png|jpg|jpeg|svg|ico|gif|css|js|xml|txt|php)$' -or $sub -match '^wp-') {
            return "href=""${prefix}$sub$frag"""
        }

        # Check redirect map
        if ($redirectMap.ContainsKey($sub)) {
            $sub = $redirectMap[$sub]
        }

        if ([string]::IsNullOrEmpty($sub)) {
            return "href=""${prefix}index.html$frag"""
        } else {
            return "href=""${prefix}$sub/index.html$frag"""
        }
    })

    # E. Rewrite root-relative links: href="/<path>"
    $raw = [regex]::Replace($raw, 'href="/([a-zA-Z0-9\-_/]+)/?"', {
        param($m)
        $sub = $m.Groups[1].Value.Trim('/')
        if ($sub -match '^cdn-cgi') {
            return 'href="#"'
        }
        if ($sub -match '\.(webp|png|jpg|jpeg|svg|ico|gif|css|js|xml|txt|php)$' -or $sub -match '^wp-') {
            return "href=""${prefix}$sub"""
        }
        if ($redirectMap.ContainsKey($sub)) {
            $sub = $redirectMap[$sub]
        }
        return "href=""${prefix}$sub/index.html"""
    })

    # F. Rewrite srcset
    $raw = [regex]::Replace($raw, 'srcset="([^"]+)"', {
        param($sm)
        $entries = $sm.Groups[1].Value -split ','
        $newEntries = foreach ($e in $entries) {
            $eClean = $e.Trim()
            [regex]::Replace($eClean, 'https://theshampoofactory\.com/(wp-[^\s\?]+)(?:\?[^\s]*)?', "${prefix}`$1")
        }
        return 'srcset="' + ($newEntries -join ', ') + '"'
    })

    # G. Rewrite JSON / escaped URLs in script tags and data-settings (Blocksy & Elementor configs)
    $escapedPrefix = $prefix.Replace('/', '\/')
    $raw = $raw -replace 'https?:\\/\\/theshampoofactory\.com\\/wp-content', "${escapedPrefix}wp-content"
    $raw = $raw -replace 'https?:\\/\\/theshampoofactory\.com\\/wp-includes', "${escapedPrefix}wp-includes"
    $raw = $raw -replace 'https://theshampoofactory\.com/wp-content', "${prefix}wp-content"
    $raw = $raw -replace 'https://theshampoofactory\.com/wp-includes', "${prefix}wp-includes"

    # G. Inject local-fixes.css before </head>
    if ($raw -notmatch 'local-fixes\.css') {
        $raw = $raw -replace '</head>', "<link rel=""stylesheet"" href=""${prefix}local-fixes.css"">`n</head>"
    }

    # H. Inject local-fixes.js before </body>
    if ($raw -notmatch 'local-fixes\.js') {
        $raw = $raw -replace '</body>', "<script src=""${prefix}local-fixes.js""></script>`n</body>"
    }

    [System.IO.File]::WriteAllText($hf.FullName, $raw, [System.Text.Encoding]::UTF8)
}

Write-Host "Completed rewriting $processed HTML files!" -ForegroundColor Green
