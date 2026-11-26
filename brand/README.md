# Announcement cards

Every Admitik announcement image is this card: `announcement-card.html`. Copy it,
change the slots, render it. The palette, the type and the three-fact row stay.

## The frame

- 1280x640.
- The wave background of the site (`content/en/background.png`) with a navy
  gradient on top, so white text holds.
- Shield and wordmark centred, Poppins, 44px.
- One row of three facts, separated by a 1px rule at 22% white.
- Widths: 402px for the first fact, 340px for the second, the rest for the third.

## Facts

Each fact is an illustration, a label and a value.

- Illustrations are flat translucent fills (white at 11-13%) with a soft shadow.
  No outlines, no borders, no badges.
- Labels and values are Space Grotesk. Labels uppercase, 12px, 2.2px tracking, in
  periwinkle `#b1c4e9`. Values 31px semibold, white.
- Only the first fact carries an accent colour.
- Numbers are the message. If a number was not measured, it does not go in.

## Illustrations

Memory. One smooth bezier curve: spikes before, one fall, a gentle wave after.
The area under it is filled twice and clipped, white before the fall and
periwinkle `#b1c4e9` after. Annotate both levels (`6 GB`, `200 MB`) and nothing else.

Docs. A browser window with the URL pill and two cards. Three bars in the
sidebar, two cards, no more. The highlighted card is filled periwinkle.

Home. A repository card: avatar, `org/repo`, branch. No stars, no badges.

## Palette

| Colour | Hex | Use |
|---|---|---|
| Wave blue | `#0d2bb5` | Background, under the artwork |
| Ink | `#061538` | Gradient on the waves |
| Sky | `#b1c4e9` | Accents, labels, the second half of the chart |
| White | `#ffffff` | Text and the first half of the chart |

## Rendering

Google Fonts has to load, so serve the repository root:

```console
python3 -m http.server 8000
```

```console
~/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell \
  --headless --no-sandbox --hide-scrollbars --window-size=1280,640 \
  --force-device-scale-factor=2 --virtual-time-budget=6000 \
  --screenshot=/tmp/card@2x.png \
  http://127.0.0.1:8000/brand/announcement-card.html
```

Downscale `/tmp/card@2x.png` to 1280x640 for the published file, and keep the 2x
next to it.
