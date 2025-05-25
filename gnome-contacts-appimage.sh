#!/bin/sh

set -eu

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

cp -v /usr/share/applications/"$DESKTOP"            ./
cp -v /usr/share/icons/hicolor/scalable/apps/"$ICON" ./
cp -v /usr/share/icons/hicolor/scalable/apps/"$ICON" ./.DirIcon

# ADD LIBRARIES
wget "$SHARUN" -O ./sharun-aio
chmod +x ./sharun-aio
xvfb-run -a -- ./sharun-aio l -p -v -e -s -k \
	/usr/bin/gnome-contacts* \
	/usr/lib/libgst* \
	/usr/lib/gstreamer-*/*.so \
        /usr/lib/folks/*/backends/*/*
rm -f ./sharun-aio

# FIXME add this variable to sharun
echo 'FOLKS_BACKEND_PATH=${SHARUN_DIR}/lib/folks/26/backends' >> ./.env

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

echo "Generating AppBundle..."
wget -qO ./pelf "https://github.com/xplshn/pelf/releases/latest/download/pelf_$(uname -m)" && chmod +x ./pelf
echo "Generating [dwfs]AppBundle...(Go runtime)"
./pelf --add-appdir ./AppDir \
	    --appbundle-id="${PACKAGE}-${VERSION}" \
     	    --compression "-C zstd:level=22 -S26 -B8" \
	    --output-to "${PACKAGE}-${VERSION}-anylinux-${ARCH}.dwfs.AppBundle"

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage
zsyncmake *.AppBundle -u *.AppBundle

echo "All Done!"
