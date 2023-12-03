#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Copy 'cp';

use FindBin;
use lib $FindBin::Bin;

use AndroidHelpImages;

# Set up to use es/scripts
BEGIN {
    use File::Basename;
    my ($name, $path) = fileparse $0;
    $path =~ s%/$%%o;
    unshift @INC, "$path/../../../../scripts";
}
use esgit;

sub doCmd {
    my $cmd = shift;
    warn "$cmd\n";
    (system $cmd) == 0
      or die "Trouble with command (see above)\n";
}

sub fileFromName {
    my $name = shift;
    my $filename = lc $name;
    if ($filename !~ / i+$/) {
        $filename .= "_i";
    }
    $filename =~ s/ /_/go;
    $filename =~ s/\&#257/a/go;
    return $filename;
}

sub dirFromFilename {
    my $filename = shift;
    my $name = $filename;
    $name =~ s/_i+$//o
      or die "Filename not in expected format: '$filename'\n";
    $name =~ s/selene/chandra/;
    $name =~ s/padua/firenze/;
    $name =~ s/basel/geneva/;
    $name =~ s/hana/haleakala/;
    $name =~ s/mauna_loa/mauna_kea/;
    $name =~ s/venezia/miami/;
    $name =~ s/gaia/terra/;
    return $name;
}

sub cssClassFromName {
    my $name = shift;
    my $cls = lc $name;
    $cls =~ s/\&#257/a/go;
    $cls =~ s/ /-/go;
    return $cls;
}

sub skuFromName {
    my $name = shift;
    my $sku = lc $name;
    $sku =~ s/\&#257/a/go;
    $sku =~ s/ /_/go;
    $sku =~ s/_ii?$//go;
    return "chronometer.$sku";
}

my $boilerplateHeader = <<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en">
<head>

 <title>Emerald Miami II</title>
 <meta name="viewport" content="width=device-width" />
 <link rel="apple-touch-icon" href="../../images/eblogo57-1.png">
 <link rel="shortcut icon" href="../../images/GlyphBerry.png" type="image/png">
 <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
 <link rel="stylesheet" href="../product.css"/>
 <style>
img.miami-ii-help-footer {
  border: 2px solid #a0ffa0;
  border-radius: 7px;
  padding: 2px;
}
 </style>
</head>

<body>
<div class='floatL'>
  <a href="../../index.php">Emerald Sequoia LLC</a><br>
  <a href="../index.html">Emerald Chronometer for Wear OS</a>
</div>
<div class='floatR'>
 <a href="../buy.html">How to Buy</a>
</div>
<br>
<br>
<hr size=1>

<h1>Emerald Miami xx<br>
  <span class='wearosSubhead'>for<br>Wear OS by Google</span></h1>
<center>
<div width='1000' max-width='1000' margin='auto'>
<img border='0' width='100%' src="miami_ii-banner.png">
</div>
<table>
  <tr>
    <td align="right"><b>Buy this face</b></td>
    <td>
<a href="https://play.google.com/store/apps/details?id=com.emeraldsequoia.chronometer.miami&utm_source=FacePage&pcampaignid=MKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1" style="text-decoration: none">
<img width="200" alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/images/generic/en_badge_web_generic.png'/>
</a>
    </td>
  </tr>
  <tr>
    <td align-"right"><b>Buy all 21 faces</b></td>
    <td>
<a href="https://play.google.com/store/apps/details?id=com.emeraldsequoia.chronometer.chronometer_pro&utm_source=FacePage&pcampaignid=MKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1" style="text-decoration: none">
<img width="200" alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/images/generic/en_badge_web_generic.png'/>
</a>
    </td>
  </tr>
</table>
</center>
<p>
EOF
  ;
my $templateName = "Miami II";
my $simplifiedTemplateName = "Miami xx";
my $templateFile = fileFromName $templateName;
my $templateCssClass = cssClassFromName $templateName;
my $templateSku = skuFromName $templateName;
warn "Template name:      $templateName\n";
warn "Template file:      $templateFile\n";
warn "Template CSS class: $templateCssClass\n";
warn "Template sku:       $templateSku\n";

my $boilerplateFooter = <<EOF
<div display='inline' class='website'>
<hr size=1>
<h3><a href="../index.html">Emerald&nbsp;Chronometer</a> Faces for Wear&nbsp;OS&nbsp;by&nbsp;Google</h3>
<a href="../mauna_kea/mauna_kea_i.html"><img class="mauna-kea-i-help-footer" alt="Mauna Kea" src="../mauna_kea/mauna_kea_i-icon.png"  width=50 align=center vspace=4></a>
<a href="../mauna_kea/mauna_loa_i.html"><img class="mauna-loa-i-help-footer" alt="Mauna Loa" src="../mauna_kea/mauna_loa_i-icon.png"  width=50 align=center vspace=4></a>
<a href="../terra/terra_i.html"><img class="terra-i-help-footer" alt="Terra" src="../terra/terra_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../terra/gaia_i.html"><img class="gaia-i-help-footer" alt="Gaia" src="../terra/gaia_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../miami/venezia_i.html"><img class="venezia-i-help-footer" alt="Venezia" src="../miami/venezia_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../haleakala/haleakala_i.html"><img class="haleakala-i-help-footer" alt="Haleakala" src="../haleakala/haleakala_i-icon.png"  width=50 align=center vspace=4></a>
<a href="../haleakala/hana_i.html"><img class="hana-i-help-footer" alt="Hana" src="../haleakala/hana_i-icon.png"  width=50 align=center vspace=4></a>
<a href="../geneva/geneva_i.html"><img class="geneva-i-help-footer" alt="Geneva" src="../geneva/geneva_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../chandra/selene_i.html"><img class="selene-i-help-footer" alt="Selene" src="../chandra/selene_i-icon.png"    width=50 align=center vspace=4></a>
<a href="../chandra/chandra_i.html"><img class="chandra-i-help-footer" alt="Chandra" src="../chandra/chandra_i-icon.png"    width=50 align=center vspace=4></a>
<a href="../paris/paris_i.html"><img class="paris-i-help-footer" alt="Paris" src="../paris/paris_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../mcalester/mcalester_i.html"><img class="mcalester-i-help-footer" alt="Mcalester" src="../mcalester/mcalester_i-icon.png"  width=50 align=center vspace=4></a>
<a href="../firenze/firenze_i.html"><img class="firenze-i-help-footer" alt="Firenze" src="../firenze/firenze_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../firenze/padua_i.html"><img class="padua-i-help-footer" alt="Padua" src="../firenze/padua_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../babylon/babylon_i.html"><img class="babylon-i-help-footer" alt="Babylon" src="../babylon/babylon_i-icon.png"    width=50 align=center vspace=4></a>
<a href="../geneva/basel_i.html"><img class="basel-i-help-footer" alt="Basel" src="../geneva/basel_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../alexandria/alexandria_i.html"><img class="alexandria-i-help-footer" alt="Alexandria" src="../alexandria/alexandria_i-icon.png" width=50  align=center vspace=4></a>
<a href="../atlantis/atlantis_i.html"><img class="atlantis-i-help-footer" alt="Atlantis" src="../atlantis/atlantis_i-icon.png"   width=50 align=center vspace=4></a>
<a href="../milano/milano_i.html"><img class="milano-i-help-footer" alt="Milano" src="../milano/milano_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../miami/miami_i.html"><img class="miami-i-help-footer" alt="Miami" src="../miami/miami_i-icon.png"      width=50 align=center vspace=4></a>
<a href="../vienna/vienna_i.html"><img class="vienna-i-help-footer" alt="Vienna" src="../vienna/vienna_i-icon.png"  width=50 align=center vspace=4></a>
<hr size=4>
Copyright&nbsp;&copy;&nbsp;2018, <a href="../../index.html"><span class='emerald'>Emerald Sequoia LLC</span></a>
</div>
<hr>
</body></html>
EOF
  ;

my $workspaceRoot = findWorkspaceRoot;
my $destRoot = "$workspaceRoot/website/m1/aw";

warn "Destination root: $destRoot\n";

sub updateOne {
    my $name = shift;
    my $filename = fileFromName $name;
    my $dir = dirFromFilename $filename;
    my $dirPath = "$destRoot/$dir";
    if (! -d $dirPath) {
        mkdir $dirPath, 0777
          or die "Couldn't create directory '$dirPath': $!\n";
    }
    my $cssClass = cssClassFromName "$name-i";
    my $sku = skuFromName "$name";

    my $simplifiedName = $name;
    $simplifiedName =~ s/\&#257/a/go;

    my $header = $boilerplateHeader;
    $header =~ s/$simplifiedTemplateName/$simplifiedName/go;
    $header =~ s/$templateName/$name/go;
    $header =~ s/$templateFile/$filename/go;
    $header =~ s/$templateCssClass/$cssClass/go;
    $header =~ s/$templateSku/$sku/go;

    my $path = "$dirPath/$filename.html";

    warn "\nName: $name\n";
    warn "File: $path\n";
    warn "css class: $cssClass\n";
    warn "Sku: $sku\n";

    my $newPath = "$path.new";
    open OLD, $path
      or die "Couldn't read existing '$path': $!\n";
    open NEW, ">$newPath"
      or die "Couldn't create new path at '$newPath': $!\n";
    print NEW $header, "\n";

    # Skip to boilerplate
    my $foundBoilerplate = 0;
    while (<OLD>) {
        if (/<!-- Boilerplate code above here -->/) {
            $foundBoilerplate = 1;
            last;
        }
    }
    if (!$foundBoilerplate) {
        close NEW;
        unlink $newPath;
        die "Didn't find header boilerplate in '$path'\n";
    }

    print NEW;  # Reprints boilerplate header
    # Now we look for the boilerplate footer
    $foundBoilerplate = 0;
    while (<OLD>) {
        print NEW;  # Make sure this happens before we exit loop
        if (/<!-- Boilerplate code below here -->/) {
            $foundBoilerplate = 1;
            last;
        }
    }
    if (!$foundBoilerplate) {
        close NEW;
        unlink $newPath;
        die "Didn't find footer boilerplate in '$path'\n";
    }
    close OLD;

    print NEW $boilerplateFooter;
    close NEW;

    rename $newPath, $path
      or die "Couldn't reaname '$newPath' to '$path': $!\n";
}

my $faceCount = 0;
foreach my $faceName (getAllUserFaceNames()) {
    updateOne $faceName;
    $faceCount++;
}
print "\nDid $faceCount faces\n";
