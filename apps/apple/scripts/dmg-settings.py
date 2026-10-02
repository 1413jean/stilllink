# dmgbuild 設定：./build.sh dmg 會用 -D app=… -D bg=… -D icon=… 傳進來
import os

app = defines["app"]  # noqa: F821
files = [app, defines["guide"]]  # noqa: F821  安裝說明.txt
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]  # noqa: F821  磁碟（掛載後）的圖示
background = defines["bg"]  # noqa: F821  有 @2x 會自動用在 Retina

format = "UDZO"
filesystem = "HFS+"
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((200, 110), (660, 572))   # 高度含標題列 32pt，內容剛好 540 對齊背景
icon_size = 128
text_size = 14
icon_locations = {
    os.path.basename(app): (180, 170),
    "Applications": (480, 170),
    os.path.basename(defines["guide"]): (330, 430),  # noqa: F821
}
