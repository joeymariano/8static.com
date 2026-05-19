# 8static.com

Site for **8static**, Philadelphia's chiptune & electronic arts showcase at PhilaMOCA.

![screenshot](https://raw.githubusercontent.com/joeymariano/8static.com/master/screenshot.png)

Built on Jekyll, originally based on the [Freelancer Bootstrap theme](http://startbootstrap.com/template-overviews/freelancer). Deployed via manual FTP of the `_site/` build.

## Local development

```sh
bundle install
bundle exec jekyll serve
```

Site builds to `_site/`. The `screenshot.png`, `README.md`, `LICENCE`, `Rakefile`, and high-resolution image backups under `img/**/high-quality/` are excluded from the build (see `_config.yml`).

## Site structure

`_layouts/default.html` composes the single homepage from these includes (in order):

- `nav.html` — top nav, shrinks on scroll
- `header.html` — hero
- `recent_fliers.html` — "Recent Shows" row, pulls the 3 most recent events that have a flier
- `next_show.html` — only renders when `_fliers/` has entries (upcoming show)
- `posts_grid.html` — current artist grid with shuffle button
- `about.html`
- `past_events.html` — collapsed-by-year archive of every show
- `modals.html` — artist + flier modals
- `footer.html`, `js.html`

JSON-LD (`Organization`, `MusicEvent` `ItemList`), OpenGraph, and Twitter Card metadata are emitted from `head.html` and `past_events.html` for SEO / AI discoverability.

## Collections

Configured in `_config.yml` (all `output: false` — rendered into the homepage, no per-item pages):

| Collection | Folder | Purpose |
|---|---|---|
| `artists` | `_artists/` | Performers for the current/most recent show. Renders the Artists grid + modals. |
| `past_events` | `_past_events/` | Full event archive (90 shows, 2008–2017, plus recent shows from 2024+). Renders the Past Events accordion, Recent Shows row, flier modals, and `MusicEvent` JSON-LD. |
| `fliers` | `_fliers/` | Upcoming show. When non-empty, the "Next Show" section renders. |

### Adding a past event

Filename: `_past_events/YYYY-MM-DD-slug.md`

```yaml
---
name: "8STATIC 01"
venue: "Studio 34"
date: 2008-10-18
date_display: "Oct 18, 2008"
year: 2008
event_id: "01"          # unique; used for modal + JSON-LD anchor
music:
  - "Performer Name"
visuals:
  - "Visualist Name"
flier:                  # optional — adds it to Recent Shows + flier modal
  img: 2024-09-07-flier.png
  alt: "Show flier"
  width: 2515
  height: 3540
flickr:                 # optional
  - url: "https://www.flickr.com/photos/..."
    label: "Album"      # optional, defaults to "Album"
---
```

Fliers live at `img/fliers/<img>`. High-res originals can be kept under `img/fliers/high-quality/` (excluded from the build).

### Adding an artist (current show)

Filename: `_artists/YYYY-MM-DD-artist-NNN.markdown`

```yaml
---
layout: default
modal-id: 001           # unique; powers the modal anchor
date: 2024-09-07
img: artist.jpeg        # path under img/artists/
alt: "Artist Name"
name: "Artist Name"
genre: visuals          # or music
bio: "..."
width: 1125
height: 1125
links:                  # optional
  - label: "Bandcamp"
    url: "https://..."
---
```

The Artists grid is reversed (`{% for artist in site.artists reversed %}`) and can be shuffled in-place via the Shuffle button.

### Adding an upcoming show

Drop a flier file into `_fliers/`. While that folder has any entries, `next_show.html` renders above the artist grid.

## Image handling

All images are served with explicit `width`/`height` and `loading="lazy" decoding="async"` to avoid CLS. Keep originals under `img/<category>/high-quality/` — those folders are excluded from `_site/`.

## Deploy

Manual FTP drag-and-drop of the `_site/` output to the host.

---

Theme license: see `LICENCE`. Jekyll docs: <https://jekyllrb.com/>.
