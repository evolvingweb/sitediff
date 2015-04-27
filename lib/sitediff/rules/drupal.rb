class SiteDiff
class Rules
class Drupal < Rules
  def sanitization_candidates
    [
      {
        'title' => 'Strip Drupal.settings',
        'selector' => 'script',
        'pattern' => '^jQuery.extend\(Drupal.settings.*$',
      },
      {
        'title' => 'Strip form build ID',
        'selector' => 'input',
        'pattern' => 'name="form_build_id" value="form-[-\w]{43}"',
        'substitution' => 'name="form_build_id" value="form-DRUPAL_FORM_BUILD_ID"',
      },
      {
        'title' => 'Strip CSS aggregation filenames',
        'selector' => 'link[rel=stylesheet]',
        'pattern' => '(href="[^"]*/files/css/css_)[-\w]{43}\.css"',
        'substitution' => '\1DRUPAL_AGGREGATED_CSS.css"',
      },
      {
        'title' => 'Strip JS aggregation filenames',
        'selector' => 'script',
        'pattern' => '(src="[^"]*/files/js/js_)[-\w]{43}\.js"',
        'substitution' => '\1DRUPAL_AGGREGATED_JS.js"',
      },
      {
        # Some are hidden inside IE version comments
        'title' => 'Strip CSS/JS cache IDs',
        'pattern' => '("[^"]*\.(js|css))\?[a-z0-9]{6}"',
        'substitution' => '\1',
      },
      {
        'title' => 'Strip Drupal JS version tags',
        'selector' => 'script',
        'pattern' => '(src="[^"]*/misc/\w+\.js)?v=\d+\.\d+"',
        'substitution' => '\1',
      },
    ]
  end
end
end
end
