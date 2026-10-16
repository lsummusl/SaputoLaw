param(
	[string]$Source = "https://saputo.law",
	[string]$Output = "content/import/saputo-library.xml"
)

$ErrorActionPreference = "Stop"

# Staging already has redesigned copies of these slugs. Importing them again
# would create a second page (press-2, practice-areas-2, and so on).
$SkipSlugs = @(
	"home",
	"attorneys",
	"paul-saputo",
	"nicholas-toufexis",
	"practice-areas",
	"results",
	"victories",
	"testimonials",
	"insights-recognition",
	"press",
	"contact-us",
	"articles",
	"es"
)

function Protect-Cdata {
	param([AllowEmptyString()][string]$Value)
	if (-not $Value) { return "" }
	return $Value.Replace("]]>", "]]]]><![CDATA[>")
}

function ConvertFrom-HtmlText {
	param([AllowEmptyString()][string]$Value)
	if (-not $Value) { return "" }
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

function Get-WpJson {
	param(
		[string]$Uri
	)

	$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("saputo-wxr-" + [guid]::NewGuid().ToString() + ".json")
	$code = & curl.exe -sk --compressed --max-time 120 -o $tmp -w "%{http_code}" $Uri
	if ($code -eq "400" -or -not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
		if (Test-Path $tmp) { Remove-Item $tmp -Force }
		return @()
	}
	$json = [System.IO.File]::ReadAllText($tmp, [System.Text.UTF8Encoding]::new($false))
	Remove-Item $tmp -Force
	if ($json -match '"code"\s*:\s*"rest_post_invalid_page"') {
		return @()
	}
	$raw = $json | ConvertFrom-Json
	if ($null -eq $raw) { return @() }
	if ($raw -is [System.Array] -and $raw.Length -gt 0 -and $raw[0] -is [System.Array]) {
		$raw = $raw[0]
	}
	return @($raw)
}

function Get-WpCollection {
	param(
		[string]$Type,
		[string]$Fields
	)

	$records = New-Object System.Collections.Generic.List[object]
	for ($page = 1; $page -le 80; $page++) {
		$uri = "$Source/wp-json/wp/v2/$Type" + "?per_page=20&page=$page&_fields=$Fields"
		$batch = @(Get-WpJson $uri)
		if ($batch.Count -eq 0) { break }
		foreach ($row in $batch) {
			if ($null -eq $row -or $row -is [System.Array] -or -not $row.id) { continue }
			$records.Add($row)
		}
		Write-Host ("Fetched {0} page {1}: {2} (total {3})" -f $Type, $page, $batch.Count, $records.Count)
		if ($batch.Count -lt 20) { break }
	}
	return $records.ToArray()
}

function Get-Depth {
	param(
		[int]$Id,
		[hashtable]$ById,
		[System.Collections.Generic.HashSet[int]]$Guard
	)
	if (-not $ById.ContainsKey($Id)) { return 0 }
	if (-not $Guard.Add($Id)) { return 0 }
	$parent = 0
	$item = $ById[$Id]
	if ($item.PSObject.Properties.Name -contains "parent" -and $item.parent) {
		$parent = [int]$item.parent
	}
	if ($parent -le 0 -or -not $ById.ContainsKey($parent)) { return 0 }
	return 1 + (Get-Depth $parent $ById $Guard)
}

$pageFields = "id,date,date_gmt,modified,slug,status,link,title,content,excerpt,parent,yoast_head_json"
$postFields = "id,date,date_gmt,modified,slug,status,link,title,content,excerpt,categories,yoast_head_json"

$pages = @(Get-WpCollection "pages" $pageFields)
$posts = @(Get-WpCollection "posts" $postFields)
$categories = @(Get-WpJson "$Source/wp-json/wp/v2/categories?per_page=100&_fields=id,name,slug,parent")

$pages = @($pages | Where-Object { $SkipSlugs -notcontains $_.slug })
$byId = @{}
foreach ($page in $pages) {
	$byId[[int]$page.id] = $page
}

$orderedPages = $pages | Sort-Object { Get-Depth ([int]$_.id) $byId (New-Object "System.Collections.Generic.HashSet[int]") }, id

$usedCategoryIds = New-Object System.Collections.Generic.HashSet[int]
foreach ($post in $posts) {
	foreach ($categoryId in @($post.categories)) {
		[void]$usedCategoryIds.Add([int]$categoryId)
	}
}
$categoryById = @{}
foreach ($category in $categories) {
	if ($category -and $category.id) {
		$categoryById[[int]$category.id] = $category
	}
}
# Include parent categories so the term tree survives the import.
$pending = New-Object System.Collections.Generic.Queue[int]
foreach ($categoryId in $usedCategoryIds) { $pending.Enqueue($categoryId) }
while ($pending.Count -gt 0) {
	$categoryId = $pending.Dequeue()
	if (-not $categoryById.ContainsKey($categoryId)) { continue }
	$parent = [int]$categoryById[$categoryId].parent
	if ($parent -gt 0 -and $usedCategoryIds.Add($parent)) {
		$pending.Enqueue($parent)
	}
}

$outputPath = Join-Path (Get-Location) $Output
New-Item -ItemType Directory -Force -Path (Split-Path $outputPath -Parent) | Out-Null
$writer = New-Object System.IO.StreamWriter($outputPath, $false, [System.Text.UTF8Encoding]::new($false))

function Write-Meta {
	param([string]$Key, [AllowEmptyString()][string]$Value)
	if (-not $Value) { return }
	$writer.WriteLine("    <wp:postmeta>")
	$writer.WriteLine("      <wp:meta_key><![CDATA[$Key]]></wp:meta_key>")
	$writer.WriteLine("      <wp:meta_value><![CDATA[$(Protect-Cdata $Value)]]></wp:meta_value>")
	$writer.WriteLine("    </wp:postmeta>")
}

function Write-Item {
	param(
		$Item,
		[string]$PostType,
		[int]$ParentId,
		[string[]]$CategorySlugs
	)

	$yoast = $Item.yoast_head_json
	$seoTitle = ""
	$description = ""
	if ($yoast) {
		$seoTitle = [string]$yoast.title
		$description = [string]$yoast.description
	}

	$title = Remove-RedirectLabel (ConvertFrom-HtmlText $Item.title.rendered)
	$seoTitle = Remove-RedirectLabel $seoTitle
	$content = ""
	if ($Item.content -and $Item.content.rendered) { $content = Remove-RedirectLabel ([string]$Item.content.rendered) }
	$excerpt = ""
	if ($Item.excerpt -and $Item.excerpt.rendered) { $excerpt = Remove-RedirectLabel (ConvertFrom-HtmlText $Item.excerpt.rendered) }

	$date = [datetime]$Item.date
	$dateGmt = if ($Item.date_gmt) { [datetime]$Item.date_gmt } else { $date.ToUniversalTime() }
	$modified = if ($Item.modified) { [datetime]$Item.modified } else { $date }
	$status = if ($Item.status) { [string]$Item.status } else { "publish" }
	$link = [string]$Item.link

	$writer.WriteLine("  <item>")
	$writer.WriteLine("    <title>$([System.Security.SecurityElement]::Escape($title))</title>")
	$writer.WriteLine("    <link>$([System.Security.SecurityElement]::Escape($link))</link>")
	$writer.WriteLine("    <pubDate>$($dateGmt.ToUniversalTime().ToString('r'))</pubDate>")
	$writer.WriteLine("    <dc:creator><![CDATA[saputo]]></dc:creator>")
	$writer.WriteLine("    <guid isPermaLink=`"false`">$([System.Security.SecurityElement]::Escape($link))</guid>")
	$writer.WriteLine("    <description></description>")
	$writer.WriteLine("    <content:encoded><![CDATA[$(Protect-Cdata $content)]]></content:encoded>")
	$writer.WriteLine("    <excerpt:encoded><![CDATA[$(Protect-Cdata $excerpt)]]></excerpt:encoded>")
	$writer.WriteLine("    <wp:post_id>$([int]$Item.id)</wp:post_id>")
	$writer.WriteLine("    <wp:post_date>$($date.ToString('yyyy-MM-dd HH:mm:ss'))</wp:post_date>")
	$writer.WriteLine("    <wp:post_date_gmt>$($dateGmt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))</wp:post_date_gmt>")
	$writer.WriteLine("    <wp:post_modified>$($modified.ToString('yyyy-MM-dd HH:mm:ss'))</wp:post_modified>")
	$writer.WriteLine("    <wp:post_modified_gmt>$($modified.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))</wp:post_modified_gmt>")
	$writer.WriteLine("    <wp:comment_status>closed</wp:comment_status>")
	$writer.WriteLine("    <wp:ping_status>closed</wp:ping_status>")
	$writer.WriteLine("    <wp:post_name>$([System.Security.SecurityElement]::Escape([string]$Item.slug))</wp:post_name>")
	$writer.WriteLine("    <wp:status>$status</wp:status>")
	$writer.WriteLine("    <wp:post_parent>$ParentId</wp:post_parent>")
	$writer.WriteLine("    <wp:menu_order>0</wp:menu_order>")
	$writer.WriteLine("    <wp:post_type>$PostType</wp:post_type>")
	$writer.WriteLine("    <wp:post_password></wp:post_password>")
	$writer.WriteLine("    <wp:is_sticky>0</wp:is_sticky>")
	foreach ($slug in $CategorySlugs) {
		$category = $categories | Where-Object { $_.slug -eq $slug } | Select-Object -First 1
		$name = if ($category) { [string]$category.name } else { $slug }
		$writer.WriteLine("    <category domain=`"category`" nicename=`"$slug`"><![CDATA[$(Protect-Cdata $name)]]></category>")
	}
	Write-Meta "_yoast_wpseo_title" $seoTitle
	Write-Meta "_yoast_wpseo_metadesc" $description
	$writer.WriteLine("  </item>")
}

try {
	$writer.WriteLine('<?xml version="1.0" encoding="UTF-8" ?>')
	$writer.WriteLine('<rss version="2.0"')
	$writer.WriteLine('  xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"')
	$writer.WriteLine('  xmlns:content="http://purl.org/rss/1.0/modules/content/"')
	$writer.WriteLine('  xmlns:dc="http://purl.org/dc/elements/1.1/"')
	$writer.WriteLine('  xmlns:wp="http://wordpress.org/export/1.2/">')
	$writer.WriteLine("<channel>")
	$writer.WriteLine("  <title>Saputo Toufexis library</title>")
	$writer.WriteLine("  <link>$Source</link>")
	$writer.WriteLine("  <description>Library pages and posts with Yoast titles and descriptions. Redesigned front-door pages are omitted.</description>")
	$writer.WriteLine("  <pubDate>$([DateTime]::UtcNow.ToString('r'))</pubDate>")
	$writer.WriteLine("  <language>en-US</language>")
	$writer.WriteLine("  <wp:wxr_version>1.2</wp:wxr_version>")
	$writer.WriteLine("  <wp:base_site_url>$Source/</wp:base_site_url>")
	$writer.WriteLine("  <wp:base_blog_url>$Source</wp:base_blog_url>")
	$writer.WriteLine("  <wp:author>")
	$writer.WriteLine("    <wp:author_id>1</wp:author_id>")
	$writer.WriteLine("    <wp:author_login><![CDATA[saputo]]></wp:author_login>")
	$writer.WriteLine("    <wp:author_email><![CDATA[import@saputo.law]]></wp:author_email>")
	$writer.WriteLine("    <wp:author_display_name><![CDATA[Saputo Toufexis]]></wp:author_display_name>")
	$writer.WriteLine("    <wp:author_first_name><![CDATA[]]></wp:author_first_name>")
	$writer.WriteLine("    <wp:author_last_name><![CDATA[]]></wp:author_last_name>")
	$writer.WriteLine("  </wp:author>")

	foreach ($category in ($categories | Where-Object { $_ -and $_.id -and $usedCategoryIds.Contains([int]$_.id) })) {
		$parentSlug = ""
		$parentId = [int]$category.parent
		if ($parentId -gt 0 -and $categoryById.ContainsKey($parentId)) {
			$parentSlug = [string]$categoryById[$parentId].slug
		}
		$writer.WriteLine("  <wp:category>")
		$writer.WriteLine("    <wp:term_id>$([int]$category.id)</wp:term_id>")
		$writer.WriteLine("    <wp:category_nicename>$([System.Security.SecurityElement]::Escape([string]$category.slug))</wp:category_nicename>")
		$writer.WriteLine("    <wp:category_parent>$parentSlug</wp:category_parent>")
		$writer.WriteLine("    <wp:cat_name><![CDATA[$(Protect-Cdata ([string]$category.name))]]></wp:cat_name>")
		$writer.WriteLine("  </wp:category>")
	}

	foreach ($page in $orderedPages) {
		$parentOut = 0
		if ($page.parent -and $byId.ContainsKey([int]$page.parent)) {
			$parentOut = [int]$page.parent
		}
		Write-Item $page "page" $parentOut @()
	}

	foreach ($post in $posts) {
		$slugs = @()
		foreach ($categoryId in @($post.categories)) {
			if ($categoryById.ContainsKey([int]$categoryId)) {
				$slugs += [string]$categoryById[[int]$categoryId].slug
			}
		}
		Write-Item $post "post" 0 $slugs
	}

	$writer.WriteLine("</channel>")
	$writer.WriteLine("</rss>")
}
finally {
	$writer.Dispose()
}

Write-Host ("Wrote {0} pages and {1} posts to {2}" -f @($orderedPages).Count, @($posts).Count, $Output)
