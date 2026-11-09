(function () {
  "use strict";

  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- sticky nav ---------- */
  var nav = document.getElementById("nav");
  var onScroll = function () {
    nav.classList.toggle("is-scrolled", window.scrollY > 24);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---------- reveal on scroll ---------- */
  var revealItems = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reducedMotion) {
    var revealObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
          revealObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -7% 0px" });
    revealItems.forEach(function (item) { revealObserver.observe(item); });
  } else {
    revealItems.forEach(function (item) { item.classList.add("in"); });
  }

  // The hero is above the fold; do not wait for a scroll event to reveal it.
  var heroReveals = document.querySelectorAll(".hero .reveal");
  window.requestAnimationFrame(function () {
    heroReveals.forEach(function (item) { item.classList.add("in"); });
  });

  /* ---------- interactive demo ---------- */
  var shell = document.getElementById("demoShell");
  if (shell) {
    var tabs = Array.prototype.slice.call(shell.querySelectorAll(".demo-tab"));
    var panelCard = document.getElementById("panelCard");
    var panelPhone = document.getElementById("panelPhone");
    var demoShot = document.getElementById("demoShot");
    var demoTitle = document.getElementById("demoTitle");
    var demoDesc = document.getElementById("demoDesc");
    var demoChip = document.getElementById("demoChip");
    var demoBar = document.getElementById("demoBar");
    var stageTags = [
      shell.querySelector(".stage-tag-1"),
      shell.querySelector(".stage-tag-2"),
      shell.querySelector(".stage-tag-3")
    ];
    var demoStage = document.getElementById("demoStage");
    var activeIndex = 0;
    var demoTimer = null;
    var DEMO_DURATION = 7000;

    var demos = [
      {
        key: "card",
        mode: "card",
        title: "桌面卡片",
        desc: "推荐、最近添加、分类，以及搜索入口都在这一屏。抬手就能点。",
        chip: "抬手就用",
        tags: ["推荐", "最近添加", "搜索"]
      },
      {
        key: "search",
        mode: "phone",
        image: "assets/search.webp",
        alt: "StarGate 搜索页，支持拼音首字母与 A–Z 分段",
        title: "搜索",
        desc: "按 A–Z 浏览全部能力，输入中文、App 名或拼音首字母，结果即时出现。",
        chip: "知道名字就搜",
        tags: ["A–Z 分段", "拼音首字母", "输入即筛"]
      },
      {
        key: "category",
        mode: "phone",
        image: "assets/category.webp",
        alt: "StarGate 分类页，按场景组织功能",
        title: "分类",
        desc: "按出行、购物、办公、生活等场景组织能力，一屏一组，点分类进入完整列表。",
        chip: "按场景逛",
        tags: ["出行", "办公", "生活"]
      },
      {
        key: "settings",
        mode: "phone",
        image: "assets/settings.webp",
        alt: "StarGate 设置页，支持分类长按拖动排序",
        title: "设置",
        desc: "分类支持长按拖动排序，顺序会持久化，并实时同步到桌面卡片。",
        chip: "按习惯调整",
        tags: ["长按拖动", "顺序持久化", "实时同步"]
      }
    ];

    var progressRun = function () {
      if (!demoBar) return;
      demoBar.classList.remove("run");
      // force a reflow so the CSS animation restarts
      void demoBar.offsetWidth;
      if (!reducedMotion) demoBar.classList.add("run");
    };

    var scheduleNext = function () {
      window.clearTimeout(demoTimer);
      if (reducedMotion || document.hidden) return;
      demoTimer = window.setTimeout(function () {
        showDemo((activeIndex + 1) % demos.length, false);
      }, DEMO_DURATION);
    };

    var showDemo = function (index, fromUser) {
      activeIndex = index;
      var demo = demos[index];

      tabs.forEach(function (tab, tabIndex) {
        var selected = tabIndex === index;
        tab.classList.toggle("is-active", selected);
        tab.setAttribute("aria-selected", selected ? "true" : "false");
        tab.setAttribute("tabindex", selected ? "0" : "-1");
      });

      var isCard = demo.mode === "card";
      if (panelCard) {
        panelCard.classList.toggle("is-active", isCard);
        panelCard.setAttribute("aria-hidden", isCard ? "false" : "true");
      }
      if (panelPhone) {
        panelPhone.classList.toggle("is-active", !isCard);
        panelPhone.setAttribute("aria-hidden", isCard ? "true" : "false");
      }
      if (!isCard && demoShot) {
        demoShot.src = demo.image;
        demoShot.alt = demo.alt;
      }

      if (demoTitle) demoTitle.textContent = demo.title;
      if (demoDesc) demoDesc.textContent = demo.desc;
      if (demoChip) demoChip.textContent = demo.chip;
      stageTags.forEach(function (tag, tagIndex) {
        if (tag) tag.textContent = demo.tags[tagIndex];
      });

      if (demoStage) demoStage.setAttribute("data-active", demo.key);
      progressRun();
      scheduleNext();
      if (fromUser) {
        // keep the active tab visible on narrow screens
        tabs[index].scrollIntoView({ block: "nearest", inline: "nearest" });
      }
    };

    tabs.forEach(function (tab, index) {
      tab.addEventListener("click", function () { showDemo(index, true); });
    });

    shell.querySelector(".demo-tabs").addEventListener("keydown", function (event) {
      var delta = 0;
      if (event.key === "ArrowRight" || event.key === "ArrowDown") delta = 1;
      if (event.key === "ArrowLeft" || event.key === "ArrowUp") delta = -1;
      if (!delta) return;
      event.preventDefault();
      var next = (activeIndex + delta + demos.length) % demos.length;
      showDemo(next, true);
      tabs[next].focus();
    });

    document.addEventListener("visibilitychange", function () {
      if (document.hidden) {
        window.clearTimeout(demoTimer);
      } else {
        progressRun();
        scheduleNext();
      }
    });

    showDemo(0, false);
  }

  /* ---------- video dialog ---------- */
  var dialog = document.getElementById("videoDialog");
  var video = document.getElementById("demoVideo");
  if (dialog && video) {
    var openVideo = function () {
      if (!dialog.open) dialog.showModal();
      document.body.classList.add("no-scroll");
      var playPromise = video.play();
      if (playPromise && typeof playPromise.catch === "function") {
        playPromise.catch(function () { /* autoplay may be blocked; controls remain */ });
      }
    };
    var closeVideo = function () {
      video.pause();
      if (dialog.open) dialog.close();
    };

    document.querySelectorAll(".video-open").forEach(function (button) {
      button.addEventListener("click", openVideo);
    });
    dialog.querySelector(".dialog-close").addEventListener("click", closeVideo);
    dialog.addEventListener("click", function (event) {
      if (event.target === dialog) closeVideo();
    });
    dialog.addEventListener("close", function () {
      video.pause();
      document.body.classList.remove("no-scroll");
    });
  }

  /* ---------- copy install command ---------- */
  var toast = document.getElementById("toast");
  var toastTimer = null;
  var showToast = function (message) {
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add("show");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () {
      toast.classList.remove("show");
    }, 1800);
  };

  var fallbackCopy = function (text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (error) { ok = false; }
    document.body.removeChild(area);
    return ok;
  };

  document.querySelectorAll("[data-copy]").forEach(function (button) {
    button.addEventListener("click", function () {
      var text = button.getAttribute("data-copy") || "";
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () {
          showToast("安装命令已复制");
        }).catch(function () {
          showToast(fallbackCopy(text) ? "安装命令已复制" : "复制失败，请手动选择");
        });
      } else {
        showToast(fallbackCopy(text) ? "安装命令已复制" : "复制失败，请手动选择");
      }
    });
  });

  /* ---------- subtle hero parallax ---------- */
  var heroVisual = document.querySelector(".hero-visual");
  var finePointer = window.matchMedia("(pointer: fine)").matches;
  if (heroVisual && finePointer && !reducedMotion) {
    var card = heroVisual.querySelector(".hero-card");
    var phone = heroVisual.querySelector(".hero-phone");
    heroVisual.addEventListener("pointermove", function (event) {
      var rect = heroVisual.getBoundingClientRect();
      var x = (event.clientX - rect.left) / rect.width - 0.5;
      var y = (event.clientY - rect.top) / rect.height - 0.5;
      if (card) card.style.transform = "rotate(-2.4deg) translate3d(" + (x * 9) + "px," + (y * 7) + "px,0)";
      if (phone) phone.style.transform = "rotate(5deg) translate3d(" + (x * -13) + "px," + (y * -9) + "px,0)";
    });
    heroVisual.addEventListener("pointerleave", function () {
      if (card) card.style.transform = "";
      if (phone) phone.style.transform = "";
    });
  }
})();
