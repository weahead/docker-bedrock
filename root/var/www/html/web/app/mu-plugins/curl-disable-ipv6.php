<?php
defined( 'ABSPATH' ) OR die( 'Do not run outside of WordPress!' );
add_action( 'http_api_curl', function ( $handle ) {
  curl_setopt( $handle, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4 );
  return $handle;
});
