<?php
/**
 * Saputo Law theme setup.
 *
 * @package SaputoLaw
 */

declare(strict_types=1);

/**
 * Live-site titles sometimes include a CMS marker such as "(redirected)".
 */
function saputo_law_strip_redirect_label(string $text): string {
	$clean = preg_replace('/\(\s*redirect(?:ed)?\s*\)\s*/i', '', $text);
	if (! is_string($clean)) {
		return trim($text);
	}

	$clean = preg_replace('/\s{2,}/', ' ', $clean);

	return trim(is_string($clean) ? $clean : $text);
}

require_once get_theme_file_path('inc/seed-content.php');
require_once get_theme_file_path('inc/library-links.php');

add_filter(
	'the_title',
	static function ($title) {
		return is_string($title) ? saputo_law_strip_redirect_label($title) : $title;
	},
	20
);

add_filter(
	'document_title_parts',
	static function ($parts) {
		if (is_array($parts) && isset($parts['title']) && is_string($parts['title'])) {
			$parts['title'] = saputo_law_strip_redirect_label($parts['title']);
		}

		return $parts;
	},
	20
);

add_filter(
	'wpseo_title',
	static function ($title) {
		return is_string($title) ? saputo_law_strip_redirect_label($title) : $title;
	},
	20
);

add_filter(
	'wpseo_opengraph_title',
	static function ($title) {
		return is_string($title) ? saputo_law_strip_redirect_label($title) : $title;
	},
	20
);

add_filter(
	'single_post_title',
	static function ($title) {
		return is_string($title) ? saputo_law_strip_redirect_label($title) : $title;
	},
	20
);

add_action(
	'wp_enqueue_scripts',
	static function (): void {
		wp_enqueue_style(
			'saputo-law',
			get_stylesheet_uri(),
			array(),
			wp_get_theme()->get('Version')
		);
		wp_enqueue_style(
			'saputo-law-layout',
			get_theme_file_uri('assets/css/layout.css'),
			array('saputo-law'),
			(string) filemtime(get_theme_file_path('assets/css/layout.css'))
		);

		wp_dequeue_style('wp-block-library-theme');
		wp_deregister_style('wp-block-library-theme');
	},
	20
);

add_action('after_switch_theme', 'saputo_law_seed_site');
add_action('admin_init', 'saputo_law_seed_site');

add_action(
	'after_setup_theme',
	static function (): void {
		add_theme_support('editor-styles');
		add_editor_style('style.css');
		add_theme_support('responsive-embeds');
	}
);
