<?php
/**
 * Render scraped library links without copying the live page bodies.
 *
 * @package SaputoLaw
 */

declare(strict_types=1);

/**
 * Catalog produced by tools/scrape-live-metadata.ps1.
 *
 * @return array<string, mixed>
 */
function saputo_law_library_catalog(): array {
	static $catalog = null;

	if (is_array($catalog)) {
		return $catalog;
	}

	$path = get_theme_file_path('data/library-links.json');
	if (!is_string($path) || !is_readable($path)) {
		$catalog = array();
		return $catalog;
	}

	$decoded = json_decode((string) file_get_contents($path), true);
	$catalog = is_array($decoded) ? $decoded : array();

	return $catalog;
}

/**
 * Keep library URLs on saputo.law until this theme is running there.
 */
function saputo_law_library_href(string $path): string {
	$host = wp_parse_url(home_url(), PHP_URL_HOST);

	if (is_string($host) && preg_match('/(^|\.)saputo\.law$/', $host) === 1) {
		return $path;
	}

	return 'https://saputo.law' . $path;
}

/**
 * @param array<string, mixed> $attributes
 */
function saputo_law_render_library_links(array $attributes): string {
	$section_id = isset($attributes['section']) ? (string) $attributes['section'] : '';
	$catalog    = saputo_law_library_catalog();
	$sections   = isset($catalog['sections']) && is_array($catalog['sections']) ? $catalog['sections'] : array();
	$section    = null;

	foreach ($sections as $candidate) {
		if (is_array($candidate) && ($candidate['id'] ?? '') === $section_id) {
			$section = $candidate;
			break;
		}
	}

	if (!is_array($section) || empty($section['links']) || !is_array($section['links'])) {
		return '';
	}

	ob_start();
	?>
	<div class="sl-library">
		<?php if (!empty($section['heading'])) : ?>
			<h2 class="wp-block-heading"><?php echo esc_html((string) $section['heading']); ?></h2>
		<?php endif; ?>
		<?php if (!empty($section['intro'])) : ?>
			<p><?php echo esc_html((string) $section['intro']); ?></p>
		<?php endif; ?>
		<ul class="sl-library-list">
			<?php foreach ($section['links'] as $link) : ?>
				<?php
				if (!is_array($link) || empty($link['path']) || empty($link['title'])) {
					continue;
				}
				?>
				<li class="sl-library-item">
					<a href="<?php echo esc_url(saputo_law_library_href((string) $link['path'])); ?>"><?php echo esc_html(saputo_law_strip_redirect_label((string) $link['title'])); ?></a>
					<?php if (!empty($link['description'])) : ?>
						<p><?php echo esc_html((string) $link['description']); ?></p>
					<?php endif; ?>
				</li>
			<?php endforeach; ?>
		</ul>
	</div>
	<?php

	return (string) ob_get_clean();
}

add_action(
	'init',
	static function (): void {
		register_block_type(
			'saputo/library-links',
			array(
				'api_version'     => 3,
				'attributes'      => array(
					'section' => array(
						'type'    => 'string',
						'default' => 'practice',
					),
				),
				'render_callback' => 'saputo_law_render_library_links',
			)
		);
	}
);
