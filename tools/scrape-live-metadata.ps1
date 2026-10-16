param(
	[string]$Source = "https://saputo.law",
	[string]$MetadataOutput = "content/import/live-metadata.json",
	[string]$LinksOutput = "wp-content/themes/saputo-law/data/library-links.json"
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

function Remove-RedirectLabel {
	param([AllowEmptyString()][string]$Value)
	if (-not $Value) { return "" }
	$clean = [regex]::Replace($Value, '\(\s*redirect(?:ed)?\s*\)\s*', '', 'IgnoreCase')
	return [regex]::Replace($clean, '\s+', ' ').Trim()
}

function Get-ShortText {
	param(
		[AllowEmptyString()][string]$Value,
		[int]$Limit = 180
	)

	if (-not $Value) {
		return ""
	}

	$clean = $Value.Trim().TrimEnd('.', ' ')
	$clean = $clean -replace "\s*(\[&\s*hellip;\s*\]|&hellip;|\.\.\.)\s*$", ""
	if ($clean.Length -le $Limit) {
		return $clean
	}

	$cut = $clean.Substring(0, $Limit)
	$space = $cut.LastIndexOf(" ")
	if ($space -gt 80) {
		$cut = $cut.Substring(0, $space)
	}
	return $cut.TrimEnd(',', ';', ':') + "..."
}

function Test-GenericDescription {
	param([AllowEmptyString()][string]$Value)

	if (-not $Value) {
		return $true
	}

	return $Value -match "(?i)(call (us )?(today|now)|free consultation|schedule a |contact us|aggressive (legal )?defense|want to represent you|best .+ (lawyer|attorney))"
}

function Get-WpCollection {
	param(
		[string]$Type
	)

	$records = New-Object System.Collections.Generic.List[object]
	for ($page = 1; $page -le 40; $page++) {
		$uri = "$Source/wp-json/wp/v2/$Type" + "?per_page=100&page=$page&_fields=id,slug,link,parent,type,title,excerpt,yoast_head_json"
		$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("saputo-" + $Type + "-" + $page + ".json")
		& curl.exe -sk --compressed --max-time 60 -o $tmp -w "%{http_code}" $uri | Out-Null
		if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
			break
		}
		$json = [System.IO.File]::ReadAllText($tmp, [System.Text.UTF8Encoding]::new($false))
		Remove-Item $tmp -Force
		if ($json -match '^\s*\{' -and $json -match '"code"\s*:\s*"rest_post_invalid_page"') {
			break
		}
		$raw = $json | ConvertFrom-Json

		if ($null -eq $raw) {
			break
		}

		# Invoke-RestMethod sometimes returns the JSON array wrapped in one extra array.
		if ($raw -is [System.Array] -and $raw.Length -gt 0 -and $raw[0] -is [System.Array]) {
			$raw = $raw[0]
		}

		$batch = @($raw)
		if ($batch.Count -eq 0) {
			break
		}

		foreach ($row in $batch) {
			$records.Add($row)
		}
		Write-Host ("Fetched {0} page {1}: {2} (total {3})" -f $Type, $page, $batch.Count, $records.Count)
		if ($batch.Count -lt 100) {
			break
		}
	}

	return $records.ToArray()
}

$pages = @(Get-WpCollection "pages")
$posts = @(Get-WpCollection "posts")
$byId = @{}

foreach ($item in ($pages + $posts)) {
	if ($item -is [string] -or -not $item.id) {
		continue
	}
	$idValue = $item.id
	if ($idValue -is [System.Array]) {
		$idValue = $idValue[0]
	}
	$byId[[int]$idValue] = $item
}

$entries = foreach ($item in ($pages + $posts)) {
	if ($item -is [string] -or -not $item.id) {
		continue
	}

	$idValue = $item.id
	if ($idValue -is [System.Array]) {
		$idValue = $idValue[0]
	}
	$yoast = $item.yoast_head_json
	$seoTitle = ""
	$description = ""
	$canonical = ""
	if ($yoast) {
		$seoTitle = [string]$yoast.title
		$description = [string]$yoast.description
		$canonical = [string]$yoast.canonical
	}

	$pageTitle = Remove-RedirectLabel (ConvertFrom-HtmlText $item.title.rendered)
	$seoTitle = Remove-RedirectLabel $seoTitle
	$excerpt = Remove-RedirectLabel (ConvertFrom-HtmlText $item.excerpt.rendered)
	$path = ([uri]$item.link).AbsolutePath
	if (-not $path.EndsWith("/")) {
		$path += "/"
	}

	$parentSlug = ""
	$parentId = 0
	if ($item.PSObject.Properties.Name -contains "parent" -and $item.parent) {
		$parentId = [int]$item.parent
		if ($byId.ContainsKey($parentId)) {
			$parentSlug = [string]$byId[$parentId].slug
		}
	}

	[ordered]@{
		id          = [int]$idValue
		type        = if ($item.type) { [string]$item.type } else { "post" }
		slug        = [string]$item.slug
		path        = $path
		parent      = $parentId
		parentSlug  = $parentSlug
		title       = $pageTitle
		seoTitle    = $seoTitle
		description = $description
		excerpt     = Get-ShortText $excerpt 220
		canonical   = if ($canonical) { $canonical } else { [string]$item.link }
	}
}

$entries = @($entries | Sort-Object path)
$metadata = [ordered]@{
	scrapedAt = (Get-Date).ToUniversalTime().ToString("o")
	source    = $Source
	count     = $entries.Count
	entries   = $entries
}

$sections = @(
	[ordered]@{
		id      = "practice"
		heading = "Guides from the library"
		intro   = "These guides stay at their current addresses. Open one for the full explanation."
		paths   = @(
			"/criminal-law/",
			"/criminal-investigation/",
			"/arrested-in-texas/",
			"/fighting-a-charge/",
			"/dallas-dwi-attorney/",
			"/dallas-assault-attorney/",
			"/dallas-sexual-assault-attorney/",
			"/dallas-murder-attorney/",
			"/federal-criminal-defense-attorneys/",
			"/texas-criminal-appeal-attorney/",
			"/criminal-law/record-clearing/",
			"/sex-offender-deregistration/",
			"/dwi-defense-resources/"
		)
	},
	[ordered]@{
		id      = "insights"
		heading = "From the legal library"
		intro   = "The statute library and practice guides remain published. These are the places to start."
		paths   = @(
			"/criminal-law/",
			"/criminal-law/texas/",
			"/criminal-law/record-clearing/",
			"/criminal-law/texas-probation-law/",
			"/criminal-law/federal/federal-habeas-corpus/",
			"/dwi-defense-resources/",
			"/texas-criminal-law/new-texas-criminal-laws-2025/"
		)
	}
)

$byPath = @{}
foreach ($entry in $entries) {
	$byPath[$entry.path] = $entry
}

$linkSections = foreach ($section in $sections) {
	$links = foreach ($path in $section.paths) {
		if (-not $byPath.ContainsKey($path)) {
			Write-Warning "No metadata for $path"
			continue
		}

		$entry = $byPath[$path]
		$summary = $entry.description
		if (Test-GenericDescription $summary) {
			$summary = $entry.excerpt
		}

		[ordered]@{
			title       = $entry.title
			description = Get-ShortText $summary 180
			path        = $entry.path
		}
	}

	[ordered]@{
		id      = $section.id
		heading = $section.heading
		intro   = $section.intro
		links   = @($links)
	}
}

$linksDocument = [ordered]@{
	scrapedAt = $metadata.scrapedAt
	source    = $Source
	sections  = @($linkSections)
}

function Write-JsonFile {
	param(
		[string]$RelativePath,
		[object]$Value
	)

	$path = Join-Path (Get-Location) $RelativePath
	New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent) | Out-Null
	$json = $Value | ConvertTo-Json -Depth 8
	[System.IO.File]::WriteAllText($path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
	Write-Output "Wrote $RelativePath"
}

Write-JsonFile $MetadataOutput $metadata
Write-JsonFile $LinksOutput $linksDocument
Write-Output ("Cataloged {0} pages and posts." -f $entries.Count)
