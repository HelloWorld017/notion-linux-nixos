# Linux desktop patches from AUR notion-app-electron.
# AST matching tolerates changes to minified variable names.
index_js=./asar_patched/.webpack/main/index.js
sg_flags=(--lang javascript -U)

sg_patch() {
  ast-grep run "${sg_flags[@]}" -p "$1" -r "$2" "$index_js"
}

sg_patch_select() {
  ast-grep run "${sg_flags[@]}" --selector "$1" -p "$2" -r "$3" "$index_js"
}

sg_patch \
  'this.tray.on("click",()=>{this.onClick()})' \
  'this.tray.setContextMenu(this.trayMenu),this.tray.on("click",()=>{this.onClick()})'
sg_patch_select method_definition \
  'class X { getIcon(){ $$$BODY } }' \
  'getIcon(){return require("path").resolve(__dirname,"trayIcon.png");}'
sg_patch \
  '$S.setUserAgent(`${$S.getUserAgent()} WantsServiceWorker`)' \
  '$S.setUserAgent(`${$S.getUserAgent().replace("Linux", "Windows")} WantsServiceWorker`)'
sg_patch \
  'if("darwin"===process.platform)$MAC;else if("win32"===process.platform){const $UNINSTALL=$ARGS=>$ARGS.find($ARG=>"--uninstall"===$ARG);$$$B}' \
  'if("darwin"===process.platform)$MAC;else if("linux"===process.platform){const $UNINSTALL=$ARGS=>$ARGS.find($ARG=>"--uninstall"===$ARG);$$$B}'
# System Electron includes app.asar in argv; it is not a Markdown file.
sg_patch \
  'function $F($ARG){const $EXT=$PATH.default.extname($ARG).toLowerCase();return!$ARG.startsWith("-")&&void 0===$SCHEME($ARG)&&$EXT.length>0&&".exe"!==$EXT}' \
  'function $F($ARG){const $EXT=$PATH.default.extname($ARG).toLowerCase();return!$ARG.startsWith("-")&&void 0===$SCHEME($ARG)&&$EXT.length>0&&".exe"!==$EXT&&".asar"!==$EXT}'
sg_patch \
  '($$$PRE,function(){$$$INIT}(),0)' \
  '($$$PRE,function(){$$$INIT}())'
sg_patch_select ternary_expression \
  '"win32"===process.platform?function($E,$T){$$$A}($E,$T):$ALT' \
  '"linux"===process.platform?function($E,$T){$$$A}($E,$T):$ALT'
