param(
	[string]$Source = "https://saputo.law",
	[string]$Manifest = "content/marketing-assets.json",
	[string]$MediaInventory = "content/media-library.json",
	[string]$DownloadDirectory = "wp-content/themes/saputo-law/assets/images/source"
)

$ErrorActionPreference = "Stop"

function ConvertFrom-HtmlText {
	param([AllowEmptyString()][string]$Value)

	if (-not $Value) {
		return ""
	}

	$text = [regex]::Replace($Value, "<[^>]+>", " ")
	$text = [System.Net.WebUtility]::HtmlDecode($text)
	return [regex]::Replace($text, "\s+", " ").Trim()
}

function Get-PageBySlug {
	param([string]$Slug)

	$uri = "$Source/wp-json/wp/v2/pages?slug=$Slug&per_page=1&_fields=id,slug,link,title,content"
	$result = Invoke-RestMethod -Uri $uri
	return @($result)
}

function Get-SafeFilename {
	param([string]$Url)

	$uri = [uri]$Url
	$name = [System.IO.Path]::GetFileName($uri.LocalPath)
	if (-not $name) {
		$name = ([guid]::NewGuid().ToString() + ".bin")
	}
	return $name
}

$pageSlugs = @(
	"home",
	"paul-saputo",
	"nicholas-toufexis",
	"practice-areas",
	"press",
	"victories"
)

$assetMap = @{}

foreach ($slug in $pageSlugs) {
	foreach ($page in (Get-PageBySlug $slug)) {
		$html = $page.content.rendered
		$tags = [regex]::Matches($html, '<img\b[^>]*>', 'IgnoreCase')

		foreach ($tag in $tags) {
			$urlMatch = [regex]::Match(
				$tag.Value,
				'(?:data-src|src)=["''](?<url>https?://[^"'']+)["'']',
				'IgnoreCase'
			)
			if (-not $urlMatch.Success) {
				continue
			}

			$url = [System.Net.WebUtility]::HtmlDecode($urlMatch.Groups["url"].Value)
			if ($url -like "https://i.ytimg.com/vi/ID/*") {
				continue
			}

			$altMatch = [regex]::Match($tag.Value, 'alt=["''](?<alt>[^"'']*)["'']', 'IgnoreCase')
			$alt = if ($altMatch.Success) {
				[System.Net.WebUtility]::HtmlDecode($altMatch.Groups["alt"].Value)
			} else {
				""
			}

			if (-not $assetMap.ContainsKey($url)) {
				$assetMap[$url] = [pscustomobject][ordered]@{
					sourceUrl = $url
					filename  = Get-SafeFilename $url
					alt       = $alt
					usedOn    = @()
					localPath = $null
					bytes     = 0
					error     = $null
				}
			}
			$assetMap[$url].usedOn += $page.link
		}

		$backgrounds = [regex]::Matches(
			$html,
			'url\((?:&quot;|["'']?)(?<url>https?://[^\)"'']+)(?:&quot;|["'']?)\)',
			'IgnoreCase'
		)
		foreach ($background in $backgrounds) {
			$url = [System.Net.WebUtility]::HtmlDecode($background.Groups["url"].Value)
			if (-not $assetMap.ContainsKey($url)) {
				$assetMap[$url] = [pscustomobject][ordered]@{
					sourceUrl = $url
					filename  = Get-SafeFilename $url
					alt       = ""
					usedOn    = @()
					localPath = $null
					bytes     = 0
					error     = $null
				}
			}
			$assetMap[$url].usedOn += $page.link
		}
	}
}

$featuredAssets = @(
	[pscustomobject]@{
		sourceUrl = "$Source/wp-content/uploads/2025/03/Nicholas-Toufexis-Paul-Saputo-10.webp"
		alt       = "Nicholas Toufexis and Paul Saputo"
		usedOn    = "$Source/"
	},
	[pscustomobject]@{
		sourceUrl = "$Source/wp-content/uploads/2025/09/AV-Preeminent-2026-Paul-Saputo-Criminal-Lawyer-Badge.webp"
		alt       = "Martindale-Hubbell AV Preeminent 2026 recognition for Paul Saputo"
		usedOn    = "$Source/"
	},
	[pscustomobject]@{
		sourceUrl = "$Source/wp-content/uploads/2026/09/d-mag-2026-dark-full-size.webp"
		alt       = "D Magazine Best Lawyers in Dallas 2026 recognition"
		usedOn    = "$Source/"
	},
	[pscustomobject]@{
		sourceUrl = "$Source/wp-content/uploads/2026/09/Ones-To-Watch-Lawyer-Logo-Nicholas-Toufexis-2026-scaled.webp"
		alt       = "Best Lawyers Ones to Watch 2026 recognition for Nicholas Toufexis"
		usedOn    = "$Source/"
	},
	[pscustomobject]@{
		sourceUrl = "$Source/wp-content/uploads/2026/09/Texas-Super-Lawyers-2026.webp"
		alt       = "Texas Super Lawyers 2026 recognition"
		usedOn    = "$Source/"
	}
)

foreach ($featured in $featuredAssets) {
	if (-not $assetMap.ContainsKey($featured.sourceUrl)) {
		$assetMap[$featured.sourceUrl] = [pscustomobject][ordered]@{
			sourceUrl = $featured.sourceUrl
			filename  = Get-SafeFilename $featured.sourceUrl
			alt       = $featured.alt
			usedOn    = @($featured.usedOn)
			localPath = $null
			bytes     = 0
			error     = $null
		}
	}
}

$downloadRoot = Join-Path (Get-Location) $DownloadDirectory
New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
$usedNames = @{}

foreach ($asset in $assetMap.Values) {
	$name = $asset.filename
	if ($usedNames.ContainsKey($name)) {
		$stem = [System.IO.Path]::GetFileNameWithoutExtension($name)
		$extension = [System.IO.Path]::GetExtension($name)
		$name = "$stem-$($usedNames[$asset.filename] + 1)$extension"
		$usedNames[$asset.filename] += 1
	} else {
		$usedNames[$name] = 0
	}

	$target = Join-Path $downloadRoot $name
	try {
		Invoke-WebRequest -Uri $asset.sourceUrl -OutFile $target -UseBasicParsing
		$asset.filename = $name
		$asset.localPath = ($DownloadDirectory.TrimEnd("/") + "/" + $name).Replace("\", "/")
		$asset.bytes = (Get-Item $target).Length
		$asset.usedOn = @($asset.usedOn | Sort-Object -Unique)
	} catch {
		$asset.localPath = $null
		$asset.bytes = 0
		$asset.error = $_.Exception.Message
	}
}

$media = @()
for ($pageNumber = 1; $pageNumber -le 8; $pageNumber++) {
	$uri = "$Source/wp-json/wp/v2/media?per_page=100&page=$pageNumber&_fields=id,date,modified,slug,source_url,alt_text,caption,media_type,mime_type,media_details"
	$pageItems = Invoke-RestMethod -Uri $uri
	foreach ($item in $pageItems) {
		$media += $item
	}
}

$manifestPath = Join-Path (Get-Location) $Manifest
$inventoryPath = Join-Path (Get-Location) $MediaInventory
New-Item -ItemType Directory -Force -Path (Split-Path $manifestPath -Parent) | Out-Null

$result = [ordered]@{
	scrapedAt = (Get-Date).ToUniversalTime().ToString("o")
	source    = $Source
	pages     = $pageSlugs
	count     = $assetMap.Count
	assets    = @($assetMap.Values | Sort-Object filename)
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding utf8
$media | ConvertTo-Json -Depth 10 | Set-Content -Path $inventoryPath -Encoding utf8

$downloaded = @($assetMap.Values | Where-Object { $_.localPath }).Count
$bytes = ($assetMap.Values | Measure-Object -Property bytes -Sum).Sum
Write-Output "Saved $downloaded marketing images ($bytes bytes) and indexed $($media.Count) media-library items."
