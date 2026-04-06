/**
 * Shared i18n configuration for MONSKILLS.
 *
 * Depends on i18next and i18nextBrowserLanguageDetector being loaded first.
 * Each page adds its own page-specific keys via addResourceBundle() after init.
 */

var I18N_RESOURCES = {
  en: {
    translation: {
      'copy.copied': 'Copied!'
    }
  },
  zh: {
    translation: {
      'copy.copied': '已复制！'
    }
  }
};

i18next
  .use(i18nextBrowserLanguageDetector)
  .init({
    resources: I18N_RESOURCES,
    fallbackLng: 'en',
    supportedLngs: ['en', 'zh'],
    detection: {
      order: ['querystring', 'localStorage', 'navigator'],
      lookupQuerystring: 'lang',
      caches: ['localStorage']
    }
  });

/** Returns the resolved language code ('en' or 'zh'). */
function getLang() {
  return i18next.language.startsWith('zh') ? 'zh' : 'en';
}

/** Translates all elements with data-i18n attributes. */
function applyI18nAttributes() {
  document.querySelectorAll('[data-i18n]').forEach(function(el) {
    el.textContent = i18next.t(el.getAttribute('data-i18n'));
  });
  document.documentElement.lang = getLang();
}

/** Highlights the active language button. */
function setActiveLangBtn() {
  var lang = getLang();
  document.querySelectorAll('.lang-btn').forEach(function(btn) {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });
}

/**
 * Initializes language switcher buttons.
 * @param {function} [onSwitch] - Optional callback invoked after language change.
 */
function initLangSwitcher(onSwitch) {
  document.querySelectorAll('.lang-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var lang = btn.dataset.lang;
      i18next.changeLanguage(lang, function() {
        applyI18nAttributes();
        setActiveLangBtn();
        // Update URL without reload
        var url = new URL(window.location);
        url.searchParams.set('lang', lang);
        history.replaceState(null, '', url);
        if (onSwitch) onSwitch(lang);
      });
    });
  });

  applyI18nAttributes();
  setActiveLangBtn();
}
