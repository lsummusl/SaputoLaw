<?php
/**
 * Saputo Law theme setup.
 *
 * @package SaputoLaw
 */

declare(strict_types=1);

require_once get_theme_file_path('inc/seed-content.php');

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
