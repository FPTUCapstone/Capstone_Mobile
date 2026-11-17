# Destination Photography & Font Attribution Manifest (`ATTRIBUTION.md`)

This manifest records the provenance, authorship, source URLs, exact licenses, and local asset transformations for all destination photographs bundled under `assets/images/destinations/` in PR 1 (**9 verified Wikimedia Commons assets**).

## Scope & License Separation Notice

- Each photograph retains **only** its individual Creative Commons license shown below; files are **not** consolidated under a single collective license.
- **No Repository-Wide License Propagation:** Bundling `CC BY-SA 3.0 / 4.0` destination photographs as static app media assets does **not** alter or apply Creative Commons ShareAlike terms to TripMate Mobile application source code or unrelated repository files. Any modified derivative of a `CC BY-SA` photograph itself remains subject to the same `CC BY-SA` version terms (`CC BY-SA 3.0` or `CC BY-SA 4.0`).
- **Pre-Release Gate:** Prior to public APK distribution or store release, an accessible in-app **Credits / Attribution** view linking these author credits and license notices must be implemented (explicitly deferred out of PR 1).
- **Typography Provenance:** Bundled fonts in `assets/fonts/` (`BricolageGrotesque` and `Manrope`) are licensed under **SIL Open Font License 1.1**; full copyright notices and license texts are preserved in `assets/fonts/BricolageGrotesque_OFL.txt` and `assets/fonts/Manrope_OFL.txt`.

---

## Verified Destination Photographs (9 Files)

| Local Filename | Depicts | Author / Creator | Exact Source Page URL | License & Version | License URL | Modifications Applied |
|---|---|---|---|---|---|---|
| `bana_golden_bridge.jpg` | Golden Bridge (Cầu Vàng), Bà Nà Hills, Đà Nẵng | DvTor8303 | https://commons.wikimedia.org/wiki/File:Golden_Bridge_at_Ba_Na_Hills_20250718.jpg | CC0 1.0 Universal (Public Domain Dedication) | http://creativecommons.org/publicdomain/zero/1.0/deed.en | Downloaded Wikimedia Commons 960px thumbnail (`960×621`, `252,653 B`) from original `4096×2649` JPEG; no crop or watermark removal. |
| `danang_dragon_bridge.jpg` | Dragon Bridge (Cầu Rồng), Đà Nẵng (daytime) | Person-with-No Name | https://commons.wikimedia.org/wiki/File:Da_Nang_Dragon_Bridge.jpg | CC BY 2.0 | https://creativecommons.org/licenses/by/2.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×640`, `214,204 B`) from original `4704×3136` JPEG; no crop or retouching. |
| `danang_dragon_night.jpg` | Dragon Bridge (Cầu Rồng), Hàn River, Đà Nẵng (night) | Kuroczynski | https://commons.wikimedia.org/wiki/File:2020_Da_Nang_Dragon_Bridge_IMG_3897.jpg | CC BY-SA 4.0 | https://creativecommons.org/licenses/by-sa/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×720`, `128,241 B`) from original `4032×3024` JPEG; resized for mobile bundle weight; derivative notice retained (`CC BY-SA 4.0`). |
| `hoian_ancient_town.jpg` | Hội An Ancient Town yellow street & lanterns | Steffen Schmitz | https://commons.wikimedia.org/wiki/File:H%E1%BB%99i_An,_Ancient_Town,_2020-01_CN-05.jpg | CC BY-SA 4.0 | https://creativecommons.org/licenses/by-sa/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×623`, `252,820 B`) from original `4242×2755` JPEG; resized for mobile bundle weight; EXIF copyright retained (`Steffen Schmitz, CC-BY-SA-4.0`). |
| `hoian_lantern_night.jpg` | Thu Bồn River boats & lanterns, Hội An (night) | Kuroczynski | https://commons.wikimedia.org/wiki/File:Boats_with_lanterns_on_the_Thu_Bon_river_IMG_3864.jpg | CC BY-SA 4.0 | https://creativecommons.org/licenses/by-sa/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×1280`, `337,873 B`) from original `3024×4032` JPEG; resized for mobile bundle weight (`CC BY-SA 4.0`). |
| `hue_ngo_mon.jpg` | Meridian Gate (Ngọ Môn), Imperial City, Huế | Chainwit. | https://commons.wikimedia.org/wiki/File:Hu%E1%BA%BF_(2024)_-_Meridian_Gate_-_Ng%E1%BB%8D_M%C3%B4n_(Ho%C3%A0ng_th%C3%A0nh_Hu%E1%BA%BF)_-_img_02.jpg | CC BY 4.0 | https://creativecommons.org/licenses/by/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×720`, `236,472 B`) from original `3830×2872` JPEG; resized for mobile bundle weight. |
| `my_khe_beach.jpg` | Mỹ Khê Beach coastline, Đà Nẵng | Jpatokal | https://commons.wikimedia.org/wiki/File:My_Khe_Beach_Danang_Coastline.jpg | CC BY-SA 4.0 | https://creativecommons.org/licenses/by-sa/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×720`, `244,895 B`) from original `4032×3024` JPEG; resized for mobile bundle weight (`CC BY-SA 4.0`). |
| `marble_mountains.jpg` | Marble Mountains (Ngũ Hành Sơn), Đà Nẵng | Kuroczynski | https://commons.wikimedia.org/wiki/File:Da_Nang_Marble_Mountains_2020_IMG_4008.jpg | CC BY-SA 4.0 | https://creativecommons.org/licenses/by-sa/4.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×485`, `157,840 B`) from original `7461×3773` JPEG; resized for mobile bundle weight (`CC BY-SA 4.0`). |
| `son_tra_pagoda.jpg` | Linh Ứng Pagoda Tam Quan Gate, Sơn Trà Peninsula | CEphoto, Uwe Aranas | https://commons.wikimedia.org/wiki/File:Son-Tra-Peninsula_Da-Nang_Vietnam_Linh-Ung-Pagoda-01.jpg | CC BY-SA 3.0 | https://creativecommons.org/licenses/by-sa/3.0 | Downloaded Wikimedia Commons 960px thumbnail (`960×716`, `224,507 B`) from original `3480×2597` JPEG; resized for mobile bundle weight (`CC BY-SA 3.0`). |

---

## Excluded Unverified Assets (Reported Separately — NOT Bundled)

- Old Unsplash Golden Bridge URL (`https://images.unsplash.com/photo-1559592413-7cec4d0cae2b`): Photographer name and Unsplash HTML source page URL could not be verified — replaced cleanly by CC0 1.0 `bana_golden_bridge.jpg` above.
- Old FE poster photo (`son_tra_coastal.jpg` / `hero-danang-sontra.jpg`): Committed without independent photo photographer/source metadata prior to Pexels video #30084777 provenance — excluded from PR 1.
- Old Unsplash Hạ Long Bay URL (`photo-1528127269322-539801943592`) and food platter URL (`photo-1555939594-58d7cb561ad1`): Off-subject & unattributed — removed from `GuestHeroBanner`, `GuestLandingPage`, and `DemoTourDetailDataSource`.
