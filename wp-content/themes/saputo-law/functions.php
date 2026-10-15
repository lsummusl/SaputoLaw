<?php
/**
 * Saputo Law theme setup.
 *
 * @package SaputoLaw
 */

declare(strict_types=1);

add_action(
	'wp_enqueue_scripts',
	static function (): void {
		wp_enqueue_style(
			'saputo-law',
			get_stylesheet_uri(),
			array(),
			wp_get_theme()->get('Version')
		);
	}
);

add_action(
	'after_setup_theme',
	static function (): void {
		add_theme_support('editor-styles');
		add_editor_style('style.css');
		add_theme_support('responsive-embeds');
		add_theme_support('wp-block-styles');
	}
);
