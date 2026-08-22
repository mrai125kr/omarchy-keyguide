.pragma library

// Each entry contains English, Korean, Japanese, Simplified Chinese, and
// Spanish in that order. Keeping the translations together makes it difficult
// to add a UI message without noticing that one of the supported languages is
// missing.
const localeOrder = ["en", "ko", "ja", "zh_CN", "es"]
const languageNames = {
  en: "English",
  ko: "한국어",
  ja: "日本語",
  zh_CN: "简体中文",
  es: "Español"
}

const messages = {
  "common.action": ["Action", "액션", "アクション", "操作", "Acción"],
  "common.available": ["Available", "사용 가능", "使用可能", "可用", "Disponible"],
  "common.cancel": ["Cancel", "취소", "キャンセル", "取消", "Cancelar"],
  "common.change": ["Change", "변경", "変更", "更改", "Cambiar"],
  "common.close": ["Close", "닫기", "閉じる", "关闭", "Cerrar"],
  "common.confirm": ["Confirm", "확인", "確認", "确认", "Confirmar"],
  "common.enabled": ["Enabled", "사용", "有効", "已启用", "Activado"],
  "common.hidden": ["Hidden", "숨김", "非表示", "隐藏", "Oculto"],
  "common.loading": ["Loading…", "불러오는 중…", "読み込み中…", "正在加载…", "Cargando…"],
  "common.refresh": ["Refresh", "새로고침", "更新", "刷新", "Actualizar"],
  "common.register": ["Register", "등록", "登録", "注册", "Registrar"],
  "common.remove": ["Remove", "제거", "削除", "移除", "Eliminar"],
  "common.save": ["Save", "저장", "保存", "保存", "Guardar"],
  "common.saving": ["Saving…", "저장 중…", "保存中…", "正在保存…", "Guardando…"],
  "common.shown": ["Shown", "표시", "表示", "显示", "Visible"],
  "common.unavailable": ["Unavailable", "사용할 수 없음", "利用できません", "不可用", "No disponible"],
  "common.unsavedChanges": ["Unsaved changes", "저장하지 않은 변경사항", "未保存の変更があります", "有未保存的更改", "Hay cambios sin guardar"],

  "language.label": ["Language", "언어", "言語", "语言", "Idioma"],
  "language.help": ["Choose the language used in Settings and the shortcut HUD.", "설정과 단축키 HUD에 표시할 언어를 선택하세요.", "設定とショートカットHUDで使用する言語を選びます。", "选择设置和快捷键 HUD 使用的语言。", "Elige el idioma de Ajustes y del HUD de atajos."],

  "settings.title": ["Omarchy Keyguide", "Omarchy 키가이드", "Omarchy キーガイド", "Omarchy 快捷键指南", "Guía de teclas de Omarchy"],
  "settings.subtitle": ["HUD and shortcut settings", "HUD 및 단축키 설정", "HUDとショートカットの設定", "HUD 和快捷键设置", "Ajustes del HUD y los atajos"],
  "settings.hud": ["HUD", "HUD", "HUD", "HUD", "HUD"],
  "settings.position": ["Position", "위치", "位置", "位置", "Posición"],
  "settings.position.center": ["Center", "가운데", "中央", "居中", "Centro"],
  "settings.position.top": ["Top", "위", "上", "顶部", "Arriba"],
  "settings.position.bottom": ["Bottom", "아래", "下", "底部", "Abajo"],
  "settings.position.left": ["Left", "왼쪽", "左", "左侧", "Izquierda"],
  "settings.position.right": ["Right", "오른쪽", "右", "右侧", "Derecha"],
  "settings.scale": ["Scale", "크기", "サイズ", "大小", "Tamaño"],
  "settings.opacity": ["Opacity", "투명도", "不透明度", "不透明度", "Opacidad"],
  "settings.followTheme": ["Follow theme", "테마 따르기", "テーマに合わせる", "跟随主题", "Usar el tema"],
  "settings.followThemeHelp": ["Use the active Omarchy popup colors.", "현재 Omarchy 팝업 색상을 사용합니다.", "現在のOmarchyポップアップの色を使用します。", "使用当前 Omarchy 弹窗的颜色。", "Usa los colores actuales de las ventanas emergentes de Omarchy."],
  "settings.hudEnabledHelp": ["Show the shortcut HUD while Super is held.", "Super 키를 누르는 동안 단축키 HUD를 표시합니다.", "Superキーを押している間、ショートカットHUDを表示します。", "按住 Super 键时显示快捷键 HUD。", "Muestra el HUD de atajos mientras mantienes pulsada la tecla Super."],
  "settings.previewTitle": ["Live HUD preview", "실시간 HUD 미리보기", "HUDライブプレビュー", "HUD 实时预览", "Vista previa del HUD"],
  "settings.previewHelp": ["Position, scale, opacity, and visibility changes appear here.", "위치, 크기, 투명도 및 표시 여부 변경사항이 여기에 나타납니다.", "位置、サイズ、不透明度、表示設定の変更がここに反映されます。", "位置、大小、不透明度和显示设置的更改会在此处显示。", "Los cambios de posición, tamaño, opacidad y visibilidad aparecen aquí."],
  "settings.resetAll": ["Reset all", "모두 초기화", "すべてリセット", "全部重置", "Restablecer todo"],
  "settings.confirmReset": ["Confirm reset", "초기화 확인", "リセットを確認", "确认重置", "Confirmar restablecimiento"],
  "settings.resetHelp": ["Press Reset all again to restore every shortcut changed by Keyguide.", "키가이드로 변경한 모든 단축키를 복원하려면 ‘모두 초기화’를 한 번 더 누르세요.", "キーガイドで変更したすべてのショートカットを元に戻すには、もう一度「すべてリセット」を押してください。", "再次按“全部重置”，即可恢复由快捷键指南更改的所有快捷键。", "Pulsa «Restablecer todo» otra vez para restaurar todos los atajos que cambió la guía."],

  "hud.heading": ["{modifiers} shortcuts", "{modifiers} 단축키", "{modifiers} ショートカット", "{modifiers} 快捷键", "Atajos de {modifiers}"],
  "hud.keyboard": ["Keyboard shortcut", "키보드 단축키", "キーボードショートカット", "键盘快捷键", "Atajo de teclado"],
  "hud.mouse": ["Mouse shortcut", "마우스 단축키", "マウスショートカット", "鼠标快捷键", "Atajo del ratón"],
  "hud.emptyGroup": ["No visible shortcuts in this group.", "이 그룹에 표시할 단축키가 없습니다.", "このグループに表示できるショートカットはありません。", "此组中没有可显示的快捷键。", "No hay atajos visibles en este grupo."],
  "hud.visibilityHelp": ["Showing or hiding only changes the HUD. The shortcut remains active in Hyprland.", "표시하거나 숨겨도 HUD만 바뀌며, 단축키는 Hyprland에서 계속 작동합니다.", "表示・非表示を切り替えてもHUDだけが変わり、ショートカットはHyprlandで引き続き有効です。", "显示或隐藏只会更改 HUD；快捷键仍会在 Hyprland 中生效。", "Mostrar u ocultar solo cambia el HUD; el atajo sigue activo en Hyprland."],

  "shortcut.management": ["Shortcut management", "단축키 관리", "ショートカット管理", "快捷键管理", "Gestión de atajos"],
  "shortcut.managementHelp": ["Choose a modifier group and key, then search for what the shortcut should do.", "보조키 그룹과 키를 고른 다음, 단축키로 실행할 항목을 검색하세요.", "修飾キーのグループとキーを選び、ショートカットで実行する項目を検索してください。", "选择修饰键组合和按键，然后搜索快捷键要执行的内容。", "Elige un grupo de modificadores y una tecla; después busca lo que debe hacer el atajo."],
  "shortcut.modifierGroup": ["Modifier group", "보조키 그룹", "修飾キーのグループ", "修饰键组合", "Grupo de modificadores"],
  "shortcut.key": ["Key", "키", "キー", "按键", "Tecla"],
  "shortcut.keyCapture": ["Key capture", "키 입력", "キー入力", "按键捕获", "Captura de tecla"],
  "shortcut.pressKey": ["Press a key…", "키를 누르세요…", "キーを押してください…", "请按一个键…", "Pulsa una tecla…"],
  "shortcut.assigned": ["Assigned", "지정됨", "割り当て済み", "已分配", "Asignado"],
  "shortcut.applying": ["Applying shortcut change…", "단축키 변경을 적용하는 중…", "ショートカットの変更を適用しています…", "正在应用快捷键更改…", "Aplicando el cambio de atajo…"],
  "shortcut.groupEnabledHelp": ["Show this modifier group in the HUD.", "이 보조키 그룹을 HUD에 표시합니다.", "この修飾キーグループをHUDに表示します。", "在 HUD 中显示此修饰键组合。", "Muestra este grupo de modificadores en el HUD."],
  "shortcut.assignmentHeading": ["Register or change action", "액션 등록 또는 변경", "アクションの登録・変更", "注册或更改操作", "Registrar o cambiar la acción"],
  "shortcut.actionTitle": ["HUD title", "HUD 제목", "HUDのタイトル", "HUD 标题", "Título del HUD"],
  "shortcut.actionTitleHelp": ["This is the friendly name shown in the shortcut HUD. You can edit it.", "단축키 HUD에 표시되는 친숙한 이름입니다. 직접 수정할 수 있습니다.", "ショートカットHUDに表示される分かりやすい名前です。自由に編集できます。", "这是快捷键 HUD 中显示的易懂名称，可以编辑。", "Es el nombre sencillo que se muestra en el HUD de atajos. Puedes editarlo."],
  "shortcut.arguments": ["Optional arguments", "선택 인자", "任意の引数", "可选参数", "Argumentos opcionales"],
  "shortcut.currentKey": ["Current key: {chord}", "현재 키: {chord}", "現在のキー: {chord}", "当前按键：{chord}", "Tecla actual: {chord}"],
  "shortcut.managedByKeyguide": ["Managed by Keyguide", "키가이드에서 관리", "キーガイドで管理", "由快捷键指南管理", "Gestionado por la guía"],
  "shortcut.omarchyDefault": ["Omarchy default", "Omarchy 기본값", "Omarchyの既定値", "Omarchy 默认设置", "Predeterminado de Omarchy"],
  "shortcut.registered": ["Registered shortcuts · HUD visibility", "등록된 단축키 · HUD 표시", "登録済みショートカット・HUD表示", "已注册的快捷键 · HUD 显示", "Atajos registrados · visibilidad en el HUD"],
  "shortcut.bindingCount": ["{count} binding", "바인딩 {count}개", "バインド {count}件", "{count} 个绑定", "{count} asignación"],
  "shortcut.bindingCountPlural": ["{count} bindings", "바인딩 {count}개", "バインド {count}件", "{count} 个绑定", "{count} asignaciones"],
  "shortcut.shortcutColumn": ["Shortcut", "단축키", "ショートカット", "快捷键", "Atajo"],
  "shortcut.titleColumn": ["Action / title", "액션 / 제목", "アクション / タイトル", "操作 / 标题", "Acción / título"],
  "shortcut.hudColumn": ["HUD", "HUD", "HUD", "HUD", "HUD"],
  "shortcut.actionColumn": ["Action", "액션", "アクション", "操作", "Acción"],
  "shortcut.emptyGroup": ["No active shortcuts in this group. Choose a free key to register one.", "이 그룹에 활성 단축키가 없습니다. 비어 있는 키를 골라 등록하세요.", "このグループに有効なショートカットはありません。空いているキーを選んで登録してください。", "此组中没有有效的快捷键。请选择一个空闲按键进行注册。", "No hay atajos activos en este grupo. Elige una tecla libre para registrar uno."],
  "shortcut.replace": ["Replace {oldTitle} with {newTitle}?", "{oldTitle}을 {newTitle}(으)로 바꾸시겠어요?", "{oldTitle}を{newTitle}に変更しますか？", "要将 {oldTitle} 替换为 {newTitle} 吗？", "¿Quieres sustituir {oldTitle} por {newTitle}?"],
  "shortcut.replaceAgain": ["Press Change again to confirm.", "확인하려면 ‘변경’을 한 번 더 누르세요.", "確認するには、もう一度「変更」を押してください。", "再次按“更改”以确认。", "Pulsa «Cambiar» otra vez para confirmar."],
  "shortcut.removeConfirm": ["Remove the {title} shortcut from {chord}?", "{chord}의 {title} 단축키를 제거할까요?", "{chord}から{title}のショートカットを削除しますか？", "要从 {chord} 移除 {title} 快捷键吗？", "¿Quieres eliminar el atajo de {title} de {chord}?"],
  "shortcut.removeAgain": ["Press Remove again to confirm.", "확인하려면 ‘제거’를 한 번 더 누르세요.", "確認するには、もう一度「削除」を押してください。", "再次按“移除”以确认。", "Pulsa «Eliminar» otra vez para confirmar."],
  "shortcut.removing": ["Removing shortcut…", "단축키를 제거하는 중…", "ショートカットを削除しています…", "正在移除快捷键…", "Eliminando el atajo…"],
  "shortcut.summary": ["{chord} will run {action}. The HUD will show “{title}”.", "{chord} 키로 {action}을(를) 실행합니다. HUD에는 ‘{title}’이(가) 표시됩니다.", "{chord}で{action}を実行します。HUDには「{title}」と表示されます。", "{chord} 将运行 {action}。HUD 会显示“{title}”。", "{chord} ejecutará {action}. El HUD mostrará «{title}»."],

  "search.prompt": ["What should this shortcut do?", "이 단축키로 무엇을 실행할까요?", "このショートカットで何を実行しますか？", "这个快捷键要执行什么？", "¿Qué debe hacer este atajo?"],
  "search.placeholder": ["Search apps, actions, or commands", "앱, 액션 또는 명령 검색", "アプリ、アクション、コマンドを検索", "搜索应用、操作或命令", "Busca aplicaciones, acciones o comandos"],
  "search.examples": ["Try “browser”, “screenshot”, or the name of an installed app.", "‘브라우저’, ‘스크린샷’ 또는 설치된 앱 이름을 입력해 보세요.", "「ブラウザ」「スクリーンショット」またはインストール済みアプリの名前を入力してください。", "可尝试输入“浏览器”“截图”或已安装应用的名称。", "Prueba con «navegador», «captura» o el nombre de una aplicación instalada."],
  "search.noResults": ["No matches. Check the spelling or try the English name.", "검색 결과가 없습니다. 철자를 확인하거나 영어 이름으로 검색해 보세요.", "一致する項目がありません。入力を確認するか、英語名で検索してください。", "没有匹配项。请检查拼写，或尝试使用英文名称。", "No hay coincidencias. Revisa la escritura o prueba el nombre en inglés."],
  "search.resultCount": ["{count} result", "결과 {count}개", "{count}件の結果", "{count} 个结果", "{count} resultado"],
  "search.resultCountPlural": ["{count} results", "결과 {count}개", "{count}件の結果", "{count} 个结果", "{count} resultados"],
  "search.category.application": ["Applications", "프로그램", "アプリケーション", "应用程序", "Aplicaciones"],
  "search.category.action": ["General actions", "일반 액션", "一般的なアクション", "常规操作", "Acciones generales"],
  "search.category.command": ["Commands", "명령", "コマンド", "命令", "Comandos"],
  "search.commandBadge": ["(CMD)", "(CMD)", "(CMD)", "(CMD)", "(CMD)"],
  "search.commandHelp": ["Advanced: runs an executable command directly.", "고급 기능: 실행 명령을 직접 실행합니다.", "上級者向け: 実行可能なコマンドを直接起動します。", "高级选项：直接运行可执行命令。", "Avanzado: ejecuta un comando directamente."],
  "search.refreshing": ["Refreshing installed apps and commands…", "설치된 프로그램과 명령을 새로 확인하는 중…", "インストール済みアプリとコマンドを更新しています…", "正在刷新已安装的应用和命令…", "Actualizando las aplicaciones y los comandos instalados…"],
  "search.selectionRemoved": ["That item is no longer installed. Choose another result.", "선택한 항목이 더 이상 설치되어 있지 않습니다. 다른 결과를 선택하세요.", "選択した項目は現在インストールされていません。別の結果を選んでください。", "所选项目已不再安装。请选择其他结果。", "Ese elemento ya no está instalado. Elige otro resultado."],
  "search.keyboardHelp": ["Use ↑ and ↓ to move, Enter to choose, and Esc to close.", "↑와 ↓로 이동하고 Enter로 선택하며 Esc로 닫을 수 있습니다.", "↑と↓で移動、Enterで選択、Escで閉じます。", "使用 ↑ 和 ↓ 移动，按 Enter 选择，按 Esc 关闭。", "Usa ↑ y ↓ para moverte, Intro para elegir y Esc para cerrar."],
  "search.catalogWarnings": ["Some unsupported application entries were hidden.", "지원하지 않는 일부 프로그램 항목은 숨겼습니다.", "対応していない一部のアプリ項目を非表示にしました。", "已隐藏部分不受支持的应用条目。", "Se ocultaron algunas entradas de aplicaciones no compatibles."],

  "error.settingsUnavailable": ["Keyguide settings are unavailable. Close and reopen Settings, then try again.", "키가이드 설정을 사용할 수 없습니다. 설정창을 닫았다가 다시 열고 시도하세요.", "キーガイドの設定を利用できません。設定を閉じて開き直してから、もう一度お試しください。", "快捷键指南设置不可用。请关闭并重新打开设置，然后重试。", "Los ajustes de la guía no están disponibles. Cierra y vuelve a abrir Ajustes e inténtalo de nuevo."],
  "error.settingsSave": ["Settings could not be saved. Your previous settings are unchanged.", "설정을 저장하지 못했습니다. 이전 설정은 그대로 유지됩니다.", "設定を保存できませんでした。以前の設定は変更されていません。", "无法保存设置。之前的设置保持不变。", "No se pudieron guardar los ajustes. Los anteriores no han cambiado."],
  "error.shortcutUnavailable": ["The shortcut service is unavailable. Close and reopen Settings, then try again.", "단축키 서비스를 사용할 수 없습니다. 설정창을 닫았다가 다시 열고 시도하세요.", "ショートカットサービスを利用できません。設定を閉じて開き直してから、もう一度お試しください。", "快捷键服务不可用。请关闭并重新打开设置，然后重试。", "El servicio de atajos no está disponible. Cierra y vuelve a abrir Ajustes e inténtalo de nuevo."],
  "error.shortcutNotEditable": ["This shortcut cannot be changed safely.", "이 단축키는 안전하게 변경할 수 없습니다.", "このショートカットは安全に変更できません。", "无法安全地更改此快捷键。", "Este atajo no se puede cambiar de forma segura."],
  "error.chooseAction": ["Choose an action and enter a HUD title.", "액션을 선택하고 HUD 제목을 입력하세요.", "アクションを選び、HUDのタイトルを入力してください。", "请选择操作并输入 HUD 标题。", "Elige una acción e introduce un título para el HUD."],
  "error.catalogLoad": ["Apps and commands could not be loaded. Refresh to try again.", "프로그램과 명령을 불러오지 못했습니다. 새로고침하여 다시 시도하세요.", "アプリとコマンドを読み込めませんでした。更新してもう一度お試しください。", "无法加载应用和命令。请刷新后重试。", "No se pudieron cargar las aplicaciones y los comandos. Actualiza para intentarlo de nuevo."],
  "error.catalogStale": ["The selected item changed or was removed. Nothing was modified; choose it again.", "선택한 항목이 변경되었거나 제거되었습니다. 아무것도 수정하지 않았으니 다시 선택하세요.", "選択した項目が変更または削除されました。変更は適用されていません。もう一度選択してください。", "所选项目已更改或移除。未修改任何内容，请重新选择。", "El elemento seleccionado cambió o se eliminó. No se modificó nada; vuelve a elegirlo."],
  "error.catalogChanged": ["The available actions changed. Nothing was modified; choose the action again.", "사용 가능한 액션이 변경되었습니다. 아무것도 수정하지 않았으니 액션을 다시 선택하세요.", "利用可能なアクションが変更されました。変更は適用されていません。もう一度選択してください。", "可用操作已更改。未修改任何内容，请重新选择操作。", "Las acciones disponibles cambiaron. No se modificó nada; vuelve a elegir la acción."],
  "error.targetOccupied": ["This shortcut is already used by {title}. Choose another key.", "이 단축키는 이미 {title}에 사용 중입니다. 다른 키를 선택하세요.", "このショートカットは{title}ですでに使用されています。別のキーを選んでください。", "此快捷键已由 {title} 使用。请选择其他按键。", "Este atajo ya lo usa {title}. Elige otra tecla."],
  "error.confirmReplacement": ["{title} already uses this shortcut. Press Change again to replace it.", "이 단축키는 {title}에서 사용 중입니다. 바꾸려면 ‘변경’을 한 번 더 누르세요.", "このショートカットは{title}で使用中です。置き換えるには、もう一度「変更」を押してください。", "此快捷键已由 {title} 使用。再次按“更改”即可替换。", "{title} ya usa este atajo. Pulsa «Cambiar» otra vez para sustituirlo."],
  "error.targetStale": ["This shortcut changed after Settings opened. Nothing was modified; select it again.", "설정창을 연 뒤 이 단축키가 변경되었습니다. 아무것도 수정하지 않았으니 다시 선택하세요.", "設定を開いた後にこのショートカットが変更されました。変更は適用されていません。もう一度選択してください。", "打开设置后，此快捷键已更改。未修改任何内容，请重新选择。", "Este atajo cambió después de abrir Ajustes. No se modificó nada; vuelve a seleccionarlo."],
  "error.languageInvalid": ["That language is not supported. Choose one of the languages in Settings.", "지원하지 않는 언어입니다. 설정에 표시된 언어 중 하나를 선택하세요.", "その言語には対応していません。設定に表示されている言語から選んでください。", "不支持该语言。请从设置中列出的语言里选择。", "Ese idioma no es compatible. Elige uno de los idiomas de Ajustes."],
  "error.invalidArguments": ["The command arguments are not valid. Check quotes and try again.", "명령 인자가 올바르지 않습니다. 따옴표를 확인하고 다시 시도하세요.", "コマンドの引数が正しくありません。引用符を確認して、もう一度お試しください。", "命令参数无效。请检查引号后重试。", "Los argumentos del comando no son válidos. Revisa las comillas e inténtalo de nuevo."],
  "error.applyFailed": ["The shortcut could not be changed. Your previous shortcut is still active.", "단축키를 변경하지 못했습니다. 이전 단축키는 계속 작동합니다.", "ショートカットを変更できませんでした。以前のショートカットは引き続き有効です。", "无法更改快捷键。之前的快捷键仍然有效。", "No se pudo cambiar el atajo. El anterior sigue activo."],
  "error.removeUnavailable": ["This shortcut cannot be removed safely. Refresh and try again.", "이 단축키는 안전하게 제거할 수 없습니다. 새로고침한 뒤 다시 시도하세요.", "このショートカットは安全に削除できません。更新してからもう一度お試しください。", "无法安全地移除此快捷键。请刷新后重试。", "Este atajo no se puede eliminar de forma segura. Actualiza e inténtalo de nuevo."],
  "error.removeFailed": ["The shortcut could not be removed. Your existing shortcuts are unchanged.", "단축키를 제거하지 못했습니다. 기존 단축키는 그대로 유지됩니다.", "ショートカットを削除できませんでした。既存のショートカットは変更されていません。", "无法移除快捷键。现有快捷键保持不变。", "No se pudo eliminar el atajo. Los atajos existentes no han cambiado."],
  "error.resetFailed": ["Shortcuts could not be reset. Existing shortcuts are unchanged.", "단축키를 초기화하지 못했습니다. 기존 단축키는 그대로 유지됩니다.", "ショートカットをリセットできませんでした。既存のショートカットは変更されていません。", "无法重置快捷键。现有快捷键保持不变。", "No se pudieron restablecer los atajos. Los existentes no han cambiado."],

  "action.terminal": ["Terminal", "터미널", "ターミナル", "终端", "Terminal"],
  "action.browser": ["Browser", "브라우저", "ブラウザ", "浏览器", "Navegador"],
  "action.fileManager": ["File Manager", "파일 관리자", "ファイルマネージャー", "文件管理器", "Gestor de archivos"],
  "action.applicationLauncher": ["Application Launcher", "프로그램 실행기", "アプリランチャー", "应用启动器", "Lanzador de aplicaciones"],
  "action.closeWindow": ["Close Window", "창 닫기", "ウィンドウを閉じる", "关闭窗口", "Cerrar ventana"],
  "action.toggleFullscreen": ["Toggle Fullscreen", "전체 화면 전환", "全画面表示を切り替え", "切换全屏", "Alternar pantalla completa"],
  "action.toggleFloating": ["Toggle Floating", "플로팅 전환", "フローティングを切り替え", "切换浮动", "Alternar modo flotante"],
  "action.lockScreen": ["Lock Screen", "화면 잠금", "画面をロック", "锁定屏幕", "Bloquear pantalla"],
  "action.settings": ["Settings", "설정", "設定", "设置", "Ajustes"],
  "action.screenshot": ["Screenshot", "스크린샷", "スクリーンショット", "截图", "Captura de pantalla"],
  "action.clipboard": ["Clipboard", "클립보드", "クリップボード", "剪贴板", "Portapapeles"],
  "action.notifications": ["Notifications", "알림", "通知", "通知", "Notificaciones"],
  "action.previousWorkspace": ["Previous Workspace", "이전 작업 공간", "前のワークスペース", "上一个工作区", "Espacio de trabajo anterior"],
  "action.nextWorkspace": ["Next Workspace", "다음 작업 공간", "次のワークスペース", "下一个工作区", "Espacio de trabajo siguiente"],
  "action.downloadVideoFromWebApp": ["Download Video from Web App", "웹 앱에서 동영상 다운로드", "Webアプリから動画をダウンロード", "从网页应用下载视频", "Descargar vídeo desde la aplicación web"],
  "action.copyUrlFromWebApp": ["Copy URL from Web App", "웹 앱에서 URL 복사", "WebアプリからURLをコピー", "从网页应用复制网址", "Copiar URL desde la aplicación web"]
}

// Omarchy action titles are presentation strings, not application identities.
// Application and brand names intentionally stay out of this table so names
// such as Codex, ChatGPT, Obsidian, and Signal are shown exactly as installed.
const omarchyActionTranslations = {
  "activity": ["action.activity", ["Activity", "활동", "アクティビティ", "活动", "Actividad"]],
  "agent": ["action.agent", ["Agent", "에이전트", "エージェント", "智能助手", "Agente"]],
  "apps menu": ["action.appsMenu", ["Apps Menu", "프로그램 메뉴", "アプリメニュー", "应用菜单", "Menú de aplicaciones"]],
  "audio": ["action.audio", ["Audio", "오디오", "オーディオ", "音频", "Audio"]],
  "background switcher": ["action.backgroundSwitcher", ["Background Switcher", "배경 전환", "背景を切り替え", "切换背景", "Cambiar fondo"]],
  "bluetooth": ["action.bluetooth", ["Bluetooth", "블루투스", "Bluetooth", "蓝牙", "Bluetooth"]],
  "browser (private)": ["action.privateBrowser", ["Private Browser", "비공개 브라우저", "プライベートブラウザ", "隐私浏览器", "Navegador privado"]],
  "calculator": ["action.calculator", ["Calculator", "계산기", "電卓", "计算器", "Calculadora"]],
  "calendar": ["action.calendar", ["Calendar", "달력", "カレンダー", "日历", "Calendario"]],
  "capture menu": ["action.captureMenu", ["Capture Menu", "캡처 메뉴", "キャプチャメニュー", "截取菜单", "Menú de captura"]],
  "clear reminders": ["action.clearReminders", ["Clear Reminders", "미리 알림 모두 지우기", "リマインダーを消去", "清除提醒", "Borrar recordatorios"]],
  "clipboard manager": ["action.clipboardManager", ["Clipboard Manager", "클립보드 관리자", "クリップボードマネージャー", "剪贴板管理器", "Gestor del portapapeles"]],
  "color picker": ["action.colorPicker", ["Color Picker", "색상 선택기", "カラーピッカー", "取色器", "Selector de color"]],
  "dismiss all notifications": ["action.dismissAllNotifications", ["Dismiss All Notifications", "알림 모두 닫기", "すべての通知を閉じる", "关闭所有通知", "Descartar todas las notificaciones"]],
  "dismiss last notification": ["action.dismissLastNotification", ["Dismiss Last Notification", "마지막 알림 닫기", "最新の通知を閉じる", "关闭上一条通知", "Descartar la última notificación"]],
  "display": ["action.display", ["Display", "디스플레이", "ディスプレイ", "显示器", "Pantalla"]],
  "editor": ["action.editor", ["Editor", "편집기", "エディター", "编辑器", "Editor"]],
  "email": ["action.email", ["Email", "이메일", "メール", "邮件", "Correo"]],
  "emojis": ["action.emojis", ["Emojis", "이모지", "絵文字", "表情符号", "Emojis"]],
  "extract text (ocr) from screenshot": ["action.extractTextOcr", ["Extract Text (OCR) from Screenshot", "스크린샷에서 텍스트 추출(OCR)", "スクリーンショットからテキストを抽出（OCR）", "从截图提取文本（OCR）", "Extraer texto (OCR) de la captura"]],
  "file manager (cwd)": ["action.fileManagerCwd", ["File Manager (Current Folder)", "현재 폴더의 파일 관리자", "現在のフォルダーでファイルマネージャーを開く", "在当前目录打开文件管理器", "Gestor de archivos (carpeta actual)"]],
  "focus on above window": ["action.focusWindowAbove", ["Focus Window Above", "위쪽 창으로 이동", "上のウィンドウにフォーカス", "聚焦上方窗口", "Enfocar la ventana superior"]],
  "focus on below window": ["action.focusWindowBelow", ["Focus Window Below", "아래쪽 창으로 이동", "下のウィンドウにフォーカス", "聚焦下方窗口", "Enfocar la ventana inferior"]],
  "focus on left window": ["action.focusWindowLeft", ["Focus Window Left", "왼쪽 창으로 이동", "左のウィンドウにフォーカス", "聚焦左侧窗口", "Enfocar la ventana izquierda"]],
  "focus on right window": ["action.focusWindowRight", ["Focus Window Right", "오른쪽 창으로 이동", "右のウィンドウにフォーカス", "聚焦右侧窗口", "Enfocar la ventana derecha"]],
  "former workspace": ["action.formerWorkspace", ["Last Used Workspace", "직전에 사용한 작업 공간", "直前に使用したワークスペース", "上次使用的工作区", "Último espacio de trabajo usado"]],
  "full width": ["action.fullWidth", ["Full Width", "최대 너비", "最大幅", "最大宽度", "Ancho completo"]],
  "hardware menu": ["action.hardwareMenu", ["Hardware Menu", "하드웨어 메뉴", "ハードウェアメニュー", "硬件菜单", "Menú de hardware"]],
  "herdr keybindings": ["action.herdrKeybindings", ["Herdr Keybindings", "Herdr 단축키", "Herdr キーバインド", "Herdr 快捷键", "Atajos de Herdr"]],
  "invoke last notification": ["action.invokeLastNotification", ["Invoke Last Notification", "마지막 알림 실행", "最新の通知を実行", "执行上一条通知", "Activar la última notificación"]],
  "keybindings": ["action.keybindings", ["Keybindings", "단축키", "キーバインド", "快捷键", "Atajos de teclado"]],
  "lock system": ["action.lockSystem", ["Lock System", "시스템 잠금", "システムをロック", "锁定系统", "Bloquear sistema"]],
  "monitor scaling down": ["action.monitorScalingDown", ["Decrease Monitor Scale", "모니터 배율 낮추기", "ディスプレイの倍率を下げる", "降低显示缩放", "Reducir la escala del monitor"]],
  "monitor scaling up": ["action.monitorScalingUp", ["Increase Monitor Scale", "모니터 배율 높이기", "ディスプレイの倍率を上げる", "提高显示缩放", "Aumentar la escala del monitor"]],
  "move active window out of group": ["action.moveActiveWindowOutOfGroup", ["Move Active Window out of Group", "활성 창을 그룹 밖으로 이동", "アクティブウィンドウをグループから外す", "将活动窗口移出组", "Sacar la ventana activa del grupo"]],
  "move grouped window focus left": ["action.moveGroupedWindowFocusLeft", ["Focus Previous Grouped Window", "그룹의 왼쪽 창으로 이동", "グループ内の左のウィンドウにフォーカス", "聚焦组内左侧窗口", "Enfocar la ventana izquierda del grupo"]],
  "move grouped window focus right": ["action.moveGroupedWindowFocusRight", ["Focus Next Grouped Window", "그룹의 오른쪽 창으로 이동", "グループ内の右のウィンドウにフォーカス", "聚焦组内右侧窗口", "Enfocar la ventana derecha del grupo"]],
  "move window to group on bottom": ["action.moveWindowToGroupBottom", ["Move Window to Group Below", "창을 아래쪽 그룹으로 이동", "ウィンドウを下のグループへ移動", "将窗口移到下方组", "Mover la ventana al grupo inferior"]],
  "move window to group on left": ["action.moveWindowToGroupLeft", ["Move Window to Group on Left", "창을 왼쪽 그룹으로 이동", "ウィンドウを左のグループへ移動", "将窗口移到左侧组", "Mover la ventana al grupo izquierdo"]],
  "move window to group on right": ["action.moveWindowToGroupRight", ["Move Window to Group on Right", "창을 오른쪽 그룹으로 이동", "ウィンドウを右のグループへ移動", "将窗口移到右侧组", "Mover la ventana al grupo derecho"]],
  "move window to group on top": ["action.moveWindowToGroupTop", ["Move Window to Group Above", "창을 위쪽 그룹으로 이동", "ウィンドウを上のグループへ移動", "将窗口移到上方组", "Mover la ventana al grupo superior"]],
  "move window to scratchpad": ["action.moveWindowToScratchpad", ["Move Window to Scratchpad", "창을 스크래치패드로 이동", "ウィンドウをスクラッチパッドへ移動", "将窗口移到暂存区", "Mover la ventana al panel temporal"]],
  "move workspace to down monitor": ["action.moveWorkspaceToMonitorDown", ["Move Workspace to Monitor Below", "작업 공간을 아래쪽 모니터로 이동", "ワークスペースを下のモニターへ移動", "将工作区移到下方显示器", "Mover el espacio de trabajo al monitor inferior"]],
  "move workspace to left monitor": ["action.moveWorkspaceToMonitorLeft", ["Move Workspace to Left Monitor", "작업 공간을 왼쪽 모니터로 이동", "ワークスペースを左のモニターへ移動", "将工作区移到左侧显示器", "Mover el espacio de trabajo al monitor izquierdo"]],
  "move workspace to right monitor": ["action.moveWorkspaceToMonitorRight", ["Move Workspace to Right Monitor", "작업 공간을 오른쪽 모니터로 이동", "ワークスペースを右のモニターへ移動", "将工作区移到右侧显示器", "Mover el espacio de trabajo al monitor derecho"]],
  "move workspace to up monitor": ["action.moveWorkspaceToMonitorUp", ["Move Workspace to Monitor Above", "작업 공간을 위쪽 모니터로 이동", "ワークスペースを上のモニターへ移動", "将工作区移到上方显示器", "Mover el espacio de trabajo al monitor superior"]],
  "music": ["action.music", ["Music", "음악", "ミュージック", "音乐", "Música"]],
  "music tui": ["action.musicTui", ["Terminal Music Player", "터미널 음악 플레이어", "ターミナル音楽プレーヤー", "终端音乐播放器", "Reproductor de música en terminal"]],
  "network": ["action.network", ["Network", "네트워크", "ネットワーク", "网络", "Red"]],
  "new email": ["action.newEmail", ["New Email", "새 이메일", "新規メール", "新邮件", "Nuevo correo"]],
  "next window in group": ["action.nextWindowInGroup", ["Next Window in Group", "그룹의 다음 창", "グループ内の次のウィンドウ", "组内下一个窗口", "Siguiente ventana del grupo"]],
  "omarchy menu": ["action.omarchyMenu", ["Omarchy Menu", "Omarchy 메뉴", "Omarchy メニュー", "Omarchy 菜单", "Menú de Omarchy"]],
  "open notification history": ["action.openNotificationHistory", ["Open Notification History", "알림 기록 열기", "通知履歴を開く", "打开通知历史", "Abrir el historial de notificaciones"]],
  "passwords": ["action.passwords", ["Passwords", "비밀번호", "パスワード", "密码", "Contraseñas"]],
  "pop window out (float & pin)": ["action.popWindowOut", ["Pop Window Out (Float and Pin)", "창을 꺼내 플로팅 및 고정", "ウィンドウを切り離す（フロート・固定）", "弹出窗口（浮动并固定）", "Extraer la ventana (flotante y fijada)"]],
  "power": ["action.power", ["Power", "전원", "電源", "电源", "Energía"]],
  "previous window in group": ["action.previousWindowInGroup", ["Previous Window in Group", "그룹의 이전 창", "グループ内の前のウィンドウ", "组内上一个窗口", "Ventana anterior del grupo"]],
  "pseudo window": ["action.pseudoWindow", ["Pseudo Window", "가상 창", "疑似ウィンドウ", "伪窗口", "Ventana simulada"]],
  "restore window width": ["action.restoreWindowWidth", ["Restore Window Width", "창 너비 복원", "ウィンドウ幅を復元", "恢复窗口宽度", "Restaurar el ancho de la ventana"]],
  "save window width": ["action.saveWindowWidth", ["Save Window Width", "창 너비 저장", "ウィンドウ幅を保存", "保存窗口宽度", "Guardar el ancho de la ventana"]],
  "set reminder": ["action.setReminder", ["Set Reminder", "미리 알림 설정", "リマインダーを設定", "设置提醒", "Establecer recordatorio"]],
  "share": ["action.share", ["Share", "공유", "共有", "分享", "Compartir"]],
  "show battery remaining": ["action.showBatteryRemaining", ["Show Battery Remaining", "남은 배터리 표시", "バッテリー残量を表示", "显示剩余电量", "Mostrar la batería restante"]],
  "show reminders": ["action.showReminders", ["Show Reminders", "미리 알림 표시", "リマインダーを表示", "显示提醒", "Mostrar recordatorios"]],
  "show time": ["action.showTime", ["Show Time", "시간 표시", "時刻を表示", "显示时间", "Mostrar la hora"]],
  "swap window down": ["action.swapWindowDown", ["Swap Window Down", "창을 아래 창과 교환", "ウィンドウを下と入れ替え", "向下交换窗口", "Intercambiar la ventana hacia abajo"]],
  "swap window to the left": ["action.swapWindowLeft", ["Swap Window Left", "창을 왼쪽 창과 교환", "ウィンドウを左と入れ替え", "向左交换窗口", "Intercambiar la ventana hacia la izquierda"]],
  "swap window to the right": ["action.swapWindowRight", ["Swap Window Right", "창을 오른쪽 창과 교환", "ウィンドウを右と入れ替え", "向右交换窗口", "Intercambiar la ventana hacia la derecha"]],
  "swap window up": ["action.swapWindowUp", ["Swap Window Up", "창을 위 창과 교환", "ウィンドウを上と入れ替え", "向上交换窗口", "Intercambiar la ventana hacia arriba"]],
  "system menu": ["action.systemMenu", ["System Menu", "시스템 메뉴", "システムメニュー", "系统菜单", "Menú del sistema"]],
  "theme menu": ["action.themeMenu", ["Theme Menu", "테마 메뉴", "テーマメニュー", "主题菜单", "Menú de temas"]],
  "tiled full screen": ["action.tiledFullScreen", ["Tiled Full Screen", "타일 전체 화면", "タイル全画面", "平铺全屏", "Pantalla completa en mosaico"]],
  "tmux keybindings": ["action.tmuxKeybindings", ["Tmux Keybindings", "Tmux 단축키", "Tmux キーバインド", "Tmux 快捷键", "Atajos de Tmux"]],
  "toggle dictation": ["action.toggleDictation", ["Toggle Dictation", "받아쓰기 전환", "音声入力を切り替え", "切换语音输入", "Alternar dictado"]],
  "toggle laptop display": ["action.toggleLaptopDisplay", ["Toggle Laptop Display", "노트북 화면 켜기/끄기", "ノートPC画面を切り替え", "切换笔记本屏幕", "Alternar la pantalla del portátil"]],
  "toggle laptop display mirroring": ["action.toggleLaptopDisplayMirroring", ["Toggle Laptop Display Mirroring", "노트북 화면 미러링 전환", "ノートPC画面のミラーリングを切り替え", "切换笔记本屏幕镜像", "Alternar la duplicación de la pantalla del portátil"]],
  "toggle locking on idle": ["action.toggleLockingOnIdle", ["Toggle Locking when Idle", "유휴 시 자동 잠금 전환", "アイドル時の自動ロックを切り替え", "切换空闲自动锁定", "Alternar el bloqueo por inactividad"]],
  "toggle menu": ["action.toggleMenu", ["Toggle Menu", "메뉴 표시 전환", "メニュー表示を切り替え", "切换菜单显示", "Alternar menú"]],
  "toggle nightlight": ["action.toggleNightlight", ["Toggle Night Light", "야간 조명 전환", "ナイトライトを切り替え", "切换夜间模式", "Alternar luz nocturna"]],
  "toggle scratchpad": ["action.toggleScratchpad", ["Toggle Scratchpad", "스크래치패드 전환", "スクラッチパッドを切り替え", "切换暂存区", "Alternar panel temporal"]],
  "toggle silencing notifications": ["action.toggleSilencingNotifications", ["Toggle Notification Silencing", "알림 음소거 전환", "通知のミュートを切り替え", "切换通知静音", "Alternar silencio de notificaciones"]],
  "toggle single-window square aspect": ["action.toggleSingleWindowSquareAspect", ["Toggle Square Aspect for One Window", "단일 창 정사각형 비율 전환", "単一ウィンドウの正方形比率を切り替え", "切换单窗口方形比例", "Alternar formato cuadrado para una ventana"]],
  "toggle top bar": ["action.toggleTopBar", ["Toggle Top Bar", "상단 바 표시 전환", "トップバーを切り替え", "切换顶部栏", "Alternar barra superior"]],
  "toggle weather": ["action.toggleWeather", ["Toggle Weather", "날씨 표시 전환", "天気表示を切り替え", "切换天气显示", "Alternar el tiempo"]],
  "toggle window floating/tiling": ["action.toggleWindowFloatingTiling", ["Toggle Window Floating/Tiling", "창 플로팅/타일 전환", "ウィンドウのフロート・タイルを切り替え", "切换窗口浮动/平铺", "Alternar ventana flotante/en mosaico"]],
  "toggle window gaps": ["action.toggleWindowGaps", ["Toggle Window Gaps", "창 간격 전환", "ウィンドウ間隔を切り替え", "切换窗口间距", "Alternar espacios entre ventanas"]],
  "toggle window grouping": ["action.toggleWindowGrouping", ["Toggle Window Grouping", "창 그룹 전환", "ウィンドウのグループ化を切り替え", "切换窗口分组", "Alternar agrupación de ventanas"]],
  "toggle window split": ["action.toggleWindowSplit", ["Toggle Window Split", "창 분할 방향 전환", "ウィンドウの分割方向を切り替え", "切换窗口分割", "Alternar división de ventana"]],
  "toggle window transparency": ["action.toggleWindowTransparency", ["Toggle Window Transparency", "창 투명도 전환", "ウィンドウの透明度を切り替え", "切换窗口透明度", "Alternar transparencia de ventana"]],
  "toggle workspace layout": ["action.toggleWorkspaceLayout", ["Toggle Workspace Layout", "작업 공간 레이아웃 전환", "ワークスペースのレイアウトを切り替え", "切换工作区布局", "Alternar diseño del espacio de trabajo"]],
  "transcode": ["action.transcode", ["Transcode", "미디어 변환", "トランスコード", "转码", "Transcodificar"]],
  "x post": ["action.xPost", ["Post to X", "X에 게시", "Xに投稿", "发布到 X", "Publicar en X"]],
  "brightness down": ["action.brightnessDown", ["Brightness Down", "화면 밝기 낮추기", "画面の明るさを下げる", "降低屏幕亮度", "Bajar el brillo"]],
  "brightness down precise": ["action.brightnessDownPrecise", ["Brightness Down Precisely", "화면 밝기 조금 낮추기", "画面の明るさを少し下げる", "精细降低屏幕亮度", "Bajar el brillo con precisión"]],
  "brightness maximum": ["action.brightnessMaximum", ["Maximum Brightness", "화면 밝기 최대로", "画面を最大の明るさにする", "屏幕亮度最高", "Brillo máximo"]],
  "brightness minimum": ["action.brightnessMinimum", ["Minimum Brightness", "화면 밝기 최저로", "画面を最小の明るさにする", "屏幕亮度最低", "Brillo mínimo"]],
  "brightness up": ["action.brightnessUp", ["Brightness Up", "화면 밝기 높이기", "画面を明るくする", "提高屏幕亮度", "Subir el brillo"]],
  "brightness up precise": ["action.brightnessUpPrecise", ["Brightness Up Precisely", "화면 밝기 조금 높이기", "画面を少し明るくする", "精细提高屏幕亮度", "Subir el brillo con precisión"]],
  "capture entire screen": ["action.captureEntireScreen", ["Capture Entire Screen", "전체 화면 캡처", "画面全体をキャプチャ", "截取整个屏幕", "Capturar toda la pantalla"]],
  "capture highlighted window": ["action.captureHighlightedWindow", ["Capture Highlighted Window", "선택한 창 캡처", "選択中のウィンドウをキャプチャ", "截取选中的窗口", "Capturar la ventana resaltada"]],
  "close all windows": ["action.closeAllWindows", ["Close All Windows", "모든 창 닫기", "すべてのウィンドウを閉じる", "关闭所有窗口", "Cerrar todas las ventanas"]],
  "disable touchpad": ["action.disableTouchpad", ["Disable Touchpad", "터치패드 끄기", "タッチパッドを無効にする", "禁用触控板", "Desactivar el panel táctil"]],
  "eject media": ["action.ejectMedia", ["Eject Media", "미디어 꺼내기", "メディアを取り出す", "弹出介质", "Expulsar el medio"]],
  "enable touchpad": ["action.enableTouchpad", ["Enable Touchpad", "터치패드 켜기", "タッチパッドを有効にする", "启用触控板", "Activar el panel táctil"]],
  "expand window down": ["action.expandWindowDown", ["Expand Window Down", "창을 아래로 늘리기", "ウィンドウを下へ広げる", "向下扩展窗口", "Ampliar la ventana hacia abajo"]],
  "expand window down a little": ["action.expandWindowDownALittle", ["Expand Window Down a Little", "창을 아래로 조금 늘리기", "ウィンドウを下へ少し広げる", "向下小幅扩展窗口", "Ampliar un poco la ventana hacia abajo"]],
  "expand window down a lot": ["action.expandWindowDownALot", ["Expand Window Down a Lot", "창을 아래로 많이 늘리기", "ウィンドウを下へ大きく広げる", "向下大幅扩展窗口", "Ampliar mucho la ventana hacia abajo"]],
  "expand window left": ["action.expandWindowLeft", ["Expand Window Left", "창을 왼쪽으로 늘리기", "ウィンドウを左へ広げる", "向左扩展窗口", "Ampliar la ventana hacia la izquierda"]],
  "expand window left a little": ["action.expandWindowLeftALittle", ["Expand Window Left a Little", "창을 왼쪽으로 조금 늘리기", "ウィンドウを左へ少し広げる", "向左小幅扩展窗口", "Ampliar un poco la ventana hacia la izquierda"]],
  "expand window left a lot": ["action.expandWindowLeftALot", ["Expand Window Left a Lot", "창을 왼쪽으로 많이 늘리기", "ウィンドウを左へ大きく広げる", "向左大幅扩展窗口", "Ampliar mucho la ventana hacia la izquierda"]],
  "focus on next monitor": ["action.focusNextMonitor", ["Focus Next Monitor", "다음 모니터로 이동", "次のモニターにフォーカス", "聚焦下一个显示器", "Enfocar el monitor siguiente"]],
  "focus on next window": ["action.focusNextWindow", ["Focus Next Window", "다음 창으로 이동", "次のウィンドウにフォーカス", "聚焦下一个窗口", "Enfocar la ventana siguiente"]],
  "focus on previous monitor": ["action.focusPreviousMonitor", ["Focus Previous Monitor", "이전 모니터로 이동", "前のモニターにフォーカス", "聚焦上一个显示器", "Enfocar el monitor anterior"]],
  "focus on previous window": ["action.focusPreviousWindow", ["Focus Previous Window", "이전 창으로 이동", "前のウィンドウにフォーカス", "聚焦上一个窗口", "Enfocar la ventana anterior"]],
  "keyboard backlight cycle": ["action.keyboardBacklightCycle", ["Cycle Keyboard Backlight", "키보드 백라이트 단계 전환", "キーボードバックライトを切り替え", "循环切换键盘背光", "Cambiar el nivel de luz del teclado"]],
  "keyboard brightness down": ["action.keyboardBrightnessDown", ["Keyboard Brightness Down", "키보드 밝기 낮추기", "キーボードの明るさを下げる", "降低键盘亮度", "Bajar el brillo del teclado"]],
  "keyboard brightness up": ["action.keyboardBrightnessUp", ["Keyboard Brightness Up", "키보드 밝기 높이기", "キーボードを明るくする", "提高键盘亮度", "Subir el brillo del teclado"]],
  "make webcam overlay larger": ["action.webcamOverlayLarger", ["Make Webcam Overlay Larger", "웹캠 화면 크게", "Webカメラ表示を大きくする", "放大摄像头画面", "Aumentar la vista de la cámara"]],
  "make webcam overlay smaller": ["action.webcamOverlaySmaller", ["Make Webcam Overlay Smaller", "웹캠 화면 작게", "Webカメラ表示を小さくする", "缩小摄像头画面", "Reducir la vista de la cámara"]],
  "move window": ["action.moveWindow", ["Move Window", "창 이동", "ウィンドウを移動", "移动窗口", "Mover ventana"]],
  "mute": ["action.mute", ["Mute", "음소거", "ミュート", "静音", "Silenciar"]],
  "mute microphone": ["action.muteMicrophone", ["Mute Microphone", "마이크 음소거", "マイクをミュート", "麦克风静音", "Silenciar el micrófono"]],
  "next track": ["action.nextTrack", ["Next Track", "다음 곡", "次の曲", "下一首", "Pista siguiente"]],
  "pause": ["action.pauseMedia", ["Pause", "일시 정지", "一時停止", "暂停", "Pausar"]],
  "play": ["action.playMedia", ["Play", "재생", "再生", "播放", "Reproducir"]],
  "power menu": ["action.powerMenu", ["Power Menu", "전원 메뉴", "電源メニュー", "电源菜单", "Menú de energía"]],
  "previous track": ["action.previousTrack", ["Previous Track", "이전 곡", "前の曲", "上一首", "Pista anterior"]],
  "reset zoom": ["action.resetZoom", ["Reset Zoom", "화면 확대 초기화", "ズームをリセット", "重置缩放", "Restablecer el zoom"]],
  "resize window": ["action.resizeWindow", ["Resize Window", "창 크기 조절", "ウィンドウサイズを変更", "调整窗口大小", "Cambiar el tamaño de la ventana"]],
  "reveal active window on top": ["action.revealActiveWindow", ["Bring Active Window to Front", "활성 창을 맨 앞으로", "アクティブウィンドウを最前面に表示", "将活动窗口置于最前", "Traer la ventana activa al frente"]],
  "screenrecording": ["action.screenRecording", ["Screen Recording", "화면 녹화", "画面録画", "屏幕录制", "Grabación de pantalla"]],
  "scroll active workspace backward": ["action.scrollWorkspaceBackward", ["Scroll Workspace Backward", "이전 작업 공간으로 스크롤", "前のワークスペースへスクロール", "滚动到上一个工作区", "Desplazarse al espacio de trabajo anterior"]],
  "scroll active workspace forward": ["action.scrollWorkspaceForward", ["Scroll Workspace Forward", "다음 작업 공간으로 스크롤", "次のワークスペースへスクロール", "滚动到下一个工作区", "Desplazarse al espacio de trabajo siguiente"]],
  "select next window to capture": ["action.selectNextCaptureWindow", ["Select Next Window to Capture", "캡처할 다음 창 선택", "キャプチャする次のウィンドウを選択", "选择下一个要截取的窗口", "Elegir la ventana siguiente para capturar"]],
  "select previous window to capture": ["action.selectPreviousCaptureWindow", ["Select Previous Window to Capture", "캡처할 이전 창 선택", "キャプチャする前のウィンドウを選択", "选择上一个要截取的窗口", "Elegir la ventana anterior para capturar"]],
  "select window to capture": ["action.selectCaptureWindow", ["Select Window to Capture", "캡처할 창 선택", "キャプチャするウィンドウを選択", "选择要截取的窗口", "Elegir una ventana para capturar"]],
  "shrink window left": ["action.shrinkWindowLeft", ["Shrink Window from Left", "창 왼쪽 줄이기", "ウィンドウを左側から縮める", "从左侧缩小窗口", "Reducir la ventana desde la izquierda"]],
  "shrink window left a little": ["action.shrinkWindowLeftALittle", ["Shrink Window from Left a Little", "창 왼쪽 조금 줄이기", "ウィンドウを左側から少し縮める", "从左侧小幅缩小窗口", "Reducir un poco la ventana desde la izquierda"]],
  "shrink window left a lot": ["action.shrinkWindowLeftALot", ["Shrink Window from Left a Lot", "창 왼쪽 많이 줄이기", "ウィンドウを左側から大きく縮める", "从左侧大幅缩小窗口", "Reducir mucho la ventana desde la izquierda"]],
  "shrink window up": ["action.shrinkWindowUp", ["Shrink Window from Top", "창 위쪽 줄이기", "ウィンドウを上側から縮める", "从上方缩小窗口", "Reducir la ventana desde arriba"]],
  "shrink window up a little": ["action.shrinkWindowUpALittle", ["Shrink Window from Top a Little", "창 위쪽 조금 줄이기", "ウィンドウを上側から少し縮める", "从上方小幅缩小窗口", "Reducir un poco la ventana desde arriba"]],
  "shrink window up a lot": ["action.shrinkWindowUpALot", ["Shrink Window from Top a Lot", "창 위쪽 많이 줄이기", "ウィンドウを上側から大きく縮める", "从上方大幅缩小窗口", "Reducir mucho la ventana desde arriba"]],
  "start dictation (push-to-talk)": ["action.startDictationPushToTalk", ["Start Dictation (Push to Talk)", "눌러서 말하기 시작", "プッシュトゥトークの音声入力を開始", "开始按键说话", "Iniciar dictado al mantener pulsado"]],
  "stop dictation (push-to-talk)": ["action.stopDictationPushToTalk", ["Stop Dictation (Push to Talk)", "눌러서 말하기 중지", "プッシュトゥトークの音声入力を停止", "停止按键说话", "Detener dictado al mantener pulsado"]],
  "switch audio output": ["action.switchAudioOutput", ["Switch Audio Output", "오디오 출력 전환", "音声出力を切り替え", "切换音频输出", "Cambiar la salida de audio"]],
  "switch media source": ["action.switchMediaSource", ["Switch Media Source", "미디어 소스 전환", "メディアソースを切り替え", "切换媒体来源", "Cambiar la fuente multimedia"]],
  "toggle touchpad": ["action.toggleTouchpad", ["Toggle Touchpad", "터치패드 켜기/끄기", "タッチパッドを切り替え", "切换触控板", "Activar o desactivar el panel táctil"]],
  "universal copy": ["action.universalCopy", ["Universal Copy", "통합 복사", "ユニバーサルコピー", "通用复制", "Copia universal"]],
  "universal cut": ["action.universalCut", ["Universal Cut", "통합 잘라내기", "ユニバーサル切り取り", "通用剪切", "Corte universal"]],
  "universal paste": ["action.universalPaste", ["Universal Paste", "통합 붙여넣기", "ユニバーサル貼り付け", "通用粘贴", "Pegado universal"]],
  "volume down": ["action.volumeDown", ["Volume Down", "볼륨 낮추기", "音量を下げる", "降低音量", "Bajar el volumen"]],
  "volume down precise": ["action.volumeDownPrecise", ["Volume Down Precisely", "볼륨 조금 낮추기", "音量を少し下げる", "精细降低音量", "Bajar el volumen con precisión"]],
  "volume up": ["action.volumeUp", ["Volume Up", "볼륨 높이기", "音量を上げる", "提高音量", "Subir el volumen"]],
  "volume up precise": ["action.volumeUpPrecise", ["Volume Up Precisely", "볼륨 조금 높이기", "音量を少し上げる", "精细提高音量", "Subir el volumen con precisión"]],
  "zoom in": ["action.zoomIn", ["Zoom In", "화면 확대", "ズームイン", "放大", "Acercar"]]
}

const numberedActionTranslations = [
  { pattern: /^bar panel ([0-9]+)$/, key: "action.barPanel",
    values: ["Bar Panel {number}", "바 패널 {number}", "バーパネル{number}", "顶部栏面板 {number}", "Panel {number} de la barra"] },
  { pattern: /^switch to workspace ([0-9]+)$/, key: "action.switchWorkspace",
    values: ["Switch to Workspace {number}", "작업 공간 {number}번으로 이동", "ワークスペース{number}に切り替え", "切换到工作区 {number}", "Cambiar al espacio de trabajo {number}"] },
  { pattern: /^move window to workspace ([0-9]+)$/, key: "action.moveWindowToWorkspace",
    values: ["Move Window to Workspace {number}", "창을 작업 공간 {number}번으로 이동", "ウィンドウをワークスペース{number}へ移動", "将窗口移到工作区 {number}", "Mover la ventana al espacio de trabajo {number}"] },
  { pattern: /^move window silently to workspace ([0-9]+)$/, key: "action.moveWindowSilentlyToWorkspace",
    values: ["Move Window Silently to Workspace {number}", "창을 작업 공간 {number}번으로 조용히 이동", "ウィンドウを追従せずワークスペース{number}へ移動", "将窗口静默移到工作区 {number}", "Mover la ventana sin cambiar al espacio de trabajo {number}"] },
  { pattern: /^switch to group window ([0-9]+)$/, key: "action.switchGroupWindow",
    values: ["Switch to Group Window {number}", "그룹 창 {number}번으로 전환", "グループ内のウィンドウ{number}に切り替え", "切换到组内窗口 {number}", "Cambiar a la ventana {number} del grupo"] }
]

const actionKeys = {
  "terminal": "action.terminal",
  "browser": "action.browser",
  "file manager": "action.fileManager",
  "application launcher": "action.applicationLauncher",
  "close window": "action.closeWindow",
  "toggle fullscreen": "action.toggleFullscreen",
  "full screen": "action.toggleFullscreen",
  "toggle floating": "action.toggleFloating",
  "lock screen": "action.lockScreen",
  "settings": "action.settings",
  "screenshot": "action.screenshot",
  "clipboard": "action.clipboard",
  "notifications": "action.notifications",
  "previous workspace": "action.previousWorkspace",
  "next workspace": "action.nextWorkspace",
  "download video from web app": "action.downloadVideoFromWebApp",
  "copy url from web app": "action.copyUrlFromWebApp"
}

Object.keys(omarchyActionTranslations).forEach(function(title) {
  const definition = omarchyActionTranslations[title]
  actionKeys[title] = definition[0]
  messages[definition[0]] = definition[1]
})

numberedActionTranslations.forEach(function(definition) {
  messages[definition.key] = definition.values
})

function normalizedLanguage(language) {
  const value = String(language || "")
  return localeOrder.indexOf(value) === -1 ? "en" : value
}

function languageIndex(language) {
  return localeOrder.indexOf(normalizedLanguage(language))
}

function languages() {
  return localeOrder.map(function(language) {
    return { id: language, name: languageNames[language] }
  })
}

function keys(language) {
  // The language parameter is accepted so callers can use one catalog-shaped
  // API. Every locale intentionally has the same message set.
  normalizedLanguage(language)
  return Object.keys(messages).sort()
}

function text(language, key, parameters) {
  const message = messages[String(key || "")]
  const source = message ? message[languageIndex(language)] : String(key || "")
  const values = parameters && typeof parameters === "object" ? parameters : ({})
  return String(source).replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g,
    function(match, name) {
      return values[name] === undefined || values[name] === null
        ? match : String(values[name])
    })
}

function modifier(language, canonicalName) {
  // These key names are conventional in all supported desktop locales. They
  // are presentation-only and never change the canonical shortcut identity.
  const names = {
    SUPER: "Super",
    CTRL: "Ctrl",
    SHIFT: "Shift",
    ALT: "Alt"
  }
  const canonical = String(canonicalName || "")
  normalizedLanguage(language)
  return names[canonical] || canonical
}

function normalizedActionTitle(title) {
  return String(title || "").trim().toLocaleLowerCase().replace(/\s+/g, " ")
}

function actionKey(englishTitle) {
  const normalized = normalizedActionTitle(englishTitle)
  const exact = actionKeys[normalized] || ""
  if (exact)
    return exact
  for (const definition of numberedActionTranslations) {
    if (definition.pattern.test(normalized))
      return definition.key
  }
  return ""
}

function actionTitle(language, labelKey, fallback) {
  const key = String(labelKey || "")
  const original = String(fallback || "")
  if (!messages[key])
    return original
  const normalized = normalizedActionTitle(original)
  for (const definition of numberedActionTranslations) {
    if (definition.key !== key)
      continue
    const match = definition.pattern.exec(normalized)
    return match ? text(language, key, { number: match[1] }) : original
  }
  return text(language, key, {})
}
