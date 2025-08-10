# gnome-contacts-appimage
Test of Gnome Contacts AppImage, not intended for daily-driving yet.

## Known issues

- It depends on the host for reading the contacts database (`${XDG_DATA_HOME}/evolution/`)
- Importing contacts doesn't work
- Need to refactor it to use newer template & to not bundle `mesa`
