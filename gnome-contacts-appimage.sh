#!/bin/sh

set -eux

PACKAGE=gnome-contacts
DESKTOP=org.gnome.Contacts.desktop
ICON=org.gnome.Contacts.svg

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1
export VERSION=$(pacman -Q "$PACKAGE" | awk 'NR==1 {print $2; exit}')
echo "$VERSION" > ~/version

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
SHARUN="https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"

# Prepare AppDir
mkdir -p ./AppDir/shared/lib
cd ./AppDir

# Copy desktop file & icon
cp -v /usr/share/applications/"$DESKTOP"             ./
cp -v /usr/share/icons/hicolor/scalable/apps/"$ICON" ./
cp -v /usr/share/icons/hicolor/scalable/apps/"$ICON" ./.DirIcon

# Patch StartupWMClass to work on X11
# Doesn't work when ran in Wayland, as it's 'org.gnome.Contacts' instead.
# It needs to be manually changed by the user in this case.
sed -i '/^\[Desktop Entry\]/a\
StartupWMClass=gnome-contacts
' "$DESKTOP"

# ADD LIBRARIES
wget "$SHARUN" -O ./sharun-aio
chmod +x ./sharun-aio
xvfb-run -a -- ./sharun-aio l -p -v -e -s -k \
	/usr/bin/gnome-contacts \
	/usr/lib/libgst* \
	/usr/lib/gstreamer-*/*.so \
	/usr/lib/folks/*/backends/*/* \
        /usr/lib/evolution-data-server/*/*
rm -f ./sharun-aio

# Copy locale manually, as sharun doesn't do that at the moment
cp -vr /usr/lib/locale           ./shared/lib
cp -r /usr/share/locale          ./share
find ./share/locale -type f ! -name '*glib*' ! -name '*gnome-contacts*' -delete
find ./share/locale -type f 
# Fix hardcoded path for locale
sed -i 's|/usr/share|././/share|g' ./shared/bin/gnome-contacts
# Fix hardcoded path for gnome-contacts-parser
sed -i 's|/usr/lib|././/lib|g' ./shared/bin/gnome-contacts

# Fix hardcoded path for 'libcamel' libraries from 'evolution-data-server'
sed -i 's|/usr/lib|././/lib|g' ./shared/lib/libcamel*
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}' >> ./.env 

# Add gnome-contacts lib directory, as it didn't get added by sharun
cp /usr/lib/gnome-contacts-search-provider ./lib/gnome-contacts-search-provider
cp -r /usr/lib/gnome-contacts ./lib/gnome-contacts

# Deploy Gstreamer, evolution-data-server & gnome-contact binaries from /lib/ manually, as sharun can only handle libraries in /lib/ for now
echo "Deploying Gstreamer & evolution-data-server binaries..."
cp -r /usr/lib/evolution-data-server ./shared/lib/evolution-data-server
cp -vn /usr/lib/gstreamer-*/*  ./shared/lib/gstreamer-* || true

echo "Sharunning Gstreamer & evolution-data-server bins..."
bins_to_find="$(find ./shared/lib/ -exec file {} \; | grep -i 'elf.*executable' | awk -F':' '{print $1}')"
for bin in $bins_to_find; do
	mv -v "$bin" ./shared/bin && ln ./sharun "$bin"
	echo "Sharan $bin"
done

# Prepare sharun
ln ./sharun ./AppRun
./sharun -g

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

#Add update info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime --appimage-addupdinfo "$UPINFO"

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S26 -B8 \
	--header uruntime \
	-i ./AppDir -o "$PACKAGE"-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage

echo "All Done!"
