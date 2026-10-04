/**
 * TheShampooFactory Local Standalone Interactive Fixes
 * Provides native event handling for Desktop Menus, Mobile Drawer,
 * and Elementor Nested Tabs without external network dependencies.
 */
(function () {
  'use strict';

  // 1. Safe Analytics & Tracking Stubs
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {};
  window._googlesitekit = window._googlesitekit || {
    throttledEvents: [],
    gtagEvent: function () {}
  };

  function ready(fn) {
    if (document.readyState !== 'loading') {
      fn();
    } else {
      document.addEventListener('DOMContentLoaded', fn);
    }
  }

  ready(function () {
    // ------------------------------------------------------------------------
    // A. Desktop Dropdown Menus
    // ------------------------------------------------------------------------
    var desktopMenus = document.querySelectorAll('header [data-device="desktop"] nav[data-id="menu"], .header-menu-1');
    desktopMenus.forEach(function (nav) {
      nav.setAttribute('data-responsive', 'yes');
      var parentItems = nav.querySelectorAll('li.menu-item-has-children');
      parentItems.forEach(function (item) {
        item.addEventListener('mouseenter', function () {
          item.classList.add('ct-active');
        });
        item.addEventListener('mouseleave', function () {
          item.classList.remove('ct-active');
        });
        item.addEventListener('focusin', function () {
          item.classList.add('ct-active');
        });
        item.addEventListener('focusout', function (e) {
          if (!item.contains(e.relatedTarget)) {
            item.classList.remove('ct-active');
          }
        });
      });
    });

    // ------------------------------------------------------------------------
    // B. Mobile Hamburger Drawer (#offcanvas)
    // ------------------------------------------------------------------------
    var offcanvas = document.getElementById('offcanvas');
    var triggers = document.querySelectorAll('[data-toggle-panel="#offcanvas"], .ct-header-trigger');
    var closeButtons = document.querySelectorAll('.ct-toggle-close, [aria-label="Close drawer"]');

    function openDrawer(e) {
      if (e && e.preventDefault) e.preventDefault();
      if (!offcanvas) return;
      offcanvas.classList.add('active');
      offcanvas.removeAttribute('inert');
      document.body.setAttribute('data-panel', 'in:start');
    }

    function closeDrawer(e) {
      if (e && e.preventDefault) e.preventDefault();
      if (!offcanvas) return;
      offcanvas.classList.remove('active');
      offcanvas.setAttribute('inert', '');
      document.body.removeAttribute('data-panel');
    }

    triggers.forEach(function (btn) {
      btn.addEventListener('click', openDrawer);
    });

    closeButtons.forEach(function (btn) {
      btn.addEventListener('click', closeDrawer);
    });

    if (offcanvas) {
      offcanvas.addEventListener('click', function (e) {
        if (e.target === offcanvas) {
          closeDrawer(e);
        }
      });
    }

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && document.body.hasAttribute('data-panel')) {
        closeDrawer();
      }
    });

    // Mobile Menu Dropdown Toggle inside Offcanvas
    var mobileDropdownButtons = document.querySelectorAll('.mobile-menu .ct-toggle-dropdown-mobile');
    mobileDropdownButtons.forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var parentLi = btn.closest('li.menu-item-has-children');
        if (parentLi) {
          var isExpanded = parentLi.classList.toggle('dropdown-active');
          btn.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
        }
      });
    });

    // ------------------------------------------------------------------------
    // C. Elementor Nested Tabs Click Switching
    // ------------------------------------------------------------------------
    var tabWidgets = document.querySelectorAll('.elementor-widget-n-tabs');
    tabWidgets.forEach(function (widget) {
      if (widget.dataset.fixesBound) return;
      widget.dataset.fixesBound = 'true';

      var tabTitles = widget.querySelectorAll('.e-n-tab-title');
      var tabPanels = widget.querySelectorAll('.e-n-tabs-content > [role="tabpanel"], .e-n-tabs-content > .e-con');

      tabTitles.forEach(function (titleBtn, index) {
        titleBtn.addEventListener('click', function (e) {
          e.preventDefault();

          tabTitles.forEach(function (btn) {
            btn.setAttribute('aria-selected', 'false');
            btn.setAttribute('tabindex', '-1');
            btn.classList.remove('e-active');
          });

          titleBtn.setAttribute('aria-selected', 'true');
          titleBtn.setAttribute('tabindex', '0');
          titleBtn.classList.add('e-active');

          var targetId = titleBtn.getAttribute('aria-controls');
          var tabIndex = titleBtn.getAttribute('data-tab-index') || (index + 1);

          tabPanels.forEach(function (panel) {
            panel.classList.remove('e-active');
            panel.style.display = 'none';
          });

          var targetPanel = targetId ? document.getElementById(targetId) : null;
          if (!targetPanel) {
            targetPanel = widget.querySelector('.e-n-tabs-content > [data-tab-index="' + tabIndex + '"]');
          }
          if (!targetPanel && tabPanels[index]) {
            targetPanel = tabPanels[index];
          }

          if (targetPanel) {
            targetPanel.classList.add('e-active');
            targetPanel.style.display = 'flex';
          }
        });
      });
    });

    // ------------------------------------------------------------------------
    // D. Smooth Scroll Fallback for In-Page Anchors & Quotes
    // ------------------------------------------------------------------------
    var quoteButtons = document.querySelectorAll('a[href*="popup:open"]');
    quoteButtons.forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        var form = document.querySelector('.fluentform, form');
        if (form) {
          e.preventDefault();
          form.scrollIntoView({ behavior: 'smooth' });
        }
      });
    });

    // ------------------------------------------------------------------------
    // E. Standalone Elementor Swiper Carousel Initializer & Enhancer
    // ------------------------------------------------------------------------
    function initProductCarousels() {
      if (typeof window.Swiper === 'undefined') {
        setTimeout(initProductCarousels, 150);
        return;
      }

      var carouselWidgets = document.querySelectorAll('.elementor-widget-image-carousel, .elementor-widget-media-carousel');
      carouselWidgets.forEach(function (widget) {
        var wrapper = widget.querySelector('.elementor-image-carousel-wrapper, .elementor-main-swiper, .swiper');
        if (!wrapper) return;

        var prevBtn = widget.querySelector('.elementor-swiper-button-prev');
        var nextBtn = widget.querySelector('.elementor-swiper-button-next');
        var paginationEl = widget.querySelector('.swiper-pagination');

        // Case A: Swiper is already initialized
        if (wrapper.swiper) {
          var sw = wrapper.swiper;
          if (sw.autoplay && !sw.autoplay.running) {
            try {
              sw.params.autoplay = {
                delay: 3500,
                disableOnInteraction: false,
                pauseOnMouseEnter: true
              };
              sw.autoplay.start();
            } catch (err) {}
          }
          if (prevBtn && !prevBtn._bound) {
            prevBtn._bound = true;
            prevBtn.addEventListener('click', function (e) {
              e.preventDefault();
              sw.slidePrev();
            });
          }
          if (nextBtn && !nextBtn._bound) {
            nextBtn._bound = true;
            nextBtn.addEventListener('click', function (e) {
              e.preventDefault();
              sw.slideNext();
            });
          }
          return;
        }

        // Case B: Not initialized yet - initialize with Swiper v8
        if (widget.dataset.carouselInit) return;
        widget.dataset.carouselInit = 'true';

        var settings = {};
        try {
          settings = JSON.parse(widget.getAttribute('data-settings') || '{}');
        } catch (e) {}

        var slides = widget.querySelectorAll('.swiper-slide');
        var slidesCount = slides.length;
        var slidesPerView = parseInt(settings.slides_to_show, 10) || 1;
        var isLoop = settings.infinite === 'yes' || settings.infinite === true || (slidesCount > 1);
        var speed = parseInt(settings.speed, 10) || 500;
        var effect = settings.effect === 'fade' ? 'fade' : 'slide';

        try {
          var instance = new window.Swiper(wrapper, {
            slidesPerView: slidesPerView,
            loop: isLoop,
            speed: speed,
            effect: effect,
            autoplay: {
              delay: 3500,
              disableOnInteraction: false,
              pauseOnMouseEnter: true
            },
            navigation: {
              prevEl: prevBtn,
              nextEl: nextBtn
            },
            pagination: {
              el: paginationEl,
              clickable: true,
              type: 'bullets',
              renderBullet: function (index, className) {
                return '<span class="' + className + '" role="button" tabindex="0" aria-label="Go to slide ' + (index + 1) + '"></span>';
              }
            },
            keyboard: {
              enabled: true,
              onlyInViewport: true
            },
            grabCursor: true,
            observer: true,
            observeParents: true
          });

          if (prevBtn) {
            prevBtn.addEventListener('click', function (e) {
              e.preventDefault();
              instance.slidePrev();
            });
          }
          if (nextBtn) {
            nextBtn.addEventListener('click', function (e) {
              e.preventDefault();
              instance.slideNext();
            });
          }
        } catch (err) {
          console.warn('[local-fixes] Swiper init error:', err);
        }
      });
    }

    initProductCarousels();
    window.addEventListener('load', initProductCarousels);
  });
})();
