(function () {
    "use strict";

    if (window.__zonasteamLoaded) return;
    window.__zonasteamLoaded = true;

    var PLUGIN = "zonasteam-plugin";

    function appIdFromUrl() {
        var m = window.location.href.match(/\/app\/(\d+)/i);
        return m ? m[1] : "";
    }

    function appNameFromPage() {
        var el = document.querySelector(".apphub_AppName, #appHubAppName, .game_title_area .title, h1");
        if (el && el.textContent.trim()) return el.textContent.trim();
        var meta = document.querySelector('meta[property="og:title"]');
        if (meta) return meta.getAttribute("content").replace(/\s+on Steam\s*$/i, "").trim();
        return document.title.replace(/\s+on Steam\s*$/i, "").trim();
    }

    function injectButton() {
        var appid = appIdFromUrl();
        if (!appid) return;

        var existing = document.getElementById("zonasteam-btn");
        if (existing) existing.remove();

        var target = document.querySelector(".apphub_AppName, #appHubAppName");
        if (!target) target = document.querySelector(".game_title_area");
        if (!target) return;

        var btn = document.createElement("button");
        btn.id = "zonasteam-btn";
        btn.textContent = "Zonasteam";
        btn.style.cssText =
            "display:inline-block;margin-left:12px;padding:6px 16px;" +
            "background:linear-gradient(135deg,#66c0f4,#4a9ece);color:#fff;" +
            "border:none;border-radius:4px;font-size:13px;font-weight:600;" +
            "cursor:pointer;transition:filter .2s;vertical-align:middle;";
        btn.onmouseover = function () { btn.style.filter = "brightness(1.15)"; };
        btn.onmouseout = function () { btn.style.filter = "none"; };
        btn.onclick = function () { startFix(appid); };

        target.parentNode.insertBefore(btn, target.nextSibling);
    }

    function showStatus(text, isError) {
        var el = document.getElementById("zonasteam-status");
        if (!el) {
            el = document.createElement("div");
            el.id = "zonasteam-status";
            el.style.cssText =
                "position:fixed;top:20px;right:20px;z-index:99999;" +
                "padding:12px 20px;border-radius:8px;font-size:14px;font-weight:500;" +
                "box-shadow:0 4px 20px rgba(0,0,0,.5);transition:opacity .3s;";
            document.body.appendChild(el);
        }
        el.textContent = text;
        el.style.background = isError ? "rgba(220,50,50,.95)" : "rgba(40,50,70,.95)";
        el.style.color = "#fff";
        el.style.opacity = "1";
        if (isError) {
            setTimeout(function () { el.style.opacity = "0"; }, 4000);
        }
    }

    function startFix(appid) {
        if (!window.Millennium || !window.Millennium.callServerMethod) {
            showStatus("Error: Millennium no disponible", true);
            return;
        }

        showStatus("Agregando juego AppID " + appid + "...");
        var btn = document.getElementById("zonasteam-btn");
        if (btn) { btn.disabled = true; btn.style.opacity = ".6"; }

        Millennium.callServerMethod(PLUGIN, "AddGame", { appid: appid })
            .then(function (res) {
                var data = typeof res === "string" ? JSON.parse(res) : (res.result || res.value || res);
                if (typeof data === "string") data = JSON.parse(data);
                if (data && data.success) {
                    showStatus("Juego agregado: " + appid, false);
                } else {
                    showStatus("Error: " + (data && data.error ? data.error : "desconocido"), true);
                }
            })
            .catch(function (err) {
                showStatus("Error: " + String(err), true);
            })
            .finally(function () {
                if (btn) { btn.disabled = false; btn.style.opacity = "1"; }
            });
    }

    function init() {
        injectButton();
        setInterval(function () {
            var newAppid = appIdFromUrl();
            var current = document.getElementById("zonasteam-btn");
            if (newAppid && (!current || current.getAttribute("data-appid") !== newAppid)) {
                injectButton();
                if (current) current.setAttribute("data-appid", newAppid);
            }
        }, 2000);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
