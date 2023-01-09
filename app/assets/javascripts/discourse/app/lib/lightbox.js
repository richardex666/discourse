import {
  escapeExpression,
  postRNWebviewMessage,
} from "discourse/lib/utilities";

import I18n from "I18n";
import User from "discourse/models/user";
import deprecated from "discourse-common/lib/deprecated";
import { getOwner } from "discourse-common/lib/get-owner";
import { helperContext } from "discourse-common/lib/helpers";
import { isTesting } from "discourse-common/config/environment";
import loadScript from "discourse/lib/load-script";
import { renderIcon } from "discourse-common/lib/icon-library";
import { spinnerHTML } from "discourse/helpers/loading-spinner";

export async function setupLightboxes({ container, selector }) {
  const lightboxService = getOwner(this).lookup("service:lightbox");
  lightboxService.setupLightboxes({ container, selector });
}

export function cleanupLightboxes() {
  const lightboxService = getOwner(this).lookup("service:lightbox");
  return lightboxService.cleanupLightboxes();
}

export default function lightbox(elem, siteSettings) {
  if (siteSettings.enable_experimental_lightbox) {
    deprecated(
      "Accessing the default `lightbox` export is deprecated. Import setupLightboxes and cleanupLightboxes from `discourse/lib/lightbox` instead.",
      {
        since: "3.0.0.beta16",
        dropFrom: "3.2.0",
        id: "discourse.lightbox.default-export",
      }
    );

    return setupLightboxes({
      container: elem,
      selector: "*:not(.spoiler):not(.spoiled) a.lightbox",
    });
  }

  if (!elem) {
    return;
  }

  const lightboxes = elem.querySelectorAll(
    "*:not(.spoiler):not(.spoiled) a.lightbox"
  );

  if (!lightboxes.length) {
    return;
  }

  const caps = helperContext().capabilities;
  const imageClickNavigation = caps.touch;

  loadScript("/javascripts/jquery.magnific-popup.min.js").then(function () {
    $(lightboxes).magnificPopup({
      type: "image",
      closeOnContentClick: false,
      removalDelay: isTesting() ? 0 : 300,
      mainClass: "mfp-zoom-in",
      tClose: I18n.t("lightbox.close"),
      tLoading: spinnerHTML,
      prependTo: isTesting() && document.getElementById("ember-testing"),

      gallery: {
        enabled: true,
        tPrev: I18n.t("lightbox.previous"),
        tNext: I18n.t("lightbox.next"),
        tCounter: I18n.t("lightbox.counter"),
        navigateByImgClick: imageClickNavigation,
      },

      ajax: {
        tError: I18n.t("lightbox.content_load_error"),
      },

      callbacks: {
        open() {
          if (!imageClickNavigation) {
            const wrap = this.wrap,
              img = this.currItem.img,
              maxHeight = img.css("max-height");

            wrap.on("click.pinhandler", "img", function () {
              wrap.toggleClass("mfp-force-scrollbars");
              img.css(
                "max-height",
                wrap.hasClass("mfp-force-scrollbars") ? "none" : maxHeight
              );
            });
          }

          if (caps.isAppWebview) {
            postRNWebviewMessage(
              "headerBg",
              $(".mfp-bg").css("background-color")
            );
          }
        },
        change() {
          this.wrap.removeClass("mfp-force-scrollbars");
        },
        beforeClose() {
          this.wrap.off("click.pinhandler");
          this.wrap.removeClass("mfp-force-scrollbars");
          if (caps.isAppWebview) {
            postRNWebviewMessage(
              "headerBg",
              $(".d-header").css("background-color")
            );
          }
        },
      },

      image: {
        tError: I18n.t("lightbox.image_load_error"),
        titleSrc(item) {
          const href = item.el.data("download-href") || item.src;
          let src = [
            escapeExpression(item.el.attr("title")),
            $("span.informations", item.el).text(),
          ];
          if (
            !siteSettings.prevent_anons_from_downloading_files ||
            User.current()
          ) {
            src.push(
              '<a class="image-source-link" href="' +
                href +
                '">' +
                renderIcon("string", "download") +
                I18n.t("lightbox.download") +
                "</a>"
            );
          }
          src.push(
            '<a class="image-source-link" href="' +
              item.src +
              '">' +
              renderIcon("string", "image") +
              I18n.t("lightbox.open") +
              "</a>"
          );
          return src.join(" &middot; ");
        },
      },
    });
  });
}
