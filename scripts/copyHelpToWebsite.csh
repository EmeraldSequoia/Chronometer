#! /bin/csh -f

if ($# != 1) then
    echo usage $0 '<website sandbox>'
    echo run after a simulator release build of Chronometer
    exit
endif

set src = build/Release-iphonesimulator/Chronometer.app/Help
set dest = $1/h

if (! -e $dest) then
    echo destination directory missing
    exit
endif

foreach watch (Alexandria Atlantis Chandra Haleakala McAlester Paris Geneva Istanbul Olympia Thebes Firenze Miami Vienna)
    sed -e's/en.m.wikipedia/en.wikipedia/g' $src/"$watch"/"$watch".html | sed -e's/Mauna Kea\/Mauna Kea-icon-f.png/MaunaKea\/MaunaKea-icon-f.png/g' | sed -e's/Mauna Kea\/Mauna Kea.html/MauneKea\/MaunaKea.html/g' > $dest/"$watch"/"$watch".html
end

    sed -e's/en.m.wikipedia/en.wikipedia/g' $src/"Mauna Kea"/"Mauna Kea".html | sed -e's/Mauna Kea\/Mauna Kea-icon-f.png/MaunaKea\/MaunaKea-icon-f.png/g' | sed -e's/Mauna Kea\/Mauna Kea.html/MaunaKea\/MaunaKea.html/g' > $dest/MaunaKea/MaunaKea.html

foreach f (Geneva/PredictingEclipses Application Settings TimeSync AstroAccuracy Complications ReleaseNotesGen Credits)
   rm -f $dest/$f.html
    sed -e's/en\.m\.wikipedia/en\.wikipedia/g' $src/$f.html | sed -e's/"Mauna Kea\/Mauna Kea-icon-f.png"/MaunaKea\/MaunaKea-icon-f.png/g' | sed -e's/"Mauna Kea\/Mauna Kea.html"/MaunaKea\/MaunaKea.html/g' > $dest/$f.html
end
