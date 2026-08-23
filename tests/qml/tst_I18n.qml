import QtQuick
import QtTest
import "../../src/plugin/I18n.js" as I18n

TestCase {
  name: "I18n"

  function test_languages_are_stable_and_english_is_first() {
    const languages = I18n.languages()

    compare(languages.map(function(item) { return item.id }).join(","),
            "en,ko,ja,zh_CN,es")
    compare(languages.map(function(item) { return item.name }).join("|"),
            "English|한국어|日本語|简体中文|Español")
  }

  function test_every_locale_has_the_exact_english_keyset() {
    const baseline = I18n.keys("en").join("|")

    for (const language of I18n.languages()) {
      compare(I18n.keys(language.id).join("|"), baseline, language.id)
      verify(I18n.keys(language.id).every(function(key) {
        return I18n.text(language.id, key, {}).trim().length > 0
      }), language.id + " has an empty translation")
    }
  }

  function test_catalog_covers_each_user_facing_domain() {
    const keys = I18n.keys("en")
    const prefixes = [
      "common.", "language.", "settings.", "hud.",
      "shortcut.", "search.", "error.", "action."
    ]

    for (const prefix of prefixes) {
      verify(keys.some(function(key) { return key.indexOf(prefix) === 0 }),
             "missing " + prefix + " translations")
    }
  }

  function test_parameter_substitution_and_language_fallback() {
    compare(I18n.text("ko", "shortcut.replace", {
      oldTitle: "터미널", newTitle: "파일"
    }), "터미널을 파일(으)로 바꾸시겠어요?")
    compare(I18n.text("invalid", "common.save", {}), "Save")
    compare(I18n.text("ko", "missing.translation", {}), "missing.translation")
  }

  function test_remove_copy_is_natural_in_every_supported_language() {
    compare(I18n.text("en", "common.remove", {}), "Remove")
    compare(I18n.text("ko", "common.remove", {}), "제거")
    compare(I18n.text("ja", "common.remove", {}), "削除")
    compare(I18n.text("zh_CN", "common.remove", {}), "移除")
    compare(I18n.text("es", "common.remove", {}), "Eliminar")
    compare(I18n.text("ko", "shortcut.removeConfirm", {
      title: "터미널", chord: "Super + A"
    }), "Super + A의 터미널 단축키를 제거할까요?")
    compare(I18n.text("ko", "shortcut.removeAgain", {}),
            "확인하려면 ‘제거’를 한 번 더 누르세요.")
  }

  function test_search_badges_never_wrap_their_labels_in_parentheses() {
    const keys = [
      "search.cmdBadge", "search.desktopAppBadge", "search.webAppBadge",
      "search.agentBadge", "search.browserBadge", "search.editorBadge",
      "search.actionBadge", "search.systemUiBadge"
    ]
    for (const language of I18n.languages()) {
      for (const key of keys) {
        const label = I18n.text(language.id, key, {})
        verify(!label.startsWith("("), language.id + ": " + key)
        verify(!label.endsWith(")"), language.id + ": " + key)
      }
    }
  }

  function test_system_ui_badge_is_translated_in_every_supported_language() {
    const expected = {
      en: "SYSTEM UI", ko: "시스템 UI", ja: "システムUI",
      zh_CN: "系统界面", es: "SISTEMA"
    }
    for (const language of I18n.languages())
      compare(I18n.text(language.id, "search.systemUiBadge", {}),
              expected[language.id])
  }

  function test_registered_shortcut_filter_copy_is_localized() {
    compare(I18n.text("en", "shortcut.filterTitle", {}),
            "Find registered shortcuts")
    compare(I18n.text("ko", "shortcut.filterTitle", {}),
            "등록된 단축키 찾기")
    compare(I18n.text("ko", "shortcut.filterPlaceholder", {}),
            "제목, 키 또는 유형 검색")
    compare(I18n.text("ko", "shortcut.filterIdle", {}),
            "검색어를 입력하거나 조합키를 선택하세요.")
    compare(I18n.text("ko", "shortcut.filterNoResults", {}),
            "조건에 맞는 등록 단축키가 없습니다.")
  }

  function test_modifiers_keep_canonical_identity_but_use_display_labels() {
    compare(I18n.modifier("en", "SUPER"), "Super")
    compare(I18n.modifier("ko", "CTRL"), "Ctrl")
    compare(I18n.modifier("ja", "SHIFT"), "Shift")
    compare(I18n.modifier("zh_CN", "ALT"), "Alt")
    compare(I18n.modifier("es", "UNKNOWN"), "UNKNOWN")
  }

  function test_known_actions_localize_and_unknown_actions_are_preserved() {
    const terminalKey = I18n.actionKey("  terminal ")

    compare(terminalKey, "action.terminal")
    compare(I18n.actionTitle("ko", terminalKey, "Terminal"), "터미널")
    compare(I18n.actionTitle("ja", terminalKey, "Terminal"), "ターミナル")
    compare(I18n.actionTitle("zh_CN", terminalKey, "Terminal"), "终端")
    compare(I18n.actionTitle("es", terminalKey, "Terminal"), "Terminal")
    compare(I18n.actionKey("Vendor Tool"), "")
    compare(I18n.actionTitle("ko", "", "Vendor Tool"), "Vendor Tool")
  }

  function test_known_action_keys_match_the_backend_contract() {
    const expected = ({
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
    })

    for (const title of Object.keys(expected))
      compare(I18n.actionKey(title), expected[title], title)
  }

  function test_omarchy_operations_translate_but_application_names_do_not() {
    const privateBrowser = I18n.actionKey("Browser (private)")
    compare(privateBrowser, "action.privateBrowser")
    compare(I18n.actionTitle("ko", privateBrowser, "Browser (private)"),
            "비공개 브라우저")
    compare(I18n.actionTitle("ja", privateBrowser, "Browser (private)"),
            "プライベートブラウザ")
    compare(I18n.actionTitle("zh_CN", privateBrowser, "Browser (private)"),
            "隐私浏览器")
    compare(I18n.actionTitle("es", privateBrowser, "Browser (private)"),
            "Navegador privado")

    const moveLeft = I18n.actionKey("Move window to group on left")
    compare(I18n.actionTitle("ko", moveLeft, "Move window to group on left"),
            "창을 왼쪽 그룹으로 이동")
    const notificationHistory = I18n.actionKey("Open notification history")
    compare(I18n.actionTitle("ja", notificationHistory,
                             "Open notification history"),
            "通知履歴を開く")
    const floatingTiling = I18n.actionKey("Toggle window floating/tiling")
    compare(I18n.actionTitle("zh_CN", floatingTiling,
                             "Toggle window floating/tiling"),
            "切换窗口浮动/平铺")

    for (const appName of ["ChatGPT", "Codex", "Docker", "Obsidian", "Signal"]) {
      compare(I18n.actionKey(appName), "", appName)
      compare(I18n.actionTitle("ko", "", appName), appName, appName)
    }
  }

  function test_every_remaining_omarchy_operation_has_all_four_translations() {
    const titles = [
      "Brightness down", "Brightness down precise", "Brightness maximum",
      "Brightness minimum", "Brightness up", "Brightness up precise",
      "Capture entire screen", "Capture highlighted window",
      "Close all windows", "Disable touchpad", "Eject media",
      "Enable touchpad", "Expand window down",
      "Expand window down a little", "Expand window down a lot",
      "Expand window left", "Expand window left a little",
      "Expand window left a lot", "Focus on next monitor",
      "Focus on next window", "Focus on previous monitor",
      "Focus on previous window", "Keyboard backlight cycle",
      "Keyboard brightness down", "Keyboard brightness up",
      "Make webcam overlay larger", "Make webcam overlay smaller",
      "Move window", "Mute", "Mute microphone", "Next track", "Pause",
      "Play", "Power menu", "Previous track", "Reset zoom",
      "Resize window", "Reveal active window on top", "Screenrecording",
      "Scroll active workspace backward", "Scroll active workspace forward",
      "Select next window to capture", "Select previous window to capture",
      "Select window to capture", "Shrink window left",
      "Shrink window left a little", "Shrink window left a lot",
      "Shrink window up", "Shrink window up a little",
      "Shrink window up a lot", "Start dictation (push-to-talk)",
      "Stop dictation (push-to-talk)", "Switch audio output",
      "Switch media source", "Toggle touchpad", "Universal copy",
      "Universal cut", "Universal paste", "Volume down",
      "Volume down precise", "Volume up", "Volume up precise", "Zoom in"
    ]
    for (const title of titles) {
      const key = I18n.actionKey(title)
      verify(key !== "", title)
      for (const language of ["ko", "ja", "zh_CN", "es"])
        verify(I18n.actionTitle(language, key, title) !== title,
               language + ": " + title)
    }
  }

  function test_numbered_omarchy_operations_preserve_their_number_when_translated() {
    const cases = [
      ["Bar panel 7", "action.barPanel", "바 패널 7"],
      ["Switch to workspace 10", "action.switchWorkspace",
       "작업 공간 10번으로 이동"],
      ["Move window to workspace 4", "action.moveWindowToWorkspace",
       "창을 작업 공간 4번으로 이동"],
      ["Move window silently to workspace 9",
       "action.moveWindowSilentlyToWorkspace",
       "창을 작업 공간 9번으로 조용히 이동"],
      ["Switch to group window 3", "action.switchGroupWindow",
       "그룹 창 3번으로 전환"]
    ]
    for (const item of cases) {
      compare(I18n.actionKey(item[0]), item[1], item[0])
      compare(I18n.actionTitle("ko", item[1], item[0]), item[2], item[0])
    }
  }

  function test_catalog_warning_is_friendly_in_every_supported_language() {
    const expected = ({
      en: "Some unsupported application entries were hidden.",
      ko: "지원하지 않는 일부 프로그램 항목은 숨겼습니다.",
      ja: "対応していない一部のアプリ項目を非表示にしました。",
      zh_CN: "已隐藏部分不受支持的应用条目。",
      es: "Se ocultaron algunas entradas de aplicaciones no compatibles."
    })
    for (const language of I18n.languages())
      compare(I18n.text(language.id, "search.catalogWarnings", {}),
              expected[language.id], language.id)
  }

  function test_beginner_search_copy_is_localized_in_every_language() {
    compare(I18n.text("en", "search.prompt", {}), "What should this shortcut do?")
    compare(I18n.text("ko", "search.prompt", {}), "이 단축키로 무엇을 실행할까요?")
    compare(I18n.text("ja", "search.prompt", {}), "このショートカットで何を実行しますか？")
    compare(I18n.text("zh_CN", "search.prompt", {}), "这个快捷键要执行什么？")
    compare(I18n.text("es", "search.prompt", {}), "¿Qué debe hacer este atajo?")
  }
}
