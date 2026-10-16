param(
	[string]$Source = "https://saputo.law",
	[string]$Output = "content/site-content.json"
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

	$uri = "$Source/wp-json/wp/v2/pages?slug=$Slug&per_page=1&_fields=link,modified,title,content"
	$result = Invoke-RestMethod -Uri $uri
	if ($result.Count -eq 0) {
		throw "Page '$Slug' was not found at $Source."
	}
	return $result[0]
}

$postsUri = "$Source/wp-json/wp/v2/posts?per_page=100&_fields=id,date,modified,slug,link,title,excerpt"
$posts = Invoke-RestMethod -Uri $postsUri

$articles = foreach ($post in $posts) {
	$section = switch -Regex ($post.link) {
		"/firm-updates/" { "Honors"; break }
		"/blog/" { "Practical Guides"; break }
		"/texas-criminal-law/" { "Legal Analysis"; break }
		default { "Other" }
	}

	[ordered]@{
		id       = $post.id
		title    = ConvertFrom-HtmlText $post.title.rendered
		date     = ([datetime]$post.date).ToString("yyyy-MM-dd")
		modified = ([datetime]$post.modified).ToString("yyyy-MM-dd")
		url      = $post.link
		section  = $section
		excerpt  = ConvertFrom-HtmlText $post.excerpt.rendered
	}
}

$pressPage = Get-PageBySlug "press"
$pressLinks = [regex]::Matches(
	$pressPage.content.rendered,
	'<a[^>]+href=["''](?<url>https?://[^"'']+)["''][^>]*>(?<label>.*?)</a>',
	[System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

$pressLabels = @{}
foreach ($match in $pressLinks) {
	$url = [System.Net.WebUtility]::HtmlDecode($match.Groups["url"].Value)
	$label = ConvertFrom-HtmlText $match.Groups["label"].Value
	if ($label) {
		$pressLabels[$url] = $label
	}
}

$allPressUrls = @($pressLabels.Keys)
$allPressUrls += [regex]::Matches(
	$pressPage.content.rendered,
	'https?://[^\s<>"'']+',
	[System.Text.RegularExpressions.RegexOptions]::IgnoreCase
) | ForEach-Object {
	$_.Value.TrimEnd(".", ",", ")", "]")
}

$press = foreach ($url in ($allPressUrls | Sort-Object -Unique)) {
	$hostName = ([uri]$url).Host -replace "^www\.", ""
	$label = $pressLabels[$url]

	if ($hostName -notlike "*.saputo.law" -and $hostName -ne "saputo.law") {
		[pscustomobject][ordered]@{
			outlet = $hostName
			title  = if ($label) { $label } else { "Coverage on $hostName" }
			url    = $url
		}
	}
}

$press = $press |
	Group-Object url |
	ForEach-Object { $_.Group[0] } |
	Sort-Object outlet, title

$recognitions = @(
	[ordered]@{
		attorney = "Paul Saputo"
		title    = "Best Lawyers in Dallas"
		issuer   = "D Magazine"
		year     = 2024
		source   = "$Source/firm-updates/best-lawyers-2024-paul-saputo-recognized-as-best-lawyer-by-d-magazine-in-2024/"
	},
	[ordered]@{
		attorney = "Paul Saputo"
		title    = "Silver Client Champion"
		issuer   = "Martindale-Hubbell"
		year     = 2021
		source   = "$Source/firm-updates/paul-saputo-receives-silver-client-champion-award-from-martindale-hubbell/"
	},
	[ordered]@{
		attorney = "Paul Saputo"
		title    = "AV Preeminent Peer Review Rating"
		issuer   = "Martindale-Hubbell"
		year     = 2020
		source   = "$Source/texas-criminal-law/saputo-law-firm-receives-av-preeminent-peer-review-rating-for-paul-saputo-from-martindale-hubbell/"
	},
	[ordered]@{
		attorney = "Nicholas Toufexis"
		title    = "Ones to Watch in America - DWI/DUI Defense"
		issuer   = "Best Lawyers"
		year     = 2025
		source   = "$Source/about/nicholas-toufexis/"
	},
	[ordered]@{
		attorney = "Nicholas Toufexis"
		title    = "Rising Star"
		issuer   = "Super Lawyers"
		year     = $null
		source   = "$Source/about/nicholas-toufexis/"
	},
	[ordered]@{
		attorney = "Nicholas Toufexis"
		title    = "One to Watch"
		issuer   = "Dallas Association of Young Lawyers"
		year     = 2023
		source   = "$Source/about/nicholas-toufexis/"
	}
)

$inventory = [ordered]@{
	scrapedAt   = (Get-Date).ToUniversalTime().ToString("o")
	source      = $Source
	counts      = [ordered]@{
		articles     = $articles.Count
		pressLinks   = @($press).Count
		recognitions = $recognitions.Count
	}
	articles    = @($articles)
	press       = @($press)
	recognitions = $recognitions
}

$outputPath = Join-Path (Get-Location) $Output
$outputDirectory = Split-Path $outputPath -Parent
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$inventory | ConvertTo-Json -Depth 8 | Set-Content -Path $outputPath -Encoding utf8

Write-Output "Saved $($articles.Count) articles, $(@($press).Count) press links, and $($recognitions.Count) recognitions to $Output."
