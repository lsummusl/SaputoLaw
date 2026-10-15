<?php
/**
 * One-time starter content for a fresh proof-of-concept installation.
 *
 * Existing pages are never overwritten. Increment the seed version only when
 * new, non-destructive setup work is required.
 *
 * @package SaputoLaw
 */

declare(strict_types=1);

const SAPUTO_LAW_SEED_VERSION = '0.1.0';

/**
 * Create one page when its slug does not already exist.
 */
function saputo_law_seed_page(
	string $slug,
	string $title,
	string $content = '',
	string $status = 'publish',
	int $parent = 0
): int {
	$existing = get_page_by_path($slug, OBJECT, 'page');

	if ($existing instanceof WP_Post) {
		return (int) $existing->ID;
	}

	$page_id = wp_insert_post(
		array(
			'post_type'    => 'page',
			'post_status'  => $status,
			'post_title'   => $title,
			'post_name'    => $slug,
			'post_content' => wp_slash($content),
			'post_parent'  => $parent,
		),
		true
	);

	return is_wp_error($page_id) ? 0 : (int) $page_id;
}

/**
 * Seed the core site structure after first activation.
 */
function saputo_law_seed_site(): void {
	if (get_option('saputo_law_seed_version') === SAPUTO_LAW_SEED_VERSION) {
		return;
	}

	$home_id = saputo_law_seed_page('home', 'Home');

	$attorneys_content = <<<'BLOCKS'
<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"signal"} -->
<p class="sl-eyebrow has-signal-color has-text-color">The trial team</p>
<!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} -->
<h2 class="wp-block-heading has-x-large-font-size">Defense counsel built for difficult cases.</h2>
<!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"large"} -->
<p class="has-large-font-size">Paul Saputo and Nicholas Toufexis have devoted their legal careers to defending people against government prosecution. Their work combines careful investigation, direct client communication, and trial preparation from the beginning.</p>
<!-- /wp:paragraph -->
<!-- wp:columns {"style":{"spacing":{"margin":{"top":"var:preset|spacing|60"}}}} -->
<div class="wp-block-columns" style="margin-top:var(--wp--preset--spacing--60)">
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|60","right":"var:preset|spacing|50","bottom":"var:preset|spacing|60","left":"var:preset|spacing|50"}}}} -->
	<div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--60);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--60);padding-left:var(--wp--preset--spacing--50)">
		<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"steel"} --><p class="sl-eyebrow has-steel-color has-text-color">Founding Partner</p><!-- /wp:paragraph -->
		<!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Paul Saputo</h3><!-- /wp:heading -->
		<!-- wp:paragraph --><p>Duke Law graduate and Texas criminal-defense attorney admitted in state courts, the Fifth Circuit, and multiple United States District Courts.</p><!-- /wp:paragraph -->
		<!-- wp:paragraph --><p><a href="/attorneys/paul-saputo/">Meet Paul →</a></p><!-- /wp:paragraph -->
	</div>
	<!-- /wp:column -->
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|60","right":"var:preset|spacing|50","bottom":"var:preset|spacing|60","left":"var:preset|spacing|50"}}}} -->
	<div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--60);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--60);padding-left:var(--wp--preset--spacing--50)">
		<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"steel"} --><p class="sl-eyebrow has-steel-color has-text-color">Managing Partner</p><!-- /wp:paragraph -->
		<!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Nicholas Toufexis</h3><!-- /wp:heading -->
		<!-- wp:paragraph --><p>SMU Dedman School of Law graduate, Navy veteran, and criminal-defense attorney admitted in Texas state and federal courts.</p><!-- /wp:paragraph -->
		<!-- wp:paragraph --><p><a href="/attorneys/nicholas-toufexis/">Meet Nick →</a></p><!-- /wp:paragraph -->
	</div>
	<!-- /wp:column -->
</div>
<!-- /wp:columns -->
BLOCKS;

	$attorneys_id = saputo_law_seed_page('attorneys', 'Attorneys', $attorneys_content);

	$paul_content = <<<'BLOCKS'
<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"signal"} --><p class="sl-eyebrow has-signal-color has-text-color">Founding Partner</p><!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">Paul Saputo</h2><!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Paul Saputo founded the firm around one purpose: defending people against the power of the government. He represents clients in serious state and federal criminal matters throughout Texas.</p><!-- /wp:paragraph -->
<!-- wp:separator {"className":"sl-tailored-rule"} --><hr class="wp-block-separator has-alpha-channel-opacity sl-tailored-rule"/><!-- /wp:separator -->
<!-- wp:columns -->
<div class="wp-block-columns">
	<!-- wp:column --><div class="wp-block-column"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Education &amp; admissions</h3><!-- /wp:heading --><!-- wp:list --><ul><li>Juris Doctor, Duke University School of Law</li><li>State Bar of Texas, 2012</li><li>United States Fifth Circuit Court of Appeals</li><li>Multiple United States District Courts</li></ul><!-- /wp:list --></div><!-- /wp:column -->
	<!-- wp:column --><div class="wp-block-column"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Selected recognition</h3><!-- /wp:heading --><!-- wp:list --><ul><li>Martindale-Hubbell AV Preeminent</li><li>D Magazine Best Lawyers in Dallas</li><li>Super Lawyers recognition</li><li>Martindale-Hubbell Silver Client Champion</li></ul><!-- /wp:list --></div><!-- /wp:column -->
</div>
<!-- /wp:columns -->
<!-- wp:paragraph --><p>Paul’s approach is direct: investigate the facts, challenge the government’s assumptions, and prepare every case with trial in mind.</p><!-- /wp:paragraph -->
BLOCKS;
	saputo_law_seed_page('paul-saputo', 'Paul Saputo', $paul_content, 'publish', $attorneys_id);

	$nick_content = <<<'BLOCKS'
<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"signal"} --><p class="sl-eyebrow has-signal-color has-text-color">Managing Partner</p><!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">Nicholas Toufexis</h2><!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Nicholas Toufexis brings a decade of service in the United States Navy and a disciplined, trial-focused approach to criminal defense in Texas state and federal courts.</p><!-- /wp:paragraph -->
<!-- wp:separator {"className":"sl-tailored-rule"} --><hr class="wp-block-separator has-alpha-channel-opacity sl-tailored-rule"/><!-- /wp:separator -->
<!-- wp:columns -->
<div class="wp-block-columns">
	<!-- wp:column --><div class="wp-block-column"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Education &amp; admissions</h3><!-- /wp:heading --><!-- wp:list --><ul><li>Juris Doctor, SMU Dedman School of Law</li><li>State Bar of Texas</li><li>United States Fifth Circuit Court of Appeals</li><li>Northern and Eastern Districts of Texas</li></ul><!-- /wp:list --></div><!-- /wp:column -->
	<!-- wp:column --><div class="wp-block-column"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Selected recognition</h3><!-- /wp:heading --><!-- wp:list --><ul><li>Best Lawyers: Ones to Watch</li><li>Super Lawyers Rising Star</li><li>Lead Counsel Verified</li><li>Dallas Association of Young Lawyers One to Watch</li></ul><!-- /wp:list --></div><!-- /wp:column -->
</div>
<!-- /wp:columns -->
<!-- wp:paragraph --><p>Nick prepares each matter around the client’s specific risks, the available evidence, and the decisions that will create leverage before trial.</p><!-- /wp:paragraph -->
BLOCKS;
	saputo_law_seed_page('nicholas-toufexis', 'Nicholas Toufexis', $nick_content, 'publish', $attorneys_id);

	$practice_content = <<<'BLOCKS'
<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"signal"} --><p class="sl-eyebrow has-signal-color has-text-color">Focused criminal defense</p><!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">The right strategy depends on where the case stands.</h2><!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">We represent clients before arrest, after charges are filed, at trial, and in post-trial proceedings. Early involvement can preserve evidence and create options that disappear later.</p><!-- /wp:paragraph -->
<!-- wp:columns {"style":{"spacing":{"margin":{"top":"var:preset|spacing|60"}}}} -->
<div class="wp-block-columns" style="margin-top:var(--wp--preset--spacing--60)">
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"}}}} --><div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Investigations</h3><!-- /wp:heading --><!-- wp:paragraph --><p>Pre-arrest counsel, interviews, search warrants, grand juries, and internal investigations.</p><!-- /wp:paragraph --></div><!-- /wp:column -->
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"}}}} --><div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">State charges</h3><!-- /wp:heading --><!-- wp:paragraph --><p>DWI, assault, drug allegations, sexual offenses, fraud, and other serious felonies.</p><!-- /wp:paragraph --></div><!-- /wp:column -->
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"}}}} --><div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Federal defense</h3><!-- /wp:heading --><!-- wp:paragraph --><p>Conspiracy, white-collar investigations, controlled substances, and complex federal prosecutions.</p><!-- /wp:paragraph --></div><!-- /wp:column -->
</div>
<!-- /wp:columns -->
<!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Trial and post-trial work</h3><!-- /wp:heading -->
<!-- wp:paragraph --><p>Trial preparation begins at intake. The firm also handles selected appeals, record-clearing matters, deregistration, and other post-trial proceedings.</p><!-- /wp:paragraph -->
BLOCKS;
	saputo_law_seed_page('practice-areas', 'Practice Areas', $practice_content);

	$results_content = <<<'BLOCKS'
<!-- wp:paragraph {"backgroundColor":"ice","fontSize":"small","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"}}}} -->
<p class="has-ice-background-color has-background has-small-font-size" style="padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><strong>Prior results do not guarantee a similar outcome.</strong> Every case is different, and the result depends on its particular facts and law.</p>
<!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">Selected case results</h2><!-- /wp:heading -->
<!-- wp:group {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"},"margin":{"bottom":"var:preset|spacing|40"}}}} --><div class="wp-block-group sl-card" style="margin-bottom:var(--wp--preset--spacing--40);padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:paragraph {"className":"sl-eyebrow","textColor":"steel"} --><p class="sl-eyebrow has-steel-color has-text-color">Dallas County · 2024</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Motion to suppress granted in DWI second-offense case</h3><!-- /wp:heading --><!-- wp:paragraph --><p>The court found the officers lacked sufficient articulable facts to justify the detention.</p><!-- /wp:paragraph --></div><!-- /wp:group -->
<!-- wp:group {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"},"margin":{"bottom":"var:preset|spacing|40"}}}} --><div class="wp-block-group sl-card" style="margin-bottom:var(--wp--preset--spacing--40);padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:paragraph {"className":"sl-eyebrow","textColor":"steel"} --><p class="sl-eyebrow has-steel-color has-text-color">Collin County · 2021</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Not guilty jury verdict</h3><!-- /wp:heading --><!-- wp:paragraph --><p>The jury returned a not guilty verdict after deliberating for less than five minutes.</p><!-- /wp:paragraph --></div><!-- /wp:group -->
<!-- wp:group {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|50","right":"var:preset|spacing|50","bottom":"var:preset|spacing|50","left":"var:preset|spacing|50"},"margin":{"bottom":"var:preset|spacing|40"}}}} --><div class="wp-block-group sl-card" style="margin-bottom:var(--wp--preset--spacing--40);padding-top:var(--wp--preset--spacing--50);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--50);padding-left:var(--wp--preset--spacing--50)"><!-- wp:paragraph {"className":"sl-eyebrow","textColor":"steel"} --><p class="sl-eyebrow has-steel-color has-text-color">Federal court · El Paso</p><!-- /wp:paragraph --><!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Federal charges dismissed</h3><!-- /wp:heading --><!-- wp:paragraph --><p>After the defense challenged discrepancies between the authorized search and the search performed, the United States Attorney’s Office dismissed the case.</p><!-- /wp:paragraph --></div><!-- /wp:group -->
<!-- wp:paragraph {"fontSize":"small"} --><p class="has-small-font-size"><strong>Prior results do not guarantee a similar outcome.</strong> Every case is different.</p><!-- /wp:paragraph -->
BLOCKS;
	saputo_law_seed_page('results', 'Results', $results_content);

	saputo_law_seed_page('insights-recognition', 'Insights & Recognition');

	$contact_content = <<<'BLOCKS'
<!-- wp:columns {"style":{"spacing":{"blockGap":{"left":"var:preset|spacing|70"}}}} -->
<div class="wp-block-columns">
	<!-- wp:column {"width":"58%"} -->
	<div class="wp-block-column" style="flex-basis:58%">
		<!-- wp:paragraph {"className":"sl-eyebrow","textColor":"signal"} --><p class="sl-eyebrow has-signal-color has-text-color">Confidential consultation</p><!-- /wp:paragraph -->
		<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">Tell us what happened.</h2><!-- /wp:heading -->
		<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">A short conversation can help identify the immediate risks, deadlines, and next steps. Call the firm or use the consultation form configured for this site.</p><!-- /wp:paragraph -->
		<!-- wp:buttons --><div class="wp-block-buttons"><!-- wp:button --><div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="tel:+18882399305">Call (888) 239-9305</a></div><!-- /wp:button --></div><!-- /wp:buttons -->
		<!-- wp:paragraph {"backgroundColor":"ice","fontSize":"small","style":{"spacing":{"margin":{"top":"var:preset|spacing|50"},"padding":{"top":"var:preset|spacing|40","right":"var:preset|spacing|40","bottom":"var:preset|spacing|40","left":"var:preset|spacing|40"}}}} --><p class="has-ice-background-color has-background has-small-font-size" style="margin-top:var(--wp--preset--spacing--50);padding-top:var(--wp--preset--spacing--40);padding-right:var(--wp--preset--spacing--40);padding-bottom:var(--wp--preset--spacing--40);padding-left:var(--wp--preset--spacing--40)">Do not send confidential or time-sensitive information until the firm confirms representation. Contacting the firm does not create an attorney-client relationship.</p><!-- /wp:paragraph -->
	</div>
	<!-- /wp:column -->
	<!-- wp:column {"className":"sl-card","style":{"spacing":{"padding":{"top":"var:preset|spacing|60","right":"var:preset|spacing|50","bottom":"var:preset|spacing|60","left":"var:preset|spacing|50"}}}} -->
	<div class="wp-block-column sl-card" style="padding-top:var(--wp--preset--spacing--60);padding-right:var(--wp--preset--spacing--50);padding-bottom:var(--wp--preset--spacing--60);padding-left:var(--wp--preset--spacing--50)">
		<!-- wp:heading {"level":3} --><h3 class="wp-block-heading">Dallas office</h3><!-- /wp:heading -->
		<!-- wp:paragraph --><p>1845 Woodall Rodgers Freeway<br>Suite 1500<br>Dallas, Texas 75201</p><!-- /wp:paragraph -->
		<!-- wp:paragraph --><p><strong>Phone</strong><br><a href="tel:+18882399305">(888) 239-9305</a></p><!-- /wp:paragraph -->
		<!-- wp:paragraph --><p><strong>Fax</strong><br>(888) 236-2516</p><!-- /wp:paragraph -->
	</div>
	<!-- /wp:column -->
</div>
<!-- /wp:columns -->
BLOCKS;
	saputo_law_seed_page('contact-us', 'Contact Us', $contact_content);

	$articles_id = saputo_law_seed_page('articles', 'Articles');

	$spanish_content = <<<'BLOCKS'
<!-- wp:paragraph {"backgroundColor":"ice"} --><p class="has-ice-background-color has-background"><strong>Draft:</strong> This page requires review by a fluent Spanish-speaking legal professional before publication.</p><!-- /wp:paragraph -->
<!-- wp:heading {"fontSize":"x-large"} --><h2 class="wp-block-heading has-x-large-font-size">Defensa penal en Dallas y en todo Texas.</h2><!-- /wp:heading -->
<!-- wp:paragraph {"fontSize":"large"} --><p class="has-large-font-size">Saputo Toufexis representa a personas que enfrentan investigaciones y acusaciones penales graves en tribunales estatales y federales.</p><!-- /wp:paragraph -->
<!-- wp:paragraph --><p>Para hablar con nuestro equipo, llame al <a href="tel:+18882399305">(888) 239-9305</a>.</p><!-- /wp:paragraph -->
BLOCKS;
	saputo_law_seed_page('es', 'Defensa Penal en Texas', $spanish_content, 'draft');

	if ($home_id > 0) {
		update_option('show_on_front', 'page');
		update_option('page_on_front', $home_id);
	}

	if ($articles_id > 0) {
		update_option('page_for_posts', $articles_id);
	}

	update_option('blogname', 'Saputo Toufexis');
	update_option('blogdescription', 'Texas Criminal Defense');
	update_option('saputo_law_seed_version', SAPUTO_LAW_SEED_VERSION);
	set_transient('saputo_law_seeded_notice', true, 60);
}

/**
 * Confirm successful setup to an administrator.
 */
function saputo_law_seeded_notice(): void {
	if (! current_user_can('manage_options') || ! get_transient('saputo_law_seeded_notice')) {
		return;
	}

	delete_transient('saputo_law_seeded_notice');
	echo '<div class="notice notice-success is-dismissible"><p>';
	echo esc_html__('Saputo Law created the starter pages and configured the homepage. Existing pages were left unchanged.', 'saputo-law');
	echo '</p></div>';
}
add_action('admin_notices', 'saputo_law_seeded_notice');
