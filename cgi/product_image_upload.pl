#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

my $type = param('type') || 'add';
my $action = param('action') || 'display';
my $code = param('code');
my $imagefield = param('imagefield');
my $delete = param('delete');

print STDERR "product_image_upload.pl - ip: " . remote_addr() . " - type: $type - action: $action - code: $code\n";

my $env = $ENV{QUERY_STRING};

print STDERR "product_image_upload.pl - query string : $env - calling init()\n";


Blogs::Display::init();

$debug = 1;

print STDERR "product_image_upload.pl - user: $User_id - code: $code - cc: $cc - lc: $lc - ip: " . remote_addr() . "\n";

if (not defined $code) {
	
	print STDERR "product_image_upload.pl - no code\n";
	exit(0);
}

my $interface_version = '20120622';

# Create image directory if needed
if (! -e "$www_root/images") {
	mkdir ("$www_root/images", 0755);
}
if (! -e "$www_root/images/products") {
	mkdir ("$www_root/images/products", 0755);
}

if ($imagefield) {

	my $path = product_path($code);
	
	print STDERR "product_image_upload - imagefield: $imagefield - delete: $delete\n";
	
	if ($delete ne 'on') {
	
		my $product_ref = product_exists($code); # returns 0 if not
		
		if (not $product_ref) {
			print STDERR "product_image_upload.pl - product code $code does not exist yet, creating product\n";
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = $interface_version;
			$product_ref->{lc} = $lc;
			store_product($product_ref, "Création du produit (envoi d'une image)");
		}
		else {
			print STDERR "product_image_upload.pl - product code $code already exists\n";
		}
	
		my $imgid = process_image_upload($code, $imagefield);
		
		my $data;

		if ($imgid < 0) {
			my %response = ( status => 'status not ok', imgid => $imgid);
			$response{error} = "error";
			($imgid == -3) and $response{error} = lang("image_upload_error_image_already_exists");
			($imgid == -4) and $response{error} = lang("image_upload_error_image_too_small");
			$data =  encode_json(\%response);	
		}
		else {
			$data =  encode_json({ status => 'status ok',
					image => {
							imgid=>$imgid,
							thumb_url=>"$imgid.${thumb_size}.jpg",
							crop_url=>"$imgid.${crop_size}.jpg",
					},
					imagefield=>$imagefield,
			});
			
			# If we don't have a picture yet, assume it is the front view of the product
			# (can be changed by the user later if necessary)
			if (not defined $product_ref->{images}{front}) {
				process_image_crop($code, 'front', $imgid, 0, undef, undef, -1, -1, -1, -1);
			}
		}
		
		print STDERR "product_image_upload - JSON data output: $data\n";

		print header ( -charset=>'UTF-8') . $data;

	}
	else {

			print STDERR "product_image_upload - no imagefield\n";
			my %response = ( status => 'status not ok');
			$response{error} = "error - imagefield not defined";
			my $data =  encode_json(\%response);		
			print header ( -charset=>'UTF-8') . $data;			

	}

}
else {
	print STDERR "product_image - no imgid defined\n";
}


exit(0);

