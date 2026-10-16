param(
	[string]$Source = "https://saputo.law",
	[string]$JsonOutput = "content/import/live-posts.json",
	[string]$XmlOutput = "content/import/saputo-live-posts.xml"
)

$ErrorActionPreference = "Stop"

function ConvertFrom-HtmlText {
	param([AllowEmptyString()][string]$Value)
	if (-not $Value) { return "" }
	$text = [regex]::Replace($Value, "<[^>]+>", " ")
	$text = [System.Net.WebUtility]::HtmlDecode($text)
	return [regex]::Replace($text, "\s+", " ").Trim()
}

function Protect-Cdata {
	param([AllowEmptyString()][string]$Value)
	if (-not $Value) { return "" }
	return $Value.Replace("]]>", "]]]]><![CDATA[>")
}

$draftSlugs = @(
	"condena-condicional-y-supervision-de-la-comunidad",
	"federal-habeas-corpus-abogado"
)

$categories = Invoke-RestMethod "$Source/wp-json/wp/v2/categories?per_page=100&_fields=id,name,slug,parent"
$categoryMap = @{}
foreach ($category in $categories) {
	$categoryMap[[int]$category.id] = $category
}

$posts = @()
for ($page = 1; $page -le 20; $page++) {
	$uri = "$Source/wp-json/wp/v2/posts?per_page=50&page=$page&_fields=id,date,date_gmt,modified,slug,link,title,excerpt,content,status,categories,featured_media"
	try {
		$batch = Invoke-RestMethod -Uri $uri
	} catch {
		break
	}
	if (-not $batch -or $batch.Count -eq 0) { break }
	$posts += $batch
	Write-Output ("Fetched page {0}: {1} posts (total {2})" -f $page, $batch.Count, $posts.Count)
	if ($batch.Count -lt 50) { break }
}

$records = foreach ($post in $posts) {
	$status = "publish"
	if ($draftSlugs -contains $post.slug) {
		$status = "draft"
	}

	$postCategories = @()
	foreach ($categoryId in @($post.categories)) {
		$category = $categoryMap[[int]$categoryId]
		if ($category) {
			$postCategories += [pscustomobject]@{
				id     = [int]$category.id
				name   = $category.name
				slug   = $category.slug
				parent = [int]$category.parent
			}
		}
	}

	[pscustomobject][ordered]@{
		id            = $post.id
		slug          = $post.slug
		link          = $post.link
		status        = $status
		date          = $post.date
		dateGmt       = $post.date_gmt
		modified      = $post.modified
		featuredMedia = $post.featured_media
		title         = ConvertFrom-HtmlText $post.title.rendered
		excerpt       = ConvertFrom-HtmlText $post.excerpt.rendered
		content       = $post.content.rendered
		categories    = $postCategories
	}
}

$jsonPath = Join-Path (Get-Location) $JsonOutput
$xmlPath = Join-Path (Get-Location) $XmlOutput
New-Item -ItemType Directory -Force -Path (Split-Path $jsonPath -Parent) | Out-Null

@{
	scrapedAt  = (Get-Date).ToUniversalTime().ToString("o")
	source     = $Source
	count      = $records.Count
	categories = $categories
	posts      = $records
} | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding utf8

$usedCategories = $records |
	ForEach-Object { $_.categories } |
	Sort-Object id -Unique

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
[void]$sb.AppendLine('<rss version="2.0"')
[void]$sb.AppendLine('  xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"')
[void]$sb.AppendLine('  xmlns:content="http://purl.org/rss/1.0/modules/content/"')
[void]$sb.AppendLine('  xmlns:wfw="http://wellformedweb.org/CommentAPI/"')
[void]$sb.AppendLine('  xmlns:dc="http://purl.org/dc/elements/1.1/"')
[void]$sb.AppendLine('  xmlns:wp="http://wordpress.org/export/1.2/">')
[void]$sb.AppendLine('<channel>')
[void]$sb.AppendLine('  <title>Saputo Toufexis posts</title>')
[void]$sb.AppendLine("  <link>$Source</link>")
[void]$sb.AppendLine('  <description>Live WordPress posts for staging import. Spanish posts are imported as drafts.</description>')
[void]$sb.AppendLine('  <pubDate>' + [DateTime]::UtcNow.ToString("r") + '</pubDate>')
[void]$sb.AppendLine('  <language>en-US</language>')
[void]$sb.AppendLine('  <wp:wxr_version>1.2</wp:wxr_version>')
[void]$sb.AppendLine('  <wp:base_site_url>' + $Source + '/</wp:base_site_url>')
[void]$sb.AppendLine('  <wp:base_blog_url>' + $Source + '</wp:base_blog_url>')

foreach ($category in $usedCategories) {
	[void]$sb.AppendLine('  <wp:category>')
	[void]$sb.AppendLine("    <wp:term_id>$($category.id)</wp:term_id>")
	[void]$sb.AppendLine("    <wp:category_nicename>$($category.slug)</wp:category_nicename>")
	[void]$sb.AppendLine('    <wp:category_parent></wp:category_parent>')
	[void]$sb.AppendLine('    <wp:cat_name><![CDATA[' + (Protect-Cdata $category.name) + ']]></wp:cat_name>')
	[void]$sb.AppendLine('  </wp:category>')
}

foreach ($post in $records) {
	$title = [System.Security.SecurityElement]::Escape($post.title)
	$date = [datetime]$post.date
	$dateGmt = if ($post.dateGmt) { [datetime]$post.dateGmt } else { $date.ToUniversalTime() }
	[void]$sb.AppendLine('  <item>')
	[void]$sb.AppendLine("    <title>$title</title>")
	[void]$sb.AppendLine("    <link>$($post.link)</link>")
	[void]$sb.AppendLine('    <pubDate>' + $dateGmt.ToUniversalTime().ToString("r") + '</pubDate>')
	[void]$sb.AppendLine('    <dc:creator><![CDATA[saputo]]></dc:creator>')
	[void]$sb.AppendLine('    <guid isPermaLink="false">' + $post.link + '</guid>')
	[void]$sb.AppendLine('    <description></description>')
	[void]$sb.AppendLine('    <content:encoded><![CDATA[' + (Protect-Cdata $post.content) + ']]></content:encoded>')
	[void]$sb.AppendLine('    <excerpt:encoded><![CDATA[' + (Protect-Cdata $post.excerpt) + ']]></excerpt:encoded>')
	[void]$sb.AppendLine("    <wp:post_id>$($post.id)</wp:post_id>")
	[void]$sb.AppendLine('    <wp:post_date>' + $date.ToString("yyyy-MM-dd HH:mm:ss") + '</wp:post_date>')
	[void]$sb.AppendLine('    <wp:post_date_gmt>' + $dateGmt.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") + '</wp:post_date_gmt>')
	[void]$sb.AppendLine("    <wp:post_modified>$($post.modified)</wp:post_modified>")
	[void]$sb.AppendLine('    <wp:comment_status>closed</wp:comment_status>')
	[void]$sb.AppendLine('    <wp:ping_status>closed</wp:ping_status>')
	[void]$sb.AppendLine("    <wp:post_name>$($post.slug)</wp:post_name>")
	[void]$sb.AppendLine("    <wp:status>$($post.status)</wp:status>")
	[void]$sb.AppendLine('    <wp:post_parent>0</wp:post_parent>')
	[void]$sb.AppendLine('    <wp:menu_order>0</wp:menu_order>')
	[void]$sb.AppendLine('    <wp:post_type>post</wp:post_type>')
	[void]$sb.AppendLine('    <wp:post_password></wp:post_password>')
	[void]$sb.AppendLine('    <wp:is_sticky>0</wp:is_sticky>')
	foreach ($category in $post.categories) {
		[void]$sb.AppendLine('    <category domain="category" nicename="' + $category.slug + '"><![CDATA[' + (Protect-Cdata $category.name) + ']]></category>')
	}
	[void]$sb.AppendLine('  </item>')
}

[void]$sb.AppendLine('</channel>')
[void]$sb.AppendLine('</rss>')
[System.IO.File]::WriteAllText($xmlPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

$draftCount = @($records | Where-Object { $_.status -eq "draft" }).Count
Write-Output ("Wrote {0} posts ({1} drafts) to {2} and {3}" -f $records.Count, $draftCount, $JsonOutput, $XmlOutput)
