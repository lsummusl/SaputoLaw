param(
	[string]$Source = "https://saputo.law",
	[string]$JsonOutput = "content/import/live-pages.json",
	[string]$XmlOutput = "content/import/saputo-live-pages.xml"
)

$ErrorActionPreference = "Stop"

$pageIds = @(
	6249,   # about
	11522,  # paul-saputo
	11517,  # nicholas-toufexis
	10134,  # practice-areas
	4565,   # victories
	990,    # press
	8393,   # contact-us
	11290,  # spanish homepage
	3,      # privacy
	838,    # terms
	814,    # faq
	6902,   # consultations
	3548,   # client-portal
	986,    # testimonials
	207,    # arrested-in-texas
	209,    # what-to-expect-in-court
	218,    # criminal-investigation
	345,    # texas-criminal-defense
	812,    # fighting-a-charge
	828,    # sex-offender-deregistration
	836,    # texas-courts
	872,    # dwi-defense-resources
	821,    # legal-acronyms
	817,    # occupational drivers license
	659     # book-now
)

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

$pages = @()
foreach ($id in $pageIds) {
	$uri = "$Source/wp-json/wp/v2/pages/$id" + '?_fields=id,date,modified,slug,link,title,excerpt,content,parent,status,featured_media'
	$page = Invoke-RestMethod -Uri $uri
	$pages += [pscustomobject][ordered]@{
		id             = $page.id
		slug           = $page.slug
		link           = $page.link
		status         = $page.status
		parent         = $page.parent
		date           = $page.date
		modified       = $page.modified
		featuredMedia  = $page.featured_media
		title          = ConvertFrom-HtmlText $page.title.rendered
		excerpt        = ConvertFrom-HtmlText $page.excerpt.rendered
		content        = $page.content.rendered
	}
	Write-Output ("Fetched {0} ({1})" -f $page.slug, $page.id)
}

$jsonPath = Join-Path (Get-Location) $JsonOutput
$xmlPath = Join-Path (Get-Location) $XmlOutput
New-Item -ItemType Directory -Force -Path (Split-Path $jsonPath -Parent) | Out-Null

@{
	scrapedAt = (Get-Date).ToUniversalTime().ToString("o")
	source    = $Source
	count     = $pages.Count
	pages     = $pages
} | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding utf8

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
[void]$sb.AppendLine('<rss version="2.0"')
[void]$sb.AppendLine('  xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"')
[void]$sb.AppendLine('  xmlns:content="http://purl.org/rss/1.0/modules/content/"')
[void]$sb.AppendLine('  xmlns:wfw="http://wellformedweb.org/CommentAPI/"')
[void]$sb.AppendLine('  xmlns:dc="http://purl.org/dc/elements/1.1/"')
[void]$sb.AppendLine('  xmlns:wp="http://wordpress.org/export/1.2/">')
[void]$sb.AppendLine('<channel>')
[void]$sb.AppendLine('  <title>Saputo Toufexis marketing pages</title>')
[void]$sb.AppendLine("  <link>$Source</link>")
[void]$sb.AppendLine('  <description>Selected live marketing pages for staging import. Statute library and county doorway pages are excluded.</description>')
[void]$sb.AppendLine('  <pubDate>' + [DateTime]::UtcNow.ToString("r") + '</pubDate>')
[void]$sb.AppendLine('  <language>en-US</language>')
[void]$sb.AppendLine('  <wp:wxr_version>1.2</wp:wxr_version>')
[void]$sb.AppendLine('  <wp:base_site_url>' + $Source + '/</wp:base_site_url>')
[void]$sb.AppendLine('  <wp:base_blog_url>' + $Source + '</wp:base_blog_url>')

foreach ($page in $pages) {
	$title = [System.Security.SecurityElement]::Escape($page.title)
	[void]$sb.AppendLine('  <item>')
	[void]$sb.AppendLine("    <title>$title</title>")
	[void]$sb.AppendLine("    <link>$($page.link)</link>")
	[void]$sb.AppendLine('    <pubDate>' + ([datetime]$page.date).ToUniversalTime().ToString("r") + '</pubDate>')
	[void]$sb.AppendLine('    <dc:creator><![CDATA[saputo]]></dc:creator>')
	[void]$sb.AppendLine('    <guid isPermaLink="false">' + $page.link + '</guid>')
	[void]$sb.AppendLine('    <description></description>')
	[void]$sb.AppendLine('    <content:encoded><![CDATA[' + (Protect-Cdata $page.content) + ']]></content:encoded>')
	[void]$sb.AppendLine('    <excerpt:encoded><![CDATA[' + (Protect-Cdata $page.excerpt) + ']]></excerpt:encoded>')
	[void]$sb.AppendLine("    <wp:post_id>$($page.id)</wp:post_id>")
	[void]$sb.AppendLine('    <wp:post_date>' + ([datetime]$page.date).ToString("yyyy-MM-dd HH:mm:ss") + '</wp:post_date>')
	[void]$sb.AppendLine('    <wp:post_date_gmt>' + ([datetime]$page.date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") + '</wp:post_date_gmt>')
	[void]$sb.AppendLine("    <wp:post_modified>$($page.modified)</wp:post_modified>")
	[void]$sb.AppendLine('    <wp:comment_status>closed</wp:comment_status>')
	[void]$sb.AppendLine('    <wp:ping_status>closed</wp:ping_status>')
	[void]$sb.AppendLine("    <wp:post_name>$($page.slug)</wp:post_name>")
	[void]$sb.AppendLine('    <wp:status>publish</wp:status>')
	[void]$sb.AppendLine('    <wp:post_parent>0</wp:post_parent>')
	[void]$sb.AppendLine('    <wp:menu_order>0</wp:menu_order>')
	[void]$sb.AppendLine('    <wp:post_type>page</wp:post_type>')
	[void]$sb.AppendLine('    <wp:post_password></wp:post_password>')
	[void]$sb.AppendLine('    <wp:is_sticky>0</wp:is_sticky>')
	[void]$sb.AppendLine('  </item>')
}

[void]$sb.AppendLine('</channel>')
[void]$sb.AppendLine('</rss>')
[System.IO.File]::WriteAllText($xmlPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Output ("Wrote {0} pages to {1} and {2}" -f $pages.Count, $JsonOutput, $XmlOutput)
